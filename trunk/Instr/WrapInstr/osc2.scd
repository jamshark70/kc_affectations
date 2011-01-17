WrapInstr([\osc2, \stereopad], { arg freq, gate, ffreq, rq, env, fenv, fenvsense,
 detune, bufnum, velsense;
 var sig;
 ffreq = Sensitivity.kr(ffreq, EnvGen.kr(fenv, gate), fenvsense);
 sig = Osc.ar(bufnum, [freq, freq*detune], 0, Latch.kr(Sensitivity.kr(1, gate, velsense), gate));
 sig = RLPF.ar(sig, ffreq, rq) * EnvGen.kr(env, gate, doneAction:2)
}, [\freq, \amp, \freq, \myrq, EnvSpec(Env.adsr), EnvSpec(Env(#[1, 1], #[1])), nil, \mydetune, nil, nil]);

//
//WrapInstr([\osc2, \choruspad], { arg freq, gate, ffreq, rq, env, fenv, fenvsense,
// detune, lfospeed, bufnum, velsense;
// var sig, fm1, fm2;
// fm1 = SinOsc.kr(lfospeed, 0, detune, 1); // slow sine wave centered around 1.0
// fm2 = SinOsc.kr(lfospeed, pi/2, detune, 1);
// ffreq = Sensitivity.kr(ffreq, EnvGen.kr(fenv, gate), fenvsense);
// sig = Mix.ar(Osc.ar(bufnum, [freq * fm1, freq / fm2], 0,
// Latch.kr(Sensitivity.kr(1, gate, velsense), gate)));
// sig = RLPF.ar(sig, ffreq, rq) * EnvGen.kr(env, gate, doneAction:2);
//}, #[\freq, \amp, \freq, \myrq, nil, nil, nil, [0, 0.1], [0, 5], nil, nil]);

WrapInstr([\osc2, \choruspad], { arg freq, gate, env, 
 detune, lfospeed, lfomod, lfomodfreq, bufnum, velsense, numlfos;
 var sig, fm;
 fm = SinOsc.kr(lfospeed * LFNoise1.kr(lfomodfreq, lfomod, 1), 
 (0, 0.5pi / (numlfos-1) .. 0.5pi), detune, 1);
 sig = Mix.ar(Osc.ar(bufnum, freq * fm, 0,
 Latch.kr(Sensitivity.kr(1, gate, velsense), gate)));
 sig = sig * EnvGen.kr(env, gate, doneAction:2);
}, [\freq, \amp, EnvSpec(Env.adsr), #[0, 0.1], #[0, 5], #[0, 2], #[0.1, 10, \exp], \mybuf, \unipolar, StaticSpec(1, 5, \lin, 1, 2)]);

WrapInstr([\osc2, \choruspadrlpf], { |ffreq, rq, fenv, fenvsense, gate|
 ffreq = Sensitivity.kr(ffreq, EnvGen.kr(fenv, gate), fenvsense);
 RLPF.ar(WrapInstr.wrap([\osc2, \choruspad], [nil, gate]), ffreq, rq)
}, [\freq, \myrq, EnvSpec(Env(#[1, 1], #[1])), nil, \amp]);


// example buffer def:
// b.sine1([0, 0, 0.25, 0, 0.5, 0] ++ (#[1, 0] ! 25).flat);

WrapInstr([\osc2, \buzzer], { |freq, gate, bufnum, env, ffreq, attack, decay, thresh, preamp, postamp, vsense|
 var sig, amp = Sensitivity.kr(1, Latch.kr(gate, gate), vsense);
 sig = (Osc.ar(bufnum, freq)) * amp;
 sig = Formlet.ar(sig, ffreq, attack, decay);
 sig = Limiter.ar(sig, thresh);
 sig = (sig * preamp).distort * postamp
 * EnvGen.kr(env, gate, doneAction:2)
}, [\freq, \amp, \mybuf, EnvSpec(Env.adsr), \freq, [0.001, 1, \exp], [0.001, 1, \exp], nil, [0.05, 20, \exp, 0, 1], [0.05, 20, \exp, 0, 1]]);


// simple 2-osc fm

WrapInstr([\osc2, \fm1], { arg freq, gate, car_env, mod_env, mod_lev, mod_ratio, detune,
 car_buf, mod_buf, car_vs, mod_vs;
 var sig, mod, car_amp, mod_amp;
 car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
 mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
 * EnvGen.kr(mod_env, gate);
 mod = Osc.ar(mod_buf, freq * mod_ratio + detune, 0, mod_amp * mod_lev);
 sig = Osc.ar(car_buf, freq + (mod * freq), 0, car_amp)
 * EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0.01, 300, \exponential], [0.25, 20, \linear, 0.1, 1], [-5, 5, \linear, 0, 0], \mybuf, \mybuf, nil, nil]);

WrapInstr("osc2.fm1porta", { |freq, freqlag|
 WrapInstr.wrap("osc2.fm1", [Lag.kr(freq, freqlag)])
}, [\freq, \unipolar]);

// very useful! to avoid aliasing
WrapInstr("osc2.fm1scale", { |freq, basefreq, keyscale, mod_lev|
 // algebraic reduction of mod_lev / (((f / b) - 1) * keyscale + 1)
 // if basefreq and keyscale are constants, renders as muladd + 2 binaryops
 mod_lev = mod_lev * basefreq / ((keyscale * freq) + (basefreq * (1 - keyscale)));
 WrapInstr.wrap("osc2.fm1", [freq, nil, nil, nil, mod_lev])
}, #[\freq, \freq, [0.001, 1.0, \exp], [0.01, 300, \exp]]);

// this is not so hot...
WrapInstr([\osc2, \fm1detune], { arg freq, gate, car_env, mod_env, car_detune, mod_lev, mod_ratio,
 mod_detune, car_buf, mod_buf, car_vs, mod_vs;
 var sig, mod, car_amp, mod_amp;
 car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
 mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
 * EnvGen.kr(mod_env, gate);
 mod = Osc.ar(mod_buf, freq * mod_ratio + mod_detune, 0, mod_amp * mod_lev);
 sig = Mix(Osc.ar(car_buf, [freq, freq*car_detune] + (mod * freq), 0, car_amp))
 * EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), \mydetune, [0.01, 300, \exponential], [0.25, 20, \linear, 0.1, 1], [-5, 5, \linear, 0, 0], \mybuf, \mybuf, nil, nil]);

// but this one is better...
WrapInstr("osc2.fm2car", { arg freq, gate, car_env, mod_env, mod_lev, mod_ratio, detune, car_detune,
 car_buf, mod_buf, car_vs, mod_vs, basefreq, keyscale;
 var sig, mod, car_amp, mod_amp;
 car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
 mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
 * EnvGen.kr(mod_env, gate);
 mod_lev = mod_lev * basefreq / ((keyscale * freq) + (basefreq * (1 - keyscale)));
 mod = Osc.ar(mod_buf, freq.madd(mod_ratio * [1, car_detune], detune * [1, -1]), 0, mod_amp * mod_lev);
 freq = freq * [1, car_detune];
 sig = Mix(Osc.ar(car_buf, freq + (mod * freq), 0, car_amp))
 * EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0.01, 300, \exponential], [1, 12, \linear, 0, 1], [-5, 5, \linear, 0, 0], \mydetune, \mybuf, \mybuf, nil, nil, \freq, [0.001, 1.0, \exp]]);


// add panning

WrapInstr([\osc2, \fm1pan], { |pan|
 Pan2.ar(WrapInstr.wrap([\osc2, \fm1]), pan)
}, #[\bipolar]);


WrapInstr([\osc2, \fm1pb], { |freq, pb|
 WrapInstr.wrap([\osc2, \fm1], [freq * pb])
}, [\freq, [5.midiratio.reciprocal, 5.midiratio, \exponential, 0, 1]]);

WrapInstr([\osc2, \fm1modbend], { arg freq, gate, car_env, mod_env, mod_lev, mod_ratio, detune,
 car_buf, mod_buf, car_vs, mod_vs, mod_ratio_env, mod_ratio_sens;
 var sig, mod, car_amp, mod_amp, mod_mod, tscale = Rand(0.8, 3);
 car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
 mod_mod = Sensitivity.kr(1, EnvGen.kr(mod_ratio_env, gate, timeScale: tscale), mod_ratio_sens);
 mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
 * EnvGen.kr(mod_env, gate);
 mod = Osc.ar(mod_buf, freq * (mod_ratio * mod_mod) + detune, 0, mod_amp * mod_lev);
 sig = Osc.ar(car_buf, freq + (mod * freq), 0, car_amp)
 * EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0.01, 300, \exponential], [0.25, 20, \linear, 0.1, 1], [-5, 5, \linear, 0, 0], \mybuf, \mybuf, nil, nil, EnvSpec(Env.one), nil]);


WrapInstr([\osc2, \fmchorus], { arg freq, gate, car_env, mod_env, mod_lev, mod_ratio,
 detune, chorus, lfospd, car_buf, mod_buf, car_vs, mod_vs;
 var sig, mod, car_amp, mod_amp, ch1, ch2;
 ch1 = SinOsc.kr(lfospd, 0, chorus, 1); // slow sine wave centered around 1.0
 ch2 = SinOsc.kr(lfospd, pi/2, chorus.neg, 1); 
 car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
 mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
 * EnvGen.kr(mod_env, gate);
 mod = Osc.ar(mod_buf, freq * mod_ratio + detune, 0, mod_amp * mod_lev);
 sig = Mix.ar(Osc.ar(car_buf, [ch1, ch2] * (freq + (mod * freq)), 0, car_amp))
 * EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, \amp, EnvSpec(Env.adsr), EnvSpec(Env.adsr), [0.01, 300, \exponential], [0.25, 20, \linear, 0.1, 1], [-5, 5, \linear, 0, 0], [0, 0.1], [0, 10], \mybuf, \mybuf, nil, nil]);


WrapInstr([\osc2, \vosc3], { arg freq, gate, bufbase, bufmod, env, bufenv, vsens, detune;
 var sig, amp, buf;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 // the bufenv should know how many buffers it's covering
 buf = bufbase + bufmod + EnvGen.kr(bufenv, gate);
 sig = VOsc3.ar(buf, freq/detune, freq, freq*detune, amp)
 * EnvGen.kr(env, gate, doneAction:2);
}, [\freq, \amp, [0, 1000, \linear, 1, 0], [0, 20], EnvSpec(Env.adsr), EnvSpec(Env(#[0, 0], #[1])), [0, 1], [0.9, 1.1, \linear, 0, 1]]);


WrapInstr([\osc2, \vosc3noadd], { arg freq, gate, bufbase, bufmod, env, bufenv, vsens, detune;
 var sig, amp, buf;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 // the bufenv should know how many buffers it's covering
 buf = bufmod + EnvGen.kr(bufenv, gate);
 sig = VOsc3.ar(buf, freq/detune, freq, freq*detune, amp)
 * EnvGen.kr(env, gate, doneAction:2);
}, [\freq, \amp, [0, 1000, \linear, 1, 0], [0, 20], EnvSpec(Env.adsr), EnvSpec(Env(#[0, 0], #[1])), [0, 1], [0.9, 1.1, \linear, 0, 1]]);


WrapInstr([\osc2, \voscnoadd], { arg freq, gate, bufbase, bufmod, env, bufenv, vsens;
 var sig, amp, buf;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 // the bufenv should know how many buffers it's covering
 buf = bufmod + EnvGen.kr(bufenv, gate);
 sig = VOsc.ar(buf, freq, 0, amp)
 * EnvGen.kr(env, gate, doneAction:2);
}, [\freq, \amp, [0, 1000, \linear, 1, 0], [0, 20], EnvSpec(Env.adsr), EnvSpec(Env(#[0, 0], #[1])), [0, 1], [0.9, 1.1, \linear, 0, 1]]);


WrapInstr([\osc2, \vosc3pan], { arg freq, gate, bufbase, bufmod, env, bufenv, vsens, detune, pan;
 var sig, amp, buf;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 // the bufenv should know how many buffers it's covering
 buf = bufbase + bufmod + EnvGen.kr(bufenv, gate);
 sig = VOsc3.ar(buf, freq/detune, freq, freq*detune, amp)
 * EnvGen.kr(env, gate, doneAction:2);
 Pan2.ar(sig, pan)
}, [\freq, \amp, [0, 1000, \linear, 1, 0], [0, 20], EnvSpec(Env.adsr), EnvSpec(Env(#[0, 0], #[1])), [0, 1], [0.9, 1.1, \linear, 0, 1], [-1, 1]]);


WrapInstr([\osc2, \vosc3filt], { arg freq, gate, bufbase, bufmod, env, bufenv, vsens, detune, ffreq, rq;
 var sig, amp, buf;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 // the bufenv should know how many buffers it's covering
 buf = bufbase + bufmod + EnvGen.kr(bufenv, gate);
 sig = VOsc3.ar(buf, freq/detune, freq, freq*detune, amp)
 * EnvGen.kr(env, gate, doneAction:2);
 RLPF.ar(sig, ffreq, rq)
}, [\freq, \amp, [0, 1000, \linear, 1, 0], [0, 20], EnvSpec(Env.adsr), EnvSpec(Env(#[0, 0], #[1])), [0, 1], [0.9, 1.1, \linear, 0, 1], \freq, [1, 0.001]]);

WrapInstr([\osc2, \vosc3fsweep], { arg freq, gate, bufbase, bufmod, env, vsens, detune, ffreq, rq, lowRatio, sweepTime, rattleStart, rattleEnd;
 var sig, amp, buf;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 buf = bufbase + bufmod;
 ffreq = EnvGen.kr(Env([lowRatio, 1, lowRatio*1.5, lowRatio],
 [sweepTime*0.75, sweepTime*0.5, 5], \exp, releaseNode:2), gate) * ffreq;
 ffreq = Lag.kr(LFPulse.kr(Line.kr(2, 8, sweepTime), 0, 0.5, ffreq*0.8, ffreq).clip(20, 20000),
 0.06);
 sig = VOsc3.ar(buf, freq/detune, freq, freq*detune, amp)
 * EnvGen.kr(env, gate, doneAction:2);
 RLPF.ar(sig, ffreq, rq)
}, [\freq, \amp, #[0, 1000, \linear, 1, 0], #[0, 20], EnvSpec(Env.adsr), #[0, 1], #[0.9, 1.1, \linear, 0, 1], \freq, #[1, 0.001], nil, #[0, 20], #[0, 20], #[0, 20]]);


WrapInstr([\osc2, \vosc3panfilt], { arg freq, gate, bufbase, bufmod, env, bufenv, vsens, detune, pan, ffreq, rq;
 var sig, amp, buf;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 // the bufenv should know how many buffers it's covering
 buf = bufbase + bufmod + EnvGen.kr(bufenv, gate);
 sig = VOsc3.ar(buf, freq/detune, freq, freq*detune, amp)
 * EnvGen.kr(env, gate, doneAction:2);
 Pan2.ar(RLPF.ar(sig, ffreq, rq), pan)
}, [\freq, \amp, [0, 1000, \linear, 1, 0], [0, 20], EnvSpec(Env.adsr), EnvSpec(Env(#[0, 0], #[1])), [0, 1], [0.9, 1.1, \linear, 0, 1], \bipolar, \freq, [1, 0.001]]);

// maps frequency onto buffers -- higher bufnums should have fewer partials to avoid aliasing
WrapInstr([\osc2, \vosc3map], { |freq, bufbase, numbufs, basefreq, topfreq|
 var baselog = log2(basefreq),
 freqmap = ((log2(freq) - baselog) / (log2(topfreq) - baselog)
 * (numbufs - 1)).clip(0, numbufs - 1.001);
 WrapInstr.wrap([\osc2, \vosc3], [freq, nil, bufbase, freqmap]);
}, [\freq, [0, 1000, \linear, 1, 0], [0, 20, \lin, 1, 0], \freq, \freq]);

WrapInstr("osc2.vosc3mapfilt", { |ffreq, rq|
 var sig = WrapInstr.wrap("osc2.vosc3map");
 RLPF.ar(sig, ffreq, rq)
}, [\freq, \myrq]);


// phase mod stuff
WrapInstr([\osc2, \pm1], { arg freq, gate, mod_ratio, mod_lev, mod_phase, detune, vsens, car_buf, car_env, mod_env;
 var mod, amp;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 mod = SinOsc.ar(freq * mod_ratio, mod_phase, mod_lev)
 * EnvGen.kr(mod_env, gate);
 Mix.ar(Osc.ar(car_buf, [freq, freq*detune], mod, amp))
 * EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, \amp, [0.25, 20, \linear, 0.1, 1], [0.01, 70, \exponential], [0, 2*pi], \mydetune, nil, \mybuf, EnvSpec(Env.adsr), EnvSpec(Env.adsr)]);

WrapInstr([\osc2, \pmrandratio], { arg freq, gate, mod_lev, mod_phase, detune, vsens, car_buf, car_env, mod_env;
 var mod, mod_ratio, amp;
 mod_ratio = Rand(1, 10).round(1);
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 mod = SinOsc.ar(freq * mod_ratio, mod_phase, mod_lev)
 * EnvGen.kr(mod_env, gate);
 Mix.ar(Osc.ar(car_buf, [freq, freq*detune], mod, amp))
 * EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, \amp, [0.01, 70, \exponential], [0, 2*pi], \mydetune, nil, \mybuf, EnvSpec(Env.adsr), EnvSpec(Env.adsr)]);

WrapInstr([\osc2, \pmrandratio1], { arg freq, gate, mod_lev, mod_phase, vsens, car_buf, car_env, mod_env;
 var mod, mod_ratio, amp;
 mod_ratio = Rand(1, 10).round(1);
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 mod = SinOsc.ar(freq * mod_ratio, mod_phase, mod_lev)
 * EnvGen.kr(mod_env, gate);
 Osc.ar(car_buf, freq, mod, amp)
 * EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, \amp, [0.01, 70, \exponential], [0, 2*pi], \mydetune, nil, \mybuf, EnvSpec(Env.adsr), EnvSpec(Env.adsr)]);
