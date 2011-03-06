// Affectations: Head controller sequence

// TLSequenceIterators for drums
// I need extra ones because they use a different clock
// They wait for signals from the drones to advance through the sequence
var	t2;

// HACK
var drumLevel = -7.dbamp;

(Document.current.path.dirname.dirname +/+ "/head/head-defs.scd")/*.debug*/.loadPath;
// ("/home/dlm/share/SuperCollider/scd/kc.git/trunk/head/head-defs.scd")/*.debug*/.loadPath;

PR(\bpCmd).clone {
	~setDoneSignal = {
		~playing = if(BP(\drum5).isPlaying) { \drum5 } { \drum6 };
		~name = if(~playing == \drum5) { \drum6 } { \drum5 };
		BP(~playing).stop(~quant);
	};
	~prepareBP = { |bp| ~extraPrep.(bp); bp.reset };
} => PR(\swap56cmd);

PR(\funcCmd).copy.putAll((
	setDoneSignal: {
		~doneSignal = Updater(~subIter, e { |obj, what, cmds|
			// "subIterCmd '%' got update: %".format(~id, [what, cmds]).debug;
			if(what == \done) {
				~doneSignal.remove;
				// "Updater calling ~stop".debug;
				~stop.((activeCmds: cmds))
			};
		});
		~setUserSignal.();
	},
	clock108: topEnvironment[\clock108],
	func: {
		~subIter.play(argClock: ~clock108 ? TempoClock.default);
	},
	done: { |parms|
		// oh, this is REALLY f*ked up
		// if the subiterator stops, the Updater fires FROM WITHIN THE ROUTINE
		// then this forcibly stops the routine early
		// causing this func never to return
		// that interrupts the subIterCmd's cleanup process
		// how many gray hairs from trying to find THAT one?
		// I tried to fix it in TLSequenceIterator but maybe it didn't take, so...
		if(~subIter.isRunning) { ~subIter.stop(parms) };
	},
	clearDoneSignal: { |parms|
		~doneSignal.remove;
		~doneSignal = nil;
		~clearUserSignal.(parms);
	},
	collIndex: \subIterCmd  // chuck => PR doesn't automatically set this
)) => PR(\subIterCmd);


// drums - run parallel to drones
t2 = [
	TLSequenceIterator([
		{	var	bp = BP(\drum1);
			bp.bar = 3;
			bp.wetCtl.value = 0.98;
			bp.fdecCtl.value = 0.25;
			bp.ffLowCtl.value = 2;
			bp.ffRangeCtl.value = 0;
			BP.all.do { |bp|
				if(bp.collIndex.asString.contains("drum")) {
					bp[\chan].tryPerform(\level_, drumLevel);
				};
			};
			// 0
			rrand(5.0, 8.0) * 108/60
		},
		// waitForNotesCmd, \cmdSync,
		Quant(3, -0.5),

		gcAutoSynthCmd: (gc: { BP(\drum1).distCtl }, /*shouldSync: false,*/ name: \ctlEnv, outName: \outbus,
			connect: 0, time: 36, env: Env(#[20, 5], #[1], 1)),
		bpCmd: (name: \drum1, quant: `nil, /*shouldSync: false,*/ prepareBP: { |bp|
			bp.bar = Pseq(#[3, 0], inf);
		}),
		12,
		gcAutoSynthCmd: (gc: { BP(\drum1).wetCtl }, name: \ctlPoint, /*shouldSync: false,*/ outName: \outbus,
			value: 0.078, time: 30, curve: 0),
		bpCmd: (name: \drum2, quant: `nil, /*shouldSync: false,*/ prepareBP: { |bp|
			bp.bar = Pseq(#[0, 2], inf);
		}),
		12,

		TLSequenceIterator([
			{	BP(\drum1).bar = Pseq([3, Prand(BP(\drum1).indices[1], 1)], inf);
				12
			},
			{	BP(\drum2).bar = Prand(BP(\drum2).indices[1], inf);
				12
			},

			{	BP(\drum2).bar = Prand(#[1, 2, 3], inf);
				12
			}
		]) //.shouldSync_(false)
	]).shouldSync_(false),
	TLSequenceIterator([
		{ rrand(5.0, 8.0) * 108/60 },
		Quant(3, -0.5),
		gcAutoSynthCmd: (gc: { BP(\drum1).ffRangeCtl }, /*shouldSync: false,*/ name: \ctlEnv, outName: \outbus,
			env: Env(#[0, 14, 0], #[0.6, 0.4], #[6, -2]), time: 30, connect: 0),
		bpCmd: (name: \drum3, quant: `nil, /*shouldSync: false,*/ prepareBP: { |bp|
			bp.bar = Prand(#[8, 2], inf);
			bp.ffreqCtl.value = 360;
		}),
		mixerAutoSynthCmd: (mixer: { BP(\drum3).chan }, /*shouldSync: false,*/ name: \ctlEnv, outName: \outbus,
			connect: 0, env: Env([-16.dbamp, drumLevel], #[18], 2.4)),
		gcAutoSynthCmd: (gc: { BP(\drum3).ffreqCtl }, /*shouldSync: false,*/ name: \ctlPoint, outName: \outbus,
			value: 18000, time: 30, curve: 5),

		12,
		{	BP(\drum3).bar = Prand([8, 2], inf) + Prand(#[0, 1, 4], inf);
			BP(\drum2).bar = 3;
			12
		},

		{	BP(\drum3).bar = Prand(BP(\drum3).indices[2], inf);
			12
		},

		{	BP(\drum3).bar = Prand(BP(\drum3).indices[[2, 3]].flat, inf);
			BP(\drum1).bar = 3;
			12
		},

		{	BP(\drum3).bar = 15;
			6
		},
		{ NotificationCenter.notify(\drumIter1, \done); 1 }
	]).shouldSync_(false),

	TLSequenceIterator([
//		{ rrand(5.0, 8.0) * 108/60 },
		Quant(3, -0.5),
		{ BP(#[drum1, drum2, drum3]).stop; 0 },
		bpCmd: (name: #[drum4, drum5], quant: `nil, shouldSync: false, prepareBP: { |bp|
			var	panEnd = -1;
			bp.reset;
			if(bp.collIndex == \drum5) {
				bp.quant = #[-1, 0.02];
				panEnd = 1;
				bp.amp = Pseq(#[1, 1 /* finger-amp */], inf) * Env(#[0, 1], #[12], 2.4)
			};
			bp.pan = Env([0, panEnd], #[30]);
			bp.wetCtl.value = 0.078;
			bp[\chan].level = drumLevel;
		}),

		18,
		gcAutoSynthCmd: (gc: { BP(\drum4).ffRangeCtl }, name: \ctlPoint, outName: \outbus,
			value: 18, time: 36),
		loopCmd: (
			// this way will force quantPhases to reset
			setDoneSignal: {
				~quantPhases = Pseq(#[0.25, 1.25, 0.75], inf).trace(prefix: "drum56 phase: ").asStream;
			},
			cmds: [
				{
					PR(\swap56cmd).copy.putAll((quant: [-1, ~quantPhases.next], extraPrep: { |bp|
						bp.amp = Pseq(#[1, 1 /* finger-amp */], inf);
						bp[\chan].level = drumLevel;
					}, shouldSync: false))
				},
				24
			],
			autoSync: false  // else swap56cmd prevents loop from advancing
		),
		funcCmd: topEnvironment[\trigParms],
		\cmdSync,
		{	NotificationCenter.notify(\drumIter2, \done);
			1
		}
	]).shouldSync_(false),

	TLSequenceIterator([
//		{ rrand(5.0, 8.0) * 108/60 },
		Quant(1, -0.05),
		{
			var c = thisThread.clock;
			c.setMeterAtBeat(3, c.nextTimeOnGrid(1));
			0
		},
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
			num3: rrand(5, 9),
			func: {
				var	thisCmd = currentEnvironment;
				BP(#[drum7, drum8]).do { |bp|
					// ~num3 = ~num3 + 5;
					bp.gest = Pseq([
						CleanupStream(
							Pseq([\threePl1, Pn(\threeAcc, ~num3), \randquant /*\ostFilt2Quant*/]).asStream,
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

		{
			var	thisLoop = PR(\loopCmd).copy.putAll((
				repeats: 2,
				qphase: Pseq(#[1.25, 0.75], inf).asStream,
				// acc: Pseq([\threeAcc, Prand(#[fiveAcc, sevenAcc], inf)]).asStream,
				acc: Prand(#[fiveAcc, sevenAcc], inf).asStream,
				cmds: [
					{ rrand(2, 4) * 3 },
					funcCmd: (
						setDoneSignal: { ~doneSignal = true },
						func: {
							var	numAcc = rrand(4, 6), acc = thisLoop.acc.next,
								pat = Pseq([\ostFilt2Sync, Pn(acc, numAcc), \ostFilt2Quant], 1),
								stream;
							BP(\drum7).override(\gest, CleanupStream(pat.asStream, e { ~stop.() }));
							BP(\drum8).override(\gest, pat);
							BP(\drum8).quant = [-1, thisLoop.qphase.next];
						}
					),
					\cmdSync
				]
			));
			thisLoop
		},
		\cmdSync,
		6,

		{
			BP(\drum8).gest = Library.at(\drum78AccGest);
		// 	6
		// },
		/*{*/
			BP(\drum7).gest = BP(\drum8).gest;
			12 //24
		},

		loopCmd: (// repeats: 3,
			acc: Prand(#[threeAcc, fiveAcc, sevenAcc], inf),
			id: \accentLoop,
			cmds: [
				{	var	// both 7+8 use the same random seed
					pat = Pseed(Pn(Date.seed, 1), Pseq([
						Pif(Ptime() < rrand(8, 11), Pseq([\randsync, ~acc], 1)),
						\randquant
					], 1));
					BP(#[drum7, drum8]).do { |bp|
						bp.keepGoing = false/*.debug("set % keepGoing".format(bp.collIndex))*/;
						bp.override(\gest, pat);
					};
					BP(\drum8).quant = -1;
					// override is guaranteed to end first because it's at most 11 beats
					rrand(2, 4) * 6
				}
			],
			clearDoneSignal: {
				// but, cmd may terminate while overriding -- clean up
				BP(#[drum7, drum8]).do { |bp|
					bp.unOverride(\gest);
				};
			}
		),

		funcCmd: topEnvironment[\trigParms].copy.put(\eventID, 2),
		\cmdSync,
		funcCmd: (func: {
			~iterator.findActive(\accentLoop).stop
		}),
		Quant(1, -0.05),
		{
			var c = thisThread.clock;
			c.setMeterAtBeat(3, c.nextTimeOnGrid(1));
			BP(#[drum7, drum8]).do(_.keepGoing = false);
			0
		},

		{
			var x = (Pseed(Pn(Date.seed, 1), Pwhite(2, 4, inf)) / BP(\drum7).messedUpMulCtl).round * 3,
				y = (Pseed(Pn(Date.seed + 234321, 1), Pwhite(3, 9, inf))
					* Env(#[1, 0.075], #[80], 0.5).asStream).round,
				oldGest = Library.at(\drum78AccGest),
				q1 = BasicTimeSpec(1), qbar = BasicTimeSpec(-1),
				rsyncEnv = Env(#[1, 0], #[90], 1.4).asStream;

			BP(\drum7).gest = Pseq([
				Pseq([
					// Pn(\ostFilt2, x.asStream.trace(prefix: bp.collIndex ++ " num ost bars: ")),
					\randquant,
					Pn(\messedUp, y.asStream),
					Pfuncn({ ~quant = qbar; \randquant }),
					Pif(Ptime() < Pstutter(1e6, x.asStream), oldGest),
				], 2),
				Prout({ |inval|
					var	xstream = x.asStream,
						muPats = [
							Pn(\messedUp, y.asStream),
							Pfuncn({
								if(~collIndex == \drum7) { BP(\wtrig).triggerOneEvent(0) };
								\messedUp1
							}, Pwhite(1, Env(#[1, 1, 5], #[10, 50]), inf).round.asStream
								.collect { |num| ~mUp1Num = num; num }
							)
						];
					NotificationCenter.notify(\drum7, \disintegrationAdvance);
					inval = Pseq([\randsync, muPats[0], \randsync, muPats[1]])
					.embedInStream(inval);
					loop {
						if(rsyncEnv.next.coin) { inval = \randsync.embedInStream(inval) };
						inval = Pseq(muPats, 1).embedInStream(inval);
						// inval = muPats[1].embedInStream(inval);
					};
				})
			]).collect { |gest| ~lastGesture = gest };
			BP(\drum8).gest = Pfunc({ BP(\drum7).lastGesture });
			BP(\drum7).messedUpMulCtl.value = 1;
			BP(\wtrig).delta = Pfunc({ BP(\drum7).lastMessedUpBeats });
			BP(\wtrig).sustain = (Pkey(\delta) / Ptempo());
			BP(\wtrig).ffreqTopCtl.value = 18000;
			BP(\wtrig).distCtl.value = 8;
			BP(\wtrig).ampCtl.value = 0.7;
			BP(\wtrig).playAttack = true;
			BP(\wtrig).offset = Pseq([
				0.75,
				Pseq([
					Pn(0, { BP(\drum7).mUp1Num - 1 }),
					min(Pwhite(1, 3, 1) * 0.5, Pkey(\delta) - 0.5)
				], inf)
			]);
			BP(\cwd).use {
				~pitchProb.value = 1;
				~ampCtl.value = 17.dbamp;
				~pitchednormAmp = ~ampCtl.asMap.asPattern;
				~pitchedenv = [Env(#[0, 1, 0.35, 0.35, 0], #[0.01, 0.1, 0.69, 0.2], -4)];
				~pfreq = (Paccumbounce(35, 46, Pwrand(#[-2, -1, 1, 2], #[0.2, 0.2, 0.3, 0.3], inf), inf)
					-.x Pseries(0, Pwhite(1, 4, Pkey(\numInChord).asStream)))
				.clump(Pfunc({ |ev| ev[\numInChord] = rrand(7, 11); ev[\numInChord] }))
				.collect { |deg, ev| Mode(ev[\mode]).cps(deg) };
				~pitchedSlideProb = Env(#[0, 0.5], #[45], 2);
				~pitchedtime = Pfunc({ BP(\wtrig).lastEvent.sustain });
				~preparePlay.();
			};
			BP(\drum7).messedUp1Beats = Pseq([
				Pwhite(4, 7, 1),
				Pseq([
					Pwrand(#[1, 1.5, 2, 2.5, 3], #[3, 4, 2, 1, 1].normalizeSum, { ~mUp1Num - 1 }),
					Pwhite(4, 7, 1),
				], inf)
			]);
			0
			// 18
		},

		{	BP(#[drum4, drum5, drum6]).stop;
			BP(\drum7).pan = -1;
			BP(\drum8).pan = 1;
			BP(\drum7).quant = -1;
			BP(\drum8).quant = #[-1, 0.75];
			BP(\drum7).distCtl.value = 5;
			BP(\drum7).finalLpfCtl.value = 18000;
			0
		},

		// bpCmd: (name: #[drum7, drum8], quant: -1, /*shouldSync: false,*/ prepareBP: { |bp|
		// 	bp.ostFiltCtl.value = 1;
		// 	bp.fmltDcyCtl.value = 0.25;
		// 	bp.fmltWetCtl.value = 0.1;
		// 	bp[\chan].level = -7.dbamp;
		// }),

		funcCmd: (
			setDoneSignal: {
				~doneSignal = NotificationCenter.register(\drum7, \disintegrationAdvance, \wait, e{
					~stop.();
				});
			},
			clearDoneSignal: { ~doneSignal.remove }
		),
		\cmdSync,

		gcAutoSynthCmd: (gc: { BP(\drum7).messedUpMulCtl }, name: \ctlEnv, outName: \outbus,
			env: Env(#[1, 3], #[45])),

		12,
		[	0.05,
			{
				PR(\gcAutoSynthCmd).copy.putAll((
					gc: BP(\drum7).finalLpfCtl, name: \bassVelMap, outName: \outbus,
					inbus: BP(\drum7).distCtl.bus,
					inMin: 5, inMax: 20, outMin: 18000, outMax: 400, slewUp: 1e6, slewDown: 1e6
				))
			},
			20,
			gcAutoSynthCmd: (gc: { BP(\wtrig).distCtl }, name: \ctlPoint, outName: \outbus,
				value: 20, time: 100),
			gcAutoSynthCmd: (gc: { BP(\wtrig).ffreqTopCtl }, name: \ctlPoint, outName: \outbus,
				value: 300, time: 140, curve: -2.1),
			gcAutoSynthCmd: (gc: { BP(\wtrig).ampCtl }, name: \ctlPoint, outName: \outbus,
				value: 0, time: 150, curve: -2.1,
				stopAction: { BP(\wtrig).playAttack = false }
			),
			70,
			gcAutoSynthCmd: (gc: { BP(\cwd).ampCtl }, name: \ctlPoint, outName: \outbus,
				value: 0, time: 125, curve: -2.1),
		],
		gcAutoSynthCmd: (gc: { BP(\drum7).distCtl }, name: \ctlEnv, outName: \outbus,
			env: Env(#[5, 20], #[120]))
	]).shouldSync_(false)
];


~faceFuncs = (
	bloop: { BP(\bl).triggerOneEvent(0) },
	squeak: {
		// note, this should only be run in an environment that has a crKeyStream
		var	key = ~crKeyStream.next;
		BP(key).gest = \squeak;
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


[
	// face dance coming

	// PR(\tlsAff).copy.putAll((
	// 	name: "H1000-face dance 1",
	// 	segID: 1000,
	// 	initProcesses: {
	// 		\chuckIf.eval(Fact(\bloops), BP, \bl, nil, Library.at(\rvbs));
	// 	},
	// 	unloadProcesses: { BP(\bl).free },
	// 	seqPattern: {
	// 		Pn((
	// 			sequence: [
	// 				// using loopCmd b/c I want to trade gestures between procs
	// 				loopCmd: (
	// 					// crKeyStream: Pseq(#[cr, cr1, cr2, cr3], inf).asStream,
	// 					cmds: [
	// 						{
	// 							topEnvironment[\faceFuncs][\bloop].value;
	// 							if(0.8.coin) { rrand(3.0, 5.5) } { rrand(1.0, 1.8) }
	// 						}
	// 					]
	// 				)
	// 			],
	// 			// onStop: {},
	// 			dur: \trigger,  // or \sync
	// 			id: 1010,  // trig id
	// 			init: Func(\nextThingTrig).v,
	// 			clear: Func(\clearNextTrig).v
	// 		), 1)
	// 	}
	// )),

	PR(\tlsAff).copy.putAll((
		name: "H1000-eye rolls",
		segID: 1000,
		initProcesses: {
	 		\chuckIf.eval(Fact(\bloops), BP, \bl, nil, Library.at(\rvbs));
			\chuckIf.eval(Fact(\creaks), BP, \cr, nil, Library.at(\rvbs));
			(1..3).do { |i|
				var	bp;
				bp = \chuckIf.eval(PR(\creaks), BP, ("cr" ++ i).asSymbol, nil, (
					chan: BP(\cr).chan,
					buf: BP(\cr).buf
				).putAll(Library.at(\rvbs))) ?? { BP(("cr" ++ i).asSymbol) };
				0 => bp;
				bp.printStopMsg = false;
			};
		},
		unloadProcesses: { BP(#[bl, cr, cr1, cr2, cr3]).free },
		crKeyStream: Pseq(#[cr, cr1, cr2, cr3], inf).asStream,
		seqPattern: {
			Pn((
				sequence: [
					{
						BP(\bl).synth = Prand(#[sinb, oscb], inf);
						BP(\bl).oscbnormAmp = 0.68;
						0
					},
					loopCmd: (
						id: \blooploop,
						setDoneSignal: {
							// ~doneSignal = nil;
							~gest = Pif(
								Pwhite(0.0, 1.0, inf) < Env(#[0, 0.65], #[40], 2.5),
								Prand(#[squeak, smoothsqueaks], inf),
								\bloop
							).asStream
						},
						dur: 40,
						crKeyStream: ~crKeyStream,
						cmds: [
							{
								topEnvironment[\faceFuncs][~gest.next].value;
								if(0.8.coin) { rrand(3.0, 5.5) } { rrand(1.0, 1.8) }
							}
						]
					),
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
					funcCmd: (
						crKeyStream: ~crKeyStream,
						func: {
							~iterator.findActive(\blooploop).stop;
							topEnvironment[\faceFuncs][\squeakfall].value
						}
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 1010,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "H1010-tongue rolls",
		segID: 1010,
		initProcesses: {
			\chuckIf.eval(Fact(\slurps), BP, \wet, nil, Library.at(\rvbs));
			\chuckIf.eval(Fact(\words), BP, \qw, nil, Library.at(\rvbs));
		},
		unloadProcesses: { BP(#[wet, qw]).free },
		preparePlay: {
			// kind of hacky, but necessary because...
			// keeping a reference to the section sequencer in a section
			// would create an infinitely recursive data structure... that's worse than this hack
			~crKeyStream = topEnvironment[\seq].sections.detect { |sect| sect.segID == 1000 }
				.tryPerform(\crKeyStream) ?? {
					"Could not find ~crKeyStream in segment 1000".warn;
				};
		},
		seqPattern: {
			Pn((
				sequence: [
					// all 3 now
					{ BP(\bl).synth = Prand(#[sinb, oscb, buzz], inf); 0 },
					loopCmd: (
						id: \blooploop,
						setDoneSignal: {
							// ~doneSignal = nil;
							~gest = Pswitch1([
								Prand(#[squeak, smoothsqueaks], inf),
								\bloop, \wet
							], Pwrand(#[0, 1, 2], #[0.5, 0.4, 0.1], inf)).asStream
						},
						// dur: 40,
						crKeyStream: ~crKeyStream,
						cmds: [
							{	var	gest = ~gest.next;
								// if \wet is busy, get another gesture
								if(gest == \wet and: { BP(\wet).isPlaying }) {
									while { (gest = ~gest.next) == \wet };
								};
								topEnvironment[\faceFuncs][gest].value;
								rrand(1.0, 1.8)
							}
						]
					),
					30,
					// shouldSync: true -- should stop this when going to next segment
					bpCmd: (name: \qw, shouldSync: true, prepareBP: { |bp|
						bp.pitchProb.value = 0;
						bp.noisydelta = Pswitch([
							Pwhite(1, 8, { rrand(4, 9) }) * 0.25,
							Plazy({
								var x = rrand(0.12, 0.19);
								Pseq([Pn(x, rrand(4, 8)), x*2], 1)
							}),
							Pwhite(3.5, 6.5, 1)  // note+rest
						], Pseq([0, Pwrand(#[0, 1, 2], #[0.75, 0.15, 0.1], inf)]));
						bp.noisytime = Pwhite(0.3, 0.6, inf);
						bp.word = Plazy({
							var	items = ~pts.select { |pt|
								~questionKeys.includesEqual(pt[\id])
							};
							Prand(items, inf)
						});
						bp.noiseenv = Env(#[0, 1, 0.5, 0], #[0.05, 0.45, 0.5], -4);
						bp.wetCtl.value = 0;
						// reset others?
					}),
					20,
					gcAutoSynthCmd: (gc: BP(\qw).wetCtl, name: \ctlPoint, outName: \outbus,
						value: 0.75, time: 30)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 1020,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "H1020-mouth opens",
		segID: 1020,
		initProcesses: {
			topEnvironment[\seq].sections.do { |sect|
				if(sect.segID < 1000) { sect.prUnload };
			};

			\chuckIf.eval(Fact(\words), BP, \sw, nil, Library.at(\rvbs));
		},
		unloadProcesses: { BP(\sw).free },
		preparePlay: {
			~crKeyStream = topEnvironment[\seq].sections.detect { |sect| sect.segID == 1000 }
				.tryPerform(\crKeyStream) ?? {
					"Could not find ~crKeyStream in segment 1000".warn;
				};
		},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \sw, shouldSync: false, id: \sw, prepareBP: { |bp|
						bp.pitchProb.value = 0;
						bp.synth = \noisy;
						// bp.synth = Plazy({ Pif(Pwhite(0.0, 1.0, inf) < ~pitchProb,
						// 	\pitched, \noisy);
						bp.noisydelta = Pwhite(3.0, 6.0, inf);
						bp.noisytime = Pkey(\delta).linlin(3.0, 6.0, 4.0, 9.0);
						bp.word = Plazy({
							var	items = ~pts.select { |pt|
								~questionKeys.includesEqual(pt[\id])
							};
							Prand(items, inf)
						});
						bp.noiseenv = Env.linen(0.2, sustainTime: 0.45, releaseTime: 0.35);
						bp.wetCtl.value = 1;
						// reset others?
					}),
					// run in parallel to words
					14, // { rrand(7.0, 10.0) },
					loopCmd: (
						id: \blooploop,
						shouldSync: false,
						dur: 70,
						setDoneSignal: {
							// ~doneSignal = nil;
							~gest = Pswitch1([
								Prand(#[squeak, smoothsqueaks], inf),
								\bloop, \wet
							], Pwrand(#[0, 1, 2], #[0.3, 0.6, 0.1], inf)).asStream;
							~deltas = Pseq([
								Pwhite(0.4, 1.1, { rrand(2, 9) }),
								Pwhite(2.2, 4.1, { rrand(1, 3) })
							], inf).asStream * Env(#[1, 5], #[60], 2.4).asStream;
						},
						// dur: 40,
						crKeyStream: ~crKeyStream,
						cmds: [
							{	var	gest = ~gest.next;
								// if \wet is busy, get another gesture
								if(gest == \wet and: { BP(\wet).isPlaying }) {
									while { (gest = ~gest.next) == \wet };
								};
								topEnvironment[\faceFuncs][gest].value;
								~deltas.next
							}
						]
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 1030,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "H1030-emotions",
		segID: 1030,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \sw, shouldSync: false, playWarning: false),
					gcAutoSynthCmd: (gc: { BP(\sw).pitchProb }, name: \ctlEnv, outName: \outbus,
						env: Env(#[0.35, 0.95], #[1], #[-1.5]), time: 40,
						connect: 0, shouldSync: false),
					{	var	e = Env(#[1, 0.18], #[30], -1.4).asStream;
						BP(\sw).noisydelta = Pwhite(3.0, 6.0, inf) * e;
						BP(\sw).noisytime = (Pkey(\delta) / e).linlin(3.0, 6.0, 4.0, 9.0) * e;
						BP(\sw).pitcheddelta = Pwhite(1.5, 4.0, inf) * e;
						// BP(\sw).pitchedtime = Pkey(\delta) * Pwhite(1.4, 2.1, inf);
						BP(\sw).word = Plazy({
							Pn(Pser(~pts, { rrand(3, 7) }, { ~pts.size.rand }), inf)
						});
						BP(\sw).synth = Pseq([
							Pn(\pitched, 2),
							Plazy({ Pif(Pwhite(0.0, 1.0, inf) < ~pitchProb, \pitched, \noisy) })
						]);
						0
					},
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
/*
					funcCmd: (func: {
						var	bp = BP(\sw), cmd;
						bp.word = Plazy({ Prand(~pts, inf) });
						bp.pitcheddelta = Pwhite(0.1, 0.4, inf);
						bp.pitchedtime = Pkey(\delta) * Pwhite(1.4, 2.1, inf);
						if((cmd = ~iterator.findActive(\blooploop)).notNil) {
							cmd.gest = Pswitch1([
								Prand(#[squeak, smoothsqueaks], inf),
								\bloop
							], Pwrand(#[0, 1], #[0.3, 0.7], inf)).asStream;
							cmd.deltas = Pwhite(0.2, 0.6, inf).asStream;
						} { "whoops! couldn't find blooploop" };
					}),
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
*/
					funcCmd: (func: {
						var	manualStop = (manualStop: true);
						~iterator.activeCmds.copy.do { |cmd|
							if(cmd !== currentEnvironment) { cmd.stop(manualStop) }
						};
					})
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 1500,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	// PR(\tlsAff).copy.putAll((
	// 	name: "",
	// 	segID: 0,
	// 	initProcesses: {},
	// 	unloadProcesses: {},
	// 	seqPattern: {
	// 		Pn((
	// 			sequence: [
	// 			],
	// 			// onStop: {},
	// 			dur: \trigger,  // or \sync
	// 			id: 0,  // trig id
	// 			init: Func(\nextThingTrig).v,
	// 			clear: Func(\clearNextTrig).v
	// 		), 1)
	// 	}
	// )),

	// drones

	PR(\tlsAff).copy.putAll((
		name: "H1500-low + harmonics",
		segID: 1500,
		initProcesses: {
			\chuckIf.eval(Fact(\mstClock), BP, \mstClock, nil, Library.at(\rvbs));

			\chuckIf.eval(PR(\hs1), BP, \hs, nil, (
				makeGResponder: 0, removeGResponder: 0
			).putAll(Library.at(\rvbs)));
			\chuckIf.eval(Fact(\hstrig), BP, \hstrig, nil, Library.at(\rvbs));
		},
		unloadProcesses: {
			BP(#[hstrig, hs]).free;
		},
		seqPattern: {
			Pn((
				sequence: [
					// if event trig was skipped, bloops might keep going
					funcCmd: (func: {
						~iterator.findActive(\blooploop).stop;
						~iterator.findActive(\sw).stop;
					}),
					{	BP(\hs).low_(2).high_(24);
						#[chan, chan2].do { |key| BP(\mstClock)[key].level = -15.dbamp };
						// topEnvironment[\master].level = ~mVol.value.dbamp;
						1
					},
					bpCmd: (name: \mstClock, shouldSync: false
						/*, prepareBP: { |bp|
							bp.tempoCtl.value = 0.1;
							}*/
					),
					gcAutoSynthCmd: (shouldSync: false,
						gc: BP(\mstClock).tempoCtl, name: \ctlEnv, outName: \outbus,
						connect: 0, env: Env(#[0.1, 0.1, 0.5, 0.245], #[30, 25, 25], 3.5), time: 1
					),
					6,
					bpCmd: (name: \hs, shouldSync: false, prepareBP: { |bp|
						bp.use {
							~lastRise = 1;
							~rat = Pswitch1([
								Pwhile1({ |in, item| ~lastRise = item; item <= ~high }, Pseries(~low, 1, inf)),
								(Pexprand(Pfunc { ~low }, Pfunc { ~high }, inf)
									.round(1).reject { |x| ~activeRatios.includes(x) });
							], Pfunc {
								(~lastRise.linexp(~low, ~high, 0.005, 1).coin
									or: { ~activeRatios.includes(~lastRise+1.0) })
								.binaryValue
							});
						};
					}),
					0.1,
					// this guy fires the streams
					bpCmd: (name: \hstrig, doReset: true, shouldSync: false,
						prepareBP: { |bp|
							bp.delta = Pexprand(0.04, 0.2, inf)
								* Plazy({ Env(#[20, 1], #[90], \exp).asStream });
						},
						setDoneSignal: { |bp|
							~doneSignal = Updater(BP(\hs), e { |obj, what|
								if(what == \allChildrenStopped) {
									~doneSignal.remove;
									BP(\hs).stop;
								}
							});
						}
					),
					25
				],
				// onStop: {},
				dur: \sync, // \trigger,  // or \sync
				id: 1510 //,  // trig id
				// not used because dur is \sync
				// init: Func(\nextThingTrig).v,
				// clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	// PR(\tlsAff).copy.putAll((
	// 	name: "H1510-start sweeps",
	// 	segID: 1510,
	// 	initProcesses: {
	// 		\chuckIf.eval(PR(\hsSweep), BP, \hswp, nil, Library.at(\rvbs));
	// 	},
	// 	unloadProcesses: { BP(\hswp).free },
	// 	seqPattern: {
	// 		Pn((
	// 			sequence: [
	// 				bpCmd: (name: \mstClock, shouldSync: false, playWarning: false),
	// 				bpCmd: (name: #[hs, hstrig], shouldSync: false, playWarning: false),
	// 				bpCmd: (name: \hswp, shouldSync: false, prepareBP: { |bp|
	// 					bp.debug.lowhCtl.value = 2;
	// 					bp.tophCtl.value = 2;
	// 				}),
	// 				TLSequenceIterator([
	// 					gcAutoSynthCmd: (
	// 						gc: BP(\hswp).tophCtl, shouldSync: false, name: \ctlPoint, outName: \outbus,
	// 						value: 32, time: 18, curve: 1.6,
	// 						setDoneSignal: {
	// 							~upd = Updater(~gc, e { |obj, msg|
	// 								var	val;
	// 								if(msg[\what] == \value and: { (val = ~gc.value.asInteger) > BP(\hs).low }) {
	// 									if(val < BP(\hs).high) {
	// 										BP(\hs).low = max(val - 12, 2);
	// 									} {
	// 										BP(#[hstrig]).stop;
	// 									}
	// 								};
	// 							});
	// 						},
	// 						clearDoneSignal: { ~upd.remove }
	// 					),
	// 					16,
	// 					gcAutoSynthCmd: (
	// 						gc: BP(\hswp).tophCtl, shouldSync: false, name: \ctlPoint, outName: \outbus,
	// 						value: 31, time: 18, curve: 1.6,
	// 						clearDoneSignal: { BP(\hswp).stop }
	// 					)
	// 				]).shouldSync_(false),
	// 				10,
	// 			],
	// 			// onStop: {},
	// 			dur: \sync, // \trigger,  // or \sync
	// 			id: 1520,  // trig id
	// 			init: Func(\nextThingTrig).v,
	// 			clear: Func(\clearNextTrig).v
	// 		), 1)
	// 	}
	// )),

	PR(\tlsAff).copy.putAll((
		name: "H1520-drone+formants",
		segID: 1520,
		initProcesses: {
			\chuckIf.eval(PR(\trajectories), BP, \trajHead);
			\chuckIf.eval(Fact(\formantfx1), BP, \fmt, nil, Library.at(\rvbs));
			\chuckIf.eval(PR(\hsDrone), BP, \hsd, nil, (
				maxTop: 40,
				trajectoryKey: \trajHead
			).putAll(Library.at(\rvbs)));
		},
		unloadProcesses: {
			fork {
				var	oldMstClock = BP(\mstClock);
				BP(#[/*traj,*/ fmt, hsd]).free;
				5.0.wait;
				if(BP(\mstClock) === oldMstClock) {
					oldMstClock.free;  // making durned sure this is the last one to go
				};
			}
		},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \mstClock, shouldSync: false, playWarning: false),
					bpCmd: (name: \hswp, shouldSync: false, playWarning: false),
					bpCmd: (name: \hsd, shouldSync: false, prepareBP: { |bp|
						bp.tophCtl.value = 2;
						bp.ampCtl.value = 0.2;
					}),
					gcAutoSynthCmd: (
						gc: BP(\hsd).tophCtl, shouldSync: false, name: \ctlPoint, outName: \outbus,
						value: 24, time: 20, curve: 1.6,
						setDoneSignal: {
							~upd = Updater(~gc, e { |obj, msg|
								var	val;
								if(msg[\what] == \value and: { (val = ~gc.value.asInteger) > BP(\hs /* was: \hswp */).low }) {
									if(val < BP(\hs).high /*val < BP(\hswp).tophCtl.value*/) {
										// BP(\hswp).lowhCtl.value = val+1;
										BP(\hs).low = val+1;
									} {
										BP(\hs /* was: \hswp */).stop;
									}
								};
							});
						},
						clearDoneSignal: { ~upd.remove; BP(\hs /* was: \hswp */).stop }
					),
					funcCmd: (
						setDoneSignal: {
							~doneSignal = Updater(BP(\hsd).tophCtl, e { |obj, event|
								if(event[\what] == \value and: { obj.value >= 15 }) {
									~stop.();
								}
							});
						},
						clearDoneSignal: {
							~doneSignal.remove
						}
					),
					\cmdSync,
					// 6,
					bpCmd: (name: \fmt, shouldSync: false, prepareBP: { |bp|
						bp.fadeIn = 18;
						bp.fadeOut = 12;
					}),
					12,
				],
				// onStop: {},
				dur: \sync, // \trigger,  // or \sync
				id: 1530,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "H1530-sung 1",
		segID: 1530,
		initProcesses: {
			\chuckIf.eval(PR(\counterpoint), BP, \cpt, nil,
				(printStopMsg: false).putAll(Library.at(\rvbs)));
			0 => BP(\cpt);

			\chuckIf.eval(PR(\cadences), BP, \cd, nil,
				(parentBP: \cpt, printStopMsg: false).putAll(Library.at(\rvbs)));
			0 => BP(\cd);

			(1..3).do { |i|
				\chuckIf.eval(Fact(("drum" ++ i).asSymbol), BP, ("drum" ++ i).asSymbol, nil,
					(source: \drum1).putAll(Library.at(\rvbs)))
			};
		},
		unloadProcesses: {
			BP(#[cpt, cd]).free;
			(1..3).do { |i| BP(("drum" ++ i).asSymbol).free }
		},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \mstClock, shouldSync: false, playWarning: false),
					bpCmd: (name: #[hsd, fmt], shouldSync: false, playWarning: false),
					subIterCmd: (id: \drumIterator0, subIter: t2[0], shouldSync: false),
					bpCmd: (name: \cd, prepareBP: { |p|
						p.tempoPat = 1;
						p.chan.level = -1.dbamp;
						p.dur = Pwhite(0.9, 1.25, inf) *.x Pwhite(12.0, 16.0, { |num| num });
						p.p5_(0).sharp_(false).shortFirst_(false).oneNote_(true);
						p.reset;	// maybe voodoo, but it seems sometimes \cd reuses a freed bus object??
					}),
					\cmdSync,
					{ rrand(16.0, 24.0) },
				],
				// onStop: {},
				dur: \sync, // \trigger,  // or \sync
				id: 1540,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "H1540-sung 2",
		segID: 1540,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \mstClock, shouldSync: false, playWarning: false),
					bpCmd: (name: #[hsd, fmt], shouldSync: false, playWarning: false),
					bpCmd: (name: \cd, prepareBP: { |p|
						p.oneNote_(false);
						p.dur = Pwhite(0.7, 0.9, inf) *.x Pwhite(12.0, 16.0, { |num| num });
					}),
					\cmdSync,
					7, //{ rrand(6.0, 14.0) },
				],
				// onStop: {},
				dur: \sync, // \trigger,  // or \sync
				id: 1550,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "H1550-sung 3",
		segID: 1550,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \mstClock, shouldSync: false, playWarning: false),
					bpCmd: (name: #[hsd, fmt], shouldSync: false, playWarning: false),
					bpCmd: (name: \cpt, prepareBP: { |p|
						p.filterNotePat = nil;
						p.useLpf = false;
						p.seqKeys = #[t2];
						p.tempoPat = (42/60) * Pexprand(0.75, 0.5.reciprocal, inf);
						p.att_(0.7).rel_(0.9).dec_(1.2);
						p.reset;
					}),
					\cmdSync,
					subIterCmd: (id: \drumIterator1, subIter: t2[1], shouldSync: false,
						// there is no **@#&*@ way to prevent clearUserSignal from firing twice
						subCmdNotScheduled: true,
						setUserSignal: {
							~endNotify = NotificationCenter.register(
								\drumIter1, \done, ~id, e {
									~endNotify.remove;
									~doneSignal.remove;
									~stop.((manualStop: false));
								}
							);
						},
						// I can't believe this playCmd trick actually works!
						clearUserSignal: { |parms|
							var	seq = topEnvironment[\seq];
							~endNotify.remove;
							if(~subCmdNotScheduled and: { parms.tryPerform(\at, \manualStop) == false }) {
								~subCmdNotScheduled = false;
								seq.sections[seq.currentSection].currentIterator
								.playCmd(PR(\subIterCmd).copy, (
									id: \drumIterator2, subIter: t2[2], shouldSync: false,
									subCmdNotScheduled: true,
									// holy recursive flow of control batman
									setUserSignal: {
										~endNotify = NotificationCenter.register(
											\drumIter2, \done, ~id, e {
												~endNotify.remove;
												~stop.((manualStop: false))
											}
										)
									},
									clearUserSignal: { |parms|
										var	seq = topEnvironment[\seq];
										~endNotify.remove;
										if(~subCmdNotScheduled and: { parms.tryPerform(\at, \manualStop) == false }) {
											~subCmdNotScheduled = false;
											seq.sections[seq.currentSection].currentIterator
											.playCmd(PR(\subIterCmd).copy, (
												id: \drumIterator3, subIter: t2[3],
												shouldSync: false
											))
										};
									}
								));
							};
						}
					),
					2, //{ rrand(6.0, 9.0) },
				],
				// onStop: {},
				dur: \sync, // \trigger,  // or \sync
				id: 1560,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "H1560-sung 4",
		segID: 1560,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \mstClock, shouldSync: false, playWarning: false),
					bpCmd: (name: #[hsd, fmt], shouldSync: false, playWarning: false),
					bpCmd: (name: \cd, prepareBP: { |p|
						p.dur = Pwhite(0.5, 0.8, inf) *.x Pwhite(12.0, 16.0, { |num| num });
						p.p5_(1).shortFirst_(true);
					}),
					\cmdSync,
					{ rrand(8.0, 12.0) },
				],
				// onStop: {},
				dur: \sync, // \trigger,  // or \sync
				id: 1570,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "H1570-sung 5",
		segID: 1570,
		// initProcesses: {},
		// unloadProcesses: {},
		initProcesses: {
			\chuckIf.eval(Fact(\drum4), BP, \drum4, nil, (pan: -1).putAll(Library.at(\rvbs)));
			// 5 and 6 are basically copies - switch between them to change phase vs. drum4
			\chuckIf.eval(Fact(\drum4), BP, \drum5, nil,
				(pan: 1, chan: BP(\drum4).chan).putAll(Library.at(\rvbs)));
			\chuckIf.eval(Fact(\drum4), BP, \drum6, nil,
				(pan: 1, chan: BP(\drum4).chan).putAll(Library.at(\rvbs)));
		},
		unloadProcesses: {
			(4..6).do { |i| BP(("drum" ++ i).asSymbol).free }
		},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \mstClock, shouldSync: false, playWarning: false),
					bpCmd: (name: #[hsd, fmt], shouldSync: false, playWarning: false),
					bpCmd: (name: \cpt, prepareBP: { |p|
						p.seqKeys = #[t2, a2b];
					}),
					\cmdSync,
					2, //{ rrand(6.0, 9.0) },
				],
				// onStop: {},
				dur: \sync, // \trigger,  // or \sync
				id: 1580,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),


	PR(\tlsAff).copy.putAll((
		name: "H1580-sung 6",
		segID: 1580,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \mstClock, shouldSync: false, playWarning: false),
					bpCmd: (name: #[hsd, fmt], shouldSync: false, playWarning: false),
					bpCmd: (name: \cd, prepareBP: { |p|
						p.sharp_(true);
					}),
					\cmdSync,
					{ rrand(8.0, 12.0) },
				],
				// onStop: {},
				dur: \sync, // \trigger,  // or \sync
				id: 1590,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "H1590-sung 7",
		segID: 1590,
		// initProcesses: {},
		// unloadProcesses: {},
		initProcesses: {
			\chuckIf.eval(Fact(\drum7), BP, \drum7, nil, Library.at(\rvbs));
			\chuckIf.eval(Fact(\drum7), BP, \drum8, nil,
				(ctlSource: \drum7, quant: #[-1, 1.25]).putAll(Library.at(\rvbs)));
			BP(\drum7).leadTime = 0.01;
		},
		unloadProcesses: {
			BP(#[drum7, drum8]).free;
		},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \mstClock, shouldSync: false, playWarning: false),
					bpCmd: (name: #[hsd, fmt], shouldSync: false, playWarning: false),
					// subIterCmd: (id: \drumIterator2, subIter: t2[2], shouldSync: false),
					bpCmd: (name: \cd, prepareBP: { |p|
						p.sharp_(true);
					}),
					\cmdSync,
					{ rrand(8.0, 12.0) },
				],
				// onStop: {},
				dur: \sync, // \trigger,  // or \sync
				id: 1600,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "H1600-sung 8",
		segID: 1600,
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \mstClock, shouldSync: false, playWarning: false),
					bpCmd: (name: #[hsd, fmt], shouldSync: false, playWarning: false),
					bpCmd: (name: \cpt, prepareBP: { |p|
						p.tempoPat = (42/60) * Pexprand(0.75, 0.5.reciprocal, inf);
						p.seqKeys = #[t3, a31, a32];
					}),
					\cmdSync,
					2,
				],
				// onStop: {},
				dur: \sync, // \trigger,  // or \sync
				id: 1610,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "H1610-sung 9",
		segID: 1610,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \mstClock, shouldSync: false, playWarning: false),
					bpCmd: (name: #[hsd, fmt], shouldSync: false, playWarning: false),
					bpCmd: (name: \cd, prepareBP: { |p|
						p.p5_(2);
					}),
					\cmdSync,
					{ rrand(8.0, 12.0) },
				],
				// onStop: {},
				dur: \sync, // \trigger,  // or \sync
				id: 1620,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "H1620-sung 10+lpc",
		segID: 1620,
		initProcesses: {
			\chuckIf.eval(Fact(\int), BP, \int, nil, Library.at(\rvbs));
			topEnvironment[\clock108] => BP(\int);
		},
		unloadProcesses: { BP(\int).free },
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \mstClock, shouldSync: false, playWarning: false),
					bpCmd: (name: #[hsd, fmt], shouldSync: false, playWarning: false),

					TLSequenceIterator([
						{ rrand(4.0, 8.0) },
						loopCmd: (
							repeats: 3,
							setDoneSignal: {  // init
								~count = 0;
								~doneSignal = \ifIDontPutSomethingInHereItWillStopImmediately;
							},
							cmds: [
								{ rrand(3.0, 9.0) },
								{	~bpDur = rrand(11.0, 18.0);
									PR(\bpCmd).copy.putAll((name: \int, quant: `nil, dur: ~bpDur))
								},
								{	var	up = rrand(0.1, 0.3);
									PR(\mixerAutoSynthCmd).copy.putAll((
										mixer: BP(\int).chan, name: \ctlEnv, outName: \outbus,
										connect: 0, time: ~bpDur, env: Env(#[-16, -2.5, -16].dbamp, [up, 1-up], \exp)
									))
								},
								{	(if((~count = ~count + 1) < ~repeats) { ~bpDur }
									{ ~doneSignal = nil })
								}
							]
						),
						\cmdSync,
						bpCmd: (name: \int, quant: `nil),
						mixerAutoSynthCmd: (
							mixer: BP(\int).chan, name: \ctlPoint, outName: \outbus,
							value: -8.5.dbamp, time: 3.5, curve: 2.1
						)
					]).shouldSync_(false),

					bpCmd: (name: \cpt, prepareBP: { |p|
						p.seqKeys = #[t2, a2d1, a2d2];
					}),
					\cmdSync,
					2,
				],
				// onStop: {},
				dur: \sync, // \trigger,  // or \sync
				id: 1630,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "H1630-sung 11",
		segID: 1630,
		initProcesses: {
			\chuckIf.eval(Fact(\words), BP, \cwd);
			// hack hack hack hack hack...
			BP(\cwd).use {
				~ampCtl ?? {
					~ampCtl = GenericGlobalControl(\amp, nil, 17.dbamp, [0, 20.dbamp, \amp])
				};
				// if it's a function, the dtor for ampCtl hasn't been added yet
				// (I said it's a hack)
				if(~userfree.isFunction) {
					~userfree = ~userfree.addFunc({ ~ampCtl.free });
				};
				~chan.doWhenReady {
					~limiter = ~chan.playfx(Instr("busfx.limiter"), [0, 2, 0.9, 0.01]);
				};
			};

			\chuckIf.eval(PR(\wordsFastChordTrig), BP, \wtrig, nil, (source: \cwd));
			BP(\wtrig).prepareForPlay;

			topEnvironment[\clock108] => BP(\wtrig);
			topEnvironment[\clock108] => BP(\cwd);
		},
		unloadProcesses: {
			BP(#[wtrig, cwd]).free;
		},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \mstClock, shouldSync: false, playWarning: false),
					bpCmd: (name: #[hsd, fmt], shouldSync: false, playWarning: false),
					bpCmd: (name: \cpt, prepareBP: { |p|
						p.filterNotePat = { |pat|
							Pfin(pat.estimateLength - 1, pat)
						};
						p.seqKeys = #[t4, a41, a42];
						p.tempoPat = 1;
						p.useLpf = true;
					}),
					\cmdSync,
					{ rrand(1.0, 2.5) },
				],
				// onStop: {},
				dur: \sync, // \trigger,  // or \sync
				id: 1640,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "H1640-sung 12",
		segID: 1640,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \mstClock, shouldSync: false, playWarning: false),
					bpCmd: (name: #[hsd, fmt], shouldSync: false, playWarning: false),
					bpCmd: (name: \cpt, prepareBP: { |p|
						p.tempoPat = 2.5;
						p.filterNotePat = { |pat|
							Pfin(pat.estimateLength - 1, pat).drop(1)
						};
					}),
					\cmdSync,
					{ rrand(1.0, 2.5) },
				],
				// onStop: {},
				dur: \sync, // \trigger,  // or \sync
				id: 1650,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "H1650-sung 13",
		segID: 1650,
		// initProcesses: {
		// 	\chuckIf.eval(Fact(\drum7), BP, \drum7, nil, Library.at(\rvbs));
		// 	\chuckIf.eval(Fact(\drum7), BP, \drum8, nil,
		// 		(ctlSource: \drum7, quant: #[-1, 1.25]).putAll(Library.at(\rvbs)));
		// 	BP(\drum7).leadTime = 0.01;
		// },
		// unloadProcesses: {
		// 	BP(#[drum7, drum8]).free;
		// },
		seqPattern: {
			// var	headChans = IdentitySet.new;
			// #[mstClock, int].do { |key|
			// 	BP(key)[\chan] !? { headChans.add(BP(key)[\chan]) };
			// };
			// headChans.add(BP(\mstClock).chan2);
			Pn((
				sequence: [
					bpCmd: (name: \mstClock, shouldSync: false, playWarning: false),
					bpCmd: (name: #[hsd, fmt], shouldSync: false, playWarning: false),
					bpCmd: (name: \cpt, prepareBP: { |p|
						p.tempoPat = 1.2;
						p.filterNotePat = { |pat|
							pat.drop(pat.estimateLength - 1)
						};
					}),
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
					TLSequenceIterator([
						gcAutoSynthCmd: (gc: BP(\hsd).tophCtl, name: \ctlPoint, outName: \outbus,
							value: BP(\hsd).minTop, time: 18),
						gcAutoSynthCmd: (gc: BP(\int).ampCtl, name: \ctlPoint, outName: \outbus,
							value: 0, time: 18, curve: -2.1),
						\cmdSync,
						{
							BP(#[hsd, fmt, mstClock, int]).stop(0);
							0
						}
					]).shouldSync_(false)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2000,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

// TEMPLATE

	// PR(\tlsAff).copy.putAll((
	// 	name: "H1570-sung 5",
	// 	segID: 1570,
	// 	// initProcesses: {},
	// 	// unloadProcesses: {},
	// 	seqPattern: {
	// 		Pn((
	// 			sequence: [
	// 			],
	// 			// onStop: {},
	// 			dur: \sync, // \trigger,  // or \sync
	// 			id: 0,  // trig id
	// 			init: Func(\nextThingTrig).v,
	// 			clear: Func(\clearNextTrig).v
	// 		), 1)
	// 	}
	// )),

	// PR(\tlsAff).copy.putAll((
	// 	name: "",
	// 	segID: 0,
	// 	initProcesses: {},
	// 	unloadProcesses: {},
	// 	seqPattern: {
	// 		Pn((
	// 			sequence: [
	// 			],
	// 			// onStop: {},
	// 			dur: \trigger,  // or \sync
	// 			id: 0,  // trig id
	// 			init: Func(\nextThingTrig).v,
	// 			clear: Func(\clearNextTrig).v
	// 		), 1)
	// 	}
	// )),
];

/*
				gcAutoSynthCmd: (gc: BP(\hsd).ampCtl, name: \ctlPoint, outName: \outbus,
					value: 0, time: 32, curve: -2.1),
				mixerAutoSynthCmd: (mixer: BP(\mstClock).chan, name: \ctlPoint, outName: \outbus,
					value: 0, time: 32, curve: -2.1,
					stopAction: {
						BP(#[mstClock, hs, hstrig, hswp, hsd, fmt]).stop
					}
				),

				{ 32 - BP(\fmt).fadeOut },
				{ BP(\fmt).doFadeOut; 0 },

];




				// DRUM SUB-ITERATOR
				funcCmd: (
					subIter: t2,
					setDoneSignal: {
						~doneSignal = Updater(~subIter, e { |obj, what|
							if(what.debug("t2 notification") == \done) {
								~doneSignal.remove;
								~stop.()
							};
						});
					},
					clock108: topEnvironment[\clock108],
					func: {
						~subIter.play(argClock: ~clock108 ? TempoClock.default);
					},
					done: {
						~subIter.stop;
					},
					clearDoneSignal: {
						~doneSignal = nil;
					}
				),

*/