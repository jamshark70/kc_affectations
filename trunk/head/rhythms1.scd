// head rhythms

SynthDescLib.global.browse;
Object.browse;
s.queryAllNodes;

MIDIPort.init([2]);
MIDIPort.autoFreeSockets = false;

MT(1).free;
MT(1).gui;

Library.put(\chucklib, \midiSearches, #["remote"]);
BP.loadGui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

(Document.current.path.dirname +/+ "head-defs.scd").loadPath;
topEnvironment[\dir] = Document.current.path.dirname.dirname +/+ "samples/feet";

m = MixerChannel(\test1, s, 1, 2);
n = MixerChannel(\test2, s, 2, 2);
m => MCG(0); n => MCG(1);

#[master, rvbmc, rvb].do(_.envirPut(nil));

VoicerProxy.new => VP.prNew(0);
8.do { VP(0).v.addControlProxy(nil, true) };
VP(0).v.gui;

//k = VoicerMIDISocket(0, VP(0).v);

{	var cc;
	8.do {
		cc = VoicerMIDIController(\omni, \knob);
		cc => CC.prNew(cc.ccnum.shortName.asSymbol);
	};
}.value;

8.do { |i| CC(("k" ++ i).asSymbol) => VP(0) };

~master ?? { ~master = MixerChannel(\master, s, 2, 2, level: 1) };

~rvbmc => MCG(6);
~master => MCG(7);
MixingBoard.at(0).refresh;

~rvb.run(false); ~rvbmc.mute;
~rvb.run(true); ~rvbmc.mute;



TempoClock.default.gui;
TempoClock.tempo = 108/60;

TempoClock.schedAbs(TempoClock.nextBar, { TempoClock.beatsPerBar = 3 });

PR(\bufPerc).v[\beatsPerBar].postcs

(
BP(\fours).free;
PR(\bufPerc).chuck(BP(\fours), nil, (
	bufPaths: "~/sounds/drums/Udu/*FING*".pathMatch,
	
	ampbase: #[0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0],
	removeMask: #[4, 7],
	amps: 0,
	pbindPreAction: {
		~amps = ~ampbase.copy;
		~removeMask.do { |i| ~amps[i] = 0 };
		~bufs = { ~buffers.size.rand } ! ~amps.count(_ > 0);
	}
));
)

(
BP(\threes).free;
PR(\bufPerc).chuck(BP(\threes), nil, (
	bufPaths: ["~/sounds/drums/Udu/uduSLAP1.wav".standardizePath],
	
	ampbase: #[1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0],
	removeMask: #[2, 6],
	amps: 0,
	pbindPreAction: {
		~amps = ~ampbase.copy;
		~removeMask.do { |i| ~amps[i] = 0 };
	}
));
)

BP(\threes).pbindPreAction = {
		~amps = ~ampbase.copy;
		~removeMask.do { |i| ~amps[i] = 0 };
// 		~bufs = { ~buffers.size.rand } ! ~amps.count(_ > 0);
	};
BP(\threes).bufs = #[0];

BP.all.do { |bp| bp.removeMask = bp.removeMask.copy; bp.removeMask.removeAt(0) };
BP(\fours).removeMask = nil;
BP(\threes).removeMask = nil;

BP(\threes).ampbase = BP(\threes).ampbase.copy.putEach(#[5, 11], #[0.4, 0.4]);


(
(keys: #[master, rvbmc],
copyKeys: #[buffers, chan, postMCCreation, calcBar, bar, amps],  // you can override this
sourceFreesMe: true,
bp: \t1,
make: { |name|
	var	parms = ~parms ?? { () }, upd;
	BP(name).free;
	~keys.do { |key| parms[key] ?? { parms.put(key, key.envirGet) } };
	~copyKeys.do { |key| parms[key] ?? { parms.put(key, BP(~bp)[key]) } };
	PR(\bufPerc).chuck(BP(name), nil, parms);
	// copies have to go away because they depend on the source's buffers, mixer etc.
	if(~sourceFreesMe ? true) {
		upd = Updater(BP(~bp), { |obj, what|
			if(what == \free) {
				upd.remove;
				BP(name).free;
			}
		});
	};
	BP(name)
}, type: \bp) => Fact(\copyBufPerc);
)

(
//var	zero = 0 ! 12;
BP(\t1).free;
PR(\bufPerc).chuck(BP(\t1), nil, (
	bufPaths: ["~/sounds/drums/Udu/uduSLAP1.wav".standardizePath],
// 	bases: [
// 		zero.copy.putEach(#[0, 8], #[1, 1]),
// 		zero.copy,
// 		zero.copy.put(8, 1)
// 	],
	baseIndices: #[0, 8],
	postMCCreation: {
		var	zero = 0 ! 12, temp;
		~pbindPreAction = Routine(~calcBar);
		~bases = { |i|
			temp = zero.copy;
			~baseIndices.size.do { |j|
				if((i bitAnd: (1 << j)) > 0) {
					temp.put(~baseIndices[j], 1)
				};
			};
			temp
		} ! (1 << ~baseIndices.size);
		~indices = { |num|
			~bases.collectIndices({ |array| array.count(_ > 0) == num });
		} ! (~baseIndices.size + 1)		
	},
	postBufferLoad: {
		// sibling processes may not init until I'm done
		NotificationCenter.notify(\t1, \ready);
	},
	amps: 0,
	bar: Pseq(#[0, 1], inf),
	calcBar: {
		var	bar = BPStream(\bar, resetSource: true).asStream,
			count = Pseries(0, 1, inf).asStream;
		"reset".debug(~collIndex);
		loop {
			~amps = ~bases[bar.next];
			~barHook.(count.next);
			0.yield;
		}
	}
));

NotificationCenter.registerOneShot(\t1, \ready, \ctor, {
	var	parms;

	Fact(\copyBufPerc).chuck(BP(\t2), nil, (
		parms: (
			baseIndices: #[2, 6],
			rates: #[1.25]
// 			bases: [
// 				zero.copy,
// 				zero.copy.put(6, 1),
// 				zero.copy.putEach(#[2, 6], 1)
// 			]
		)
	));

	parms = (
		bufPaths: "~/sounds/drums/Udu/*FING*".pathMatch,
		amps: 0,
		barHook: {
			~bufs = { ~buffers.size.rand } ! ~amps.count(_ > 0);
		},
		baseIndices: #[1, 4, 7, 10]
	);
	#[postMCCreation, calcBar].do { |key| parms.put(key, BP(\t1)[key]) };
	
	BP(\f1).free;
	PR(\bufPerc).chuck(BP(\f1), nil, parms);

/*
	Fact(\copyBufPerc).chuck(BP(\t2), nil, (
		parms: (
			bases: [
				zero.copy,
				zero.copy.put(6, 1)
			]
		)
	));

	Fact(\copyBufPerc).chuck(BP(\t2), nil, (
		parms: (
			bases: [
				zero.copy,
				zero.copy.put(6, 1)
			]
		)
	));
*/

	~num = BP.keys.size;
	BP.keys.asArray.sort.do { |key, i|
		BP(key).chuck(MT(1), 73 - ~num + i);
	};
});
)

BP(\t2).rates = #[1.25];

BP(\t1).bar = Pseq(#[3, 0], inf);
BP(\t2).bar = Pseq(#[0, 2], inf);

BP.all.do(_.alwaysReset = true)
BP.all.do({ |bp| bp[\reset] = { "reset func".debug(~collIndex); ~pbindPreAction.reset } });

BP.all.do(_.reset);

BP(\t2).bar = Prand(BP(\t2).indices[1], inf);
BP(\t1).bar = Pseq([3, Prand(BP(\t1).indices[1], 1)], inf);

BP(#[t1, t2]).do { |bp| bp.bar = Pseq(#[0, 2], inf) };

BP(\t1).bar = 0; BP(\t2).bar = 2;


(
var	zero = 0 ! 12,
parms = (
	bufPaths: "~/sounds/drums/Udu/*FING*".pathMatch,
	amps: 0,
	barHook: {
		~bufs = { ~buffers.size.rand } ! ~amps.count(_ > 0);
	},
	baseIndices: #[1, 4, 7, 10]
);
#[postMCCreation, calcBar].do { |key| parms.put(key, BP(\t1)[key]) };

BP(\f1).free;
PR(\bufPerc).chuck(BP(\f1), nil, parms);
)

BP(\f1).bar = Prand(#[8, 2], inf);
BP(\f1).bar = Prand([8, 2], inf) + Prand(#[0, 1, 4], inf);
BP(\f1).bar = Prand(BP(\f1).indices[1], inf);
BP(\f1).bar = Prand(BP(\f1).indices[2], inf);
BP(\f1).bar = Prand(BP(\f1).indices[3], inf);

BP(\f1).bases[[8, 2]]

BP(\t2).bar = Prand(BP(\t2).indices[1], inf);
BP(\t1).bar = Pseq([3, Prand(BP(\t1).indices[1], 1)], inf);

BP(\t1).bar = 3;
BP(\t2).bar = 3;
BP(\f1).bar = 15;
