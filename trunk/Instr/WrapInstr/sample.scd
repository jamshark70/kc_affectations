WrapInstr([\sample, \fixedPitch], { arg freq, gate, // needed for voicer; freq is ignored
 startPos, rate, loop, numChan, bufnum, env; // rate adjustment is allowed
 var sig;
 sig = PlayBuf.ar(numChan, bufnum, rate*BufRateScale.kr(bufnum), 1.0, startPos, loop);
 sig * EnvGen.kr(env, gate, doneAction:2);
}, [\freq, [0, 1, \linear, 0, 1], [0, 10e10], [0.25, 4, \exponential, 0, 1], [0, -1, \linear, 1, 0],
 [0, 8, \linear, 1, 1], \mybuf, EnvSpec(Env.adsr(0.05, 1, 1, 0.05))]);

WrapInstr([\sample, \finitediskin], { arg bufnum = 0, numChan = 1, dur = 1;
 DiskIn.ar(numChan, bufnum)
 * EnvGen.kr(Env.linen(0.001, 0.998, 0.001), gate:1, timeScale:dur, doneAction:2);
}, #[\mybuf, \numChannels, [0, 1000]]);

WrapInstr([\sample, \gatediskin], { arg bufnum = 0, numChan = 1, gate, env;
 DiskIn.ar(numChan, bufnum) * EnvGen.kr(env, gate, doneAction:2);
}, [\mybuf, \numChannels, [0, 1], EnvSpec(Env.adsr(0.01, 1, 1, 0.1))]);

// holds for x amount of time, unless cutoff early by \n_set, \gate, 0
WrapInstr([\sample, \gatetimediskin], { arg bufnum = 0, numChan = 1, gate, dur, env;
 var trig = Trig.kr(1, dur) * gate.max(0);
 DiskIn.ar(numChan, bufnum) * EnvGen.kr(env, trig, doneAction:2);
}, [\mybuf, \numChannels, [0, 1], nil, EnvSpec(Env.adsr(0.01, 1, 1, 0.1))]);

WrapInstr([\sample, \timestretch], { arg freq, gate,
 startPos, rate, stretch, loop, numChan, bufnum, env; // stretch = 0.5, play twice as long
 var sig;
 sig = PlayBuf.ar(numChan, bufnum, rate*BufRateScale.kr(bufnum) * stretch,
 1.0, startPos, loop);
 PitchShift.ar(sig, pitchRatio: stretch.reciprocal) * EnvGen.kr(env, gate, doneAction:2);
}, [\freq, [0, 1], [0, 10e10], [0.25, 4, \exponential, 0, 1], [0.25, 4, \exponential, 0, 1],
 [0, -1, \linear, 1, 0], [0, 8, \linear, 1, 1], \mybuf, EnvSpec(Env.adsr(0.05, 1, 1, 0.05))]);

 // modulate rate of playback by a sine wave
WrapInstr([\sample, \fm1], { arg freq, gate,
 startPos, rate, loop, modfreq, modamp,
 numChan, bufnum, env;
 var ratemod;
 ratemod = SinOsc.kr(modfreq, 0, modamp, rate); // hover around input rate
 PlayBuf.ar(numChan, bufnum, ratemod * BufRateScale.kr(bufnum),
 1.0, startPos, loop) * EnvGen.kr(env, gate, doneAction:2);
}, [\freq, [0, 1], [0, 10e10], [0.25, 4, \exponential, 0, 1], [0, -1, \linear, 1, 0],
 [0.1, 100, \exponential, 0, 1], [0, 1],
 [0, 8, \linear, 1, 1], \mybuf, EnvSpec(Env.adsr(0.05, 1, 1, 0.05))]);

 // modulate rate of playback by a signal on a bus


 // modulate rate of playback by a signal in a buffer
