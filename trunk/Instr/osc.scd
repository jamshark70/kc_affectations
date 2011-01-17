Instr([\osc, \stereopad], { arg freq, gate, ffreq, rq, env, fenv, fenvsense,
 detune, bufnum, velsense;
 var sig;
 ffreq = Sensitivity.kr(ffreq, EnvGen.kr(fenv, gate), fenvsense);
 sig = Osc.ar(bufnum, [freq, freq*detune], 0, Latch.kr(Sensitivity.kr(1, gate, velsense), gate));
 sig = RLPF.ar(sig, ffreq, rq) * EnvGen.kr(env, gate, doneAction:2)
}, #[\freq, \amp, \freq, \myrq, nil, nil, nil, \mydetune, nil, nil]);


Instr([\osc, \choruspad], { arg freq, gate, ffreq, rq, env, fenv, fenvsense,
 detune, lfospeed, bufnum, velsense;
 var sig, fm1, fm2;
 fm1 = SinOsc.kr(lfospeed, 0, detune, 1); // slow sine wave centered around 1.0
 fm2 = SinOsc.kr(lfospeed, pi/2, detune, 1);
 ffreq = Sensitivity.kr(ffreq, EnvGen.kr(fenv, gate), fenvsense);
 sig = Mix.ar(Osc.ar(bufnum, [freq * fm1, freq / fm2], 0,
 Latch.kr(Sensitivity.kr(1, gate, velsense), gate)));
 sig = RLPF.ar(sig, ffreq, rq) * EnvGen.kr(env, gate, doneAction:2);
}, #[\freq, \amp, \freq, \myrq, nil, nil, nil, [0, 0.1], [0, 5], nil, nil]);


Instr([\osc, \fm1], { arg freq, gate, car_env, mod_env, mod_lev, mod_ratio, detune,
 car_buf, mod_buf, car_vs, mod_vs;
 var sig, mod, car_amp, mod_amp;
 car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
 mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
 * EnvGen.kr(mod_env, gate);
 mod = Osc.ar(mod_buf, freq * mod_ratio + detune, 0, mod_amp * mod_lev);
 sig = Osc.ar(car_buf, freq + (mod * freq), 0, car_amp)
 * EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0.01, 300, \exponential], [0.25, 20, \linear, 0.1, 1], [-5, 5, \linear, 0, 0], \mybuf, \mybuf, nil, nil]);


Instr([\osc, \fm1pan], { arg freq, gate, car_env, mod_env, mod_lev, mod_ratio, detune,
 car_buf, mod_buf, car_vs, mod_vs, pan;
 var sig; // , mod, car_amp, mod_amp;
 sig = Instr([\osc, \fm1]).ar(freq, gate, car_env, mod_env, mod_lev, mod_ratio, detune,
 car_buf, mod_buf, car_vs, mod_vs);
// car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
// mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
// * EnvGen.kr(mod_env, gate);
// mod = Osc.ar(mod_buf, freq * mod_ratio + detune, 0, mod_amp * mod_lev);
// sig = Osc.ar(car_buf, freq + (mod * freq), 0, car_amp)
// * EnvGen.kr(car_env, gate, doneAction:2);
 Pan2.ar(sig, pan)
}, [\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0.01, 300, \exponential], [0.25, 20, \linear, 0.1, 1], [-5, 5, \linear, 0, 0], \mybuf, \mybuf, nil, nil, \bipolar]);


Instr([\osc, \fmchorus], { arg freq, gate, car_env, mod_env, mod_lev, mod_ratio,
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
}, #[\freq, \amp, nil, nil, [0.01, 300, \exponential], [0.25, 20, \linear, 0.1, 1], [-5, 5, \linear, 0, 0], [0, 0.1], [0, 10], \mybuf, \mybuf, nil, nil]);


Instr([\osc, \vosc3], { arg freq, gate, bufbase, bufmod, env, bufenv, vsens, detune;
 var sig, amp, buf;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 // the bufenv should know how many buffers it's covering
 buf = bufbase + bufmod + EnvGen.kr(bufenv, gate);
 sig = VOsc3.ar(buf, freq/detune, freq, freq*detune, amp)
 * EnvGen.kr(env, gate, doneAction:2);
}, #[\freq, \amp, [0, 1000, \linear, 1, 0], [0, 20], nil, nil, [0, 1], [0.9, 1.1, \linear, 0, 1]]);


Instr([\osc, \vosc3noadd], { arg freq, gate, bufbase, bufmod, env, bufenv, vsens, detune;
 var sig, amp, buf;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 // the bufenv should know how many buffers it's covering
 buf = bufmod + EnvGen.kr(bufenv, gate);
 sig = VOsc3.ar(buf, freq/detune, freq, freq*detune, amp)
 * EnvGen.kr(env, gate, doneAction:2);
}, #[\freq, \amp, [0, 1000, \linear, 1, 0], [0, 20], nil, nil, [0, 1], [0.9, 1.1, \linear, 0, 1]]);


Instr([\osc, \voscnoadd], { arg freq, gate, bufbase, bufmod, env, bufenv, vsens;
 var sig, amp, buf;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 // the bufenv should know how many buffers it's covering
 buf = bufmod + EnvGen.kr(bufenv, gate);
 sig = VOsc.ar(buf, freq, 0, amp)
 * EnvGen.kr(env, gate, doneAction:2);
}, #[\freq, \amp, [0, 1000, \linear, 1, 0], [0, 20], nil, nil, [0, 1], [0.9, 1.1, \linear, 0, 1]]);


Instr([\osc, \vosc3pan], { arg freq, gate, bufbase, bufmod, env, bufenv, vsens, detune, pan;
 var sig, amp, buf;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 // the bufenv should know how many buffers it's covering
 buf = bufbase + bufmod + EnvGen.kr(bufenv, gate);
 sig = VOsc3.ar(buf, freq/detune, freq, freq*detune, amp)
 * EnvGen.kr(env, gate, doneAction:2);
 Pan2.ar(sig, pan)
}, #[\freq, \amp, [0, 1000, \linear, 1, 0], [0, 20], nil, nil, [0, 1], [0.9, 1.1, \linear, 0, 1], [-1, 1]]);


Instr([\osc, \vosc3filt], { arg freq, gate, bufbase, bufmod, env, bufenv, vsens, detune, ffreq, rq;
 var sig, amp, buf;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 // the bufenv should know how many buffers it's covering
 buf = bufbase + bufmod + EnvGen.kr(bufenv, gate);
 sig = VOsc3.ar(buf, freq/detune, freq, freq*detune, amp)
 * EnvGen.kr(env, gate, doneAction:2);
 RLPF.ar(sig, ffreq, rq)
}, #[\freq, \amp, [0, 1000, \linear, 1, 0], [0, 20], nil, nil, [0, 1], [0.9, 1.1, \linear, 0, 1], \freq, [1, 0.001]]);

Instr([\osc, \vosc3fsweep], { arg freq, gate, bufbase, bufmod, env, vsens, detune, ffreq, rq, lowRatio, sweepTime, rattleStart, rattleEnd;
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


Instr([\osc, \vosc3panfilt], { arg freq, gate, bufbase, bufmod, env, bufenv, vsens, detune, pan, ffreq, rq;
 var sig, amp, buf;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 // the bufenv should know how many buffers it's covering
 buf = bufbase + bufmod + EnvGen.kr(bufenv, gate);
 sig = VOsc3.ar(buf, freq/detune, freq, freq*detune, amp)
 * EnvGen.kr(env, gate, doneAction:2);
 Pan2.ar(RLPF.ar(sig, ffreq, rq), pan)
}, #[\freq, \amp, [0, 1000, \linear, 1, 0], [0, 20], nil, nil, [0, 1], [0.9, 1.1, \linear, 0, 1], [-1, 1], \freq, [1, 0.001]]);


Instr([\osc, \fm1pb], { arg freq, gate, car_env, mod_env, mod_lev, mod_ratio, detune,
 car_buf, mod_buf, car_vs, mod_vs, pb;
 var sig, mod, car_amp, mod_amp;
 freq = freq * pb;
 car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
 mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
 * EnvGen.kr(mod_env, gate);
 mod = Osc.ar(mod_buf, freq * mod_ratio + detune, 0, mod_amp * mod_lev);
 sig = Osc.ar(car_buf, freq + (mod * freq), 0, car_amp)
 * EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, \amp, nil, nil, [0.01, 300, \exponential], [0.25, 20, \linear, 0.1, 1], [-5, 5, \linear, 0, 0], \mybuf, \mybuf, nil, nil, [5.midiratio.reciprocal, 5.midiratio, \exponential, 0, 1]]);


// phase mod stuff
Instr([\osc, \pm1], { arg freq, gate, mod_ratio, mod_lev, mod_phase, detune, vsens, car_buf, car_env, mod_env;
 var mod, amp;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 mod = SinOsc.ar(freq * mod_ratio, mod_phase, mod_lev)
 * EnvGen.kr(mod_env, gate);
 Mix.ar(Osc.ar(car_buf, [freq, freq*detune], mod, amp))
 * EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, \amp, [0.25, 20, \linear, 0.1, 1], [0.01, 70, \exponential], [0, 2*pi], \mydetune, nil, \mybuf, EnvSpec(Env.adsr), EnvSpec(Env.adsr)]);

Instr([\osc, \pmrandratio], { arg freq, gate, mod_lev, mod_phase, detune, vsens, car_buf, car_env, mod_env;
 var mod, mod_ratio, amp;
 mod_ratio = Rand(1, 10).round(1);
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 mod = SinOsc.ar(freq * mod_ratio, mod_phase, mod_lev)
 * EnvGen.kr(mod_env, gate);
 Mix.ar(Osc.ar(car_buf, [freq, freq*detune], mod, amp))
 * EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, \amp, [0.01, 70, \exponential], [0, 2*pi], \mydetune, nil, \mybuf, EnvSpec(Env.adsr), EnvSpec(Env.adsr)]);

Instr([\osc, \pmrandratio1], { arg freq, gate, mod_lev, mod_phase, vsens, car_buf, car_env, mod_env;
 var mod, mod_ratio, amp;
 mod_ratio = Rand(1, 10).round(1);
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 mod = SinOsc.ar(freq * mod_ratio, mod_phase, mod_lev)
 * EnvGen.kr(mod_env, gate);
 Osc.ar(car_buf, freq, mod, amp)
 * EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, \amp, [0.01, 70, \exponential], [0, 2*pi], \mydetune, nil, \mybuf, EnvSpec(Env.adsr), EnvSpec(Env.adsr)]);
