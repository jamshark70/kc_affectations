// synth play for face dance

MIDIPort.init([2]);
MIDIPort.autoFreeSockets = false;

MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

(Document.current.path.dirname.dirname +/+ "common/common-defs.scd").loadPath;

(Document.current.path.dirname +/+ "head-defs.scd").loadPath;
topEnvironment[\dir] = Document.current.path.dirname.dirname +/+ "samples/feet";

m = MixerChannel(\test1, s, 1, 2, level: 0.1);
n = MixerChannel(\test2, s, 2, 2, level: 0.1);
m => MCG(0); n => MCG(1);

[m, n].do { |mx|
	mx.outbus = ~master;
	mx.sendsSignalTo(~glrvbmc);
	mx.sendsSignalTo(~lcrvbmc);
};

~master => MCG(7);

PeakMonitor(m);
PeakMonitor(n);

[~glrvb, ~lcrvb].do(_.run(false));
[~glrvb, ~lcrvb].do(_.run(true));


// Bloops

// too harsh
a = m.play {
	var	freq = XLine.kr(50, 900, 1, doneAction: 2),
		wMod = Line.kr(0.1, 0.45, 1),
		sig = Pulse.ar(freq, wMod);
	LPF.ar(sig, XLine.kr(14000, 1200, 1))
};

a.free;

a = m.play(Instr("test2", { |freq = 200, preAmp = 1/*, postAmp = 1*/|
	var //freq = XLine.kr(50, 900, 1, doneAction: 2),
		sig = SinOsc.ar(freq, 0, preAmp),
		// this is right! 
		postAmp = 0.5 / preAmp * (preAmp+1),
		dist = sig.distort * postAmp;
	dist
}, [\freq, #[0.05, 20, \exp]/*, #[0.05, 20, \exp]*/]));
a.gui;

o.remove;
o = OSCresponderNode(s.addr, '/amps', { |t, r, m| m[3..].postln }).add;

a = m.play {
	var	freq = XLine.kr(50, 900, 1, doneAction: 2),
		preAmp = Line.kr(0.3, 15.0, 1),
		postAmp = 0.5 / preAmp * (preAmp+1);
	SinOsc.ar(freq, 0, preAmp).distort * postAmp
};

d = \addRvbOut.eval(\dsinbloop, { |freq1 = 50, freq2 = 900, fcurve = 0, time = 1, fHoldPct = 0,
	amp1 = 1, amp2 = 1, noiseBlend = 0.1, noiseFmul = 1, noisePreamp = 1, rq = 1.0,
	normAmp = 0.5, pan1 = 0, pan2 = 0|
	var	freq = EnvGen.kr(Env([freq1, freq1, freq2], [fHoldPct, 1 - fHoldPct], fcurve),
			timeScale: time),
		preAmp = Line.kr(amp1, amp2, time),
		sig = XFade2.ar(SinOsc.ar(freq), BPF.ar(PinkNoise.ar, freq * noiseFmul, rq, noisePreamp),
			noiseBlend.madd(2, -1), preAmp),
		pan = Line.kr(pan1, pan2, time),
		postAmp = normAmp / preAmp * (preAmp+1),
		env = NamedControl.kr(\env, (0 ! 20).overWrite(Env.linen(0.01, 0.98, 0.01).asArray)),
		eg = EnvGen.kr(env, timeScale: time, doneAction: 2);
	Pan2.ar(sig.distort, pan, postAmp * eg)
}).add;

d = \addRvbOut.eval(\doscbloop, { |bufnum, freq1 = 50, freq2 = 900, fcurve = 0, time = 1, fHoldPct = 0,
	amp1 = 1, amp2 = 1, noiseBlend = 0.1, noiseFmul = 1, noisePreamp = 1, rq = 1.0,
	normAmp = 0.5, pan1 = 0, pan2 = 0|
	var	freq = EnvGen.kr(Env([freq1, freq1, freq2], [fHoldPct, 1 - fHoldPct], fcurve),
			timeScale: time),
		preAmp = Line.kr(amp1, amp2, time),
// 		sig = XFade2.ar(COsc.ar(bufnum, freq, ExpRand(0.5, 9.0)),
// 			BPF.ar(PinkNoise.ar, freq * noiseFmul, rq, noisePreamp),
// 			noiseBlend.madd(2, -1), preAmp),
		sig = BPF.ar(COsc.ar(bufnum, freq, ExpRand(0.5, 9.0)), freq, rq, noisePreamp),
		pan = Line.kr(pan1, pan2, time),
		postAmp = normAmp / preAmp * (preAmp+1),
		env = NamedControl.kr(\env, (0 ! 20).overWrite(Env.linen(0.01, 0.98, 0.01).asArray)),
		eg = EnvGen.kr(env, timeScale: time, doneAction: 2);
	Pan2.ar(sig.distort, pan, postAmp * eg)
}).add;

n.play(~rvbEvent.copy.putAll((
	instrument: \dsinbloop, time: 2,
	freq1: 100, freq2: 500,
	amp1: 3, amp2: 12, distance: 18, pan1: -0.8, pan2: 0.8
)));

e = n.play(~rvbEvent.copy.putAll((
	instrument: \dsinbloop, time: 2,
	freq1: 100, freq2: 500, fHoldPct: 0.8, fcurve: 2.1,
	noiseBlend: 0.1, noiseFmul: 5, noisePreamp: 20,
	amp1: 3, amp2: 12, distance: 18 //, pan1: -0.8, pan2: 0.8
)));

c = Buffer.sendCollection(s, Signal.fill(1024, { 1.0.rand2 }).asWavetable, 1, 0.05, { "done".postln });

e = n.play(~rvbEvent.copy.putAll((
	instrument: \doscbloop, time: 2, bufnum: c, normAmp: 3,
	freq1: 100, freq2: 500, fHoldPct: 0.8, fcurve: 2.1,
	noiseBlend: 0.1, noiseFmul: 5, noisePreamp: 20, rq: 0.1,
	amp1: 3, amp2: 12, distance: 18 //, pan1: -0.8, pan2: 0.8
)));

s.sendMsg(\n_trace, e[\id].first);

p = n.play(Pbind(
	\instrument, \dsinbloop,
	\delta, Pwrand(#[0.25, 0.5, 0.75], #[0.5, 0.35, 0.15], inf),
	\time, 0.2, // Pkey(\delta) * 0.8,
	\fHoldPct, Pwhite(0.2, 0.8, inf),
	\freq1, Pexprand(150, 400, inf),
	\freq2, Pkey(\freq1) * (Pwhite(1.8, 3.0, inf) pow: Prand(#[-1, 1], inf)),
	\fcurve, 2.1 * sign(Pkey(\freq2) - Pkey(\freq1)),
	\amp1, Pexprand(0.7, 1.4, inf),
	\amp2, Pkey(\amp1) * Pwhite(3.0, 7.0, inf),
	\distance, sin(Ptime() * (2pi / 10)),
	\pan1, 0,
	\pan2, 0
), (protoEvent: ~rvbEvent));

p.stop;


// Creaking (eye rolls)

g = GenericGlobalControl(\rt, nil, 0.07, #[0.05, 1, \exp]); g.gui;

// fail
a = m.play {
	var	sig = WhiteNoise.ar,
		freq = LFNoise1.kr(0.5).linexp(-1, 1, 600, 1400),
		trig = Impulse.ar(58),
		amp = EnvGen.ar(Env.perc(), gate: trig, timeScale: 12.reciprocal * 0.8);
	sig = DynKlank.ar(`[
		{ exprand(0.8, 1.25) },
		1 ! 5, g.kr ! 5
	], sig, freqscale: freq);
	Limiter.ar(sig) * amp
}.play;

a.free;



// Low buzzes, analog-y (tongue rolls in mouth)

b.free;
b = Buffer.allocConsecutive(6, s, 1024, 1, { |buf, i|
	buf.chebyMsg((0 ! (i*2+1)).put(i*2, 1).put(0, -1).postln)
});

fork {
	b.reverse.do { |buf| buf.plotWavetable; 0.5.wait }
};

m.scope

g = GenericGlobalControl(\pwidth, nil, 0.5, #[0.05, 0.5]);

p = m.play(Instr("ptest", { |freq, pwidth = 0.5, ffreqMul = 5, sbufbase, sbufi|
	var	sig = Pulse.ar(freq, pwidth),
	sb1 = sbufi.round(2),
	sbFrac2 = sbufi - sb1,
	sb2 = sb1 + sbFrac2.sign;
	sig = LPF.ar(sig, (freq * ffreqMul).clip(20, 18000));
	sig = Shaper.ar(sbufbase + [sb1, sb2], sig.clip(-1.0, 1.0));
	XFade2.ar(*(sig ++ [sbFrac2.abs.madd(2, -1)]))
}, [\freq, #[0.05, 0.5], #[2, 20, \exp], \mybuf, nil]), [nil, g, nil, b.first.bufnum, KrNumberEditor(0, [0, b.size - 1.01])]);
p.gui;

p.synth.trace

g.watch.automate { SinOsc.kr(1).range(0.05, 0.5) };
KrBusWatcher.newFrom(s).updateFreq = 6;
g.stopWatching.stopAuto;

g.dump;

// Wet, slurpy (tongue popping out -- muffle for tongue-in-mouth also)

// eq out electric hum from sample
b.free;
b = Buffer.readAndQuery(s, "~/SCServer/trax/orig-kc/slurpy-norm.aiff".standardizePath);

a = m.play { PlayBuf.ar(1, b, /*1, Impulse.kr(1.9), 519799,*/ loop: 1) };
a.free;

a.trace;

c = m.playfx(Instr("busfx.brickwall", { |bus, numCh, wipe = 0|
	var	sig = In.ar(bus, numCh),
	fft = FFT({ LocalBuf(2048, 1) } ! numCh, sig);
	fft = PV_BrickWall(fft, wipe);
	IFFT(fft)
}, [\audiobus, \numChannels, \bipolar]), [0, 1, KrNumberEditor(0.0001, #[0.0001, 0.1, \exp])]);
c.gui;

c.run(false);
c.run(true);

Instr("busfx.chorus").openFile

MultiEQ(1).edit(m);

s.freqscope;
PeakMonitor(m);

m.stopRecord;
MixerRecorder.dir = thisProcess.platform.recordingsDir;

a = LPCAna(topEnvironment[\sampleDir] +/+ "head/slurpy.aiff");
a.ana(50, 2000, 0.25);
a.saveToFiles(topEnvironment[\sampleDir] +/+ "head/slurpy.lpc");

a.pchcps;

b.free;
b = Buffer.readAndQuery(s, topEnvironment[\sampleDir] +/+ "head/slurpy.lpc.aif");
f = SoundFile.openRead(topEnvironment[\sampleDir] +/+ "head/slurpy.aiff");
c = f.numFrames;
f.close;

y = LPCFile(topEnvironment[\sampleDir] +/+ "head/slurpy.lpc");
y.pchcps;
y.loadToBuffer;
y.nrmerr.maxItem

b.getn(0, 100, _.postln);

z.free;
z = m.play { |amp = 1|
	var	freq, rms, err,
		phase = Phasor.ar(0, 1 / c, 0, 1),
		sig;
	#freq, rms, err = LPCVals.ar(y.buffer, phase);
	err = err.clip(0, 1);
 	sig = Blip.ar(freq, 100, (1 - err) * 0.4) + WhiteNoise.ar(err);
 	LPCSynth.ar(b, sig, phase, rms) * amp;
//	SinOsc.ar(freq, 0, 0.1)
}.play;

z.set(\amp, 100)

z.trace

z.free;

s.sendMsg(\n_free, 1011);

(Document.current.path.dirname.dirname +/+ "feet/feet-defs.scd").loadPath;

SynthDef(\blip, { |outbus, freq = 440, numh = 100, amp = 1, gate = 1|
	var eg = EnvGen.kr(Env.adsr, gate, doneAction: 2);
	Out.ar(outbus, Blip.ar(freq, min(20000 / freq, numh), amp))
}).add;

~lpcEv = (instrument: \simpleLPCfxPan, target: m.effectgroup, /*inbus: bus,*/ bus: m.inbus,
	lpcbuf: b, voxdur: c/44100, start: 0, end: c/44100, time: c/44100,
	hpf: 20, lpf: 6000);

e = (instrument: \blip, freq: 60.midicps * [1, 5/4, 3/2], sustain: c/44100, chan: m, parent: ProtoEvent(\polySynthBusLock).v.parent, collIndex: \dummy, lpcEv: ~lpcEv.copy, amp: 20);

g = e.copy.play;

// Tongue comes out, open mouth: start vocalization

// Smile and other emotions: vocal chatter
