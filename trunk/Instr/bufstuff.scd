Instr([\bufstuff, \delayWriter], {
 arg bus, // Bus object -- should be audio
 destBuf, // Buffer object
 delayTime;

 var index, sig;

 (bus.numChannels != destBuf.numChannels).if({
 "Can't build delayWriter: bus and buffer have different numChannels.".die;
 });
 
 sig = In.ar(bus.index, bus.numChannels);
 index = Phasor.ar(1, 1, 0, destBuf.numFrames, 0);
 BufWr.ar(DelayN.ar(sig, delayTime, delayTime), destBuf.bufnum, index, 1);
 SinOsc.ar(400, 0, 0); // should not make noise
// Out.ar(0, [0]);
}, #[nil, nil, [0, 5, \linear, 0, 1]]);


Instr("bufstuff.bufRollRLPF", { |bufnum, start, time = 1, rate = 1, amp = 1, strokesPerSec = 18,
 ffreqtop, rq, grainenv, ampenv, ffreqenv|
 var sig, 
 aenv = EnvGen.kr(ampenv, 1, timeScale: time, doneAction: 2),
 trig = Impulse.ar(strokesPerSec),
 grainlen = strokesPerSec.reciprocal,
 genv = EnvGen.ar(grainenv, trig, timeScale: grainlen),
 fenv = EnvGen.ar(ffreqenv, 1, timeScale: time);
 sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), trig, start, 1)
 * aenv * genv;
// I really want ffreqenv to be discontinuous but Latch seems broken in this context?
// now it's working, don't know why it failed before
 RLPF.ar(sig, ffreqtop * Latch.ar(fenv, trig), rq, amp)
}, [\mybuf, nil, [0, 10, \lin, 0, 1], \rate, \amp, [1.0, 32.0, \lin, 0, 18], \freq, \myrq, 
 // grainenv will scale 1.0 total time onto grain length
 // default is longer than 1.0 b/c no need to decay to 0 on each grain
 EnvSpec(Env.perc(0.01, 5.0)),
 // ampenv and ffreqenv will scale 1.0 total time onto time
 EnvSpec(Env(#[0.1, 1], #[1.0], 4)),
 EnvSpec(Env.one)
]);
