// head rhythms

SynthDescLib.global.browse;
Object.browse;
s.queryAllNodes;

MIDIPort.init([2]);
MIDIPort.autoFreeSockets = false;

MT(1).free;
MT(1).gui;

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
TempoClock.sched(TempoClock.timeToNextBeat(4), { TempoClock.beatsPerBar = 3 });

TempoClock.schedAbs(TempoClock.nextBar.trunc, { TempoClock.beatsPerBar = 3 });

TempoClock.baseBarBeat
TempoClock.default.dump

TempoClock.default.dumpQueue

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
	bufPaths: "~/sounds/drums/Udu/*SLAP*".pathMatch,
	
	ampbase: #[1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0],
	removeMask: #[2, 6],
	amps: 0,
	pbindPreAction: {
		~amps = ~ampbase.copy;
		~removeMask.do { |i| ~amps[i] = 0 };
		~bufs = { ~buffers.size.rand } ! ~amps.count(_ > 0);
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