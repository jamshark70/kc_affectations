// arg freq = 440, gate = 0, env, amp = 1, pb = 1, ffreq = 1000, rq = 1;
// var out;
// out = EnvGen.kr(env, gate, doneAction:2) *
// RLPF.ar(Pulse.ar(freq * pb, 0.25, amp), ffreq, rq);
// [out,out]
//}, [\freq, \amp, nil, nil, nil, \freq, [1, 0.05]]);
//
//WrapInstr([\test, \seqpantest], {
// arg freq = 440, gate = 0, env, amp = 1, ffreq = 1000, rq = 1, pan = 0;
// var out;
// out = EnvGen.kr(env, gate, doneAction:2) *
// RLPF.ar(Pulse.ar(freq, 0.25, amp), ffreq, rq);
// Pan2.ar(out, pan)
//}, [\freq, \amp, nil, nil, \freq, [1, 0.05], [-1, 1]]);

var sens;

sens = { arg scaler, value, sense;
 (scaler == 0).if({
 1
 }, {
 (scaler == 1).if({
 (value-1) * sense + 1
 }, {
 scaler * ((value - 1) * sense + 1)
 })
 });
};

WrapInstr([\test, \tuner], {
 arg freq, gate, env, vsens, detune;
 var out, amp;
 amp = Latch.kr(sens.value(1, gate, vsens), gate);
 out = SinOsc.ar(freq * detune, 0, amp)
 * EnvGen.kr(env, gate, doneAction:2);
 [out,out]
}, [\freq, \amp, EnvSpec.new(Env.adsr(0.05, 0, 1, 0.1)), [0, 1], [-1.midiratio, 1.midiratio, \exponential, 0, 1]]);
