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

m = MixerChannel(\test1, s, 1, 2);
n = MixerChannel(\test2, s, 2, 2);
m => MCG(0); n => MCG(1);

#[master, rvbmc, rvb].do(_.envirPut(nil));

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
~rvb.run(true); ~rvbmc.mute;


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
		\chorusDelay, 0, //Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf)
		\chorusAmps, [0 ! 3]
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
p.gesture = Pxrand(#[spray, sprayFtoS, sprayStoF, blipup], inf); //\spray;
p.gsel = \unison;
p.numWalkers = Pseq(#[3, 0], inf);
p.preSync = 0;


// blip up, blip down gestures
p.gestures[\blipup] = { |i, parms|
	var	numEv = rrand(8, 15);
	Pbind(
		\root, Plazy { |ev| Pn(rrand(28, 37).unmapMode(ev[\mode]).midicps) },
//		\ffreq, Pkey(\root) * Pn(Pseries(1, rrand(2, 5).reciprocal, rrand(5, 9))),
		\ffreq, Pkey(\root) * Pseries(1, rrand(2, 5).reciprocal, numEv),
		\filtDecay, Pkey(\filtAttack) + 0.05,
		\delta, (parms[\dur] - rrand(1, 3)) / numEv
	) <> ~gestures[\spray].(i, parms);
};

p.dur = Pwhite(5, 9, inf);

p.numWalkers = 5;
p.gesture = \blipup;
p.gesture = \spray;

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]); r.remove; }).add;


// recheck granular synth
// pvstretch for regular steps? (already used for water steps)
b = BP(\st).buf;

c.free;
f = 512;
c = Buffer.alloc(s, b.duration.calcPVRecSize(f, 0.25));

a = {
	var	sig = PlayBuf.ar(1, b, BufRateScale.kr(b), 1, 0, 0),
		fft = FFT(LocalBuf(f, 1), sig, 0.25, 1),
		stop = Line.kr(0, 1, b.duration, doneAction: 2);
	PV_RecordBuf(fft, c, run: 1, hop: 0.25, wintype: 1);
	stop.poll(Done.kr(stop), "over");
	Silent.ar(1)
}.play;

a.trace;

(
SynthDef(\pvplayStereoPos, { |outbus, pvbuf, time = 1, rate = 1, amp = 1, pan,
//	stretch = 1, shift = 0,
	shiftS, shiftE,
	attack = 0.01, decay = 0.05|
	var	posEnv = \posEnv.kr(Env(#[0, 1], #[1]).asArray.extend(24, 0)),
		point = EnvGen.kr(posEnv, timeScale: time),
		frSize = Index.kr(pvbuf, 0),
		even = PV_BufRd(LocalBuf(frSize, 1), pvbuf, point),
		odd = PV_Copy(even, LocalBuf(frSize, 1)),
		sig;
// 	even = PV_RectComb(even, 12,
// 		LFSaw.kr(0.02, 1.5, 0.5, 0.5),
// 		SinOsc.kr(1.23213).range(0.1, 0.9)
// 	);
//	even = PV_BinShift(even, 1, Line.kr(shiftS, shiftE, time));
// 	odd = PV_BinShift(odd, 1, Line.kr(shiftS, shiftE, time));
// 	odd = PV_RandComb(odd, Line.kr(0, Rand(0.5, 0.8), time));
// 	even = PV_Add(even, odd);
// 	odd = PV_Copy(even, odd);
	even = PV_EvenBin(even <! odd);
	odd = PV_OddBin(odd);
	sig = IFFT([even, odd], 1)
		* EnvGen.kr(Env.linen(attack, time - attack - decay, decay), doneAction: 2);
	Out.ar(outbus, Balance2.ar(sig[0], sig[1], pan, amp));
}).add;
)


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

e = { |q| Env((q + #[0, 0.5]) / b.duration, #[1]) };

e = { |pt| Env((pt + #[0, 0.1, 0.5]) / b.duration, #[0.25, 0.75], \lin) };

r = 0.1;
z = 1;

a = n.play((instrument: \pvplayStereoPos, pvbuf: c, rate: r, time: 1/r, amp: 1, posEnv: { e.value(q.next) } ! z, pan: if(z > 1) { 0.5 * (-1.0, (z-1).reciprocal * 2 - 1 .. 1.0) } { 0 }, stretch: 0.75, shift: 16));
a[\id].do(s.sendMsg(\n_trace, _));

z = 5;
a = n.play((instrument: \pvplayStereoPos, pvbuf: c, rate: r, time: 1/r, decay: 4, amp: 1, posEnv: { e.value(q.next) } ! z, pan: if(z > 1) { 0.5 * (-1.0, (z-1).reciprocal * 2 - 1 .. 1.0) } { 0 }, shiftS: 0, shiftE: { rrand(8, 15) } ! z));

~master.startRecord(thisProcess.platform.recordingsDir +/+ "feet-demos.aiff");

// this actually is pretty fricken cool
a = n.play(Pbind(
	\instrument, \pvplayStereoPos,
	\pvbuf, c,
	\rate, Pgeom.fromEndpoints(1, 0.11, 8),
	\time, Pkey(\rate).reciprocal,
	\decay, Pkey(\time) * 0.14,
	\amp, 1,
	\n, 3,
	\pt, Pn(Pshuf(p.pt, 1), inf).clump(Pkey(\n)),
	\posEnv, Pfunc { |ev| ev[\pt].collect { |pt| e.value(pt) } },
	\pan, Pif(Pkey(\n) > 1, Pn(Plazy { |ev| Pseries.fromEndpoints(-0.5, 0.5, ev[\n]) }), 0),
	\shiftS, -5,
	\shiftE, Pwhite(4, 30, inf).clump(Pkey(\n)),
	\delta, Pkey(\time) * Ptempo() * Pwhite(0.75, 0.9, inf)
));

n.play(a.next(()));

a.stop
n.stopRecord;
~master.stopRecord;

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


c.free;
c = Buffer.alloc(s, 512, 1, { |buf| buf.setnMsg(0, Env.perc(0.1, 0.9).discretize(buf.numFrames)) });
c.plot;

Signal.hanningWindow(512).plot;
z = Pgeom.fromEndpoints(0.001, 1, 512).asStream.all;
z.plot;
c.setn(0, z);
c.setn(0, Signal.hanningWindow(1024)[ .. 511]);

// can be a LOT of low-freq audio
g = GenericGlobalControl(\blend, nil, 1);
g.gui;

// steady (blend == 1) needs work: just a buzz now (even w/ hanning window)
a = n.play({ |blend = 1, z = 0.008|
	var	blendf = { |blend, a, b| a + (blend * (b - a)) },
			// Dust outputs 0 < y <= 1; I want flat levels
		trig = blendf.(blend, Dust.kr(18) > 0, Impulse.kr(70)),
		pt = p.pt.choose.debug("pt"),
		// often I'd divide rate by bufdur, but 0.004 is already normalized
		zneg = z.neg,
		fwdpt = Phasor.kr(0, (z*2) / 5 * ControlDur.ir, zneg, z, zneg) * b.duration,
		randpt = TRand.kr(zneg, z, trig) * b.duration,
		blended = blendf.(blend, randpt, fwdpt),
		bufPt01 = pt + blended,
		rate = TExpRand.kr(0.5, 6, trig),
		rateBlend = blendf.(blend, rate, TExpRand.kr(0.98, 0.98.reciprocal, trig)),
		dur = SinOsc.kr(0.05).exprange(0.08, 0.5),
		pan = blendf.(blend, TRand.kr(-1.0, 1.0, trig), 0);
//	GrainBuf.ar(2, trig, dur, b, rateBlend, bufPt01, 2, pan, c)
	TGrains3.ar(2, trig, b, rateBlend, bufPt01, dur, pan, amp: trig, att: 0.5 * dur, dec: 0.5 * dur, window: w, interp: 2)
}, [blend: g]);

a.trace;

a.free;

~mc = BasicMIDIControl(0, \knob, { |val, div| g.value = val / div });

c.get(0, { |fs| ((c.numFrames - 3) / fs).postln });
6988.reciprocal
0.004 * b.duration

(
a = n.play({ |z = 0.008, blend = 0, moveRate = 1, slowBufDur = 0.1|
	var	blendf = { |blend, a, b| a + (blend * (b - a)) },
		pvbuf = c,
		framesize = Index.kr(pvbuf, 0),
		fftrig = FFTTrigger(LocalBuf(framesize, 1), /*0.25*/ Index.kr(pvbuf, 1)),
		fft2,
		alltrigs = fftrig >= 0,
		trigcoin = TRand.kr(0.0, 1.0, alltrigs) < 0.05,
		trig = alltrigs * trigcoin,
		zneg = z.neg,
//		rise = Phasor.kr(trig, (z*2) / 5 * ControlDur.ir, zneg, z, zneg),
		fastRise = Phasor.kr(trig, ControlDur.ir / b.duration, 0, 1, 0),
		slowRise = Phasor.kr(0, moveRate * ControlDur.ir, 0, slowBufDur, 0) / b.duration,
		rise = blendf.(blend, fastRise + TRand.kr(z, zneg, trig), slowRise),
		pt = 5.09152 /*p.pt.choose*/ / b.duration,
		pos = pt + rise,
		shift = TIRand.kr(-8, 12, alltrigs) * LinExp.kr(blend, 0, 1, 1, 0.001);

	fftrig = PV_BinBufRd(fftrig, pvbuf, pos, numBins: 512, clear: 1);
	fftrig = PV_BinShift(fftrig, 1, shift);
	fft2 = PV_Copy(fftrig, LocalBuf(framesize, 1));
	fftrig = PV_EvenBin(fftrig <! fft2);
	fft2 = PV_OddBin(fft2);
	IFFT([fftrig, fft2])
}, [blend: g, moveRate: h]);
)

a.set(\moveRate, 0.025).set(\slowBufDur, 0.1);

h = GenericGlobalControl(\moveR, nil, 0.025, #[0.025, 10.0, \exp]); h.gui;
h.automate({ SinOsc.kr(0.01, -0.5pi).exprange(0.025, 3.0) });
h.watch;

h.stopAuto;
h.stopWatching;

a.trace;
a.free;

// ^^ rvb send level c. 0.132
n.postSettings

w.free;
w = Buffer.alloc(s, 512, 1, { |buf| buf.setnMsg(0, Signal.hanningWindow(1024)[..511]) });
w.plot;

// steady (blend == 1) needs work: just a buzz now (even w/ hanning window)
a = n.play({
	var	trig = Dust.kr(8) > 0,
		pt = p.pt.choose,
		// often I'd divide rate by bufdur, but 0.004 is already normalized
		fwdpt = 0, // Phasor.kr(0, 0.004 / 5 * ControlDur.ir, -0.002, 0.002, -0.002) * b.duration,
		randpt = TRand.kr(-0.002, 0.002, trig) * b.duration,
		bufPt01 = pt + fwdpt + randpt,
		rate = TExpRand.kr(0.5, 6, trig),
		dur = SinOsc.kr(0.05).exprange(0.08, 0.5);
	TGrains3.ar(2, trig, b, rate, bufPt01, dur, 0, amp: trig, att: 0.1 * dur, dec: 0.9 * dur, window: w, interp: 2)
});

a.free;

// steady (blend == 1) needs work: just a buzz now (even w/ hanning window)
a = n.play({
	var	trig = Impulse.kr(50),
		pt = p.pt.choose,
		// often I'd divide rate by bufdur, but 0.004 is already normalized
		fwdpt = Phasor.kr(0, 0.004 / 5 * ControlDur.ir, -0.002, 0.002, -0.002) * b.duration,
		randpt = 0, // TRand.kr(-0.002, 0.002, trig) * b.duration,
		bufPt01 = pt + fwdpt + randpt,
		rate = TExpRand.kr(0.5, 6, trig),
		dur = SinOsc.kr(0.05).exprange(0.08, 0.5);
	TGrains3.ar(2, trig, b, rate, bufPt01, dur, 0, amp: trig, att: 0.1 * dur, dec: 0.9 * dur, window: w, interp: 2)
});

a.free;


a = n.play({ |blend = 1, z = 0.008|
	var	blendf = { |blend, a, b| a + (blend * (b - a)) },
			// Dust outputs 0 < y <= 1; I want flat levels
		trig = blendf.(blend, Dust.kr(18) > 0, Impulse.kr(70)),
		pt = p.pt.choose.debug("pt"),
		// often I'd divide rate by bufdur, but 0.004 is already normalized
		zneg = z.neg,
		fwdpt = Phasor.kr(0, (z*2) / 5 * ControlDur.ir, zneg, z, zneg) * b.duration,
		randpt = TRand.kr(zneg, z, trig) * b.duration,
		blended = blendf.(blend, randpt, fwdpt),
		bufPt01 = pt + blended,
		rate = TExpRand.kr(0.5, 6, trig),
		rateBlend = blendf.(blend, rate, TExpRand.kr(0.98, 0.98.reciprocal, trig)),
		dur = SinOsc.kr(0.05).exprange(0.08, 0.5),
		pan = blendf.(blend, TRand.kr(-1.0, 1.0, trig), 0);
//	GrainBuf.ar(2, trig, dur, b, rateBlend, bufPt01, 2, pan, c)
	TGrains3.ar(2, trig, b, rateBlend, bufPt01, dur, pan, amp: trig, att: 0.5 * dur, dec: 0.5 * dur, window: w, interp: 2)
}, [blend: g]);

0.008 * b.duration


SynthDef(\pvdisintegrate, { |outbus, audiobuf, pvbuf, blend, ptSec, fastTrigProb = 0.05, ptRandSec = 0.15, moveRate = 1, slowBufDur = 1, shiftL = -8, shiftR = 12, attack = 0.1, decay = 0.1, gate = 1, amp = 1|
	var	blendf = { |blend, a, b| a + (blend * (b - a)) },
		bufdur = BufDur.ir(audiobuf),
		framesize = Index.kr(pvbuf, 0),
		hop = Index.kr(pvbuf, 1),
		cdur = ControlDur.ir,
		fftrig = FFTTrigger(LocalBuf(framesize, 1), hop),
		fft2,
		alltrigs = fftrig >= 0,
		trigcoin = TRand.kr(0.0, 1.0, alltrigs) < fastTrigProb,
		trig = alltrigs * trigcoin,
		z = ptRandSec / bufdur, zneg = z.neg,
		fastRise = Phasor.kr(trig, cdur / bufdur, 0, 1, 0),
		slowRise = Phasor.kr(0, moveRate * cdur, 0, slowBufDur, 0) / bufdur,
		rise = blendf.(blend, fastRise + TRand.kr(z, zneg, trig), slowRise),
		pt = ptSec / bufdur,
		pos = pt + rise,
		shift = TIRand.kr(shiftL, shiftR, alltrigs) * LinExp.kr(blend, 0, 1, 1, 0.01),
		eg = EnvGen.kr(Env.asr(attack, 1, decay), gate, doneAction: 2);

	fftrig = PV_BinBufRd(fftrig, pvbuf, pos, numBins: framesize, clear: 1);
	fftrig = PV_BinShift(fftrig, 1, shift);
	fft2 = PV_Copy(fftrig, LocalBuf(framesize, 1));
	fftrig = PV_EvenBin(fftrig <! fft2);
	fft2 = PV_OddBin(fft2);
	Out.ar(outbus, IFFT([fftrig, fft2]) * eg * amp)
}).add;

// client drives randomized trigs - note here, client should calculate shift amount - no auto blending
SynthDef(\t_pvdisintegrate, { |outbus, audiobuf, pvbuf, blend, ptSec, t_fasttrig = 1, ptRandSec = 0.15, moveRate = 1, slowBufDur = 1, shift = 0, attack = 0.1, decay = 0.1, gate = 1, amp = 1|
	var	blendf = { |blend, a, b| a + (blend * (b - a)) },
		bufdur = BufDur.ir(audiobuf),
		framesize = Index.kr(pvbuf, 0),
		hop = Index.kr(pvbuf, 1),
		frameTime = framesize * hop / SampleRate.ir,
		cdur = ControlDur.ir,
		fftrig = FFTTrigger(LocalBuf(framesize, 1), hop),
		fft2,
		alltrigs = fftrig >= 0,
		trigmask = Trig1.kr(t_fasttrig, frameTime - cdur),
		trig = alltrigs * trigmask,
		z = ptRandSec / bufdur, zneg = z.neg,
		fastRise = Phasor.kr(trig, cdur / bufdur, 0, 1, 0),
		slowRise = Phasor.kr(0, moveRate * cdur, 0, slowBufDur, 0) / bufdur,
		rise = blendf.(blend, fastRise + TRand.kr(z, zneg, trig), slowRise),
		pt = ptSec / bufdur,
		pos = pt + rise,
		eg = EnvGen.kr(Env.asr(attack, 1, decay), gate, doneAction: 2);

	fftrig = PV_BinBufRd(fftrig, pvbuf, pos, numBins: framesize, clear: 1);
	fftrig = PV_BinShift(fftrig, 1, shift);
	fft2 = PV_Copy(fftrig, LocalBuf(framesize, 1));
	fftrig = PV_EvenBin(fftrig <! fft2);
	fft2 = PV_OddBin(fft2);
	Out.ar(outbus, IFFT([fftrig, fft2]) * eg * amp)
}).add;



// buzz --> separate steps
g = GenericGlobalControl(\tfreq, nil, 20, #[5, 200, \exp]); g.gui;
g.spec = #[0.5, 150, \exp];

// steady (blend == 1) needs work: just a buzz now (even w/ hanning window)
a = n.play({ |tfreq = 50|
	var	trig = Impulse.ar(tfreq),
		pt = p.pt.choose.debug,
		// often I'd divide rate by bufdur, but 0.004 is already normalized
		fwdpt = 0, //Phasor.ar(0, 0.01 * SampleDur.ir, 0, 0.5, 0) * b.duration,
//		randpt = 0, //TRand.kr(-0.002, 0.002, trig) * b.duration,
		randpt = SinOsc.ar(0.1, 0, 0.01),
		bufPt01 = pt + fwdpt + randpt,
		rate = 1, //TExpRand.kr(0.5, 6, trig),
		dur = (tfreq.reciprocal * 10).clip(0.1, 0.4);
	TGrains.ar(2, trig, b, rate, bufPt01, dur, 0, amp: trig, interp: 2)
}, [tfreq: g]);

a.trace;
a.free;

WrapInstr("grain.tone", { |bufnum, tfreq = 50, pt = 0, lfospd = 0.1, lfoamt = 0.01, rate = 1, durMul = 10|
	var	trig = Impulse.ar(tfreq),
		// often I'd divide rate by bufdur, but 0.004 is already normalized
		lfo = SinOsc.ar(lfospd, 0, lfoamt),
		bufPt01 = pt + lfo,
		dur = (tfreq.reciprocal * durMul).clip(0.1, 0.4);
	TGrains.ar(2, trig, bufnum, rate, bufPt01, dur, 0, amp: trig, interp: 2)
}, [\mybuf, #[0.5, 300, \exp], #[0, 20], #[0.01, 10, \exp], #[0.001, 0.1, \exp], #[0.25, 4, \exp], #[1, 20, \exp]]);

WrapInstr("grain.tone").listArgs

a = n.play(WrapInstr("grain.tone"), [b, nil, p.pt.choose]); a.gui;
z = n.playfx(Instr("busfx.chorus"),  [0, 2]); z.gui;


WrapPatch(
	[ 'grain', 'tone' ], [ Buffer.new, 79.129751054297, 14.303334, 0.74989420933246, 0.01564748046212, 1.0, 10.0 ]
)

FxPatch(
	[ 'busfx', 'chorus' ], [ 18, 2, 0.0084255985991258, 0.40842391509327, 0.005573957308325, 1.8325956521762, 0.5 ]
)



// steps chords
p.gestures[\blox] = { |i, parms|
	// must not have more than one walker
	if(i == 0) {
		Pbind(
			\instrument, \bufGrainPanKlank,
			\pan, Pwhite(-1.0, 1.0, inf),
			\amp, ~amp.(i, parms),
			\n, Pwhite(3, 6, inf),
			\mnotes, Pscratch(
				Pvbrown(39, 50, Pwhite(1, 3, inf), inf) -.x Pclump(Pkey(\n), Pseries(0, Pwrand(#[1, 2, 3], #[0.1, 0.45, 0.45], inf), Pkey(\n).asStream)),
				Pwrand(#[-1, 0, 1], #[0.1, 0.5, 0.4], inf),
				memorySize: 30
			),
			\ffreq, Pfunc { |ev| ev[\mnotes].unmapMode(ev[\mode]).midicps },
			\filtAttack, BPStream(\klankAttack),
			\filtDecay, Pkey(\filtAttack) + 0.05,
			\chorusAmt, 0, //BPStream(\syncopChorusAmt),
			\chorusDelay, 0, //Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf)
			\chorusAmps, [0 ! 3],
			\lpfreq, ~hiFilt,
			\delta, Pstutter(Pwhite(3, 10, inf), Pwhite(2, 4, inf).reciprocal)
		)
	} {
		Event.silent(parms[\dur])
	}
};

p.gesture = \blox;
p.numWalkers = 1;

BP(\st).reset;
BP(\st).prepareForPlay;

p.eventStream.next(p.event.copy).postcs; ""