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

[p, q].free;
BP(\drum7).free;
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
	], inf).trace(prefix: bp.collIndex ++ " gesture: ")
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