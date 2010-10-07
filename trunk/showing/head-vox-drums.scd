// head: vox + drums section code for showing, 31 Aug 2010

if(MCG.exists(0).not) {
	\makeEmptyMixer8.eval;
};

s.waitForBoot {
	if(PR.exists(\hs1).not) {
		// (thisProcess.nowExecutingPath.dirname.dirname +/+ "feet/feet-defs.scd").loadPath;
		// 2.0.wait;	// seems to be necessary to prevent duplicate reverbs
		(thisProcess.nowExecutingPath.dirname.dirname +/+ "head/head-defs.scd").loadPath;
		2.0.wait;
	};

	~master => MCG(7);

	Fact(\mstClock) => BP(\mstClock);
	
	PR(\hs1).chuck(BP(\hs), nil, (
		makeGResponder: 0, removeGResponder: 0
	));
	Fact(\hstrig) => BP(\hstrig);
	
	PR(\hsSweep) => BP(\hswp);
	
	PR(\trajectories) => BP(\traj);
	Fact(\formantfx1) => BP(\fmt);
	PR(\hsDrone).chuck(BP(\hsd), nil, (maxTop: 40));
	
	BP(\cpt).free;
	PR(\counterpoint).chuck(BP(\cpt), nil, (master: ~master));
	0 => BP(\cpt);
	
	BP(\cd).free;
	PR(\cadences).chuck(BP(\cd), nil, (parentBP: \cpt));
	0 => BP(\cd);
	
	Fact(\int) => BP(\int);
	// what clock should int use?
	//~clock60 ?? { ~clock60 = TempoClock(tempo: 1, queueSize: 1024) };
	~clock108 => BP(\int);
	
	BP(#[cd, cpt, fmt, hs, hsd, hstrig, hswp, int, mstClock]).do { |bp| bp.printStopMsg = false };
	
	(1..3).do { |i| Fact(("drum" ++ i).asSymbol).chuck(BP(("drum" ++ i).asSymbol), nil, (source: \drum1)) };
	
	NotificationCenter.registerOneShot(\drum3, \ready, \bploader, e {
		Fact(\drum4).chuck(BP(\drum4), nil, (pan: -1));
		// 5 and 6 are basically copies - switch between them to change phase vs. drum4
		Fact(\drum4).chuck(BP(\drum5), nil, (pan: 1, chan: BP(\drum4).chan));
		Fact(\drum4).chuck(BP(\drum6), nil, (pan: 1, chan: BP(\drum4).chan));
	
		Fact(\drum7) => BP(\drum7);
		Fact(\drum7).chuck(BP(\drum8), nil, (ctlSource: \drum7, quant: #[-1, 1.25]));
	});
	
	PR(\bpCmd).clone {
		~setDoneSignal = {
			~playing = if(BP(\drum5).isPlaying) { \drum5 } { \drum6 };
			~name = if(~playing == \drum5) { \drum6 } { \drum5 };
			BP(~playing).stop(~quant);
		};
		~prepareBP = { |bp| ~extraPrep.(bp); bp.reset };
	} => PR(\swap56cmd);

	~feetGui = Proto {
		~width = 356;
		~background = Color.grey(0.3);
		~stringColor = Color.green(0.8);
		~prep = {
			if(~win.isNil or: { ~win.isClosed }) {
				~win = ResizeFlowWindow("Head: vox + drums", Window.screenBounds);
				StaticText(~win, Rect(0, 0, ~width, 30))
					.align_(\center)
					.background_(~background).stringColor_(~stringColor)
					.string_("Head: vox + drums");
				~win.startRow;
				~goButton = Button(~win, Rect(0, 0, ~width, 30))
					.states_([["GO"], ["stop"]])
					.action_(e { |view|
						if(view.value > 0) {
							(~playingSeq = ~seq.value).play(argClock: SystemClock);
							~win.userCanClose = false;
							~quitButton.enabled = false;
							~upd = Updater(~playingSeq, e { |obj, what|
								if(what == \done) {
									~upd.remove;
									defer(e {
										~goButton.value = 0;
										~win.userCanClose = true;
										~quitButton.enabled = true;
									});
								}
							});
						} {
							~playingSeq.stop;
							~playingSeq = nil;
						}
					});
				~win.startRow;
				StaticText(~win, Rect(0, 0, 200, 20))
					.align_(\center)
					.string_("initial master volume");
				~mVol = GenericGlobalControl(\mvolume, nil, -4, #[-20, 0, \db]);
				~mVol.gui(~win);
				~win.startRow;
				~quitButton = Button(~win, Rect(0, 0, ~width, 30))
					.states_([["Quit this demo"]])
					.action_(e {
						~upd.remove;
						~win.close;
					});
		
				~win.onClose = e {
					fork {
						BP.all.do { |bp|
							if(#[mstClock, traj].includes(bp.collIndex).not) { bp.free }
						};
						BP(#[mstClock, traj]).free;
						~mVol.free;
					};
				};
				fork({
					~win.recursiveResize;
					0.1.wait;
					~win.bounds = ~win.bounds.center_(Window.screenBounds.center);
					0.1.wait;
					~win.front;
				}, AppClock);
			}
		};

		~seq = {
			var	notifyRecd = 0,
				notifyExpected = -1,
				drumLevel = -7.dbamp,
				waitForNotesCmd = PR(\funcCmd).copy.putAll((
					setDoneSignal: {
//[notifyRecd, notifyExpected].debug("waitcmd: notifications received, expected");
						if(notifyRecd > notifyExpected) {
							~doneSignal = NotificationCenter.register(\notes, \go, \drumproc, e { |args|
//								args.debug("got go signal");
								~doneSignal.remove;  // this is a NotificationRegistration
								~stop.();
							});
						} { ~doneSignal = nil }
					},
					clearDoneSignal: {
						notifyRecd = notifyRecd + 1;
//[notifyRecd, notifyExpected].debug("stopping wait cmd (received, expected)");
						~doneSignal = nil
					}
				)),
				t2 = TLSequenceIterator([
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
						// if(d.class == DDWTimer) { d.reset };
						0
					},
				/*
					loopCmd: (
						setDoneSignal: {
							~doneSignal = true;
							defer(e {
								~window = ResizeFlowWindow("trigger",
									Rect(Window.screenBounds.width - 200, 50, 200, 100));
								Button(~window, 90@20)
									.states_([["go"]])
									.action_(e {
										if(BP(\drum1).isPlaying.not) { ~cmd.stop };
									});
								Button(~window, 90@20)
									.states_([["move on"]])
									.action_(e {
										currentEnvironment.stop;
									});
								~window.recursiveResize.front;
							})
						},
						clearDoneSignal: { defer(e { ~window.close }) },
						cmds: [
							{	PR(\funcCmd).copy.putAll((
									looper: currentEnvironment,
									func: { ~looper.cmd = currentEnvironment },
									doneSignal: true
								))
							},
							\cmdSync,
							{	if(~doneSignal == true) {
									PR(\bpCmd).copy.putAll((
										name: \drum1,
										quant: 1,
										dur: 2.9
									))
								}
							},
							\cmdSync
						]
					),
					\sync,
				*/
			
					waitForNotesCmd, \cmdSync,
					Quant(3, -0.5),
				
			
					gcAutoSynthCmd: (gc: BP(\drum1).distCtl, name: \ctlEnv, outName: \outbus, 
						connect: 0, time: 36, env: Env(#[20, 5], #[1], 1)),
					bpCmd: (name: \drum1, quant: `nil, prepareBP: { |bp|
						bp.bar = Pseq(#[3, 0], inf);
					}),
					12,
					gcAutoSynthCmd: (gc: BP(\drum1).wetCtl, name: \ctlPoint, outName: \outbus, 
						value: 0.078, time: 30, curve: 0),
					bpCmd: (name: \drum2, quant: `nil, prepareBP: { |bp|
						bp.bar = Pseq(#[0, 2], inf);
					}),
					12,
			
					[	{	BP(\drum1).bar = Pseq([3, Prand(BP(\drum1).indices[1], 1)], inf);
							12
						},
						{	BP(\drum2).bar = Prand(BP(\drum2).indices[1], inf);
							12
						},
					
						{	BP(\drum2).bar = Prand(#[1, 2, 3], inf);
							12
						}
					],
			
					waitForNotesCmd, \cmdSync,
					Quant(3, -0.5),
				
					gcAutoSynthCmd: (gc: BP(\drum1).ffRangeCtl, name: \ctlEnv, outName: \outbus, 
						env: Env(#[0, 14, 0], #[0.6, 0.4], #[6, -2]), time: 30, connect: 0),
					bpCmd: (name: \drum3, quant: `nil, prepareBP: { |bp|
						bp.bar = Prand(#[8, 2], inf);
						bp.ffreqCtl.value = 360;
					}),
					mixerAutoSynthCmd: (mixer: BP(\drum3).chan, name: \ctlEnv, outName: \outbus,
						connect: 0, env: Env([-16.dbamp, drumLevel], #[18], 2.4)),
					gcAutoSynthCmd: (gc: BP(\drum3).ffreqCtl, name: \ctlPoint, outName: \outbus, 
						value: 18000, time: 30, curve: 5),
					
					24,
					{	BP(\drum3).bar = Prand([8, 2], inf) + Prand(#[0, 1, 4], inf);
						BP(\drum2).bar = 3;
						12
					},
				
					{	BP(\drum3).bar = Prand(BP(\drum3).indices[2], inf);
						12
					},
				
					{	BP(\drum3).bar = Prand(BP(\drum3).indices[[2, 3]].flat, inf);
						BP(\drum1).bar = 3;
						24
					},
				
					{	BP(\drum3).bar = 15;
						6
					},
				
					waitForNotesCmd, \cmdSync,
					Quant(3, -0.5),
			
					{ BP(#[drum1, drum2, drum3]).stop; 0 },
				
					bpCmd: (name: #[drum4, drum5], quant: `nil, prepareBP: { |bp|
						var	panEnd = -1;
						bp.reset;
						if(bp.collIndex == \drum5) {
							bp.quant = #[-1, 0.02];
							panEnd = 1;
							bp.amp = Pseq(#[1, 1 /* finger-amp */], inf) * Env(#[0, 1], #[12], 2.4)
						};
						bp.pan = Env([0, panEnd], #[30]);
						bp.wetCtl.value = 0.078;
					}),
				
					18,
					swap56cmd: (quant: #[-1, 0.25], extraPrep: { |bp| bp.amp = Pseq(#[1, 1 /* finger-amp */], inf) }),
					gcAutoSynthCmd: (gc: BP(\drum4).ffRangeCtl, name: \ctlPoint, outName: \outbus, 
						value: 18, time: 36),
				
					24,
					swap56cmd: (quant: #[-1, 1.25], extraPrep: { |bp| bp.amp = Pseq(#[1, 1 /* finger-amp */], inf) }),
					24,
					swap56cmd: (quant: #[-1, 0.75]),
					24,
				
					waitForNotesCmd, \cmdSync,
					Quant(3, -0.5),
			
					{	BP(#[drum4, drum5, drum6]).stop;
						BP(\drum7).pan = -1;
						BP(\drum8).pan = 1;
						BP(\drum7).quant = -1;
						BP(\drum8).quant = #[-1, 0.75];
						0
					},
				
					bpCmd: (name: #[drum7, drum8], quant: -1, prepareBP: { |bp|
						bp.ostFiltCtl.value = 1;
						bp.fmltDcyCtl.value = 0.25;
						bp.fmltWetCtl.value = 0.1;
					}),
					funcCmd: (doneSignal: true,
						num3: rrand(2, 7),
						func: {
							var	thisCmd = currentEnvironment;
							BP(#[drum7, drum8]).do { |bp|
								~num3 = ~num3 + 5;
								bp.gest = Pseq([
									CleanupStream(
										Pseq([\threePl1, Pn(\threeAcc, ~num3), \ostFilt2Quant]).asStream,
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
					{ "synced".debug; 6 },
				
					18,
					loopCmd: (repeats: 2,
						qphase: Pseq(#[1.25, 0.75], inf).asStream,
						acc: Pseq([\threeAcc, Prand(#[fiveAcc, sevenAcc], inf)]).asStream,
						cmds: [
							{	var	numAcc = rrand(3, 6), acc = ~acc.next,
									pat = Pseq([\ostFilt2Sync, Pn(acc, numAcc), \ostFilt2Quant], 1);
								BP(#[drum7, drum8]).do { |bp|
									bp.override(\gest, pat);
								};
								BP(\drum8).quant = [-1, ~qphase.next];
								rrand(3, 5) * 6
							}
						]
					),
					\cmdSync,
				
					{	BP(\drum8).gest = Pfsm([
							#[4, 5],
							Pwrand(#[five, fiveRest], #[0.5, 0.5], { rrand(2, 4) }), #[0, 1, 2, 3],
							Pwrand(#[seven, sevenRest], #[0.5, 0.5], { rrand(2, 4) }), #[0, 1, 2, 3],
							\fiveAcc, #[2, 4, 5],
							\sevenAcc, #[3, 4, 5],
							\five1Acc, #[0, 2],
							\seven1Acc, #[1, 3],
						], inf);
						6
					},
					{	BP(\drum7).gest = BP(\drum8).gest;
						6 //24
					},
				
					loopCmd: (repeats: 3,
						acc: Prand(#[threeAcc, fiveAcc, sevenAcc], inf),
						cmds: [
							{	var	// both 7+8 use the same random seed
									pat = Pseed(Pn(Date.seed, 1), Pseq([
										Pif(Ptime() < rrand(8, 11), Pseq([\randsync, ~acc], 1)),
										\randquant
									], 1));
								BP(#[drum7, drum8]).do { |bp|
									bp.keepGoing = false;
									bp.override(\gest, pat);
								};
								BP(\drum8).quant = -1;
								rrand(2, 4) * 6
							}
						]
					),
					\cmdSync,
				
					gcAutoSynthCmd: (gc: BP(\drum7).fmltWetCtl, name: \ctlPoint, outName: \outbus,
						value: 0.736, time: 20, curve: 2),
					loopCmd: (repeats: 4,
						cmds: [
							funcCmd: (
								doneSignal: true,
								func: {
									var	seed = Date.seed, num = rrand(7, 15),
										thisCmd = currentEnvironment,
										n = Pxrand((2..8), num).asStream.all.debug("n"),
										factor = { rrand(1, 2) } ! num,
										rest = #[1, 2].wchoose(#[0.8, 0.2]);
									BP(#[drum7, drum8]).do { |bp|
										var	once = true, saven, saveFactor;
										bp.keepGoing = false;
										bp.override(\restBeats, Pn(rest, 1));
										bp.override(\gest, Pseq([
											\randsync,
											\oneAcc,
											Pseed(Pn(seed, 1),
												Pwrand(#[nhigh, nhighAcc], #[0.4, 0.6], num)
											).collect { |gest|
												if(once) {
													bp.override(\n, Pseq(n, 1));
													bp.override(\factor, Pseq(factor, 1));
													once = false;
												};
												gest
											}
										], 1), false, { thisCmd.stop });
									};
								}
							),
							\sync,
							{ if(~repeats > 1) { rrand(12, 24) } { 0 } }
						]
					),
					\cmdSync,
					{ "synced".debug; 0 },
				
					{	BP(\drum7).gest = Pseq([
							\randsync,
							Pwrand(#[ngap, ngapAcc, nhigh, nhighAcc], #[0.2, 0.2, 0.3, 0.3], { rrand(7, 15) }),
							Pfin((Pwhite(4, 8, inf) * Pseries.fromEndpoints(5, 0.3, 5)).trunc.trace(prefix: "7-num57: ").asStream, BP(\drum7).gest)
						], inf);
						12
					},
				
					{	BP(\drum8).gest = Pseq([
							\randsync,
							Pwrand(#[ngap, ngapAcc, nhigh, nhighAcc], #[0.2, 0.2, 0.3, 0.3], { rrand(7, 15) }),
							Pfin((Pwhite(4, 8, inf) * Pseries.fromEndpoints(5, 0.3, 5)).trunc.trace(prefix: "8-num57: ").asStream, BP(\drum8).gest)
						], inf);
						36
					},
			
				// 	36,
				//	funcCmd: (func: { ~iterator.stop })
				//	{ BP.all.stop; 8 },
				//	{ ~master.stopRecord; 0 }
				]),
				c = BP(\mstClock).clock;

			TLSequenceIterator([
				{	BP(\hs).low_(2).high_(24);
					#[chan, chan2].do { |key| BP(\mstClock)[key].level = -15.dbamp };
					topEnvironment[\master].level = ~mVol.value.dbamp;
					1
				},
				bpCmd: (name: \mstClock/*, prepareBP: { |bp|
					bp.tempoCtl.value = 0.1;
				}*/),
				gcAutoSynthCmd: (
					gc: BP(\mstClock).tempoCtl, name: \ctlEnv, outName: \outbus,
					connect: 0, env: Env(#[0.1, 0.1, 0.5, 0.245], #[30, 25, 25], 3.5), time: 1
				),
				6,
				bpCmd: (name: \hs, prepareBP: { |bp|
					bp.debug.use {
						~lastRise = 1;
						~rat = Pswitch1([
							Pwhile1({ |in, item| ~lastRise = item; item <= ~high }, Pseries(~low, 1, inf)),
							(Pexprand(Pfunc { ~low }, Pfunc { ~high }, inf)
								.round(1).reject { |x| ~activeRatios.includes(x) });
						], Pfunc {
							(~lastRise.linexp(~low, ~high, 0.005, 1)/*.debug("coin")*/.coin
							or: { ~activeRatios.includes(~lastRise+1.0)/*.debug("already playing %".format(~lastRise+1))*/ })
							.binaryValue
						});
					};
				}),
				0.1,
				bpCmd: (name: \hstrig, doReset: true, setDoneSignal: { |bp|
					~upd = Updater(BP(\hs), e { |obj, what|
						if(what == \allChildrenStopped) {
							~upd.remove;
							BP(\hs).stop;
						}
					});
				}),
			
				40,
				bpCmd: (name: \hswp, prepareBP: { |bp|
					bp.debug.lowhCtl.value = 2;
					bp.tophCtl.value = 2;
				}),
				gcAutoSynthCmd: (
					gc: BP(\hswp).tophCtl, name: \ctlPoint, outName: \outbus,
					value: 32, time: 28, curve: 1.6,
					setDoneSignal: {
						~upd = Updater(~gc, e { |obj, msg|
							var	val;
							if(msg[\what] == \value and: { (val = ~gc.value.asInteger) > BP(\hs).low }) {
								if(val < BP(\hs).high) {
									BP(\hs).low = max(val - 12, 2);
								} {
									BP(#[hstrig]).stop;
								}
							};
						});
					},
					clearDoneSignal: { ~upd.remove }
				),
			
				18,
			// 	#[30] ++ #[chan, chan2].collect { |key|
			// 		PR(\mixerAutoSynthCmd).copy.putAll((
			// 			mixer: BP(\mstClock)[key], name: \ctlPoint, outName: \outbus,
			// 			value: -15.dbamp, time: 30, curve: -2.1
			// 		))
			// 	},
				bpCmd: (name: \hsd, prepareBP: { |bp|
					bp.debug.tophCtl.value = 2;
					bp.ampCtl.value = 0.2;
				}),
				gcAutoSynthCmd: (
					gc: BP(\hsd).tophCtl, name: \ctlPoint, outName: \outbus,
					value: 32, time: 30, curve: 1.6,
					setDoneSignal: {
						~upd = Updater(~gc, e { |obj, msg|
							var	val;
							if(msg[\what] == \value and: { (val = ~gc.value.asInteger) > BP(\hswp).low }) {
								if(val < BP(\hswp).tophCtl.value) {
									BP(\hswp).lowhCtl.value = val+1;
								} {
									BP(\hswp).stop;
								}
							};
						});
					},
					clearDoneSignal: { ~upd.remove; BP(\hswp).stop }
				),
			//	\cmdSync,
				14,
				bpCmd: (name: \fmt, prepareBP: { |bp|
					bp.debug.fadeIn = 22;
					bp.fadeOut = 12;
				}),
			
			// start choral section (which was always after formants)
			
				16, //{ rrand(10.0, 18.0) },
			
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
						~doneSignal.remove;
						~doneSignal = nil;
					}
				),
			
				bpCmd: (name: \cd, prepareBP: { |p|
					p.debug("choral").tempoPat = 1;
					p.chan.level = -1.dbamp;
					p.dur = Pwhite(0.9, 1.25, inf) *.x Pwhite(12.0, 16.0, { |num| num });
					p.p5_(0).sharp_(false).shortFirst_(false).oneNote_(true);
					p.reset;	// maybe voodoo, but it seems sometimes \cd reuses a freed bus object??
				}),
				\cmdSync,
			
				{ rrand(16.0, 24.0) },
			
				[	{ rrand(5.0, 8.0) },
					{	notifyExpected = 0;
//[notifyRecd, notifyExpected].debug("sending notification (received, expected)");
						NotificationCenter.notify(\notes, \go, 0);  // tell drum process to move ahead
						0
					}
				],
				bpCmd: (name: \cd, prepareBP: { |p|
					p.oneNote_(false);
					p.dur = Pwhite(0.7, 0.9, inf) *.x Pwhite(12.0, 16.0, { |num| num });
				}),
				\cmdSync,
				7, //{ rrand(6.0, 14.0) },
			
				bpCmd: (name: \cpt, prepareBP: { |p|
					p.filterNotePat = nil;
					p.useLpf = false;
					p.seqKeys = #[t2];
					p.tempoPat = (42/60) * Pexprand(0.75, 0.5.reciprocal, inf);
					p.att_(0.7).rel_(0.9).dec_(1.2);
					p.reset;
				}),
				\cmdSync,
				2, //{ rrand(6.0, 9.0) },
			
				[	{ rrand(5.0, 8.0) },
					{	notifyExpected = 1;
//[notifyRecd, notifyExpected].debug("sending notification (received, expected)");
						NotificationCenter.notify(\notes, \go, 1);
						0
					}
				],
				bpCmd: (name: \cd, prepareBP: { |p|
					p.dur = Pwhite(0.5, 0.8, inf) *.x Pwhite(12.0, 16.0, { |num| num });
					p.p5_(1).shortFirst_(true);
				}),
				\cmdSync,
				{ rrand(8.0, 12.0) },
			
				bpCmd: (name: \cpt, prepareBP: { |p|
					p.seqKeys = #[t2, a2b];
				}),
				\cmdSync,
				2, //{ rrand(6.0, 9.0) },
			
				bpCmd: (name: \cd, prepareBP: { |p|
					p.sharp_(true);
				}),
				\cmdSync,
				{ rrand(8.0, 12.0) },
			
				[	{ rrand(5.0, 8.0) },
					{	notifyExpected = 2;
//[notifyRecd, notifyExpected].debug("sending notification (received, expected)");
						NotificationCenter.notify(\notes, \go, 2);
						0
					}
				],
				bpCmd: (name: \cpt, prepareBP: { |p|
					p.tempoPat = (42/60) * Pexprand(0.75, 0.5.reciprocal, inf);
					p.seqKeys = #[t3, a31, a32];
				}),
				\cmdSync,
				2,
			
				bpCmd: (name: \cd, prepareBP: { |p|
					p.p5_(2);
				}),
				\cmdSync,
				{ rrand(8.0, 12.0) },
			
				[	{ rrand(4.0, 8.0) },
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
				],
			
				bpCmd: (name: \cpt, prepareBP: { |p|
					p.seqKeys = #[t2, a2d1, a2d2];
				}),
				\cmdSync,
				2,
			
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
			
				bpCmd: (name: \cpt, prepareBP: { |p|
					p.tempoPat = 2.5;
					p.filterNotePat = { |pat|
						Pfin(pat.estimateLength - 1, pat).drop(1)
					};
				}),
				\cmdSync,
				{ rrand(1.0, 2.5) },
			
				[	{ rrand(1.0, 3.0) },
					{	notifyExpected = 3;
//[notifyRecd, notifyExpected].debug("sending notification (received, expected)");
						NotificationCenter.notify(\notes, \go, 3);
						0
					}
				],
				bpCmd: (name: \cpt, prepareBP: { |p|
					p.tempoPat = 1.2;
					p.filterNotePat = { |pat|
						pat.drop(pat.estimateLength - 1)
					};
				}),
				\cmdSync,
			
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
			
				48,
				mixerAutoSynthCmd: (mixer: topEnvironment[\master], name: \ctlPoint, outName: \outbus,
					value: 0, time: 32, curve: -2.1),
				\cmdSync,
			
			// 	{ rrand(6.0, 9.0) },
				funcCmd: (func: {
					~iterator.stop;
				})
			])
		};
	};
	~feetGui.prep;
};

