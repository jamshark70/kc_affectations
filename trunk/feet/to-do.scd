MIDIPort.init([2]);
MIDIPort.autoFreeSockets = false;

s.options.preferredDeviceFunc_(nil).device_("Aggregate Device");

BP.loadGui;

MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

(Document.current.path.dirname.dirname +/+ "common/common-defs.scd").loadPath;
(Document.current.path.dirname +/+ "feet-defs.scd").loadPath;

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


[~glrvb, ~lcrvb].do(_.run(false)); [~glrvbmc, ~lcrvbmc].do(_.mute(true));
[~glrvb, ~lcrvb].do(_.run(true)); [~glrvbmc, ~lcrvbmc].do(_.mute(false));

VoicerProxy.new => VP.prNew(0);
4.do { VP(0).v.addControlProxy(VoicerGCProxy(nil, VP(0).v), addAlways: true) };
VP(0).v.gui;


/**** TODO Slide/inversion gesture */

Fact(\opening) => BP(\op);
Fact(\openingSteps) => BP(\st);

p = BP(\st);

p.gestures.lauraslide = { |parms|
	var env = Env([0, rrand(-25, -12), rrand(15, 30), 6], #[1, 1, 1.5].normalizeSum * 0.8, \sin);
	// var env = Env([0, rrand(30, 45)], #[1], \sin);
	Pbindf(~gestures[\slowStepStretch].(parms.copy.put(\numEv, 2)).drop(2),
		\instrument, \pvplayPanEnvShiftDist,
		\env, Pfunc { env }
		// \shiftS, -100,
		// \shiftE, 100,
		// \shiftFreq, rrand(2.0, 5.0, inf)
	).trace(prefix: "\n")
};
// ^^ NOT WORKING

// good enough:
p.runningNotes = (
	lauraslide: Pseries(
		{ |ev| rrand(-7, 0) },
		Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
		Pkey(\numEv).asStream
	) //,
	// inversion1: ,
	// inversion2: 
);

p.gestures.lauraslide = { |parms|
	Pbind(
		\numEv, parms[\numEv],
		\instrument, Pn(\bufGrainPanKlankDist, parms[\numEv]),
		\delta, 0.4 * Pexprand(0.8, 1.25, inf)
			* Pgeom.fromEndpoints(rrand(0.35, 0.6), rrand(0.1, 0.2), parms[\numEv]),
		\amp, BPStream(\amp) * 0.04,  // filters are LOUD
		\numNotes, Pwrand(#[1, 2, 3], #[1, 4, 3].normalizeSum, inf),
		\filtDegree, (~runningNotes[\lauraslide].value(parms)
			+.x Pseries(0, Pwrand(#[-1, -2, -3], #[1, 2, 2].normalizeSum, Pkey(\numNotes).asStream), inf))
			.clump(Pkey(\numNotes)),
		\filtFreq, Pkey(\filtDegree).collect { |deg| Mode(\g).cps(deg + 35) },
		\filtAttack, 0.01,
		\filtDecay, Pseries.fromEndpoints(0.2, 2.75, parms[\numEv]),
		\filtAmp, BPStream(\kamp),
		\chorusFreq, parms[\chorusFreq] ?? { Pstutter(inf, Pwhite(0.05, 0.11, inf)) },
		\chorusAmt, parms[\chorusAmt] ?? { 0.02 },
		\chorusDelay, parms[\chorusDelay] ?? { 0.03 },
		\chorusAmps, parms[\chorusAmps] ?? { [~defaultChorusAmps] },
		\harm, parms[\harm] ?? { [~defaultKlankHarm] },
		\amps, parms[\amps] ?? { [~defaultKlankAmps] },
		\decays, parms[\decays] ?? { [~defaultKlankDecays] },
		\pan, sin(Pseries(0, Pseries.fromEndpoints(0.08, 0.33, parms[\numEv]), inf) * 2pi)
			* #[-1, 1].choose,
		\distance, Pseries.fromEndpoints(20, 5, parms[\numEv])
	)
};

p.gest = \lauraslide;
p.autoRun = false;

p.autoRun = true;
p.gDelta = 2.5;
~saveNumEv = p.numEv;
p.numEv = Pwhite(8, 15, inf);

p.reset;
p.play;
p.runGesture((gest: \lauraslide, numEv: rrand(8, 14).postln));
p.runGesture((gest: \slowStepStretch, numEv: 8));

p.stop;






o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;

o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;


/**** TODO Leaning */
/**** TODO Falling */
/**** TODO Conflict */
/**** TODO Multiple speeds */
/**** TODO [#C] Distinguish locomotive themes */
