// reworking, changing focus away from steady footsteps

// c. 7min
// fix opening chord sound -- automate filter up, and bufmod
// st and stw: increase reverb before end
// fix timing on water chord fadeout
// lpc

SynthDescLib.global.browse;
Object.browse;

MIDIPort.init([2]);
MIDIPort.autoFreeSockets = false;

MT(1).gui;

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

~rvbmc => MCG(6);
~master => MCG(7);
MixingBoard.at(0).refresh;

~rvb.run(false);
~rvbmc.free;  // or, on netbook, dump rvb altogether
~rvbmc = nil;

// load footsteps
BP(\st).free;
PR(\steps1) => BP(\st);
//PR(\steps1).chuck(BP(\st), nil, (rvbmc: ~rvbmc));
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




// st process
/*
PR(\steps1) api requirements:
dur == nil, stop
dur is positive, numWalkers is 0, rest for dur
numWalkers == nil, stop
0 <= numWalkers < 1.0, treat as ratio of dur
numWalkers >= 1.0, treat as exact beats presyncop

gsel: call gSelector
if a gSelector uses ~gestureStream, it must put something in parms \numSyncop

oneWalkerPattern populates:
instrument
bufnum,
gesture,
i
rate
attack
start
lag
mode
chan
shapebuf
pan
--- post-gesture: time
*/

p = BP(\st);
p.printStopMsg = true;
p.gesture = \one;
p.gsel = \unison;

p.listVars;

p.gestures[\spray] = { |i, parms, delta|
	Pbind(
		\instrument, \bufGrainPanKlank,
		\delta, delta ?? { Pseg(
			Ppatlace([Pexprand(0.12, 0.25, inf), Pexprand(0.5, 0.75, inf)], inf, { 2.rand }),
			Pexprand(5.0, 12.0, inf),
			\exp
		) },
		\pan, Pseg(
			Pwhite(0.7, 1.0, inf) * Pseq(#[-1, 1], inf, { 2.rand }),
			Pexprand(0.25, 1.0, inf)
		),
		\amp, ~amp.(i, parms),
		\lpfreq, ~hiFilt,
		\filtAttack, BPStream(\klankAttack),
		\filtDecay, ~sprayDecay.(i, parms),
		\ffreq, Pseg(
			Pexprand(150, 900, inf),
			Pexprand(0.25, 1.0, inf),
			\exp
		),
		\chorusAmt, 0, //BPStream(\syncopChorusAmt),
		\chorusDelay, 0 //Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf)
	)
};

p.gestures[\sprayFtoS] = { |i, parms|
	~gestures[\spray].(i, parms, Env([rrand(0.12, 0.25), rrand(0.5, 0.75)], [parms[\dur]], \exp))
};

p.gestures[\sprayStoF] = { |i, parms|
	~gestures[\spray].(i, parms, Env([rrand(0.5, 0.75), rrand(0.12, 0.25)], [parms[\dur]], \exp))
};


p.play;

p.numWalkers = 2;
p.gesture = Pn(\spray, inf);
p.gsel = Pseq(#[unison, manySyncop], inf);
p.gesture = Pseq([\spray, Pfin(Pkey(\numSyncop).asStream, Prand(#[triplet4, someSyncops, running, halfSyncop, tripping, dot8], inf))], inf).trace(prefix: "gesture: ");

p.gestures.keys

p.sprayDecay = Pkey(\filtAttack) + Pseg(Pseq(#[0, 0.002, 0], inf), Pseq([Pfin(1, Pkey(\dur)), 0, 0], inf), 6);

p.sprayDecay = { |i, parms|
	Pkey(\filtAttack) + Env([0, 0.002], [parms[\dur]], 3).asStream
};

p.dur = Pwhite(8, 14, inf);
p.preSync = Pwhite(1, 2, inf);
p.numSyncop = 2;

// another config: rests - OK! need more gestural variety
p.dur = Ppatlace([Pexprand(5, 14, inf).round, Pwhite(1, 3, inf)], inf);
p.gesture = Pxrand(#[spray, sprayFtoS, sprayStoF], inf); //\spray;
p.gsel = \unison;
p.numWalkers = Pseq(#[1, 0], inf);
p.preSync = 0;



// recheck granular synth
// pvstretch for regular steps? (already used for water steps)
