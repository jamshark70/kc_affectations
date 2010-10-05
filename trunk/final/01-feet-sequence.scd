// Affectations: Feet controller sequence

// ChuckableBrowser.newWindow;

// if you need to clear everything, do this:
BP.all.free; VC.all.free;


// this block loads everything: cursor on open-paren, then ctrl-alt-x
(
if(BP.exists(\transports)) { BP(\transports).free };

s.waitForBoot {
	var	cond = Condition.new;
	(Document.current.path.dirname.dirname +/+ "/common/common-defs.scd").debug.loadPath;
	NotificationCenter.registerOneShot(\lcrvb, \lcrvbexists, \feetSeq, {
		cond.unhang;
	});
	cond.hang;

	(Document.current.path.dirname.dirname +/+ "/feet/feet-defs.scd").debug.loadPath;

	if(~master.mcgui.isNil) { MixingBoard(\arms, nil, ~master) };

/*
	BP(\segTrig).free;
	PR(\busTrig).chuck(BP(\segTrig), nil, (message: '/segment'));
	BP(\evTrig).free;
	PR(\busTrig).chuck(BP(\evTrig), nil, (message: '/event', busIndex: 4094));
	0.5.wait;
	BP(#[segTrig, evTrig]).play(0);
*/

	~sections = [
		PR(\tlsAff).copy.putAll((
			name: "F1-Bang!",
			segID: 1,
			initProcesses: {
				\chuckIf.eval(PR(\trajectories), BP, \traj);
				\chuckIf.eval(Fact(\opening), BP, \op, nil, Library.at(\rvbs));
				\chuckIf.eval(Fact(\openingSteps), BP, \st, nil, Library.at(\rvbs));
			},
			// unloadProcesses: {},
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
			name: "F10-3 poses + hop",
			segID: 10,
			// initProcesses: {},
			// unloadProcesses: {},
			hasChangedSteps: false,
			changeSteps: {
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
				], (Pwhite(0.0, 1.0, inf) < Env(#[0.0, 0.8], #[120])).collect(_.binaryValue));
				bp.gDelta = Pwhite(1.5, 3.0, inf) * Env(#[1, 0.36], #[90]);
				bp.numEv = Pwhite(6, 14, inf);
			},
			seqPattern: {
				Pn((
					sequence: [
						// I have a sneaky feeling I oughtn't do it this way...
						funcCmd: (func: {
							// ~sequencer is the tlsAff Proto
							// reinit in case it's replaying
							~sequencer.hasChangedSteps = false;
						}),
						bpCmd: (name: \st, shouldSync: false, playWarning: false),
						{ BP(\st).override(\kdecay, Pwhite(0.15, 0.3, 3)); 0 },
						loopCmd: (repeats: 3,
							cmds: [
								{	if(~repeats < 3) {
										PR(\funcCmd).copy.putAll(topEnvironment[\trigParms])
									} {
										PR(\funcCmd).copy.putAll((dur: 0.01))
									}
								},
								\cmdSync,
								{	BP(\st).runGesture((gest: \oneKlankSteps, numEv: rrand(10, 20)));
									0
								},
							]
						),
						\cmdSync,
						[	5,
							funcCmd: (func: {
								if(~sequencer.hasChangedSteps.not) {
									~sequencer.changeSteps;
									~sequencer.hasChangedSteps = true;
								};
							})
						],
						funcCmd: topEnvironment[\trigParms],
						{	BP(\st).runGesture((gest: \klankHrmSteps, kdecay: rrand(0.14, 0.22), numEv: rrand(10, 20)));
							0
						}
					],
					onStop: {
						if(~hasChangedSteps.not) {
							~changeSteps.();
							~hasChangedSteps = true;
						};
					},
					dur: \trigger,  // or \sync
					id: 20,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "F20-slinky",
			segID: 20,
			// initProcesses: {},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: (name: \st, shouldSync: false, playWarning: false),
						// { BP(\st).removeAutoRun; 0 },
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
					id: 30,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "F30-normal",
			segID: 30,
			// initProcesses: {},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: (name: \st, shouldSync: false, playWarning: false),
						// { BP(\st).addAutoRun; 0 }
					],
					// onStop: {},
					dur: \trigger,  // or \sync
					id: 40,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "F40-3 poses",
			segID: 40,
			// initProcesses: {},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: (name: \st, shouldSync: false, playWarning: false),
						{ BP(\st).removeAutoRun; 0 },
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
						{ BP(\st).addAutoRun; 0 }
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
			name: "F50-multispeed",
			segID: 50,
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
					id: 55,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "F55-hop!",
			segID: 55,
			// initProcesses: {},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: (name: \st, shouldSync: false, playWarning: false),
						0.05,
						{
							BP(\st).runGesture((gest: \klankHrmSteps, kdecay: rrand(0.14, 0.22), numEv: rrand(10, 20)));
							BP(\st).addAutoRun;
							BP(\st).autoRunMultiSpeed(false);
							// should be lots of activity!
							BP(\st).gDelta = Pwhite(0.35, 0.8, inf);
							0
						}
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
			name: "F60-stop(short)",
			segID: 60,
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
					id: 70,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "F70-axial",
			segID: 70,
			initProcesses: {
				\chuckIf.eval(Fact(\waterpad), VC, \wp, nil, Library.at(\rvbs));
				Fact(\feetChordBP) => BP(\fc);
				VC(\wp) => BP(\fc);
			},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: (name: \fc),
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
			name: "F80-walking(swinging)",
			segID: 80,
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
					id: 90,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "F90-3 inversions",
			segID: 90,
			// initProcesses: {},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: (name: \st, shouldSync: false, playWarning: false),
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
					id: 100,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "F100-hop/lean",
			segID: 1,
			initProcesses: {
				\chuckIf.eval(PR(\leaning), BP, \ln);
				VC(\wp) => BP(\ln);
				0 => BP(\ln);
			},
			// unloadProcesses: {},
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
								bp.autoRun = false;
							})
						],
						bpCmd: (name: \ln, dur: 15),
						\cmdSync
					],
					// onStop: {},
					dur: \sync, // \trigger,  // or \sync
					id: 110,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "F110-Conflict",
			segID: 110,
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
							kAmp: Pseries.fromEndpoints(0.024, 0.35, numEv ? 25)
						))
					)
				});
			},
			// unloadProcesses: {},
			oneSnare: { |gest(\one)|
				BP(\st).snareParms((
					numEv: max(2, BP(\st).snareRhythms[gest].estimateLength),
					rhythms: Pn(gest, 1), kAmp: 0.35
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
						{ "starting loop".debug; 0 },
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
					id: 120,  // trig id
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

	~seq = PR(\affSectSeq).copy.sections_(~sections);

	~seq.loadResources(0);
	PR(\transports).chuck(BP(\transports), nil, (model: ~seq));
};
)



BP.all.stop;

BP(\st).free;

~seq.sections[~seq.currentSection].currentIterator.activeCmds;
~seq.sections[~seq.currentSection].currentIterator.activeCmds.do(_.listVars); ""

"\n\n".postln;

~seq.sections[~seq.currentSection].savedCmds
~seq.sections[~seq.currentSection].savedCmds.do(_.listVars); ""

t = ~seq.sections[~seq.currentSection].currentIterator;
t.dependants
t.changed(\done)

~seq.listVars
~seq.sections.last.listVars;

BP(\st) => MT(1);
