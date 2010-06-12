
// run one of these lines to control whether x/y come from mouse or video OSC messages

~useMouse = true;

~useMouse = false;

s.sendMsg(\c_setn, 3996, 8, 0, 0, 0, 0, 0, 0, 0, 0)
Help.gui;

(
var	stopUpdater;

s.waitForBoot {

	~master ?? { ~master = MixerChannel(\master, s, 2, 2, level: 1) };

	(Document.current.path.dirname +/+ "arms-defs.scd").loadPath;

	if(VC.exists(\chord).not) { Fact(\fmping) => VC(\chord) };
	if(VC.exists(\bass).not) { Fact(\armsBass) => VC(\bass) };

	MixingBoard.at(0) ?? {
		fork {
			MixingBoard(\mixer, nil, VC(\chord), VC(\bass), ~master);
			2.0.wait;
			MixingBoard.at(0).refresh;
		};
	};

	BP.all.free;

	// create xy tracker
	PR(\xyDispatch) => BP(\xy);
	0 => BP(\xy);

	// create chord chooser
	// note, this should be done before chord and bass to create dependencies
	PR(\chordChooser) => BP(\cchs);
	1 => BP(\cchs);
	BP(\cchs).leadTime = 0.05;

	// create chord player
	Fact(\vertNotes) => BP(\vertNotes);
	BP(\vertNotes) => VC(\chord);

// THIS LINE OVERRIDES DEFAULT ATTACK SPEED BEHAVIOR!
// 0 maps onto shortest possible; 1 maps onto 10* longer
BP(\vertNotes).envScale = 0;

	// create bass player
	PR(\rhythmBusPool) => BP(\bass);
	BP(\bass) => VC(\bass);
	1 => BP(\bass);

	// show rhythm-audibility parameter
	~rhythmW !? { ~rhythmW.close };
	~rhythmW = ResizeFlowWindow("rhythm", Rect(200, 80, 400, 400));
	BP(\bass).modUpCtl.gui(~rhythmW);
	~rhythmW.recursiveResize.front;

	// show tracking gui
	PR(\trackviz).chuck(BP(\viz), nil, (
		model: \xy,
		useMouse: ~useMouse ? false,
		diffScale: 10
	));

	stopUpdater = Updater(BP(\viz), e { |obj, what|
		if(what == \free) {
			stopUpdater.remove;
			BP.all.stop;
			BP.all.free;
			~rhythmW.close; ~rhythmW = nil;
			{ VC.all.free; MixingBoard.at(0).free; }.defer(2.5);
		};
	});

	// play processes
	BP(#[xy, cchs, bass]).play(2);

};
)
