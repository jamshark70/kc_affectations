// synth play for face dance

MIDIPort.init([2]);
MIDIPort.autoFreeSockets = false;

MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

(Document.current.path.dirname +/+ "head-defs.scd").loadPath;
topEnvironment[\dir] = Document.current.path.dirname.dirname +/+ "samples/feet";

m = MixerChannel(\test1, s, 1, 2);
n = MixerChannel(\test2, s, 2, 2);
m => MCG(0); n => MCG(1);


// Bloops

// too harsh
a = m.play {
	var	freq = XLine.kr(50, 900, 1, doneAction: 2),
		wMod = Line.kr(0.1, 0.45, 1),
		sig = Pulse.ar(freq, wMod);
	LPF.ar(sig, XLine.kr(14000, 1200, 1))
};

a = m.play {
	Pulse.ar(200, SinOsc.kr(0.5).range(0.1, 0.4))
};

a.free;



// Creaking (eye rolls)

// Low buzzes, analog-y (tongue rolls in mouth)

b.free;
b = Buffer.allocConsecutive(6, s, 1024, 1, { |buf, i|
	buf.chebyMsg((0 ! (i*2+1)).put(0, 1).put(i*2, 1).postln)
});

fork {
	b.do { |buf| buf.plotWavetable; 0.5.wait }
};

p = m.play(Instr("ptest", { |freq, pmodFreq = 0.5, ffreqMul = 5, sbufbase, sbufi|
	var	sig = Pulse.ar(freq, SinOsc.kr(pmodFreq).range(0.1, 0.4)),
	sb1 = sbufi.round(2),
	sbFrac2 = sbufi - sb1,
	sb2 = sb1 + sbFrac2.sign;
	sig = LPF.ar(sig, (freq * ffreqMul).clip(20, 18000));
	sig = Shaper.ar(sbufbase + [sb1, sb2], sig.clip(-1.0, 1.0));
	XFade2.ar(*(sig ++ [sbFrac2.abs.madd(2, -1)]))
}, [\freq, #[0.1, 10, \exp], #[2, 20, \exp], \mybuf, nil]), [nil, nil, nil, b.first.bufnum, KrNumberEditor(0, [0, b.size - 1.01])]);
p.gui;

p.synth.trace


// Wet, slurpy (tongue popping out -- muffle for tongue-in-mouth also)

// Tongue comes out, open mouth: start vocalization

// Smile and other emotions: vocal chatter
