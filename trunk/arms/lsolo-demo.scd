// hold yxsw upper notes longer (decayTimeScale maybe?)
// melody


(Document.current.path.dirname +/+ "arms-defs1.scd").loadPath;

(
\chuckIf.eval(Fact(\armsChordVC), VC, \ac, nil, Library.at(\rvbs));
Fact(\armsBass) => VC(\abs);
Fact(\shimmerpad).chuck(VC(\sp), nil, (
	env: Env.adsr(0.5, 0.4, 0.8, 1.8, curve: -2),
	fenv: {
		var	peak = NamedControl.kr(\fenvpeak, 1);
		Env.adsr(0.5, 0.5, 0.1, 3, peakLevel: peak, bias: 1, curve: \exp)
	},
	globalFilter: false
));
Fact(\armsmelVC).chuck(VC(\bmel), nil, (
	env: { var length = NamedControl.kr(\length, 0); Env.perc(0.01, length) },
	// env: Env.adsr(0.01, 2.5, 0.05, 1.2),
	isMono: false
));
VC(\bmel).v.setArgDefaults([ffreq: 12258]);
Fact(\locomoLead) => VC(\lm);

Fact(\dataIn).chuck(BP(\di), nil, (playTestFile: true, readFrame: 138));
BP(\di).setStartTime(14, 54);

BP(\dr).free;
PR(\dataReader) => BP(\dr);
0 => BP(\dr);

BP(\lsyx).free;
Fact(\lsoloTrig).chuck(BP(\lsyx), nil, (
	doTrig: { |data|
		case { data[0] > ~thresh } {
			~hasFiredHigh = true;
			BP(#[qc, lsac]).stop;
//			if(BP.exists(\lsm)) { BP(\lsm).stop };
			BP(\yxsw).nextNoteNow;
			NotificationCenter.registerOneShot(BP(\yxsw).esp, \event, \bass, { |event|
				(	voicer: VC(\abs).v,
					mode: event[\mode],
					freq: event[\degrees][0] - 7,
					delta: 1,
					length: rrand(3.5, 5.5),
					gate: 0.4
				).parent_(ProtoEvent(\voicerNote).v.parent)
				.play;
			});
		}
		{ data[0] < ~lowThresh and: { #[nil, true].includes(~hasFiredHigh) } } {
			~hasFiredHigh = false;
			~lowThreshTime = ~clock.beats;
			if(BP(\bfl).isPlaying.not) { BP(\bfl).play };
			BP(\lsac).play;
			BP(\qc).reset;
			BP(\qc).triggerOneEvent(DelayTimeSpec(0.4));
		};
	}
));

BP(\lsac).free;
Fact(\acceltrig).chuck(BP(\lsac), nil, (
	doTrig: { |latest|
		if(latest.sign > 0 and: { (BP(\qc).clock.beats - BP(\qc).v[\eventSchedTime]) > 1.0 }) {
			BP(\qc).triggerOneEvent(0);
			if(BP.exists(\lsm) and: { BP(\lsm).isPlaying.not and: {
				(BP(\lsyx).clock.beats - BP(\lsyx).lowThreshTime) > 2.0
			} }) {
				BP(\lsm).play(DelayTimeSpec(rrand(0.7, 1.5)));
			};
		};
	},
	autoPlay: false
));

BP(\yxsw).free;
PR(\yxswirls) => BP(\yxsw);
VC(\ac) => BP(\yxsw);
0 => BP(\yxsw);

BP(\qc).free;
PR(\quietChords) => BP(\qc);
VC(\sp) => BP(\qc);
0 => BP(\qc);

BP(\bfl).free;
PR(\bellFlourish) => BP(\bfl);
VC(\bmel) => BP(\bfl);
0 => BP(\bfl);
BP(\bfl).printStopMsg = false;

BP(\lsm).free;
Fact(\lsoloMel) => BP(\lsm);
VC(\lm) => BP(\lsm);
BP(\lsm).event.mainAmp = BP(\lsm).event.mainAmp * 12.dbamp;

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
BP(#[lsac, qc, bfl, yxsw, lsyx, dr, di]).free;
VC.all.free;

Object.dependantsDictionary.keys.select(_.isMemberOf(BP))

BP(\lsyx).v[\preparePlay] = { ~hasFiredHigh = nil };

BP(\lsyx).doTrig = { |data|
	case { data[0] > ~thresh } {
		~hasFiredHigh = true;
		BP(#[qc, lsac]).stop;
		BP(\yxsw).nextNoteNow;
		NotificationCenter.registerOneShot(BP(\yxsw).esp, \event, \bass, { |event|
			(	voicer: VC(\abs).v,
				mode: event[\mode],
				freq: event[\degrees][0] - 7,
				delta: 1,
				length: rrand(3.5, 5.5),
				gate: 0.4
			).parent_(ProtoEvent(\voicerNote).v.parent)
			.play;
		});
	}
		{ data[0] < ~lowThresh and: { #[nil, true].includes(~hasFiredHigh) } } {
		~hasFiredHigh = false;
		if(BP(\bfl).isPlaying.not) { BP(\bfl).play };
		BP(\lsac).play;
		BP(\qc).reset;
		BP(\qc).triggerOneEvent(DelayTimeSpec(0.4));
	};
};


BP(\di).vs.controlSpec = #[0, 2];
BP(\di).velSizeSpec = #[1, 8, -2].asSpec;

BP(\lsac).autoPlay = false;

BP(\lsac).doTrig = { |latest|
	if(latest.sign > 0 and: { (BP(\qc).clock.beats - BP(\qc).v[\eventSchedTime]).debug("time since last qc") > 1.0 }) {
		BP(\qc).debug("triggering").triggerOneEvent(0)
	};
};

VC(\sp).env.target.synthgroup.set(\gate, 0)

BP(\yxsw).decayTimeScale = Pkey(\freq).linlin(19, 53, 1, 3.5);
BP(\yxsw).iok = Pfunc({ |ev|
		var	i, rand, base = ev[\base], randTop = ev[\randomizer],
			test = { |hz| ev[\voicer].nodes.any { |n|
				n.isPlaying and: { n.isReleasing.not and: { n.frequency == hz } } 
			} };
		block { |break|
			3.do {
				rand = randTop.rand;
				i = (base + rand).round;
				if(test.(Mode(ev[\mode]).cps(ev[\degrees][i])).not) {
					// ev[\i] = (ev[\base] + rand).round;
					break.([i, true])
				};
			};
			[-1, false]
		}
	});
