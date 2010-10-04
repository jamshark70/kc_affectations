//////// arms section sequencer

// first, put the cursor right below '// init' (on the paren)
// and do ctrl-alt-x

// then put the cursor here and C-c C-c to run the line
t.stop; t.play;

// and if you need to stop:
t.stop;  // by itself

~seq.gotoSection(5);
~seq.play;

"\n\n\n\n\n\n".post;
~seq.stop;

// init
(
s.waitForBoot {
	var	cond = Condition.new;
	(Document.current.path.dirname.dirname +/+ "/common/common-defs.scd").debug.loadPath;
	NotificationCenter.registerOneShot(\lcrvb, \lcrvbexists, \armsSeq, {
		cond.unhang;
	});
	cond.hang;

	(Document.current.path.dirname.dirname +/+ "/arms/arms-defs1.scd").debug.loadPath;

	if(~master.mcgui.isNil) { MixingBoard(\arms, nil, ~master) };

	BP(\segTrig).free;
	PR(\busTrig).chuck(BP(\segTrig), nil, (message: '/segment'));
	BP(\evTrig).free;
	PR(\busTrig).chuck(BP(\evTrig), nil, (message: '/event', busIndex: 4094));
	0.5.wait;
	BP(#[segTrig, evTrig]).play(0);

	Library.put(\diparms, (id: \lc_data, name: \di, quant: 0,
		playWarning: false, shouldSync: false));

	// if(t.isPlaying) { t.stop; "Wait for old sequencer to stop...".die };

	~sections = [
		// TEMPLATE
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

		PR(\tlsAff).copy.putAll((
			name: "A1-axial",
			segID: 1,
			initProcesses: {
				\chuckIf.eval(Fact(\dataIn), BP, \di, nil, (
					filename: "arms/NACL_Arms.wav"
				));
				BP(\di).put(\update, { |obj, what|
					if(what == \stop and: { obj === topEnvironment[\seq] }) {
						BP(~collIndex).stop;
					};
				});
				\chuckIf.eval(PR(\armsSkidMel), BP, \am, nil, (
					glrvbmc: topEnvironment[\glrvbmc],
					lcrvbmc: topEnvironment[\lcrvbmc],
					master: topEnvironment[\master]
				));
				
				BP(\am).amp = 0.9;
				BP(\am).prepareForPlay;
				BP(\am).v.reset;  // drives me NUTS this function isn't called by BP().reset
			},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						{ "///// 10:05 -- axial".debug; 0 },
						bpCmd: (id: \lc_data, name: \di, quant: 0, shouldSync: false),
						loopCmd: (
							id: \am1,
							autoSync: false,
							cmds: [
								funcCmd: topEnvironment[\trigParms],
								\cmdSync,
								{ 2.do { BP(\am).triggerOneEvent(0) }; 0 }
							]
						),
					],
					// onStop: {},
					dur: \trigger,  // or \sync
					id: 2,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "A2-locomotive",
			segID: 2,
			initProcesses: {
				var	p;
				\chuckIf.eval(Fact(\armsChordVC), VC, \ac, nil, Library.at(\rvbs));
				\chuckIf.eval(PR(\armsChord), BP, \acDisp, nil, (
					angleBus: BP(\di).bus.index + 1, // ??
					rotSpeedBus: BP(\di).bus.index + 4
				));
				BP(\acDisp) => VC(\ac);
				0 => BP(\acDisp);
				
				p = BP(\acDisp);
				p.startAuto = p[\saveStartAuto] ? p[\startAuto];
				p.row = p[\saveRow] ? p[\row];
				p.chord = p[\saveChord] ? p[\chord];
				p.fullCh.removeAt(\diss1);
				p.fullCh.removeAt(\diss2);

				BP(\di).playTestFile = false;
			},
			// unloadProcesses: {},
			seqPattern: {
				// var	sect = currentEnvironment;
				Pn((
					sequence: [
						bpCmd: Library.at(\diparms),
						loopCmd: (
							id: \lc1,
							autoSync: false,
							cmds: [
								{ BP(\acDisp).spawnChild(0); 0 },
								funcCmd: topEnvironment[\trigParms],
								\cmdSync
							]
						),
					],
					// onStop: {},
					dur: \trigger,  // or \sync
					id: 3,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "A3-sunrise",
			segID: 3,
			initProcesses: {
				\chuckIf.eval(PR(\sunrise), BP, \sr);
				BP(\sr).ampCtl.value = -23.dbamp;
				VC(\ac) => BP(\sr);
				0 => BP(\sr);
			},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: Library.at(\diparms),
						bpCmd: (name: \sr),
						\cmdSync,
						loopCmd: (
							id: \lc2,
							autoSync: false,
							cmds: [
								{ BP(\acDisp).spawnChild(0); 0 },
								funcCmd: topEnvironment[\trigParms],
								\cmdSync
							]
						)
					],
					// onStop: {},
					dur: \trigger,  // or \sync
					id: 4,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "A4-stacking",
			segID: 4,
			initProcesses: {
				\chuckIf.eval(PR(\stacking), BP, \st, nil, /*(
					// TEST
					root: Pstutter(Pwrand(#[1, 2], #[0.8, 0.2], inf), Pseq([
						Pwhile1({ |inval, next| next < 40 },
							Pseries(26, Pwrand(#[1, 2, 3], #[1, 4, 3].normalizeSum, inf), inf)
						),
						Pwhile1({ |inval, next| next >= 21 },
							Pseries(40, Pwrand(#[-1, -2, -3], #[1, 4, 3].normalizeSum, inf), inf)
						)
					]));
				)*/);
				VC(\ac) => BP(\st);
				0 => BP(\st);
			},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: Library.at(\diparms),
						bpCmd: (id: \stack, name: \st)
					],
					dur: \sync
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "A5-partnering",
			segID: 5,
			initProcesses: {
				\chuckIf.eval(Fact(\shimmerpad), VC, \sp, nil, (
					env: Env.adsr(0.5, 0.4, 0.8, 1.8, curve: -2),
					fenv: Env.adsr(0.5, 0.5, 0.1, 3, peakLevel: 1, bias: 1)
				));
				\chuckIf.eval(PR(\armsInv), BP, \ai);
				BP(\ai).ampCtl.value = 0.045;
				VC(\sp) => BP(\ai);
				0 => BP(\ai);
			},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: Library.at(\diparms),
						bpCmd: (id: \ai, name: \ai,
							// TEST
							prepareBP: { |bp|
								bp.autoRun = true
							}
						)
					],
					// onStop: {},
					dur: \trigger,  // or \sync
					id: 6,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "A6-Shiva",
			segID: 6,
			initProcesses: {
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
				));
				if(BP.exists(\am0).not) { Fact(\shivaBPs).makev(Library.at(\rvbs)) };
				\chuckIf.eval(PR(\thinChords), BP, \tc);
				BP(\tc).finalAmp = 0.2;
				BP(\tc) => VC(\btp);
				\chuckIf.eval(PR(\shivaTrig), BP, \shivaTrig);
				BP(#[am0, am1, am2]).do { |bp| bp.amp = -4.dbamp };
				BP(#[am0, am1, am2, tc]).do({ |bp|
					bp.prepareForPlay;
					bp.v.reset
				});
			},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: Library.at(\diparms),
						loopCmd: (
							id: \shiva,
							autoSync: false,
							cmds: [
								{ BP(\shivaTrig).triggerOneEvent(0); 0 },
								funcCmd: topEnvironment[\trigParms],
								\cmdSync
							],
							clearDoneSignal: { BP(\shivaTrig).stop }
						),
					],
					// onStop: {},
					dur: \trigger,  // or \sync
					id: 7,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "A7-partnering",
			segID: 7,
			// initProcesses: {},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: Library.at(\diparms),
						bpCmd: (name: \ai, quant: 0, prepareBP: { |bp|
							bp.eventStream = nil;
							bp.reset;
							bp.autoRun = false;
						}),
						0.1,
						loopCmd: (
							cmds: [
								{ PR(\loopCmd).copy.putAll((
									cmds: [
										{ BP(\ai).runGesture; 0 },
										funcCmd: topEnvironment[\trigParms],
										\cmdSync										
									],
									repeats: rrand(2, 3)
								)) },
								\cmdSync,
								{ PR(\loopCmd).copy.putAll((
									cmds: [
										{ BP(\shivaTrig).triggerOneEvent(0); 0 },
										funcCmd: topEnvironment[\trigParms],
										\cmdSync										
									],
									repeats: rrand(2, 4),
									clearDoneSignal: { BP(\shivaTrig).stop }
								)) },
								\cmdSync
							]
						),
						\cmdSync
					],
					// onStop: {  },
					dur: \trigger,  // or \sync
					id: 8,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "A8-axial 3 levels",
			segID: 8,
			initProcesses: {
				if(BP.exists(\sm0).not) { Fact(\threelevBP).makev(Library.at(\rvbs)) };
				BP(#[sm0, sm1, sm2]).do { |bp| bp.amp = -11.dbamp };
				\chuckIf.eval(Fact(\l3Trig), BP, \l3Trig, nil, (
					event: (eventKey: \l3Trig),
					playtc: false,
					i: 3
				));
			},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: Library.at(\diparms),
						loopCmd: (
							id: \threelev,
							autoSync: false,
							cmds: [
								{ BP(\l3Trig).triggerOneEvent(0); 0 },
								funcCmd: topEnvironment[\trigParms],
								\cmdSync
							],
							clearDoneSignal: { BP(\l3Trig).stop }
						),
					],
					// onStop: {},
					dur: \trigger,  // or \sync
					id: 9,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "A9-S&I duet",
			segID: 9,
			initProcesses: {
				\chuckIf.eval(PR(\siDuet), BP, \sid);
				VC(\sp) => BP(\sid);
				BP(\sid).finalAmp = 0.037;
				BP(\sid).delta = Pif(Pkey(\high) > 0, Pwhite(3, 5, inf),
					Pwrand(#[1, 2, 3, 4], (1..4).reciprocal, inf)
				);
			},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: Library.at(\diparms),
						loopCmd: (
							id: \s_i,
							autoSync: false,
							highPats: Pseq([
								Pn(`Pn(1, 1), 2),
								`Pseq([0, 1], 1),
								Pn(`Pseq([Pn(0, { rrand(1, 5) }), Pn(1, { rrand(1, 2) })], 1), inf)
							]).asStream,
							cmds: [
								{	var	self = currentEnvironment;
									PR(\bpCmd).copy.putAll((name: \sid, quant: 0, prepareBP: { |bp|
										bp.high = self[\highPats].next.dereference
									}))
								},
								\cmdSync,
								funcCmd: topEnvironment[\trigParms],
								\cmdSync
							]
						)
					],
					onStop: {},
					dur: \trigger,  // or \sync
					id: 9.5,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "A9.5-locomotive(short)",
			segID: 9.5,
			// initProcesses: {},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: Library.at(\diparms),
						loopCmd: (
							id: \lc2,
							autoSync: false,
							cmds: [
								{ BP(\acDisp).spawnChild(0); 0 },
								funcCmd: topEnvironment[\trigParms],
								\cmdSync
							]
						)
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
			name: "A10-manipulation",
			segID: 10,
			initProcesses: {
				\chuckIf.eval(Fact(\lauraManip), BP, \lm, nil, Library.at(\rvbs));
				BP(\lm).amp = 0.45;
				BP(\lm).v.reset;
			},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: Library.at(\diparms),
						loopCmd: (
							id: \lauraManip,
							autoSync: false,
							cmds: [
								{ 2.do { BP(\lm).triggerOneEvent(0) }; 0 },
								funcCmd: topEnvironment[\trigParms],
								\cmdSync
							],
							clearDoneSignal: { BP(\lm).stop }
						),
					],
					// onStop: {},
					dur: \trigger,  // or \sync
					id: 11,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "A11-locomotive(short)",
			segID: 11,
			// initProcesses: {},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: Library.at(\diparms),
						loopCmd: (
							id: \lc2,
							autoSync: false,
							cmds: [
								{ BP(\acDisp).spawnChild(0); 0 },
								funcCmd: topEnvironment[\trigParms],
								\cmdSync
							]
						)
					],
					onStop: {},
					dur: \trigger,  // or \sync
					id: 12,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "A12-Stephen solo",
			segID: 12,
			initProcesses: {
				\chuckIf.eval(PR(\armsSkidMel), BP, \ssol, nil, (
					master: topEnvironment[\master],
					glrvbmc: topEnvironment[\glrvbmc],
					lcrvbmc: topEnvironment[\lcrvbmc],
					event: (eventKey: \polySynthPlayer),
					def: \airskid,
					hiffreq: Pfunc({ |ev|
						var deg = ev[\degree];
						deg = deg + (#[0] ++ ({ #[-1, -2, -3].wchoose(#[0.1, 0.5, 0.4]) } ! 2).integrate);
						Mode(ev[\mode]).cps(deg + 42)
					}),
					delta: Pwhite(1.5, 4.0, inf),
					sustain: Pkey(\delta) * Pwhite(1.8, 2.5, inf),
					amp: 0.45
				));
			},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: Library.at(\diparms),
						loopCmd: (
							id: \stsolo,
							autoSync: false,
							cmds: [
								{ 2.do { BP(\ssol).triggerOneEvent(0) }; 0 },
								funcCmd: topEnvironment[\trigParms],
								\cmdSync
							],
							clearDoneSignal: { BP(\ssol).stop }
						)
					],
					// onStop: {},
					dur: \trigger,  // or \sync
					id: 13,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "A13-cradling",
			segID: 13,
			initProcesses: {
				\chuckIf.eval(PR(\rockingChords), BP, \rc);
				VC(\sp) => BP(\rc);
				BP(\rc).finalAmp = 0.025;
			},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: Library.at(\diparms),
						bpCmd: (id: \rc, name: \rc,
							// TEST
							prepareBP: { |bp|
								bp.autoRun = true
							}
						)
					],
					// onStop: {},
					dur: \trigger,  // or \sync
					id: 14,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "A14-Laura solo",
			segID: 14,
			initProcesses: {
				var p = BP(\acDisp);
				SynthDef(\rotSpeedAuto2, { |outbus, time = 1, proportion = 0.5, speedMul = 1,
					topSpeed = 1|
					ReplaceOut.kr(outbus,
						LFNoise1.kr(Rand(0.5, 1.0) * speedMul).linlin(-1, 1, 0.1, topSpeed)
						* EnvGen.kr(Env(#[1, 1, 0.1], [proportion, 1 - proportion]),
							timeScale: time, doneAction: 2)
					);
				}).add;

				p[\saveStartAuto] ?? { p.saveStartAuto = p[\startAuto] };
				p.startAuto = {
					var	time = ~chordTimeStream.next, proportion = rrand(0.7, 0.85);
					~procTime = time;
					s.makeBundle(nil, {
						~rotSpeed.automate(\rotSpeedAuto2,
							[time: time, proportion: proportion /*, topSpeed: 2 */],
							~event[\voicer].tryPerform(\bus).tryPerform(\asMixer).tryPerform(\fadergroup),
							\addToHead);
						~angle.automate(\angleAuto,
							[speedMul: ~speedMul.asMap, speedBus: ~rotSpeed.bus],
							~rotSpeed.autoSynth, \addAfter);
						~yxRatio.automate(\yxRatioAuto, 
							[inbus: BP(\di).bus.index + 7],
							~rotSpeed.autoSynth, \addAfter);
					});
					OSCpathResponder(s.addr, ['/n_end', ~rotSpeed.autoSynth.nodeID], e { |time, resp, msg|
						resp.remove;
						if(BP.exists(~collIndex)) {
							BP(~collIndex).stop(0);
						};
					}).add;
				};

				p[\saveRow] ?? { p.saveRow = p.row };
				p.row = Plazy({
					var	proportion = rrand(0.3, 0.8);
					Env(#[0.0, 2.12, 0.0], [proportion, 1 - proportion] * ~procTime, \sin).asStream
				});

				p.addChord(\diss1, #[g, 39, 47, 52, 57, 60, 62, 68, 75, 85]);
				p.addChord(\diss2, #[g, 42, 49, 52, 60, 65, 71, 73, 79, 89]);

				p[\saveChord] ?? { p.saveChord = p.chord };
				p.chord = Pif(Pwhite(0.0, 1.0, inf) < Env(#[0, 1], #[50]),
					Pseq(#[diss1, diss2], inf),
					Pxrand(#[c_ish, em, g, am], inf)
				);
				if(p.bpsKeys.includes(\chordTime).not) {
					p.bpsKeys = p.bpsKeys ++ #[chordTime];
				};
			},
			// unloadProcesses: {},
			seqPattern: {
				var	playfunc = Pwrand([
					{ BP(\acDisp).spawnChild(0) },
					{ 2.do { BP(\ssol).triggerOneEvent(0) } },
					{ BP(\ai).runGesture }
				], #[4, 1, 3].normalizeSum, inf).asStream;
				Pn((
					sequence: [
						bpCmd: (name: \ai),
						0.1,
						loopCmd: (
							cmds: [
								{	
									PR(\funcCmd).copy.putAll((
										func: playfunc.next,
										dur: if(0.3.coin) { rrand(2.0, 3.5) } { rrand(5.0, 8.0) }
									))
								},
								\cmdSync
							]
						),
					],
					// onStop: {},
					dur: \trigger,  // or \sync
					id: 15,  // trig id
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

	0.5.wait;

	// ~seq.play;

};
)



t.stop;
t.play;


t.isPlaying

BP.all.stop;

BP.all.do(_.reset);


t.activeCmds.do(_.listVars);

BP(#[am0, am1, am2]).do { |bp| bp.amp = -6.dbamp };
BP(#[sm0, sm1, sm2]).do { |bp| bp.amp = -6.dbamp };

s.sendMsg(\c_set, 4094, 1);
s.sendMsg(\c_set, 4095, 1);

t.stop;


s.sendMsg(\c_set, 4095, 1);
s.sendMsg(\c_set, 4095, 2);
s.sendMsg(\c_set, 4095, 3);
s.sendMsg(\c_set, 4095, 5);

~seq.stop;

ChuckableBrowser.newWindow;

x = ~seq.sections[1];
x.listVars

x.at(\seqPattern).postcs

x.cleanupTrigger;
x.stop

x.currentIterator.activeCmds

~seq.listVars
~seq.sectionNames

BP.all.free;
VC.all.free;
