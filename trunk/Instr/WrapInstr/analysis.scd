// analysis-related WrapInstr's

// outputs a kr envelope gated by a signal's amplitude
WrapInstr([\analysis, \ampEnv], { |bus, numChan = 1, env, topValue, lowRatio, thresh = 0.5,
 attack = 2, decay = 3, sustain = 0.8, release = 4, ampRelease = 0.5, envCurve|
 var gate;
 gate = Amplitude.kr(In.ar(bus, 1), releaseTime:ampRelease) > thresh;
 // you can have controls for some envelope parameters
 // if you pass in an Env, value is ignored
 env = env.value(lowRatio, attack, decay, sustain, release, envCurve);
 EnvGen.kr(env, gate) * topValue
}, [\audiobus, \numChannels,
 ObjectSpec({ |lowRatio, attack, decay, sustain, release, envCurve|
 Env([lowRatio, 1, sustain, lowRatio], [attack, decay, release],
 curve:envCurve, releaseNode:2)
 }),
 nil, nil, nil, nil, nil, nil, nil, #[0.001, 2, \lin, 0.01, 0.5], ObjectSpec(\linear)]
);


WrapInstr("analysis.jensen", { |bufnum, fftbuf, propsc = 0.25, prophfe = 0.25, prophfc = 0.25, propsf = 0.25,
 threshold = 1.0, waittime = 0.04|
 var bufdur = BufDur.kr(bufnum),
 time = Line.kr(0, bufdur, bufdur, doneAction:2),
 sig = PlayBuf.ar(1, bufnum),
 fft = FFT(fftbuf, sig),
 trig = PV_JensenAndersen.ar(fft, propsc, prophfe, prophfc, propsf, threshold, waittime);
 SendTrig.kr(A2K.kr(trig), 0, time - (BufDur.kr(fftbuf) * 0.5));
 sig ! 2;
}, [\mybuf, \mybuf]);


WrapInstr("analysis.jensen-disk", { |bufnum, fftbuf, propsc = 0.25, prophfe = 0.25, prophfc = 0.25, propsf = 0.25,
 threshold = 1.0, waittime = 0.04|
 var time = Line.kr(0, 2**16, 2**16, doneAction:2),
 sig = DiskIn.ar(1, bufnum),
 fft = FFT(fftbuf, sig),
 trig = PV_JensenAndersen.ar(fft, propsc, prophfe, prophfc, propsf, threshold, waittime);
 SendTrig.kr(A2K.kr(trig), 0, time - (BufDur.kr(fftbuf) * 0.5));
 sig ! 2;
}, [\mybuf, \mybuf]);


WrapInstr("analysis.jensen-live", { |bus, fftbuf, propsc = 0.25, prophfe = 0.25, prophfc = 0.25, propsf = 0.25,
 threshold = 1.0, waittime = 0.04|
 var time = Line.kr(0, 10000, 10000, doneAction:2),
 sig = In.ar(bus, 1),
 fft = FFT(fftbuf, sig),
 trig = PV_JensenAndersen.ar(fft, propsc, prophfe, prophfc, propsf, threshold, waittime);
 SendTrig.kr(A2K.kr(trig), 0, time - (BufDur.kr(fftbuf) * 0.5));
 sig ! 2;
}, [\mybuf, \mybuf]);


WrapInstr("analysis.triggerfinder", { |bufnum, thresh, attack, release, timeBetween|
 var sig = PlayBuf.ar(1, bufnum),
 bufdur = BufDur.kr(bufnum),
 time = Line.kr(0, bufdur, bufdur, doneAction: 2),
 amp = Amplitude.kr(sig, attack, release),
 trig = amp >= thresh,
 lastTrigTime = Latch.kr(time, Delay1.kr(trig)),
 sendTrig = (time - lastTrigTime) >= timeBetween;
 SendTrig.kr(sendTrig * trig, 0, time);
 sig
}, [\mybuf, nil, [0.0001, 1.0, \exp], [0.0001, 1.0, \exp], nil]);

WrapInstr("analysis.triggerfinder-disk", { |bufnum, thresh, attack, release, timeBetween|
 var sig = DiskIn.ar(1, bufnum),
 bufdur = BufDur.kr(bufnum),
 time = Line.kr(0, bufdur, bufdur, doneAction: 2),
 amp = Amplitude.kr(sig, attack, release),
 trig = amp >= thresh,
 lastTrigTime = Latch.kr(time, Delay1.kr(trig)),
 sendTrig = (time - lastTrigTime) >= timeBetween;
 SendTrig.kr(sendTrig * trig, 0, time);
 sig
}, [\mybuf, nil, [0.0001, 1.0, \exp], [0.0001, 1.0, \exp], nil]);

