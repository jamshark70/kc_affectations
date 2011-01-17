Instr([\analog, \pulselead], { arg freq, gate, freqlag, env, fenv, ffreq, rq, width, vsens, fenvsens, detune;
 var sig, amp, fcurve;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 freq = Lag.kr(freq, freqlag);
 fcurve = Sensitivity.kr(ffreq, amp, fenvsens) * EnvGen.kr(fenv, gate);
 sig = Mix.ar(Pulse.ar([freq, freq*detune], width, amp));
 sig = RLPF.ar(sig, fcurve, rq) * EnvGen.kr(env, gate, doneAction:2);
}, [\freq, \amp, [0.00001, 20, \exponential], EnvSpec(Env.adsr), EnvSpec(Env.one), \freq, [1, 0.001], [0.0001, 0.9999], nil, nil, \mydetune]);


Instr([\analog, \sawpulse], { arg freq, gate, freqlag, env, fenv, ffreq, rq, width, vsens, fenvsens, detune, pb, plfofreq, mw, plfoClass;
 var sig, plfo, amp, fcurve;
 amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
 plfo = plfoClass.kr(plfofreq, mul:mw, add:1);
 freq = Lag.kr(freq, freqlag) * pb * plfo; // pb = pitch bend factor
 fcurve = Sensitivity.kr(ffreq, EnvGen.kr(fenv, gate), fenvsens);
 sig = Mix.ar([Pulse.ar(freq, width), Saw.ar(freq*detune)]);
 sig = RLPF.ar(sig, fcurve, rq) * EnvGen.kr(env, gate, doneAction:2) * amp;
}, #[\freq, \amp, [0.000001, 20, \exponential], nil, nil, \freq, [1, 0.001], [0.0001, 0.9999], nil, nil, \mydetune, nil, [0, 10], [0, 0.1], nil]);


Instr([\analog, \harmonic], { arg freq, gate, freqlag, fundfreq, widthfreq, env, vsense, detune;
 var amp;
 amp = Sensitivity.kr(1, Latch.kr(gate, gate), vsense);
 Formant.ar([fundfreq, fundfreq*detune], freq, widthfreq, amp * 0.5)
 * EnvGen.kr(env, gate, doneAction:2)
}, [\freq, [0, 1], [0, 10], \freq, \freq, EnvSpec(Env.adsr(0.01, 1, 0.75, 0.1)), [0, 1], \mydetune]);


Instr([\analog, \formlet], { arg freq, gate, freqlag, fundfreq, attacktime, decaytime,
 env, vsense, detune;
 var amp;
 amp = Sensitivity.kr(1, Latch.kr(gate, gate), vsense);
 Formlet.ar(Blip.ar([fundfreq, fundfreq*detune], 200, amp), freq, attacktime, decaytime)
 * EnvGen.kr(env, gate, doneAction:2);
}, [\freq, [0, 1], [0, 10], \freq, [0.001, 1, \exponential], [0.001, 1, \exponential], EnvSpec(Env.adsr(0.01, 1, 0.75, 0.1)), [0, 1], \mydetune]);


Instr([\analog, \formletbydiff], { arg freq, gate, freqlag, fundfreq, attacktime, decayadd,
 env, vsense, detune;
 var amp;
 amp = Sensitivity.kr(1, Latch.kr(gate, gate), vsense);
 Formlet.ar(Blip.ar([fundfreq, fundfreq*detune], 200, amp), freq, attacktime,
 attacktime + decayadd)
 * EnvGen.kr(env, gate, doneAction:2);
}, [\freq, [0, 1], [0, 10], \freq, [0.001, 1, \exponential], [0.001, 1, \exponential], EnvSpec(Env.adsr(0.01, 1, 0.75, 0.1)), [0, 1], \mydetune]);


Instr([\analog, \ghostly], { arg freq, gate, freqlag, attacktime, decaytime, env, vsense, mul = 1;
 var amp;
 amp = Sensitivity.kr(1, Latch.kr(gate, gate), vsense);
 Mix.ar(Formlet.ar(PinkNoise.ar([0.2, 0.2]), freq, attacktime, decaytime, mul))
 * EnvGen.kr(env, gate, doneAction:2) * amp
}, [\freq, [0, 1], [0, 2], [0.001, 2, \exponential], [0.001, 2, \exponential], EnvSpec(Env.adsr(0.01, 1, 0.75, 0.1)), [0, 1], [0, 1]]);


// not unlike CHANT but very cpu efficient: 4 formHarmRatios = c. 2.5% cpu with default exciter

Instr([\analog, \voxlet], { |freq, gate, freqlag, exciterFunc, detune, formfreq, formfreqlag, ffreq, env, formfreqenv, attacktime, decaytime, vsens, fenvsens, formHarmRatios, formHarmAmps, vibRate, vibAmp|
 var amp, sig;
 formfreq = Lag.kr(formfreq, formfreqlag);
 formfreq = formfreq * (1 + Sensitivity.kr(1, EnvGen.kr(formfreqenv, gate), fenvsens));
 freq = Lag.kr(freq, freqlag);
 (vibAmp != 0).if({ freq = freq * SinOsc.kr(vibRate, 0, vibAmp, 1) });
 amp = Sensitivity.kr(1, Latch.kr(gate, gate), vsens);
 sig = exciterFunc.value(freq, detune);
 sig = Formlet.ar(sig,
 formHarmRatios.notNil.if({ formfreq * formHarmRatios }, { formfreq }), 
 attacktime, decaytime, mul: formHarmAmps ?? { 1 });
 // formlet is a bit volatile, so limit its amplitude
 Limiter.ar(LPF.ar(Mix.ar(sig), ffreq), 0.9)
 * EnvGen.kr(env, gate, doneAction:2)
}, [
 \freq,
 \amp,
 \amp,
 ObjectSpec({ |fr| Impulse.ar(fr) }), // override this with a func for a different exciter
 \mydetune,
 \freq,
 \amp,
 #[20, 20000, \exp, 0, 1200],
 EnvSpec(Env.adsr(0.07, 0.2, 0.8, 0.11)),
 EnvSpec(Env(#[1, 1], [1])),
 #[0, 1, \exp, 0, 0.01],
 #[0, 1, \exp, 0, 0.1],
 ObjectSpec(nil),
 ObjectSpec(nil),
 #[0.1, 20],
 \amp
]);


// a variant that randomly modulates the formant frequency

Instr([\analog, \voxlet_modformfreq], { |freq, gate, freqlag, exciterFunc, detune, formfreq, formfreqlag, ffreq, env, formfreqenv, attacktime, decaytime, vsens, fenvsens, formHarmRatios, formHarmAmps, vibRate, vibAmp|
 var amp, sig, formfreqrand, freqtrig;
 freqtrig = HPZ1.kr(freq).abs;
 formfreqrand = TRand.kr(-0.5, 1, freqtrig + Dust.kr(1.4));
 formfreq = formfreq * (EnvGen.kr(formfreqenv, gate).madd(fenvsens * formfreqrand, 1));
 formfreq = Lag.kr(formfreq, formfreqlag);
 freq = Lag.kr(freq, freqlag);
 (vibAmp != 0).if({ freq = freq * SinOsc.kr(vibRate, 0, vibAmp, 1) });
 amp = Sensitivity.kr(1, Latch.kr(gate, gate), vsens);
 sig = exciterFunc.value(freq, detune);
 sig = Formlet.ar(sig,
 formHarmRatios.notNil.if({ formfreq * formHarmRatios }, { formfreq }), 
 attacktime, decaytime, mul: formHarmAmps ?? { 1 });
 // formlet is a bit volatile, so limit its amplitude
 Limiter.ar(LPF.ar(Mix.ar(sig), ffreq), amp)
 * EnvGen.kr(env, gate, doneAction:2)
}, [ \freq,
 \amp,
 \amp,
 ObjectSpec(#{ |fr| Impulse.ar(fr) }), // override this with a func for a different exciter
 \mydetune,
 \freq,
 \amp,
 #[20, 20000, \exp, 0, 1200],
 EnvSpec(Env.adsr(0.07, 0.2, 0.8, 0.27)),
 EnvSpec(Env(#[0, 0], [1])),
 #[0.0001, 1, \exp, 0, 0.01],
 #[0.0001, 1, \exp, 0, 0.1],
 \amp,
 \amp,
 ObjectSpec(nil),
 ObjectSpec(nil),
 #[0.1, 20],
 \amp
]);
