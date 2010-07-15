// rhythm evolution
// to do: create processes first!

Library.put(\chucklib, \midiSearches, #["remote"]); BP.loadGui;

(Document.current.path.dirname +/+ "head-defs.scd").loadPath;

~master ?? { ~master = MixerChannel(\master, s, 2, 2, level: 1) };

//~rvbmc => MCG(6);
~master => MCG(7);
MixingBoard.at(0).refresh;

BP.all.do { |bp| bp.free };

(
(1..3).do { |i| Fact(("drum" ++ i).asSymbol).chuck(BP(("drum" ++ i).asSymbol), nil, (source: \drum1)) };

NotificationCenter.registerOneShot(\drum3, \ready, \bploader, e {
	Fact(\drum4).chuck(BP(\drum4), nil, (pan: -1));
	// 5 and 6 are basically copies - switch between them to change phase vs. drum4
	Fact(\drum4).chuck(BP(\drum5), nil, (pan: 1, chan: BP(\drum4).chan));
	Fact(\drum4).chuck(BP(\drum6), nil, (pan: 1, chan: BP(\drum4).chan));

	Fact(\drum7) => BP(\drum7);
	Fact(\drum7).chuck(BP(\drum8), nil, (ctlSource: \drum7, quant: #[-1, 1.25]));
});
)

// NotificationCenter.registrationsFor(\drum3, \ready)
// NotificationCenter.unregister(\drum3, \ready, \bploader);

BP.keys.asArray.sort.do { |key|
	var mc = BP(key).chan;
	BP(key) => MT(1);
	if(mc.notNil and: { mc.mcgui.isNil }) {
		mc => MCG.collection.detect { |mcg| mcg.v.mixer.isNil };
	}
};


(
PR(\bpCmd).clone {
	~setDoneSignal = {
		~playing = if(BP(\drum5).isPlaying) { \drum5 } { \drum6 };
		~name = if(~playing == \drum5) { \drum6 } { \drum5 };
		BP(~playing).stop(~quant);
	};
	~prepareBP = { |bp| ~extraPrep.(bp); bp.reset };
} => PR(\swap56cmd);
)


(
//~master.startRecord(thisProcess.platform.recordingsDir +/+ "rhythm1.aiff");
t = TLSequenceIterator([
	{	var	bp = BP(\drum1);
		bp.bar = 3;
		bp.wetCtl.value = 0.98;
		bp.fdecCtl.value = 0.25;
		bp.ffLowCtl.value = 2;
		bp.ffRangeCtl.value = 0;
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
	Quant(3, -0.5),
/*
	bpCmd: (name: \drum1, quant: `nil, prepareBP: { |bp|
		bp.bar = Pseq(#[3, 0], inf);
// 		bp.wetCtl.value = 0.98;
// 		bp.fdecCtl.value = 0.25;
// 		bp.ffLowCtl.value = 2;
// 		bp.ffRangeCtl.value = 0;
	}),
	12,
	gcAutoSynthCmd: (gc: BP(\drum1).wetCtl, name: \ctlPoint, outName: \outbus, 
		value: 0.078, time: 30, curve: 0),
	bpCmd: (name: \drum2, quant: `nil, prepareBP: { |bp|
		bp.bar = Pseq(#[0, 2], inf);
	}),
	12,

	bpCmd: (name: \drum3, quant: `nil, prepareBP: { |bp|
		bp.bar = Prand(#[8, 2], inf);
		bp.ffreqCtl.value = 60;
	}),
	mixerAutoSynthCmd: (mixer: BP(\drum3).chan, name: \ctlEnv, outName: \outbus,
		connect: 0, env: Env(#[0, 0.75], #[18], 2.4)),
	gcAutoSynthCmd: (gc: BP(\drum3).ffreqCtl, name: \ctlPoint, outName: \outbus, 
		value: 18000, time: 30, curve: 5),

	{	BP(\drum1).bar = Pseq([3, Prand(BP(\drum1).indices[1], 1)], inf);
		12
	},
	{	BP(\drum2).bar = Prand(BP(\drum2).indices[1], inf);
		12
	},

	{	BP(\drum2).bar = Prand(#[1, 2, 3], inf);
		12
	},

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
		24
	},

	{ BP(#[drum1, drum2, drum3]).stop; 0 },
*/
	bpCmd: (name: #[drum4, drum5], quant: `nil, prepareBP: { |bp|
		var	panEnd = -1;
		bp.reset;
		if(bp.collIndex == \drum5) {
			bp.quant = #[-1, 0.02];
			panEnd = 1;
			bp.amp = Pseq(#[1, 3.7], inf) * Env(#[0, 1], #[12], 2.4)
		};
		bp.pan = Env([0, panEnd], #[30]);
	}),

	24,
	swap56cmd: (quant: #[-1, 0.25], extraPrep: { |bp| bp.amp = Pseq(#[1, 3.7], inf) }),
	24,
	swap56cmd: (quant: #[-1, 0.75], extraPrep: { |bp| bp.amp = Pseq(#[1, 3.7], inf) }),
	24,
	swap56cmd: (quant: #[-1, 1.25]),
	24,

 	funcCmd: (func: { ~iterator.stop })
//	{ BP.all.stop; 8 },
//	{ ~master.stopRecord; 0 }
]).play(argClock: ~clock108 ? TempoClock.default);
)

t.stop;

t.activeCmds

0.1 / ~clock108.tempo

u.do(_.remove);
u = #[drum5, drum6].collect { |k|
	Updater(BP(k), { |... args| [thisThread.beats, args].debug })
};

~clock108.clear

BP(#[drum4, drum5, drum6]).do(_.reset);
BP(\drum4).play(-1);
BP(\drum5).play([-1, 0.75]);


BP(#[drum4, drum5, drum6]).do(_.stopNow);