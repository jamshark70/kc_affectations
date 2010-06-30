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

SynthDef(\formantXfer2, { |inbus, outbus, t_trig = 0, slideTime = 1/*, noiseAmp = 0.1*/|
	var	ffreqs = NamedControl.kr(\ffreqs, Array.series(5, 400, 400)),
		amps = NamedControl.kr(\amps, 1 ! 5),
		qs = NamedControl.kr(\qs, 0.1 ! 5),
		sig = In.ar(inbus, 1); //,
//		noise = PinkNoise.ar(noiseAmp * Amplitude.kr(sig));
	ffreqs = ffreqs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
	amps = amps.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
	qs = qs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
	sig = BBandPass.ar(sig /*+ noise*/, ffreqs, qs, amps).sum;
	Out.ar(outbus, sig ! 2);
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

if(MBM.exists(0).not) { MIDIBufManager(chan: nil) => MBM.prNew(0) };

~ratios = [1, 4/3 * 4/5, 9/8, 6/5, 5/4, 4/3, 9/8 * 5/4, 3/2, 4/3 * 6/5, 4/3 * 5/4, 16/9, 3/2 * 5/4];
~tun = CompositeTuning([
	TuningRatios(12, tunings: ~ratios),
	TuningRatios(12, tunings: ~ratios.copy.putEach(#[5, 9, 10], [27/20, 27/16, 9/5]))
]).root_(8).calibrate(32.midicps, 32);

~tun.cps(61)
(~tun.cps(61.01) / ~tun.cps(58)).asRational

~tun.cps(68) absdif: 68.midicps

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
	#[1, 0.5, 0.5, 0.5, 0.5, 1.5, 0.5, 0.5, 0.5, 3],
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
MBM(0)[\a51].notes.last.dur_(5).length_(5);

MIDIRecBuf(\a52, [
	#[r, 63, 65, 67, 68, 66, 65.01, 65, 63, 61, 60],
	#[2, 1, 1, 1, 2, 1, 1, 1, 1, 1, 2],
	#[2, 1, 1, 1, 2, 1, 1, 1, 1, 1, 2],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\t5, [
	#[r, 63, 61, 60, 58, 61, 56, 63],
	#[5, 1, 1, 1, 1, 1, 2, 2],
	#[5, 1, 1, 1, 1, 1, 2, 2],
	0.5
].asNotes, ~tprop) => MBM(0);

MIDIRecBuf(\b5, [
	#[r, 44, 46, 48, 49.01, 49, 48, 46, 44],
	#[5, 1, 1, 1, 1, 1, 1, 1, 2],
	#[5, 1, 1, 1, 1, 1, 1, 1, 2],
	0.5
].asNotes, (type: \c, voice: \bass, xfer: \lpfxfer2)) => MBM(0);


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

//		~noiseCtl = GenericGlobalControl(\noiseLevel, nil, 0.1, \amp);
	};

//	~useGui = { |vpi| ~noiseCtl => VP(vpi) };

	~freeCleanup = { [~chan/*, ~noiseCtl*/].free };

	~fx = \none; // Pfunc { ~fxPool.keys.choose };
	~vowel = Pclutch(Pxrand(['A', 'E', 'I', 'O', 'U'], inf), Pdiff(Ptime()) > 0);

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
		Plazy { |ev| ~patternTemplate.(ev) }
			.collect { |ev| ~preprocessNote.(ev) }
	};

	~evalEnvir = { |key| currentEnvironment.env.use { key.envirGet.valueEnvir } };

	~patternTemplate = { |ev|
		// change this later
		Ppar(
			~seqKeys.collect { |key|
				~currentKey = key;
				Pbind(
					\instrument, ~def.name,
					// valueEnvir to allow subclasses to get arguments dynamically
					\note, ~evalEnvir.(\notePattern),
					\rhyScale, BPStream(\rhyScale),
					\delta, Pfunc { |ev| ev[\note].dur * ev[\rhyScale] },
					\sustain, Pfunc { |ev| ev[\note].length * ev[\rhyScale] },
					\att, BPStream(\att), \dec, BPStream(\dec), \rel, BPStream(\rel),
					\fLowRatio, BPStream(\fLow),
					\chan, ~chan,
					\numCh, 1,
					\fxProto, \singleSynthPlayNotify,
					\busFreeDelay, 3.2,
					\fxPatEv, Pbind(
						\syllable, ~evalEnvir.(\vocKey),
						\pat, Pfunc { |ev|
							var	fspecs = FormantTable.at(ev[\syllable]),
								fxPat;
							fxPat = ~fxPool[~fxStream.next(ev)].(ev);
							Pseq([
								Pn((
									instrument: ~evalEnvir.(\xferKey),
									ffreq: ~lpfxferFreqStream.next(ev),
									lpfxAmp: ~lpfxferAmpStream.next(ev),
									ffreqs: fspecs[0],
									amps: fspecs[1],
									qs: fspecs[2],
									sustain: nil,
									delta: 0,
									collIndex: ~collIndex,
									notifyDependents: { ~lock.killNodes = ~node }
								), 1),
								if(fxPat.notNil) { Pfindur(ev[\sustain], fxPat) }
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
} => PR(\counterpoint);
)

BP(\c).free;
PR(\counterpoint) => BP(\c);
0 => BP(\c);
BP(\c).tun = ~tun;

BP(\c).seqKeys = #[t1, a1b];
BP(\c).seqKeys = #[t2, a2];
BP(\c).seqKeys = #[t2, a2b];
BP(\c).seqKeys = #[t2, a2c];
BP(\c).seqKeys = #[t2, a2d1, a2d2];
BP(\c).seqKeys = #[t3, a31, a32];
BP(\c).seqKeys = #[a41, a42, t4, b4];
BP(\c).seqKeys = #[a51, a52, t5, b5];

BP(\c).vowel = BP(\c).vowel.trace;

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
