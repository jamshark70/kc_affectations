// Affectations: Body controller sequence

var	fades = {
	var fadeSpecs = [
		[\sw, \sw, \pitchednormAmp, Env(#[3, 0], #[20.8], -2.1)],
		[#[am0, am1, am2], \shivaTrig, \amp, Env(#[1, 0], #[22], -2.1)]
	];
	// fxampStream *should* be there if the segments played through
	// according to the timing in the choreography
	// but, we can't guarantee that the cue operator will not royally screw up
	// and advance out of BOTH segments that use \ltf too quickly
	// if that happens, A/ the show is f'cked and B/ BP(\ltf).fxampStream.next will throw an error
	// I am not sure which is worse
	if(BP(\ltf).v[\fxampStream].notNil) {
		fadeSpecs = fadeSpecs.add([
			\ltf, \ltf, \fxamp, Env([BP(\ltf).fxampStream.next, 0], #[22])
		]);
	};
	fadeSpecs.do { |info|
		var bps, checkBP, key, env;
		#bps, checkBP, key, env = info;
		bps.do { |bp|
			if(BP(checkBP)[\isFading] != false) {
				BP(bp).put(key, env);
				BP(bp).isFading = true;
			};
		};
	};
	
	// work around a stupid oversight in my lib
	// you can't \cmdSync to a TLSequenceIterator
	// because the TLSeq never gets set as the last command... BOOOOO!!
	PR(\subIterCmd).copy.putAll((
		subIter: TLSequenceIterator(
			#[bss, hdr, ldr, md].collect { |key|
				PR(\gcAutoSynthCmd).copy.putAll((
					gc: BP(key).ampCtl, name: \ctlPoint, outName: \outbus,
					value: 0, time: 24, curve: -2.1
				));
			}
			++
			[	\cmdSync,
				{ BP(#[bss, hdr, ldr, md, sw, ltf]).stop(0); 0 }
			]
		),
		clock108: topEnvironment[\clock52]
	))
};

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
		// initProcesses: {
		// },
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
							Library.at(\vizAddr).tryPerform(\sendMsg,
								\note, \sp.hash, s.latency, 59.midicps.explin(20, 20000, -1, 1),
								8, 0.15, nil, nil);
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
							Library.at(\vizAddr).tryPerform(\sendMsg,
								\note, \sp.hash, s.latency, 68.midicps.explin(20, 20000, -1, 1),
								8, 0.15, nil, nil);
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
						], inf) * Env(#[1, 4.5], #[25], 5);
					}),
					{ TempoClock.default => BP(\sw); 0 },
					bpCmd: (name: \sw, prepareBP: { |bp|
						var	slowdown = Env(#[1, 4.5], #[25], 5);
						bp.isFading = false;
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
							Library.at(\vizAddr).tryPerform(\sendMsg,
								\note, \sp.hash, s.latency, 73.midicps.explin(20, 20000, -1, 1),
								8, 0.15, nil, nil);
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
			// \chuckIf.eval(Fact(\bodySteps), BP, \bst);

			\chuckIf.eval(PR(\lowTonesFmt), BP, \ltf, nil, Library.at(\rvbs));
			0 => BP(\ltf);
		},
		unloadProcesses: { BP(#[ldr, hdr, bss, /*bst,*/ ltf]).free },
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
							8,  // 32; 18.46 - 36.92
							bpCmd: (name: \ltf, shouldSync: false,
								prepareBP: { |bp|
									bp.fxamp = 18.dbamp;
									bp.delta = Pn(1, 1);
									bp.time = 45;
									bp.envel = Env.linen(0.25, 0.25, 0.5, 1, \sqr);
									bp.mode = \a0;
									bp.degree = #[41, 39, 38, 36, 33];
									bp.isFading = false;
								},
								setDoneSignal: {
									~doneSignal = Updater(BP(\ltf), e { |obj, what|
										if(what == \notesEmpty) {
											obj.stop(0);  // which will also kill the cmd
										};
									});
								},
								clearDoneSignal: { ~doneSignal.remove }
							),
							8,
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
			BP(\sus).printStopMsg = false;

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
			BP(\tc).finalAmp = 0.4;
			BP(\tc) => VC(\btp);
			\chuckIf.eval(PR(\shivaTrig), BP, \shivaTrig);
			BP(#[am0, am1, am2]).do { |bp, i|
				bp.event.soundID = i;
				bp.amp = -4.dbamp;
			};
			topEnvironment[\clock52] => BP(\shivaTrig);
			BP(\shivaTrig).printStopMsg = false;

			\chuckIf.eval(Fact(\opening), BP, \op, nil, Library.at(\rvbs));
			\chuckIf.eval(Fact(\openingSteps), BP, \st);
			topEnvironment[\clock52] => BP(\st);

			\chuckIf.eval(Fact(\bells), BP, \bel, nil,
				Library.at(\rvbs).copy.put(\glrvbmc, topEnvironment[\cRvbMc]));
			topEnvironment[\clock52] => BP(\bel);
			BP(\bel).printStopMsg = false;
			BP(\bel).v.put(\reset, {
				~objects.keysValuesDo { |id, obj|
					obj[\args].pairsDo { |name, pattern|
						~makeStreamForKey.((id ++ name).asSymbol)
					}
				}
			});
		},
		unloadProcesses: {
			BP(#[sus, am0, am1, am2, shivaTrig, tc, op, st]).free;
			VC(#[am, btp]).free;
		},
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
						id: \sus1sub,
						subIter: TLSequenceIterator([
							Quant(8, -0.25),
							{
								BP(\bss).ampCtl.value = -7.5.dbamp;
								BP(\hdr).ampCtl.value = 0.5;
								BP(\ldr).ampCtl.value = 0.4;
								0
							},
							bpCmd: (name: #[bss, hdr, ldr], /*shouldSync: false,*/ playWarning: false),
/***** 42:30 - sus1
**** 43:47 (0:34) - arms
**** 44:32 (1:19) - walking
**** 45:08 (1:55) - sus2*/

							16,

							{	var p = BP(\sw);
								topEnvironment[\clock52] => p;
								1 => p;
								p.pfreq = (Paccumbounce(39, 50,
									Pwrand(#[-2, -1, 1, 2], #[0.2, 0.2, 0.3, 0.3], inf), inf)
									-.x Pseries(0, Pwhite(1, 4, 3))
								).clump(3)
								.collect { |deg, ev| Mode(ev[\mode]).cps(deg) };
								p.pitchedmode = Pwrand(#[d0, e0], #[0.8, 0.2], inf);
								p.synth = \pitched;
								p.pitcheddelta = Pdelta(Pwhite(0, 15, inf) * 0.25, 4);
								p.pitchedtime = Pexprand(0.4, max(0.4, Pkey(\delta) * 1.2), inf);
								p.preamp = 9;
								p.pitchednormAmp = 3;
								p.isFading = false;
								// later: p.pitcheddelta = Pwhite(3, 10, inf) * 0.25;
								0
							},
							bpCmd: (name: \sw, dur: 32, shouldSync: false, quant: 4),
							8,  // 8; 0 - 9.23
							gcAutoSynthCmd: (gc: BP(\bss).densityCtl, name: \ctlPoint, outName: \outbus,
								value: 4, time: 24),
							24,  // 32; 9.23 - 36.923

// shiva recall
							{	var bp = BP(\shivaTrig);
								bp.delta = Pwrand(#[0.5, 1, 1.5, 2],
									#[1, 3, 1, 2.5].normalizeSum, 8);
								bp.playtc = 0.5.asPattern.coin; //true;
								bp.isFading = false;
								bp.reset; bp.v.reset;

								BP(#[am0, am1, am2]).do { |bp|
									bp.amp = 1; // -4.dbamp;
									bp.gate = Pexprand(0.1, 0.22, inf);
									bp.scaleRoot = 9;
									bp.root = 57;
									bp.phrases = #[
										[1, 9, 6],
										[5, 11, 10, 7, 13],
										[1, 9, 11, 8]
									];
									bp.makeStreamForKey(\degree);
								};
								0
							},
							loopCmd: (
								id: \shivaTrig,
								// shouldSync: false,
								numEv: Pseq([8, Pwhite(5, 11, inf)]).asStream,
								deltaBase: Pwrand(#[0.5, 1, 1.5, 2],
									#[1, 3, 1, 2.5].normalizeSum, inf),
								cmds: [
									{ rrand(4, 10) },
									{	var db = ~deltaBase, numEv = ~numEv;
										PR(\bpCmd).copy.putAll((
											name: \shivaTrig,
											prepareBP: { |bp|
												bp.delta = Pseq([
													Pfin(numEv.next - 1, db),
													rrand(4.5, 6.5)
												], 1)
											}
										))
									},
									\cmdSync
								]
							),

							16,
							{
								// BP(\bel).lowbellfLow = Pif(
								// 	Pkey(\delta) < 5,
								// 	Pexprand(700, 1200, inf),
								// 	Pexprand(140, 240, inf)
								// );
								BP(\bel).lowbellfLow = Pexprand(800, 1250, inf);
								BP(\bel).lowbellbeaterFilt = Pexprand(6000, 12000, inf);
								BP(\bel).delta = Pseq([
									Pwrand(#[0.5, 0.75, 1], #[0.2, 0.4, 0.4],
										{ rrand(2, 4) }),
									6
								], 1);
								BP(\bel).sustain = Pwhite(5.0, 8.0, inf);
								BP(\bel).lowbellatten = 0.04;
								0
							},
							loopCmd: (
								id: \bel,
								// shouldSync: false,
								cmds: [
									bpCmd: (name: \bel, prepareBP: { |bp|
										bp.makeStreamForKey(\delta);
										bp.reset;
									}),
									\cmdSync,
									Quant(1),
									{ rrand(4, 15) }
								]
							),

							15,  // 48; 36.92 - 55.38
							bpCmd: (name: \st, shouldSync: false, quant: `nil, /*dur: 16,*/
								prepareBP: { |bp|
									bp.autoRun = false;
									bp.ampCtl.value = 1;  // 1.12?
								}
							),
							Quant(-1, -0.1),
							loopCmd: (
								id: \stretchSteps,
								// shouldSync: false,
								nStrm: Pseq([10, Pwhite(5, 12, inf)]).asStream,
								cmds: [
									{	var n = ~nStrm.next,
											dl = Pseq([Pn(0.5, n), Pseq(#[0.25, 0.5, 0.75], 1)], 1),
											dur = dl.asStream.all.sum;
										BP(\st).runGesture((
											gest: \slowStepStretch,
											numEv: n+3,
											delta: dl,
											yEnds: #[15, 5]
										), true, \slowStepBody);
										// BP(\st).endStreamHook = { |stream, id|
										// 	if(id == \slowStepBody) {
										// 		~streamEndHook = nil;	// remove me
										// 		BP(\st).debug("stopping").stop;
										// 	};
										// };
										dur + rrand(4, 10)
									}
								]
							),

							0.1 + 12,  // 60; 55.38 - 69.23
							4,  // 64; 55.38 - 73.84

							8,  // 72; 73.84 - 83.07

							
							8,

							// 88; - 101.5 (+18)
							
							bpCmd: (name: \sw, shouldSync: false, quant: 4, prepareBP: { |bp|
								bp.isFading = false;
							}),

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
		initProcesses: {
			\chuckIf.eval(PR(\noiseFmt), BP, \nf, nil, Library.at(\rvbs));
		},
		unloadProcesses: {
			BP(\nf).free;
		},
		seqPattern: {
			Pn((
				sequence: [
					funcCmd: (
						func: {
							// #[shivaTrig, bel, stretchSteps].do { |key|
							// 	~iterator.findActive(key).debug(key).stop;
							// };
							~iterator.findActive(\sus1sub).stop;
							BP(\sw).stop(0);
							BP(#[bss, hdr, ldr]).stop(DelayTimeSpec(1.5));
						}
					),
					[
						bpCmd: (name: \sus, prepareBP: { |bp|
							bp.repeats = 1;
							bp.phraseDur = 25;
							bp.degree = Pseq(#[40, 43, 45, 46, 49, 52.5], 1);
							bp.delta = Pexprand(3.0, 6.0, inf) * 0.35;
							bp.ampCtl.value = 0.28;
						}),
						10,
						gcAutoSynthCmd: (gc: BP(\sus).ampCtl, name: \ctlPoint, outName: \outbus,
							value: 0, curve: -2.1, time: 15)
					],
					bpCmd: (name: \nf,
						prepareBP: { |bp|
							bp.fxDelta = Pwhite(0.4, 1.4, inf);
							bp.fxamp = 18.dbamp;
							bp.panCtl.watch.automate {
								SinOsc.kr(SinOsc.kr(0.05).exprange(0.07, 0.75), Rand(0, 2pi))
							};
							bp.delta = Pwhite(1.0, 3.0, inf);
							bp.time = Pkey(\delta) * Pwhite(1.4, 2.5, inf);
							bp.envel = Env.linen(0.3, 0.4, 0.3, 1, \sqr);
							bp.patKey = \noiseSrc;
							bp.event.distFar = 80;
						},
						clearDoneSignal: {
							BP(\nf).panCtl.stopWatching.stopAuto;
						}
					),
					gcAutoSynthCmd: (gc: BP(\nf).hpfCtl, name: \ctlEnv, outName: \outbus,
						env: Env(#[4500, 1250, 7500], #[11, 24], \exp),
						connect: 0
					),
					gcAutoSynthCmd: (gc: BP(\nf).distCtl, name: \ctlEnv, outName: \outbus,
						env: Env(#[60, 8, 42], #[11, 24], #[-5, 2.1]),
						connect: 0
					),

					9,
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
							Library.at(\vizAddr).tryPerform(\sendMsg,
								\note, \sp.hash, s.latency, 68.midicps.explin(20, 20000, -1, 1),
								8, 0.15, nil, nil);
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

					3,
					subIterCmd: (
						shouldSync: false,
						id: \sus2sub,
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
							bpCmd: (name: #[bss, hdr, ldr], shouldSync: false,
								playWarning: false,
								prepareBP: { |bp| bp.reset }
							),

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
								// workaround: BP(\sw) is not supposed to be playing here
								// but Lorne found that it was at one point
								// but, if the clock is wrong we need the warning, so...
								if(p.clock !== topEnvironment[\clock52]) {
									if(p.isPlaying) {
										"Somehow BP(\\sw) is playing when setting the clock. The clock may be wrong going forward".warn;
									} {
										topEnvironment[\clock52] => p;
									}
								};
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
								bp.isFading = false;
							}),

							16,
							bpCmd: (name: \ltf, shouldSync: false,
								prepareBP: { |bp|
									bp.isFading = false;
									bp.fxamp = 18.dbamp;
									bp.delta = Pwhite(14.0, 25.0, inf);
									bp.time = Pkey(\delta) * Pwhite(0.7, 1.2, inf);
									bp.envel = Env.linen(0.25, 0.25, 0.5, 1, \sqr);
									bp.mode = \a0;
									// ensure interval between topnotes is at least 5
									bp.degree = (Penvir((last: 0, sideEffect: { |x| x }), Pwhite(32, 41, inf).select { |num| ~sideEffect.((num absdif: ~last) > 4, ~last = num) }) -.x Pseries(0, Pwrand(#[1, 2, 3], #[0.2, 0.4, 0.4], 5), inf).clump(5));
									bp.panCtl.watch.automate {
										SinOsc.kr(SinOsc.kr(0.05).exprange(0.07, 0.75),
											Rand(0, 2pi))
									};
								},
								// setDoneSignal: {
								// 	~doneSignal = Updater(BP(\ltf), e { |obj, what|
								// 		if(what == \notesEmpty) {
								// 			obj.stop(0);  // which will also kill the cmd
								// 		};
								// 	});
								// },
								clearDoneSignal: {
									// ~doneSignal.remove;
									BP(\ltf).panCtl.stopWatching.stopAuto;
								}
							),

							8,
							loopCmd: (
								id: \shivaTrig,
								// shouldSync: false,
								numEv: Pwhite(5, 11, inf).asStream,
								deltaBase: Pwrand(#[0.5, 1, 1.5, 2],
									#[1, 3, 1, 2.5].normalizeSum, inf),
								setDoneSignal: { BP(\shivaTrig).isFading = false },
								cmds: [
									{ rrand(4, 10) },
									{	var db = ~deltaBase, numEv = ~numEv;
										PR(\bpCmd).copy.putAll((
											name: \shivaTrig,
											prepareBP: { |bp|
												bp.delta = Pseq([
													Pfin(numEv.next - 1, db),
													rrand(4.5, 6.5)
												], 1)
											}
										))
									},
									\cmdSync
								]
							),

							// c. 52 beats
							36,
							fades
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
					funcCmd: (
						func: {
							var	iter = ~iterator.findActive(\sus2sub);
							if(iter.notNil) {
								iter.subIter.tryPerform(\findActive, \shivaTrig).stop;
							};
						}
					),
					fades,
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
					funcCmd: (
						dur: 10,
						func: {
							// extra insurance to make sure this REALLY fades out in time
							if(BP(\ltf).v[\fxampStream].notNil) {
								BP(\ltf).fxamp = Env([BP(\ltf).fxampStream.next, 0], #[10])
							};
						},
						clearDoneSignal: { BP(\ltf).stop }
					),
					\cmdSync //,
					// { BP.all.stop;  0 }
				],
				onStop: {
					BP.keys.do { |key|
						if(#[segTrig, evTrig].includes(key).not) { BP(key).stop };
					};
					VC(\sp).releaseAll;
				},
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