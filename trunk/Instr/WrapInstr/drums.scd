// drum synths

WrapInstr("drums.statickik2", { |basefreq = 50, depth = 100, fallratio, beatertime, falltime, attack, time, decay, rq, preamp, postamp, amp = 1|
 var topfreq = basefreq * depth,
 freq = EnvGen.kr(Env([topfreq, topfreq, basefreq, basefreq * fallratio],
 [0.003, beatertime, falltime], \exp)),
 sig = SinOsc.ar(freq, 0.5pi),
 noise = BPF.ar(PinkNoise.ar, freq, rq, preamp).distort * postamp;
 sig = sig + noise;
 sig * amp * EnvGen.kr(Env(#[0, 1, 0.8, 0], [attack, time, decay], -2), 1, doneAction:2);
}, [#[20, 300, exp, 0, 50], #[1, 500, \exp, 0, 100], #[0.1, 1.0, \exp, 0, 1], #[0.001, 0.5, \exp, 0, 0.01], #[0.1, 10, \exp, 0, 1], #[0.001, 0.5, \exp, 0, 0.005], #[0.001, 0.5, \exp, 0, 0.1], #[0.001, 0.5, \exp, 0, 0.2], \myrq, #[0.01, 100, \exp, 0, 1], #[0.01, 100, \exp, 0, 1], \amp]);

WrapInstr("drums.statickik", { |basefreq = 50, depth = 100, fallratio, beatertime, falltime, attack, time, decay, rq, preamp, postamp, amp = 1|
 var freq = EnvGen.kr(Env([basefreq * depth, basefreq, basefreq * fallratio],
 [beatertime, falltime], \exp)),
 sig = SinOsc.ar(freq, 0.5pi),
 noise = BPF.ar(PinkNoise.ar, freq, rq, preamp).distort * postamp;
 sig = sig + noise;
 sig * amp * EnvGen.kr(Env(#[0, 1, 0.8, 0], [attack, time, decay], -2), 1, doneAction:2);
}, [#[20, 300, exp, 0, 50], #[1, 500, \exp, 0, 100], #[0.1, 1.0, \exp, 0, 1], #[0.001, 0.5, \exp, 0, 0.01], #[0.1, 10, \exp, 0, 1], #[0.001, 0.5, \exp, 0, 0.005], #[0.001, 0.5, \exp, 0, 0.1], #[0.001, 0.5, \exp, 0, 0.2], \myrq, #[0.01, 100, \exp, 0, 1], #[0.01, 100, \exp, 0, 1], \amp]);


WrapInstr("drums.statickiktest", { |basefreq = 50, depth = 100, fallratio, beatertime, falltime, attack, time, decay, rq, preamp, postamp, amp = 1, trig|
 var topfreq = basefreq * depth,
 freq = EnvGen.kr(Env([topfreq, topfreq, basefreq, basefreq * fallratio],
 [0.003, beatertime, falltime], \exp), trig),
 sig = SinOsc.ar(freq, 0.5pi),
 noise = BPF.ar(PinkNoise.ar, freq, rq, preamp).distort * postamp;
 sig = sig + noise;
 sig * amp * EnvGen.kr(Env(#[0, 1, 0.8, 0], [attack, time, decay], -2), trig);
}, [#[20, 300, exp, 0, 50], #[1, 500, \exp, 0, 100], #[0.1, 1.0, \exp, 0, 1], #[0.001, 0.5, \exp, 0, 0.01], #[0.1, 10, \exp, 0, 1], #[0.001, 0.5, \exp, 0, 0.005], #[0.001, 0.5, \exp, 0, 0.1], #[0.001, 0.5, \exp, 0, 0.2], \myrq, #[0.01, 100, \exp, 0, 1], #[0.01, 100, \exp, 0, 1], \amp, TrigSpec()]);

WrapInstr("drums.statickiktest_startlow", { |basefreq = 50, depth = 100, fallratio, beatertime, falltime, attack, time, decay, rq, preamp, postamp, amp = 1, trig|
 var topfreq = basefreq * depth,
 freq = EnvGen.kr(Env([basefreq, topfreq, basefreq, basefreq * fallratio],
 [0.003, beatertime, falltime], \exp), trig),
 sig = SinOsc.ar(freq, 0.5pi),
 noise = BPF.ar(PinkNoise.ar, freq, rq, preamp).distort * postamp;
 sig = sig + noise;
 sig * amp * EnvGen.kr(Env(#[0, 1, 0.8, 0], [attack, time, decay], -2), trig);
}, [#[20, 300, exp, 0, 50], #[1, 500, \exp, 0, 100], #[0.1, 1.0, \exp, 0, 1], #[0.001, 0.5, \exp, 0, 0.01], #[0.1, 10, \exp, 0, 1], #[0.001, 0.5, \exp, 0, 0.005], #[0.001, 0.5, \exp, 0, 0.1], #[0.001, 0.5, \exp, 0, 0.2], \myrq, #[0.01, 100, \exp, 0, 1], #[0.01, 100, \exp, 0, 1], \amp, TrigSpec()]);

WrapInstr("drums.statickik2_startlow", { |basefreq = 50, depth = 100, fallratio, beatertime, falltime, attack, time, decay, rq, preamp, postamp, amp = 1|
 var topfreq = basefreq * depth,
 freq = EnvGen.kr(Env([topfreq, topfreq, basefreq, basefreq * fallratio],
 [0.003, beatertime, falltime], \exp)),
 sig = SinOsc.ar(freq, 0.5pi),
 noise = BPF.ar(PinkNoise.ar, freq, rq, preamp).distort * postamp;
 sig = sig + noise;
 sig * amp * EnvGen.kr(Env(#[0, 1, 0.8, 0], [attack, time, decay], -2), 1, doneAction:2);
}, [#[20, 300, exp, 0, 50], #[1, 500, \exp, 0, 100], #[0.1, 1.0, \exp, 0, 1], #[0.001, 0.5, \exp, 0, 0.01], #[0.1, 10, \exp, 0, 1], #[0.001, 0.5, \exp, 0, 0.005], #[0.001, 0.5, \exp, 0, 0.1], #[0.001, 0.5, \exp, 0, 0.2], \myrq, #[0.01, 100, \exp, 0, 1], #[0.01, 100, \exp, 0, 1], \amp]);

WrapInstr("drums.statkffreq", { |basefreq = 50, depth = 100, fallratio, beatertime, falltime, attack, time, decay, ffreq, rq, preamp, postamp, amp = 1|
 var freqenv = EnvGen.kr(Env([depth, 1, fallratio], [beatertime, falltime], \exp)),
 freq = basefreq * freqenv,
 sig = SinOsc.ar(freq, 0.5pi),
 noise = BPF.ar(PinkNoise.ar, (ffreq * freqenv).clip(20, 20000), rq, preamp)
 .distort * postamp;
 sig = sig + noise;
 sig * amp * EnvGen.kr(Env(#[0, 1, 0.8, 0], [attack, time, decay], -2), 1, doneAction:2);
}, [#[20, 300, exp, 0, 50], #[1, 500, \exp, 0, 100], #[0.1, 1.0, \exp, 0, 1], #[0.001, 0.5, \exp, 0, 0.01], #[0.1, 10, \exp, 0, 1], #[0.001, 0.5, \exp, 0, 0.005], #[0.001, 0.5, \exp, 0, 0.1], #[0.001, 0.5, \exp, 0, 0.2], \freq, \myrq, #[0.01, 100, \exp, 0, 1], #[0.01, 100, \exp, 0, 1], \amp]);

//WrapInstr("drums.statkffreq", { |basefreq = 50, depth = 100, fallratio, beatertime, falltime, attack, time, decay, ffreq, rq, preamp, postamp|
// var freq = EnvGen.kr(Env([basefreq * depth, basefreq, basefreq * fallratio],
// [beatertime, falltime], \exp)),
// sig = SinOsc.ar(freq, 0.5pi),
// noise = BPF.ar(PinkNoise.ar, ffreq, rq, preamp).distort * postamp;
// sig = sig + noise;
// sig * EnvGen.kr(Env(#[0, 1, 0.8, 0], [attack, time, decay], -2), 1, doneAction:2);
//}, [#[20, 300, exp, 0, 50], #[1, 500, \exp, 0, 100], #[0.1, 1.0, \exp, 0, 1], #[0.001, 0.5, \exp, 0, 0.01], #[0.1, 10, \exp, 0, 1], #[0.001, 0.5, \exp, 0, 0.005], #[0.001, 0.5, \exp, 0, 0.1], #[0.001, 0.5, \exp, 0, 0.2], \freq, \myrq, #[0.01, 100, \exp, 0, 1], #[0.01, 100, \exp, 0, 1]]);


// not really "drum" -- Karplus-Strong chord with random panning and note onsets
Spec.specs.put(\shorttime, ControlSpec(0.001, 0.2, \exp, 0, 0.01));

WrapInstr("drums.monocomb", { |freq = 440, decay = 0.1, amp = 1, ampcorrexn = 1, lowfreq = 1000, hifreq = 12000,
 ampffreqsens = 0,
 excattack = 0.001, excdecay = 0.05, combratio = 0.75, lowsplay = 0.003, hisplay = 0.05|
 var exc = LPF.ar(PinkNoise.ar, LinExp.kr(Rand(0, 1), 0, 1, lowfreq, hifreq)
 * Sensitivity.kr(1, amp, ampffreqsens))
 * EnvGen.ar(Env.perc(excattack, excdecay)),
 sig = CombL.ar(exc, 0.1, (Array.geom(4, 1, combratio) * freq).reciprocal, decay);
 sig = DelayN.ar(sig, 0.1, { Rand(lowsplay, hisplay) } ! 4);
 sig = amp * ampcorrexn * Mix(sig);
 DetectSilence.ar(sig, doneAction:2);
 sig
}, [\freq, \shorttime, \amp, \amp, \freq, \freq, nil, \shorttime, \shorttime, [0.5, 1.0], \shorttime, \shorttime]);

WrapInstr("drums.stereocomb", { |freq = 440, decay = 0.1, amp = 1, ampcorrexn = 1, lowfreq = 1000, hifreq = 12000,
 ampffreqsens = 0,
 excattack = 0.001, excdecay = 0.05, combratio = 0.75, lowsplay = 0.003, hisplay = 0.05,
 panbias = 0, panwidth = 0|
 var exc = LPF.ar(PinkNoise.ar, LinExp.kr(Rand(0, 1), 0, 1, lowfreq, hifreq)
 * Sensitivity.kr(1, amp, ampffreqsens))
 * EnvGen.ar(Env.perc(excattack, excdecay)),
 sig = CombL.ar(exc, 0.1, (Array.geom(4, 1, combratio) * freq).reciprocal, decay);
 sig = DelayN.ar(sig, 0.1, { Rand(lowsplay, hisplay) } ! 4);
 panwidth = panwidth * (1.0 - panbias.abs);
 sig = sig.collect({ |chan| Pan2.ar(chan, Rand(panwidth.neg, panwidth) + panbias) });
 sig = amp * ampcorrexn * Mix(sig);
 DetectSilence.ar(sig, doneAction:2);
 sig
}, [\freq, \shorttime, \amp, \amp, \freq, \freq, nil, \shorttime, \shorttime, [0.5, 1.0], \shorttime, \shorttime, \bipolar, nil]);


WrapInstr("drums.tuneklank", { |klankspecs, freq, time, env, amp|
 // env should total 1.0 sec
 // future: use decayscale to compensate: higher frequencies have a more pronounced ring
 Klank.ar(`klankspecs, PinkNoise.ar, freqscale: freq)
 * EnvGen.kr(env, 1, timeScale: time, doneAction: 2)
 * amp
}, [ObjectSpec(#[[1], [1], [1]]), \freq, #[0.01, 10, \lin, 0, 1], EnvSpec(Env.perc(0.01, 0.99))]);

WrapInstr("drums.tuneklfenv", { |ffreq, rq, fenv, time|
 var sig = WrapInstr.wrap("drums.tuneklank", [nil, nil, time]),
 cutoff = ffreq * EnvGen.kr(fenv, 1, timeScale: time);
 RLPF.ar(sig, cutoff, rq)
}, [\freq, \myrq, EnvSpec(Env.one), #[0.01, 10, \lin, 0, 1]]);

