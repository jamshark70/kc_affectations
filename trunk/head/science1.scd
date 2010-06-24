// head - harmonic series -> intellectual exploration


SynthDescLib.global.browse;
Object.browse;
s.queryAllNodes;

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

#[master, rvbmc, rvb].do(_.envirPut(nil));

VoicerProxy.new => VP.prNew(0);
4.do { VP(0).v.addControlProxy(nil, true) };
VP(0).v.gui;

k = VoicerMIDISocket(0, VP(0).v);

{	var cc;
	8.do {
		cc = VoicerMIDIController(\omni, \knob);
		cc => CC.prNew(cc.ccnum.shortName.asSymbol);
	};
}.value;

4.do { |i| CC(("k" ++ i).asSymbol) => VP(0) };

~rvbmc => MCG(6);
~master => MCG(7);
MixingBoard.at(0).refresh;

~rvb.run(false); ~rvbmc.mute;
~rvb.run(true); ~rvbmc.mute;



// waveshaping or .distort or...? dirty up the sinewaves a bit
// panning?

SynthDef(\partial, { |outbus, gate = 1, freq = 440, amp = 1, ampLfoSpd = 1|
	var	lfo = SinOsc.kr(ampLfoSpd, -0.5pi, 0.5, 0.5) * amp,
		sig = SinOsc.ar(freq, 0, lfo),
		eg = EnvGen.kr(Env.asr(0.1, 1, 0.1), gate, doneAction: 2);
	Out.ar(outbus, sig * eg);
}).add;

SynthDef(\partial1, { |outbus, freq = 440, amp = 1, time = 1|
	var	sig = SinOsc.ar(freq, 0, amp),
		eg = EnvGen.kr(Env(#[0, 1, 0], (time * 0.5) ! 2, \sine), doneAction: 2);
	Out.ar(outbus, sig * eg);
}).add;

Env(#[0, 1, 0], 0.5 ! 2, \sine).plot

m.play((instrument: \partial, freq: 32.midicps, amp: 0.2, sustain: 3));

m.play((instrument: \partial, freq: 32.midicps * (1..15), ampLfoSpd: 0.25 * (1..15), timingOffset: 4 * (1 - (1..15).reciprocal) * 0.5, amp: 0.5 /* * (1..15).reciprocal */, sustain: 12));

m.play((instrument: \partial, freq: 32.midicps * (1..15), ampLfoSpd: 0.25 * (1..15), timingOffset: 4 * ((1..15).reciprocal) * 0.5, amp: 0.5 /* * (1..15).reciprocal */, sustain: 12));

p = m.play(Pbind(
	\instrument, \partial,
	\ratio, Pseries(1, 1, 15),
	\freq, 32.midicps * Pkey(\ratio),
	\ampLfoSpd, 0.25 * Pkey(\ratio),
	\timingOffset, 4 * 0.5 * (1 - Pkey(\ratio).reciprocal),
	\amp, 0.5,
	\sustain, (4*15) - Ptime() - Pkey(\timingOffset),
	\delta, 4
).trace);

p.stop;

m.play((instrument: \partial, freq: 32.midicps * 15, ampLfoSpd: 0.25 * 15, timingOffset: 4 * (1 - 15.reciprocal) * 0.5, amp: 0.5 /* * 15.reciprocal */, sustain: 12));

// synchro test
SynthDef(\partial2, { |out, gate = 1, freq = 440, amp = 1, ampLfoSpd = 1|
	var	lfo = SinOsc.kr(ampLfoSpd, -0.5pi, 0.5, 0.5) * amp,
		sig = SinOsc.ar(freq, 0, lfo),
		eg = EnvGen.kr(Env.asr(0.1, 1, 0.1), gate, doneAction: 2);
	Out.ar(out, sig * eg);
}).add;

Pbind(
	\instrument, \partial2,
	\freq, 32.midicps * (1..3),
	\ampLfoSpd, (1..3),
	\timingOffset, (1 - (1..3).reciprocal) * 0.5,
	\amp, 0.5 * (1..3).reciprocal,
	\sustain, 3,
	\delta, Pn(3, 1),
	\out, Pfunc { |ev| ev[\out].index + (0..2) }
).record(numChannels: 3, out: 8);

// don't like it
m.play(Pbind(
	\instrument, \partial2,
	\freq, 32.midicps * (1..3),
	\ampLfoSpd, (1..3),
	\timingOffset, ((1..3).reciprocal) * 0.5,
	\amp, 0.5 * (1..3).reciprocal,
	\sustain, 3,
	\delta, Pn(3, 1)
))


// ok, how to control density with this?
g = GenericGlobalControl(\density, nil, 0); g.gui;

p = m.play(
	Ppar({ |i|
		Pbind(
			\prob, g.asPattern + (i+1).reciprocal,
			\type, Pif(Pwhite(0.0, 1.0, inf) < Pkey(\prob), \note, \rest),
			\instrument, \partial1,
			\ratio, i+1,
			\freq, 32.midicps * Pkey(\ratio),
			\time, 4 / Pkey(\ratio),
			\timingOffset, 4 * 0.5 * (1 - Pkey(\ratio).reciprocal),
			\amp, 0.5,
			\delta, Pkey(\time)
		)
	} ! 15, inf)
);

p.stop;

Event.default.eventTypes.keys

~p = { |pat, clock(TempoClock.default), quant, mixer(m)|
	mixer.play(pat, (quant: quant, clock: clock, protoEvent: ProtoEvent(\singleSynthPlayer).copy))
};

n = 12;
d = 60;
~p.(Ptpar([
	{ |i| d * (1 - (i+1).reciprocal) } ! n,
	{ |i|
		Pbind(
			\instrument, \partial1,
			\ratio, i+1,
			\freq, 32.midicps * Pkey(\ratio),
			\time, d / Pkey(\ratio),
			// 		\timingOffset, d * 0.5 * (1 - Pkey(\ratio).reciprocal),
			\amp, 0.5,
			\delta, Pfin(i+1 * 2, Pkey(\time)),
			\grain, true
		)
	} ! n
].flop.flat, 1));

m.scope

// this allows me to speed up the envelope in RT
c = Buffer.alloc(s, 1024, 1, { |buf| buf.setnMsg(0, Env(#[0, 1, 0], #[0.5, 0.5], \sine).discretize(1024)) });

// egRate == 1 corresponds to 1 sec dur; 0.25 = 4 sec
SynthDef(\partial1a, { |outbus, freq = 440, amp = 1, egRate = 1, egRateMul = 1, egBuf|
	var	sig = SinOsc.ar(freq, 0, amp),
		egpos = Sweep.kr(1, egRate * egRateMul),
		eg = BufRd.kr(1, egBuf, egpos * BufFrames.ir(egBuf), loop: 0, interpolation: 2);
	FreeSelf.kr(egpos >= 1.0);
	Out.ar(outbus, sig * eg);
}).add;

SynthDef(\partial1b, { |outbus, freq = 440, amp = 1, egRate = 1, egRateMul = 1, egBuf,
	panWidth = 0, panCtr = 0|
	var	sig = SinOsc.ar(freq, 0, amp),
		swRate = egRate * egRateMul,
		egpos = Sweep.kr(1, swRate),
		eg = BufRd.kr(1, egBuf, egpos * BufFrames.ir(egBuf), loop: 0, interpolation: 2),
		pan = LFNoise1.kr(swRate, panWidth, panCtr).clip(-1.0, 1.0);
	FreeSelf.kr(egpos >= 1.0);
	Out.ar(outbus, Pan2.ar(sig * eg, pan));
}).add;

t = TempoClock.new;

g = GenericGlobalControl(\egRate, nil, 1/12, [1/60, 10, \exp]); g.gui;
u.remove;
u = Updater(g, { |obj, parms|
	if(parms.tryPerform(\at, \what) == \value) {
		t.tempo = g.value
	}
});

m.startRecord(thisProcess.platform.recordingsDir +/+ "partials1.aiff");

n = MixingBoard.at(0).mixers[1].mixer;

~num = 30;
p = ~p.(Ptpar([
	// because I'm not halving the offsets, this breaks apart the partials
	{ |i| (1 - (i+1).reciprocal) } ! ~num,
	{ |i|
		Pbind(
			\instrument, \partial1b,
			\ratio, i+1,
			\freq, 32.midicps * Pkey(\ratio),
//			\time, Pkey(\ratio).reciprocal,
			\egRate, g.asMap,
			\egRateMul, i+1,
			\egBuf, c,
			\amp, 0.2,
			\delta, Pkey(\egRateMul).reciprocal,
			\panWidth, i/(~num-1),
			\grain, true //,
//			\debug, true
		)
	} ! ~num
].flop.flat, 1), t, 1, n);

p.stop
m.stopRecord;