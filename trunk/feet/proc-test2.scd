// building multi-process complexes

// c. 7min
// fix opening chord sound -- automate filter up, and bufmod
// st and stw: increase reverb before end
// fix timing on water chord fadeout
// lpc

SynthDescLib.global.browse;
Object.browse;

MIDIPort.init([2]);
MIDIPort.autoFreeSockets = false;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

VoicerProxy.new => VP.prNew(0);
4.do { VP(0).v.addControlProxy(nil, true) };
VP(0).v.gui;

k = VoicerMIDISocket(0, VP(0).v);

(
var cc;
8.do {
	cc = VoicerMIDIController(\omni, \knob);
	cc => CC.prNew(cc.ccnum.shortName.asSymbol);
};
);

4.do { |i| CC(("k" ++ i).asSymbol) => VP(0) };

(Document.current.path.dirname +/+ "feet-defs.scd").loadPath;
TempoClock.tempo = 110/60;

~master => MCG(7);
MixingBoard.at(0).refresh;

// load footsteps
BP(\st).free;
PR(\steps1) => BP(\st);
BP(\st).leadTime = 0.015 * (110/60);
#[1, -0.18, 0, true] => BP(\st);

BP(\st).gsel = \unison;
BP(\st).printStopMsg = false;

if(MCG.exists(1)) { BP(\st) => MCG(1) };

Error.debug = true;
Error.debug = false;

// BP(\st).klankDecay = BP(\st).klankDcyCtl.asPattern;
// BP(\st).klankDecay = 0.011;

/*
// try some counts
// steps, steps, rest, steps, steps, acc+steps, acc+steps, acc, acc
BP(\st).dur = Pseq(#[/*8, 32, 6,*/ 8, 5, 7, 4, 4, 4], 1);
BP(\st).numWalkers = Pseq(#[/*1, 2, 0,*/ 2, 3, 3, 3, 3, 3], 1);
// gestureStream is not called for a rest segment
BP(\st).gesture = Pclutch(Pseq(#[/*one, one, /*one,*/ */ one, one, accsteps, accsteps, accrest, accrest], 1), Ptime().differentiate > 0).trace(prefix: "gesture: ");
*/

// load chords

Fact(\slidePad) => VC(\sp);
if(MCG.exists(2)) { VC(\sp) => MCG(2) };

BP(\slch).free;
Fact(\slideChords) => BP(\slch);
BP(\slch) => VC(\sp);

VC(\bs).free;
Fact(\feetbass) => VC(\bs);
if(MCG.exists(3)) { VC(\bs) => MCG(3) };

Fact(\slideBass) => BP(\sb);

MIDIRecBuf(\ch2, [
	#[60, 74, 69,  62, 71, 72,  60, 69, 78, 79,  60, 62, 66, 67,  59, 64, 66, 69, 74],
	Pseq([Pn(1, Pseq(#[3, 3, 4, 4, 5], 1).asStream - 1), 2], 5).asStream.all,
	1, 0.5
].asNotes, (type: \ch, mode: \g, useOwnMode: true)) => MBM(0);

VC(\sp).v.gui;


// important to prevent cutting off the arpeg pattern too soon
Pn(#[2.5, inf], inf) =>.macro BP(\slch);
TempoClock.default.gui

BP(\slch).triggerOneEvent(0);
VC(\sp).v.trace;

BP(\slch).macro.postcs

t.isPlaying

Dialog.getPaths({ |p| p.postln });
~master.startRecord("/Users/dewdrop/SCServer/trax/kc/feet1.aiff");

(
var w;
~timer = DDWTimer.new;
w = Window.allWindows.detect { |w| w.name == "DDWTimer" };
if(w.notNil) { w.onClose = { topEnvironment[\timer] = nil } <> w.onClose };
)

// coordinate
(
var	hoptime = 60;

~chordDoneSignal = {
	~doneSignal = NotificationCenter.registerOneShot(
		BP(\slch).child, \childStop, currentEnvironment, e {
			~stop.();
		};
	)
};

t = TLSequenceIterator([
	funcCmd: (func: {
		BP(\st).klankDcyCtl.value = 0.011;
		BP(\st).accDecay = 0.011;
		BP(\st).gestureOne = \one;
		BP(\st).chan.level = 0.75;
		BP(\slch).child.fitFunc = \asis;
		BP(\slch).arpeg = \asis1;
		MBM(0)[\ch1] => BP(\slch);
		BP(\slch).child.makeChordPattern = { Pseq(~chords, inf) };
		BP(\slch).reset;
		topEnvironment[\timer] !? { topEnvironment[\timer].reset };
	}),
	Quant(1, -0.5),

	// `nil: we need the bpcmd to use BP(\st)'s quant instead of default NilTimeSpec
	bpCmd: (name: \st, quant: `nil, prepareBP: { |bp|
		bp.printStopMsg = false;
		bp.gsel = \unison;
		bp.dur = Pseq(#[8, 32], 1);
		bp.numWalkers = Pseq(#[1, 2], 1);
		bp.gesture = \one;
	}),
	\sync,
	3,
	bp1eventCmd: (name: \slch, doReset: true,
		shouldSync: true,
		// TEMPORARY until doReset behavior is fixed
		prepareBP: { |bp| bp.reset },
		setDoneSignal: ~chordDoneSignal
	),
	\sync,
	8,
	bpCmd: (name: \st, quant: `nil, prepareBP: { |bp|
		bp.dur = Pseq(#[8, 5, 7, 4, 4, 4], 1);
		bp.numWalkers = Pseq(#[2, 3, 3, 3, 3, 3], 1);
		bp.gesture = Pclutch(Pseq(#[one, one, accstepsUnpitched, accstepsUnpitched, accrestUnpitched, accrestUnpitched], 1), Ptime().differentiate > 0);
	}),
	\sync,
	1,

	bp1eventCmd: (name: \slch, shouldSync: true, setDoneSignal: ~chordDoneSignal),
	\sync,
	4,


// thinking of 'hop' gesture: all walkers hit a klank chord - combFreq for pitches
// ok... needs better pitch pattern
	bpCmd: (name: \st, quant: `nil, prepareBP: { |bp|
		bp.numWalkers = Pseq(#[3, 5], inf);
		bp.dur = Pconst(hoptime, Ppatlace([Pwhite(5, 19, inf), 1], inf));
		bp.gsel = Pseq([\one, \unison], inf);
		bp.gesture = \accsteps;
		bp.mode = \g;
		bp.combMel = (Paccumbounce(39, 50, Pwhite(-7, 7, inf).reject(_ == 0), start: rrand(39, 42)) +.x Pseries(0, Pwrand(#[-1, -2, -3, -4], #[2, 5, 4, 1].normalizeSum, inf), Pkey(\numWalkers).asStream)); //.trace(prefix: "combMel: ");
		bp.accDecay = Env(#[0.011, 0.025], [hoptime], 4);
	}),


	// chords;
	{	MBM(0)[\ch2] => BP(\slch);
		BP(\slch).arpeg = \smallInt1;
		// change to chordFitInt when bass plays
		BP(\slch).child.fitFunc = \chordRandInt;
		BP(\slch).child.makeChordPattern = {
			// mimics Pxrand, but with limited starting positions (0 or 1)
			Pindex(~chords, Pseries(2.rand, Pwhite(1, ~chords.size - 1, inf)))
		};
		BP(\slch).reset;
		0
	},
	[
		loopCmd: (cmds: [
			{ ~delay.next },
			bp1eventCmd: (name: \slch, quant: 1)
		], setDoneSignal: {	// cheating and using this for more init, not donesig
			~dur = rrand(80, 110).debug("pre-bass");
			~delay = Plimitsum(~dur - 8, Pwhite(18, 28, inf))
				.asStream;
		}),
		\sync,
		{	thisThread.clock.beats.debug("synced, starting bass");
			BP(\slch).child.fitFunc = \chordFitInt;
			0
		},
		bpCmd: (name: \sb, quant: 1),
		3,
		loopCmd: (doneSignal: true, cmds: [
			{	// conditional termination: when \sb is not playing,
				// the returned sequence item is 'nil' forcing the subiterator to stop
				if(BP(\sb).isPlaying) {
					PR(\bp1eventCmd).copy.putAll((name: \slch, quant: 1))
				}
			},
			// wait for exactly bass's total duration
			{ Library.at(BP(\sb).bassID).dur }
		])
	],

	// v. important to change dur pattern before it stops!
	// this will b/c the iterator runs a bit ahead of the pattern
	hoptime,

// some big klanks
// halfSyncop, add pitch slowly -- stay in g major at first
// a couple of cycles with more chaotic syncopations
// 2 syncops, 1 in g, other random

// interact with chord notes

	{	var	bp = BP(\st);
		"moving on".debug;
		bp.klankDcyCtl.value = 0.011;
		bp.accDecay = Env(#[0.025, 0.011], #[75]).asStream.trace(prefix: "accDecay: ");
		bp.gsel = Ppatlace([\unison, Pseq([Pn(\oneSyncop, 3), Pn(\manySyncop, inf)], 1)], inf);
		bp.numWalkers = Pstutter(2, Pseq([3, 3, 3, Pn(5, inf)], 1));
		// numSyncop doesn't get called when gsel is oneSyncop
		bp.numSyncop = 2; // Pseq(#[/*1, 1, 1,*/ 2, 2, 2], 2);
		bp.dur = Ppatlace([
			Pif(Pseries(0, 1, inf) < 3, 4, Env(#[4, 2], #[140]).asStream.roundUp),
//			4,
			// once we go to manySyncop, speed up the changes
			(Pwhite(12, 20, inf) * Pif(Pseries(0, 1, inf) < 3, 1, Env(#[1, 0.5], #[140]))).roundUp
// 			(Pwhite(0, 8, inf) + Pif(Pseries(0, 1, inf) < 3, 12, Env(#[12, 6], #[140]).asStream.roundUp.trace(prefix: "rand add: ")))
		], inf)/*.trace(prefix: "dur: ")*/;
			// >= 1 is number of beats
		bp.preSync = Pwhite(1, Pfunc { |dur| min(4, (dur * 0.3).roundUp.asInteger) }, inf)/*.trace(prefix: "presyncop: ")*/;
		bp.gesture = Pswitch1([
			\stepsacc, // \stepsaccUnpitched,
			Pseq([
				\halfSyncop, \halfSyncop, 
				\patRejectLastN.eval(Ppatlace([Prand(#[halfSyncop, dot8, triplet4], inf), Prand(#[halfSyncop, dot8, triplet4, running, tripping])], inf), 2)
			], 1)
			// 'which' arg of Pswitch1 generates syncop gestures according to numsycop
		], Pseq([0, Pn(1, Pkey(\numSyncop).asStream)], inf)); //.trace(prefix: "gesture: ");
		bp.mode = Pif(
			Pfunc { |ev| #[someSyncops, halfSyncop, dot8, triplet4, running, tripping].includes(ev[\gesture]) },
			Pseq([Pn(\g, 5), Ppatlace([\g, \patRejectLastN.eval(Pxrand(Mode.keys.asArray.reject(#[cmin, default, g, g0].includes(_)), inf), 5)], inf)], 1),
			\g
		)/*.trace(prefix: "mode: ")*/;
		0
	},
// TEMPORARY - in case I'm not using hop segment above
	bpCmd: (name: \st, quant: `nil, playWarning: false),
	24,
	{ "autosynth".debug; 0 },
	gcAutoSynthCmd: (gc: BP(\st).klankDcyCtl, name: \ctlPoint, outName: \outbus,
		value: 0.018, time: 48, curve: 5, stopAction: { "autosynth done".debug }
	),
	140,


// TEMPORARY - in case I'm not using hop segment above
	bpCmd: (name: \st, quant: `nil, playWarning: false),

	funcCmd: (func: {
		var	bp = BP(\st);
		"reset".debug;
		bp.gsel = \unison;
		bp.gesture = Pseq([\stepsacc, Pn(\allAcc, inf)]);
		bp.dur = Pseq(#[4, 3, 4, 5, 7, 10], 1);
		bp.v[\saveCombMel] ?? { bp.saveCombMel = bp.combMel };
		bp.combTop = Pseries(40, Pwrand(#[1, 2, 3], #[0.2, 0.35, 0.45], inf), inf);
		bp.combMel = Pn(Plazy { |in|
			var target = ~combTopStream.next(in),
				steps;
			if(in[\gesture] == \allAcc) {
				steps = ({ #[1, 2, 3].wchoose(#[0.2, 0.45, 0.35]) } ! (in[\dur] - 1));
			};
			steps = steps ++ #[0];
			Pseries(target - steps.sum, Pseq(steps), inf)
		}, inf)
			-.x Pseries(0, Pwrand(#[1, 2, 3], #[0.2, 0.45, 0.35], inf), Pkey(\numWalkers).asStream);
		bp.accDecay = Pclutch(Pseq([
			Pn(0.02, { |ev| ev[\dur] }),
			#[0.011, 0.06, 4.5].asSpec.map(Pn(Pseries(0, 1/6, { |ev| ev[\dur] }), 4)),
			Env(#[0.011, 0.32, 5], #[8, 0.99], #[7.5, 0])
		]), Pdiff(Ptime()) > 0);
		bp.numWalkers = 5;
		bp.resetq(bp.quant);  // this method subtracts 0.05 from sched time

		BP(\sb).stop(0);
	}, setDoneSignal: {
		~doneSignal = Updater(BP(\st), e { |obj, what, more|
			if(more == \stopped) { ~stop.() };
		})
	}, clearDoneSignal: {
		BP(\st).combMel = BP(\st).saveCombMel;
		~doneSignal.remove;
	}),
	\cmdSync,
	Quant(1, -0.5),
	3,

	bpCmd: (name: \st, quant: `nil, prepareBP: { |bp|
		bp.numWalkers = 3;
		bp.gsel = \one;
		bp.gestureOne = \one;
		bp.dur = 32;
		bp.reset;
	}),
	4,
	{ "addfx".debug;
		BP(\st).playfx;
		BP(\st).wetCtl.value = 0;
		BP(\st).threshCtl.value = 1;
		if(BP.exists(\brook).not) { Fact(\brook) => BP(\brook) };
		if(BP.exists(\stw).not) { Fact(\watersteps) => BP(\stw) };
		if(VC.exists(\wp).not) { Fact(\waterpad) => VC(\wp) };
		if(BP.exists(\wch).not) { Fact(\waterch) => BP(\wch) };
		BP(\wch) => VC(\wp);
		1 => BP(\wch);
		0
	},
	gcAutoSynthCmd: (gc: BP(\st).wetCtl, name: \ctlPoint, outName: \outbus,
		value: 1, time: 12, curve: 0 //, stopAction: { "autosynth done".debug }
	),
	6,
	gcAutoSynthCmd: (gc: BP(\st).threshCtl, name: \ctlPoint, outName: \outbus,
		value: 0.01, time: 14, curve: -5 //, stopAction: { "autosynth done".debug }
	),
	20,
	[	bpCmd: (name: \brook, quant: `nil, prepareBP: { |bp| bp.reset; bp.chan.level = 0 }),
		9,
		bpCmd: (name: \stw, quant: `nil, prepareBP: { |bp|
			bp.gsel = \one;
			bp.gestureOne = \one;
			bp.dur = 8;
			bp.preSync = Pwhite(0.3, 0.6, inf);
			/*bp.reset;*/ bp.chan.level = 0;
		}),
		\sync  // otherwise, iterator stops and thereby, prev bpcmd doesn't play
	],
	[	20,
		mixerAutoSynthCmd: (mixer: { BP(\st).chan }, name: \ctlPoint, outName: \outbus,
			value: 0, time: 35, curve: -2.1, stopAction: { BP(\st).stopNow })
	],
	[
	mixerAutoSynthCmd: (mixer: { BP(\brook).chan }, name: \ctlPoint, outName: \outbus,
		value: 0.75, time: 25, curve: 2.1),
	9,
	mixerAutoSynthCmd: (mixer: { BP(\stw).chan }, name: \ctlPoint, outName: \outbus,
		value: -12.dbamp, time: 25, curve: 2.1)
	],
	\cmdSync,	// wait until all the water bits are faded in
	Quant(1, -0.5),
	{	var	p = BP(\stw);
		"all there".debug;
		p.gsel = \unison;
		p.gesture = \somept5;
		p.dur = Pwhite(18, 30, inf);
		p.preSync = Pfunc { |dur| max(1, dur - rrand(5, 12)) };
		6
	},
	bpCmd: (name: \wch, quant: `nil, prepareBP: { |bp|
		bp.value.reset;
		bp.child.gatePat = Pseq([
			Pseries.fromEndpoints(0.1, 0.75, 6),
			Pn(Plazy { Pseries.fromEndpoints(rrand(0.05, 0.3), rrand(0.75, 1.0), rrand(5, 12)) })
		]);
		VC(\wp).env.playfx;
	}, resetBP: { VC(\wp).env.stopfx }),
	mixerAutoSynthCmd: (mixer: { VC(\wp).env.target }, name: \ctlEnv, outName: \outbus,
		connect: 0, env: Env(#[-40, -33].dbamp, #[24], 2.1)),
	mixerAutoSynthCmd: (mixer: { VC(\wp).env.combsMC }, name: \ctlEnv, outName: \outbus,
		connect: 0, env: Env(#[-inf, -25].dbamp, #[39], 2.1)),
	gcAutoSynthCmd: (gc: { VC(\wp).v.globalControls[\ffreq] }, name: \ctlEnv, outName: \outbus,
		connect: 0, env: Env(#[170, 1200, 400], #[60, 65], \exp)),
//	{ (105 * thisThread.clock.tempo).roundUp },
	{ (45 * thisThread.clock.tempo).roundUp },
	{	BP(\stw).gesture = \onept5stretch;
		(60 * thisThread.clock.tempo).roundUp
	},

//	bpCmd: (name: \stw, quant: `nil, playWarning: false),
	[	12,
		mixerAutoSynthCmd: (mixer: { BP(\brook).chan }, name: \ctlPoint, outName: \outbus,
			value: 0, time: 48, curve: -2.1, stopAction: { BP(\brook).stop }),
		mixerAutoSynthCmd: (mixer: { VC(\wp).env.target }, name: \ctlPoint, outName: \outbus,
			value: 0, time: 34, curve: -2.1),
		mixerAutoSynthCmd: (mixer: { VC(\wp).env.combsMC }, name: \ctlPoint, outName: \outbus,
			value: 0, time: 34, curve: -2.1),
		\cmdSync,
		{ BP(\wch).stop; 0 }
	],
	funcCmd: (func: {
		"bigstretch".debug;
		// collect here is a variant on 'once'
		// the first time, it will use the ~stop.() function below;
		// after that it's replaced by an inert 'return the argument' func
		BP(\stw).dur_((Pwhite(9, 15, 4) * Pgeom(1, 0.84, inf)).round.collect(e { |ev| ~doneSignal.(ev) }))
			.preSync_(Pfunc { |dur| dur } - Pwhile1({ |dur, next| next < dur }, Pseries(2, Prand(#[1, 2], inf), inf)))
			.gesture_(\stepsStretch).gsel_(\unison);
	}, setDoneSignal: {
		~doneSignal = e { |ev| ~doneSignal = { |ev| ev }; ~stop.(); ev };
	}),
	\cmdSync,	// this is so I know when bigstretch *really* started
	mixerAutoSynthCmd: (mixer: { BP(\stw).chan }, name: \ctlPoint, outName: \outbus,
		value: -4.dbamp, time: 14, curve: 2.1),
	funcCmd: (func: { nil },
		setDoneSignal: {
			~doneSignal = Updater(BP(\stw), e { |obj, what, more|
				if(more == \stopped) { ~stop.() };
			});
		}, clearDoneSignal: {
			~doneSignal.remove;
		}
	),
	\cmdSync,	// and this is so I know when stepsStretch ran out of parent events
		// I can't believe this actually worked!
	bpCmd: (name: \stw, quant: `nil, prepareBP: { |bp|
		bp.dur_(Pseries(3, Prand(#[1, 2, 3], 5))).preSync_(0);
	})
]).play;

// (r = r { thisThread.clock.beats.debug("in r"); t.play; nil }).play(quant: 1);
)

t.stop;

BP.all.stop

t.isPlaying;

VC(\wp).v.playingNodes.maxItem(_.frequency).trace
VC(\wp).v.nodes.choose.initArgs

BP.all.free; VC.all.free;

BP(\st).klankDcyCtl.value

BP(\st).chan.inbus
SynthDescLib.at(\waterfx).makeGui;
s.queryAllNodes;
s.sendMsg(\g_head, BP(\st).chan.effectgroup.nodeID, 1520);
Help.gui;

s.sendMsg(\n_free, 1917);

BP(\st).dur = BP(\st).dur.trace(prefix: "dur: ");

~master.levelTo(0, 25, \amp);
~master.stopRecord;

t.play;
t.activeCmds

Env(#[0.011, 0.018], #[25], 7).plot

NotificationCenter.registrationsFor(BP(\slch).child)
t.isPlaying

BP(\st).klankDcyCtl.gui

BP(\st).syncopInstr = Pif(Pfunc { |ev|
	(thisThread.clock.beats + ~leadTime - ~quant.phase % 1)/*).debug("test time")*/ > 0
}, \bufGrainPanKlank, Pfunc { ~def });


VC(\sp).v.globalControls[\bufmod].spec

VC(\sp).v.globalControls[\bufmod].automate({
	SinOsc.kr(SinOsc.kr(0.012847362, -0.5pi).exprange(0.01, 0.12), -0.5pi).range(0.0, 6.998);
});

VC(\sp).v.globalControls[\bufmod].watch;
VC(\sp).v.globalControls[\bufmod].autoSynth.trace

VC(\sp).v.globalControls[\bufmod].stopAuto;
VC(\sp).v.globalControls[\bufmod].stopWatching;

VoicerGlobalControl.browse

BP(\slch).triggerOneEvent(0);

BP(\slch).child.chords.collect(_.mode)
BP(\slch).child.chords.collect(_.useOwnMode)
BP(\slch).child.chords.do { |ch| ch.notes.asFloat.postln }; ""
BP(\slch).topNote.listVars
BP(\slch).topNote.deg.postcs
