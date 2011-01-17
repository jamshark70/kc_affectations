Instr([\noise, \rlpfed], { arg noiseClass, freq, gate, rq, env, vsens, done;
 RLPF.ar(noiseClass.ar(Latch.kr(Sensitivity.kr(1, gate, vsens), gate)), freq, rq)
 * EnvGen.kr(env, gate, doneAction:done)
}, [nil, \freq, \amp, [1, 0.001], nil, nil, [0, 12, \linear, 1, 2]]);

Instr([\noise, \resonz], { arg noiseClass, freq, gate, rq, env, vsens, done;
 Resonz.ar(noiseClass.ar(Latch.kr(Sensitivity.kr(1, gate, vsens), gate)), freq, rq)
 * EnvGen.kr(env, gate, doneAction:done)
}, [nil, \freq, \amp, [1, 0.001], nil, nil, [0, 12, \linear, 1, 2]]);

