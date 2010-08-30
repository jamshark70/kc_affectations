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

d = \addRvbOut.eval(\dsinbloop, { |freq1 = 50, freq2 = 900, time = 1, amp1 = 1, amp2 = 1,
	normAmp = 0.5, pan1 = 0, pan2 = 0|
	var	freq = XLine.kr(freq1, freq2, time),
		preAmp = Line.kr(amp1, amp2, time),
		pan = Line.kr(pan1, pan2, time),
		postAmp = normAmp / preAmp * (preAmp+1),
		env = NamedControl.kr(\env, (0 ! 20).overWrite(Env.linen(0.01, 0.98, 0.01).asArray)),
		eg = EnvGen.kr(env, timeScale: time, doneAction: 2);
	Pan2.ar(SinOsc.ar(freq, 0, preAmp).distort, pan, postAmp * eg)
}).add;

m.play(~rvbEvent.copy.putAll((
	instrument: \dsinbloop, time: 2,
	freq1: 100, freq2: 500,
	amp1: 3, amp2: 12, distance: 18, pan1: -0.8, pan2: 0.8
)));

p = m.play(Pbind(
	\instrument, \dsinbloop,
	\delta, Pwrand(#[0.25, 0.5, 0.75], #[0.5, 0.35, 0.15], inf),
	\time, Pkey(\delta) * 0.8,
	\freq1, Pexprand(150, 400, inf),
	\freq2, Pkey(\freq1) * (Pwhite(1.8, 3.0, inf) pow: Prand(#[-1, 1], inf)),
	\amp1, Pexprand(0.7, 1.4, inf),
	\amp2, Pkey(\amp1) * Pwhite(3.0, 7.0, inf),
	\distance, sin(Ptime() * (2pi / 10)),
	\pan1, 0,
	\pan2, 0
), (protoEvent: ~rvbEvent));

p.stop;


// Creaking (eye rolls)

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

// Tongue comes out, open mouth: start vocalization

// Smile and other emotions: vocal chatter
