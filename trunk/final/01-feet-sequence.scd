// Affectations: Feet controller sequence

ChuckableBrowser.newWindow;

BP.all.free; VC.all.free;
BP.all.stop;

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

(
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
			name: "F10-3 poses",
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
								funcCmd: topEnvironment[\trigParms],
								\cmdSync,
								{	BP(\st).runGesture((gest: \oneKlankSteps, numEv: rrand(10, 20)));
									0
								},
							]
						),
						\cmdSync,
						5,
						funcCmd: (func: {
							if(~sequencer.hasChangedSteps.not) {
								~sequencer.changeSteps;
								~sequencer.hasChangedSteps = true;
							};
						}),
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
						{	BP(\st).removeAutoRun;
							BP(\st).autoRunMultiSpeed;
							0
						}
						// { if(BP(\st)[\autoRunner].isNil) { BP(\st).addAutoRun }; 0 },
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
						{	BP(\st).removeAutoRun;
							if(BP(\st)[\mSpeedPlayer].notNil) {
								BP(\st).autoRunMultiSpeed;  // toggle-should stop
							};
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
						bpCmd: (name: \st, shouldSync: false),
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
						)
					],
					// onStop: {},
					dur: \trigger,  // or \sync
					id: 100,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		// PR(\tlsAff).copy.putAll((
		// 	name: "",
		//	segID: 1,
		// 	initProcesses: {},
		// 	unloadProcesses: {},
		// 	seqPattern: {
		// 		Pn((
		// 			sequence: [],
		// 			onStop: {},
		// 			dur: \trigger,  // or \sync
		// 			id: 0,  // trig id
		//			init: Func(\nextThingTrig).v,
		//			clear: Func(\clearNextTrig).v
		// 		), 1)
		// 	}
		// )),

	];

	~seq = PR(\affSectSeq).copy.sections_(~sections);

	~seq.loadResources(0);
	PR(\transports).chuck(BP(\transports), nil, (model: ~seq));
};
)