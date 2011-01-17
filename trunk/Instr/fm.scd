
Instr(#[fm, fmunit], { |car_oscil, mod_oscil, car_freq, mod_ratio, car_amp, mod_amp, car_bufnum, mod_bufnum|
 mod_oscil = mod_oscil.notNil.if({
 mod_oscil.value(car_freq * mod_ratio, mod_amp, mod_bufnum);
 }, {
 Osc.ar(mod_bufnum, car_freq * mod_ratio, 0, mod_amp)
 });
 car_oscil = car_oscil.notNil.if({
 car_oscil.value(car_freq * (1+mod_oscil), car_amp, car_bufnum);
 }, {
 Osc.ar(car_bufnum, car_freq * (1+mod_oscil), 0, car_amp)
 });
 car_oscil
}, [ObjectSpec.new(nil), ObjectSpec.new(nil), \freq, #[0.1, 50, \exp, 0.1, 1], \amp, \amp, \mybuf, \mybuf]);


Instr("fm.poink", { |freq, gate, mod_amp, mod_ratio, vsense, car_env, mod_env, modratio_env|
 Instr.wrap("fm.fmunit", [nil, nil, // use buffers instead of oscillators
 freq, mod_ratio * EnvGen.kr(modratio_env, gate),
 EnvGen.kr(car_env, gate, levelScale: Sensitivity.kr(1, gate, vsense), doneAction:2),
 mod_amp * EnvGen.kr(mod_env, gate)])
}, [\freq, \amp, #[0.01, 300, 'exp', 0, 0.01], #[0.1, 50, \exp, 0.1, 1], nil, EnvSpec(Env.adsr), EnvSpec(Env(#[1, 1], #[1])), EnvSpec(Env(#[1, 1], #[1]))]);
