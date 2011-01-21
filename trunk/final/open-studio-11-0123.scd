// Affectations
// Open-studio loader for 2011 Jan. 23


// this block loads everything: cursor on open-paren, then ctrl-alt-x
(
var	mypath = thisProcess.nowExecutingPath; // indices;

var	trigBus = 4094,
	continuousDataSize = 12,
	continuousDataBus = trigBus - continuousDataSize;

s = Server.local;
s.waitForBoot {
	var	cond = Condition.new, p;
	(mypath.dirname.dirname +/+ "/common/common-defs.scd").loadPath;
	NotificationCenter.registerOneShot(\lcrvb, \lcrvbexists, \feetSeq, {
		cond.unhang;
	});
	cond.hang;

	if(~master.mcgui.isNil) {
		if(MCG.exists(7)) {
			~master => MCG(7)
		} {
			MixingBoard(\arms, nil, ~master)
		};
	};

	// BP(\segTrig).free;
	// PR(\busTrig).chuck(BP(\segTrig), nil, (message: '/segment'));
	BP(\evTrig).free;
	PR(\busTrig).chuck(BP(\evTrig), nil, (
		message: '/event', busIndex: trigBus,
		actions: [
			nil,  // index 0 is not a real trigger
			{	// axial melody - later, switch between different sounds?
				2.do { BP(\am).triggerOneEvent(0) }
			},
			{	// locomotive chords
				BP(\acDisp).spawnChild(0);
			},
			{	// chordal material
				var	isPlaying = BP(\ai).isPlaying;
				if(BP(\ai).isPlaying) {
					BP(\ai).runGesture;
				} {
					BP(\ai).autoRun_(false);
					BP(\ai).play(0);
					BP(\ai).clock.sched(0.01, { BP(\ai).runGesture; nil });
				};
			},
			{	// bass support
				// process isn't good for on-the-fly reset
				// triggers while it's already playing will be dropped
				if(BP(\abs).isPlaying.not) { BP(\abs).play(0) };
			},
			{
				if(BP(\bmel).isPlaying) {
					BP(\bmel).preparePlay;  // resets streams, restarting melody
				} {
					BP(\bmel).play(0)
				};
			}
		],
		userPreparePlay: {
			~resp ?? {
				~resp = OSCresponderNode(s.addr, ~message, e { |time, resp, msg|
					~actions[msg[3]].(time, resp, msg);
					~flashProc.(msg[3]);
				}).add;
			};
			(e { ~makeControlPanel.() }).defer(1.2);
		},
		userStopCleanup: {
			~resp.remove; ~resp = nil;
		},
		procDisplayNames: [nil, \axial, \locomotive, \chordal, \bass, \bells],
		procResetTimes: (0 ! 6).put(0, nil),
		procFlashTime: 0.75,
		procFlashColor: Color.new255(255, 120, 120),
		procUnFlashColor: Color.gray(0.92),
		flashProc: { |i|
			{	var now = thisThread.clock.beats;
				// the array item is nil if there's nothing to do; ignore in that case
				if(~procResetTimes[i].notNil) {
					if(now > ~procResetTimes[i]) {
						~procBtns[i].background_(~procFlashColor);
					};
					~procResetTimes[i] = now + ~procFlashTime;
					~procFlashTime.wait;
					if(thisThread.clock.beats >= ~procResetTimes[i]) {
						~procBtns[i].background_(~procUnFlashColor);
					};
				};
			}.fork(AppClock);
		},
		makeControlPanel: {
			var savedAddr;

			// control panel
			~win = ResizeFlowWindow("Open Studio 2011-01-23", Rect(10, 50, 600, 500))
				.onClose_(e {
					var	file, path, addr, dibus;
					~dataPlayUpd.remove;
					dibus = BP(\di).recvBus;
					if(Library.at(\vizAddr).isKindOf(NetAddr)) {
						path = Platform.userAppSupportDir +/+ "vizaddr.txt";
						addr = path.loadPath(warnIfNotFound: false);
						if(Library.at(\vizAddr) != addr) {
							protect {
								file = File(path, "w");
								if(file.isOpen) {
									file <<< Library.at(\vizAddr) << Char.nl;
								} {
									"Couldn't persist visual system address in %\n".format(path).warn;
								};
							} { file.tryPerform(\close) };
						};
					};
					VC.all.free;
					BP.all.do { |bp|
						if(bp.collIndex != \di) { bp.free };
					};
					BP(\di).free;
					dibus.releaseBus(~collIndex);
				});
	
			StaticText(~win, 590@40)
				.string_("Open Studio 2011-01-23")
				.align_(\center)
				.font_(Font.default.copy.size_(24).boldVariant)
				.background_(Color.new255(255, 255, 200));
			StaticText(~win, 150@20)
				.string_("Visual system IP/port")
				.align_(\right);
	
			savedAddr = (Platform.userAppSupportDir +/+ "vizaddr.txt").loadPath(warnIfNotFound: false);
			~ipField = TextField(~win, (590 - 150 - 60 - 8) @ 20)
				.value_(if(savedAddr.notNil) {
					savedAddr.ip ++ ":" ++ savedAddr.port
				} {
					"ip.ip.ip.ip:port"
				})
				.action_({ |view|
					var	str = view.value, ip, port, colonI,
					flashString = { |message, color, endColor|
						{
							view.background_(color).string_(message);
							0.8.wait;
							view.background_(endColor ?? { Color.white }).string_(str);
						}.fork(AppClock);
					};
					if((colonI = str.indexOf($:)).notNil) {
						ip = str[ .. colonI-1];
						port = str[colonI+1 .. ].tryPerform(\asInteger) ? -9999;
						if(port <= 0) { port = -9999 };
						if(ip.count(_ == $.) != 3 or: { port == -9999
							or: { ip.reject(_ == $.).any { |ch| ch.isDecDigit.not } } }) {
								flashString.value("WRONG FORMAT", Color.red);
							} {
								Library.put(\vizAddr, NetAddr(ip, port));
								flashString.value("OK: " ++ Library.at(\vizAddr).asString,
									Color.new255(180, 255, 180), Color.new255(180, 255, 180));
								// view.string_(Library.at(\vizAddr).asString);
							};
					} {
						flashString.value("WRONG FORMAT", Color.red);
					};
				})
				.tryPerform(\focusLostAction_, { |view| view.doAction })
				.tryPerform(\focusGainedAction_, { |view| view.background_(Color.white) });
	
			~testBtn = Button(~win, 60@20)
				.states_([["Test"]])
				.action_({ |view|
					var	vizAddr = Library.at(\vizAddr);
					if(vizAddr.notNil) {
						"Sending test message to %\n".postf(vizAddr);
						vizAddr.sendBundle(nil, [\note, \test.hash, -1, 0.2, 0.0, 1.0, 1.0, 0.0, 5].debug("msg"));
					} {
						"Enter a valid address before clicking".warn;
					};
				});
			~win.startRow;

			~procBtns = Array.newClear(6);
			~bWidth = (590 - (4*4)) / 5;
			~procDisplayNames[1..].do { |proc, i|
				~procBtns[i+1] = StaticText(~win, ~bWidth @ 20)
				.background_(~procUnFlashColor)
				.string_(proc)
				.align_(\center)
			};
	
			StaticText(~win, (590/2 - 2) @ 20)
				.string_("Continuous data:")
				.align_(\right);
			~dataPlayBtn = Button(~win, 100@20)
				.states_([["is stopped"], ["is running", Color.black, Color.new255(180, 255, 180)]])
				.action_({ |view|
					if(view.value > 0) { BP(\di).play } { BP(\di).stop };
				});
			~dataPlayUpd = Updater(BP(\di), e { |obj, what, more|
				case
					{ what == \play } { ~dataPlayBtn.value = 1 }
					{ more == \stopped } { ~dataPlayBtn.value = 0 };
			});

			if(savedAddr.notNil) { ~ipField.doAction; ~testBtn.focus(true) } {
				~ipField.focus(true)
			};
			~win.recursiveResize.front;
		}
	));
	0.5.wait;
	BP(\evTrig).play(0);

	// Library.put(\diparms, (id: \lc_data, name: \di, quant: 0,
	// 	playWarning: false, shouldSync: false));

	(mypath.dirname.dirname +/+ "arms/arms-defs1.scd").loadPath;

	// load 5 procs
	// common: data in
	s.controlBusAllocator.reserve(continuousDataBus, continuousDataSize, warn: false);
	\chuckIf.eval(Fact(\dataIn), BP, \di, nil, (
		recvBus: Bus(\control, continuousDataBus, continuousDataSize, s)
	));
	BP(\di).recvBus.owner = \evTrig;

	// 1. Axial
	\chuckIf.eval(Fact(\dataIn), BP, \di, nil/*, (
			filename: "arms/hands-1_data2.wav" //"arms/NACL_Arms.wav"
			)*/);
	\chuckIf.eval(PR(\armsSkidMel), BP, \am, nil, (
		glrvbmc: topEnvironment[\glrvbmc],
		lcrvbmc: topEnvironment[\lcrvbmc],
		master: topEnvironment[\master]
	));
	
	BP(\am).amp = 0.35 * 10.dbamp; // 0.9;
	BP(\am).prepareForPlay;
	BP(\am).v.reset;

	// 2. Locomotive
	\chuckIf.eval(Fact(\armsChordVC), VC, \ac, nil, Library.at(\rvbs));
	\chuckIf.eval(PR(\armsChord), BP, \acDisp, nil, (
		angleBus: BP(\di).bus.index + 1, // ??
		rotSpeedBus: BP(\di).bus.index + 4,
		amp: 0.2 * (10.dbamp)
	));
	BP(\acDisp) => VC(\ac);
	0 => BP(\acDisp);
	
	p = BP(\acDisp);
	p.startAuto = p[\saveStartAuto] ? p[\startAuto];
	p.row = p[\saveRow] ? p[\row];
	p.chord = p[\saveChord] ? p[\chord];
	p.fullCh.removeAt(\diss1);
	p.fullCh.removeAt(\diss2);
	// p.amp = -20.dbamp;

	// 3. Chordal
	\chuckIf.eval(Fact(\shimmerpad), VC, \sp, nil, (
		env: Env.adsr(0.5, 0.4, 0.8, 1.8, curve: -2),
		fenv: Env.adsr(0.5, 0.5, 0.1, 3, peakLevel: 1, bias: 1)
	).putAll(Library.at(\rvbs)));
	\chuckIf.eval(PR(\armsInv), BP, \ai);
	BP(\ai).ampCtl.value = 0.115 * 10.dbamp; // 0.115; // 0.045;
	VC(\sp) => BP(\ai);
	0 => BP(\ai);

	// 4. Bass
	\chuckIf.eval(Fact(\armsBass), VC, \abs, nil, Library.at(\rvbs));
	\chuckIf.eval(PR(\armsbass), BP, \abs);
	VC(\abs) => BP(\abs);
	1 => BP(\abs);
	VC(\abs).env.target.level = -10.dbamp;

	// 5. Bell melody
	topEnvironment[\clock96] ?? {
		topEnvironment[\clock96] = TempoClock(96/60).permanent_(true);
	};

	\chuckIf.eval(Fact(\armsmelVC), VC, \bmel, nil, (
		env: { var length = NamedControl.kr(\length, 0); Env.perc(0.01, length) },
		// env: Env.adsr(0.01, 2.5, 0.05, 1.2),
		isMono: false
	));
	VC(\bmel).v.setArgDefaults([ffreq: 12258]);

	\chuckIf.eval(Fact(\bmelBP), BP, \bmel);
	0 => BP(\bmel);
	topEnvironment[\clock96] => BP(\bmel);
	BP(\bmel).ampMul.value = 0.26 * 10.dbamp;

	BP(\am).event.vizKeys = Library.at(\defaultVizKeys).copy.put(3, {
		~hiffreq.asArray[0].tryPerform(\explin, 20, 20000, -1.0, 1.0)
	});
	BP(\am).event.soundID = 0;

	BP(\ai).event.soundID = 0;
	BP(\abs).event.soundID = 0;
	BP(\bmel).event.soundID = 0;

	~master.level = -10.dbamp;
};
)



// DEBUG SNIPS

ChuckableBrowser.newWindow;

MT(1).gui;

BP.all.stop;

// if you need to clear everything, do this:
BP.all.do { |bp| if(bp.collIndex != \mstClock) { bp.free } }; VC.all.free;
if(BP.exists(\mstClock)) { BP(\mstClock).free };

~seq.sections.do(_.prUnload);



// unit tests
c = BP(\evTrig).bus;
c.set(1.debug);
c.set(2.debug);
c.set(3.debug);
c.set(4.debug);
c.set(5.debug);

r = fork {
	var	p = Psmartstutter(Pfunc({ |pr| if(pr == 1) { rrand(3, 8) } { 1 } }),
			Pwhite(1, 5, inf)).asStream,
	w = Pswitch1([
		1, //dummy
		Pwhite(0.7, 1.2, inf),
		Pwhite(2.0, 4.5, inf),
		Pwhite(2.0, 4.5, inf),
		Pwhite(2.0, 4.5, inf),
		Pwhite(2.0, 4.5, inf)
	], Pfunc({ |n| n })).asStream,
	proc;
	loop {
		BP(\evTrig).bus.set(proc = p.next);
		w.next(proc).wait;
	}
};

r.stop;


BP(\evTrig).flashProc(1)

// run some data for tests
BP(\di).playTestFile = true;
BP(\di).setStartTime(10, 0);

BP(\di).bus
BP(\di).recvBus

o.remove;
o = OSCresponderNode(nil, '/note', { |t, r, m| m.postln }).add;

Library.at(\vizAddr).sendMsg('/note', 834821825, -1, 0.20000000298023, 0, 1, 1, 0, 5);
Library.at(\vizAddr).sendMsg(*['/note', 834821825, -1, 0.20000000298023, 0, 1, 1, 0, 5]);
Library.at(\vizAddr).sendMsg(*[834821825, -1, 0.20000000298023, 0, 1, 1, 0, 5]);
Library.at(\vizAddr).sendMsg(834821825, -1, 0.20000000298023, 0, 1, 1, 0, 5);

n = NetAddr("127.0.0.1", NetAddr.langPort);

BP(\am).event.vizKeys = Library.at(\defaultVizKeys).copy.put(3, { ~hiffreq.asArray[0].tryPerform(\explin, 20, 20000, -1.0, 1.0) });
BP(\am).event.soundID = 0;

BP(\ai).event.soundID = 0;
BP(\abs).event.soundID = 0;
BP(\bmel).event.soundID = 0;

BP(\am).reset; BP(\am).v.reset;

BP(\am).amp = 0.35 * 10.dbamp;
BP(\acDisp).amp = 0.2 * (10.dbamp);

BP(\acDisp).amp = 0.1 * 10.dbamp;

BP(\bmel).ampMul.value = 0.26 * 10.dbamp;
BP(\ai).ampCtl.value = 0.115 * 10.dbamp;
VC(\abs).env.target.level = -17.dbamp * 10.dbamp;


c.set(10);

ChuckableBrowser.newWindow;

MixingBoard.at(0).add(VC(\abs));

PeakMonitor(~master)