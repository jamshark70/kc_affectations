//////// arms section sequencer

ChuckableBrowser.newWindow;

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

	\chuckIf.eval(PR(\armsSkidMel), BP, \am, nil, (
		glrvbmc: ~glrvbmc,
		lcrvbmc: ~lcrvbmc,
		master: ~master
	));

	~trigParms = (
		sbounds: Window.screenBounds,
		// play: \dummy,
		setDoneSignal: {
			~doneSignal = true;
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
};
);

(
if(t.isPlaying) { t.stop; "Wait for old sequencer to stop...".die };
t = TLSequenceIterator([
	{	BP(\am).prepareForPlay;
		// HACK
		BP(\am).makeStreamForKey(\degree);
		BP(\am).makeStreamForKey(\rewriteLevel);

		\chuckIf.eval(Fact(\armsChordVC), VC, \ac);
		\chuckIf.eval(Fact(\dataIn), BP, \di);
		\chuckIf.eval(PR(\armsChord), BP, \acDisp, nil, (
			angleBus: BP(\di).bus.index + 1, // ??
			rotSpeedBus: BP(\di).bus.index + 4
		));
		BP(\acDisp) => VC(\ac);
		0 => BP(\acDisp);

		// TEST
		BP(\di).playTestFile = true;

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
		VC(\ac) => BP(\sr);
		0 => BP(\sr);
		0
	},
	bpCmd: (id: \lc1, name: \di, quant: 0,
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
		BP(\tc) => VC(\btp);
		\chuckIf.eval(PR(\shivaTrig), BP, \shivaTrig);
		BP(#[am0, am1, am2, tc]).do(_.prepareForPlay);
		0
	},
	bpCmd: (id: \ai, name: \ai),
	funcCmd: \nextThingParms.eval(\ai),
	\cmdSync,

	{ "///// 12:10 -- Shiva".debug; 0 },
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
	///// 13:20 -- axial theme in three levels
	///// (restarted that at 13:54)
	///// 14:37 -- Stephen/Ilana partnering
	///// 15:08 -- picking up Laura, then manipulating her through the axial theme
	///// 15:42 -- locomotive
	///// 15:49 -- short solo from Stephen
	///// 15:55 -- cradling, drawing bow sequence
	///// 16:34 -- all three to the ground, then up
	///// 16:50 -- Laura solo, mostly locomotive material
	///// 18:08 -- screen in, Laura goes behind shortly after
	///// 18:38 -- face dance

	{ "over and out!".debug; 0 }
]).play;
)

t.stop;

t.isPlaying

BP.all.stop;

BP.all.do(_.reset);

BP.all.free;
VC.all.free;