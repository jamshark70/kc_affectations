// reworking, changing focus away from steady footsteps

// c. 7min
// fix opening chord sound -- automate filter up, and bufmod
// st and stw: increase reverb before end
// fix timing on water chord fadeout
// lpc

SynthDescLib.global.browse;
Object.browse;
s.queryAllNodes;

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

~rvb.run(false); ~rvbmc.mute;
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
b = BP(\st).buf;

c.free;
f = 2048;
c = Buffer.alloc(s, b.duration.calcPVRecSize(f, 0.25));

a = {
	var	sig = PlayBuf.ar(1, b, BufRateScale.kr(b), 1, 0, 0),
		fft = FFT(LocalBuf(f, 1), sig, 0.25, 1),
		stop = Line.kr(0, 1, b.duration, doneAction: 2);
	PV_RecordBuf(fft, c, run: 1, hop: 0.25, wintype: 1);
	stop.poll(Done.kr(stop), "over");
	Silent.ar(1)
}.play;

SynthDef(\pvplayStereoPos, { |outbus, pvbuf, time = 1, rate = 1, amp = 1, pan,
	stretch = 1, shift = 0,
	attack = 0.01, decay = 0.05|
	var	posEnv = \posEnv.kr(Env(#[0, 1], #[1]).asArray.extend(24, 0)),
		point = EnvGen.kr(posEnv, timeScale: time),
		frSize = Index.kr(pvbuf, 0),
		even = PV_BufRd(LocalBuf(frSize, 1), pvbuf, point),
		odd = PV_Copy(even, LocalBuf(frSize, 1)),
		sig;
	odd = PV_BinShift(odd, stretch, shift);
//	even = PV_BinShift(even, stretch, shift);
 	even = PV_Add(even, odd);
 	odd = PV_Copy(even, odd);
	even = PV_EvenBin(even <! odd);
	odd = PV_OddBin(odd);
	sig = IFFT([even, odd], 1)
		* EnvGen.kr(Env.linen(attack, time - attack - decay, decay), doneAction: 2);
	Out.ar(outbus, Balance2.ar(sig[0], sig[1], pan, amp));
}).add;


c.get(0, { |fr| ~fr = ((c.numFrames - 3) / fr).debug("pv frames") });
~fr

q = p.pt.choose;
r = 0.1;
a = n.play(\pvplayPan, [pvbuf: c, startFrame: q.next / b.duration * ~fr, rate: r, time: 1/r/*, frameSize: f*/]);
a.free

a.trace

q = Pn(Pshuf(p.pt, 1), inf).asStream;
z = 3;
a = n.play((instrument: \pvplayStereo, pvbuf: c, startFrame: ({ q.next } ! z) / b.duration * ~fr, rate: r, time: 1/r, amp: 1, pan: 0.5 * (-1.0, (z-1).reciprocal * 2 - 1 .. 1.0)));

a[\id].do(s.sendMsg(\n_free, _));
a[\id].do(s.sendMsg(\n_trace, _));

n = MCG(1).v.mixer;

q = q.next;

e = {
	var	pt = q.next;
	Env((pt + #[0, 0.05, 0.1]) / b.duration, #[0.25, 0.75], \sin)
};

r = 0.1;
z = 1;

a = n.play((instrument: \pvplayStereoPos, pvbuf: c, rate: r, time: 1/r, amp: 1, posEnv: { e.value } ! z, pan: if(z > 1) { 0.5 * (-1.0, (z-1).reciprocal * 2 - 1 .. 1.0) } { 0 }, stretch: 0.75, shift: 16));

fork({
a = n.play((instrument: \pvplayStereoPos, pvbuf: c, rate: r, time: 1/r, amp: 1, posEnv: { e.value } ! z, pan: if(z > 1) { 0.5 * (-1.0, (z-1).reciprocal * 2 - 1 .. 1.0) } { 0 }, stretch: 1, shift: -20));
s.sendBundle(s.latency + (2049/44100), [\n_trace, a[\id][0]]);
}, SystemClock);

a = (instrument: \pvplayStereoPos, pvbuf: c, rate: r, time: 1/r, amp: 1, posEnv: { e.value } ! z, pan: if(z > 1) { 0.5 * (-1.0, (z-1).reciprocal * 2 - 1 .. 1.0) } { 0 }, stretch: 1, shift: 20).asOSC[0][1].put(2, s.nextNodeID);

s.listSendBundle(nil, [a, [\n_trace, a[2]]].postcs);


s.makeBundle(s.latency + (3084/44100), { a[\id].do(s.sendMsg(\n_trace, _)) });

a[\id].do(s.sendMsg(\n_free, _));
a[\id].do(s.sendMsg(\n_trace, _));


// try some convolution w/vox -- not bad, too obviously voxy - need other IRs
// get brookfx from lpcplay
Fact(\brook) => BP(\brook);
Fact(\brookfx) => BP(\brookfx);

~pt = BP(\brookfx).pt;
~irbufs = List.new;
~vbuf = Buffer.readAndQuery(s, BP(\brookfx).dir +/+ "words-mono.aiff");

(
fork {
	var	tempbuf, frames, irbuf;
	~pt.do { |pt, i|
pt.debug;
		frames = ((pt[1] - pt[0]) * ~vbuf.sampleRate).asInteger;
		tempbuf = Buffer.alloc(s, frames, 1, { |buf| ~vbuf.copyMsg(buf, dstStartAt: 0, srcStartAt: (pt[0] * ~vbuf.sampleRate).asInteger) });
		irbuf = Buffer.alloc(s, PartConv.calcBufSize(2048, tempbuf));
		~irbufs.add(irbuf);
		s.sync;
		irbuf.preparePartConv(tempbuf, 2048);
		s.sync;
		tempbuf.free;
		s.sync;
	};
}
)

// not bad for cpu, c. 5%
SynthDef(\partConv, { |start, time, bufnum, rate = 1, amp = 1, irbuf,
		attack = 0.001, decay = 0.02, outbus|
	var sig;
	sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
		* EnvGen.kr(Env.linen(attack, time, decay));
	sig = PartConv.ar(sig, 2048, irbuf);
	DetectSilence.ar(sig, 0.001, doneAction: 2);
	Out.ar(outbus, sig * amp);
}).add;

a = m.play((instrument: \partConv, start: p.pt.choose, time: 0.2, amp: 1, irbuf: ~irbufs.choose, bufnum: p.buf));

// WAY FRICKEN LOUD!!
a = m.play((instrument: \partConv, start: 0, time: p.buf.duration, amp: 1, irbuf: ~irbufs.choose, bufnum: p.buf));