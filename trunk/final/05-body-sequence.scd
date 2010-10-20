// Affectations: Body controller sequence

(Document.current.path.dirname.dirname +/+ "/body/body-defs.scd")/*.debug*/.loadPath;

[
	PR(\tlsAff).copy.putAll((
		name: "B2500-Laura 1",
		segID: 2500,
		initProcesses: {
			\chuckIf.eval(PR(\armsSkidMel), BP, \bskid, nil,
				(def: \bellskid).putAll(Library.at(\rvbs)));
			BP(\bskid).prepareForPlay;
		},
		unloadProcesses: { BP(\bskid).free },
		seqPattern: {
			Pn((
				sequence: [
					{	BP(\bskid).v.reset;
						0
					},
					loopCmd: (
						id: \am1,
						autoSync: false,
						firstWait: false,
						cmds: [
							{	if(~firstWait) {
									PR(\funcCmd).copy.putAll(topEnvironment[\trigParms])
								} {
									~firstWait = true;
									PR(\funcCmd).copy  // will stop immediately
								}
							},
							\cmdSync,
							{ 2.do { BP(\bskid).triggerOneEvent(0) }; 0 }
						]
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2510,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2510-reset axial",
		segID: 2510,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					{	BP(\bskid).v.reset;
						0
					},
					loopCmd: (
						id: \am1,
						autoSync: false,
						firstWait: false,
						cmds: [
							// {	if(~firstWait) {
							// 		PR(\funcCmd).copy.putAll(topEnvironment[\trigParms])
							// 	} {
							// 		~firstWait = true;
							// 		PR(\funcCmd).copy  // will stop immediately
							// 	}
							// },
							// \cmdSync,
							{ 2.do { BP(\bskid).triggerOneEvent(0) }; rrand(0.6, 1.1) }
						]
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2520,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2520-locomotive",
		segID: 2520,
		initProcesses: {
			\chuckIf.eval(Fact(\dataIn), BP, \di, nil, (
				filename: "arms/hands-1_data2.wav"
			));
			\chuckIf.eval(Fact(\armsChordVC), VC, \ac, nil, Library.at(\rvbs));
			\chuckIf.eval(PR(\armsChord), BP, \acDisp, nil, (
				angleBus: BP(\di).bus.index + 1, // ??
				rotSpeedBus: BP(\di).bus.index + 4
			));
			BP(\acDisp) => VC(\ac);
			0 => BP(\acDisp);
			BP(\acDisp).mod_lev = Pkey(\distance).linlin(Pkey(\distNear), Pkey(\distFar), 9.0, 5.0);
			// inharmonic spectra
			BP(\acDisp).mod_ratio = Pwhite(1, 6, inf) + Pswitch1([
				Pwhite(0.1, 0.3, inf),
				Pwhite(0.7, 0.9, inf)
			], Prand(#[0, 1], inf));
			\chuckIf.eval(Fact(\shimmerpad), VC, \sp, nil, (
				env: Env.adsr(0.5, 0.4, 0.8, 1.8, curve: -2),
				fenv: Env.adsr(0.5, 0.5, 0.1, 3, peakLevel: 1, bias: 1)
			).putAll(Library.at(\rvbs)));
			if(VC(\sp).env.target.postSends.every { |send|
				send.outbus.tryPerform(\asMixer) !== topEnvironment[\glrvbmc]
			}) {
				VC(\sp).env.target.newPostSend(topEnvironment[\glrvbmc], 0.6);
			};
			\chuckIf.eval(Fact(\formantfx2), BP, \ffx2, nil,
				(chan: VC(\sp).env.target, fmtSearch: "sopr"));
			BP(\ffx2).fadeIn_(0.05).fadeOut_(3);
		},
		unloadProcesses: { VC(\ac).free; BP(\acDisp).free },
		seqPattern: {
			Pn((
				sequence: [
					{	
						BP(\acDisp).mod_lev = Pkey(\distance)
							.linlin(Pkey(\distNear), Pkey(\distFar), 9.0, 5.0);
						// inharmonic spectra
						BP(\acDisp).mod_ratio = Pwhite(1, 6, inf) + Pswitch1([
							Pwhite(0.1, 0.3, inf),
							Pwhite(0.7, 0.9, inf)
						], Prand(#[0, 1], inf));
						BP(\acDisp).startAuto = PR(\armsChord).v[\startAuto];
						BP(\acDisp).amp = -21.dbamp;
						0
					},
					loopCmd: (
						cmds: [
							{ BP(\acDisp).spawnChild(0); 5.2 }
						]
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2530,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2530-stop low, arm up",
		segID: 2530,
		initProcesses: {
		},
		unloadProcesses: { VC(\sp).free; BP(\ffx2).free },
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \ffx2/*, dur: 15*/, shouldSync: false),
					0.07,
					funcCmd: (
						dur: 8,
						func: {
							VC(\sp).env.target.level = -4.dbamp;
							fork {
								~nodes = VC(\sp).v.trigger(#[55, 110], 0.15,
									[glrvbamt: 0, lcrvbamt: 0, freqlag: 6], lat: s.latency);
								0.05.wait;
								#[59, 71].midicps.do { |f, i| ~nodes[i].set([freq: f], latency: s.latency) }
							};
						},
						clearDoneSignal: { defer(e { ~nodes.do(_.release) }, 1.5) }
					)
				],
				onStop: { defer({ BP(\ffx2).stop(0) }, 2.0) },
				dur: \trigger,  // or \sync
				id: 2540,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2540-reset axial 2",
		segID: 2540,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					{	BP(\bskid).v.reset;
						0
					},
					loopCmd: (
						id: \am1,
						autoSync: false,
						firstWait: false,
						cmds: [
							// {	if(~firstWait) {
							// 		PR(\funcCmd).copy.putAll(topEnvironment[\trigParms])
							// 	} {
							// 		~firstWait = true;
							// 		PR(\funcCmd).copy  // will stop immediately
							// 	}
							// },
							// \cmdSync,
							// { 2.do { BP(\bskid).triggerOneEvent(0) }; 0 }
							{ 2.do { BP(\bskid).triggerOneEvent(0) }; rrand(0.6, 1.1) }
						]
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2550,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2550-Locomotive",
		segID: 2550,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					{	
						BP(\acDisp).mod_lev = Pkey(\distance)
							.linlin(Pkey(\distNear), Pkey(\distFar), 9.0, 5.0);
						// inharmonic spectra
						BP(\acDisp).mod_ratio = Pwhite(1, 6, inf) + Pswitch1([
							Pwhite(0.1, 0.3, inf),
							Pwhite(0.7, 0.9, inf)
						], Prand(#[0, 1], inf));
						BP(\acDisp).amp = -21.dbamp;
						BP(\acDisp).spawnChild(0);
						0
					},
					loopCmd: (
						cmds: [
							{ BP(\acDisp).spawnChild(0); rrand(2.5, 7.0) }
						]
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2560,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2560-Wild arms",
		segID: 2560,
		initProcesses: {
			\chuckIf.eval(Fact(\messyDrums), BP, \md, nil, (master: topEnvironment[\master]));
			\chuckIf.eval(Fact(\words), BP, \sw, nil, Library.at(\rvbs));
		},
		unloadProcesses: { BP(#[md, sw]).free },
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \ffx2/*, dur: 15*/, shouldSync: false),
					0.07,
					funcCmd: (
						// dur: 12,
						id: \gsharp,
						doneSignal: true,
						shouldSync: false,
						func: {
							VC(\sp).env.target.level = -4.dbamp;
							fork {
								~nodes = VC(\sp).v.trigger(#[55, 110], 0.05,
									[glrvbamt: 0, lcrvbamt: 0, freqlag: 7], lat: s.latency);
								0.05.wait;
								#[68, 80].midicps.do { |f, i| ~nodes[i].set([freq: f], latency: s.latency) }
							};
						},
						clearDoneSignal: {
							fork {
								3.5.wait;
								~nodes.do(_.release);
								1.5.wait;
								BP(\ffx2).stop(0);
							}
						}
					),
					0.5,
					bpCmd: (name: \md, prepareBP: { |bp|
						bp.ampCtl.value = 0.2;
						bp.delta = Pseq([
							Pexprand(0.05, 0.2, { rrand(3, 11) }),
							Pwhite(0.3, 0.7, 1)
						], inf) * Env(#[1, 4.5], #[15], 5);
					}),
					{ TempoClock.default => BP(\sw); 0 },
					bpCmd: (name: \sw, prepareBP: { |bp|
						var	slowdown = Env(#[1, 4.5], #[15], 5);
						bp.noisydelta = Pwhite(0.3, 0.6, inf) * slowdown;
						bp.noisytime = Pkey(\delta).linlin(0.3, 0.6, 0.4, 0.4);
						bp.noisynormAmp = 1.5;
						bp.word = Plazy({ Prand(~pts, inf) });
						bp.pitcheddelta = Pwhite(0.1, 0.4, inf) * slowdown;
						bp.pitchedtime = Pkey(\delta) * Pwhite(1.4, 2.1, inf);
						bp.pfreq = (Paccumbounce(32, 46,
							Pwrand(#[-2, -1, 1, 2], #[0.2, 0.2, 0.3, 0.3], inf), inf)
							+.x Pseries(0, Pwhite(1, 4, 3)))
							.clump(3)
							.collect { |deg, ev| Mode(ev[\mode]).cps(deg) };
						bp.pitchProb.value = 0.88;
						bp.pitchednormAmp = 3;
						bp.mode = Pseq([
							Pn(\e0, { rrand(12, 24) }),
							Pstutter(Pwhite(2, 6, inf), Prand(Mode.keys.asArray.select { |key|
								key != \e0 and: { key.asString.last == $0 }
							}, { rrand(1, 4) }))
						], inf);
					}),
					4,
					mixerAutoSynthCmd: (mixer: VC(\sp).env.target,
						name: \ctlPoint, outName: \outbus, shouldSync: false,
						value: -9.dbamp, time: 12
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2570,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2570-arm touch",
		segID: 2570,
		initProcesses: {
			\chuckIf.eval(Fact(\armsmelVC), VC, \am, nil, Library.at(\rvbs));
			\chuckIf.eval(Fact(\bodymel), BP, \bmel);
			VC(\am) => BP(\bmel);
			VC(\am).v.portaTime = 0.9;
		},
		unloadProcesses: { VC(\am).free; BP(\bmel).free; },
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \ffx2, shouldSync: false, playWarning: false),
					{
						if(VC(\sp).env.target.controls[\level].autoSynth.isNil) {
							PR(\mixerAutoSynthCmd).copy.putAll((mixer: VC(\sp).env.target,
								name: \ctlPoint, outName: \outbus, shouldSync: false,
								value: -9.dbamp, time: 12
							))
						} { 0 }
					},
					funcCmd: (
						id: \csharp,
						doneSignal: true,
						shouldSync: false,
						func: {
							fork {
								~nodes = VC(\sp).v.trigger(#[68, 80].midicps, 0.05,
									[glrvbamt: 0, lcrvbamt: 0, freqlag: 7], lat: s.latency);
								0.05.wait;
								#[73, 85].midicps.do { |f, i| ~nodes[i].set([freq: f], latency: s.latency) }
							};
						},
						clearDoneSignal: {
							~iterator.findActive(\gsharp).stop;
							fork {
								3.5.wait;
								~nodes.do(_.release);
							}
						}
					),
					12,
					// 35 plays thru last note then stops
					bpCmd: (name: \bmel, dur: 35)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2580,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2580-drums 1",
		segID: 2580,
		initProcesses: {
			\chuckIf.eval(Fact(\lowdrum), BP, \ldr);
			\chuckIf.eval(Fact(\hidrum), BP, \hdr);
			\chuckIf.eval(PR(\bassline), BP, \bss);
			VC(\ac) => BP(\bss);
			topEnvironment[\clock52] => BP(\bss);
			\chuckIf.eval(Fact(\bodySteps), BP, \bst);
		},
		unloadProcesses: { BP(#[ldr, hdr, bss, bst]).free },
		seqPattern: {
			Pn((
				sequence: [
					subIterCmd: (
						shouldSync: false,
						subIter: TLSequenceIterator([
							Quant(1),
							{ thisThread.clock.beatsPerBar = 4; 0 },
							bpCmd: (name: \bss, dur: 3, quant: 4, prepareBP: { |bp|
								bp.calcBar = \simpleBassLine;
								bp.densityCtl.value = 1;
								bp.ampCtl.value = -7.5.dbamp;
							}),
							bpCmd: (name: \hdr, quant: 4, shouldSync: false, prepareBP: { |bp|
								bp.densityCtl.value = 0
							}),
							gcAutoSynthCmd: (gc: BP(\hdr).ampCtl, name: \ctlEnv, outName: \outbus,
								env: Env(#[0, 0.5], #[16], 3.5), time: 1, connect: 0),
							7.75,  // 8; 0 - 9.23
							bpCmd: (name: \bss, dur: 3, quant: 4),
							8,  // 16; 9.23 - 18.46
							bpCmd: (name: \bss, quant: 4, shouldSync: false/*, prepareBP: { |bp|
								bp.calcBar = \makeBassNotes;
							}*/),
							16,  // 32; 18.46 - 36.92
							bpCmd: (name: \ldr, quant: 4, shouldSync: false, prepareBP: { |bp|
								bp.ampCtl.value = 0.4;
							}),
							16,  // 48; 36.92 - 55.38
							{ BP(\bss).calcBar = \makeBassNotes; BP(\bss).densityCtl.value = 0; 8 },
							gcAutoSynthCmd: (gc: BP(\hdr).densityCtl, name: \ctlPoint, outName: \outbus,
								value: 6, time: 45, shouldSync: false),
							// long, just to keep it going until the cue
							// "long" isn't enough... it keeps stopping the processes early!
							10000,  // 72; 55.38 - 1:23.07
						]).shouldSync_(false),
						clock108: topEnvironment[\clock52]
					),
					32,
					funcCmd: (func: {
						fork {
							// they wouldn't die thru the commands, so force them
							VC(\sp).releaseAll;
							3.5.wait;
							BP(\ffx2).stop(0);
						}
					})
				],
				onStop: {
					fork {
						// and make extra fricken' sure
						VC(\sp).releaseAll;
						3.5.wait;
						BP(\ffx2).stop(0);
					}
				},
				dur: \trigger,  // or \sync
				id: 2590,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2590-suspension 1",
		segID: 2590,
		initProcesses: {
			currentEnvironment.putAll(Library.at(\rvbs));
			\chuckIf.eval(Fact(\armsmelVC), VC, \sus, nil, (isMono: false).putAll(Library.at(\rvbs)));
			\chuckIf.eval(PR(\finalSus), BP, \sus);
			0 => BP(\sus);
			VC(\sus) => BP(\sus);
		},
		unloadProcesses: { BP(\sus).free },
		seqPattern: {
			Pn((
				sequence: [
					[
						bpCmd: (name: \sus, prepareBP: { |bp|
							bp.repeats = 1;
							bp.phraseDur = 18;
							bp.degree = Pseq(#[35, 36, 38, 38.5, 41, 47.5], 1);
							bp.delta = Pexprand(3.0, 6.0, inf) * 0.35;
							bp.ampCtl.value = 0.28;
						}),
						6,
						gcAutoSynthCmd: (gc: BP(\sus).ampCtl, name: \ctlPoint, outName: \outbus,
							value: 0, curve: -2.1, time: 12)
					],
					subIterCmd: (
						shouldSync: false,
						subIter: TLSequenceIterator([
							Quant(8, -0.25),
							{
								BP(\bss).ampCtl.value = -7.5.dbamp;
								BP(\hdr).ampCtl.value = 0.5;
								BP(\ldr).ampCtl.value = 0.4;
								0
							},
							bpCmd: (name: #[bss, hdr, ldr], shouldSync: false, playWarning: false),
/***** 42:30 - sus1
**** 43:47 (0:34) - arms
**** 44:32 (1:19) - walking
**** 45:08 (1:55) - sus2*/

							16,

							{	var p = BP(\sw);
								topEnvironment[\clock52] => p;
								1 => p;
								p.pitchedmode = Pwrand(#[d0, e0], #[0.8, 0.2], inf);
								p.synth = \pitched;
								p.pitcheddelta = Pdelta(Pwhite(0, 15, inf) * 0.25, 4);
								p.pitchedtime = Pexprand(0.4, max(0.4, Pkey(\delta) * 1.2), inf);
								p.preamp = 9;
								p.pitchednormAmp = 3;
								// later: p.pitcheddelta = Pwhite(3, 10, inf) * 0.25;
								0
							},
							bpCmd: (name: \sw, dur: 32, shouldSync: false, quant: 4),
							8,  // 8; 0 - 9.23
							gcAutoSynthCmd: (gc: BP(\bss).densityCtl, name: \ctlPoint, outName: \outbus,
								value: 4, time: 24),
							24,  // 32; 9.23 - 36.923

							{	
								BP(\acDisp).mod_lev = Pkey(\distance)
								.linlin(Pkey(\distNear), Pkey(\distFar), 4, 2); //PR(\armsChord).mod_lev;
								BP(\acDisp).mod_ratio = PR(\armsChord).mod_ratio;
								BP(\acDisp).amp = -18.dbamp;
								BP(\acDisp).startAuto = {
									var	time = ~chordTimeStream.next, proportion = rrand(0.7, 0.85);
									fork {
										~rotSpeed.automate({
												Line.kr(0, 1, time, doneAction: 2);
												LFDNoise1.kr(Rand(0.8, 1.5)).range(1.8, 3.0)
											},
											[time: time],
											~event[\voicer].tryPerform(\bus).tryPerform(\asMixer)
												.tryPerform(\fadergroup),
											\addToHead);
										s.sync;
										~angle.automate(\angleAuto,
											[speedMul: ~speedMul.asMap, speedBus: ~rotSpeed.bus],
											~rotSpeed.autoSynth, \addAfter);
										~yxRatio.automate({
												EnvGen.kr(Env([3, 5, 3], [proportion, 1 - proportion], \sine))
											}, 
											nil,
											~rotSpeed.autoSynth, \addAfter);
										OSCpathResponder(s.addr, ['/n_end', ~rotSpeed.autoSynth.nodeID], e { |time, resp, msg|
											resp.remove;
											if(BP.exists(~collIndex)) {
												BP(~collIndex).stop(0);
											};
										}).add;
									};
								};
								0
							},
							loopCmd: (
								repeats: 2,
								shouldSync: false,
								cmds: [
									{ BP(\acDisp).spawnChild(0); rrand(3.5, 6.0) }
								]
							),

							16,  // 48; 36.92 - 55.38
							bpCmd: (name: \bst, shouldSync: false, quant: `nil, dur: 16, prepareBP: { |bp|
								bp.ampCtl.value = 0.8;
								bp.filtAmp = 0; // Env(#[0, 1, 0], #[8, 8]);
								bp.filtDecay = 0.011; // Env(#[0.011, 0.018, 0.011], #[12, 4]);
								bp.delta = 0.5; // Pwrand(#[0.25, 0.5], #[0.3, 0.7], inf);
								bp.amp = Env(#[0.05, 1, 0.05], #[10, 6], #[3, -3]);
							}),

							12,  // 60; 55.38 - 69.23
							loopCmd: (
								repeats: 2,
								shouldSync: false,
								cmds: [
									{ BP(\acDisp).spawnChild(0); rrand(3.5, 6.0) }
								]
							),
							4,  // 64; 55.38 - 73.84

							8,  // 72; 73.84 - 83.07

							bpCmd: (name: \bst, shouldSync: false, quant: `nil, dur: 32, prepareBP: { |bp|
								bp.ampCtl.value = 0.234;
								bp.filtAmp = 0; // Env(#[0, 1, 0], #[8, 8]);
								bp.filtDecay = 0.011; // Env(#[0.011, 0.018, 0.011], #[12, 4]);
								bp.delta = 0.5;
								bp.amp = Env(#[0.5, 1], #[10], 3);
							}),
							
							8,
							{	var bp = BP(\bst);
								bp.delta = Pwrand(#[0.25, 0.5], #[0.4, 0.6], inf);
								// bp.filtAmp = Pseg(
								// 	Pseq([0, Pwhite(0.3, 1, inf)], 1),
								// 	Pwhite(3.0, 9.0, inf),
								// 	\lin
								// );
								// bp.filtDecay = Pseg(
								// 	Pseq([0.011, Pexprand(0.011, 0.07, inf)], 1),
								// 	Pwhite(3.0, 9.0, inf),
								// 	\exp
								// );
								bp.filtAmp = Env(#[0, 1, 0.2, 0], #[7, 7, 10]);
								bp.filtDecay = Env(#[0.011, 0.015, 0.011], #[10, 14], \exp);
								8
							},

							// 88; - 101.5 (+18)
							
							bpCmd: (name: \sw, shouldSync: false, quant: 4),

							10000


							// { BP(\bss).stop(-1); 0 },
							// bpCmd: (name: \bst, quant: 4, shouldSync: false),
							// gcAutoSynthCmd: (gc: BP(\bst).ampCtl, name: \ctlEnv, outName: \outbus,
							// 	env: Env(#[0, 0.3], #[26], 3.5), time: 1, connect: 0),
							// 16,
							// bpCmd: (name: \bss, quant: 4, shouldSync: false),
							// 256
						]).shouldSync_(false),
						clock108: topEnvironment[\clock52]
					),
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2600,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2600-suspension 2",
		segID: 2600,
		// initProcesses: {
		// },
		// unloadProcesses: { BP(\sus).free },
		seqPattern: {
			Pn((
				sequence: [
					{ BP(\sw).stop(0); BP(#[bss, hdr]).stop(4); 0 },
					[
						bpCmd: (name: \sus, prepareBP: { |bp|
							bp.repeats = 1;
							bp.phraseDur = 18;
							bp.degree = Pseq(#[40, 43, 45, 46, 49, 52.5], 1);
							bp.delta = Pexprand(3.0, 6.0, inf) * 0.35;
							bp.ampCtl.value = 0.28;
						}),
						6,
						gcAutoSynthCmd: (gc: BP(\sus).ampCtl, name: \ctlPoint, outName: \outbus,
							value: 0, curve: -2.1, time: 12)
					],
					subIterCmd: (
						shouldSync: false,
						subIter: TLSequenceIterator([
							Quant(8, -0.25),
							{
								BP(\hdr).densityCtl.value = 12;
								BP(\hdr).ampCtl.value = 0.5;
								BP(\bss).densityCtl.value = 5;
								BP(\bss).ampCtl.value = -7.5.dbamp;
								BP(\ldr).ampCtl.value = 0.4;
								0
							},
							bpCmd: (name: #[bss, hdr, ldr], shouldSync: false, playWarning: false),

							bpCmd: (name: \md, shouldSync: false, quant: 4, prepareBP: { |bp|
								bp.ampCtl.value = 0.2;
								bp.numInBar = Pwhite(4, 10, inf);
								bp.delta = PnNilSafe(Plazy({ |ev|
									var	avail = (0..31).scramble * 0.125,
										pts = { |i| avail[i] } ! ~numInBarStream.next(ev);
									Pdelta(Pseq(pts.sort ++ #[4], 1), 4)
								}), inf);
								bp.ampCtl.value = 0.2;
							}),
							// gcAutoSynthCmd: (gc: BP(\md).ampCtl, name: \ctlEnv, outName: \outbus,
							// 	env: Env(#[0.05, 0.2], #[1], \exp), connect: 0, time: 16),

							{	var p = BP(\sw);
								topEnvironment[\clock52] => p;
								1 => p;
								p.pitchedmode = Pwrand(#[d0, e0], #[0.8, 0.2], inf);
								p.synth = \pitched;
								p.pitcheddelta = Pdelta(Pwhite(0, 15, inf) * 0.25, 4);
								p.pitchedtime = Pexprand(0.4, max(0.4, Pkey(\delta) * 1.2), inf);
								p.pitchednormAmp = 3;
								// later: p.pitcheddelta = Pwhite(3, 10, inf) * 0.25;
								0
							},
							bpCmd: (name: \sw, shouldSync: false, quant: 4, prepareBP: { |bp|
								bp.pitcheddelta = Pwhite(2, 6, inf) * 0.25;
								bp.pitchedtime = Pwhite(0.4, 0.8, inf);
							}),

							bpCmd: (name: \ffx2/*, dur: 15*/, shouldSync: false),
							0.07,
							funcCmd: (
								// dur: 12,
								id: \gsharp,
								doneSignal: true,
								shouldSync: false,
								func: {
									VC(\sp).env.target.level = -11.dbamp;
									fork {
										~nodes = VC(\sp).v.trigger(#[55, 110, 73, 146], 0.05,
											[glrvbamt: 0, lcrvbamt: 0, freqlag: 7], lat: s.latency);
										0.05.wait;
										#[68, 80, 73, 85].midicps.do { |f, i| ~nodes[i].set([freq: f], latency: s.latency) }
									};
								},
								clearDoneSignal: {
									fork {
										3.5.wait;
										~nodes.do(_.release);
										1.5.wait;
										BP(\ffx2).stop(0);
									}
								}
							),

							// c. 52 beats
							60,
							{ BP(\sw).pitchednormAmp = Env(#[3, 0], #[20.8], -2.1); 0 },
							// work around a stupid oversight in my lib
							// you can't \cmdSync to a TLSequenceIterator
							// because the TLSeq never gets set as the last command... BOOOOO!!
							subIterCmd: (
								subIter: TLSequenceIterator(#[bss, hdr, ldr, md].collect { |key|
									PR(\gcAutoSynthCmd).copy.putAll((
										gc: BP(key).ampCtl, name: \ctlPoint, outName: \outbus,
										value: 0, time: 24, curve: -2.1
									));
								}),
								clock108: topEnvironment[\clock52]
							),
							\cmdSync,
							{ BP(#[bss, hdr, ldr, md, sw]).stop(0); 0 }
						]).shouldSync_(false),
						clock108: topEnvironment[\clock52]
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2610,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2610-sus3-last cue",
		segID: 2610,
		// initProcesses: {
		// },
		// unloadProcesses: { BP(\sus).free },
		seqPattern: {
			Pn((
				sequence: [
					// { BP.all.stop; 0 },
					bpCmd: (name: \sus, prepareBP: { |bp|
						bp.repeats = 1;
						bp.phraseDur = 24;
						bp.degree = Pseq(#[48, 53, 56], 1);
						bp.delta = Pexprand(3.0, 6.0, inf);
						bp.ampCtl.value = 0.28;
					}),
					7,
					gcAutoSynthCmd: (gc: BP(\sus).ampCtl, name: \ctlPoint, outName: \outbus,
						level: 0, time: 19, curve: -2.1),
					mixerAutoSynthCmd: (mixer: VC(\sp).env.target, name: \ctlPoint, outName: \outbus,
						level: 0, time: 19, curve: -2.1),
					\cmdSync,
					{ BP.all.stop; VC(\sp).releaseAll; 0 }
				],
				onStop: { BP.all.stop },
				dur: \sync,
				id: 2620,  // trig id
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

]