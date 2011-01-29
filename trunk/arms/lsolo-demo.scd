(Document.current.path.dirname +/+ "arms-defs1.scd").loadPath;

(
\chuckIf.eval(Fact(\armsChordVC), VC, \ac, nil, Library.at(\rvbs));
Fact(\armsBass) => VC(\abs);

Fact(\dataIn).chuck(BP(\di), nil, (playTestFile: true, readFrame: 138));
BP(\di).setStartTime(14, 50);

BP(\dr).free;
PR(\dataReader) => BP(\dr);
0 => BP(\dr);

BP(\lsyx).free;
Fact(\lsoloTrig).chuck(BP(\lsyx), nil, (
	doTrig: {
		var espUpd;
		BP(\yxsw).nextNoteNow;
		espUpd = Updater(BP(\yxsw).esp, { |obj, what, event|
			if(what == \event) {
				espUpd.remove;
				(	voicer: VC(\abs).v,
					mode: event[\mode],
					freq: event[\degrees][0] - 7,
					delta: 1,
					length: rrand(3.5, 5.5),
					gate: 0.4
				).parent_(ProtoEvent(\voicerNote).v.parent)
				.play;
			}
		});
	}
));

BP(\yxsw).free;
PR(\yxswirls) => BP(\yxsw);
VC(\ac) => BP(\yxsw);
0 => BP(\yxsw);

s.latency = 0.075;

u.remove;
u = Updater(BP(\lsyx), { |obj, what, more|
	case { what == \play } { BP(\yxsw).play(DelayTimeSpec(0.1)) }
		{ more == \stopped } { BP(\yxsw).stop };
});

VC(\abs).portaTime = 0.8;

~master.mcgui ?? { MixingBoard(\lsolo, nil, VC(\abs), ~master) };
)

BP(\di).play;

// after laura leaves the stage, or anytime
BP(\di).stop;

// cleanup
BP(#[yxsw, lsyx, dr, di]).free;
VC.all.free;