//////// arms section sequencer

// first, put the cursor right below '// init' (on the paren)
// and do ctrl-alt-x

// then put the cursor here and C-c C-c to run the line
t.stop; t.play;

// and if you need to stop:
t.stop;  // by itself

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
	Library.put(\rvbs, (
		glrvbmc: topEnvironment[\glrvbmc],
		lcrvbmc: topEnvironment[\lcrvbmc],
		master: topEnvironment[\master]
	));

	{ |source, class, key, adverb, parms|
		if(class.exists(key).not) {
			source.chuck(class.new(key), adverb, parms);
		};
	} => Func(\chuckIf);

	// \chuckIf.eval(PR(\armsSkidMel), BP, \am, nil, (
	// 	glrvbmc: ~glrvbmc,
	// 	lcrvbmc: ~lcrvbmc,
	// 	master: ~master
	// ));

	~trigParms = (
		sbounds: Window.screenBounds,
		// play: \dummy,
		setDoneSignal: {
			~doneSignal = OSCresponderNode(s.addr, '/event', e { |t, r, m|
				r.remove;
				~stop.();
			}).add;
			defer(e {
				~window = Window("GO", Rect(~sbounds.right - 120, ~sbounds.height - 150, 120, 60));
				Button(~window, ~window.view.bounds.insetBy(2, 2))
					.states_([["event"]])
					.action_(e { ~stop.() });
				~window.front.userCanClose_(false);
			});
		},
		clearDoneSignal: {
			defer(e { ~window.close })
		},
		func: \dummy
	);

/*	{ |segID, searchID|
		(	cmdID: searchID,
			segID: segID,
			sbounds: Window.screenBounds,
			// play: \dummy,
			setDoneSignal: {
				~doneSignal = List.new;
				~cmdID = ~cmdID.asArray;
				~iterator.activeCmds.do { |cmd|
					if(~cmdID.includes(cmd.id)) { ~doneSignal.add(cmd) };
				};
				if(~doneSignal.isEmpty) {
					~doneSignal = nil
				} {
					~resp = OSCresponderNode(s.addr, '/segment', e { |t, r, m|
						var	inSeg = m[3];
						case { inSeg == ~segID } {
							r.remove;
							~stop.();
						}
						{ inSeg > ~segID } {
							"NEED TO SKIP SEGMENT HERE -- JUST ADVANCING NOW!".debug;
							r.remove;
							~stop.();
						}
						{ "Trigger segment % ignored; waiting for segment %\n"
							.postf(inSeg, ~segID)
						};
					}).add;
					defer(e {
						~window = Window("move on",
							Rect(~sbounds.right - 120, ~sbounds.height - 300, 120, 60));
						Button(~window, ~window.view.bounds.insetBy(2, 2))
							.states_([["to seg %".format(~segID)]])
							.action_(e { ~stop.() });
						~window.front.userCanClose_(false);
					});
				}
			},
			clearDoneSignal: {
				~doneSignal.do(_.stop);  // this is the previous loopcmd!
				~resp.remove;
				~window !? { defer(e { ~window.close }) };
			};
		)
	} => Func(\nextThingParms);
*/

	{	|item|
		var	sbounds = Window.screenBounds;
		~trigResp = OSCresponderNode(s.addr, '/segment', e { |t, r, m|
			var	inSeg = m[3], i;
			case { inSeg == item[\id] } {
				r.remove;
				// stop section, section sequencer will advance
				// false = not a manual stop, don't kill non-sync commands
				~stop.(nil, false);
			}
			{ inSeg > item[\id] } {
				if((i = topEnvironment[\seq].sections.detectIndex { |sect|
					sect.segID == inSeg
				}).notNil) {
					"skipping to %\n".postf(inSeg);
					r.remove;
					topEnvironment[\seq].gotoSection(i);  // this stops cur sect
				} {
					"Segment % doesn't exist; still waiting for segment %\n"
					.postf(inSeg, item[\id])
				};
			}
			{ "Trigger segment % ignored; waiting for segment %\n"
				.postf(inSeg, item[\id])
			};
		}).add;
		defer(e {
			~window = Window("move on",
				Rect(sbounds.right - 120, sbounds.height - 300, 120, 60));
			Button(~window, ~window.view.bounds.insetBy(2, 2))
				.states_([["to seg %".format(item[\id])]])
				.action_(e { ~stop.(nil, false) });
			~window.front.userCanClose_(false)
				.onClose_(e { ~window = nil });
		});
	} => Func(\nextThingTrig);

	{	~trigResp.remove;
		~window !? { defer(e { ~window.close }) };
		~currentTriggerItem = nil;  // what a horrendous, god-awful hack
		~cleanupTrigger.(nil, (manualStop: false));
	} => Func(\clearNextTrig);

	PR(\tlSection).clone {
		~stop = { |notifyTime, manualStop = true|
			if(~isRunning.()) {
				~status = \idle;
				~currentIterator.stop((manualStop: manualStop ? true).debug("tlseq stop parms"));
				~done.(manualStop);
				~clearDoneSignal.();
				~clock.schedAbs((notifyTime ?? { ~clock.beats }), e {
					currentEnvironment.changed(\done, ~savedCmds);
				});
				if(thisThread === ~seqPlayer) {
					nil.yield
				} {
					~seqPlayer.stop;
				};
			};
		};
		~done = { |manualStop| ~cleanupTrigger.(nil, (manualStop: manualStop)) };
		~cleanupTrigger = { |triggerID, parms|
			if(~currentTriggerItem.notNil) {
				~currentIterator.stop(parms);
				~currentTriggerItem[\clear].(~currentTriggerItem, triggerID, parms);
				~currentTriggerItem = nil;
			};
		};
	} => PR(\tlsAff);

	BP(\segTrig).free;
	PR(\busTrig).chuck(BP(\segTrig), nil, (message: '/segment'));
	BP(\evTrig).free;
	PR(\busTrig).chuck(BP(\evTrig), nil, (message: '/event', busIndex: 4094));
	0.5.wait;
	BP(#[segTrig, evTrig]).play(0);

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
			name: "A1",
			segID: 1,
			initProcesses: {
				\chuckIf.eval(Fact(\dataIn), BP, \di, nil, (
					filename: "arms/NACL_Arms.wav"
				));
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
						bpCmd: (id: \lc_data, name: \di, quant: 0, shouldSync: false //,
							// yetToStopParent: true,
							// clearDoneSignal: {
							// 	if(~yetToStopParent) {
							// 		~yetToStopParent = false;
							// 		sect.stop;
							// 	};
							// }
						),
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
			name: "A2",
			segID: 2,
			initProcesses: {
				\chuckIf.eval(Fact(\armsChordVC), VC, \ac, nil, Library.at(\rvbs));
				\chuckIf.eval(PR(\armsChord), BP, \acDisp, nil, (
					angleBus: BP(\di).bus.index + 1, // ??
					rotSpeedBus: BP(\di).bus.index + 4
				));
				BP(\acDisp) => VC(\ac);
				0 => BP(\acDisp);
				
				BP(\di).playTestFile = true;
			},
			// unloadProcesses: {},
			seqPattern: {
				// var	sect = currentEnvironment;
				Pn((
					sequence: [
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
			name: "A3",
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
			name: "A4",
			segID: 4,
			initProcesses: {
				\chuckIf.eval(PR(\stacking), BP, \st, nil, (
					// TEST
					root: Pstutter(Pwrand(#[1, 2], #[0.8, 0.2], inf), Pseq([
						Pwhile1({ |inval, next| next < 40 },
							Pseries(26, Pwrand(#[1, 2, 3], #[1, 4, 3].normalizeSum, inf), inf)
						),
						Pwhile1({ |inval, next| next >= 21 },
							Pseries(40, Pwrand(#[-1, -2, -3], #[1, 4, 3].normalizeSum, inf), inf)
						)
					]));
				));
				VC(\ac) => BP(\st);
				0 => BP(\st);
			},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
						bpCmd: (id: \stack, name: \st)
					],
					dur: \sync
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "A5",
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
			name: "",
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
				BP(\tc).finalAmp = 0.3;
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
					id: 8,  // trig id
					init: Func(\nextThingTrig).v,
					clear: Func(\clearNextTrig).v
				), 1)
			}
		)),

		PR(\tlsAff).copy.putAll((
			name: "A8",
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
			name: "A9",
			segID: 9,
			initProcesses: {
				\chuckIf.eval(PR(\siDuet), BP, \sid);
				VC(\sp) => BP(\sid);
				BP(\sid).finalAmp = -22.dbamp;
				BP(\sid).delta = Pif(Pkey(\high) > 0, Pwhite(3, 5, inf),
					Pwrand(#[1, 2, 3, 4], (1..4).reciprocal, inf)
				);
			},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
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
										bp.high = self[\highPats].next.dereference.debug.trace
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
			name: "A9.5",
			segID: 9.5,
			// initProcesses: {},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
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
			name: "A10",
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
			name: "A11",
			segID: 11,
			// initProcesses: {},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
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
			name: "A12",
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
			name: "A13",
			segID: 13,
			initProcesses: {
				\chuckIf.eval(PR(\rockingChords), BP, \rc);
				VC(\sp) => BP(\rc);
				BP(\rc).finalAmp = -22.dbamp;
			},
			// unloadProcesses: {},
			seqPattern: {
				Pn((
					sequence: [
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

/*
	t = TLSequenceIterator([	
		///// 12:45 -- swaying, into another partnering sequence
		/////// (not done yet, crap!!)
	
		
	
	
	/*
	//	{ "///// 16:34 -- all three to the ground, then up".debug; 0 },
		{ "///// 16:50 -- Laura solo, mostly locomotive material".debug; 0 },
	
	
		{ "///// 18:08 -- screen in, Laura goes behind shortly after".debug; 0 },
		{ "///// 18:38 -- face dance".debug; 0 },
	*/
	
		{ "over and out!".debug; 0 }
	]).play;
*/

	~seq = PR(\sectionSequencer).clone({
		~gotoSection = { |section|
			var	toStop = ~sections[~currentSection];
			if(~isRunning.()) {
				~loadResources.(section);
				~nextSectionToPlay = section;
				toStop.stop(nil, false);  // will advance by ~update
			} {
				~currentSection = section;
			};
			currentEnvironment.changed(\section, section);
		};
		~loadResources = { |section|
			//section.debug(">> loadResources");
			// must add 1 because do runs from 0 to n-1
			(section+1).do({ |sect|
				if((~sections[sect].tryPerform(\isLoaded) ? true).not
					/*.debug("section % needs to load".format(sect))*/) {
						~sections[sect].prInitProc;
					};
			});
			//debug("<< loadResources");
		};
		~countOffAndGo = {
			var	clock = ~clock.value;
			thisThread.clock.sched(0, ~sectionRoutine = Routine({
				~status = \playing;
				while { ~isRunning.() and: { ~currentSection < ~sections.size } } {
					//~savedCmds.debug("playing section % with saved cmds".format(~sections[~currentSection].name));
					~sections[~currentSection].play(~savedCmds);
					//"section sequencer: set savedCmds to nil".debug;
					~savedCmds = nil;
					// ~update method below will catch notifications
					~sections[~currentSection].addDependant(currentEnvironment);
					~loadResources.(~currentSection + 1);
					// note, this doesn't force-stop the routine
					// just pauses it
					nil.yield;
				};
				~stop.(true);	// stop last section
			}));
		};
		~stop = { ~nextSectionToPlay = nil } <> ~stop;
		~update = { |obj, what, args|
			var	section;
			[obj, what, args].debug("section sequencer got update");
			if(obj === ~sections[~currentSection]) {
				switch(what)
				{ \done } {
					args.debug("section sequencer update - savedCmds");
					~savedCmds = args;
					obj.removeDependant(currentEnvironment);
					if(~isRunning.()) {
						~currentSection = ~nextSectionToPlay ?? { ~currentSection + 1 };
						~nextSectionToPlay = nil;
						~currentSection.debug("section done, moving to");
						currentEnvironment.changed(\section, ~currentSection);
						~clock.value.sched(0, ~sectionRoutine);
					};
				}
				{ \initNext } {
					if(~sections[~currentSection + 1].notNil) {
						~sections[~currentSection + 1].prInitProc;
					}
				}
				{ \unload } {
					args.tryPerform(\at, \name).asArray.do { |sectName|
						if((section = ~sections.detect { |sct| sct.name == sectName }).notNil) {
							section.prUnload;
						}
					};
				}
			};
		};
	}).sections_(~sections);

	~seq.loadResources(0);

	0.5.wait;

	// ~seq.play;

};
)



t.stop;
t.play;


t.isPlaying

BP.all.stop;

BP.all.do(_.reset);

BP.all.free;
VC.all.free;

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