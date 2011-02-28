MIDIPort.init(#[3]);

BP.loadGui;

MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

// (Document.current.path.dirname.dirname +/+ "common/common-defs.scd").loadPath;
(Document.current.path.dirname +/+ "head-defs.scd").loadPath;

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

~cRvbMc.free;

VoicerProxy.new => VP.prNew(0);
4.do { VP(0).v.addControlProxy(VoicerGCProxy(nil, VP(0).v), addAlways: true) };
VP(0).v.gui;




Fact(\dataIn).chuck(BP(\di), nil, (playTestFile: true, readFrame: 138));

BP(\di).setStartTime(20, 42);

// 10-1122 vid:
// head starts, 21:25
// voices start, 22:55
// drums start, 23:22
// final cadence, 26:05
// metronome, 26:15

// find "metronome"
BP(\di).setStartTime(25, 05);


// drum7/8 disintegrate
BP.keys.asArray.sort.do { |key|
	if(key.asString.beginsWith("drum")) { BP(key).free };
};

(1..3).do { |i|
	\chuckIf.eval(Fact(("drum" ++ i).asSymbol), BP, ("drum" ++ i).asSymbol, nil,
		(source: \drum1).putAll(Library.at(\rvbs)))
};

BP(#[drum7, drum8]).free;
Fact(\drum7) => BP(\drum7);
\chuckIf.eval(Fact(\drum7), BP, \drum8, nil,
	(ctlSource: \drum7/*, quant: #[-1, 1.25]*/).putAll(Library.at(\rvbs)));

p = BP(\drum7);
q = BP(\drum8);

p.pan = -1; q.pan = 1;

p.leadTime = 0.01;

p.finalLpfCtl => VP(0);

p.ostFiltCtl.value = 1;
p.fmltDcyCtl.value = 0.25;
p.fmltWetCtl.value = 0; // 0.1;
p[\chan].level = -7.dbamp;


p.v.env.keys.select { |key| key.asString.contains("Ctl") }
// Set[ ost2AmpCtl, fmltWetCtl, distCtl, ostFiltCtl, accWetCtl, fmltDcyCtl ]

VP(0).clearControlProxies;
p.distCtl => VP(0);

VP(0).controlProxies[0].gc.free;

// this mapping is good
u.remove;
u = Updater(BP(\drum7).distCtl, { |obj, event|
	if(event[\what] == \value) {
		BP(\drum7).finalLpfCtl.value = obj.value.linexp(5, 20, 18000, 400)
	};
});



// parameterize!

[p, q].do { |bp|
	bp.gest = \messedUp;
};

{
	if(bp.collIndex == \drum7) {
		bp.messedUpMulCtl = bp.v[\messedUpMulCtl] ?? { GenericGlobalControl(\messDMul, nil, 1, #[1, 4]) };
		if(bp.v[\freeCleanup].isKindOf(Function)) {
			bp.v[\freeCleanup] = bp.v[\freeCleanup].addFunc({ ~messedUpMulCtl.free });
		};
	} {
		bp.messedUpMulCtl = BP(\drum7).messedUpMulCtl;
	};
	bp.messedUpRatios = Prand([3/2, 4/3, 5/4, 6/5, 9/8], inf);
	bp.messedUpNumEv = Pwhite(3, 9, inf);
	bp.messedUpBeats = Plazy({ Pwhite(1, 6, inf) * ~messedUpMulCtl.round });
};

[p, q].do { |bp|
	bp.gestures.messedUp = Plazy({ |inEv|
			var	accEv = ~accEvent.(inEv, Pkey(\delta)).asStream,
				once = false,
				dur,
				pat = Pchain(
					Pfunc({ |ev|
						var	x;
						if(ev[\doAccent]) {
							ev = accEv.next(ev).put(\wet, 0.55);
							if(once) { ev } {
								once = true;
								x = ~messedUpRatiosStream.nextN(3, ev);
								x.doAdjacentPairs { |a, b, i| x[i+1] = a*b };
								ev.put(\ffreq, ev[\ffreq] * x)
									.put(\ffreq2, ev[\ffreq2] * x);
							};
						} { ev }
					}),
					Pbind(
						\bufIndex, Pswitch1([0, Pxrand((1..4), inf)],
							Pwrand(#[0, 1], Pif(Pkey(\delta) >= (~messedUpMulCtl.asPattern * 0.25), #[0.75, 0.25], #[0.1, 0.9]), inf)
						),
						// \amp, 1,
						\amp, Pn(Plazy({ |ev|
							var	bool = 0.3.coin;
							if(bool) {
								Pn(1, ev[\numInSeg])
							} {
								Pgeom.fromEndpoints(1, rrand(0.2, 0.5), ev[\numInSeg])
							}
						}), inf),
						\rate, Pif(Pkey(\bufIndex) > 0, 1, Prand(#[0.5, 0.6], inf)),
						\start, 0,
						\pan, Plazy({ BPStream(\pan) }),
						\ffreq, Plazy({ BPStream(\lpfreq) }),
						\wet, 0
					),
					Pbind(
						\doAccent, false,
						\delta, Pn(Plazy({ |ev|
							ev[\numInSeg] = rrand(3, 9);
							ev[\doAccent] = true;
							Pgeom.fromEndpoints(*
								[rrand(0.4, 0.6), rrand(0.08, 0.2)].rotate(2.rand)
								++ [ev[\numInSeg]]
							) * ~messedUpMulCtl
						}), inf)
					)
				);
			if(~leadTime > 0) {
				~lastMessedUpBeats = dur = ~messedUpBeatsStream.next(inEv)
			} {
				dur = BP(~ctlSource).lastMessedUpBeats;
			};
			Pfindur(dur.debug(~collIndex ++ " messedUpBeats"), pat)
		});
};

p.quant = -1;
q.quant = [-1, 0.5];

[p, q].do(_.reset);
[p, q].play;
[p, q].stop;

p.messedUpMulCtl => VP(0);
p.distCtl => VP(0);
p.finalLpfCtl => VP(0);

p.messedUpMulCtl.watch.automate({ XLine.kr(1, 3, 50, doneAction: 2) });

x = p.distCtl.watch.automate({ Line.kr(5, 20, 75, doneAction: 2) });
p.finalLpfCtl.watch.automate({ p.distCtl.kr.linexp(5, 20, 18000, 400) }, nil, x, \addAfter);
NodeWatcher.register(x);
u = Updater(x, { |obj, what|
	u.remove;
	if(what == \n_end) { p.finalLpfCtl.stopAuto };
});

p.distCtl.autoSynth

p.messedUpMulCtl.watch.automate({ XLine.kr(3, 1, 25, doneAction: 2) });

p.messedUpMulCtl.stopAuto.stopWatching;

p.gest.postcs;

1 * p.messedUpMulCtl.round
p.messedUpBeats = Plazy({ Pwhite(1, 6, inf) * ~messedUpMulCtl.asPattern.round });

p.gestures.keys
p.gestures[\randquant].postcs
p.gestures[\randsync].postcs
p.gestures[\barsync].postcs

// Date.seed evaluates once, will be shared by all streams
var x = (Pseed(Pn(Date.seed, 1), Pwhite(3, 6, inf)) / p.messedUpMulCtl).round,
	y = Pseed(Pn(Date.seed + 234321, 1), Pwhite(3, 9, inf));
[p, q].do { |bp|
	bp.gest = Pseq([
		Pn(\ostFilt2, x.asStream.trace(prefix: bp.collIndex ++ " num ost bars: ")),
		\randsync,
		Pn(\messedUp, y.asStream),
		\randquant
	], inf) // .trace(prefix: bp.collIndex ++ " gesture: ")
};


[p, q].do { |bp|
	bp.gestures.putAll((
		barsync: { |pat|
			var	q = thisThread.clock.nextBar - thisThread.beats - ~leadTime;
		 	if(q.abs < 0.002) { q = thisThread.clock.beatsPerBar };
			Psync(pat, q, q);
		},
		quantsync: { |pat|
			var	q = thisThread.clock.nextBar - thisThread.beats - ~leadTime
					+ (BP(~collIndex).quant.phase ? 0);
		 	if(q.abs < 0.002) { q = thisThread.clock.beatsPerBar };
			Psync(pat, q, q);
		}
	))
};



x = p.distCtl.watch.automate({ Line.kr(5, 20, 75, doneAction: 2) });
p.finalLpfCtl.watch.automate({ p.distCtl.kr.linexp(5, 20, 18000, 400) }, nil, x, \addAfter);
NodeWatcher.register(x);
u = Updater(x, { |obj, what|
	u.remove;
	if(what == \n_end) { p.finalLpfCtl.stopAuto };
});


SynthDef(\bassVelMap, { |inbus, outbus, inMin, inMax, outMin, outMax, slewUp, slewDown|
	var sig = In.kr(inbus);
	sig = Slew.kr(sig, slewUp, slewDown).linexp(inMin, inMax, outMin, outMax, \minmax);
	Out.kr(outbus, sig);
}).add;

(
var	drumLevel = -7.dbamp, record = true, upd;

t.stop;
t = TLSequenceIterator([
	// { rrand(5.0, 8.0) * 108/60 },
	{
		if(record) { ~master.startRecord(thisProcess.platform.recordingsDir +/+ "drum78-%.aiff".format(Date.getDate.stamp)) };
		0
	},
	Quant(3, -0.5),
	{	BP(#[drum4, drum5, drum6]).stop;
		BP(\drum7).pan = -1;
		BP(\drum8).pan = 1;
		BP(\drum7).quant = -1;
		BP(\drum8).quant = #[-1, 0.75];

		BP(\drum7).distCtl.value = 5;
		BP(\drum7).finalLpfCtl.value = 18000;
		0
	},

	bpCmd: (name: #[drum7, drum8], quant: -1, /*shouldSync: false,*/ prepareBP: { |bp|
		bp.ostFiltCtl.value = 1;
		bp.fmltDcyCtl.value = 0.25;
		bp.fmltWetCtl.value = 0.1;
		bp[\chan].level = drumLevel;
	}),
	funcCmd: (doneSignal: true,
		num3: rrand(2, 7),
		func: {
			var	thisCmd = currentEnvironment;
			BP(#[drum7, drum8]).do { |bp|
				~num3 = ~num3 + 5;
				bp.gest = Pseq([
					CleanupStream(
						Pseq([\threePl1, Pn(\threeAcc, ~num3), \ostFilt2Quant]).asStream,
						{ thisCmd.stop }
					),
					Pn(\ostFilt2, inf)
				]);
				bp.accFreq = 52 * Pwhite(2, Pseries.fromEndpoints(16, 5, ~num3) ++ Pn(5, inf), inf);
				bp.accFreq2 = (Pkey(\ffreq) * Pwhite(2, 4, inf)).wrap(52, 52 * (Pseries.fromEndpoints(16, 5, ~num3) ++ Pn(5, inf)));
			};
		}
	),
	\cmdSync,
	{ "synced".debug; 6 },

	18,
	loopCmd: (repeats: 2,
		qphase: Pseq(#[1.25, 0.75], inf).asStream,
		acc: Pseq([\threeAcc, Prand(#[fiveAcc, sevenAcc], inf)]).asStream,
		cmds: [
			{	var	numAcc = rrand(3, 6), acc = ~acc.next,
				pat = Pseq([\ostFilt2Sync, Pn(acc, numAcc), \ostFilt2Quant], 1);
				BP(#[drum7, drum8]).do { |bp|
					bp.override(\gest, pat);
				};
				BP(\drum8).quant = [-1, ~qphase.next];
				rrand(3, 5) * 6
			}
		]
	),
	\cmdSync,

	{	BP(\drum8).gest = Pfsm([
		#[4, 5],
		Pwrand(#[five, fiveRest], #[0.5, 0.5], { rrand(2, 4) }), #[0, 1, 2, 3],
		Pwrand(#[seven, sevenRest], #[0.5, 0.5], { rrand(2, 4) }), #[0, 1, 2, 3],
		\fiveAcc, #[2, 4, 5],
		\sevenAcc, #[3, 4, 5],
		\five1Acc, #[0, 2],
		\seven1Acc, #[1, 3],
	], inf);
		6
	},
	{	BP(\drum7).gest = BP(\drum8).gest;
		6 //24
	},

	loopCmd: (repeats: 3,
		acc: Prand(#[threeAcc, fiveAcc, sevenAcc], inf),
		cmds: [
			{	var	// both 7+8 use the same random seed
				pat = Pseed(Pn(Date.seed, 1), Pseq([
					Pif(Ptime() < rrand(8, 11), Pseq([\randsync, ~acc], 1)),
					\randquant
				], 1));
				BP(#[drum7, drum8]).do { |bp|
					bp.keepGoing = false.debug("set % keepGoing".format(bp.collIndex));
					bp.override(\gest, pat);
				};
				BP(\drum8).quant = -1;
				// override is guaranteed to end first because it's at most 11 beats
				rrand(2, 4) * 6
			}
		]
	),
	\cmdSync,

	{
		var x = (Pseed(Pn(Date.seed, 1), Pwhite(3, 6, inf)) / p.messedUpMulCtl).round * 3,
			y = Pseed(Pn(Date.seed + 234321, 1), Pwhite(3, 9, inf)),
			oldGest = BP(\drum7).gest;
		BP(#[drum7, drum8]).do { |bp|
			bp.gest = Pseq([
				// Pn(\ostFilt2, x.asStream.trace(prefix: bp.collIndex ++ " num ost bars: ")),
				\randsync,
				Pn(\messedUp, y.asStream),
				\randsync, // \randquant,
				Pif(Ptime() < Pstutter(1e6, x.asStream), oldGest),
			], inf) //.trace(prefix: bp.collIndex ++ " gesture: ")
		};
		BP(\drum7).messedUpMulCtl.value = 1;
		18
	},

	gcAutoSynthCmd: (gc: BP(\drum7).messedUpMulCtl, name: \ctlEnv, outName: \outbus,
		env: Env(#[1, 3], #[45])),

	12,
	gcAutoSynthCmd: (gc: BP(\drum7).distCtl, name: \ctlEnv, outName: \outbus,
		env: Env(#[5, 20], #[70])),
	gcAutoSynthCmd: (gc: BP(\drum7).finalLpfCtl, name: \bassVelMap, outName: \outbus,
		inbus: BP(\drum7).distCtl.bus,
		inMin: 5, inMax: 20, outMin: 18000, outMax: 400, slewUp: 1e6, slewDown: 1e6)

	// gcAutoSynthCmd: (gc: { BP(\drum7).fmltWetCtl }, name: \ctlPoint, shouldSync: false, outName: \outbus,
	// 	value: 0.736, time: 20, curve: 2),
]).play(argClock: ~clock108);
//.shouldSync_(false)

// if(record) {
	upd = Updater(t, { |obj, what|
		if(what == \done) {
			upd.remove;
			"notify me".debug;
			{ topEnvironment[\master].stopRecord }.defer(3)
		};
	});
// };
)

t.isPlaying
NotificationCenter.unregister(t, \done, \recorder);


// head section coda - starts while drums disintegrate
13:31 * 2 - break out of metronome
14:33 * 2 - torso
-----
 1:02 * 2 = 2:04


\chuckIf.eval(Fact(\bloops), BP, \bl, nil, Library.at(\rvbs));
\chuckIf.eval(Fact(\creaks), BP, \cr, nil, Library.at(\rvbs));
\chuckIf.eval(Fact(\words), BP,\sw, nil, Library.at(\rvbs));

(1..3).do { |i|
	var	bp;
	bp = \chuckIf.eval(PR(\creaks), BP, ("cr" ++ i).asSymbol, nil, (
		chan: BP(\cr).chan,
		buf: BP(\cr).buf
	).putAll(Library.at(\rvbs))) ?? { BP(("cr" ++ i).asSymbol) };
	0 => bp;
	bp.printStopMsg = false;
};

(
~crKeyStream = Pseq(#[cr, cr1, cr2, cr3], inf).asStream;

~faceFuncs = (
	bloop: { BP(\bl).triggerOneEvent(0) },
	squeak: {
		// note, this should only be run in an environment that has a crKeyStream
		var	key = ~crKeyStream.next;
		BP(key).gest = \squeak;
		BP(key).play;
	},
	shortsqueak: {
		var	key = ~crKeyStream.next;
		BP(key).gest = \shortsqueak;
		BP(key).play;
	},
	fastsqueaks: {
		var	key = ~crKeyStream.next;
		BP(key).gest = \fastsqueaks;
		BP(key).play;
	},
	squeaks: {
		var	key = ~crKeyStream.next;
		BP(key).gest = \squeaks;
		BP(key).play;
	},
	smoothsqueaks: {
		var	key = ~crKeyStream.next;
		BP(key).gest = \smoothsqueaks;
		BP(key).play;
	},
	squeakfall: {
		var	key = ~crKeyStream.next;
		BP(key).gest = \squeakfall;
		BP(key).play;
	},
	wet: { |view|
		BP(\wet).fastProbCtl.value = 0.6;
		BP(\wet).play(0);
		BP(\wet).clock.sched(rrand(2.0, 5.0), {
			BP(\wet).stop(0); nil
		});
	}
);
)

~faceFuncs[\dummy] = 0;

BP(\bl).sinbtime = 0.1;
BP(\bl).synth = \sinb;
BP(\bl).synth = Pfunc({ ~objects.keys.choose });

BP(\bl).objects[\sinb][\args]

BP(\bl).buzzEnv.do(_.postcs); ""
BP(\bl).sinbenv = [BP(\bl).buzzEnv[0]];

BP(\bl).objects.keysDo { |key|
	BP(\bl).v.put((key ++ "time").asSymbol, 0.1)
	.put((key ++ "env").asSymbol, [BP(\bl).buzzEnv[0]]);
};

g = GenericGlobalControl(\amp, nil, 0.8, #[0, 2, \amp]);
g.gui;

g.spec = [0, 4, \amp];

#[sinbnormAmp, oscbnormAmp, buzzamp].do { |key| BP(\bl)[key].postcs }; ""
#[sinbnormAmp, oscbnormAmp, buzzamp].do { |key| BP(\bl)[key] = g.asMap }; ""
#[sinbnormAmp, oscbnormAmp, buzzamp].do { |key| BP(\bl)[key] = 2.25 }; ""

g.free;

BP(\cr).gestures[\squeak].postcs

BP(#[cr, cr1, cr2, cr3]).do { |bp|
	bp.gestures[\shortsqueak] = { |ev|
		var parms = ~parmsPatStream.next(ev);
		~makeOne.(parms
			.put(\num, 1)
			.put(\pct, parms[\pct] * 0.35)
		)
	};
	bp.gest = \shortsqueak;
	bp.reset;
};

BP(~crKeyStream.next).play(0);

p = Pbind(
	\delta, Pseq(#[0.25, 0.25, 0.5, 0.5], inf),
	\key, Pseq(#[bloop, shortsqueak], inf),
	\crKeyStream, Pclutch(Pseq(#[cr, cr1, cr2, cr3], inf), Pbinop('==', Pkey(\key), \shortsqueak)),
	\play, Pnsym(Pkey(\key), ~faceFuncs)
).play(~clock108);

p.stop;

// flash of quick bloops/squeaks, then lpc chord(s)?
// quicker lpc chords, then slower bloops, then a punctuating lpc chord?
// end coda with a few of the low, slow lpc words -> blend with low tones

BP(\wtrig).free; BP(\cwd).free;
\chuckIf.eval(Fact(\words), BP, \cwd);

c = BP(\cwd);
c.listVars;

c.pitchProb.value = 1;
c.pitchedSlideProb = 0;

c.v.env.keys.asArray.sort.do { |key|
	if(key.asString.beginsWith("pitched")) { [key, p[key]].postcs };
}; ""

c.noiseenv.postcs
// c.pitchedenv = [Env.adsr(0.05, 0.25, 0.35, 0.7)];
c.pitchedenv = [Env(#[0, 1, 0.35, 0.35, 0], #[0.01, 0.1, 0.69, 0.2], -4)];

c.prepareForPlay;
c.triggerOneEvent(0);

k = BasicMIDISocket(0, { c.triggerOneEvent(0) });

SynthDef(\lpfxferPan2, { |inbus, outbus, ffreq1 = 2000, ffreq2 = 2000,
	sustain = 1, ffreqTimeScale = 1, panTimeScale = 1, attackPct = 0.05,
	pan = 0, pan2 = 0, lpfxAmp = 0.3|
	var	ffreq = XLine.kr(ffreq1, ffreq2, sustain * ffreqTimeScale),
		sig = In.ar(inbus, 1),
		env = Env.perc(attackPct, 1 - attackPct),
		eg = EnvGen.kr(env, timeScale: sustain, doneAction: 2);
	pan = Line.kr(pan, pan2, sustain * panTimeScale);
	sig = LPF.ar(sig, ffreq, lpfxAmp);
	Out.ar(outbus, Pan2.ar(sig, pan, eg));
}).add;

\addRvbOut.eval(\lpfxferPan2Dist, SynthDescLib.at(\lpfxferPan2).def.func).add;

(
(
play: {
//	currentEnvironment.debug;
	if(~playChild) {
		BP(~source).triggerOneEvent(DelayTimeSpec(min(~offset ? 0, ~delta - 0.5)));
	};
}) => ProtoEvent(\fastChordTrig);

PR(\abstractProcess).clone {
	~event = (eventKey: \fastChordTrig, isFx: true);
	~source = \cwd;

	~ffreq1 = 18000;
	~ffreq2 = 400;
	// ~sustain = 2;
	~ffreqTimeScale = 0.3;
	~lpfxAmp = 0.4;
	~playAttack = false.asPattern;
	~playChild = true.asPattern;

	~delta = 3; // Pwhite(3, 10, inf) * 0.25;
	~sustain = Pwhite(1.2, 2.1, inf);
	~offset = Prand(#[0.5, 1.0], inf);

	~filtXferParms = Plazy({
		Pbind(
			\instrument, \lpfxferPan2,
			\chan, Pfunc({ BP(~source).chan }),
			\ffreq1, BPStream(\ffreq1),
			\ffreq2, BPStream(\ffreq2),
			\ffreqTimeScale, BPStream(\ffreqTimeScale),
			\lpfxAmp, BPStream(\lpfxAmp)
		)
	});

	~prep = {
		BP(~source).addDependant(currentEnvironment);
	};
	~freeCleanup = {
		BP(~source).removeDependant(currentEnvironment);
	};

	~asPattern = {
		~reset.();
		Pbind(
			\source, ~source,
			\delta, BPStream(\delta),
			\sustain, BPStream(\sustain),
			\offset, BPStream(\offset),
			\playChild, BPStream(\playChild)
		).collect { |ev| ~lastEvent = ev; ev }
	};

	~update = { |obj, what, event|
		if(what == \oneEventPlayed and: { ~lastEvent.notNil and: { ~playAttackStream.next(event) } }) {
			~filtXferParmsStream.next(ProtoEvent(\singleSynthPlayer).copy)
			.put(\inbus, event.lpcEv.inbus)
			.put(\sustain, ~lastEvent[\sustain])
			.play;
		};
	};

	~reset = { ~makeStreamForKey.(\filtXferParms) };
} => PR(\wordsFastChordTrig);
)

BP(\wtrig).free;
PR(\wordsFastChordTrig).chuck(BP(\wtrig), nil, (source: \cwd));

BP(\cwd).dependants

BP(\wtrig).prepareForPlay;
BP(\wtrig).playAttack = true.asPattern;
BP(\wtrig).triggerOneEvent(0);

r = BP(\wtrig);

r.ffreq1 = 18000;
r.ffreq2 = 400;
r.sustain = 2;
r.ffreqTimeScale = 0.3;
r.lpfxAmp = 0.6;

BP(\cwd).pitchedtime = 2;

q.lastEvent
q.play


q.filtXferParms = Plazy({
	Pbind(
		\instrument, \lpfxferPan2,
		\chan, Pfunc({ BP(~source).chan }),
		\ffreq1, BPStream(\ffreq1),
		\ffreq2, BPStream(\ffreq2),
		\ffreqTimeScale, BPStream(\ffreqTimeScale),
		\lpfxAmp, BPStream(\lpfxAmp)
	).trace(prefix: "xferparms: ");
});

BP(\wtrig)[\update] = { |obj, what, event|
// [obj, what/*, event*/].debug("wtrig update");
		if(what == \oneEventPlayed and: { ~lastEvent.notNil and: { ~playAttackStream.next(event) } }) {
			~filtXferParmsStream.next(ProtoEvent(\singleSynthPlayer).copy)
			.put(\inbus, event.lpcEv.inbus)
			.put(\sustain, ~lastEvent[\sustain])
			.play;
		};
	};


[p, q].do { |bp| bp.gest = \messedUp };
BP(\wtrig).delta = Pfunc({ BP(\drum7).lastMessedUpBeats });

~clock108 => BP(\wtrig);
~clock108 => BP(\cwd);

BP(\cwd).pitchednormAmp = 25.dbamp;

BP(#[drum7, drum8]).play(-1);
BP(\wtrig).play(-1);

BP(\wtrig).playChild = 0.6.asPattern.coin;

BP.all.stop

c = BP(\cwd);
c.listVars;

25.unmapMode(\ab0).asInteger.asMIDINote

c.pfreq = (Paccumbounce(35, 46, Pwrand(#[-2, -1, 1, 2], #[0.2, 0.2, 0.3, 0.3], inf), inf)
-.x Pseries(0, Pwhite(1, 4, Pkey(\numInChord).asStream)))
.clump(Pfunc({ |ev| ev[\numInChord] = rrand(7, 11); ev[\numInChord] }))
.collect { |deg, ev| Mode(ev[\mode]).cps(deg) };

k.free;
k = BasicMIDISocket(0, {
	BP(\wtrig).debug("go").triggerOneEvent(0)
});

r.lastEvent

c.triggerOneEvent(0);
c.pfreqStream.next((mode: \ab0))

z = Pwhite(1, 4, { |ev| ev[\numInChord] = rrand(5, 9); ev.debug[\numInChord] }).asStream;
z.next(e = ())

SynthDef(\lpfxferPan2, { |inbus, outbus, ffreq1 = 2000, ffreq2 = 2000,
	sustain = 1, ffreqTimeScale = 1, panTimeScale = 1, fshiftTimeScale = 1, attackPct = 0.05,
	pan = 0, pan2 = 0, lpfxAmp = 0.3, fshiftMix = 0.5|
	var	ffreqtime = sustain * ffreqTimeScale,
		ffreq = XLine.kr(ffreq1, ffreq2, ffreqtime),
		sig = In.ar(inbus, 1),
		env = Env.perc(attackPct, 1 - attackPct),
		eg = EnvGen.kr(env, timeScale: sustain, doneAction: 2);
	pan = Line.kr(pan, pan2, sustain * panTimeScale);
	sig = LPF.ar(sig, ffreq, lpfxAmp);
	sig = XFade2.ar(sig,
		FreqShift.ar(sig, Line.kr(Rand(80, 300) * (IRand(0, 1).madd(2, -1)), 0.01,
			sustain * fshiftTimeScale
		)),
		fshiftMix.madd(2, -1)
	);
	Out.ar(outbus, Pan2.ar(sig, pan, eg));
}).add;

\addRvbOut.eval(\lpfxferPan2Dist, SynthDescLib.at(\lpfxferPan2).def.func).add;

r.fshiftMix = 0.9;

r.fshiftMix = Pwhite(0, 0.4, inf);
r.fshiftTimeScale = 0.125;
r.attackPct = 0.003;

r.filtXferParms = Plazy({
	Pbind(
		\instrument, \lpfxferPan2Dist,
		\chan, Pfunc({ BP(~source).chan }),
		\isFx, true,
		\ffreq1, BPStream(\ffreq1),
		\ffreq2, BPStream(\ffreq2),
		\ffreqTimeScale, BPStream(\ffreqTimeScale),
		\lpfxAmp, BPStream(\lpfxAmp),
		\fshiftMix, BPStream(\fshiftMix),
		\fshiftTimeScale, BPStream(\fshiftTimeScale),
		\attackPct, BPStream(\attackPct)
	)
});

r.playChild = true;


e = r.use { ~eventStream.next(~event.copy) };
e.play;



c.pitchedtime = 3; // Pwhite(1.4, 2.1, inf);
c.dist = 5;

r.setAttackChord(true);

r.ffreq1 = 18000;
r.ffreq2 = 400;
r.sustain = 2;
r.ffreqTimeScale = 0.3;
r.lpfxAmp = 1.6;

();
z = BP(#[cr, cr1, cr2, cr3]);

z.do { |bp|
	~clock108 => bp;
	bp.fastsqkCoords = bp.pt[#[0, 1, 2, 4]].collect(_[#[0, 1]]);
	bp.fastsqkDelta = Pn(Plazy({ |ev|
		ev[\numInSeg] = rrand(3, 9);
		Pgeom.fromEndpoints(*
			([rrand(0.4, 0.6), rrand(0.08, 0.2)].rotate(2.rand))
			++ [ev[\numInSeg]]
		)
	}), { rrand(4, 8) });
	bp.gestures.fastsqueaks = { |ev|
		var parms = ~parmsPatStream.next(ev);
		CleanupStream(
			Pbind(
				\instrument, ~def,
				\bufnum, ~buf.bufnum,
				// \angle, 
				// calculate distance and pan by trig
				\distance, ~dist, // Pseries.fromEndpoints(startd, 25-startd, num),
				\pan, 0,
				\amp, BPStream(\amp),
				\delta, ~fastsqkDelta, // should be a finite pattern here!
				\rate, Pwhite(0.3, 0.7, inf),
				\time, Pwhite(0.05, 0.15, inf),
				#[lowSec, hiSec], Prand(~fastsqkCoords, inf),
				// \start, Pwhite(0, ~buf.numFrames - (Pkey(\time) * Pkey(\rate)), inf),
				\start, Pwhite(Pkey(\lowSec),
					max(Pkey(\hiSec) - (Pkey(\time) * Pkey(\rate)), Pkey(\lowSec)), inf)
				* ~buf.sampleRate,
				#[attack, decay], Pkey(\time) * #[0.08, 0.8],
				\time, Pkey(\time) - Pkey(\attack) - Pkey(\decay)
			).asStream, {
				NotificationCenter.notify(\fastsqueaks, \done);
			}
		)
	}
};

~faceFuncs[\fastsqueaks].();

z.do { |bp|
	bp.fastsqkDelta = Pconst({ rrand(3, 8).debug("limit") }, Pwxrand(#[0.25, 0.5, 0.75, 1], #[10, 6, 4, 1].normalizeSum, inf)).trace;
	bp.amp = 3;
};

z.do { |bp|
	bp.fastsqkDelta = Pn(Plazy({ |ev|
		ev[\numInSeg] = rrand(3, 9);
		Pgeom.fromEndpoints(*
			([rrand(0.4, 0.6), rrand(0.08, 0.2)].rotate(2.rand))
			++ [ev[\numInSeg]]
		)
	}), { rrand(2, 5) });
	bp.amp = 3;
};

BP(\wtrig).offset = 0;
BP(\wtrig).offset = (Pwhite(1, 3, inf) * 0.5).trace(prefix: "offset: ");
BP(\wtrig).offset = 0.5;
BP(\cwd).v.env.keys.select { |key| key.asString.containsi("slide") }
BP(\cwd).pitchedSlideProb = 0.5;
BP(\cwd).pitchedtime = Pfunc({ BP(\wtrig).lastEvent.sustain });

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;

BP(\wtrig).triggerOneEvent(0);
r.attackPct = 0.01;
r.fshiftMix = 0;

NotificationCenter.register(\fastsqueaks, \done, \boing, {
	// BP(\wtrig).triggerOneEvent(0);
	BP(\wtrig).delta = Pwhite(2, 5, rrand(1, 4)) * 0.5;
	BP(\wtrig).play(0);
});

BP(\cwd).pfreq.postcs

	BP(\wtrig).delta = Pwhite(2, 5, inf) * 0.5;
	BP(\wtrig).play(0);

BP(\wtrig).sustain = 0.5;
BP(\wtrig).sustain = min(Pkey(\delta), 1.8) / Ptempo();
BP(\wtrig).fshiftMix = 0;
BP(\wtrig).fshiftMix = 0.8;
BP(\wtrig).fshiftMix = Prand(#[0, 0.8], inf);

BP(\wtrig).filtXferParmsStream.next(())

BP(\wtrig).makeStreamForKey(\filtXferParmsStream);

BP(\drum7).distCtl.value = 5;
BP(\drum7).finalLpfCtl.value = 18000;
~clock108.nextTimeOnGrid(-1, 0.05) - ~clock108.beats

(
t.stop;
t = TLSequenceIterator([
	{ Quant(-1, -0.05).asTLItem },
	bpCmd: (name: #[drum7, drum8], quant: BasicTimeSpec(-1)),
	{
		var p = BP(\drum7),
			x = (Pseed(Pn(Date.seed, 1), Pwhite(3, 6, inf)) / BP(\drum7).messedUpMulCtl).round * 3,
			y = (Pseed(Pn(Date.seed + 234321, 1), Pwhite(3, 9, inf))
				* Env(#[1, 0.075], #[80], 0.5).asStream).round,
			oldGest = BP(\drum7).gest,
			rsyncEnv = Env(#[1, 0], #[90], 1.4).asStream;
		BP(\wtrig).delta = Pfunc({ BP(\drum7).lastMessedUpBeats }).trace(prefix: "wtrig delta: ");
		BP(\wtrig).sustain = (Pkey(\delta) / Ptempo()).trace(prefix: "wtrig sustain: ");
		BP(\wtrig).offset = Pseq([
			0.75,
			Pseq([
				Pn(0, { BP(\drum7).mUp1Num - 1 }),
				min(Pwhite(1, 3, 1) * 0.5, Pkey(\delta) - 0.5)
			], inf)
		]);
		BP(\drum7).messedUp1Beats = Pseq([
			Pwhite(4, 7, 1),
			Pseq([
				Pwrand(#[1, 1.5, 2, 2.5, 3], #[3, 4, 2, 1, 1].normalizeSum, { ~mUp1Num - 1 }),
				Pwhite(4, 7, 1),
			], inf)
		]);
		BP(\drum7).gest = Prout({ |inval|
			var	xstream = x.asStream,
				muPats = [
					Pn(\messedUp, y.asStream),
					Pfuncn({
						if(~collIndex == \drum7) { BP(\wtrig).triggerOneEvent(0) };
						\messedUp1
					}, Pwhite(1, Env(#[1, 1, 5], #[10, 50]), inf).round.asStream.collect { |num|
						~mUp1Num = num.debug("\nmUp1Num"); num
					})
				];
			inval = Pseq([\randsync, muPats[0], \randsync, muPats[1]])
				.embedInStream(inval);
			loop {
				if(rsyncEnv.next.coin) { inval = \randsync.embedInStream(inval) };
				inval = muPats[0].embedInStream(inval);
				inval = muPats[1].embedInStream(inval);
			};
		}).collect { |gest| ~lastGesture = gest };
		BP(\drum8).gest = Pfunc({ BP(\drum7).lastGesture });
		BP(\drum7).messedUpMulCtl.value = 1;
		18
	},

	// // 12,
	// loopCmd: (
	// 	setDoneSignal: {
	// 		// var crKeyStream = Pseq(#[cr, cr1, cr2, cr3], inf).asStream,
	// 		// 	faceFuncs = topEnvironment[\faceFuncs];
	// 		~crKeyStream = Pseq(#[cr, cr1, cr2, cr3], inf).asStream;
	// 		~fastSqueakParms = (
	// 			setDoneSignal: {
	// 				// ~crKeyStream = crKeyStream;
	// 				~doneSignal = NotificationCenter.register(\fastsqueaks, \done, \boing, e {
	// 					~stop.()
	// 				});
	// 			},
	// 			// func: {
	// 			// 	faceFuncs[\fastsqueaks].();
	// 			// },
	// 			clearDoneSignal: { ~doneSignal.remove }
	// 		)
	// 	},
	// 	cmds: [
	// 		{	// var	key = ~crKeyStream.next;
	// 			PR(\bpCmd).copy.putAll((name: ~crKeyStream.next.debug("key"), prepareBP: { |bp|
	// 				bp.gest = \fastsqueaks;
	// 			}))
	// 			// PR(\funcCmd).copy.putAll(~fastSqueakParms)
	// 		},
	// 		\cmdSync,
	// 		Quant(1),
	// 		bpCmd: (name: \wtrig, prepareBP: { |bp|
	// 			bp.reset;
	// 			bp.delta = Pwhite(2, 5, rrand(1, 4)) * 0.5;
	// 		}),
	// 		\cmdSync,
	// 		{ rrand(0.5, 1.5) }
	// 	]
	// )//,
	gcAutoSynthCmd: (gc: BP(\drum7).messedUpMulCtl, name: \ctlEnv, outName: \outbus,
		env: Env(#[1, 3], #[45]))
]).play(argClock: ~clock108);
)

BP(\wtrig).prepareForPlay;
BP(\wtrig).reset;
BP(\wtrig).use { BP(\wtrig).eventStream.next(()) }
BP(\wtrig).v[\asPattern].postcs

BP(\wtrig).asPattern = {
		~reset.();
		Pbind(
			\source, ~source,
			\delta, BPStream(\delta),
			\sustain, BPStream(\sustain),
			\offset, BPStream(\offset),
			\playChild, BPStream(\playChild)
		).collect { |ev| ~lastEvent = ev; ev }
	}

BP(\wtrig).delta.postcs

BP(\wtrig).delta = Pwhite(2, 5, inf) * 0.5;

).collect { |num|
	currentEnvironment.debug("what environment");
	num
};

u.remove;
u = Updater(BP(\wtrig), { |obj, what|
	[obj, what].debug("wtrig msg");
});

\ab0.asMode.cps(#[44, 40, 38, 37, 33, 31, 27, 25, 23])


			bp.gest = Pseq([
				// Pn(\ostFilt2, x.asStream.trace(prefix: bp.collIndex ++ " num ost bars: ")),
				Pn(\messedUp, y.asStream),
				\randsync, // \randquant,
				Pif(Ptime() < xstream.next, oldGest),
				\randsync,
				Pn(\messedUp, y.asStream),
				\randsync,
				Pfuncn({
					if(bp.collIndex == \drum7) { BP(\wtrig).triggerOneEvent(0) };
					\messedUp1
				}),
				\randsync,
				Pn(\messedUp, y.asStream),
				\randsync,
				Pseq([
					Pfuncn({
						if(bp.collIndex == \drum7) { BP(\wtrig).triggerOneEvent(0) };
						\messedUp1
					}),
					\randsync
				], inf)
			], inf)//.trace(prefix: bp.collIndex ++ " gesture: ")



// some stuff I changed, reincorporate later
BP(#[drum7, drum8]).do { |bp|
	bp.gestures.messedUpBase = { |inEv|
			var	accEv = ~accEvent.(inEv, Pkey(\delta)).asStream,
				once = false;
			Pchain(
				Pfunc({ |ev|
					var	x;
					if(ev[\doAccent]) {
						ev = accEv.next(ev).put(\wet, 0.55);
						if(once) { ev } {
							once = true;
							x = ~messedUpRatiosStream.nextN(3, ev);
							x.doAdjacentPairs { |a, b, i| x[i+1] = a*b };
							ev.put(\ffreq, ev[\ffreq] * x)
								.put(\ffreq2, ev[\ffreq2] * x);
						};
					} { ev }
				}),
				Pbind(
					\bufIndex, Pswitch1([0, Pxrand((1..4), inf)],
						Pwrand(#[0, 1], Pif(Pkey(\delta) >= (~messedUpMulCtl.asPattern * 0.25), #[0.75, 0.25], #[0.1, 0.9]), inf)
					),
					// \amp, 1,
					\amp, Pn(Plazy({ |ev|
						var	bool = 0.3.coin;
						if(bool) {
							Pn(1, ev[\numInSeg])
						} {
							Pgeom.fromEndpoints(1, rrand(0.2, 0.5), ev[\numInSeg])
						}
					}), inf),
					\rate, Pif(Pkey(\bufIndex) > 0, 1, Prand(#[0.5, 0.6], inf)),
					\start, 0,
					\pan, Plazy({ BPStream(\pan) }),
					\ffreq, Plazy({ BPStream(\lpfreq) }),
					\wet, 0
				),
				Pbind(
					\doAccent, false,
					\delta, Pn(Plazy({ |ev|
						ev[\numInSeg] = rrand(3, 9);
						ev[\doAccent] = true;
						Pgeom.fromEndpoints(*
							[rrand(0.4, 0.6), rrand(0.08, 0.2)].rotate(2.rand)
							++ [ev[\numInSeg]]
						) * ~messedUpMulCtl
					}), inf)
				)
			);
		};
};

BP(#[drum7, drum8]).do { |bp|
	bp.gestures.messedUp1 = Plazy({ |inEv|
			var	dur;
			if(~leadTime > 0) {
				// ~lastMessedUpBeats = dur = ~messedUpBeatsStream.next(inEv)
				// 	* 3 / ~messedUpMulCtl.value.round
				~lastMessedUpBeats = dur = rrand(7, 14).debug("messedup1 dur");
			} {
				dur = BP(~ctlSource).lastMessedUpBeats;
			};
			Psync(Pfin(1, ~gestures[\messedUpBase].(inEv)), dur, dur)
		})
};

BP(#[drum7, drum8]).do { |bp|
	bp.asPattern = {
		~makeStreamForKey.(\gest);
		~makeStreamForKey.(\n);
		~makeStreamForKey.(\factor);
		~makeStreamForKey.(\numBars);
		~makeStreamForKey.(\restBeats);
		#[messedUpRatios, messedUpNumEv, messedUpBeats, numAcc].do { |key|
			(key ++ "Stream").asSymbol.envirGet ?? { ~makeStreamForKey.(key) };
		};
		// w/o Pif, Event.silent results from Ppar cause this to die
		Pif(Pfunc({ |ev| ev[\type] == \rest }), Pfunc({ |ev| ev }),
			Pbind(
				\bufnum, Pindex(~buffers, Pkey(\bufIndex), inf),
				\time, Pfunc({ |ev| ~buffers[ev[\bufIndex]].asArray.collect(_.duration) })
			)
		)
		<>
		PnNilSafe(
			Plazy({
				~keepGoing = true;
				Pwhile1({ |proto, ev|
					// ~keepGoing or: { ev.delta == 0 }
					if(~keepGoing) { true }
						{ /*ev.delta.debug("~keepGoing = false; delta"); ev.debug;*/ ev.delta == 0 }
				},
					~gestures[~gestStream.next]
				)
			}),
			inf, 3  // 3 == don't force a stop on the first empty embed
		);
	}
};


		.collect { |bts|
			(if(bts < 5) { bts }
				{ bts * #[0.1, 0.2, 0.3, 1.0].wchoose(#[0.2, 0.2, 0.2, 0.4]) }
			).round
		};

			// if(bp.collIndex == \drum7) {
				bp.gest = bp.gest.trace(prefix: bp.collIndex ++ " gesture: ");
			// };
		};
BP(\cwd).pitchedtime.postcs



// introduce some lpc in H1010
();
BP(\sw).free;
\chuckIf.eval(Fact(\words), BP, \sw, nil, Library.at(\rvbs));

p = BP(\sw);
p.synth.postcs
p.pitchProb.value  // 0 by default

p.v.env.keys.asArray.sort.do { |key|
	if(key.asString.beginsWith("noisy")) { [key, p[key]].postcs };
}; ""

p.noiseenv.postcs
p.noiseenv = Env(#[0, 1, 0.5, 0], #[0.05, 0.45, 0.5], -4);

p.noisydelta = Pwhite(1, 8, inf) * 0.25;
p.noisytime = Pkey(\delta) * Pwhite(0.5, 0.8, inf);
p.noisytime = Pwhite(0.3, 0.6, inf);

p.noisydelta = Pswitch([
	Pwhite(1, 8, { rrand(4, 9) }) * 0.25,
	Plazy({ var x = rrand(0.12, 0.19); Pseq([Pn(x, rrand(4, 8)), x*2], 1) }),
	Pwhite(3.5, 6.5, 1)  // note+rest
], Pseq([0, Pwrand(#[0, 1, 2], #[0.75, 0.15, 0.1], inf)])/*.trace(prefix: "delta index: ")*/); //.trace(prefix: "delta: ");

p.wetCtl.gui;
p.normAmpCtl.gui;

w = GenericGlobalControl(\lpcwet, nil, 1);
w.gui;

p.event.wet = w.asMap;

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;

p.debug = true;
p.debug = false;

p.reset;

p.use { e = ~eventStream.next(~event.copy) }; e.play;

w.bus.get(_.postln);

e.keys
e.msgArgs

