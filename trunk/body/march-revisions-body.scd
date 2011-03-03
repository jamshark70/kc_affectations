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
BP(\st).override(\kfreq, Ptuple([Pseq([-3, 5, 2], 1), 1]));
BP(\st).runGesture((gest: \oneKlank, numEv: 2, mode: \e));

p.unOverride(\kdecay); p.unOverride(\kfreq);
p.listVars


// Ilana solo bells?
// Noisy stuff from torso? maybe rhythmicize
// Melodies: Arms axial
// Melodies: Arms rhythmic melody?
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
		~chan = MixerChannel(~collIndex, s, 2, 2);
		~event.put(\chan, ~chan);
		[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\receivesSignalFrom, ~chan));

		~pitchbufs = \makeWavetables.eval(8, s, 2048, 48, { |numh| 1 ! numh });

		\addRvbOut.eval(\formantfx2Dist, { |inbus, /*outbus,*/ t_trig = 0, slideTime = 1, gate = 1,
			amp = 1, fadeIn = 5, fadeOut = 5, pan = 0, topWet = 1|
			var	ffreqs = NamedControl.kr(\ffreqs, Array.series(5, 400, 400)),
				amps = NamedControl.kr(\amps, 1 ! 5),
				qs = NamedControl.kr(\qs, 0.1 ! 5),
				sig = In.ar(inbus, 1), sig2,
				wet = Linen.kr(gate, fadeIn, topWet, fadeOut, doneAction: 2);
			ffreqs = ffreqs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
			amps = amps.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
			qs = qs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
			sig2 = BBandPass.ar(sig, ffreqs, qs, amps).sum * amp;
			sig = XFade2.ar(sig, sig2, wet.madd(2, -1));
			Pan2.ar(sig, pan)
			// ReplaceOut.ar(outbus, sig);
		}, nil, nil, nil, ReplaceOut).add;

		~distCtl = GenericGlobalControl(\distance, nil, 10, #[5, 20]);
		~panCtl = GenericGlobalControl(\pan, nil, 0, \bipolar);

		~notes = IdentitySet.new;
		~fmtKeys = FormantTable.keys.select { |k| k.asString.contains("tenor") }.asArray;
	};

	~freeCleanup = {
		[~chan, ~pitchbufs, ~distCtl, ~panCtl].free;
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
	~topWet = 1;

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
				\topWet, BPStream(\topWet),
				\fadeIn, BPStream(\fadeIn),
				\fadeOut, BPStream(\fadeOut)
			),
			// notes
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
		], 1)
	};

	~stopCleanup = {
		if(~notes.notEmpty) {
			~notes.do { |node| node.release(~fadeOutTime.neg - 1) };
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
		var	upd;
		node.do { |n|
			switch(n.defName.asSymbol)
				{ \oscbloop1 } {
					~notes.add(n);
					n.register;
					upd = Updater(n, e { |obj, what|
						if(what == \n_end) {
							upd.remove;
							~notes.remove(obj);
							if(~notes.isEmpty and: { ~isPlaying.not }) { ~stopFx.() };
						};
					});
				}
				{ \formantfx2Dist } {
					~fxnode !? { ~fxnode.free };
					~fxnode = n;
				};
		};
	};
} => PR(\lowTonesFmt);
)

BP(\ltf).free;
PR(\lowTonesFmt) => BP(\ltf);
0 => BP(\ltf);

BP(\ltf).fxDelta = Pwhite(0.4, 1.4, inf);
BP(\ltf).fxamp = 18.dbamp;

BP(\ltf).degree = Pwhite(30, 39, inf) -.x Pseries(0, Pwrand(#[1, 2, 3], #[0.2, 0.4, 0.4], 3), inf).clump(3);

(
BP(\fmt2).free;
Fact(\formantfx1).chuck(BP(\fmt2), nil, (
	chan: n,
	objects: (
			fmt: (
				def: SynthDef(\formantfx2, { |inbus, outbus, t_trig = 0, slideTime = 1, gate = 1,
						amp = 1, fadeIn = 5, fadeOut = 5|
					var	ffreqs = NamedControl.kr(\ffreqs, Array.series(5, 400, 400)),
						amps = NamedControl.kr(\amps, 1 ! 5),
						qs = NamedControl.kr(\qs, 0.1 ! 5),
						sig = In.ar(inbus, 2), sig2,
						wet = Linen.kr(gate, fadeIn, 1, fadeOut, doneAction: 2);
					ffreqs = ffreqs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
					amps = amps.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
					qs = qs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
					sig2 = BBandPass.ar(sig, ffreqs, qs, amps).sum * amp;
					sig = XFade2.ar(sig, sig2, wet.madd(2, -1));
					ReplaceOut.ar(outbus, sig);
				}),
				args: [
					protoEvent: Pseq([\singleSynthPlayNotify, Pn(\singleSynthTrigger, inf)]),
					#[ffreqs, amps, qs], Pnsym(BPStream(\formant), FormantTable),
					ffreqs: Pkey(\ffreqs) * Pexprand(0.95, 0.95.reciprocal, inf).clump(5),
					trig: 1,
					slideTime: Pkey(\delta) * Pwhite(0.4, 0.8, inf),
					inbus: Plazy({ Pn(~chan.inbus, inf) }),
					node: Pfunc({ ~node ? 0 }),
					sustain: inf,
					amp: 12.5.dbamp,
					fadeIn: BPStream(\fadeIn),
					fadeOut: BPStream(\fadeOut)
				]
			)
	)
));
BP(\fmt2).v.putAll((
	recvEventNotify: { |node, event|
		~node = node;
	},
	stopCleanup: { ~node.release; ~node = nil; ~makeStreamForKey.(\fmtprotoEvent) }
));
BP(\fmt2).event.put(\chan, n).put(\eventKey, \monoSupport);
)

s.sendMsg(\n_free, *(1102..1200))

BP(\fmt2).event.eventKey = \monoSupport;
BP(\fmt2).reset;

BP(\fmt2).fmtprotoEventStream.next
BP(\fmt2).stopCleanup;
BP(\fmt2).v[\stopCleanup].postcs;

BP(\fmt2).stopCleanup = 0;

s.sendMsg(\n_free, 1093, 1098);

BP(\fmt2).node.trace

// Harmonies: Torso held notes


