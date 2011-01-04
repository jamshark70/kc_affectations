// Affectations: Arms controller sequence

(Document.current.path.dirname.dirname +/+ "/arms/arms-defs1.scd")/*.debug*/.loadPath;

[
	PR(\tlsAff).copy.putAll((
		name: "A500-axial",
		segID: 500,
		initProcesses: {
			\chuckIf.eval(Fact(\dataIn), BP, \di, nil, (
				filename: "arms/hands-1_data2.wav" //"arms/NACL_Arms.wav"
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
		unloadProcesses: { BP(\am).free },
		seqPattern: {
			Pn((
				sequence: [
					{ "///// 10:05 -- axial".debug; 0 },
					// bpCmd: (id: \lc_data, name: \di, quant: 0, shouldSync: false),
					loopCmd: (
						id: \am1,
						autoSync: false,
						cmds: [
							funcCmd: topEnvironment[\trigParms],
							\cmdSync,
							{ 2.do { BP(\am).triggerOneEvent(0) }; 0 }
						]
					),
					3.0,
					{ BP(\st).stop(0); 0 }
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 510,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "A510-locomotive",
		segID: 510,
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
			p.amp = -20.dbamp;

			BP(\di).playTestFile = false;

			\chuckIf.eval(Fact(\locomoLead), VC, \lcm, nil, Library.at(\rvbs));
			// VC(\lcm).env.target.level = -19.dbamp;
			\chuckIf.eval(PR(\locoMel), BP, \lcm);
			VC(\lcm) => BP(\lcm);
			1 => BP(\lcm);
		},
		unloadProcesses: { BP(#[acDisp, lm]).free; VC(#[ac, lm]).free },
		seqPattern: {
			// var	sect = currentEnvironment;
			Pn((
				sequence: [
					bpCmd: Library.at(\diparms),
					[
						loopCmd: (
							id: \lc1,
							autoSync: false,
							cmds: [
								{ BP(\acDisp).spawnChild(0); 0 },
								0.05,
								{ BP(BP(\acDisp).lastSpawned).automationTime + rrand(-1.0, 0.25) }
							]
						),
						loopCmd: (
							cmds: [
								funcCmd: topEnvironment[\trigParms],
								\cmdSync,
								// false == let bp finish after section stops
								bpCmd: (name: \lcm, shouldSync: false),
								funcCmd: (
									setDoneSignal: {
										~doneSignal = Updater(BP(\lcm), e { |obj, what, more|
											if(more == \stopped) { ~stop.() };
										});
									},
									clearDoneSignal: { ~doneSignal.remove }
								),
								\cmdSync
							]
						)
					],
				],
				// onStop: {},
				onStop: {
					BP.keys.do { |key|
						if("acDisp[0-9]+".matchRegexp(key.asString)) { BP(key).stop(0) };
					};
				},
				dur: \trigger,  // or \sync
				id: 520,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "A520-sunrise",
		segID: 520,
		initProcesses: {
			\chuckIf.eval(PR(\sunrise), BP, \sr);
			BP(\sr).ampCtl.value = -23.dbamp;
			VC(\ac) => BP(\sr);
			0 => BP(\sr);

			// free up unused resources
			// note, sections load resources one in advance
			// so this actually happens when entering A2
			topEnvironment[\seq].sections.do { |sect|
				if(sect.segID < 500) { sect.prUnload };
			};
		},
		unloadProcesses: { BP(\sr).free },
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
							0.05,
							{ BP(BP(\acDisp).lastSpawned).automationTime + rrand(-1.0, 0.25) }
						]
					)
				],
				// onStop: {},
				onStop: {
					BP.keys.do { |key|
						if("acDisp[0-9]+".matchRegexp(key.asString)) { BP(key).stop(0) };
					};
				},
				dur: \trigger,  // or \sync
				id: 530,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "A530-stacking",
		segID: 530,
		initProcesses: {
			\chuckIf.eval(PR(\stacking), BP, \stack, nil, (
				// TEST
				root: Pstutter(Pwrand(#[1, 2], #[0.8, 0.2], inf), Pseq([
					Pwhile1({ |inval, next| next < 40 },
						Pseries(26, Pwrand(#[1, 2, 3], #[1, 4, 3].normalizeSum, inf), inf)
					),
					Pwhile1({ |inval, next| next >= 21 },
						Pseries(40, Pwrand(#[-1, -2, -3], #[1, 4, 3].normalizeSum, inf), inf)
					)
				]))
			));
			VC(\ac) => BP(\stack);
			0 => BP(\stack);

			BP(\stack).length = Plazy({ |ev|
				Pseries.fromEndpoints(1, exprand(0.05, 0.4), ev[\num])
				* (Pwhite(3.0, 4.5, inf) - Pseries(0, Pkey(\dur), inf))
			});
			BP(\stack).attackTimeScale = Pkey(\length).linlin(0.2, 3.0, 0.1, 1, \minmax);
			BP(\stack).decayTimeScale = Pkey(\length).linlin(0.2, 3.0, 0.1, 1, \minmax);
			BP(\stack).mod_lev = Pkey(\length).linlin(0.2, 3.0, Pwhite(4.5, 8.0, inf), 2.5, \minmax);
		},
		unloadProcesses: { BP(\stack).free },
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: Library.at(\diparms),
					bpCmd: (id: \stack, name: \stack)
				],
				dur: \trigger,  // or \sync
				id: 540,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "A540-partnering",
		segID: 540,
		initProcesses: {
			\chuckIf.eval(Fact(\shimmerpad), VC, \sp, nil, (
				env: Env.adsr(0.5, 0.4, 0.8, 1.8, curve: -2),
				fenv: Env.adsr(0.5, 0.5, 0.1, 3, peakLevel: 1, bias: 1)
			).putAll(Library.at(\rvbs)));
			\chuckIf.eval(PR(\armsInv), BP, \ai);
			BP(\ai).ampCtl.value = 0.115; // 0.045;
			VC(\sp) => BP(\ai);
			0 => BP(\ai);
		},
		unloadProcesses: { BP(\ai).free; VC(\sp).free },
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
				id: 550,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "A550-Shiva",
		segID: 550,
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
			).putAll(Library.at(\rvbs)));
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
		unloadProcesses: {
			BP(#[am0, am1, am2, tc, shivaTrig]).free; VC(#[am, btp]).free;
		},
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
				id: 560,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "A560-partnering",
		segID: 560,
		initProcesses: {
			\chuckIf.eval(Fact(\armsmelVC), VC, \bmel, nil, (
				env: { var length = NamedControl.kr(\length, 0); Env.perc(0.01, length) },
				// env: Env.adsr(0.01, 2.5, 0.05, 1.2),
				isMono: false
			));
			VC(\bmel).v.setArgDefaults([ffreq: 12258]);

			\chuckIf.eval(Fact(\bmelBP), BP, \bmel);
			0 => BP(\bmel);

			topEnvironment[\clock96] ?? {
				topEnvironment[\clock96] = TempoClock(96/60);
			};
			topEnvironment[\clock96] => BP(\bmel);
		},
		// MUST free BP first
		unloadProcesses: {
			BP(\bmel).free; VC(\bmel).free;
			topEnvironment[\clock96].stop;  // do I really want to do this?
			topEnvironment[\clock96] = nil;
		},
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
					{ PR(\loopCmd).copy.putAll((
						id: \pt1,
						cmds: [
							{ BP(\ai).runGesture; rrand(2.5, 5.0) } //,
							// funcCmd: topEnvironment[\trigParms],
							// \cmdSync										
						] //,
						// repeats: rrand(2, 3)
					)) },
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
					funcCmd: (func: {
						~iterator.findActive(\pt1).stop;
						BP(#[am, am0, am1, am2]).do { |bp| bp.reset; bp.v.reset };
					}),
					{ PR(\loopCmd).copy.putAll((
						id: \pt2,
						cmds: [
							{ BP(\shivaTrig).triggerOneEvent(0); rrand(1.5, 2.5) } //,
							// funcCmd: topEnvironment[\trigParms],
							// \cmdSync										
						],
						repeats: rrand(3, 5),
						clearDoneSignal: { BP(\shivaTrig).stop }
					)) },
					// funcCmd: topEnvironment[\trigParms],
					\cmdSync,
					funcCmd: (func: {
						~iterator.findActive(\pt2).stop;
						BP(\bmel).dur = BP(\bmel).simpleDur;
						BP(\bmel).ampMul.value = 0.5;
						BP(\bmel).numDescents = Pwhite(3, 5, inf);
						BP(\bmel).numDecays = Pwhite(4, 7, inf);
						BP(\bmel).distance = BP(\bmel).origDistance;
					}),
					subIterCmd: (
						id: \pt3,  // I need this id below
						clock108: TempoClock.default,
						subIter: TLSequenceIterator([
							loopCmd: (
								cmds: [
									{ BP(\ai).runGesture; rrand(2.5, 5.0) }
								]
							),
							loopCmd: (
								cmds: [
									{ rrand(2.0, 4.0) },
									bpCmd: (name: \bmel),
									\cmdSync,
									{ rrand(3.0, 5.0) }
								]
							)
						])
					),
					funcCmd: topEnvironment[\trigParms],
					\cmdSync,
					funcCmd: (func: { ~iterator.findActive(\pt3).stop }),
					loopCmd: (
						autoSync: false,
						cmds: [
							{ BP(\acDisp).spawnChild(0); rrand(4.5, 8.5) } //,
						]
					)
				],
				onStop: {
					BP.keys.do { |key|
						if("acDisp[0-9]+".matchRegexp(key.asString)) { BP(key).stop(0) };
					};
				},
				dur: \trigger,  // or \sync
				id: 570,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "A570-axial 3 levels",
		segID: 570,
		initProcesses: {
			if(BP.exists(\sm0).not) { Fact(\threelevBP).makev(Library.at(\rvbs)) };
			BP(#[sm0, sm1, sm2]).do { |bp| bp.amp = -11.dbamp };
			\chuckIf.eval(Fact(\l3Trig), BP, \l3Trig, nil, (
				event: (eventKey: \l3Trig),
				playtc: false,
				i: 3
			));
		},
		unloadProcesses: { BP(#[sm0, sm1, sm2, l3Trig]).free },
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
				id: 580,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "A580-S&I duet",
		segID: 580,
		initProcesses: {
			\chuckIf.eval(PR(\siDuet), BP, \sid);
			VC(\sp) => BP(\sid);
			BP(\sid).finalAmp = 0.05; // 0.037;
			BP(\sid).delta = Pif(Pkey(\high) > 0, Pwhite(3, 5, inf),
				Pwrand(#[1, 2, 3, 4], (1..4).reciprocal, inf)
			);
			BP(\sid).printStopMsg = false;

			\chuckIf.eval(Fact(\armsBass), VC, \abs, nil, Library.at(\rvbs));
			\chuckIf.eval(PR(\armsbass), BP, \abs);
			VC(\abs) => BP(\abs);
			// 1 => BP(\abs); //?
		},
		unloadProcesses: { BP(#[sid, abs]).free; VC(\abs).free },
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: Library.at(\diparms),
					{	// var	self = currentEnvironment;
						PR(\bpCmd).copy.putAll((name: \abs, quant: 0, prepareBP: { |bp|
							bp.dur = Pseq(#[1, 6], 1);  // not random, don't really need {}
							VC(\abs).env.target.level = -19.dbamp;
						}))
					},
					2,
					loopCmd: (
						id: \s_i,
						autoSync: false,
						repeats: 2,
						i: 0,
						// highPats: Pseq([
						// 	Pn(`Pn(1, 1), 2),
						// 	`Pseq([0, 1], 1),
						// 	Pn(`Pseq([Pn(0, { rrand(1, 5) }), Pn(1, { rrand(1, 2) })], 1), inf)
						// ]).asStream,
						cmds: [
							{	var	self = currentEnvironment;
								~i = ~i + 1;
								if(~i == 2) { NotificationCenter.notify(\s_i, \go) };
								PR(\bpCmd).copy.putAll((name: \sid, quant: 0, prepareBP: { |bp|
									bp.high = Pn(1, 1) //self[\highPats].next.dereference
								}))
							},
							\cmdSync,
							funcCmd: topEnvironment[\trigParms],
							\cmdSync
						]
					),
					// simply block until second chord
					funcCmd: (
						setDoneSignal: {
							~doneSignal = NotificationCenter.register(\s_i, \go, \wait, e { ~stop.() });
						},
						clearDoneSignal: {
							NotificationCenter.unregister(\s_i, \go, \wait);
						}
					),
					\cmdSync,
					{	BP(\abs).dur = Plazy({
							Pseq([rrand(2, 4), rrand(8, 12)], 1) * 0.5
						});
						rrand(3.5, 6.0)
					},
					{	BP(\sid).high = Pseq([Pn(0, { rrand(1, 5) }), Pn(1, { rrand(1, 2) })], 1);
						0
					},
					loopCmd: (
						cmds: [
							{	var delays = [0, rrand(0.5, 2.5)];
								[delays, [
									[bpCmd: (name: \abs)],
									[bpCmd: (name: \sid, prepareBP: { |bp| bp.highStream.reset })],
								].rotate(2.rand)].flop.flat.debug("add TLSeq")
							},
							\cmdSync,
							{ rrand(0.8, 2.5).debug("wait") }  // rrand(3.5, 6.0)
						]
					),
					{	BP(\bmel).numDescents = Pwhite(5, 9, inf);
						BP(\bmel).numDecays = Pwhite(4, 7, inf);
						BP(\bmel).distance = BP(\bmel).origDistance + 12;
						rrand(7.0, 10.0)
					},
					loopCmd: (
						cmds: [
							bpCmd: (name: \bmel),
							\cmdSync,
							{ rrand(5.0, 9.0) }
						]
					)
				],
				onStop: {},
				dur: \trigger,  // or \sync
				id: 600,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

/*
	PR(\tlsAff).copy.putAll((
		name: "A590-locomotive(short)",
		segID: 590,
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
				id: 600,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),
*/

	PR(\tlsAff).copy.putAll((
		name: "A600-manipulation",
		segID: 600,
		initProcesses: {
			\chuckIf.eval(Fact(\lauraManip), BP, \lm, nil, Library.at(\rvbs));
			BP(\lm).amp = 0.45;
			BP(\lm).v.reset;
		},
		unloadProcesses: { BP(\lm).free },
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
				id: 610,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "A610-locomotive(short)",
		segID: 610,
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
				id: 620,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "A620-Stephen solo",
		segID: 620,
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
		unloadProcesses: { BP(\ssol).free },
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
				id: 630,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "A630-cradling",
		segID: 630,
		initProcesses: {
			\chuckIf.eval(PR(\rockingChords), BP, \rc);
			VC(\sp) => BP(\rc);
			BP(\rc).finalAmp = 0.05;
		},
		unloadProcesses: { BP(\rc).free },
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
				id: 640,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "A640-Laura solo",
		segID: 640,
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
					~yxRatio.automate({
							EnvGen.kr(Env([Rand(0, 2.5), Rand(3.5, 5), Rand(0, 2.5)], [proportion, 1 - proportion], \sine))
						},
						nil,
						~rotSpeed.autoSynth, \addAfter);
					// ~yxRatio.automate(\yxRatioAuto, 
					// 	[inbus: BP(\di).bus.index + 7],
					// 	~rotSpeed.autoSynth, \addAfter);
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
		unloadProcesses: {},
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
				id: 650,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "A650-Silence before face",
		segID: 650,
		seqPattern: {
			Pn((
				sequence: [
					{
						BP.keys.do { |bpk|
							if(#[di, segTrig, evTrig].includes(bpk).not) { BP(bpk).stop(0) };
						};
						0
					}
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 1000,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	))
]