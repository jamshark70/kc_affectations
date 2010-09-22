// feet, opening section code for showing, 31 Aug 2010

if(MCG.exists(0).not) {
	\makeEmptyMixer8.eval;
};

s.waitForBoot {
	if(Fact.exists(\opening).not) {
		// (thisProcess.nowExecutingPath.dirname.dirname +/+ "feet/feet-defs.scd").loadPath;
		// 2.0.wait;	// seems to be necessary to prevent duplicate reverbs
		(thisProcess.nowExecutingPath.dirname.dirname +/+ "feet/feet-defs.scd").loadPath;
		2.0.wait;
	};

	~master => MCG(7);

	Fact(\opening) => BP(\op);
	Fact(\openingSteps) => BP(\st);
	PR(\trajectories) => BP(\traj);

	2.0.wait;

	~feetGui = Proto {
		~width = 356;
		~background = Color.grey(0.3);
		~stringColor = Color.green(0.8);
		~prep = {
			if(~win.isNil or: { ~win.isClosed }) {
				~win = ResizeFlowWindow("feet opening", Window.screenBounds);
				StaticText(~win, Rect(0, 0, ~width, 30))
					.align_(\center)
					.background_(~background).stringColor_(~stringColor)
					.string_("Feet opening sequence");
				~win.startRow;
				~goButton = Button(~win, Rect(0, 0, ~width, 30))
					.states_([["GO"], ["stop"]])
					.action_(e { |view|
						if(view.value > 0) {
							~seq.play;
							~win.userCanClose = false;
							~quitButton.enabled = false;
							~upd = Updater(~seq, e { |obj, what|
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
							~seq.stop;
						}
					});
				~win.startRow;
				StaticText(~win, Rect(0, 0, 200, 20))
					.align_(\center)
					.string_("initial master volume");
				~mVol = GenericGlobalControl(\mvolume, nil, -4, #[-20, 0, \db]);
				~mVol.gui(~win);
				~win.startRow;
				StaticText(~win, Rect(0, 0, 120, 20))
					.align_(\center)
					.string_("IP:port of v4");
				~addrBox = TextField(~win, Rect(0, 0, ~width - 122, 20))
					.action_({ |view|
						var	str = view.value, ip, port, colonI,
							badFmt = {
								fork {
									view.background_(Color.red).string_("WRONG FORMAT");
									0.8.wait;
									view.background_(Color.clear).string_(str);
								}
							};
						if((colonI = str.indexOf($:)).notNil) {
							ip = str[ .. colonI-1];
							port = str[colonI+1 .. ].tryPerform(\asInteger) ? -9999;
							if(ip.count(_ == $.) != 3 or: { port == -9999 }) {
								badFmt.value;
							} {
								Library.put(\vizAddr, NetAddr(ip, port));
								view.string_(Library.at(\vizAddr).asString);
							};
						} {
							badFmt.value;
						};
					});
				~win.startRow;
				~quitButton = Button(~win, Rect(0, 0, ~width, 30))
					.states_([["Quit this demo"]])
					.action_(e {
						~upd.remove;
						~win.close;
					});
		
				~win.onClose = e {
					fork {
						BP.all.stop;
						0.2.wait;
						BP(#[op, st, traj]).free;
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

		~seq = TLSequenceIterator([
			{	topEnvironment[\master].level = ~mVol.value.dbamp;
//				topEnvironment[\master].startRecord(thisProcess.platform.recordingsDir +/+ "feet4showing.aiff");
				1
			},
			bpCmd: (name: \op, dur: 35, prepareBP: { |bp|
				bp.ampCtl.value = 0.68;
				if(d.class == DDWTimer) { d.reset };
			}),
			12,
			gcAutoSynthCmd: (gc: BP(\op).ampCtl, name: \ctlPoint, outName: \outbus,
				value: 0, time: 22, curve: -2),
			bpCmd: (name: \st, prepareBP: { |bp|
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
				value: 0.7, time: 14, curve: 2),
			\cmdSync,
			20,
			loopCmd: (repeats: 3,
				cmds: [
					funcCmd: (
						setDoneSignal: {
							~doneSignal = true;
							defer(e {
								~window = Window("go", Rect.aboutPoint(Window.screenBounds.center, 50, 20));
								Button(~window, ~window.view.bounds.insetBy(2, 2))
									.states_([["play note soon"]])
									.action_(e { ~stop.() });
								~window.front;
							});
						},
						func: 0,
						clearDoneSignal: {
							defer(e { ~window.close });
						}
					),
					\cmdSync,
					funcCmd: (
						doneSignal: true,
						func: {
							BP(\st).override(\gest, Pn(\oneKlankStepsCallback, 1), false,
								// override cleanup will always hit before the next gesture is picked
								// therefore it won't use defaultParms that aren't meant for it
								{ BP(\st).defaultParms = nil });
							// guarantee next "note" can't happen until last note gesture is done
							BP(\st).defaultParms = (numEv: rrand(10, 20), callback: e { ~stop.() });
						}
					),
					\cmdSync
				]
			),
			\cmdSync,
			{ "post-loop".debug; 5 },
			{	var	bp = BP(\st);
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
				120
			},
			mixerAutoSynthCmd: (mixer: topEnvironment[\master], name: \ctlPoint, outName: \outbus,
				value: 0, time: 20, curve: -2.1),
			\cmdSync,
			funcCmd: (func: {
//				topEnvironment[\master].stopRecord;
				~iterator.stop;
			})
		]);
	};
	~feetGui.prep;
};

