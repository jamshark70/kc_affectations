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

~master ?? { ~master = MixerChannel(\master, s, 2, 2, level: 1) };

~rvbmc => MCG(6);
~master => MCG(7);
MixingBoard.at(0).refresh;

~rvb.run(false); ~rvbmc.mute;
~rvb.run(true); ~rvbmc.mute;



// waveshaping or .distort or...? dirty up the sinewaves a bit
// panning?

SynthDef(\partial, { |outbus, gate = 1, freq = 440, amp = 1, ampLfoSpd = 1|
	var	lfo = SinOsc.kr(ampLfoSpd, -0.5pi, 0.5, 0.5) * amp,
		sig = FSinOsc.ar(freq, 0, lfo),
		eg = EnvGen.kr(Env.asr(0.1, 1, 0.1), gate, doneAction: 2);
	OffsetOut.ar(outbus, sig * eg);
}).add;

SynthDef(\partial1, { |outbus, freq = 440, amp = 1, time = 1|
	var	sig = FSinOsc.ar(freq, 0, amp),
		eg = EnvGen.kr(Env(#[0, 1, 0], (time * 0.5) ! 2, \sine), doneAction: 2);
	OffsetOut.ar(outbus, sig * eg);
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
		sig = FSinOsc.ar(freq, 0, lfo),
		eg = EnvGen.kr(Env.asr(0.1, 1, 0.1), gate, doneAction: 2);
	OffsetOut.ar(out, sig * eg);
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
	var	sig = FSinOsc.ar(freq, 0, amp),
		egpos = Sweep.kr(1, egRate * egRateMul),
		eg = BufRd.kr(1, egBuf, egpos * BufFrames.ir(egBuf), loop: 0, interpolation: 2);
	FreeSelf.kr(egpos >= 1.0);
	OffsetOut.ar(outbus, sig * eg);
}).add;

SynthDef(\partial1b, { |outbus, freq = 440, amp = 1, egRate = 1, egRateMul = 1, egBuf,
	panWidth = 0, panCtr = 0|
	var	sig = FSinOsc.ar(freq, 0, amp),
		swRate = egRate * egRateMul,
		egpos = Sweep.kr(1, swRate),
		eg = BufRd.kr(1, egBuf, egpos * BufFrames.ir(egBuf), loop: 0, interpolation: 2),
		pan = LFNoise1.kr(swRate, panWidth, panCtr).clip(-1.0, 1.0);
	FreeSelf.kr(egpos >= 1.0);
	OffsetOut.ar(outbus, Pan2.ar(sig * eg, pan));
}).add;


SynthDef(\partial1bgated, { |outbus, freq = 440, amp = 1,
	egRate = 1, egRateMul = 1, egSusPt = 0.5, egBuf,
	panWidth = 0, panCtr = 0, gate = 1|
	var	sig = FSinOsc.ar(freq, 0, amp),
		swRate = egRate * egRateMul,
		posTest = Select.kr(Impulse.kr(0), [LocalIn.kr(1), 0]),
		notReachedSusPt = BinaryOpUGen('==', sign(egSusPt - posTest), swRate.sign),
		egpos = Sweep.kr(1, swRate * (((gate <= 0) + notReachedSusPt) > 0)),
// 		egpos = Sweep.kr(1, swRate * (((gate <= 0) + (posTest < egSusPt)) > 0)),
		eg = BufRd.kr(1, egBuf, egpos * BufFrames.ir(egBuf), loop: 0, interpolation: 2),
		pan = LFNoise1.kr(swRate, panWidth, panCtr).clip(-1.0, 1.0);
	LocalOut.kr(egpos);
	FreeSelf.kr(egpos >= 1.0);
	OffsetOut.ar(outbus, Pan2.ar(sig * eg, pan));
}).add;

x = n.play(\partial1bgated, [freq: 220, amp: 0.4, egBuf: c]);
x.trace
x.release;

0.2.acos / pi + 0.5
c.get((((0.2 * 2 - 1).acos / 2pi + 0.5) * c.numFrames).asInteger, _.postln)

n.play((instrument: \partial1bgated, freq: 32.midicps * (1..40), amp: 0.1, egRate: (1..40) / 8, egBuf: c,
	timingOffset: 8 * 0.5 * (1 - (1..40).reciprocal), sustain: 12 - (8 * 0.5 * (1 - (1..40).reciprocal))));

var pt = ~pt.choose.postln;
(
chan: n, instrument: \partial1bgated,
freq: 40.midicps * (1..80), amp: 0.1, egRate: 50, egBuf: c,
sustain: 3,
lpcEv: (
	instrument: \simpleLPCfxPan, lpcbuf: ~lpcb, voxdur: ~voxdur,
	start: pt[0], end: pt[1], time: 3
)
)
.parent_(ProtoEvent(\polySynthBusLock).v.parent)
.play;

a = m.play { Blip.ar(32.midicps, 15000 / 32.midicps, 0.5) };
a.free

32.midicps * 40

n.scope

t.stop; t = TempoClock(queueSize: 2048).permanent_(true);

g = GenericGlobalControl(\egRate, nil, 1/12, [1/60, 10, \exp]); g.gui;
u.remove;
u = Updater(g, { |obj, parms|
	if(parms.tryPerform(\at, \what) == \value) {
		t.tempo = obj.value
	}
});

m.startRecord(thisProcess.platform.recordingsDir +/+ "partials1.aiff");

n = MixingBoard.at(0).mixers[1].mixer;

	// because I'm not halving the offsets, this breaks apart the partials

h = GenericGlobalControl(\offsetmul, nil, 0.5, #[0, 0.5]); h.gui;
j = GenericGlobalControl(\holdbias, nil, 1, #[1, 20, \lin, 1]); j.gui;

~num = 24;
p = ~p.(Ptpar([
	({ |i| (1 - (i+1).reciprocal) * 0.5 } ! ~num).postln,
	{ |i|
		Pbind(
			\instrument, \partial1bgated,
			\numHold, Pwhite(1, j.asPattern, inf),
			\ratio, i+1,
			\freq, 32.midicps * Pkey(\ratio),
//			\time, Pkey(\ratio).reciprocal,
			\egRate, g.asMap,
			\egRateMul, i+1,
			\egBuf, c,
			\amp, 0.2,
			\delta, Pkey(\egRateMul).reciprocal * Pkey(\numHold),
			\sustain, Pkey(\delta) * (1 - (0.5 / Pkey(\numHold))),
			\panWidth, 0, // i/(~num-1),
			\timingOffset, (1 - (i+1).reciprocal) * h.asPattern//,
//			\grain, true //,
//			\debug, true
		) //.trace(key: \numHold)
	} ! ~num
].flop.flat, 1), t, nil, n);

p.stop;
m.stopRecord;

n.scope;


~num = 20;
p = ~p.(Ptpar([
	({ |i| (1 - (i+1).reciprocal) * 0.5 } ! ~num).postln,
	{ |i|
		Pbind(
			\instrument, Pn(\partial1b, 2),
			\ratio, i+1,
			\freq, 32.midicps * Pkey(\ratio),
//			\time, Pkey(\ratio).reciprocal,
			\egRate, g.asMap,
			\egRateMul, i+1,
			\egBuf, c,
			\amp, 0.2,
			\time, Pkey(\ratio).reciprocal,
			\delta, Pkey(\egRateMul).reciprocal,
			\panWidth, 0, // i/(~num-1),
			\timingOffset, (1 - (i+1).reciprocal) * h.asPattern,
			\grain, true
		)
	} ! ~num
].flop.flat, inf), t, nil, n);

p.stop;

p = ~p.(
	Pspawner({ |sp|
		(1..50).do { |num|
			sp.seq(
				Pfindur(2, Ptpar([
					{ |i| (1 - (i+1).reciprocal) * 0.5 } ! num,
					{ |i|
						Pbind(
							\instrument, Pn(\partial1bgated, 2),
							\numHold, if(i > 0, j.asPattern, 1),
							\ratio, i+1,
							\freq, 32.midicps * Pkey(\ratio),
							\egRate, g.asMap,
							\egRateMul, i+1,
							\egBuf, c,
							\amp, 0.4,
//							\time, Pkey(\ratio).reciprocal,
							\delta, Pkey(\egRateMul).reciprocal * Pkey(\numHold),
							\sustain, Pkey(\delta) * (1 - (0.5 / Pkey(\numHold))),
							\panWidth, 0, // i/(num-1),
							\timingOffset, (1 - (i+1).reciprocal) * h.asPattern//,
//							\grain, true
						)
					} ! num
				].lace(num*2), 1))
			)
		}
	}),
t, nil, n);

p.stop;


0.2.acos / pi + 0.5
c.get((((0.2 * 2 - 1).acos / 2pi + 0.5) * c.numFrames).asInteger, _.postln)

z = { |i|
	(type: \on, instrument: \partial1bgated,
		freq: 32.midicps * (i+1), egRate: 0.5, egRateMul: (i+1), egBuf: c, amp: 0.4,
		// this is the 'i' recip * 1/2 / egRate
		timingOffset: 2 * 0.5 * (1 - (i+1).reciprocal)
	)
} ! 15;

z.do { |e| n.play(e) };

// slow fade, replace with real Sawtooth

// egRateMul: cover half env cycle in 5 sec
// 0.2 = 1/5; egRate = 0.5 which accounts for the half cycle
// really it should be egRate / desiredTime / 0.5 * (numh / (i+1))
z.do { |e, i|
	e.putAll((type: \set, args: #[], egRateMul: 0.2 * 15 / (i+1), timingOffset: 0)).play;
	e.type_(\off).play;
};
a = m.play {
	var	sig = Saw.ar(32.midicps),
		fswp = EnvGen.kr(Env(#[48, 780, 780, 8000], #[5, 6, 7], \exp));
	LPF.ar(sig, fswp)
};

a.trace
a.free;
32.midicps * 15

// --> sawtooth (egSusPt formula gets fractional index into buffer where the desired magnitude is)
z.do { |e, i| e.putAll((type: \set, args: #[], egRateMul: 0.25,
	egSusPt: acos((i+1).reciprocal * 2 - 1) / 2pi + 0.5).postln).play;
};

//z.do { |e| e.putAll((egRateMul: -0.1, egSusPt: 0.5)).play };

z.do { |e| e.egRateMul_(0.5).play; e.type_(\off).play };

s.sendMsg(\n_trace, z[0][\id][0])
z.do { |e| e.hasGate_(false).play };


// notes

WrapInstr("analog.saw", { |freq, gate = 1, detune = 1.003, ffreq = 2000, env, vsens = 0.5|
	var	amp = (Latch.kr(gate, gate) - 1) * vsens + 1,
		sig = Saw.ar(freq * [1, detune], amp).sum,
		eg = EnvGen.kr(env, gate, doneAction: 2);
	LPF.ar(sig, ffreq, eg)
}, [\freq, NoLagControlSpec(0, 1), \mydetune, \freq, EnvSpec(Env.adsr), nil]);

z = TuningRatios(12, 32.midicps, 32, [1, 4/3 * 4/5, 9/8, 6/5, 5/4, 4/3, 9/8 * 5/4, 3/2, 4/3 * 6/5, 4/3 * 5/4, 16/9, 3/2 * 5/4]).root_(8);

// this one cheats and tunes E-nat to F-nat = M3 over Db, and F-nat to P5 over Bb
z = TuningRatios(12, tunings: [1, 4/3 * 4/5, 9/8, 6/5, 5/4, 4/3, 9/8 * 5/4, 3/2, 4/3 * 5/4, 9/8 * 3/2, 16/9, 3/2 * 5/4]).root_(8).calibrate(32.midicps, 32);

z.tunings.asRational

MIDIPort.autoFreeSockets = true;

v = WrapInstr("analog.saw").miditest(0, initArgs: [env: Env.adsr(0.1, 0.2, 0.6, 0.5)], target: m);
k = MIDIPort.search(v);
k.midiToFreq = z;
z;

// need CompositeTuning - F-nat is a problem

4/%3 * 5/4
9/%8 * 3/2

k.midiToFreq = nil;
k.midiToFreq

MIDIPort.sources
j = MIDIThruSocket(#[1, \omni], #[0, 0]);


p = Pspawner({ |sp|
	var notes = [
		#[56, 58, 56, 54, 56, 58, 61, 56],
		#[63, 61, 63, 66, 68, 66, 64, 63],
		