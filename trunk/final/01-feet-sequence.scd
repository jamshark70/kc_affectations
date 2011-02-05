// Affectations: Feet controller sequence

// hakkity-hakk-hakk-hakk
// this must be a function because we can't evaluate this until BP(\st) exists
var lwpLoopParms = { (
	// dur: 35,
	// // fine print: ~doneSignal is non-nil by default, preventing 'dur' from being used
	// setDoneSignal: { ~doneSignal = nil },
	lwpParms: (
		gest: \klankMachineLWp,
		instr: Pwrand(#[bufGrainPanKlankDist, bufGrainPanKlRingDist], #[0.4, 0.6], inf),
		numEv: inf, //numEv,
		newDelta: Pseg(
			Pser([Pwhite(0.4, 0.7, 1), Pwhite(0.12, 0.18, 1)], 3,
				#[0, 1].wchoose(#[0.7, 0.3])),
			Pwhite(2.5, 4.5, inf),
			\exp
		),
		timeMul: Pif(
			(Plazy({ Pseries.fromEndpoints(1, BP(\st).pitchProbCtl.value, rrand(4, 7)) }) ++ BP(\st).pitchProbCtl.asPattern).coin,
			Pwhite(0.15, 0.35, inf),
			0.01
		) / Pkey(\delta),
		// oh, it gets uglier!
		filtAttackRatio: Pif(
			(Pkey(\filtDecay) * Pkey(\delta)) >= 0.011,
			Pwhite(0.9, 0.98, inf),
			1
		),
		chorusAmps: #[[0, 0, 0]],
		// pull pitch only if you'll hear it
		freq: Pif(
			(Pkey(\filtDecay) * Pkey(\delta)) >= 0.011,
			BPStream(("laurawp" ++ BP(\st).lauraWpPitchPoolStream.next).asSymbol, envir: BP(\st).v),
			Pwhite(28, 42, inf).collect { |degree| Mode(\g).cps(degree) }
		),
		mainAmp: 1,
		kAmp: 2,
		harm: Pstutter(Pwhite(6, 15, inf), Pseq([
			Pexprand(0.98, 0.98.reciprocal, inf).clump(5) * [1, 2, 3, 4, 5],
			Pexprand(0.98, 0.98.reciprocal, inf).clump(5) * [1, 3, 5, 7, 9]
		], inf).collect([_]))  // polySynthPlayer: wrap array arg in another array
	),
	cmds: [
		{
			BP(\st).runLauraWp(~lwpParms, true);
			rrand(5.0, 9.0)
		}
	]
) };

(Document.current.path.dirname.dirname +/+ "/feet/feet-defs.scd")/*.debug*/.loadPath;

[
	PR(\tlsAff).copy.putAll((
		name: "F1-Bang!",
		segID: 1,
		initProcesses: {
			\chuckIf.eval(Fact(\dataIn), BP, \di, nil, (
				// filename: "arms/hands-1_data2.wav" //"arms/NACL_Arms.wav"
				readFrame: 138,
				recvBus: Bus(\control, 4000, 12, s)
			));
			// addDependant is in BP(\di).prep
			BP(\di).put(\update, { |obj, what|
				if(what == \stop and: { obj === topEnvironment[\seq] }) {
					BP(~collIndex).stop;
				};
			});

			\chuckIf.eval(PR(\trajectories), BP, \traj);
			\chuckIf.eval(Fact(\opening), BP, \op, nil, Library.at(\rvbs));
			\chuckIf.eval(Fact(\openingSteps), BP, \st, nil, Library.at(\rvbs));
		},
		unloadProcesses: {
			BP(#[op, st]).free;
		},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \op, dur: 35, shouldSync: false, prepareBP: { |bp|
						bp.ampCtl.value = 0.68;
						// if(d.class == DDWTimer) { d.reset };
					}),
					12,
					gcAutoSynthCmd: (gc: BP(\op).ampCtl, name: \ctlPoint, outName: \outbus,
						value: 0, time: 22, curve: -2, shouldSync: false),
					bpCmd: (name: \st, shouldSync: false, prepareBP: { |bp|
						bp.ampCtl.value = 0;
						bp.gest = Pseq([Pn(\slowSteps, { rrand(2, 4) }), \slowStepStretch], inf);
						bp.numEv = Pwhite(4, 7, inf);
						bp.gDelta = Pwhite(2.5, 4.0, inf);
						bp.slowRate = Pwhite(0.5, 0.8, inf);
						bp.defaultParms = nil;
						bp.kdecay = Pexprand(0.014, 0.017, inf);
						bp.makeStreamForKey(\kfreq);	// reset this one
						bp.autoRun = true;
						
						bp.gestures.oneKlankStepsCallback = { |parms|
							CleanupStream(~gestures[\oneKlankSteps].(parms).asStream, parms[\callback])
						};
					}),
					gcAutoSynthCmd: (gc: BP(\st).ampCtl, name: \ctlPoint, outName: \outbus,
						shouldSync: false,
						value: 0.7, time: 14, curve: 2),
					// \cmdSync,
					// 20,
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 10,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F10-Ilana joins",
		segID: 10,
		initProcesses: {
			\chuckIf.eval(Fact(\ilanaSteps), BP, \is, nil, Library.at(\rvbs));
		},
		unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					{ BP(\st).stop; 0 },
					bpCmd: (name: \is, dur: 40, prepareBP: { |bp|
						bp.rate1 = Pwhite(1.3, 1.9, inf);
						bp.rate2 = Pkey(\rate1) * Pwhite(2.0, 3.2, inf);
						bp.maxSynthsCtl.value = 2;
						bp.decayCtl.value = 2;
						bp.delta = Plazy({ Pbeta(1, 4.8, ~deltaDistribCtl, 1, inf) });
					}, clearDoneSignal: { BP(\is).stopNodes(-1) }),
					20, // really?
					{	BP(\is).delta = Plazy({ Pbeta(0.6, 2.0, ~deltaDistribCtl, 1, inf) });
						BP(\is).maxSynthsCtl.value = 3;
						0
					}
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 20,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F20-Laura joins",
		segID: 20,
		initProcesses: {},
		unloadProcesses: {},
		seqPattern: {
			if(lwpLoopParms.isFunction) { lwpLoopParms = lwpLoopParms.value };
			Pn((
				sequence: [
					{ BP(\is).stop; 0 },
					bpCmd: (name: \st, prepareBP: { |bp|
						bp.autoRun = false;
						bp.pitchProbCtl.value = 0.08;
						bp.setLauraWps(Mode(\g).cps(#[22, 28, 31, 33, 34, 37, 39, 40, 43, 46]));
					}),
					0.01,  // a RACE condition? Ya gotta be kidding me!
					TLSequenceIterator([
						15,
						gcAutoSynthCmd: (gc: BP(\st).pitchProbCtl, name: \ctlPoint, outName: \outbus,
							value: 0.27, time: 33, curve: 5.4)
					]).shouldSync_(false),
					loopCmd: lwpLoopParms.copy.put(\id, \lwp1),
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
					funcCmd: (func: {
						~iterator.findActive(\lwp1).stop;
						BP(\st).stopSavedStreams;
						BP(\st).override(\kdecay, Pwhite(0.15, 0.3, 3));
						0
					}),
					loopCmd: (repeats: 3,
						cmds: [
							{	BP(\st).runGesture((gest: \oneKlank, numEv: 2));
								if(~repeats > 1) {
									PR(\funcCmd).copy.putAll(topEnvironment[\trigParms])
								} {
									rrand(1.5, 2.5)
								}
							}
						]
					),
					\cmdSync,
					loopCmd: lwpLoopParms.copy, //.shouldSync_(false),
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 30,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F30-Stephen pattern",
		segID: 30,
		// initProcesses: {},
		// unloadProcesses: {},
		hasChangedSteps: false,
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \st, shouldSync: false, playWarning: false, prepareBP: { |bp|
						bp.autoRun = false;  // just in case... prevent warning in next thing
					}),
					0.01,
					{
						var	bp = BP(\st);
						bp.chordN = 0;
						bp.kdecay = (Pwhite(0.1, 0.3, inf) * Env(#[0.1, 0.25], #[86], 7));
						bp.gest = Pswitch1([
							Pseq([
								Pwrand(#[clatter, oneKlankSteps, clatterDecay, klankDecay, slowSteps],
									#[4, 2, 3, 1, 1].normalizeSum, { rrand(3, 6) }),
								\slowStepStretch
							], inf),
							Prand(#[oneKlankSteps, klankDecay, klankHarmonize, klankHrmSteps], inf)
						], (Pwhite(0.0, 1.0, inf) < Env(#[0.0, 0.5], #[120])).collect(_.binaryValue));
						bp.gDelta = Pwhite(1.5, 3.0, inf) * Env(#[1, 0.36], #[90]);
						bp.numEv = Pwhite(6, 14, inf);
						bp.addAutoRun;
						0
					}
				],
				onStop: {
					// if(~hasChangedSteps.not) {
					// 	~changeSteps.();
					// 	~hasChangedSteps = true;
					// };
				},
				dur: \trigger,  // or \sync
				id: 40,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F40-slinky",
		segID: 40,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \st, shouldSync: false, playWarning: false),
					0.01,
					{ BP(\st).removeAutoRun; 0 },
					loopCmd: (
						cmds: [
							{
								var	numEv = rrand(9, 17),
								numInChord = rrand(2, 3),
								startDelta = rrand(0.35, 0.6);
								BP(\st).runGesture((
									gest: \klankMachine,
									numEv: numEv,
									newDelta: Pgeom.fromEndpoints(startDelta, rrand(0.05, 0.09), numEv),
									timeMul: startDelta / Pkey(\delta),
									freq: (Pseries(
										rrand(28, 33) - 7,
										Pwrand(#[1, 2], #[0.7, 0.3], inf),
										inf
									) -.x Pclump(numInChord, Pseries(
										0, Pwrand(#[1, 2, 3], #[1, 4, 3].normalizeSum, numInChord), inf
									))).collect { |deg| Mode(\g).cps(deg) },
									kAmp: 0.22,
									harm: Pstutter(Pwhite(3, 7, inf), Pfunc({ [(1..5) * ({ exprand(0.8, 1.25) } ! 5).put(0, 1)] })),
									xEnds: { rrand(-1.0, 1.0) } ! 2,
									yEnds: [rrand(15.0, 20.0), rrand(5.0, 8.0)]
								));
								0
							},
							funcCmd: topEnvironment[\trigParms],
							\cmdSync
						]
					)
					// tweak pacing (lorne data?)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 50,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F50-Ilana pattern",
		segID: 50,
		initProcesses: {},
		unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					{ BP(\st).stop; 0.4 },
					bpCmd: (name: \is, dur: 20, prepareBP: { |bp|
						bp.maxSynthsCtl.value = 8;
						bp.decayCtl.value = 2;
						bp.delta = Plazy({ Pbeta(0.6, 2.0, ~deltaDistribCtl, 1, inf) });
					} /*, clearDoneSignal: { BP(\is).stopNodes(-1) }*/),
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 60,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F60-Laura pattern",
		segID: 60,
		initProcesses: {},
		unloadProcesses: {},
		seqPattern: {
			if(lwpLoopParms.isFunction) { lwpLoopParms = lwpLoopParms.value };
			Pn((
				sequence: [
					bpCmd: (name: \st, prepareBP: { |bp|
						bp.autoRun = false;
						bp.pitchProbCtl.value = 0.36;
						bp.setLauraWps(Mode(\g).cps(#[22, 28, 31, 33, 34, 37, 39, 40, 43, 46]));
					}),
					0.01,
					gcAutoSynthCmd: (gc: BP(\st).pitchProbCtl, name: \ctlEnv, outName: \outbus,
						env: Env(#[0.36, 0.6], #[1], 4), time: 18, connect: 0),
					loopCmd: lwpLoopParms.copy.put(\id, \lwp3),
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
					funcCmd: (func: {
						BP(\st).removeAutoRun;
						~iterator.findActive(\lpw3).stop;
						0
					}),
					loopCmd: (repeats: 3,
						cmds: [
							{	if(~repeats < 3) {
									PR(\funcCmd).copy.putAll(topEnvironment[\trigParms])
								} {
									PR(\funcCmd).copy.putAll((dur: 0.01))
								}
							},
							\cmdSync,
							{	BP(\st).runGesture((gest: \klankHrmSteps, kdecay: rrand(0.14, 0.22), numEv: rrand(10, 20)));
								0
							},
						]
					),
					\cmdSync,
					// { BP(\st).addAutoRun; 0 },
					loopCmd: lwpLoopParms.copy.put(\id, \lwp3)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 70,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	// PR(\tlsAff).copy.putAll((
	// 	name: "F30-normal",
	// 	segID: 30,
	// 	// initProcesses: {},
	// 	// unloadProcesses: {},
	// 	seqPattern: {
	// 		Pn((
	// 			sequence: [
	// 				bpCmd: (name: \st, shouldSync: false, playWarning: false),
	// 				// { BP(\st).addAutoRun; 0 }
	// 			],
	// 			// onStop: {},
	// 			dur: \trigger,  // or \sync
	// 			id: 40,  // trig id
	// 			init: Func(\nextThingTrig).v,
	// 			clear: Func(\clearNextTrig).v
	// 		), 1)
	// 	}
	// )),

	PR(\tlsAff).copy.putAll((
		name: "F70-multispeed",
		segID: 70,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \st, shouldSync: false, playWarning: false),
					0.05,
					{	BP(\st).removeAutoRun;  // really?
						BP(\st).autoRunMultiSpeed;
						0
					}
					// { if(BP(\st)[\autoRunner].isNil) { BP(\st).addAutoRun }; 0 },
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 80,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F80-3 pattern counterpoint",
		segID: 80,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \op, dur: 35, /* shouldSync: false, */ prepareBP: { |bp|
						bp.ampCtl.value = 0.68;
						// if(d.class == DDWTimer) { d.reset };
					}),

					{	BP(\st).stopSavedStreams;
						BP(\st).addAutoRun;
						BP(\st).autoRunMultiSpeed(false);
						0.05
					},
					bpCmd: (name: \st, shouldSync: false, playWarning: false),

					loopCmd: (
						actions: [
							{ BP(\st).runGesture },
							{ BP(\is).triggerOneEvent(0) },
							{ BP(\st).runLauraWp(lwpLoopParms[\lwpParms], true); }
						],
						cmds: [
							{
								~actions.choose.value;
								exprand(0.6, 2.6)
							}
						]
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 90,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F90-stop(short)",
		segID: 90,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					{	BP(\st).stop(0);
						// BP(\st).removeAutoRun;
						// if(BP(\st)[\mSpeedPlayer].notNil) {
						// 	BP(\st).autoRunMultiSpeed;  // toggle-should stop
						// };
						0
					}
				],
				onStop: {
					{ BP(\st).stop }.defer(12)
				},
				dur: \trigger,  // or \sync
				id: 100,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F100-axial",
		segID: 100,
		initProcesses: {
			\chuckIf.eval(Fact(\waterpad), VC, \wp, nil, Library.at(\rvbs));
			Fact(\feetChordBP) => BP(\fc);
			VC(\wp) => BP(\fc);
		},
		unloadProcesses: {
			VC(\wp).free; BP(\fc).free;
		},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \fc),
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 110,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F110-walking(swinging)",
		segID: 110,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \st, shouldSync: false, prepareBP: { |bp|
						bp.gDelta = Pwhite(1.5, 3.0, inf)
					}),
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 120,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F120-3 inversions",
		segID: 120,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \st, shouldSync: false, playWarning: false),
					0.05,
					{ BP(\st).removeAutoRun; 0 },
					loopCmd: (
						repeats: 3,
						notesKeys: Pseq(#[lauraslide, inversion1, inversion2], 1).asStream,
						cmds: [
							{	if(~repeats < 3) {
									PR(\funcCmd).copy.putAll(topEnvironment[\trigParms])
								} {
									PR(\funcCmd).copy.putAll((dur: 0.01))
								}
							},
							\cmdSync,
							{	BP(\st).runGesture((
									gest: \lauraslide,
									notesKey: ~notesKeys.next,
									ampAdjust: 0.11,
									numEv: rrand(11, 19)
								));
								0
							},
						]
					),
					\cmdSync,
					1.2,
					{ BP(\st).addAutoRun; 0 }
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 130,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F130-hop/lean",
		segID: 130,
		initProcesses: {
			\chuckIf.eval(PR(\leaning), BP, \ln);
			VC(\wp) => BP(\ln);
			0 => BP(\ln);
		},
		unloadProcesses: { BP(\ln).free },
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \st, shouldSync: false, playWarning: false),
					0.05,
					{
						BP(\st).runGesture((gest: \klankHrmSteps, kdecay: rrand(0.14, 0.22), numEv: rrand(10, 20)));
						0
					},
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
					// .stop clears all footstep sounds
					{ BP(\st).stop(0); 0 },
					// replaying does NOT resume them if autoRun == false
					[	0.2,
						bpCmd: (name: \st, shouldSync: false, prepareBP: { |bp|
							bp.gest = Prand(#[oneKlankSteps, klankDecay, klankHarmonize, klankHrmSteps], inf);
							bp.autoRun = false;
						})
					],
					bpCmd: (name: \ln, dur: 15, prepareBP: { |bp|
						bp.selector = Pseq([Pn(0, 6), Pn(1, inf)], 1);
						bp.delta = Pgeom.fromEndpoints(0.18, 0.8, 6);
						bp.klankkAmp = Pexprand(0.4, 0.64, inf);
						bp.klankdelta = Pwhite(1.2, 2.6, inf);
					}) //,
					// \cmdSync
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 140,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F140-Conflict",
		segID: 140,
		initProcesses: {
			// what an obscene hack, but my framework is too complicated
			var numEvStream = Pwhile1({ |ev, next| next < 25 },
				Pseries(2, Pwrand(#[0, 1, 2], #[0.2, 0.4, 0.4], inf), inf)
			).asStream;
			// usually this is used for resource loading
			// but it serves nicely for lazy init too
			~snareKeys = BP(\st).snareRhythms.keys;
			// ~snrGest = Pseq([\one, Pxrand(~snareKeys, inf)], 1).asStream;
			~multiSnareParms = ~oneSnareParms.copy.put(\setDoneSignal, {
				var	numEv = numEvStream.next;
				~doneSignal = ~pat = BP(\st).makeGesture(
					BP(\st).snareParms((
						numEv: numEv,
						kAmp: Pseries.fromEndpoints(0.024, 0.35, numEv ? 25),
						mainAmp: rrand(0.2, 0.32)
					))
				)
			});
		},
		// unloadProcesses: {},
		oneSnare: { |gest(\one)|
			BP(\st).snareParms((
				numEv: max(2, BP(\st).snareRhythms[gest].estimateLength),
				rhythms: Pn(gest, 1), kAmp: 0.35, mainAmp: 0.37
			));
		},
		oneSnareParms: (
			setDoneSignal: {
				~doneSignal = ~pat = BP(\st).makeGesture(~sequencer.oneSnare)
			},
			func: {
				// environment confusion: I need to create the func
				// in the funcCmd environment, not BP(\st)'s!
				// (so it's attached to the cmd envir)
				var	cleanup = e { ~stop.() }, pat = ~pat;
				BP(\st).use {
					~spawner.par(CleanupStream(pat.asStream, cleanup));
				};
			}
		),
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \st, shouldSync: false, playWarning: false),
					0.05,
					funcCmd: ~oneSnareParms,
					\cmdSync,
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
					funcCmd: ~oneSnareParms,
					\cmdSync,
					2.0,
					loopCmd: (
						cmds: [
							{	PR(\funcCmd).copy.putAll(~sequencer[\multiSnareParms])
								// // currentEnvironment is the loopCmd holding this
								// .put(\loopcmdParent, currentEnvironment)
							},
							\cmdSync,
							{ rrand(1, 3) * 0.5 },
						]
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 150,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F150-small leans",
		segID: 150,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \st, shouldSync: false, playWarning: false),
					0.05,
					bpCmd: (name: \ln, prepareBP: { |bp|
						bp.selector = Pseq([Pn(0, { rrand(2, 7) }), 1], inf);
						bp.delta = Pwhite(0.2, 0.4, inf) * Pseq(#[1, 2.1], inf);
					}),
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 160,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F160-military turns",
		segID: 160,
		initProcesses: {
			// another hack: refactor after premiere to move these into BP(\st)
			var	conflict = topEnvironment[\seq].sections.detect { |sct| sct.segID == 140 };
			if(conflict.notNil and: { conflict[\multiSnareParms].notNil }) {
				// this should reuse function scope from the other section
				// (I said this is a hack...)
				~multiSnareParms = conflict.multiSnareParms;
			} {
				"Couldn't find multiSnareParms in conflict section.".warn;
			};
		},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \st, shouldSync: false, playWarning: false),
					0.05,
					loopCmd: (
						cmds: [
							{	PR(\funcCmd).copy.putAll(~sequencer[\multiSnareParms])
								// // currentEnvironment is the loopCmd holding this
								// .put(\loopcmdParent, currentEnvironment)
							},
							\cmdSync,
							{ rrand(1, 3) * 0.3 },
						]
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 170,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F170-falling",
		segID: 170,
		fallRatios: #[0.4, 0.7, 0.86], // reverse order
		initProcesses: {
			Fact(\fallingBP) => BP(\fall);
			VC(\wp) => BP(\fall);
		},
		unloadProcesses: { BP(\fall).free },
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \st, shouldSync: false, playWarning: false),
					0.05,
					{	var	numChords = rrand(2, 4);
						BP(\st).removeAutoRun;  // maybe already gone
						PR(\bpCmd).copy.putAll((name: \fall, prepareBP: { |bp|
							bp.fallLow = ~sequencer[\fallRatios][2];
							bp.selector = Pseq([Pn(0, numChords), Pn(1, inf)], 1);
							bp.makeStreamForKey(\delta);
						}))
					},
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
					loopCmd: (
						repeats: 18,
						setDoneSignal: {
							~mainAmp = Pseries(1, 0.2, 18).reciprocal.asStream;
							~waitStream = Pgeom.fromEndpoints(0.12, 0.75, 18).asStream;
						},
						cmds: [
							{	BP(\st).runGesture((
									gest: \oneKlank,
									kdecay: rrand(0.14, 0.22),
									mainAmp: ~mainAmp.next
								));
								~waitStream.next
							}
						]
					),
					// \cmdSync,
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
					{ BP(\fall).stop(0); 0.1 },
					{	var	numChords = rrand(6, 9);
						PR(\bpCmd).copy.putAll((name: \fall, prepareBP: { |bp|
							bp.fallLow = ~sequencer[\fallRatios][1];
							bp.selector = Pseq([Pn(0, numChords), Pn(1, inf)], 1);
							bp.makeStreamForKey(\delta);
						}))
					},
					{ BP(\st).addAutoRun; 0 },
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
					{ BP(\fall).stop(0); BP(\st).removeAutoRun; 0.1 },
					bpCmd: (name: \fall, prepareBP: { |bp|
						bp.fallLow = ~sequencer[\fallRatios][0] * Pwhite(0.9, 1.3, inf);
						bp.selector = Psmartstutter(
							Pfunc({ |n| rrand(1, 4) * (2-n) }),
							Pseq(#[0, 1], inf)
						);
						bp.makeStreamForKey(\delta);
					}),
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
					{	BP(\fall).stop(0);
						BP(\st).runGesture((
							gest: \lauraslide,
							notesKey: \lauraslide,
							ampAdjust: 0.12,
							numEv: rrand(16, 23)
						));
						0.1
					}
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 180,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F180-military turns",
		segID: 180,
		tempo: 60/104,
		initProcesses: {
			var	conflict = topEnvironment[\seq].sections.detect { |sct| sct.segID == 140 };
			if(conflict.notNil and: { conflict[\multiSnareParms].notNil }) {
				~multiSnareParms = conflict.multiSnareParms;
			} {
				"Couldn't find multiSnareParms in conflict section.".warn;
			};
		},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \st, shouldSync: false, playWarning: false),
					0.05,
					{	var	snarePlayerStream, seq = currentEnvironment; // ~sequencer;
						BP(\st).removeAutoRun;
						BP(\st).use {
							snarePlayerStream = ~spawner.par(Prout({
								loop {
									~runGesture.(~snareParms.((
										numEv: rrand(12, 25),
										mainAmp: 0.2
									)));
									~spawner.wait(rrand(2, 4) * seq[\tempo]);
								}
							}))
						};
						~snarePlayerStream = snarePlayerStream;
						1
					}
				],
				onStop: {
					if(BP(\st).isPlaying) {
						BP(\st).spawner.suspend(~snarePlayerStream)
					};
				},
				dur: \trigger,  // or \sync
				id: 190,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F190-normal+inversions",
		segID: 190,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \st, shouldSync: false, playWarning: false),
					0.05,
					{ BP(\st).addAutoRun; 0 },
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
					{	BP(\st).runGesture((
							gest: \lauraslide,
							notesKey: \lauraslide,
							ampAdjust: 0.15,
							numEv: rrand(16, 23)
						));
						0
					},
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
					{	
						fork {
							Pshuf(BP(\st).runningNotes.keys.asArray, 1)
							.asStream.do { |key|
								BP(\st).runGesture((
									gest: \lauraslide,
									notesKey: key,
									ampAdjust: 0.15,
									numEv: rrand(5, 8),
									numNotesPat: 1
								));
								rrand(0.9, 1.4).wait  // waiting would be good here, (ahem)
							};
						};
						0
					}
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 200,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F200-multispeed",
		segID: 200,
		initProcesses: {
			~baseMSpeedParms = BP(\st).use {
				// "I AM MAKING MSPARMS NOW!".debug;
				~multiSpeedParmsStream ?? { ~makeStreamForKey.(\multiSpeedParms) };
				BP(\st).multiSpeedParmsStream.next(()) //.debug("Here they are")
			};
		},
		// unloadProcesses: {},
		seqPattern: {
			var	self = currentEnvironment;
			// "OK I'm in the environment that should have ~baseMSpeedParms - where is it?".debug;
			// self.listVars;
			Pn((
				sequence: [
					bpCmd: (name: \st, shouldSync: false, playWarning: false),
					0.1,
					loopCmd: (
						repeats: 3,
						cmds: [
							{	var	parms,
									range = 3 - ~repeats,
									delta = range.linexp(0, 5, 1.2, 0.09) * rrand(1.0, 1.2);
								parms = self[\baseMSpeedParms].copy.putAll((
									range: range,
									prob: 1,
									newDelta: delta,
									numEv: (40 - (10*range)) / delta,
									// if I had designed this right in the first place,
									// I wouldn't have to do something stupid like this now
									freq: Plazy({ |ev|
										var i = ev[\parms][\range],
										n = ev[\parms][\numEv],
										n1 = (n * rrand(0.4, 0.65)).roundUp,
										n2 = ((n - n1) * 0.5).trunc,
										adder = Pwrand(#[0, 1, 2, 3], #[1.5, 2, 2, 1].normalizeSum, n2);
										if(i >= 4) {
											adder = Pfin(n2, Ppatlace([adder, 0, 0], inf))
										};
										Pseries(ev[\parms][\notes][i], Pseq([
											Pn(0, n1),
											adder,
											adder.neg
										])).collect { |deg| Mode(\d).cps(deg) }
									})
								));
								BP(\st).removeAutoRun;
								BP(\st).runGesture(parms, true);
								rrand(2.5, 3.5) * ~repeats
							}
						]
					),
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
					{ BP(\st).autoRunMultiSpeed(true); 0 }
				],
				onStop: { BP(\st).stopSavedStreams; BP(\st).autoRunMultiSpeed(false); },
				dur: \trigger,  // or \sync
				id: 210,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "F210-Partnering",
		segID: 210,
		initProcesses: {
			~cmdPool = [
				{	var	stream, cmd = currentEnvironment;
					BP(\st).use {
						stream = CleanupStream(~makeGesture.((
							gest: \lauraslide,
							notesKey: BP(\st).runningNotes.keys.choose,
							ampAdjust: 0.15,
							numEv: rrand(7, 10)
						)).asStream, {
							{ cmd.activeGest.putEach(#[0, 1], false);
							}.defer(2.5);
						});
						cmd.activeGest.putEach(#[0, 1], true);
						~spawner.par(stream);
					};
					0
				},
				{	var	cmd = currentEnvironment;
					BP(\st).use {
						var	mspeeds = { ~multiSpeedParmsStream.next(()) } ! 4,
							mstream;
						mstream = CleanupStream(
							Ppar(mspeeds.collect { |parms| ~makeGesture.(parms) }, 1).asStream,
							e {
								~streamsToStop.remove(mstream);
								cmd.activeGest.putEach(#[0, 1], false);
							}
						);
						~spawner.par(mstream);
						~streamsToStop.add(mstream);
						cmd.activeGest.putEach(#[0, 1], true);
					};
					0
				},
				{	var	cmd = currentEnvironment;
					cmd.activeGest.putEach(#[2, 3], true);
					PR(\bpCmd).copy.putAll((name: \ln, dur: rrand(2.0, 4.0),
						clearDoneSignal: { { cmd.activeGest.putEach(#[2, 3], false) }.defer(7.0) }
					));
				},
				{	var	cmd = currentEnvironment;
					cmd.activeGest.putEach(#[2, 3], true);
					PR(\bpCmd).copy.putAll((name: \fc, dur: rrand(2.0, 4.0),
						clearDoneSignal: { { cmd.activeGest.putEach(#[2, 3], false) }.defer(7.0) }
					));
				},
				{ BP(\st).runGesture((name: \klankHrmSteps, numEv: rrand(4, 7),
					kdecay: rrand(0.4, 0.9))); 0 }
			];
		},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \st, shouldSync: false, playWarning: false, prepareBP: { |bp|
						bp.autoRun = false;
					}),
					0.1,
					{ BP(\st).removeAutoRun; 0 },
					loopCmd: (
						setDoneSignal: {
							~activeGest = false ! ~sequencer[\cmdPool].size;
							// ~gest = Pwhite(0, ~sequencer[\cmdPool].size - 1, inf)
							~gest = Pwrand((0..4), #[1, 0, 1, 1, 1].normalizeSum, inf)
								.reject { |i| ~activeGest[i] }
								.asStream;
						},
						dStream: Pexprand(0.9, 2.2, inf).asStream,
						cmds: [
							{ ~sequencer[\cmdPool][~gest.next].value },
							{ ~dStream.next }
						]
					)
				],
				// actually I think I like it better if it overlaps
				// onStop: {
				// 	BP(\st).stop(0);
				// 	VC(\wp).v.nodes.do { |node| node.release(-1.6) };
				// },
				dur: \trigger,  // or \sync
				id: 501,  // trig id
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

];
