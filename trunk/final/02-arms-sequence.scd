// Affectations: Arms controller sequence

(Document.current.path.dirname.dirname +/+ "/arms/arms-defs1.scd")/*.debug*/.loadPath;

[
	PR(\tlsAff).copy.putAll((
		name: "A500-axial",
		segID: 500,
		initProcesses: {
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
					{ BP(\di).setStartTime(9, 20); 0 },
					bpCmd: Library.at(\diparms),
					// bpCmd: (id: \lc_data, name: \di, quant: 0, shouldSync: false),
					loopCmd: (
						id: \am1,
						autoSync: false,
						cmds: [
							{ 2.do { BP(\am).triggerOneEvent(0) }; 0 },
							funcCmd: topEnvironment[\trigParms],
							\cmdSync
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
			p.amp = -11.dbamp;

			BP(\di).playTestFile = Library.at(\isJamesBox);

			\chuckIf.eval(Fact(\locomoLead), VC, \lcm, nil, Library.at(\rvbs));
			// VC(\lcm).env.target.level = -19.dbamp;
			\chuckIf.eval(PR(\locoMel), BP, \lcm);
			VC(\lcm) => BP(\lcm);
			1 => BP(\lcm);
		},
		unloadProcesses: { BP(#[acDisp, lcm]).free; VC(#[ac, lcm]).free },
		seqPattern: {
			// var	sect = currentEnvironment;
			Pn((
				sequence: [
					{ BP(\di).setStartTime(9, 46); 0 },
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
			BP(\sr).ampCtl.value = -20.5.dbamp;
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
					{ BP(\di).setStartTime(10, 21); 0 },
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
				// root: Pstutter(Pwrand(#[1, 2], #[0.8, 0.2], inf), Pseq([
				// 	Pwhile1({ |inval, next| next < 40 },
				// 		Pseries(26, Pwrand(#[1, 2, 3], #[1, 4, 3].normalizeSum, inf), inf)
				// 	),
				// 	Pwhile1({ |inval, next| next >= 21 },
				// 		Pseries(40, Pwrand(#[-1, -2, -3], #[1, 4, 3].normalizeSum, inf), inf)
				// 	)
				// ]))
				// root: Pwhile1({ |inval, next| next >= 21 },
				// 	Pseries(
				// 		26,
				// 		Pwrand(#[1, 2, 3], #[1, 4, 3].normalizeSum, inf)
				// 			* sign(Pkey(\ymax) - Pkey(\prevymax)),
				// 		inf
				// 	)
				// )
				// previous version, was possible to stop very early
				// if sign() was negative at the start
				// now, don't consider stop condition until an upper threshold is reached
				root: Prout({ |inval|
					var	x = 26,
						incrStream = (Pwrand(#[1, 2, 3], #[1, 4, 3].normalizeSum, inf)
							* sign(Pkey(\ymax) - Pkey(\prevymax))).asStream,
						dontStopYet = true;
					while { dontStopYet or: { x >= 21 } } {
						inval = x.yield;
						x = x + incrStream.next(inval);  // inval needed for Pkey
						if(dontStopYet) {
							case
								{ x > 35 } { dontStopYet = false }
								// hover around the low bound but don't stay in the same place
								{ x < 21 } { x = x - incrStream.next(inval) };
						};
					};
				})
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
			BP(\stack).ampCtl.value = -14.5.dbamp;
		},
		unloadProcesses: { BP(\stack).free },
		seqPattern: {
			Pn((
				sequence: [
					{ BP(\di).setStartTime(10, 27); 0 },
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
			// I got stuck nodes on this a LOT, so, disable voice stealing
			VC(\sp).v.steal = false;
			\chuckIf.eval(PR(\armsInv), BP, \ai);
			BP(\ai).ampCtl.value = -16.5.dbamp; // 0.115; // 0.045;
			VC(\sp) => BP(\ai);
			0 => BP(\ai);
		},
		unloadProcesses: { BP(\ai).free; VC(\sp).free },
		seqPattern: {
			Pn((
				sequence: [
					{ BP(\di).setStartTime(10, 48); 0 },
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
			BP(#[am0, am1, am2]).do { |bp, i|
				bp.event.soundID = i;
				bp.amp = -4.dbamp;
			};
		},
		unloadProcesses: {
			BP(#[am0, am1, am2, tc, shivaTrig]).free; VC(#[am, btp]).free;
		},
		seqPattern: {
			Pn((
				sequence: [
					{ BP(\di).setStartTime(11, 4); 0 },
					bpCmd: Library.at(\diparms),
					{
						BP(\shivaTrig).v.reset;
						BP(#[am, am0, am1, am2]).do { |bp|
							bp.gate = 0.8;
							bp.root = 67;
							bp.freqlag = 0.3;
							bp.distance = 17;
							bp.reset;
							bp.v.reset;
						};
						BP(#[am0, am1, am2, tc]).do({ |bp|
							bp.prepareForPlay;
							bp.v.reset
						});
						0
					},
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
			).putAll(Library.at(\rvbs)));
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
					{ BP(\di).setStartTime(11, 44); 0 },
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
						BP(\shivaTrig).reset;
						BP(#[am, am0, am1, am2]).do { |bp|
							bp.gate = 0.8;
							bp.root = 67;
							bp.freqlag = 0.3;
							bp.distance = 17;
							bp.reset;
							bp.v.reset;
						};
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
					{ BP(\di).setStartTime(12, 7); 0 },
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
					{ BP(\di).setStartTime(12, 54); 0 },
					bpCmd: Library.at(\diparms),
					{	// var	self = currentEnvironment;
						PR(\bpCmd).copy.putAll((name: \abs, quant: 0, prepareBP: { |bp|
							bp.dur = Pseq(#[1, 6], 1);  // not random, don't really need {}
							VC(\abs).env.target.level = -19.dbamp;
						}))
					},
					1.5,
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
							{
								if(~repeats > 1) {
									PR(\funcCmd).copy.putAll(topEnvironment[\trigParms])
								} {
									PR(\funcCmd).copy
								};
							},
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
						bpCmdArray: [
							[bpCmd: (name: \abs)],
							[bpCmd: (name: \sid, prepareBP: { |bp| bp.highStream.reset })],
						],
						cmds: [
							{	var delays = [0, rrand(0.5, 2.5)];
								[delays, ~bpCmdArray.rotate(2.rand)].flop.flat
							},
							\cmdSync,
							{ rrand(0.8, 2.5) }  // rrand(3.5, 6.0)
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

	PR(\tlsAff).copy.putAll((
		name: "A600-manipulation",
		segID: 600,
		initProcesses: {
			\chuckIf.eval(Fact(\lauraManip), BP, \lm, nil, Library.at(\rvbs));
			BP(\lm).amp = -1.dbamp;
			BP(\lm).v.reset;
		},
		unloadProcesses: { BP(\lm).free },
		seqPattern: {
			Pn((
				sequence: [
					{ BP(\di).setStartTime(13, 30); 0 },
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
		name: "A610-loco-prep",
		segID: 610,
		initProcesses: {
			\chuckIf.eval(PR(\bAnacrusis), BP, \bana);
			0 => BP(\bana);
			BP(\bana).mainAmpCtl.value = -17.dbamp;
		},
		unloadProcesses: {
			BP(\bana).free;
		},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \bana, shouldSync: false),
					gcAutoSynthCmd: (gc: BP(\bana).mainAmpCtl, name: \ctlEnv, outName: \outbus,
						env: Env(#[-24, -17].dbamp, #[10], 2.1), connect: 0 //, shouldSync: false
					)
				],
				onStop: { BP(\bana).stop(DelayTimeSpec(1.0)) },
				dur: \trigger,  // or \sync
				id: 620,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "A620-locomotive(short)",
		segID: 620,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					{ BP(\di).setStartTime(13, 57); 0 },
					bpCmd: Library.at(\diparms),
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
				onStop: {
					BP.keys.do { |key|
						if("acDisp[0-9]+".matchRegexp(key.asString)) { BP(key).stop(0) };
					};
				},
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
			BP(\rc).finalAmp = -19.dbamp;

			\chuckIf.eval(PR(\shimmerbass), BP, \shb);
			VC(\sp) => BP(\shb);
			0 => BP(\shb);
		},
		unloadProcesses: { BP(#[rc, shb]).free },
		seqPattern: {
			var	runGestParms = (
				func: {
					var strm = BP(\rc).runGesture;
					~doneSignal = NotificationCenter.register(strm, \done,
						currentEnvironment, e { // |code|
							~stop.()
						});
				},
				setDoneSignal: { ~doneSignal = true },
				clearDoneSignal: { ~doneSignal.remove }
			);
			Pn((
				sequence: [
					{ BP(\di).setStartTime(14, 6); 0 },
					bpCmd: (name: \di, playWarning: false, shouldSync: false),
					bpCmd: (name: \rc, prepareBP: { |bp|
						bp.autoRun = false;
						// bp.ffreqCtl.value = 3861;
						bp.distCtl.value = 5;
						bp.reset;
					}),
					0.01,
					TLSequenceIterator([
						gcAutoSynthCmd: (gc: BP(\rc).ffreqCtl, name: \ctlEnv, outName: \outbus,
							env: Env(#[14000, 3861], #[50], \exp), connect: 0),
						6,
						gcAutoSynthCmd: (gc: BP(\rc).distCtl, name: \ctlEnv, outName: \outbus,
							env: Env(#[5, 12], #[32])/*, connect: 0*/)
					]).autoSyncAtEnd_(false), // cool! cmds get promoted right away
					loopCmd: (
						repeats: 2,
						cmds: [
							funcCmd: runGestParms,
							\cmdSync,
							{ if(~repeats > 1) { rrand(2, 4) * 0.5 } { 0 } }
						]
					),
					\cmdSync,
					{
						BP(#[am0, am1, am2]).do { |bp, i|
							bp.gate = 0.8 * #[1, 0.4, 0.1][i];
							bp.root = 67 + #[0, -0.1, 0.1][i];
							bp.freqlag = Penvir((sideEffect: { |x| x }), Pfunc({ |ev|
								~sideEffect.(
									if(~prevMidi.notNil) {
										(ev[\midi] absdif: ~prevMidi).linlin(0, 16, 1.2, 0.7)
									} { 0.9 },
									~prevMidi = ev[\midi]
								)
							}));
							bp.distance = Pkey(\gate).linlin(0.1, 0.75, 45, 8);
							bp.prepareForPlay;
							bp.reset
						};
						0
					},
					loopCmd: (
						repeats: 3,
						clearDoneSignal: {
							thisThread.clock.sched(rrand(1.0, 2.0), { BP(#[am0, am1, am2]).stop })
						},
						cmds: [
							{
								fork {
									BP(#[am0, am1, am2]).do { |bp| bp.triggerOneEvent(0); rrand(0.2, 0.5).wait };
								};
								/*~lastDelta =*/ rrand(3, 6) * 0.5
							}
						]
					),
					\cmdSync,
					loopCmd: (
						// repeats: 2,
						cmds: [
							funcCmd: runGestParms,
							\cmdSync,
							// { if(~repeats > 1) { rrand(2, 4) * 0.5 } { 0 } }
							rrand(3, 7) * 0.5
						]
					),
					TLSequenceIterator([
						{ rrand(2.0, 4.0) },
						{ BP(\shb).prepareForPlay; 0 },
						{	var	loopc = PR(\loopCmd).copy.putAll((
							doneSignal: true,
							clearDoneSignal: { BP(\shb).stop },
							cmds: [
								funcCmd: (
									setDoneSignal: {
										~doneSignal = Updater(BP(\shb), e { |obj, what, event|
											if(what == \oneEventPlayed) {
												loopc.bassEvent = event;
												~stop.();
											}
										});
									},
									func: {
										BP(\shb).triggerOneEvent(0);
									},
									clearDoneSignal: { ~doneSignal.remove }
								),
								\cmdSync,
								{
									~bassEvent[\dur] + if(~bassEvent[\dur] > 0) {
										rrand(6.0, 15.0)
									} { 0 }
								}
							]
						));
							loopc
						}
					]).autoSyncAtEnd_(false),
					{ rrand(5, 9) },
					loopCmd: (
						id: \am,
						cmds: [
							loopCmd: (
								repeats: { rrand(3, 7) },
								clearDoneSignal: {
									thisThread.clock.sched(rrand(1.0, 2.0), { BP(#[am0, am1, am2]).stop })
								},
								cmds: [
									{
										fork {
											BP(#[am0, am1, am2]).do { |bp|
												bp.triggerOneEvent(0);
												rrand(0.2, 0.5).wait;
											};
										};
										~lastDelta = rrand(3, 6) * 0.5
									}
								]
							),
							\cmdSync,
							{ rrand(3, 7) }
						]
					),
					\sync,
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
			\chuckIf.eval(PR(\dataReader), BP, \dr, nil, (autoPlay: false));
			0 => BP(\dr);

			\chuckIf.eval(Fact(\lsoloTrig), BP, \lsyx, nil, (
				autoPlay: false,
				doTrig: { |data|
					case { data[0] > ~thresh } {
						~hasFiredHigh = true;
						BP(#[qc, lsac]).stop;
						// if(BP.exists(\lsm)) { BP(\lsm).stop };
						BP(\yxsw).nextNoteNow;
						NotificationCenter.registerOneShot(BP(\yxsw).esp, \event, \bass, { |event|
							(	voicer: VC(\abs).v,
								mode: event[\mode],
								freq: event[\degrees][0] - 7,
								delta: 1,
								length: rrand(3.5, 5.5),
								gate: 0.4
							).parent_(ProtoEvent(\voicerNote).v.parent)
							.play;
						});
					}
					{ data[0] < ~lowThresh and: { #[nil, true].includes(~hasFiredHigh) } } {
						~hasFiredHigh = false;
						~lowThreshTime = ~clock.beats;
						if(BP(\bfl).isPlaying.not) { BP(\bfl).play };
						BP(\lsac).play;
						BP(\qc).reset;
						BP(\qc).triggerOneEvent(DelayTimeSpec(0.4));
					};
				}
			));

			\chuckIf.eval(Fact(\acceltrig), BP, \lsac, nil, (
				autoPlay: false,
				doTrig: { |latest|
					if(latest.sign > 0 and: { (BP(\qc).clock.beats - BP(\qc).v[\eventSchedTime]) > 1.0 }) {
						BP(\qc).triggerOneEvent(0);
						if(BP.exists(\lsm) and: { BP(\lsm).isPlaying.not and: {
							(BP(\lsyx).clock.beats - BP(\lsyx).lowThreshTime) > 2.0
						} }) {
							BP(\lsm).play(DelayTimeSpec(rrand(0.7, 1.5)));
						};
					};
				},
				autoPlay: false
			));

			\chuckIf.eval(PR(\yxswirls), BP, \yxsw);
			VC(\ac) => BP(\yxsw);
			0 => BP(\yxsw);

			\chuckIf.eval(PR(\quietChords), BP, \qc);
			VC(\sp) => BP(\qc);
			0 => BP(\qc);
			BP(\qc).finalAmp = -16.dbamp;

			\chuckIf.eval(PR(\bellFlourish), BP, \bfl);
			VC(\bmel) => BP(\bfl);
			0 => BP(\bfl);
			BP(\bfl).printStopMsg = false;
			BP(\bfl).ampMul = -5.dbamp;

			\chuckIf.eval(Fact(\lsoloMel), BP, \lsm);
			VC(\lcm) => BP(\lsm);
			BP(\lsm).event.mainAmp = -17.5.dbamp; // orig == -12.5, +3

			// BP(\yxsw).update = { |obj, what, more|
			// 	case { what == \play } { BP(\yxsw).play(DelayTimeSpec(0.1)) }
			// 		{ more == \stopped } { BP(\yxsw).stop };
			// };
			// BP(\lsyx).addDependant(BP(\yxsw).v);
		},
		unloadProcesses: {
			// BP(\lsyx).removeDependant(BP(\yxsw).v);
			BP(#[lsm, lsac, qc, bfl, yxsw, lsyx, dr]).free;
		},
		seqPattern: {
			Pn((
				sequence: [
					{ BP(\di).setStartTime(14, 53); 0 },
					bpCmd: Library.at(\diparms),
					bpCmd: (name: #[dr, lsyx, yxsw])
				],
				onStop: { BP(#[yxsw, lsyx, dr]).stop(0) },
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
							if(#[di, segTrig, evTrig, osclog].includes(bpk).not) { BP(bpk).stop(0) };
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