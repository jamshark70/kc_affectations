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


