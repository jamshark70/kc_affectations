//////// arms section sequencer

// first, put the cursor right below '// init' (on the paren)
// and do ctrl-alt-x

// then put the cursor here and C-c C-c to run the line
t.stop; t.play;

// and if you need to stop:
t.stop;  // by itself



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

	{ |searchID|
		(	cmdID: searchID,
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
						r.remove;
						~stop.();
					}).add;
					defer(e {
						~window = Window("move on",
							Rect(~sbounds.right - 120, ~sbounds.height - 300, 120, 60));
						Button(~window, ~window.view.bounds.insetBy(2, 2))
							.states_([["next seg"]])
							.action_(e { ~stop.() });
						~window.front.userCanClose_(false);
					});
				}
			},
			clearDoneSignal: {
				~doneSignal.do(_.stop);  // this is the previous loopcmd!
				~window !? { defer(e { ~window.close }) };
			};
		)
	} => Func(\nextThingParms);

	BP(\segTrig).free;
	PR(\busTrig).chuck(BP(\segTrig), nil, (message: '/segment'));
	BP(\evTrig).free;
	PR(\busTrig).chuck(BP(\evTrig), nil, (message: '/event', busIndex: 4094));
	0.5.wait;
	BP(#[segTrig, evTrig]).play(0);

	0.5.wait;

	if(t.isPlaying) { t.stop; "Wait for old sequencer to stop...".die };
	t = TLSequenceIterator([
		{	
			\chuckIf.eval(PR(\armsSkidMel), BP, \am, nil, (
				glrvbmc: ~glrvbmc,
				lcrvbmc: ~lcrvbmc,
				master: ~master
			));
	
			BP(\am).amp = 0.9;
			BP(\am).prepareForPlay;
			BP(\am).v.reset;  // drives me NUTS this function isn't called by BP().reset
	
			\chuckIf.eval(Fact(\armsChordVC), VC, \ac);
			\chuckIf.eval(Fact(\dataIn), BP, \di);
			\chuckIf.eval(PR(\armsChord), BP, \acDisp, nil, (
				angleBus: BP(\di).bus.index + 1, // ??
				rotSpeedBus: BP(\di).bus.index + 4
			));
			BP(\acDisp) => VC(\ac);
			0 => BP(\acDisp);
	
			BP(\di).playTestFile = false;
	
			0
		},
	
		{ "///// 10:05 -- axial".debug; 0 },
		loopCmd: (
			id: \am1,
			autoSync: false,
			cmds: [
				funcCmd: topEnvironment[\trigParms],
				\cmdSync,
				{ 2.do { BP(\am).triggerOneEvent(0) }; 0 }
			]
		),
		funcCmd: \nextThingParms.eval(\am1),
		\cmdSync,
	
		{ "///// 10:37 -- locomotive".debug; 0 },
		{	\chuckIf.eval(PR(\sunrise), BP, \sr);
			BP(\sr).ampCtl.value = -23.dbamp;
			VC(\ac) => BP(\sr);
			0 => BP(\sr);
			0
		},
		bpCmd: (id: \lc_data, name: \di, quant: 0,
			yetToStopParent: true,
			clearDoneSignal: {
				var cmd = ~iterator.findActive(\lcWait);
				if(cmd.notNil and: { ~yetToStopParent }) {
					~yetToStopParent = false;
					cmd.stop;
				};
			}
		),
		loopCmd: (
			id: \lc1,
			autoSync: false,
			cmds: [
				{ BP(\acDisp).spawnChild(0); 0 },
				funcCmd: topEnvironment[\trigParms],
				\cmdSync
			]
		),
		funcCmd: \nextThingParms.eval(\lc1).put(\id, \lcWait),
		\cmdSync,
	
		///// 10:52 -- lifting from center (again a few seconds later)
		{ "///// 11:17 -- sunrise".debug; 0 },
		bpCmd: (name: \sr),
		\cmdSync,
	
		{	\chuckIf.eval(PR(\stacking), BP, \st, nil, (
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
			0
		},
		loopCmd: (
			id: \lc2,
			autoSync: false,
			cmds: [
				{ BP(\acDisp).spawnChild(0); 0 },
				funcCmd: topEnvironment[\trigParms],
				\cmdSync
			]
		),
		funcCmd: \nextThingParms.eval(\lc2).put(\id, \lcWait),
		\cmdSync,
	
		{ "///// 11:24 -- hand stacking".debug; 0 },
		{	
			\chuckIf.eval(Fact(\shimmerpad), VC, \sp, nil, (
				env: Env.adsr(0.5, 0.4, 0.8, 1.8, curve: -2),
				fenv: Env.adsr(0.5, 0.5, 0.1, 3, peakLevel: 1, bias: 1)
			));
			\chuckIf.eval(PR(\armsInv), BP, \ai);
			VC(\sp) => BP(\ai);
			0 => BP(\ai);
			0
		},
		bpCmd: (id: \stack, name: \st),
		// funcCmd: \nextThingParms.eval(\stack),
		\cmdSync,
		
		{ "///// 11:57 -- intricate partnering sequence".debug; 0 },
		{
			\chuckIf.eval(Fact(\armsmelVC), VC, \am);
			\chuckIf.eval(Fact(\shimmerpad), VC, \btp, nil, (
				env: Env.adsr(0.5, 0.4, 0.8, 1.8, curve: -2),
				fenv: Env.adsr(0.5, 0.5, 0.1, 3, peakLevel: 1, bias: 1),
				// need some EQ pre-reverb
				graphInsert: { |sig|
					var	hishelf = EQSpec1.newSpec(\hishelf, freq: 8705, k: -6.667.dbamp, rq: 1, sr: 44100);
					sig = HPF.ar(sig, 668);
					sig = StaticEQ.eqFuncs[\hishelf].(sig, hishelf.k, hishelf.a0);
				}
			));
			if(BP.exists(\am0).not) { Fact(\shivaBPs).makev };
			\chuckIf.eval(PR(\thinChords), BP, \tc);
			BP(\tc).finalAmp = 0.3;
			BP(\tc) => VC(\btp);
			\chuckIf.eval(PR(\shivaTrig), BP, \shivaTrig);
			BP(#[am0, am1, am2]).do { |bp| bp.amp = -4.dbamp };
			BP(#[am0, am1, am2, tc]).do({ |bp|
				bp.prepareForPlay;
				bp.v.reset
			});
			0
		},
		bpCmd: (id: \ai, name: \ai,
			// TEST
			prepareBP: { |bp|
				bp.autoRun = true
			}
		),
		funcCmd: \nextThingParms.eval(\ai),
		\cmdSync,
	
		{ "///// 12:10 -- Shiva".debug; 0 },
		{	if(BP.exists(\sm0).not) { Fact(\threelevBP).makev };
			BP(#[sm0, sm1, sm2]).do { |bp| bp.amp = -11.dbamp };
			\chuckIf.eval(Fact(\l3Trig), BP, \l3Trig, nil, (
				event: (eventKey: \l3Trig),
				playtc: false,
				i: 3
			));
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
		funcCmd: \nextThingParms.eval(\shiva),
		\cmdSync,
	
		///// 12:45 -- swaying, into another partnering sequence
		/////// (not done yet, crap!!)
	
		{ "///// 13:20 -- axial theme in three levels".debug; 0 },
		///// (restarted that at 13:54)
		{	\chuckIf.eval(PR(\siDuet), BP, \sid);
			VC(\sp) => BP(\sid);
			BP(\sid).finalAmp = -22.dbamp;
			BP(\sid).delta = Pif(Pkey(\high) > 0, Pwhite(3, 5, inf),
				Pwrand(#[1, 2, 3, 4], (1..4).reciprocal, inf)
			);
			0
		},
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
		funcCmd: \nextThingParms.eval(\threelev),
		\cmdSync,
		
		///// 14:37 -- Stephen/Ilana partnering
		{	\chuckIf.eval(Fact(\lauraManip), BP, \lm);
			BP(\lm).amp = 0.45;
			BP(\lm).v.reset;
			0
		},
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
		),
		funcCmd: \nextThingParms.eval(\s_i),
		\cmdSync,
	
		// (bit of locomotive before laura-manipulation?)
		loopCmd: (
			id: \lc3,
			autoSync: false,
			cmds: [
				{ BP(\acDisp).spawnChild(0); 0 },
				funcCmd: topEnvironment[\trigParms],
				\cmdSync
			]
		),
		funcCmd: \nextThingParms.eval(\lc3).put(\id, \lcWait),
		\cmdSync,
	
		{ "///// 15:08 -- picking up Laura, then manipulating her through the axial theme".debug; 0 },
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
		funcCmd: \nextThingParms.eval(\lauraManip),
		\cmdSync,
	
		{ "///// 15:42 -- locomotive".debug; 0 },
		{	\chuckIf.eval(PR(\armsSkidMel), BP, \ssol, nil, (
				master: ~master,
				glrvbmc: ~glrvbmc,
				lcrvbmc: ~lcrvbmc,
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
			0
		},
		loopCmd: (
			id: \lc4,
			autoSync: false,
			cmds: [
				{ BP(\acDisp).spawnChild(0); 0 },
				funcCmd: topEnvironment[\trigParms],
				\cmdSync
			]
		),
		funcCmd: \nextThingParms.eval(\lc4).put(\id, \lcWait),
		\cmdSync,
	
		{ "///// 15:49 -- short solo from Stephen".debug; 0 },
		{	\chuckIf.eval(PR(\rockingChords), BP, \rc);
			VC(\sp) => BP(\rc);
			BP(\rc).finalAmp = -22.dbamp;
			0
		},
		loopCmd: (
			id: \stsolo,
			autoSync: false,
			cmds: [
				{ 2.do { BP(\ssol).triggerOneEvent(0) }; 0 },
				funcCmd: topEnvironment[\trigParms],
				\cmdSync
			],
			clearDoneSignal: { BP(\ssol).stop }
		),
		funcCmd: \nextThingParms.eval(\stsolo),
		\cmdSync,
	
		{ "///// 15:55 -- cradling, drawing bow sequence".debug; 0 },
		bpCmd: (id: \rc, name: \rc,
			// TEST
			prepareBP: { |bp|
				bp.autoRun = true
			}
		),
		funcCmd: \nextThingParms.eval(\rc),
		\cmdSync,
	
	/*
	//	{ "///// 16:34 -- all three to the ground, then up".debug; 0 },
		{ "///// 16:50 -- Laura solo, mostly locomotive material".debug; 0 },
	
	
		{ "///// 18:08 -- screen in, Laura goes behind shortly after".debug; 0 },
		{ "///// 18:38 -- face dance".debug; 0 },
	*/
	
		{ "over and out!".debug; 0 }
	]).play;
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