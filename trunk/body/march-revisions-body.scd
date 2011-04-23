MIDIPort.init(#[3]);

BP.loadGui;

MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

(Document.current.path.dirname.dirname +/+ "common/common-defs.scd").loadPath;

// well, for pete's sake...
#["feet/feet-defs.scd",
"arms/arms-defs1.scd",
"head/head-defs.scd",
"torso/torso-defs.scd",
"body/body-defs.scd"].do { |file|
	(Document.current.path.dirname.dirname +/+ file).loadPath;
};

s.sendMsg(\n_free, 1001);

~master.doWhenReady { PeakMonitor(~master) };


m = MixerChannel(\test1, s, 1, 2/*, level: 0.1*/, outbus: ~master);
n = MixerChannel(\test2, s, 2, 2/*, level: 0.1*/, outbus: ~master);
m => MCG(0); n => MCG(1);

[m, n].do { |mx|
	// mx.outbus = ~master;
	mx.sendsSignalTo(~glrvbmc);
	mx.sendsSignalTo(~lcrvbmc);
};

~master => MCG(7);
~glrvbmc => MCG(5);
~lcrvbmc => MCG(6);

PeakMonitor(m);
PeakMonitor(n);
PeakMonitor(~master);
PeakMonitor(~glrvbmc);
PeakMonitor(~lcrvbmc);


[~glrvb, ~lcrvb].do(_.run(false)); [~glrvbmc, ~lcrvbmc].do(_.mute(true));
[~glrvb, ~lcrvb].do(_.run(true)); [~glrvbmc, ~lcrvbmc].do(_.mute(false));


[~glrvb/*, ~lcrvb*/].do(_.run(false)); [~glrvbmc/*, ~lcrvbmc*/].do(_.mute(true));
[~glrvb/*, ~lcrvb*/].do(_.run(true)); [~glrvbmc/*, ~lcrvbmc*/].do(_.mute(false));

[/*~glrvb,*/ ~lcrvb].do(_.run(false)); [/*~glrvbmc,*/ ~lcrvbmc].do(_.mute(true));
[/*~glrvb,*/ ~lcrvb].do(_.run(true)); [/*~glrvbmc,*/ ~lcrvbmc].do(_.mute(false));

~cavernousRvb.run(false); ~cRvbMc.mute(true);
~cavernousRvb.run(true); ~cRvbMc.mute(false);


VoicerProxy.new => VP.prNew(0);
4.do { VP(0).v.addControlProxy(VoicerGCProxy(nil, VP(0).v), addAlways: true) };
VP(0).v.gui;



// data
Fact(\dataIn).chuck(BP(\di), nil, (playTestFile: true, readFrame: 138));

value { var x = BP(\di).buf.numFrames / 30; [x div: 60, x % 60] };

BP(\di).setStartTime(39, 07); // L comes back on for solo
BP(\di).setStartTime(40, 16); // S&I enter from R
BP(\di).setStartTime(40, 29); // stop
BP(\di).setStartTime(39, 07);

BP(\di).player.trace


// footsteps
BP(#[st, op, traj]).free;
\chuckIf.eval(PR(\trajectories), BP, \traj);
\chuckIf.eval(Fact(\opening), BP, \op, nil, Library.at(\rvbs));
\chuckIf.eval(Fact(\openingSteps), BP, \st, nil, Library.at(\rvbs));

p = BP(\st);

p.gestures.slowStepStretch = { |parms|
				parms[\xEnds] ?? {
					parms[\xEnds] = [rrand(0.5, 1.0) * #[-1, 1].choose, 0]
				};
				parms[\yEnds] ?? {
					parms[\yEnds] = [rrand(0.5, 1.0).linlin(0.0, 1.0, ~distNear, ~distFar), ~distNear]
				};
				parms[\delta] ?? {
					parms[\delta] = (BPStream(\slowDelta)
						* Pgeom.fromEndpoints(1.8, rrand(0.5, 0.7), parms[\numEv])
					)
				};
				Pbind(
					\instrument, \pvplayPanDist,
					\early, 0,
					\pvbuf, ~pvbuf,
					\pt, BPStream(\ptIndex).clump(3),
					\start, ~start,
					\startFrame, Pkey(\start) / ~buffers[0].numFrames * ~numPvFrames,
					#[pan, distance], Pseq([
						Pfinval(parms[\numEv] /* - 1 */, ~xyPat.(parms)),
						[#[-1, 0, 1], ~distNear]
					]),
					\delta, Pseq([parms[\delta], 0.4], 1),
					\rate, Pseq([
						Pfinval(parms[\numEv] /* - 1 */, BPStream(\slowRate).clump(3)),
						Pwhite(0.04, 0.1, 1)
					]),
					\time, Pseq([
						Pfinval(parms[\numEv] /* - 1 */, Pkey(\delta)),
						Pkey(\delta) / Pkey(\rate)
					]),
					\amp, BPStream(\amp) * -4.dbamp,
					\origShiftS, BPStream(\slowShift).clump(3),
					\shiftS, Pkey(\origShiftS) + Pseq([
						Pfinval(parms[\numEv] /* - 1 */, 0),
						Pwhite(3, 9, 1)
					]),
					\shiftE, Pkey(\origShiftS)
				) //.collect { |ev| if(ev[\shiftS][0] > ev[\origShiftS][0]) { ev.postcs } { ev } }
			};

p.autoRun = false;
p.play;

// promising
p.runGesture((
	gest: \slowStepStretch,
	numEv: 5,
	delta: Pn(0.5, 5)
));


p.gestures.keys.asArray.sort

~clock52 => p;

p.spawner.par(
	Pseq([
		Pfuncn({ Event.silent(thisThread.clock.timeToNextBeat.debug("wait")) }),
		Pbind(
			\play, { p.runGesture((gest: \decay)) },
			\delta, Pseq([0.75, 0.5, 0.75, Pwrand(#[0.25, 0.5, 0.75], #[0.2, 0.4, 0.4], inf)], 1)
		)
	])
)

p.runningNotes.keys

// stop rhythm a couple of times for this, or just drop in at will?
p.runGesture((
	gest: \lauraslide,
	notesKey: p.runningNotes.keys.choose,
	ampAdjust: 0.11,
	numEv: rrand(11, 19)
));


p.gestures.oneKlank = { |parms|
				Pbind(
					\vizPath, #[note],
					\vizKeys, Library.at(\defaultVizKeys).copy.put(3, \filtFreq),
					\instrument, Pn(\bufGrainPanKlankDist, 1),
					\delta, 0.5,
					\amp, (parms[\mainAmp] ? 1) * BPStream(\amp),
					#[filtDegree, level], BPStream(\kfreq),
					\filtFreq, Pkey(\filtDegree).collect { |deg| Mode(parms[\mode] ?? { \g }).cps(deg + 35) },
					\filtAttack, 0.01,
					\filtDecay, parms[\kdecay] ?? { BPStream(\kdecay) },
					\filtAmp, BPStream(\kamp),
					\chorusFreq, parms[\chorusFreq] ?? { Pstutter(inf, Pwhite(0.05, 0.11, inf)) },
					\chorusAmt, parms[\chorusAmt] ?? { 0.02 },
					\chorusDelay, parms[\chorusDelay] ?? { 0.03 },
					\chorusAmps, parms[\chorusAmps] ?? { [~defaultChorusAmps] },
					\harm, parms[\harm] ?? { [~defaultKlankHarm] },
					\amps, parms[\amps] ?? { [~defaultKlankAmps] },
					\decays, parms[\decays] ?? { [~defaultKlankDecays] },
					\pan, rrand(-1.0, 1.0),
					\distance, Pkey(\level).linlin(1, 6, ~distNear, ~distFar)
				)
			};

BP(\st).makeStreamForKey(\kfreq);  // reset
BP(\st).override(\kdecay, Pwhite(0.15, 0.3, 3));
// original is 4, 7, 6
BP(\st).override(\kfreq, Ptuple([Pseq([-3, 5, 2], 1) + 7, 1]));
BP(\st).runGesture((gest: \oneKlank, numEv: 2, mode: \e));

BP(\st).runGesture((gest: \klankHarmonize, numEv: 2, mode: \e));

BP(\st).chordN = 1;
BP(\st).nextLowerInt.postcs

p.unOverride(\kdecay); p.unOverride(\kfreq);
p.listVars


// Ilana solo bells?
BP(\bel).free;
\chuckIf.eval(Fact(\bells), BP, \bel, nil, Library.at(\rvbs).copy.put(\glrvbmc, topEnvironment[\cRvbMc]));
\chuckIf.eval(Fact(\bellfx), BP, \belfx, nil, (
	parentChan: BP(\bel).chan
));

p = BP(\bel);

// lowbell-specific parms
p.v.env.keys.asArray.sort.do { |key|
	var	skey = key.asString;
	if(skey.beginsWith("lowbell") and: { skey.contains("Stream").not }) {
		(key -> p[key]).postcs
	}
}; ""

p = BP(\bel);

p.lowbellfLow = Pexprand(900, 1600, inf);

p.delta = Pwhite(1, 6, inf) * 0.25;
p.sustain = Pwhite(2.5, 7.0, inf);
p.sustain = Pwhite(1.2, 3.5, inf);

p.delta.postcs

p.chan.insp

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;

MixerChannel.servers[s][20]

p.event.proto = p.event.proto.copy.put(\glrvbout, ~cRvbMc.inbus);


// Noisy stuff from torso? maybe rhythmicize - below under drones
// Melodies: Arms axial
// use Shiva basically as is
BP(#[am0, am1, am2]).free;
BP(\tc).free;

\chuckIf.eval(Fact(\armsmelVC), VC, \am, nil, Library.at(\rvbs));
\chuckIf.eval(Fact(\shimmerpad), VC, \btp, nil, (
	env: Env.adsr(0.5, 0.4, 0.8, 1.8, curve: -2),
	fenv: Env.adsr(0.5, 0.5, 0.1, 3, peakLevel: 1, bias: 1),
	// need some EQ pre-reverb
	graphInsert: { |sig|
		var	hishelf = EQSpec1.newSpec(\hishelf,
			freq: 8705, k: -6.667.dbamp, rq: 1, sr: 44100);
		sig = HPF.ar(sig, 668);
		sig = StaticEQ.eqFuncs[\hishelf].(sig, hishelf.k, hishelf.a0);
	}
).putAll(Library.at(\rvbs)));
if(BP.exists(\am0).not) { Fact(\shivaBPs).makev(Library.at(\rvbs)) };
\chuckIf.eval(PR(\thinChords), BP, \tc);
BP(\tc).finalAmp = 0.4;
BP(\tc) => VC(\btp);
\chuckIf.eval(PR(\shivaTrig), BP, \shivaTrig);
BP(#[am0, am1, am2]).do { |bp, i|
	bp.event.soundID = i;
	bp.amp = -4.dbamp;
};

BP(\shivaTrig).delta = Pwrand(#[0.5, 1, 1.5, 2], #[1, 3, 1, 2.5].normalizeSum, inf);
BP(\shivaTrig).playtc = 0.5.asPattern.coin; //true;
BP(\shivaTrig).reset; BP(\shivaTrig).v.reset;


BP(\am0).at(\node)

BP(#[am0, am1, am2]).do { |bp|
	bp.scaleRoot = 9;
	bp.root = 57;
	bp.phrases = #[
		[1, 9, 6],
		[5, 11, 10, 7, 13],
		[1, 9, 11, 8]
	];
	bp.makeStreamForKey(\degree);
};

thisProcess.interpreter.insp

Object.dependantsDictionary.keys.select(_.isKindOf(BP));

BP(\shivaTrig).dependants

Error.debug = true;


// Melodies: Arms rhythmic melody?
VC(\bmel).free;
\chuckIf.eval(Fact(\armsmelVC), VC, \bmel, nil, (
	env: { var length = NamedControl.kr(\length, 0); Env.perc(0.01, length) },
	// env: Env.adsr(0.01, 2.5, 0.05, 1.2),
	isMono: false
).putAll(Library.at(\rvbs)));
VC(\bmel).v.setArgDefaults([ffreq: 12258]);

BP(\bmel).free;
\chuckIf.eval(Fact(\bmelBP), BP, \bmel);
0 => BP(\bmel);

~clock52 => BP(\bmel);

p = BP(\bmel);

p.dur = p.simpleDur; // .asStream * 0.5;

p.dur = PR(\pwxrandn).copy.prep([
	0.5, 0.75, 1, 1.5, 2,
	Pn(0.25, { #[1, 2, 3].wchoose(#[0.45, 0.35, 0.2]) })
], #[2, 1, 0.2, 1.2, 2, 4].normalizeSum, inf).asStream * 0.5;



// Melodies: S&L duet
// Harmonies: Arms partnering
// Harmonies: Drones?

// has some promise... blip is cheap, could do chords

WrapInstr(\blipdetune, { |freq, detune, numh = 100, amp = 0.1, ffreq = 2000|
	LPF.ar(Blip.ar(freq * [1, detune], numh).sum, ffreq, amp) ! 2
}, [\freq.asSpec.copy.default_(32.midicps), \mydetune, #[20, 200, \lin, 1], \amp, \freq]);

a = n.play(WrapInstr(\blipdetune));
a.gui;

a.free;

// use oscbloop1 with these?
// combine torso low tones with formantfx!
(
PR(\abstractProcess).clone {
	~event = (eventKey: \monoSupportData);
	~alwaysReset = true;
	~fadeOutTime = 3;

	~prep = {
		~chan = MixerChannel(~collIndex, s, 2, 2, outbus: ~master);
		~event.put(\chan, ~chan);
		~event.proto = topEnvironment[\rvbEvent].proto;
		[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\receivesSignalFrom, ~chan));

		~pitchbufs = \makeWavetables.eval(8, s, 2048, 48, { |numh| 1 ! numh });

		\addRvbOut.eval(\formantfx2Dist, { |inbus, /*outbus,*/ t_trig = 0, slideTime = 1, gate = 1,
			amp = 1, fadeIn = 5, fadeOut = 5, pan = 0, wet = 1|
			var	ffreqs = NamedControl.kr(\ffreqs, Array.series(5, 400, 400)),
				amps = NamedControl.kr(\amps, 1 ! 5),
				qs = NamedControl.kr(\qs, 0.1 ! 5),
				sig = In.ar(inbus, 1), sig2,
				wetenv = Linen.kr(gate, fadeIn, 1, fadeOut, doneAction: 2);
			ffreqs = ffreqs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
			amps = amps.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
			qs = qs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
			sig2 = BBandPass.ar(sig, ffreqs, qs, amps).sum * amp;
			sig = XFade2.ar(sig, sig2, (wet * wetenv).madd(2, -1));
			Pan2.ar(sig, pan)
			// ReplaceOut.ar(outbus, sig);
		}, nil, nil, nil, ReplaceOut).add;

		~distCtl = GenericGlobalControl(\distance, nil, 10, #[5, 20]);
		~panCtl = GenericGlobalControl(\pan, nil, 0, \bipolar);
		~wetCtl = GenericGlobalControl(\wet, nil, 1);

		~notes = IdentitySet.new;
		~fmtKeys = FormantTable.keys.select { |k| k.asString.contains("tenor") }.asArray;
	};

	~freeCleanup = {
		[~chan, ~pitchbufs, ~distCtl, ~panCtl, ~wetCtl].free;
	};

	// notes
	~mode = \e;
	~degree = Pwhite(24, 33, inf);
	~freq1 = Pfunc({ |ev| Mode(ev[\mode]).cps(ev[\degree]) });
	~bufnum = Plazy({ Pkey(\freq1).cpsmidi.linlin(48, 48+(12*7),
		~pitchbufs.first.bufnum, ~pitchbufs.first.bufnum + ~pitchbufs.size - 1
	) });
	~delta = Pwhite(7.5, 15.0, inf);
	~time = Pkey(\delta) * Pwhite(1.2, 1.7, inf);
	~amp1 = 1;
	~normAmp = 1;
	~beats = Pkey(\freq1).explin(50, 1200, 1.8, 3.6);
	~envel = Env.linen(0.3, 0.4, 0.3, 1, \sqr);

	// fx
	~ffreqs = Pkey(\ffreqs) * Pexprand(0.95, 0.95.reciprocal, inf).clump(5);
	~slideTime = Pkey(\delta) * Pwhite(0.4, 0.8, inf);
	~inbus = Plazy({ Pn(~chan.inbus, inf) });
	~fxamp = 12.5.dbamp;
	~fadeIn = 0.01;
	~fadeOut = 0.01;
	~fxDelta = Pexprand(0.1, 0.9, inf); // Pexprand(1.0, 4.0, inf),
	~formant = Plazy({ Pxrand(~fmtKeys, inf) });

	~patKey = \dummy;

	~patterns = Plazy({
		Pbind(
			\protoEvent, \polySynthPlayNotifyData,
			\instrument, \oscbloop1,
			\mode, BPStream(\mode),
			\degree, BPStream(\degree),
			\freq1, BPStream(\freq1),
			\freq2, Pkey(\freq1),
			\bufnum, BPStream(\bufnum),
			\delta, BPStream(\delta),
			\time, BPStream(\time),
			\amp1, BPStream(\amp1),
			\amp2, Pkey(\amp1),
			\normAmp, BPStream(\normAmp),
			\beats, BPStream(\beats),
			\env, Pfunc({ |ev| ~envel.value(ev) })
		)
	});

	~asPattern = {
		Ppar([
			// fx
			Pbind(
				\protoEvent, Pseq([\singleSynthPlayNotifyData, Pn(\singleSynthTriggerData)]),
				\dataToViz, false,
				\isFx, true,
				\instrument, \formantfx2Dist,
				\node, Pfunc({ ~fxnode ? 0 }),
				#[ffreqs, amps, qs], Pnsym(BPStream(\formant), FormantTable),
				\ffreqs, BPStream(\ffreqs),
				\trig, 1,
				\delta, BPStream(\fxDelta),
				\sustain, inf,
				\slideTime, BPStream(\slideTime),
				\inbus, BPStream(\inbus),
				\amp, BPStream(\fxamp),
				\fadeIn, BPStream(\fadeIn),
				\fadeOut, BPStream(\fadeOut),
				\distance, ~distCtl.asMap,
				\pan, ~panCtl.asMap,
				\wet, ~wetCtl.asMap
			),
			// notes
			BPStream(\patterns) <> Pbind(
				\patKey, BPStream(\patKey),
				\protoEvent, \singleSynthPlayNotifyData
			)
		], 1)
	};

	~stopCleanup = {
		if(~notes.notEmpty) {
			~notes.do { |node| node.release(~fadeOutTime) };
		} {
			~stopFx.()
		};
	};
	~stopFx = {
		~fxnode !? {
			~fxnode.free;
			~fxnode = nil;
		};
	};

	~recvEventNotify = { |node, event|
		// var	upd;
		node.do { |n|
			switch(n.defName.asSymbol)
				{ \formantfx2Dist } {
					~fxnode !? { ~fxnode.free };
					~fxnode = n;
				}
				// default case: it's a note
				{	~notes.add(n);
					n.register;
					Updater(n, e { |obj, what|
						if(what == \n_end) {
							// upd.remove;
							obj.releaseDependants;
							~notes.remove(obj);
							if(~notes.isEmpty and: { ~isPlaying.not }) { ~stopFx.() };
						};
					});
				}
		};
	};
} => PR(\lowTonesFmt);
)

BP(\ltf).free;
PR(\lowTonesFmt).chuck(BP(\ltf), nil, Library.at(\rvbs));
0 => BP(\ltf);

BP(\ltf).fxDelta = Pwhite(0.4, 1.4, inf);
BP(\ltf).fxamp = 18.dbamp;

BP(\ltf).distCtl => VP(0);
BP(\ltf).panCtl => VP(0);

BP(\ltf).panCtl.watch.automate { SinOsc.kr(SinOsc.kr(0.05).exprange(0.07, 0.75)) };
BP(\ltf).panCtl.stopWatching.stopAuto;

BP(\ltf).delta = Pwhite(1.5, 3.0, inf);
BP(\ltf).time = Pkey(\delta) * Pwhite(2.5, 3.5, inf);

BP(\ltf).mode = \a0;
BP(\ltf).degree = (Penvir((last: 0, sideEffect: { |x| x }), Pwhite(32, 41, inf).select { |num| ~sideEffect.((num absdif: ~last) > 4, ~last = num) }) -.x Pseries(0, Pwrand(#[1, 2, 3], #[0.2, 0.4, 0.4], 5), inf).clump(5)).trace(prefix: "notes: ");

BP(\ltf).event.proto = ~rvbEvent.proto;

Pwhite(32, 41, inf) -.x Pseries(0, Pwrand(#[1, 2, 3], #[0.2, 0.4, 0.4], 3), inf).clump(3);

BP(\ltf).notes;
BP(\ltf).notes.clear;
BP(\ltf).stopFx;

BP(\ltf).envels = [
	Env.linen(0.15, 0.35, 0.5, 1, \sqr),
	Env.perc(0.005, 0.995, 1, -4)
];

BP(\ltf).envel = { ~envels.choose.postcs };

o.remove;
o = OSCresponderNode(s.addr, '/n_end', { |t, r, m| m[1].debug("node id ended") }).add;


// one long-swelling chord
p = BP(\ltf);
p.alwaysReset

p.delta = Pn(1, 1);
p.time = 36; // Pwhite(18.0, 26.0, inf);
p.envel = Env.linen(0.4, 0.2, 0.4, 1, \sqr);

u.remove;
u = Updater(BP(\ltf), { |obj, what|
	if(what == \notesEmpty) { BP(\ltf).debug("stopping").stop(0) };
});


// try noise with formants
(
PR(\lowTonesFmt).clone {
	~prep = {
		~chan = MixerChannel(~collIndex, s, 2, 2, outbus: ~master);
		~event.put(\chan, ~chan);
		~event.proto = topEnvironment[\rvbEvent].proto;
		[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\receivesSignalFrom, ~chan));

		~noisedata = Signal.fill(1024, { 1.0.rand2 });
		~noisebuf = Buffer.sendCollection(s, ~noisedata.asWavetable, 1, 0.05);

		SynthDef(\noiseSrc, { |outbus, gate = 1, normAmp = 1, time = 1, hpf = 50|
			var	sig = PinkNoise.ar(normAmp),
				env = NamedControl.kr(\env, (0 ! 24).overWrite(Env.linen(0.3, 0.4, 0.3).asArray)),
				eg = EnvGen.kr(env, gate, timeScale: time, doneAction: 2);
			sig = HPF.ar(sig, hpf);
			Out.ar(outbus, sig * eg)
		}).add;

		~distCtl = GenericGlobalControl(\distance, nil, 10, #[5, 20]);
		~panCtl = GenericGlobalControl(\pan, nil, 0, \bipolar);
		~wetCtl = GenericGlobalControl(\wet, nil, 1);

		~notes = IdentitySet.new;
		~fmtKeys = FormantTable.keys.select { |k| k.asString.contains("tenor") }.asArray;
	};
	// notes
	~delta = Pwhite(7.5, 15.0, inf);
	~time = Pkey(\delta) * Pwhite(1.2, 1.7, inf);
	~envel = Env.linen(0.3, 0.4, 0.3, 1, \sqr);

	~freq1 = Pexprand(80.0, 250.0, inf);
	~noiseSlideProb = 0.35;
	~freq2 = Pkey(\freq1) * Pif(Pfunc({ ~noiseSlideProb.coin }),
		Pexprand(0.75, 1.33, inf), 1);
	~fHoldPct = Pwhite(0.35, 0.7, inf);
	~fcurve = Pwhite(2.7, 4.5, inf) * (Pkey(\freq2) - Pkey(\freq1)).sign;
	~preamp = 9;
	~normAmp = 7.dbamp;
	~noiseenv = Env.linen(0.2, sustainTime: 0.45, releaseTime: 0.35);
	~hpf = 50;

	~patKey = Penvir((last: nil ! 2, i: Pseq(#[0, 1], inf).asStream),
		Pif(
			Pfunc({ ~last.includes(\noiseSrc) }),
			\oscbloop1,
			Pwrand(#[oscbloop1, noiseSrc], #[0.8, 0.2], inf)
		).collect { |name| ~last[~i.next] = name; name }
	);

	~patterns = Plazy({
		Psym1(Pkey(\patKey), (
			noiseSrc: Pbind(
				// \protoEvent, \polySynthPlayNotifyData,
				\instrument, \noiseSrc,
				\delta, BPStream(\delta),
				\time, BPStream(\time),
				\normAmp, BPStream(\normAmp),
				\hpf, BPStream(\hpf),
				\env, Pfunc({ |ev| ~envel.value(ev) })
			),
			oscbloop1: Pbind(
				\bufnum, ~noisebuf,
				\instrument, \oscbloop1,
				\freq1, BPStream(\freq1),
				\freq2, BPStream(\freq2),
				\fcurve, BPStream(\fcurve),
				\fHoldPct, BPStream(\fHoldPct),
				\delta, BPStream(\delta),
				\time, BPStream(\time),
				\amp1, BPStream(\preamp),
				\amp2, Pkey(\amp1),
				\normAmp, BPStream(\normAmp),
				\env, Pfunc({ |ev| ~envel.value(ev) })
			)
		))
	});
} => PR(\noiseFmt);
)

BP(\nf).free;
PR(\noiseFmt).chuck(BP(\nf), nil, Library.at(\rvbs));
0 => BP(\nf);

p = BP(\nf);

p.delta = Pwhite(1, 4, inf) * 0.25;
p.time = max(0.4, Pkey(\delta) * Pexprand(0.7, 2.5, inf));
p.normAmp = 12.dbamp;
p.envel = Env.perc(0.01, 0.99);

p.noiseSlideProb = 0.35;
p.noiseSlideProb = 0;
p.freq1 = Pexprand(180.0, 500.0, inf);
p.freq1 = Pwhite(37, 51, inf).collect { |x| Mode(\a0).cps(x) };

p.fxDelta = Pwhite(0.4, 1.4, inf);

p.event.debug = false;
p.event.trace = true;


p.patKey = Penvir((last: nil ! 2, i: Pseq(#[0, 1], inf).asStream),
		Pif(
			Pfunc({ ~last.includes(\noiseSrc) }),
			\oscbloop1,
			Pwrand(#[oscbloop1, noiseSrc], #[0.5, 0.5], inf)
		).collect { |name| ~last[~i.next] = name; name }
).trace(prefix: "patkey: ");

// slower works much better with noiseSrc
p.delta = Pwhite(1.0, 3.0, inf);
p.time = Pkey(\delta) * Pwhite(1.4, 2.5, inf);
p.envel = Env.linen(0.3, 0.4, 0.3, 1, \sqr);
p.patKey = \noiseSrc;

BP(\nf).distCtl => VP(0);
BP(\nf).panCtl => VP(0);
BP(\nf).wetCtl => VP(0);

g = GenericGlobalControl(\hpf, nil, 50, \freq);
g => VP(0);

p.hpf = g.asMap;

g.watch.automate { XLine.kr(7500, 150, 40, doneAction: 2) };

// come down and up faster
g.watch.automate { EnvGen.kr(Env(#[7500, 150, 3000], #[40, 30], \exp), doneAction: 2) };
p.patKey = Pswitch1(#[noiseSrc, oscbloop1],
	(Pwhite(0, 0.999999, inf) + Env(#[0, 0, 1], #[15, 60]).asStream).trunc
).trace(prefix: "patKey: ");

p.fxDelta = Pwhite(1, 4, inf) * 0.25;
p.slideTime = 0.12;

p.fxnode.trace

p.v[\asPattern].postcs
p.listVars

e = p.use { ~patternsStream.next(~event.copy.put(\patKey, \oscbloop1)) };
e = p.use { ~patternsStream.next(~event.copy.put(\patKey, \noiseSrc)) };

// Harmonies: Torso held notes


// contrasting
// reuse 3 poses, decay
// almost, but I want faster material
\chuckIf.eval(PR(\trajectories), BP, \traj);
\chuckIf.eval(Fact(\opening), BP, \op, nil, Library.at(\rvbs));
\chuckIf.eval(Fact(\openingSteps), BP, \st, nil, Library.at(\rvbs));

\chuckIf.eval(Fact(\waterpad), VC, \wp, nil, Library.at(\rvbs));
\chuckIf.eval(PR(\leaning), BP, \ln);
VC(\wp) => BP(\ln);
0 => BP(\ln);


(
t.stop;
t = TLSequenceIterator([
	{ BP(\st).autoRun = false; 0.05 },
	// 0.05,
	bpCmd: (name: \ln, prepareBP: { |bp|
		bp.selector = Pseq([Pn(0, { rrand(2, 7) }), 1], inf);
		bp.delta = Pwhite(0.4, 0.8, inf) * Pseq(#[1, 2.1], inf)
			* Env(#[1, 6], #[40], \exp);
	}),
	{ rrand(3.0, 6.0) },
	bpCmd: (name: \st, quant: 0, shouldSync: false, playWarning: false, prepareBP: { |bp|
		bp.gest = \decay;
		bp[\origAmp] ?? { bp[\origAmp] = bp.amp };
		bp.amp = bp.origAmp * 10.dbamp;
		bp.gDelta = Pwhite(1.5, 3.5, inf);
	}),
	funcCmd: (
		setDoneSignal: {
			~doneSignal = Updater(BP(\st), e { |bp, what|
				if(what == \play) {
					~stop.();
				}
			});
		},
		clearDoneSignal: { ~doneSignal.remove }
	),
	\cmdSync,
	0.5,
	{ BP(\st).addAutoRun; rrand(4.0, 9.0) },
	{
		BP(\st).kdecay = Pwhite(0.15, 0.3, inf);
		BP(\st).makeStreamForKey(\kfreq);
		0
	},
	loopCmd: (
		id: \poses,
		deltaStream: Pseq([
			Pwhite(0.8, 3.0, Pseq([2, Pwhite(2, 7, inf)]).asStream),
			Pwhite(4.5, 8.0, 1)
		], inf).trace.asStream,
		cmds: [
			{	BP(\st).runGesture((gest: \oneKlank, numEv: 2));
				~deltaStream.next // rrand(1.5, 2.5)
			}
		]
	),
	40,
	funcCmd: (
		func: {
			BP(#[st, ln]).stop(0);
			~iterator.findActive(\poses).stop
		}
	),
	{ "done".postln; 0 }
]).play(argClock: ~clock52);
)

BP(\st).amp.postcs

BP(\st).kfreqStream.next




// faster bass material
\chuckIf.eval(Fact(\armsChordVC), VC, \ac, nil, (isMono: true).putAll(Library.at(\rvbs)));
\chuckIf.eval(PR(\bassline), BP, \bss);
VC(\ac) => BP(\bss);
~clock52 => BP(\bss);

BP(\bss).calcBar = \makeBassNotes;

BP(\bss).mode = \f;
BP(\bss).mode = \d;

BP(\bss).runPool = [
	Ptuple([Pseq(#[1, 2, 1, 1, 1, 2]), Pwrand(#[1, 2], #[0.7, 0.3], inf)]),
	Ptuple([Pseq(#[-1, -2, -1, 1, 2, 1, 2, 1]), Pwrand(#[1, 2], #[0.7, 0.3], inf)]),
	Ptuple([
		Pwrand(#[1, 2], #[0.7, 0.3], { rrand(3, 7) })
			* Pstutter(Pwhite(1, 3, inf), Pseq(#[-1, 1], inf, { 2.rand })),
		Pwrand(#[1, 2], #[0.75, 0.25], inf)
	]),
	Ptuple([
		Pstutter(2, Pxrand(#[1, 2, 3, 4], { rrand(2, 4) }))
			* Pseq(#[1, -1], inf),
		Pseq(#[1, 2], inf)
	])
];

BP(\bss).contrastingModes = Mode.keys.select { |key| key.asString.right(2) == "b0" };
BP(\bss).mode = Pclutch(Pfunc({ ~contrastingModes.choose }), Pdiff(Pkey(\barCount)) > 0).collect { |mode| ~lastMode = mode };

(
{	var arrivalPitches, arrivalTimes,
		avail = \scrambleDistrib.eval((4, 8 .. 31)),
		run, intervalSum, timeSince, last;

	#arrivalPitches, arrivalTimes = (rrand(2, 4) * ~densityCtl.value * 0.2)
	.round.asInteger.collect { |i|
		[rrand(20, 26), avail[i]]
	}.sort { |a, b| a[1] < b[1] }.flop;

	// ~mode = ~contrastingModes.choose;

	~freqs = [rrand(23, 26), rrand(-5, -2), -1].integrate;
	// ~amps = [~ampBase.copy, 0].lace(~ampBase.size * 2);
	~durs = Pseries(0, Pwrand(#[0.25, 0.5, 0.75], #[0.1, 0.45, 0.45], 3), 3).asStream.all;
	~amps = (0 ! 32).putEach(~durs * 8, 1);
	~lengths = (0.22 ! 3); // ~lengthBase.copy;
	~gates = 0.8 ! 3;
	\expandKeys.eval;

// ~durs.debug("\nexpandkeys");

	~freqs.putEach(arrivalTimes, arrivalPitches);
	~amps.putEach(arrivalTimes, 1);
	~durs.putEach(arrivalTimes, arrivalTimes);
	~lengths.putEach(arrivalTimes, 0.25);
	~gates.putEach(arrivalTimes, 0.8);

	arrivalTimes.do { |time, i|
		timeSince = time - (arrivalTimes[i-1] ? 0);
// [time, (arrivalTimes[i-1] ? 0), timeSince].debug("timeSince");
		run = #[[0, 0]] ++ (Pwhile1({ |in, next|
			timeSince = timeSince - next[1];
			timeSince > 0
		}, ~runPool.choose).asStream.all);
// run.debug("pre-integrate");
		run = run.integrate.flop;
		// now run[0].last is the offset for the ending pitch
		// and run[1] holds the timepoints
		run[0] = run[0] + arrivalPitches[i] - run[0].last;
		run[1] = run[1] + arrivalTimes[i] - run[1].last;
// run[1].debug("timepoints");
// if(run[1][0] <= (arrivalTimes[i-1] ? 0)) {
// 	"OMG FAIL FAIL FAIL".die;
// };
		~freqs.putEach(run[1], run[0]);
		~durs.putEach(run[1], run[1] * 0.125);
// ~durs.debug("put gesture");
		~amps.putEach(run[1], 1);
		~gates.putEach(run[1].drop(-1), exprand(0.4, 0.75));
		~lengths.putEach(run[1], 0.14);
	};

	last = ~lengths.size;
	~lengths.reverseDo { |len, i|
		if(len > 0) {
			i = 31-i;
			case
				// if next is accented, make sure this note is not legato
				{ ~gates[last] == 0.8 } {
					~lengths[i] = min(~lengths[i], (last - i) * 0.125 - 0.04);
				}
				// randomly throw in some long notes
				{ 0.12.coin } {
					~lengths[i] = min(1.25, (last - i) * 0.125 - 0.02);
				};
			last = i;
		};
	};

	\shrinkKeys.eval;
//~durs.debug("durs");
} => Func(\fasterBassNotes);
)

BP(\bss).use { \fasterBassNotes.eval };

BP(\bss).calcBar = \fasterBassNotes;

BP(\bss).lengths

BP(\bss).densityCtl => VP(0);

Error.debug = true;

(
{	|array, distrib(Env(#[0, 1], #[1], -4))|
	var j, temp;

	do(array.size-1) { |i|
		j = (distrib.at(1.0.rand) * (array.size - i) + i).asInteger;
		if(j > i) {
			temp = array[j];
			forBy(j-1, i, -1) { |k| array[k+1] = array[k] };
			array[i] = temp;
		};
	};
	array
} => Func(\scrambleDistrib);
)

VC(\ac).v.nodes[0].defname
BP(\bss).mod_lev = Pkey(\gate).linexp(0.1, 0.8, 2.2, 5.3);

BP(\bss).leadTime = 0.02;

// some scraps for roll args below
		// \distNear, ,
		// \distFar, ,
		// \glrvbout, ,
		// \lcrvbout, ,
		// \glrvbamt, ,
		// \lcrvbamt, ,
		// \attNearFreq, ,
		// \attFarFreq, ,
		// \attNearDb, ,
		// \attFarDb, ,
		// \attNearRs, ,
		// \attFarRs, ,
		// \attack, ,
		// \decay, ,


// add rolls into hdr
BP(\hdr).free;
\chuckIf.eval(Fact(\hidrum), BP, \hdr);
p = BP(\hdr);

p.useGui = { |vpi|
	[~densityCtl, ~runProbCtl, ~rollProbCtl].do { |gc| gc => VP(vpi) };
};


\addMovingRvbOut.eval(\bufRollPanDist, { |start, time = 1, bufnum, rate = 1, amp = 1,
		strokeRateStart = 18, strokeRateEnd = 18,
		attack = 0.002, decay = 0.01,	// attack and decay of individual stroke
		pan = 0, panEnd = 0, outbus|
	SynthDescLib.at(\bufRollPanChangeRate).def.func.value(start, time, bufnum, rate, amp, strokeRateStart, strokeRateEnd, attack, decay, pan, panEnd, outbus)
}).add;

// p.argPairs = [pan: Plazy({ Pseq(~pans, 1) })];
BP(\hdr).argPairs = [pan: Plazy({ ~makePattern.(\pans, 1) })];

p.addArgs = Psym1(Pkey(\instrument), (
	rest: Pfunc({ |ev| ev }),  // no-op, but don't return nil
	bufGrainPanFiltDist: Pbind(
		\distance, Plazy({ Pn(~distanceCtl.asMap, inf) }),
		\ffreq, 18000,
		\ampMap, Plazy({ Pn(~ampCtl.asMap, inf) })
	),
	bufRollPanDist: Plazy({ Pbind(
		\distance1, BPStream(\rolld1),
		\distance2, BPStream(\rolld2),
		\moveTime, BPStream(\rollMoveTime),
		\strokeRateStart, BPStream(\rollStroke1),
		\strokeRateEnd, BPStream(\rollStroke2),
		\pan, BPStream(\rollPan1),
		\panEnd, BPStream(\rollPan2),
		\env, BPStream(\rollEnv)
	) })
));

p.use {
	~rolld1 = Plazy({ Pn(~distanceCtl.asMap, inf) });
	~rolld2 = Pkey(\distance1);
	~rollMoveTime = Pkey(\time);
	~rollStroke1 = Pwhite(12.5, 18.0, inf);
	~rollStroke2 = Pkey(\strokeRateStart) * Pwhite(0.15, 0.35, inf);
	~rollPan1 = Pkey(\pan);
	~rollPan2 = Pwhite(0.84, 1.0, inf) * Pkey(\pan).sign.neg;
	~rollDefaultEnv = Env(#[0, 1, 0], #[0.001, 0.999], -4);
	~rollEnv = Pfunc({ ~rollDefaultEnv });
};

// SynthDescLib.at(\bufRollPanDist).controlNames.do(_.postln); ""

p.asPattern = {
	var	out;
	~prepareForPlay.value;	// one use is streams that must persist past 1 bar
	PnNilSafe(Plazy(e {
		~doPreAction.value;
		out = ~makePbindArray.value;
		out = ~addArgPairs.(out);
		// out = ~doPostAction.(out) ? out;	// do postprocessing on pbind pairs
		~addArgs <> Pbind(*out);
	}), inf);
};


// what's the musical gesture?
// some running 64ths
// some rolls (where?)

p.divCycle = 1/16;  // 64ths
p.usedKeys = #[bufs, pans, def, times];

{	var	acc = ~accentOptions.choose * 2, avail,
		num, ampPat, panPat, runsDone = List.new.add(64), nextRun;
// thisThread.beats.debug("hidrumrollgen ran at");
	~amps = [~ampBase, 0].lace(~ampBase.size * 2);
	~bufs = ~amps.copy;
	~pans = ~amps.copy;
	~def = \bufGrainPanFiltDist ! ~amps.size;
	~times = ~amps.copy;
	avail = (0, 2 .. ~amps.size-1);
	acc.do { |i|
		~amps[i] = 1;
		~bufs[i] = ~buffers.size.rand;
		~pans[i] = 0;
		~times[i] = ~bufTimes[~bufs[i]] * ~clock.tempo;
		avail.take(i);
	};
	// avail = avail.scramble;
	block { |break|
		(~densityCtl.value + 7.rand).do { |i|
			if(avail.isEmpty) { break.() };
			i = avail.takeAt(avail.size.rand);
			nextRun = runsDone.select(_ > i).minItem;
			num = min(nextRun - i, ~runNumStream.next);
			if(~runProbCtl.coin) {
				if(~rollProbCtl.coin) {
					~def[i] = \bufRollPanDist;
					~times[i] = num * ~divCycle;
					~bufs[i] = ~buffers.size.rand;
					~amps[i] = 1;
					~pans[i] = 0.7.rand2;
					(i .. i+num-1).do { |j|
						avail.take(j);
					};
				} {
					ampPat = Pgeom.fromEndpoints(1, rrand(0.02, 0.08), num).asStream;
					panPat = Pseries.fromEndpoints(0.7.rand2, 0.7.rand2, num).asStream;
					(i .. i+num-1).do { |j|
						~amps[j] = ampPat.next * (0.75.coin.binaryValue);
						~pans[j] = panPat.next;
						~bufs[j] = ~buffers.size.rand;
						~times[j] = ~bufTimes[~bufs[i]] * ~clock.tempo;
						avail.take(j);
					};
				};
				runsDone.add(i);
			} {
				~amps[i] = exprand(0.3, 0.8);
				~bufs[i] = ~buffers.size.rand;
				~pans[i] = 0.7.rand2;
				~times[i] = ~bufTimes[~bufs[i]] * ~clock.tempo;
			};
		};
	};
	\shrinkKeys.eval;
} => Func(\hidrumrollgen);

p.pbindPreAction = \hidrumrollgen;
p.runNum = Pwhite(4, 10, inf);
p.runNumStream.next;

p.rollStroke1 = Pwhite(35.0, 60.0, inf);
p.rollStroke2 = Pkey(\strokeRateStart) * Pwhite(0.04, 0.08, inf);
p.rollDefaultEnv = Env(#[0, 1, 0], #[0.01, 0.99], -9);

p.rollDefaultEnv.plot;

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;

p.event.grain = false;

Error.debug = true;
Error.debug = false;

p.v.env.keysValuesDo { |k, v| if(v.isKindOf(GlobalControlBase)) { k.postln } }; ""
ampCtl
densityCtl
distanceCtl

p.densityCtl => VP(0);

p.rollProbCtl = GenericGlobalControl(\rollProb, nil, 0.05);
p.runProbCtl = GenericGlobalControl(\runProb, nil, 0.05);
p.rollProbCtl => VP(0);
p.runProbCtl => VP(0);
p.freeCleanup = { [~rollProbCtl, ~runProbCtl].free } <> p[\freeCleanup];

p.pans


p.divCycle = 1/16;  // 64ths
p.usedKeys = #[bufs, pans, def, times];
p.pbindPreAction = \hidrumrollgen;

p.divCycle = 1/8;  // 32nds
p.usedKeys = #[bufs, pans];
p.pbindPreAction = \hidrumgen;


p.amps.size


// low drum mangling
BP(\ldr).free;
\chuckIf.eval(Fact(\lowdrum), BP, \ldr);

p = BP(\ldr);
p.listVars;

{	|shrink(true)|
	var avail;
// thisThread.beats.debug("ldrFasterGen ran at");
	~amps = ~ampBase.copy.put(3, 0.98);
	avail = \getRests.eval.scramble * 2;
	~amps = [~amps, 0].lace(32);
	~times = (0 ! 32).put(0, 0.4).put(6, 0.2);
	rrand(3, 9).do { |i|
		if(0.1.coin and: { avail[i] % 4 == 0 }) {
			~amps[avail[i]] = 1;
			~times[avail[i]] = 0.4;
		} {
			~amps[avail[i]] = exprand(0.3, 0.8);
			~times[avail[i]] = exprand(0.06, 0.12);
			if(0.6.coin) {
				~amps[avail[i] + 1] = ~amps[avail[i]] * 0.65;
				~times[avail[i] + 1] = exprand(0.06, 0.12);
			};
		};
	};
	// ~argPairs = ~origArgPairs.copy.put(1, playBar.not.binaryValue);
	if(shrink) { \shrinkKeys.eval };
} => Func(\ldrFasterGen);

p.pbindPreAction = \ldrFasterGen;
p.divCycle = 0.125;

p.argPairs = [
	numPoly: Pwhite(1, 4, inf),
	freq: Pif(Pkey(\amp) >= 1,
		40.midicps * Pif(Pfunc({ ~clock.beatInBar == 0 }), 1, Pwhite(2, 9, inf).degreeToKey(#[0, 2, 3, 5, 7, 9, 10], 12).midiratio),
		50.midicps
			* Pn(Pseries(0, Pwrand(#[1, 2, 3], #[0.2, 0.5, 0.3], inf), Pkey(\numPoly).asStream)
			.degreeToKey(#[0, 2, 4, 5, 7, 9, 11], 12).midiratio.clump(Pkey(\numPoly)), inf)
	) * Pfunc({
		if(BP.exists(\bss).not or: { BP(\bss).v[\lastMode].isNil }) {
			1
		} {
			// crap, most of the contrasting modes are 0-transposed
			// so root is always 0 despite pitch class content
			// dodgy workaround in 3... 2... 1...
			(BP(\bss).lastMode.asString.reject(_.isDecDigit).asSymbol.asMode.root - 2).midiratio
		}
	}),
	freqenv: Pif(Pkey(\amp) >= 1, Pfunc({ ~slideEnv }), Pwrand([`(Env.one), Pfuncn({ Env([1, rrand(1.25, 1.5)], #[0.05], 6) })], #[0.95, 0.05], inf)),
	preamp: 4.23,
	distance: Plazy({ Pn(~distanceCtl.asMap, inf) }),
	ampMap: Plazy({ Pn(~ampCtl.asMap, inf) })
//,	debugDummy: Pfunc({ |ev| ev.postcs })
];

Pwhite(2, 9, inf).trace(prefix: "in: ").degreeToKey(#[0, 2, 3, 5, 7, 9, 10], 12).trace(prefix: "\tout: ").asStream.nextN(5)

p.reset;
p.clock.sched(0, { p.eventStream.next(p.event.copy).keysValuesDo { |k, v| [k, v].postln } });

p.event.eventKey = \polySynthPlayerData;

p.event.debug = false;
p.debug = true;

p.slideEnv.value.postcs

{	var	clearStart;
	\ldrFasterGen.eval(false);
	// clear some
	((clearStart = rrand(0, 22)) .. min(clearStart + rrand(10, 16), ~amps.size-1)).do { |i|
		~amps[i] = 0;
	};
	\shrinkKeys.eval;
} => Func(\ldrFasterGenPartBar);

BP(\ldr).divCycle
BP(\ldr).pbindPreAction = \ldrFasterGenPartBar;


{	var	clearStart;
	\hidrumrollgen.eval(false);
	// clear some
	((clearStart = rrand(0, 22) * 2) .. min(clearStart + rrand(20, 32), ~amps.size-1)).do { |i|
		~amps[i] = 0;
	};
	\shrinkKeys.eval;
} => Func(\hdrFasterGenPartBar);

BP(\hdr).pbindPreAction = \hdrFasterGenPartBar;

BP(\ldr).leadTime = 0.01;

(1..4).reciprocal.normalizeSum

{	var	starts = Pwhile1({ |in, next| next < 8 }, Pseries(#[0, 1, 2, 3].wchoose(#[0.48, 0.24, 0.16, 0.12]), Pwhite(3, 5, inf), inf)) * 4;
// thisThread.beats.debug("ldrAccents ran at");
	~amps = 0 ! 32;
	~times = 0 ! 32;
	starts.do { |i|
		min(rrand(2, 5), (32 - i) div: 3).do { |j|
			~amps.overWrite(#[0.99, 0, 0], pos: i + (3*j));
			~times[i + (3*j)] = 0.1;
		}
	};
	if(~amps[0] > 0) {
		~amps[0] = 1;
		~times[0] = 0.4;
	};
	\shrinkKeys.eval;
} => Func(\ldrAccents);

BP(\ldr).pbindPreAction = \ldrAccents;

{	var count, panStrm = Pseq(#[-1, 1], inf).asStream;
// thisThread.beats.debug("hdrAccents ran at");
	~amps = BP(\ldr).amps;
	count = ~amps.count(_ > 0);
	~bufs = { ~buffers.size.rand } ! count;
	~pans = { 1.0.rand2 } ! count;
	~def = Pwrand(#[bufGrainPanFiltDist, bufRollPanDist], #[0.66, 0.44], count).asStream.all;
	~rates = 1 ! count;
	~times = ~def.collect { |def, i|
		if(def == \bufGrainPanFiltDist) {
			~bufTimes[~bufs[i]]
		} {
			0.32  // 3/32 between notes == 0.375 beats, little gap
		} * ~clock.tempo;
	};
	\expandKeys.eval;
	(0, 4 .. 31).do { |i|
		if(~amps[i] == 0) {
			~amps[i] = 0.5;
			~bufs[i] = ~buffers.size.rand;
			~pans[i] = panStrm.next;
			~def[i] = \bufGrainPanFiltDist;
			~times[i] = ~bufTimes[~bufs[i]];
		};
		~rates[i] = 1.25;
	};
	\shrinkKeys.eval;
} => Func(\hdrAccents);

BP(\hdr).usedKeys = #[bufs, pans, def, times, rates];

BP(\hdr).pbindPreAction = \hdrAccents;
BP(\hdr).divCycle = 0.125;

BP.all.do(_.reset);

BP(\ldr).divCycle;


// with 3/32 bits, single bass notes + LPC chords

{
	~amps = 0 ! 32;
	~freqs = 0 ! 32;
	~lengths = 0 ! 32;
	~gates = 0 ! 32;

	Ppatlace([Place(#[[0.6, 0.5, 0.5, 0.5], 0.1], 4), 0, 0, 0], 8).coin.do { |addNote, i|
		if(addNote) {
			~amps[i] = 1;
			~freqs[i] = rrand(19, 27);
			~lengths[i] = 0.2;
			~gates[i] = 0.8;
		}
	};

	if(~amps.count(_ > 0) == 0) {
		~amps[0] = 1;
		~freqs[0] = rrand(19, 27);
		~lengths[0] = 0.2;
		~gates[0] = 0.8;
	};

	\shrinkKeys.eval;
	~durs = ~amps.collectIndices(_ > 0) * 0.125;
} => Func(\singleBassNotes);

BP(\bss).calcBar = \singleBassNotes;

BP(\bss).use { ~calcBar.eval };


BP(\sw).free;
\chuckIf.eval(Fact(\words), BP, \sw, nil, Library.at(\rvbs));
~clock52 => BP(\sw);
p = BP(\sw);

4 => p;
p.pfreq = (Paccumbounce(39, 50,
	Pwrand(#[-2, -1, 1, 2], #[0.2, 0.2, 0.3, 0.3], inf), inf)
	-.x Pseries(0, Pwhite(1, 4, 3))
).clump(3)
.collect { |deg, ev| Mode(ev[\mode]).cps(deg) };
p.pitchedmode = Pfunc({ BP(\bss).v[\lastMode] ? \d });
p.synth = \pitched;
p.pitcheddelta = PnNilSafe(Plazy({
	var	d = BP(\bss).durs;
	if(d.isEmpty) {
		Pn(4, 1)
	} {
		Pdelta(Pseq(d ++ #[4], 1), 4)
	}
}), inf);
p.pitchedtime = Pexprand(0.6, 1.0, inf);
p.preamp = 9;
p.pitchednormAmp = 5;
p.isFading = false;

// fairly interesting with mode changes
// chord is too wishywashy
// needs pulse - use hdr

BP.all.do(_.reset)

BP(\bss).leadTime = 0.2;
BP(\sw).quant = #[4, -0.15];




BP(\sw).asPattern = {
	~basePattern.value.collect({ |ev|
		if(ev[\synthKey] != \rest) {
			~getUserArgs.(ev);
		};
		~lastEvent = ev;
		ev
	});
};

BP(\sw).lastEvent

// too lazy to adapt something
(
PR(\abstractProcess).clone {
	// this proc leeches off the raw Hz from \sw
	~event = (eventKey: \voicerNote, midiNoteToFreq: { |x| x },
		// but, stupid crappy voicerNote event will try to modally map the Hz
		// if I don't lie to it like this
		midi: true
	);
	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto.copy
			.put(\glrvbout, topEnvironment[\cRvbMc].inbus.index);
		~glrvbamtCtl = GenericGlobalControl(\glrvbamt, nil, 0.15);
	};
	~freeCleanup = {
		~glrvbamtCtl.free;
	};
	~fsrc = \sw;
	~dsrc = \bss;
	~freq = Pfunc({ BP(~fsrc).lastEvent[\freq1] ? #[] });
	~dur = Pfunc({ BP(~fsrc).lastEvent[\delta] });
	~length = Pfunc({ BP(~fsrc).lastEvent[\length] ? 1 });
	~gate = Pfunc({ BP(~fsrc).lastEvent[\gate] ? 0.5 });
	~mod_lev = 9;
	~mod_ratio = 1;
	~distance = 5;
	~amp = 0.2;
	~glrvbamt = Plazy({ Pn(~glrvbamtCtl.asMap, inf) }); // 0.1;
	~asPattern = {
		// PnNilSafe(Plazy({
			Pbind(
				\freq, BPStream(\freq),
				\dur, BPStream(\dur), // Pdelta(Pseq(BP(~dsrc).durs ++ #[4], 1), 4),
				\length, BPStream(\length), // Pseq(BP(~dsrc).lengths, 1),
				\gate, BPStream(\gate), // Pseq(BP(~dsrc).gates, 1),
				\mod_lev, BPStream(\mod_lev),
				\mod_ratio, BPStream(\mod_ratio),
				\attackTimeScale, 0.1,
				\decayTimeScale, 0.5,
				\distance, BPStream(\distance), // ~distanceCtl.asMap,
				\glrvbamt, BPStream(\glrvbamt),
				\finalAmp, BPStream(\amp) // ~ampCtl.asMap
			)
		// }), inf)
	};
} => PR(\chordAcc);
)

\chuckIf.eval(Fact(\armsChordVC), VC, \ac2, nil, Library.at(\rvbs));

BP(\ac2).free;
PR(\chordAcc) => BP(\ac2);
VC(\ac2) => BP(\ac2);
4 => BP(\ac2);
~clock52 => BP(\ac2);

BP(#[bss, ac2, sw]).do { |bp| bp.quant.wrap = true };

Error.debug = true;
Error.debug = false;

// oh my fucking GOD
BP(\ac2).event.midi = true;
BP(\ac2).dur = Pfunc({ BP(~fsrc).lastEvent[\delta] });
BP(\ac2).length = Pexprand(0.15, 0.3, inf);

BP(\ac2).event.glrvbamt = 0.35;
BP(\ac2).event.glrvbout = ~cRvbMc.inbus.index;
PeakMonitor(~cRvbMc)

BP(\ac2).glrvbamt = Env(#[0.15, 0.35], #[60]);



// prototype
\chuckIf.eval(Fact(\armsChordVC), VC, \ac, nil, (isMono: true).putAll(Library.at(\rvbs)));
\chuckIf.eval(PR(\bassline), BP, \bss);
VC(\ac) => BP(\bss);
~clock52 => BP(\bss);
BP(\bss).leadTime = 0.2;

BP(\hdr).free;
\chuckIf.eval(Fact(\hidrum), BP, \hdr);
~clock52 => BP(\hdr);

BP(\ldr).free;
\chuckIf.eval(Fact(\lowdrum), BP, \ldr);
if(BP(\ldr).v[\origArgPairs].isNil) {
	BP(\ldr).origArgPairs = BP(\ldr).argPairs;
};
BP(\ldr).leadTime = 0.01;
~clock52 => BP(\ldr);

BP(\sw).free;
\chuckIf.eval(Fact(\words), BP, \sw, nil, Library.at(\rvbs));
~clock52 => BP(\sw);
BP(\sw).quant = #[4, -0.15];
BP(\sw).v[\asPattern] = {
	~basePattern.value.collect({ |ev|
		if(ev[\synthKey] != \rest) {
			~getUserArgs.(ev);
		};
		~lastEvent = ev;
		ev
	});
};

\chuckIf.eval(Fact(\armsChordVC), VC, \ac2, nil, Library.at(\rvbs));
BP(\ac2).free;
PR(\chordAcc) => BP(\ac2);
VC(\ac2) => BP(\ac2);
4 => BP(\ac2);
~clock52 => BP(\ac2);


(
t.stop;
BP.all.do(_.reset);
t = TLSequenceIterator([
	Quant(4, -0.5),
// { thisThread.beats.debug("what the fuck time is it when we start"); 0 },
	bpCmd: (name: \ldr, quant: 4, prepareBP: { |bp|
		bp.pbindPreAction = \ldrFasterGen;
		// bp.densityCtl.value = 1;
		bp.divCycle = 0.125;
		bp.argPairs = [
			numPoly: Pwhite(1, 4, inf),
			freq: Pif(Pkey(\amp) >= 1,
				40.midicps * Pif(Pfunc({ ~clock.beatInBar == 0 }), 1, Pwhite(2, 9, inf).degreeToKey(#[0, 2, 3, 5, 7, 9, 10], 12).midiratio),
				50.midicps
				* Pn(Pseries(0, Pwrand(#[1, 2, 3], #[0.2, 0.5, 0.3], inf), Pkey(\numPoly).asStream)
					.degreeToKey(#[0, 2, 4, 5, 7, 9, 11], 12).midiratio.clump(Pkey(\numPoly)), inf)
			) * Pfunc({
				if(BP.exists(\bss).not or: { BP(\bss).v[\lastMode].isNil }) {
					1
				} {
					// crap, most of the contrasting modes are 0-transposed
					// so root is always 0 despite pitch class content
					// dodgy workaround in 3... 2... 1...
					(BP(\bss).lastMode.asString.reject(_.isDecDigit).asSymbol.asMode.root - 2).midiratio
				}
			}),
			freqenv: Pif(Pkey(\amp) >= 1, Pfunc({ ~slideEnv }), Pwrand([`(Env.one), Pfuncn({ Env([1, rrand(1.25, 1.5)], #[0.05], 6) })], #[0.8, 0.2], inf)),
			preamp: 4.23,
			distance: Plazy({ Pn(~distanceCtl.asMap, inf) }),
			ampMap: Plazy({ Pn(~ampCtl.asMap, inf) })
		];
		bp.distanceCtl.value = 5;
	}),
	bpCmd: (name: \hdr, quant: 4, prepareBP: { |bp|
		bp.pbindPreAction = \hidrumrollgen;
		bp.densityCtl.value = 2;
		bp.runProbCtl.value = 0.05;
		bp.rollProbCtl.value = 0.05;
		bp.divCycle = 1/16;  // 64ths
		bp.usedKeys = #[bufs, pans, def, times];
		bp.distanceCtl.value = 5;
	}),
	bpCmd: (name: \bss, quant: 4, prepareBP: { |bp|
		bp.calcBar = \fasterBassNotes;
		bp.densityCtl.value = 1;
		bp.mod_lev = Pkey(\gate).linexp(0.1, 0.8, 2.2, 5.3);
	}),
	8,

	// up the density

	// gcAutoSynthCmd: (gc: BP(\ldr).densityCtl, name: \ctlPoint, outName: \outbus,
	// 	value: , time: ),
	{
		PR(\gcAutoSynthCmd).copy.putAll((
			gc: BP(\hdr).densityCtl, name: \ctlPoint, outName: \outbus,
			value: 10.1, time: 32 / thisThread.clock.tempo
		))
	},
	{
		BP(\hdr).rollProbCtl.value = 0.25;
		PR(\gcAutoSynthCmd).copy.putAll((
			gc: BP(\hdr).runProbCtl, name: \ctlPoint, outName: \outbus,
			value: 0.6, time: 16 / thisThread.clock.tempo
		))
	},
	{
		PR(\gcAutoSynthCmd).copy.putAll((
			gc: BP(\bss).densityCtl, name: \ctlPoint, outName: \outbus,
			value: 4.1, time: 16 / thisThread.clock.tempo
		))
	},
	\cmdSync,

	{
// thisThread.beats.debug("what the fuck time is it when the goddamn cmdSync releases");
		BP(\ldr).pbindPreAction = \ldrAccents;
		BP(\ldr).divCycle = 0.125;
		BP(\hdr).pbindPreAction = \hdrAccents;
		BP(\hdr).usedKeys = #[bufs, pans, def, times, rates];
		BP(\hdr).divCycle = 0.125;
		BP(\bss).calcBar = \singleBassNotes;
		0
	},
	bpCmd: (name: \sw, quant: #[4, -0.15], prepareBP: { |bp|
		4 => bp;
		bp.pfreq = (Paccumbounce(39, 50,
			Pwrand(#[-2, -1, 1, 2], #[0.2, 0.2, 0.3, 0.3], inf), inf)
			-.x Pseries(0, Pwhite(1, 4, 3))
		).clump(3)
		.collect { |deg, ev| Mode(ev[\mode]).cps(deg) };
		bp.pitchedmode = Pfunc({ BP(\bss).v[\lastMode] ? \d });
		bp.synth = \pitched;
		bp.pitcheddelta = PnNilSafe(Plazy({
			var	d = BP(\bss).durs;
			if(d.isEmpty) {
				Pn(4, 1)
			} {
				Pdelta(Pseq(d ++ #[4], 1), 4)
			}
		}), inf);
		bp.pitchedtime = Pexprand(0.6, 1.0, inf);
		bp.preamp = 9;
		bp.pitchednormAmp = 5;
		bp.isFading = false;
	}),
	bpCmd: (name: \ac2, quant: 4, prepareBP: { |bp|
		bp.mod_lev = Pexprand(4.5, 7.0, inf);
		bp.amp = Plazy({ Env(#[0.16, 0.3], #[32]) });  // be sure it's treated as a pattern
		bp.distance = Plazy({ Env(#[12, 20], #[32]) });
		bp.glrvbamtCtl.value = 0.15;
	}),
	gcAutoSynthCmd: (gc: BP(\ac2).glrvbamtCtl, name: \ctlEnv, outName: \outbus,
		env: Env(#[0.15, 0.67], #[32]), connect: 0),
	gcAutoSynthCmd: (gc: BP(\ldr).distanceCtl, name: \ctlPoint, outName: \outbus,
		value: 18.5, time: 32 * 60/52),
	gcAutoSynthCmd: (gc: BP(\hdr).distanceCtl, name: \ctlPoint, outName: \outbus,
		value: 12.5, time: 32 * 60/52),
	{
		BP(\ldr).argPairs = BP(\ldr).argPairs.copy
		.put(5, Pif(Pkey(\amp) >= 1, Pfunc({ ~slideEnv }), Pwrand([`(Env.one), Pfuncn({ Env([1, rrand(1.25, 1.5)], #[0.05], 6) })], #[0.95, 0.05], inf)));
		0
	},
	32
]).play(argClock: ~clock52);
)

BP(\ac2).mod_lev = Pexprand(4.5, 7.0, inf);

BP(\ac2).amp = 0.16;
BP(\ac2).distance = 5;
BP(\ac2).glrvbamtCtl.value = 0.15;

BP(\ac2).amp = Env(#[0.16, 0.3], #[20]);
BP(\ac2).distance = Env(#[5, 20], #[20]);
BP(\ac2).glrvbamtCtl.watch.automate(\ctlEnv, [env: Env(#[0.15, 0.67], #[30])]);

BP(\ac2).amp = 0.3;




// crappy goddamn motherfucking hacking testing fucking code because the goddamn thing won't motherfucking play two goddamn fucking processes together even though I've written tons of fucking code to do it, god mother fucking damn it to hell


~clock52 => BP(\sw);

BP(#[sw, bss, ac2]).do(_.reset);

BP(\sw).quant
BP(\bss).quant

BP(#[bss, ac2]).play;
BP(\sw).play(BasicTimeSpec(4, -0.15).wrap_(true));

BP(#[bss, sw, ac2]).stop;

BP(\sw).pitchedprotoEvent.postcs

BP(\sw).pitchedprotoEvent = PnNilSafe(Plazy({
	Pif(
		Pseq(BP(\bss).freqs).collect { |f| f.isNumber },
		\polySynthBusLockData, \dummy
	)
}), inf);

BP(\ac2).freq = Pfunc({
		var	ev = BP(~fsrc).lastEvent;
		if(ev[\protoEvent] == \dummy) {
			#[]
		} {
			ev[\freq1] ? #[]
		}
	});


BP(\sw).event

BP(\bss).mod_lev.postcs
BP(\bss).mod_lev = Pkey(\gate).linexp(0.1, 0.8, 3.5, 8.0);



BP(\sw).syncdelta = PnNilSafe(Plazy({ Pdelta(Pseq(BP(\bss).durs ++ #[4]), 4) }), inf).trace(prefix: "syncdelta: ");
BP(\sw).pitcheddelta = BPStream(\syncdelta, false, BP(\sw).v);

BP(\sw).restdelta

BP(\sw).pitcheddelta.inspect

BP(\bss).asPattern = {
		PnNilSafe(Plazy({
			~barCount = ~barCount + 1;
			~calcBar.eval;
			Pbind(
				\barCount, ~barCount,
				\mode, BPStream(\mode),
				\freq, Pseq(~freqs, 1),
				// durs should always end with 4
				\dur, Pdelta(Pseq((~durs ++ #[4]), 1), 4),
				\length, Pseq(~lengths, 1),
				\gate, Pseq(~gates, 1),
				\mod_lev, BPStream(\mod_lev),
				\mod_ratio, BPStream(\mod_ratio),
				\attackTimeScale, 0.1,
				\decayTimeScale, 0.5,
				\distance, ~distanceCtl.asMap,
				\finalAmp, ~ampCtl.asMap
			).trace(#[freq, dur], prefix: "bss: ")
		}), inf);
	};


Pdelta(Pseq(#[2, 3], 1)).asStream.all


BP(\sw).pfreq = PnNilSafe(Plazy({
	Pif(
		Pseq(BP(\bss).freqs.debug("freqs"), 1).collect({ |f| f.size > 0 }),
		(Paccumbounce(39, 50,
			Pwrand(#[-2, -1, 1, 2], #[0.2, 0.2, 0.3, 0.3], inf), inf)
			-.x Pseries(0, Pwhite(1, 4, 3))
		).clump(3)
		.collect { |deg, ev| Mode(ev[\mode]).cps(deg) },
		#[]
	)
}), inf);


BP(\sw).pfreq = (Paccumbounce(39, 50,
	Pwrand(#[-2, -1, 1, 2], #[0.2, 0.2, 0.3, 0.3], inf), inf)
	-.x Pseries(0, Pwhite(1, 4, 3))
).clump(3)
.collect { |deg, ev| Mode(ev[\mode]).cps(deg) };

BP(\sw).synth = PnNilSafe(Plazy({ Pif(Pseq(BP(\bss).freqs).collect { |f| f.isNumber }, \pitched, \rest) }), inf);


// bass suboctave, for return - don't need fast notes
\chuckIf.eval(Fact(\armsChordVC), VC, \ac, nil, (isMono: true).putAll(Library.at(\rvbs)));
\chuckIf.eval(PR(\bassline), BP, \bss);
VC(\ac) => BP(\bss);
~clock52 => BP(\bss);

BP(\bss).mode = \d;

p = BP(\bss);
p.listVars;

p.mod_lev = Pkey(\gate).linexp(0.1, 0.8, 2.2, 5.3);

Mode(\d).cps(p.pitchBase)

VC(\ac).env.target.postSettings

s.sendMsg(\n_trace, 1004);

p.mod_ratio = 3;
p.mod_ratio = 9;

p.mod_ratio = Pwhite(3, 11, inf);

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| o.remove; s.sendMsg(\n_trace, m[1]) }).add;

q = VC(\ac).env.target.playfx(Instr("busfx.rlpf"), [0, 2]); q.gui;

Library.at(Instr, \busfx).keys


Instr("busfx.trigfilt", { |bus, numChan, thresh = 0.238, gate = 1,
	//nflow = 0.2, nfhi = 4.5,
	fenvAtkLo = 0.01, fenvAtkHi = 0.12, fenvDcyLo = 0.4, fenvDcyHi = 0.8,
	fflow = 60, ffhi = 300, fmul = 4.5, rq = 0.1,
	wetBias = 1, wetTrigAmt = 1, wetRandLo = 0.5, wetRandHi = 2/*,
	poll = 0*/|
	var	sig = In.ar(bus, numChan),
		fft = FFT(LocalBuf(512, 1), sig.asArray.sum),
		trig = Onsets.kr(fft, thresh /*, odftype: rcomplex, relaxtime: 1, floor: 0.1, mingap: 10, medianspan: 11, whtype: 1, rawodf: 0 */),
		ffreq = EnvGen.kr(
			Env(
				[60, TRand.kr(fflow, ffhi, trig) * TRand.kr(1.5, fmul, trig),
					TRand.kr(fflow, ffhi, trig)
				],
				[TRand.kr(fenvAtkLo, fenvAtkHi, trig), TRand.kr(fenvDcyLo, fenvDcyHi, trig)],
				\exp
			),
			trig
		),
		wet = Decay2.kr(trig, 0.05, TRand.kr(wetRandLo, wetRandHi, trig), wetTrigAmt, wetBias)
			.clip(0, 1),
		wetMaster = Linen.kr(gate, 0.5, 1, 0.5, doneAction: 2),
		filt = Limiter.ar(RLPF.ar(sig, ffreq.clip(20, 20000), rq), 1, 0.05);
	// PulseCount.kr(trig).poll(trig * poll, "onset trig");
	XFade2.ar(sig, filt, (wet * wetMaster).madd(2, -1));
}, [\audiobus, StaticSpec(1, 8, \lin, 1, 1), \unipolar, #[0, 1],
	// #[0.05, 20, \exp], #[0.05, 20, \exp],
	#[0.005, 3.0, \exp], #[0.005, 3.0, \exp], #[0.005, 3.0, \exp], #[0.005, 3.0, \exp],
	\freq, \freq, #[1.5, 12.0, \exp], \myrq,
	\unipolar, \unipolar, #[0.1, 5, \exp], #[0.1, 5, \exp] /*,
	#[0, 1, \lin, 1, 0] */
]);

Instr("busfx.trigfilt").listArgs

q = VC(\ac).env.target.playfx(Instr("busfx.trigfilt"), [0, 2]); q.gui;

q.synth.trace;

FxPatch(
	[ 'busfx', 'trigfilt' ], [ 24, 2, 0.3928571427241, 0.01, 0.05718911258037, 0.56170743642834, 1.6313060134497, 60.0, 300.0, 6.1503849450928, 0.34404762983322, 0.29761904478073, 0.19047619402409, 0.38596610570799, 0.74081682278355, 1.0 ]
)


#[filtWetBiasCtl, filtWetTrigCtl].do { |key|
	BP(\bss)[key] => VP(0);
};

BP(\bss).addFilt;

BP(\bss).filter.synth.trace;

BP(\bss).filter.synth.set(\gate, 0);
BP(\bss).removeFilt;


s.sendMsg(\n_set, 2575, \gate, 0);