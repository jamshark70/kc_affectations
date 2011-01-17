WrapInstr([\pads, \pulse2], {
 arg freq, freqlag, gate, ffreq, rq, velsense, env, fenv, detune, width, done = 2;
 var amp, sig;
 amp = Sensitivity.kr(1, Latch.kr(gate, gate), velsense);
 freq = Lag.kr(freq, freqlag);
 sig = Mix.ar(Pulse.ar([freq, freq*detune], width, amp));
 sig = RLPF.ar(sig, EnvGen.kr(fenv, gate) * ffreq, rq);
 sig = sig * EnvGen.kr(env, gate, doneAction:done);
}, #[\freq, [0, 2], \amp, \freq, [1, 0.05, \linear, 0, 0.5], \amp, nil, nil, [0.98, 1.02, \linear, 0, 1], [0, 1], [0, 12, \linear, 1, 2]]);

//.miditest(0, [\env, Env.adsr(0, 0.1, 0.75, 0.01), \fenv, Env.adsr(0.15, 0.2, 0.6, 50)], target:m);
