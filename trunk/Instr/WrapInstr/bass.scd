WrapInstr([\bass, \wowfunk], { arg freq, gate, freqlag, env, fenv, ffreq, rq, vsens, /*fvsens, */fenvsens, detune;
 var sig, fcurve, amp;
 freq = Lag.kr(freq, freqlag);
 amp = Sensitivity.kr(1, Latch.kr(gate, gate), vsens);
 sig = Mix.ar(Saw.ar([freq, freq*detune], amp));
 fcurve = Sensitivity.kr(ffreq, EnvGen.kr(fenv, gate), fenvsens);
 sig = RLPF.ar(sig, fcurve, rq);
 sig * EnvGen.kr(env, gate, doneAction:2) // output
}, [\freq, \amp, [0, 5], EnvSpec(Env.adsr(0.1, 0.25, 0.75, 0.1)), EnvSpec(Env.adsr(0.05, 0.75, 0.4, 0.5)), \freq, [1, 0.01], [0, 1], [0, 1], \mydetune]);


WrapInstr([\bass, \distpulse], { arg freq, gate, freqlag, pwidth, detune, distortion, ffreq, rq,
 vsense, fenvsense, env, fenv, trigthresh, t_gate,
 logate = 0, higate = 1, lotrig = 0.5, hitrig = 1.0;
 var sig, amp;
 var trig = (t_gate > trigthresh) *
 LinLin.kr((t_gate - trigthresh).clip(logate, higate), logate, higate, lotrig, hitrig);
 freq = Lag.kr(freq, freqlag);
 amp = Sensitivity.kr(1, Latch.kr(gate, gate), vsense);
 // oscillator
 sig = Pulse.ar([freq, freq*detune], pwidth);
 // distortion
 sig = Mix.ar((sig * distortion).distort) * amp;
 // filter envelope
// ffreq = Sensitivity.kr(ffreq, EnvGen.kr(fenv, trig, levelScale: trig), fenvsense);
 ffreq = ffreq * (EnvGen.kr(fenv, trig, levelScale: trig * fenvsense, levelBias: 1));
 sig = RLPF.ar(sig, ffreq.clip(20, 20000), rq);
 // output phase
 sig * EnvGen.kr(env, gate, doneAction:2)
}, [\freq, [0, 1], \freqlag, [0, 1], \mydetune, [1, 10], \freq, \myrq, [0, 1], [0, 1], EnvSpec(Env.adsr(0.01, 0.25, 0.5, 0.1)), EnvSpec(Env.adsr(0.01, 1, 1, 1))]);

WrapInstr([\bass, \distpulsefall], { |freq, t_gate, pitchEnv, pitchsense|
 freq = Sensitivity.kr(freq, EnvGen.kr(pitchEnv, t_gate), pitchsense);
 WrapInstr.wrap([\bass, \distpulse], [freq] ++ (nil ! 12) ++ [t_gate])
}, [\freq, #[0, 1], EnvSpec(Env(#[1, 1], [1]))]);


WrapInstr([\bass, \distsine], { arg freq, gate, freqlag, detune, distortion, ffreq, rq,
 vsense, fenvsense, env, fenv;
 var sig, amp;
 freq = Lag.kr(freq, freqlag);
 amp = Sensitivity.kr(1, Latch.kr(gate, gate), vsense);
 // oscillator
 sig = SinOsc.ar([freq, freq*detune]);
 // distortion
 sig = Mix.ar((sig * distortion).distort);
 // filter envelope
 ffreq = Sensitivity.kr(ffreq, EnvGen.kr(fenv, gate), fenvsense);
 // output phase
 RLPF.ar(sig, ffreq, rq, amp) * EnvGen.kr(env, gate, doneAction:2)
}, [\freq, [0, 1], \freqlag, \mydetune, [1, 10], \freq, \myrq, [0, 1], [0, 1], EnvSpec(Env.adsr(0.01, 0.25, 0.5, 0.1)), EnvSpec(Env.adsr(0.01, 1, 1, 1))]);

WrapInstr([\bass, \distsinefall], { |freq, t_gate, pitchEnv, pitchsense|
 freq = Sensitivity.kr(freq, EnvGen.kr(pitchEnv, t_gate), pitchsense);
 WrapInstr.wrap([\bass, \distsine], [freq])
}, [\freq, #[0, 1], EnvSpec(Env(#[1, 1], [1]))]);


 // simple sinewave fm w/filter that optionally applies a shaper to carrier (before filter)
WrapInstr([\bass, \fmshaper], { arg freq, gate, freqlag, mod_ratio, mod_lev, mod_detune, shaper_bufnum, ffreq, rq, car_env, mod_env, fenv, car_vsense, mod_vsense, mod_envSense, fenvsense;
 var mod, car, amp, car_amp;
 freqlag.notNil.if({ freq = Lag.kr(freq, freqlag) });
 amp = Latch.kr(gate, gate);
 car_amp = Sensitivity.kr(1, amp, car_vsense);
 // modulator
 mod = SinOsc.ar(freq * mod_ratio * mod_detune, 0, Sensitivity.kr(mod_lev, amp, mod_vsense))
 * Sensitivity.kr(1, EnvGen.kr(mod_env, gate), mod_envSense);
 // carrier
 car = SinOsc.ar(freq + (mod*freq), 0, car_amp);
 (shaper_bufnum >= 0).if({ car = Shaper.ar(shaper_bufnum, car) });
 // filter & output
 RLPF.ar(car, Sensitivity.kr(ffreq, EnvGen.kr(fenv, gate), fenvsense), rq)
 * EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, [0, 1], \freqlag, [0.25, 20, \exponential, 0, 1], [0.01, 300, \exponential, 0, 1], \mydetune, \mybuf, \freq, \myrq,
 EnvSpec(Env.adsr(0.01, 0.25, 0.8, 0.1)), EnvSpec(Env.adsr(0.01, 1, 1, 0.1)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0, 1], [0, 1], [0, 1]]);


// add some high partial resonz-ed noise to a deep bass
// it's aggressive but pretty expensive (10% cpu per synth)
WrapInstr([\bass, \blipBPF], { |freq, gate, freqlag, ffreq, rq, env, fenv, numharm, detune, bpRatios, bpRqs, bpAmps, velsense, fenvsense|
 var sig, amp, filters, cutoff, filtEnv;
 freq = Lag.kr(freq, freqlag);
 amp = Sensitivity.kr(1, Latch.kr(gate, gate), velsense);
 sig = Mix.ar(Blip.ar([freq, freq*detune], numharm));
 filtEnv = Sensitivity.kr(1, EnvGen.kr(fenv, gate), fenvsense);
 filters = Mix.ar(BPF.ar(sig, freq * filtEnv * bpRatios, bpRqs * rq, bpAmps));
 (RLPF.ar(sig, ffreq * filtEnv, rq) + filters)
 * amp * EnvGen.kr(env, gate, doneAction:2);
}, [\freq, nil, [0, 5], \freq, \myrq, EnvSpec(Env.adsr(0.05, 0.25, 0.75, 0.1)), EnvSpec(Env.adsr(0.1, 1.0, 0.2, 0.5)), [1, 200, \lin, 1, 50], \mydetune, nil, \myrq, nil, nil, [0, 1], [0, 1]]);

WrapInstr([\bass, \sawBPF], { |freq, gate, freqlag, ffreq, rq, env, fenv, numharm, detune, bpRatios, bpRqs, bpAmps, velsense, fenvsense|
 var sig, amp, filters, cutoff, filtEnv;
 freq = Lag.kr(freq, freqlag);
 amp = Sensitivity.kr(1, Latch.kr(gate, gate), velsense);
 sig = Mix.ar(Saw.ar([freq, freq*detune]));
 filtEnv = Sensitivity.kr(1, EnvGen.kr(fenv, gate), fenvsense);
 filters = Mix.ar(BPF.ar(sig, freq * filtEnv * bpRatios, bpRqs * rq, bpAmps));
 (RLPF.ar(sig, ffreq, rq) + filters)
 * amp * EnvGen.kr(env, gate, doneAction:2);
}, [\freq, nil, [0, 5], \freq, \myrq, EnvSpec(Env.adsr(0.05, 0.25, 0.75, 0.1)), EnvSpec(Env.adsr(0.1, 1.0, 0.2, 0.5)), [1, 200, \lin, 1, 50], \mydetune, nil, \myrq, nil, nil, [0, 1], [0, 1]]);


// cool thing here is that the formlet takes time to stabilize on change of pitch
// attacktime determines how long it takes
WrapInstr([\bass, \sawformlet], { arg freq, gate, freqlag, env, fenv, ffreq, rq, vsens, fenvsens, detune, formratio, attacktime, decaytime, formPreAmp, formletAmp /*, formbeats, formscoop, formscoopTime */;
 var sig, fcurve, amp, formfreq;
 freq = Lag.kr(freq, freqlag);
 amp = Sensitivity.kr(1, Latch.kr(gate, gate), vsens);
 sig = Mix.ar(Saw.ar([freq, freq*detune], amp));
 fcurve = Sensitivity.kr(ffreq, EnvGen.kr(fenv, gate), fenvsens);
 formfreq = freq * formratio; // - XLine.kr(formscoop, formbeats, formscoopTime);
 sig = (RLPF.ar(sig, fcurve, rq)
 + (Formlet.ar(sig, formfreq, attacktime, decaytime, formPreAmp).softclip * formletAmp))
 * EnvGen.kr(env, gate, doneAction:2);
}, [\freq, \amp, [0, 5], EnvSpec(Env.adsr(0.1, 0.25, 0.75, 0.1)), EnvSpec(Env.adsr(0.05, 0.75, 0.4, 0.5)), \freq, [1, 0.01], [0, 1], [0, 1], \mydetune, [1, 16, \lin, 0.05, 16], nil, nil, [0, 3, \lin, 0, 1], nil /*, [0.001, 40], [0.001, 40], [0, 2] */]);


//WrapInstr([\bass, \warm_atmos], {
// arg freq, gate, freqlag, 
// 
// 
//})
