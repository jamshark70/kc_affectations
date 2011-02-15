// head - harmonic series -> intellectual exploration

// to do: reverb for chorus process


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

n.startRecord(thisProcess.platform.recordingsDir +/+ "h-series.aiff");

~num = 24;
p = ~p.(
	Pspawner({ |sp|
		Pwhile1({ |inval, next| next < 18 }, Pseries(1, Pstutter(8, Pseries(1, 1, inf)), inf)).trace
		.do { |num|
			sp.seq(
				Pfindur(2, Ptpar([
					{ |i| (1 - (i+1).reciprocal) * 0.5 } ! num,
					{ |i|
						Pbind(
							\instrument, Pn(\partial1bgated, 2),
// 							\numHold, if(i > 0, j.asPattern, 1),
							\numHold, if(i == 0, 1, max(num / 4, 1)),
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
		};
		sp.seq(
			Ptpar([
				({ |i| (1 - (i+1).reciprocal) * 0.5 } ! ~num).postln,
				{ |i|
					Pbind(
						\instrument, \partial1bgated,
						\numHold, Pwhite(1, j.asPattern, inf),
						\ratio, i+1,
						\freq, 32.midicps * Pkey(\ratio),
						\egRate, g.asMap,
						\egRateMul, i+1,
						\egBuf, c,
						\amp, 0.2,
						\delta, Pkey(\egRateMul).reciprocal * Pkey(\numHold),
						\sustain, Pkey(\delta) * (1 - (0.5 / Pkey(\numHold))),
						\panWidth, 0, // i/(~num-1),
						\timingOffset, (1 - (i+1).reciprocal) * h.asPattern//,
					) //.trace(key: \numHold)
				} ! ~num
			].flop.flat, 1)
		)
	}),
t, nil, n);

p.stop;
s.queryAllNodes
n.stopRecord;

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


WrapInstr("analog.saw", { |freq, gate = 1, detune = 1.003, ffreq = 2000, env, vsens = 0.5|

d = WrapPatch("analog.saw", [nil, nil, nil, `18000, Env.adsr(0.1, 0.2, 0.6, 0.5), 0.8]).asSynthDef.add;
SynthDescLib.at(d.name.asSymbol).msgFuncKeepGate = true;

SynthDef(\ringzFadePan, { |inbus, outbus, ffreq = 5000, filtAtk = 0.2, filtDcy = 0.22, time = 1,
	pan = 0, amp = 1|
	var	sig = In.ar(inbus, 1),
		eg = EnvGen.kr(Env(#[0, 1, 0], 0.5 ! 2, \sine), timeScale: time, doneAction: 2);
	sig = Formlet.ar(sig, ffreq, filtAtk, filtDcy);
	Out.ar(outbus, Pan2.ar(Limiter.ar(sig), pan, eg * amp));
}).add;

SynthDef(\ringzFadeEnv, { |inbus, outbus, filtAtk = 0.2, filtDcy = 0.22, time = 1,
	pan = 0, amp = 1|
	var	sig = In.ar(inbus, 1),
		eg = EnvGen.kr(Env(#[0, 1, 0], 0.5 ! 2, \sine), timeScale: time, doneAction: 2),
		freqEnv = NamedControl.kr(\freqEnv, Env(#[2000, 2000], #[1]).asArray.extend(24, 0)),
		ffreq = EnvGen.kr(freqEnv, timeScale: time);
	sig = Formlet.ar(sig, ffreq, filtAtk, filtDcy);
	Out.ar(outbus, Pan2.ar(Limiter.ar(sig), pan, eg * amp));
}).add;

SynthDef(\lpfxfer2, { |inbus, outbus, ffreq = 2000, lpfxAmp = 0.3|
	Out.ar(outbus, LPF.ar(In.ar(inbus, 1), ffreq, lpfxAmp) ! 2);
}).add;

SynthDef(\formantXfer2, { |inbus, outbus, t_trig = 0, slideTime = 1, amp = 1, lpfreq = 2000|
	var	ffreqs = NamedControl.kr(\ffreqs, Array.series(5, 400, 400)),
		amps = NamedControl.kr(\amps, 1 ! 5),
		qs = NamedControl.kr(\qs, 0.1 ! 5),
		sig = In.ar(inbus, 1); //,
//		noise = PinkNoise.ar(noiseAmp * Amplitude.kr(sig));
	ffreqs = ffreqs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
	amps = amps.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
	qs = qs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
	sig = LPF.ar(sig, lpfreq);
	sig = BBandPass.ar(sig /*+ noise*/, ffreqs, qs, amps).sum;
	Out.ar(outbus, (sig * amp) ! 2);
}).add;

SynthDescLib.at(\formantXfer2).msgFunc.postcs

(
e = (
	parent: ProtoEvent(\polySynthFxPatLock).v.parent,
	instrument: d.name.asSymbol,
	freq: 56.midicps * (4..6) / 4,
	sustain: 25,
	gate: 0.5,
	chan: n,
	numCh: 1,
	busFreeDelay: 1.5,
	fxProto: \monoSupport,
	formantKeys: FormantTable.keys.select { |key| key.asString.contains("tenor") }.asArray,
	fxPatEv: (
		pat: Pfindur({ ~sustain },
			Ppar([
				Pbind(
					\instrument, \formantXfer2,
					\protoEvent, Pseq([\singleSynthPlayNotify, Pn(\singleSynthTrigger, inf)]),
					// outer event (holding formantKeys) should be current when Plazy fires
					#[ffreqs, amps, qs], Pnsym(Plazy { Pxrand(~formantKeys, inf) }, FormantTable),
					\trig, 1,
					\delta, Pwhite(0.5, 1.5, inf),
					\slideTime, 0.4,
					\collIndex, \dummy,
					\notifyDependents, { ~lock.killNodes = ~node },
					\node, Pfunc { |ev| ev[\lock].killNodes ? 0 }
				),
				Pbind(
					\instrument, \ringzFadePan,
					\protoEvent, \singleSynthPlayNotify,
					\ffreq, Pexprand(1000, 9000, inf),
					\filtAtk, 0.1,
					\filtDcy, Pkey(\filtAtk) * Pexprand(1.05, 1.25, inf),
					\pan, Pwhite(0.7, 1.0, inf) * Prand(#[-1, 1], inf),
					\time, 1.5,
					\delta, 0.5,
					\amp, 0.3,
					\notifyDependents, 0
				)
			], 1)
		)
	)
).play;
)

e.node.do(_.free);

s.audioBusAllocator.debug

FormantTable.keys
z = FormantTable.get(\tenorU);

z = TuningRatios(12, tunings: [1, 4/3 * 4/5, 9/8, 6/5, 5/4, 4/3, 9/8 * 5/4, 3/2, 4/3 * 5/4, 9/8 * 3/2, 16/9, 3/2 * 5/4]).root_(8).calibrate(32.midicps, 32);

(
if(MBM.exists(0).not) { MIDIBufManager(chan: nil) => MBM.prNew(0) };

~ratios = [1, 4/3 * 4/5, 9/8, 6/5, 5/4, 4/3, 9/8 * 5/4, 3/2, 4/3 * 6/5, 4/3 * 5/4, 16/9, 3/2 * 5/4];
~tun = CompositeTuning([
	TuningRatios(12, tunings: ~ratios),
	TuningRatios(12, tunings: ~ratios.copy.putEach(#[5, 9, 10], [27/20, 27/16, 9/5]))
]).root_(8).calibrate(32.midicps, 32);

~tprop = (type: \c, voice: \tenor);
~aprop = (type: \c, voice: \alto);

MIDIRecBuf(\t1, [#[56, 58, 56], 16, 15.5, 0.5].asNotes, ~tprop) => MBM(0);
MIDIRecBuf(\a1, [#[68, 66.01, 68], 16, 15.5, 0.5].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\a1b, [#[68, 66.01, 68] - 5, 16, 15.5, 0.5].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\t2, [
	#[56, 58, 56, 54, 56, 61, 58, 56],
	#[1, 0.5, 0.5, 0.5, 0.5, 1, 2, 3],
	#[1, 0.5, 0.5, 0.5, 0.5, 1, 2, 3],
	0.5
].asNotes, ~tprop) => MBM(0);

MIDIRecBuf(\a2, [
	#[63, 65.01, 63, 61, 63, 68, 65.01, 63],
	#[1, 0.5, 0.5, 0.5, 0.5, 1, 2, 3],
	#[1, 0.5, 0.5, 0.5, 0.5, 1, 2, 3],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\a2b, [
	#[63, 65.01, 63, 61, 63, 68, 65.01, 67, 68],
	#[1, 0.5, 0.5, 0.5, 0.5, 1, 1, 1, 3],
	#[1, 0.5, 0.5, 0.5, 0.5, 1, 1, 1, 3],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\a2c, [
	#[68, 67, 68, 70, 72, 68, 67, 68],
	#[1, 0.5, 0.5, 0.5, 0.5, 2, 1, 3],
	#[1, 0.5, 0.5, 0.5, 0.5, 2, 1, 3],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\a2d1, [
	#[68, 67, 68, 70, 72, 68, 67, 67, 65, 68],
	#[1, 0.5, 0.5, 0.5, 0.5, 1.5, 0.5, 0.5, 0.5, 3],
	#[1, 0.5, 0.5, 0.5, 0.5, 1.5, 0.12, 0.4, 0.4, 3],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\a2d2, [
	// 61: better to tune Db vs. Ab rather than Bb
	#[63, 61, 63, 68, 65, 61, 63],
	#[1, 0.5, 1, 0.5, 1, 2, 3],
	#[1, 0.5, 1, 0.5, 1, 2, 3],
	0.5
].asNotes, ~aprop) => MBM(0);


MIDIRecBuf(\t3, [
	#[56, 58, 60, 61.01, 63, 61, 60, 58, 56],
	#[1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 2, 3],
	#[1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 2, 3],
	0.5
].asNotes, ~tprop) => MBM(0);

MIDIRecBuf(\a31, [
	#[63, 61, 63, 65.01, 67, 65, 63, 61, 63],
	#[1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 2, 3],
	#[1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 2, 3],
	0.5
].asNotes, ~aprop) => MBM(0);

MBM(0)[\a2c].copy.name_(\a32) => MBM(0);


MIDIRecBuf(\a41, [
	#[68, 70, 72, 73, 72, 70, 68],
	#[1, 1, 1, 2, 1, 3, 3],
	#[1, 1, 1, 2, 1, 3, 3],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\a42, [
	#[63, 65.01, 66, 65.01, 67, 68, 67, 63],
	#[1, 1, 1, 1, 1, 3, 1, 3],
	#[1, 1, 1, 1, 1, 3, 1, 3],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\t4, [
	#[60, 58, 56, 58, 63, 63, 61, 60],
	#[1, 1, 1, 1, 1, 2, 2, 3],
	#[1, 1, 1, 1, 1, 2, 2, 3],
	0.5
].asNotes, ~tprop) => MBM(0);

MIDIRecBuf(\b4, [
	#[44, 49.01, 48, 46, 44, 51, 44],
	#[1, 1, 1, 2, 1, 3, 3],
	#[1, 1, 1, 2, 1, 3, 3],
	0.5
].asNotes, (type: \c, voice: \bass, xfer: \lpfxfer2)) => MBM(0);


MBM(0)[\a41].copy.name_(\a51) => MBM(0);
MBM(0)[\a51].notes.last.dur_(8).length_(8);

MIDIRecBuf(\a52, [
	#[r, 63, 65, 67, 68, 66, 65.01, 65, 63, 61, 60],
	#[2, 1, 1, 1, 2, 1, 1, 1, 1, 1, 5],
	#[2, 1, 1, 1, 2, 1, 1, 1, 1, 1, 5],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\t5, [
	#[r, 63, 61, 60, 58, 61, 56, 63],
	#[5, 1, 1, 1, 1, 1, 2, 5],
	#[5, 1, 1, 1, 1, 1, 2, 5],
	0.5
].asNotes, ~tprop) => MBM(0);

MIDIRecBuf(\b5, [
	#[r, 44, 46, 48, 49.01, 49, 48, 46, 44],
	#[5, 1, 1, 1, 1, 1, 1, 1, 5],
	#[5, 1, 1, 1, 1, 1, 1, 1, 5],
	0.5
].asNotes, (type: \c, voice: \bass, xfer: \lpfxfer2)) => MBM(0);
)


(
WrapInstr("analog.sawB", { |freq, gate = 1, detune = 1.003, ffreq = 2000, vsens = 0.5
	att = 0.1, dec = 0.2, sus = 0.6, rel = 0.5, fLowRatio = 0.05|
	var	amp = (Latch.kr(gate, gate) - 1) * vsens + 1,
		sig = Saw.ar(freq * [1, detune], amp).sum,
		env = Env.adsr(att, dec, sus, rel),
		eg = EnvGen.kr(env, gate, doneAction: 2),
		fcurve = EnvGen.kr(Env([fLowRatio, 1], [att], \exp));
	LPF.ar(sig, ffreq * fcurve, eg)
}, [\freq, NoLagControlSpec(0, 1), \mydetune, \freq, nil, #[0.01, 20.0], #[0.01, 20.0], #[0, 1], #[0.01, 20.0]]);

PR(\abstractProcess).clone {
	~event = (eventKey: \polySynthFxPatLock, addAction: \addToHead);

	~seqKeys = #[t1, a1];
	~att = 1; // Pkey(\sustain) * 0.3;
	~dec = 1; // Pkey(\sustain) * 0.1;
	~rel = 1; // Pkey(\sustain) * 0.4;
	~fLow = 0.05;
	~rhyScale = 1;
	~legato = 0.93;
	~tempoPat = 42/60;

	~lpfxferFreq = 900;
	~lpfxferAmp = 0.3;

	~prep = {
		~chan = MixerChannel(~collIndex, s, 2, 2, completionFunc: { |chan|
			~chorus = chan.playfx(Instr("busfx.chorus2"), [0, 2, 2, 3, 0.036937527208376, 0.11364637357074, 0.0062137993811117, 0.69813170599922, 0.82540422302882]);
		});

		~def = WrapPatch("analog.sawB", [nil, nil, nil, `18000, 0.8])
			.asSynthDef.add;
		~defname = ~def.name.asSymbol;
		SynthDescLib.at(~defname).msgFuncKeepGate = true;

		~alto = ~formantKeys.("alto");
		~tenor = ~formantKeys.("tenor");
		~bass = ~formantKeys.("bass");
	};

	~freeCleanup = { [~chan/*, ~noiseCtl*/].free };

	~fx = \none; // Pfunc { ~fxPool.keys.choose };
	~fxProto = \monoSupport;
	~vowel = Pclutch(Pxrand(['A', 'E', 'I', 'O', 'U'], inf), Pdiff(Ptime()) > 0);

	~ratios = [1, 4/3 * 4/5, 9/8, 6/5, 5/4, 4/3, 9/8 * 5/4, 3/2, 4/3 * 6/5, 4/3 * 5/4, 16/9, 3/2 * 5/4];
	~tun = CompositeTuning([
		TuningRatios(12, tunings: ~ratios),
		TuningRatios(12, tunings: ~ratios.copy.putEach(#[5, 9, 10], [27/20, 27/16, 9/5]))
	]).root_(8).calibrate(32.midicps, 32);

	// NOTE: These will be evaluated in the Proto's context
	~fxPool = (
		rainbow: { |ev|
			var	up = rrand(0.3, 0.6);
			Pbind(
				\instrument, \ringzFadePan,
				\ffreq, Env(#[2500, 9000, 2500], [up, 1-up] * ev[\sustain], \sine),
				\filtAtk, Pexprand(0.08, 0.2, inf),
				\filtDcy, Pkey(\filtAtk) + Pwhite(0.05, 0.3, inf),
				\time, Pwhite(1.8, 3.2, inf),
				\delta, Pexprand(0.25, 0.8, inf),
				\pan, Pwhite(0.7, 1.0, inf) * Prand(#[-1, 1], inf),
				\amp, 0.05
			)
		},
		rainbow1: { |ev|
			var	up = rrand(0.15, 0.75), atk;
			Pn((
				instrument: \ringzFadeEnv,
				freqEnv: Env(#[2500, 9000, 2500], [up, 1-up] * ev[\sustain], \sine),
				filtAtk: atk = exprand(0.08, 0.2),
				filtDcy: atk + rrand(0.05, 0.3),
				time: ev[\sustain],
				delta: 1,
				pan: rrand(0.7, 1.0) * #[-1, 1].choose,
				amp: 0.05
			), 1)
		}
	);

	~formantKeys = { |string|
		FormantTable.keys.select { |key| key.asString.contains(string) }.asArray
	};

	~asPattern = {
		~fxStream ?? { ~makeStreamForKey.(\fx) };
		~lpfxferFreqStream ?? { ~makeStreamForKey.(\lpfxferFreq) };
		~lpfxferAmpStream ?? { ~makeStreamForKey.(\lpfxferAmp) };
		~vowelStream ?? { ~makeStreamForKey.(\vowel) };
		// currentEnvironment is a Proto; doesn't work for valueEnvir
		Plazy { |ev|
			Pbind(\tempo, Pclutch(~tempoPat.(ev), Pdiff(Ptime()) > 0))
			<>
			~patternTemplate.(ev)
		}.collect { |ev| ~preprocessNote.(ev) }
	};

	~evalEnvir = { |key| currentEnvironment.env.use { key.envirGet.valueEnvir } };

	~patternTemplate = { |ev|
		Ppar(
			~seqKeys.collect { |key|
				~currentKey = key;
				Pbind(
					\instrument, ~defname,
					// valueEnvir to allow subclasses to get arguments dynamically
					\note, ~evalEnvir.(\notePattern),
					\rhyScale, BPStream(\rhyScale),
					\delta, Pfunc { |ev| ev[\note].dur * ev[\rhyScale] },
					\legato, BPStream(\legato),
					\sustain, Pfunc { |ev| ev[\note].length * ev[\rhyScale] * ev[\legato] },
					\att, BPStream(\att), \dec, BPStream(\dec), \rel, BPStream(\rel),
					\fLowRatio, BPStream(\fLow),
					\chan, ~chan,
					\numCh, 1,
					\fxKey, BPStream(\fx),
					\fxProto, BPStream(\fxProto),
					\busFreeDelay, 3.2,
					\fxPatEv, Pbind(
						\syllable, ~evalEnvir.(\vocKey),
						\pat, Pfunc { |ev|
							var	fspecs = FormantTable.at(ev[\syllable]),
								fxPat, lockref;
							fxPat = ~fxPool[ev[\fxKey]].(ev);
							Pseq([
								Pn(~xferEvent.(ev, fspecs, lockref = `nil), 1),
								if(fxPat.notNil) {
									Pfindur(ev[\sustain],
										fxPat <> Pbind(\protoEvent, \singleSynthPlayNotify,
											\lock, Pfunc { lockref.value }))
								}
							])
						}
					)
				)
			}
		)
	};

	~notePattern = { |currentKey| MBM(0)[currentKey].asPattern };
	~vocKey = { |currentKey|
		var	prefix = MBM(0)[currentKey].properties[\voice];
		~vowelStream.collect { |vowel| (prefix ++ vowel).asSymbol }
	};
	~xferKey = { |currentKey| MBM(0)[currentKey].properties[\xfer] ?? { \formantXfer2 } };

	~preprocessNote = { |ev|
		var	note;
		// yeah, isKindOf = bad, but this could be called with an Event.silent
		if((note = ev[\note]).isKindOf(SequenceNote)) {
			if(note.freq.isSymbol) {
				ev[\instrument] = \rest;
//				ev = Event.silent(note.dur)
			} {
				ev.freq_(note.freq.asArray.collect(~tun.cps(_)))
					/*.sustain_(note.length)*/
					.gate_(note.gate)
			};
		}; // { "not a sequencenote".postln; note.postcs };
		ev
	};

	~xferEvent = { |ev, fspecs, lockref|
		(
			protoEvent: \singleSynthPlayNotify,
			instrument: ~evalEnvir.(\xferKey),
			ffreq: ~lpfxferFreqStream.next(ev),
			lpfxAmp: ~lpfxferAmpStream.next(ev),
			ffreqs: fspecs[0],
			amps: fspecs[1],
			qs: fspecs[2],
			sustain: nil,
			delta: 0.1,
			collIndex: ~collIndex,
			notifyDependents: {
				lockref.value = ~lock;
				~lock.killNodes = ~lock.killNodes.add(~node);
			}
		)
	};
} => PR(\counterpoint);

();
PR(\counterpoint).clone {
	~parentBP = \c;
	~importKeys = #[chan, alto, tenor, defname, tun];
	~prep = {
		if(BP.exists(~parentBP).not) {
			Error("BP(%) must be created first".format(~parentBP.asCompileString)).throw;
		};
		~importKeys.do { |key| key.envirPut(BP(~parentBP)[key]) };
		~parmKeys.do { |key| ~makeStreamForKey.(key) };
	};
	~freeCleanup = 0;

	~fx = \vowelChange;

	~fxPool = (
		vowelChange: { |ev|
			var	prefix = ev[\syllable].asString.drop(-1);
			Pbind(
				\protoEvent, \singleSynthTrigger,
				\node, Pfunc { |ev| ev[\lock].killNodes.asArray.detect(_.isKindOf(Synth)) },
				\trig, 1,
				#[ffreqs, amps, rqs], Pnsym(
					Pxrand(#['A', 'E', 'I', 'O', 'U'], inf)
						.collect { |vowel| (prefix ++ vowel).asSymbol },
					FormantTable
				),
				\delta, Pexprand(0.8, 1.8, inf),
				\slideTime, Pkey(\delta) * Pwhite(0.4, 0.7, inf)
			)
		}
	);

	// the meat!
	~seqKeys = #[not_applicable];
	~parmKeys = #[p5, sharp, shortFirst, dur, legato, gate, shortDur, oneNote];
	~oneNote = Pwhite(0.0, 1.0, inf) < 0.5; //true;
	~p5 = Pwhite(0.0, 1.0, inf) < 0.5; //false;  // false == 8ve
	~sharp = Pwhite(0.0, 1.0, inf) < 0.5; //true;  // true == raise cadence note
	~shortFirst = Pwhite(0.0, 1.0, inf) < 0.5; //true;
	~dur = Pwhite(0.65, 1.15, inf) *.x Pwhite(12.0, 16.0, { |num| num });
	~shortDur = Pwhite(1.2, 2.2, inf);
	~legato = Pwhite(1.02, 1.1, inf);
	~gate = Pif(Pfunc { |n| n > 1 },
		Pseq(#[0.6, 1.0, 0.6], inf) * Pwhite(0.5, 0.7, inf),
		Pwhite(0.4, 1.0, inf)
	);

	~lpfEnv = {
		var	up = rrand(0.3, 0.7);
		Env([200, 14000, 200], [up, 1-up], \exp);
	};

	~superPattern = ~asPattern;
	~asPattern = {
		var	self = currentEnvironment, resp;
		Pfset({ ~lpfbus = Bus.control(s, 1) },
			Ptpar([
				0, ~superPattern.(),
				0.01, Pfuncn { |ev|
					(	type: \on, instrument: \ctlEnv, outbus: ev[\lpfbus],
						time: self[\phraseDur] + 3, connect: 0, env: self.lpfEnv,
						group: self.chan.synthgroup,
						callback: { |event|
							resp = OSCpathResponder(s.addr, ['/n_end', event[\id][0]], {
								ev[\lpfbus].free; resp.remove;
							}).add
						},
						delta: 0
					).parent_(nil)  // force default parent event
				},
			])//,
//			{	(e { ~lpfbus.free }).defer(5.0) }
		)
	};

	// important: must output SequenceNotes
	~notePattern = { //|p5, sharp, shortFirst|
		// 61.01 is needed for Bb/Db and Bb/Gb
		// .01 has no effect on D-nat or G-nat (already tuned pure against Bb)
		var	freqs = if(~oneNoteStream.next) { #[[56, 63]] } {
				[
					#[56, 58, 56],
					[63, 61.01 + ~sharpStream.next.binaryValue, 63]
						+ (5 * ~p5Stream.next.not.binaryValue)
				].flop
			},
			fsize = freqs.size,
			durs = { ~durStream.next(fsize) } ! fsize;

		if(~shortFirstStream.next) { durs[0] = ~shortDurStream.next(fsize) };
		~phraseDur = durs.sum;	// BAD HACK
		Pseq(freqs.collect { |f, i|
			SequenceNote(f, durs[i], durs[i] * ~legatoStream.next, ~gateStream.next(fsize))
		}, 1)
	};

	// not using MIDIRecBufs for this so I must override these funcs too
	~vocKey = {
		var	prefix = ["tenor", "alto"].choose;
		~vowelStream.collect { |vowel| (prefix ++ vowel).asSymbol }
	};
	~xferKey = \formantXfer2;

	~superXferEvent = ~xferEvent;
	~xferEvent = { |ev, fspecs, lockref|
		~superXferEvent.(ev, fspecs, lockref).put(\lpfreq, ev[\lpfbus].asMap)
	};
} => PR(\cadences);
)

BP(#[cd, c]).free;
PR(\counterpoint) => BP(\c);
0 => BP(\c);
//BP(\c).tun = ~tun;

BP(\cd).free;
PR(\cadences).chuck(BP(\cd), nil, (parentBP: \c));
0 => BP(\cd);

p = BP(\cd);
p.parmKeys
p.p5_(false).sharp_(false).shortFirst_(false).oneNote_(true);
p.p5_(false).sharp_(false).shortFirst_(false).oneNote_(false);
p.p5_(true).shortFirst_(true);
p.sharp_(true);

p[\p5Stream]

BP(\cd).use { ~asPattern.().play(protoEvent: ~event.copy) };
BP.all.free

BP(\cd).fxPool = (
		vowelChange: { |ev|
			var	prefix = ev[\syllable].asString.drop(-1);
prefix.debug("Hello?");
			DebugPbind(
				\protoEvent, \singleSynthTrigger,
				\node, Pfunc { |ev| ev[\lock].killNodes.asArray.detect(_.isKindOf(Synth)) },
				\trig, 1,
				#[ffreqs, amps, rqs], Pnsym(
					Pxrand(#['A', 'E', 'I', 'O', 'U'], inf)
						.collect { |vowel| (prefix ++ vowel).asSymbol },
					FormantTable
				),
				\delta, Pexprand(0.8, 1.8, inf),
				\slideTime, Pkey(\delta) * Pwhite(0.4, 0.7, inf)
			)
		}
	);

BP(\cd).fx = \rainbow;

s.queryAllNodes;
s.sendMsg(\n_trace, 1113);

BP(\cd).dur = trace(Pwhite(0.65, 1.15, inf) *.x Pwhite(12.0, 16.0, 3));
BP(\cd).legato = 0.95; // Pwhite(1.02, 1.1, inf);
BP(\cd).p5 = Pwhite(0.0, 1.0, inf) < 0.5;
BP(\cd).sharp = Pwhite(0.0, 1.0, inf) < 0.5;
BP(\cd).shortDur = Pwhite(1.2, 2.2, inf);

Error.debug = true;
Error.debug = false;

BP(\cd).fx = \none;
BP(\cd).fx = \vowelChange;


TempoClock.default = TempoClock.all[0];
TempoClock.default.tempo = 42/60;
//BP(\c).seqKeys = #[t1, a1b];
BP(\c).seqKeys = #[t2];
BP(\c).seqKeys = #[t2, a2];
BP(\c).seqKeys = #[t2, a2b];
BP(\c).seqKeys = #[t2, a2c];

BP(\c).att_(0.7).rel_(0.9).dec_(1.2);
BP(\c).legato = 1;

BP(\c).tempoPat = ((42/60) * Pexprand(0.75, 0.5.reciprocal, inf)).trace;
BP(\c).seqKeys = #[t2, a2d1, a2d2];
BP(\c).seqKeys = #[t3, a31, a32];
BP(\c).seqKeys = #[a41, a42, t4, b4];

BP(\c).tempoPat = { 1.1 * (Env(#[1, 1, 0.56], #[6, 6], 3).asStream) };
BP(\c).seqKeys = #[a51, a52, t5, b5];

BP(\c).vowel = BP(\c).vowel.trace;

BP(\c).clock.tempo

MBM(0)[\b5]

BP(\c).rhyScale = 1;

#[att, dec, rel].do { |k| BP(\c)[k] = 0.25 };
BP(\c).fx = \none;
BP(\c).fx = \rainbow;

BP(\c).lpfxferAmp = 0.25;


Error.debug = true;
Error.debug = false;

q = BP(\c).chan.playfx(Instr("busfx.chorus2"), [0, 2, 2, 3]); q.gui;
BP(\c).event.addAction = \addToHead;

BP(\c).fx = \rainbow;
BP(\c).fx = \none;

#[att, dec, rel].do { |k| BP(\c)[k] = BP(\c)[k].trace(prefix: k) };

BP(\c).att = Pkey(\sustain) * 0.55;
BP(\c).dec = Pkey(\sustain) * 0.1;
BP(\c).rel = Pkey(\sustain) * 0.35;
BP(\c).fLow = 0.008;

BP(\c).noiseCtl.spec = #[0.1, 8.0, \exp];

#[alto, tenor, bass].do { |k| BP(\c)[k] = [(k ++ "A").asSymbol].postln }; ""

s.queryAllNodes;
s.sendMsg(\n_trace, 5065)

MCG(2).v.mixer.free

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m|
	s.sendMsg(\n_trace, m[1]); // r.remove;
}).add;

BP(\c).fxPool.rainbow1 = { |ev|
			var	up = rrand(0.15, 0.75), atk;
			Pn((
				instrument: \ringzFadeEnv,
				freqEnv: Env(#[600, 14000, 600], [up, 1-up], \sine),
				filtAtk: atk = exprand(0.08, 0.2),
				filtDcy: atk + rrand(0.05, 0.3),
				time: ev[\sustain],
				delta: 1,
				pan: rrand(0.7, 1.0) * #[-1, 1].choose,
				amp: 0.5
			), 1)
		}



BP(\c).fxPool.rainbow = { |ev|
			var	up = rrand(0.3, 0.6);
			Pbind(
				\instrument, \ringzFadePan,
				\ffreq, Env(#[1800, 9000, 1800], [up, 1-up] * ev[\sustain], \sine),
				\filtAtk, 0.02, // Pexprand(0.08, 0.2, inf),
				\filtDcy, Pkey(\filtAtk) + Pwhite(0.05, 0.1, inf),
				\time, Pwhite(0.9, 1.7, inf),
				\delta, Pexprand(0.1, 0.4, inf),
				\pan, Pwhite(0.7, 1.0, inf) * Prand(#[-1, 1], inf),
				\amp, 0.05
			)//.trace(key: \ffreq)
		}


// justly-tuned lpc'ed intervals to obscure final cadence
t = PR(\counterpoint).tun.copy.root_(0).calibrate;

r = {: [a, b], a <- (0..5), b <- (a+1..6),
	var x = t.cps(a.unmapMode(\default)), var y = t.cps(b.unmapMode(\default)),
	(y / x).asRational.denominator > 10
};

r.do(_.postln);
// questionable intervals in the default scale
[ 1, 3 ]
[ 1, 5 ]
[ 2, 3 ]
[ 3, 6 ]

r = {: [a, b], a <- #[1, 3], b <- #[3, 5, 6],
	var x = t.cps(a.unmapMode(\default) + 0.01), var y = t.cps(b.unmapMode(\default) + 0.01),
	(y / x).asRational.denominator > 10
};
// test the same in the alternate scale
r.do(_.postln);
[ 3, 6 ]  // fa - ti - 45/32 = pure M2 + M3 = as good as a tritone gets

(45/32).asFraction

t.cps(#[3, 6].unmapMode(\default)).reduce('/').asRational

#[[ 1, 3 ], [ 1, 5 ], [ 2, 3 ]].do({ |xy|
	t.cps(xy.unmapMode(\default)).reduce('/').asRational.postln
});

// thus, denominator threshold should be <= 16


(
BP(\int).free;
PR(\basicSynthChooser).chuck(BP(\int), nil, (
	dir: topEnvironment[\dir] ?? { Document.current.path.dirname.dirname +/+ "samples/feet" },
	lpcPath: "words-ana3.lpc.aif",
	labelPath: "words-labels.txt",
	audioPath: "words-mono.aiff",
	event: (eventKey: \polySynthBusLock),
	tun: PR(\counterpoint).tun,

	userprep: {
		~wt = Buffer.allocConsecutive(8, s, 2048, 1, { |buf, i|
			var	amps = 1 ! 18,	// c. 800 Hz top freq, just for test
				indices = (1..17).scramble.keep(rrand(9, 12));
			indices.do { |i| amps[i] = rrand(0.0, 0.1) };
			buf.sine1Msg(amps)
		});

		~lpcb = Buffer.readAndQuery(s, ~dir +/+ ~lpcPath);
		~pt = TabFileReader.read(~dir +/+ ~labelPath);
		~pt = ~pt.do { |pt| #[0, 1, 3, 4].do { |i| pt[i] = pt[i].asFloat } };
		SoundFile.use(~dir +/+ ~audioPath, { |file| ~voxdur = file.duration });
	},
	userfree: { [~wt, ~lpcb].free },

	degree: Pwhite(36, 44, inf) -.x Pseries(0, Pwhite(1, 7, 2), inf).clump(2),
	mode: \ab,
	bufmod: Pwhite(0, Pfunc { ~wt.size - 1.001 }, inf),
	amp: Pexprand(0.5, 1, inf),

	degToCps: Pfunc { |ev|  // ev[\degree] should be a 2-item array
		var	deg = ev[\degree].unmapMode(ev[\mode]),
			fr = ~tun.cps(deg), ratio;
		if(fr.size > 1) {
			ratio = fr.reduce('/');
			if(ratio < 1.0) { ratio = ratio.reciprocal };
			// if interval is not tuned close to pure, switch to alternate scale
			if(ratio.asFraction[1] > 16) {
				fr = ~tun.cps(deg + 0.01)
			} { fr };
		} {
			fr
		}
	},

	lpcDef: \simpleLPCfxPan,
	lpcStart: Pkey(\ptstart), // Pwhite(Pkey(\ptstart), Pkey(\ptend) - Pkey(\time), inf),
	lpcEnd: Pkey(\ptend), // Pkey(\start) + Pkey(\time),
	lpcPan: Pwhite(-1.0, 1.0, inf),
	lpcAtt: 0.05,
	lpcDec: 0.05,

	lpcEvPat: Plazy {
		/*Debug*/Pbind(
			\instrument, BPStream(\lpcDef),
			\lpcbuf, ~lpcb,
			\voxdur, ~voxdur,
			\pt, Pxrand(~pt, inf),
			#[ptstart, ptend], Pkey(\pt),
			\start, BPStream(\lpcStart),
			\end, BPStream(\lpcEnd),
			// \time should be populated by sanitizeEvent
			\amp, 1,
			\pan, BPStream(\lpcPan),
			\attack, BPStream(\lpcAtt),
			\decay, BPStream(\lpcDec)
		) <> Pfunc { |ev| ~sanitizeEvent4lpc.(ev) ?? { ev } }
	},
	objects: { (
		wtblip: (
			def: (  // this looks funny but is legal! expression sequence returns last result
				WrapInstr("osc2.vosc3percEnv", { |egAtk = 0.01, egDcy = 0.2|
					WrapInstr("osc2.vosc3").wrap((nil ! 4) ++ Env.adsr(egAtk, egDcy, 0, 0.01));
				}, nil ! 2);
				WrapPatch("osc2.vosc3percEnv", [nil, nil, nil, KrNumberEditor(1, #[0, 1]).lag_(nil),
					~wt.first.bufnum, nil, nil, nil, `1.003])
			),
			args: [
				degree: BPStream(\degree),
				mode: BPStream(\mode),
				freq: BPStream(\degToCps),
				bufmod: BPStream(\bufmod),
				vsens: 1,
				gate: BPStream(\amp),
				egAtk: 0.01,
				egDcy: Pkey(\sustain)
			]
		)
	) },

	superPattern: PR(\basicSynthChooser).v[\asPattern],
	asPattern: {
		/*Debug*/Pbind(\lpcEv, ~lpcEvPat) <> ~superPattern.()
// 		Pbindf(~superPattern.(),
// //			\lpcProto, \singleSynthPlayer,
// 			\lpcEv, ~lpcEvPat
// 		)
	},
	sanitizeEvent4lpc: { |ev, keys((time: \sustain))|
		var	newEv = ();
		keys.keysValuesDo { |k, v|
			newEv[k] = ev[v];
		};
		newEv
	}
));
0 => BP(\int);
)

p = BP(\int);
p.delta = Pexprand(0.25, 1.0, inf);
p.sustain = Pwhite(0.6, 2.2, inf);
p.amp = Pwhite(0.5, 1, inf);

p.wtblip

p.clock.tempo = 1

p.lpcEvPat = Plazy {
		/*Debug*/Pbind(
			\instrument, BPStream(\lpcDef),
			\lpcbuf, ~lpcb,
			\voxdur, ~voxdur,
			\pt, Pxrand(~pt, inf),
			#[ptstart, ptend], Pkey(\pt),
			\start, BPStream(\lpcStart),
			\end, BPStream(\lpcEnd),
			// \time should be populated by sanitizeEvent
			\amp, 1,
			\pan, BPStream(\lpcPan),
			\attack, BPStream(\lpcAtt),
			\decay, BPStream(\lpcDec)
		) <> Pfunc { |ev| ~sanitizeEvent4lpc.(ev) ?? { ev } }
	};

~saveD = p[\degToCps];
p.degToCps = p.degToCps.trace;
p.degToCps = ~saveD;

p.triggerOneEvent;

p.degree = Pwhite(36, 44, inf) -.x Pseries(0, Pwhite(1, 7, 2), inf).clump(2);
p.mode = \ab0;

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m|
	t.debug("\nn_go at");
	s.sendMsg(\n_trace, m[1]); // r.remove;
}).add;

p.lpcStart = Pkey(\ptstart);
p.lpcEnd = Pkey(\ptend);



// watch formant bus
(
var w = Window("formants", Rect(900, 50, 300, 200)), data = 0 ! BP(\fmt).fmtBus.numChannels,
	bpupd, busupd;

w.drawHook = {
	Pen.moveTo(Point(0, 199 - (data[0]*199)));
	data.doAdjacentPairs { |a, b, i|
		Pen.lineTo(Point(i * 299 / (data.size-1), 199 - (b*199)));
	};
	Pen.stroke;
};

w.onClose = { bpupd.remove; busupd.remove; KrBusWatcher.unregister(BP(\fmt).fmtBus) };

bpupd = Updater(BP(\fmt), { |obj, what, more|
	case { what == \play } { KrBusWatcher.register(BP(\fmt).fmtBus) }
	{ more == \stopped } { KrBusWatcher.unregister(BP(\fmt).fmtBus) }
});

busupd = Updater(BP(\fmt).fmtBus, { |bus, val|
	data = val;
	{ w.refresh }.defer;
});

w.front;
)

Window.allWindows.last.front

BP(\fmt).fmtBus.dependants
KrBusWatcher.newFrom(s).nodes