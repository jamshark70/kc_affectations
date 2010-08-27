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

BP(#[di, acTrig]).play;

BP.all.stop;