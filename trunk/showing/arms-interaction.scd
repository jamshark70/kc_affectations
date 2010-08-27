// arms interaction code for showing, 31 Aug 2010

if(MCG.exists(0).not) {
	\makeEmptyMixer8.eval;
};

if(PR.exists(\armsChord).not) {
	s.waitForBoot {
		// (thisProcess.nowExecutingPath.dirname.dirname +/+ "feet/feet-defs.scd").loadPath;
		// 2.0.wait;	// seems to be necessary to prevent duplicate reverbs
		(thisProcess.nowExecutingPath.dirname.dirname +/+ "arms/arms-defs1.scd").loadPath;
		2.0.wait;

		~master => MCG(7);
		Fact(\armsChordVC) => VC(\ac);
		VC(\ac).env.target => MCG(0);

		Fact(\dataIn).chuck(BP(\di), nil, (bus: Bus.new(\control, 3996, 8, s)));
		
		BP(\acDisp).free;
		PR(\armsChord) => BP(\acDisp);
		BP(\acDisp) => VC(\ac);
		0 => BP(\acDisp);

		Fact(\acTrig) => BP(\acTrig);
	};
};

// ChuckableBrowser.newWindow;

/*
BP(#[di, acTrig]).play;

BP(BP(\acDisp).lastSpawned) => VP(0);

BP.all.stop;
BP.all.free;
*/

~armsGui = Proto {
	~prep = {
		~win = ResizeFlowWindow("arms chords", Window.screenBounds);
		StaticText(~win, Rect(0, 0, 200, 30)).string_("Arms locomotive theme");
		~win.startRow;
		Button(~win, Rect(0, 0, 200, 30))
			.states_([["Use live data"], ["Use test file"]])
			.action_({ |view| BP(\di).playTestFile = view.value > 0 });
		~win.startRow;
		~goButton = Button(~win, Rect(0, 0, 200, 30))
			.states_([["GO"], ["stop"]])
			.action_(e { |view|
				if(view.value > 0) {
					BP(#[di, acTrig]).play;
					~win.userCanClose = false;
					~quitButton.enabled = false;
					~upd = Updater(BP(\di), e { |obj, what, more|
						if(more == \stopped) {
							~upd.remove;
							~goButton.value = 0;
							~win.userCanClose = true;
							~quitButton.enabled = true;
							BP.all.stop;
						}
					});
				} {
					BP(\di).stop;
				}
			});
		~win.startRow;
		~quitButton = Button(~win, Rect(0, 0, 200, 30))
			.states_([["Quit this demo"]])
			.action_(e {
				~upd.remove;
				~win.close;
			});

		~win.onClose = { 
			BP.all.stop;
			BP.keys.do { |key|
				var	keyStr = key.asString;
				if(keyStr[..1] == "ac" and: { keyStr.any(_.isDecDigit) }) { BP(key).free };
			};
			BP(#[acDisp, acTrig, di]).free;
			VC(\ac).free;
		};
		~win.recursiveResize;
		~win.bounds = ~win.bounds.center_(Window.screenBounds.center);
		~win.front;
	};
};

~armsGui.prep;