// var trig, sig, startPos, len, rate;
//// trig = Dust.kr(dustFreq); // when to fire the next grain
// // trig should be regular but randomized around the center == grainFreq
// trig = Impulse.kr(LFNoise1.kr(grainFreq, freqRange, grainFreq));
// len = grainLen + TRand.kr(lenRandomizer.neg, lenRandomizer, trig); // how long
// // where to start in buffer
// startPos = TRand.kr(0, buf.bufFramesKr - len * buf.sampleRateKr, trig); rate = 1 + TRand.kr(rateRandomizer.neg.max(-0.99999), rateRandomizer, trig); // how fast
// 
// sig = PlayBuf.ar(buf.numChannels, buf.bufnumIr, buf.bufRateScaleKr * rate,
// trig, startPos, 1)
// * EnvGen.kr(env, trig, timeScale: len, doneAction:0); // window it
//}, [\buffer, [0.05, 100, \exponential, 0, 10], [0, 50, \linear, 0, 0], EnvSpec(Env.linen(0.1, 0.8, 0.1)), [0.001, 2, \exponential, 0, 0.2], [0, 2], [0, 5]]);

 // un-randomizing triggers, removing rate randomizer
 // now using Phasor so startPos has an effect
 // buf should be a Sample
Instr([\grain, \singlebuf], { arg buf, grainFreq, env, grainLen, startOffset, startRandomizer, lenRandomizer;
 var trig, sig, startPos, len, index, sampRate;
// sampRate = buf.sampleRateKr; // ugen needs to be shared
 trig = Impulse.kr(grainFreq);
 // how long--give max and this reduces it
 len = (grainLen - TRand.kr(0, lenRandomizer, trig)).clip(0, grainFreq.reciprocal);
 // where to start in buffer
 startPos = TRand.kr(startOffset * buf.bufFramesKr, startRandomizer * buf.bufFramesKr, trig);
 index = Phasor.ar(trig, buf.bufRateScaleKr, 0, buf.bufFramesKr, 0) + startPos;

 sig = BufRd.ar(buf.numChannels, buf.bufnumKr, index, 0)
 * EnvGen.kr(env, trig, timeScale: len, doneAction:0); // window it
}, [ \buffer, // 0:buffer
 [0.05, 100, \exponential, 0, 10], // 1:grainFreq
 EnvSpec(Env.linen(0.1, 0.8, 0.1)), // 2:env -- fixed len, should total 1sec
 [0.001, 2, \exponential, 0, 0.2], // 3:grainLen
 [0, 1], // 4:startOffset
 [0, 1], // 5:startRandomizer
 [0, 2] // 6:lenRandomizer -- should not exceed grainLen
 ]
);

 // same as above but without using Sample
Instr([\grain, \singlebuf2], { arg bufnum, numChannels, grainInterval, env, grainLen, startOffset, startRandomizer, lenRandomizer, panRange;
 var trig, sig, startPos, len, index, sampRate, pan, bufLen;
 var panFuncs;
 panFuncs = [nil, // 0 channels, irrelevant
 { arg sig, pan; Pan2.ar(sig, pan) },
 { arg sig, pan; Balance2.performList(\ar, sig ++ [pan]) }
 ];
// sampRate = BufSampleRate.kr(bufnum); // ugen needs to be shared
 bufLen = BufFrames.kr(bufnum);
 trig = Impulse.kr(grainInterval.reciprocal);
 // how long--give max and this reduces it
 len = (grainLen - TRand.kr(0, lenRandomizer, trig)); // .clip(0, grainFreq.reciprocal);
 // where to start in buffer
 startPos = TRand.kr(startOffset * bufLen, startRandomizer * bufLen, trig);
 index = Phasor.ar(trig, BufRateScale.kr(bufnum), 0, bufLen, 0) + startPos;
 pan = TRand.kr(panRange.neg, panRange, trig);

 sig = BufRd.ar(numChannels, bufnum, index, 0)
 * EnvGen.kr(env, trig, timeScale: len, doneAction:0); // window it
 panFuncs.at(numChannels).value(sig, pan);
}, [ [0, 200, \linear, 1, 0], // 0:buffer num, must be integer
 [0, 8, \linear, 1, 1], // 1:numChannels
 [0.05, 100, \exponential, 0, 10], // 2:grainFreq
 EnvSpec(Env.linen(0.1, 0.8, 0.1)), // 3:env -- fixed len, should total 1sec
 [0.001, 2, \exponential, 0, 0.2], // 4:grainLen
 [0, 1], // 5:startOffset
 [0, 1], // 6:startRandomizer
 [0, 2], // 7:lenRandomizer -- should not exceed grainLen
 [0, 1] // 8:panRange
 ]
);

// grainLen expressed as proportion of grainInterval
Instr([\grain, \singlebuf3], { arg bufnum, numChannels, grainInterval, env, grainLen, startOffset, startRandomizer, lenRandomizer, panRange;
 var trig, sig, startPos, len, index, sampRate, pan, bufLen;
 var panFuncs;
 panFuncs = [nil, // 0 channels, irrelevant
 { arg sig, pan; Pan2.ar(sig, pan) },
 { arg sig, pan; Balance2.performList(\ar, sig ++ [pan]) }
 ];
// sampRate = BufSampleRate.kr(bufnum); // ugen needs to be shared
 bufLen = BufFrames.kr(bufnum);
 grainLen = grainLen * grainInterval;
 trig = Impulse.kr(grainInterval.reciprocal);
 // how long--give max and this reduces it
 len = (grainLen - TRand.kr(0, lenRandomizer, trig)); // .clip(0, grainFreq.reciprocal);
 // where to start in buffer
 startPos = TRand.kr(startOffset * bufLen, startRandomizer * bufLen, trig);
 index = Phasor.ar(trig, BufRateScale.kr(bufnum), 0, bufLen, 0) + startPos;
 pan = TRand.kr(panRange.neg, panRange, trig);

 sig = BufRd.ar(numChannels, bufnum, index, 1)
 * EnvGen.kr(env, trig, timeScale: len, doneAction:0); // window it
 panFuncs.at(numChannels).value(sig, pan);
}, [ [0, 200, \linear, 1, 0], // 0:buffer num, must be integer
 [0, 8, \linear, 1, 1], // 1:numChannels
 [0.05, 100, \exponential, 0, 10], // 2:grainFreq
 EnvSpec(Env.linen(0.1, 0.8, 0.1)), // 3:env -- fixed len, should total 1sec
 [0.001, 1, \exponential, 0, 0.8], // 4:grainLen -- proportion of grainInterval
 [0, 1], // 5:startOffset
 [0, 1], // 6:startRandomizer
 [0, 2], // 7:lenRandomizer -- should not exceed grainLen
 [0, 1] // 8:panRange
 ]
);


Instr([\grain, \singlebufpart], { arg bufnum, startFrame, numChannels, grainInterval, env, grainLen, startRandomizer, lenRandomizer, panRange, bufLen;
 var trig, sig, startPos, len, index, sampRate, pan, bufFr;
 var panFuncs;
 panFuncs = [nil, // 0 channels, irrelevant
 { arg sig, pan; Pan2.ar(sig, pan) },
 { arg sig, pan; Balance2.performList(\ar, sig ++ [pan]) }
 ];
 sampRate = BufSampleRate.kr(bufnum); // ugen needs to be shared
 bufFr = BufFrames.kr(bufnum) - startFrame;
 bufLen = bufLen ? bufFr;
 trig = Impulse.kr(grainInterval.reciprocal);
 // how long--give max and this reduces it
 len = (grainLen - TRand.kr(0, lenRandomizer, trig)); // .clip(0, grainFreq.reciprocal);
 // where to start in buffer
 startPos = TRand.kr(startFrame, startFrame + (startRandomizer * bufLen), trig);
 index = Phasor.ar(trig, BufRateScale.kr(bufnum), 0, bufLen, 0) + startPos;
 pan = TRand.kr(panRange.neg, panRange, trig);

 sig = BufRd.ar(numChannels, bufnum, index, 0)
 * EnvGen.kr(env, trig, timeScale: len, doneAction:0); // window it
 panFuncs.at(numChannels).value(sig, pan);
}, [ [0, 200, \linear, 1, 0], // 0:buffer num, must be integer
 [0, 2**30, \linear, 1, 0], // 1:starting frame in buffer
 [0, 8, \linear, 1, 1], // 2:numChannels
 [0.05, 100, \exponential, 0, 10], // 3:grainFreq
 EnvSpec(Env.linen(0.1, 0.8, 0.1)), // 4:env -- fixed len, should total 1sec
 [0.001, 2, \exponential, 0, 0.2], // 5:grainLen
 [0, 1], // 7:startRandomizer
 [0, 2], // 8:lenRandomizer -- should not exceed grainLen
 [0, 1] // 9:panRange
 ]
);


 // same as above but using a static pan arg
Instr([\grain, \singlebufStaticPan], { arg bufnum, numChannels, grainInterval, env, grainLen, startOffset, startRandomizer, lenRandomizer, pan;
 var trig, sig, startPos, len, index, sampRate, bufLen;
 var panFuncs;
 panFuncs = [nil, // 0 channels, irrelevant
 { arg sig, pan; Pan2.ar(sig, pan) },
 { arg sig, pan; Balance2.performList(\ar, sig ++ [pan]) }
 ];
 sampRate = BufSampleRate.kr(bufnum); // ugen needs to be shared
 bufLen = BufFrames.kr(bufnum);
 trig = Impulse.kr(grainInterval.reciprocal);
 // how long--give max and this reduces it
 len = (grainLen - TRand.kr(0, lenRandomizer, trig)); // .clip(0, grainFreq.reciprocal);
 // where to start in buffer
 startPos = TRand.kr(startOffset * bufLen, startRandomizer * bufLen, trig);
 index = Phasor.ar(trig, BufRateScale.kr(bufnum), 0, bufLen, 0) + startPos;

 sig = BufRd.ar(numChannels, bufnum, index, 0)
 * EnvGen.kr(env, trig, timeScale: len, doneAction:0); // window it
 panFuncs.at(numChannels).value(sig, pan);
}, [ [0, 200, \linear, 1, 0], // 0:buffer num, must be integer
 [0, 8, \linear, 1, 1], // 1:numChannels
 [0.05, 100, \exponential, 0, 10], // 2:grainFreq
 EnvSpec(Env.linen(0.1, 0.8, 0.1)), // 3:env -- fixed len, should total 1sec
 [0.001, 2, \exponential, 0, 0.2], // 4:grainLen
 [0, 1], // 5:startOffset
 [0, 1], // 6:startRandomizer
 [0, 2], // 7:lenRandomizer -- should not exceed grainLen
 [-1, 1] // 8:pan
 ]
);


// uses another buffer to store pointers to buffers that can be chosen
// buffers must be preallocated and read, and you can't use Sample with this one
// make several index bufs with different configurations and switch between them
// with a single n_set

Instr([\grain, \multi], { arg indexbuf, numChannels, grainInterval, env, grainLen, startOffset, startRandomizer, lenRandomizer;
 var trig, sig, buf, startPos, len, index, sampRate, bufLen;
 trig = Impulse.kr(grainInterval.reciprocal);
 // choose a sample buffer
 buf = Index.kr(indexbuf, TRand.kr(0, BufFrames.kr(indexbuf), trig));
 bufLen = BufFrames.kr(buf); // ugens need to be shared
 sampRate = BufSampleRate.kr(buf);
 // how long--give max and this reduces it
 len = (grainLen - TRand.kr(0, lenRandomizer, trig)); // .clip(0.0, grainInterval);
//SendTrig.kr(trig, 0, grainLen);
//SendTrig.kr(trig, 1, len);
//SendTrig.kr(trig, 2, x);
 // where to start in buffer
 startPos = TRand.kr(startOffset * bufLen, startRandomizer * bufLen, trig);
 index = Phasor.ar(trig, BufRateScale.kr(buf), 0, bufLen, 0) + startPos;

 sig = BufRd.ar(numChannels, buf, index, 0)
 * EnvGen.kr(env, trig, timeScale: len, doneAction:0); // window it
}, [ [0, 200, \linear, 1, 0], // 0:bufnum
 [1, 8, \linear, 1, 1], // 1:numChannels
 [0.005, 1, \exponential, 0, 0.1], // 2:grainInterval
 EnvSpec(Env.linen(0.1, 0.8, 0.1)), // 3:env -- fixed len, should total 1sec
 [0.001, 2, \exponential, 0, 0.2], // 4:grainLen
 [0, 1], // 5:startOffset
 [0, 1], // 6:startRandomizer
 [0.0001, 2, \exponential] // 7:lenRandomizer -- should not exceed grainLen
 ]
);


Instr([\grain, \test], { arg bufnum, numChannels, grainInterval, env, grainLen, startOffset, startRandomizer, lenRandomizer, panRange;
 var trig, sig, startPos, len, index, sampRate, bufLen, pan;
 sampRate = BufSampleRate.kr(bufnum); // ugen needs to be shared
 bufLen = BufFrames.kr(bufnum);
 trig = Impulse.kr(grainInterval.reciprocal);
 // how long--give max and this reduces it
 // where to start in buffer
 index = Phasor.ar(trig, BufRateScale.kr(bufnum), 0, bufLen, 0);

 sig = BufRd.ar(numChannels, bufnum, index, 0)
 * EnvGen.kr(env, trig, timeScale: grainLen, doneAction:0); // window it
}, [ [0, 200, \linear, 1, 0], // 0:buffer num, must be integer
 [0, 8, \linear, 1, 1], // 1:numChannels
 [0.05, 100, \exponential, 0, 10], // 2:grainFreq
 EnvSpec(Env.linen(0.1, 0.8, 0.1)), // 3:env -- fixed len, should total 1sec
 [0.001, 2, \exponential, 0, 0.2], // 4:grainLen
 [0, 1], // 5:startOffset
 [0, 1], // 6:startRandomizer
 [0, 2] // 7:lenRandomizer -- should not exceed grainLen
 ]
);


Instr("grain.overlapzappans", { |bufnum, numChannels = 1, numOverlaps, trigrate = 10,
 centerpos, rate, rateratio = 1, windowrate, grainlenfactor, amp = 1, grainenv, env, time,
 ratelo = 0.5, ratehi = 1.25, panwidth, panbias, start = 0|
 var trig, trigs, increment, delay, grainlen, startpos, bufdur, sig, rates, pans, panlo, panhi;
 
 trigrate = trigrate.dereference.value; // user may supply function here
 grainlenfactor = grainlenfactor.dereference.value(numOverlaps, trigrate, bufdur);
 grainlen = trigrate.reciprocal;
 trig = Impulse.kr(trigrate * numOverlaps);
 trigs = PulseDivider.kr(trig, numOverlaps, (0 .. numOverlaps - 1));

 // centerpos: 0 = beginning, 1 = end, must scale by BufDur
 bufdur = BufDur.kr(bufnum);
 windowrate = windowrate.dereference.value(numOverlaps, trigrate, grainlen, bufdur);
 grainlen = grainlen * grainlenfactor; // only need this before adjusting startpos & env'ing
 centerpos = centerpos.dereference.value(numOverlaps, trigrate, grainlen, bufdur,
 windowrate, start) * bufdur;
 rate = EnvGen.kr(Env([rate, rate, rate * rateratio], [0, time], \lin));
 rates = trigs.collect({ |trig|
 var start = TRand.kr(ratelo, ratehi, trig);
 EnvGen.kr(Env([start, start, TRand.kr(ratelo, ratehi, trig)], [0, grainlen], \lin), trig,
 levelScale: rate)
 });
 panwidth = panwidth * (1 - panbias).abs;
 panlo = panbias - panwidth;
 panhi = panbias + panwidth;
 pans = trigs.collect({ |trig|
 var start = TRand.kr(panlo, panhi, trig);
 EnvGen.kr(Env([start, start, TRand.kr(panlo, panhi, trig)], [0, grainlen], \lin), trig);
 });
 startpos = (centerpos - (grainlen * rates)).clip(0, bufdur - grainlen)
 * BufSampleRate.kr(bufnum);
 sig = PlayBuf.ar(numChannels, bufnum, rates * BufRateScale.kr(bufnum), trigs, startpos,
 loop: 0)
 * EnvGen.kr(grainenv, trigs, timeScale: grainlen);
 sig = Pan2.ar(sig, pans, amp);
 Mix(sig) * EnvGen.kr(env, 1, timeScale: time, doneAction:2)
}, [\mybuf, nil, ObjectSpec(3), #[2, 40, \exp, 0, 10], 
 ObjectSpec({ |n, tr, gl, bufdur, wrate, startpos|
 Phasor.ar(0, bufdur.reciprocal * SampleDur.ir * wrate, startpos, 1, startpos)
 }), nil, #[0.1, 10, \exp, 0, 1], #[0.1, 10, \exp, 0, 1], #[0.01, 1, \exp, 0, 1], nil,
 EnvSpec(Env(#[0, 1, 1, 0], #[0.05, 0.9, 0.05], \sin)), EnvSpec(Env.linen(0.1, 0.9, 0.1)),
 #[0.01, 100, \exp, 0, 1], #[0.25, 4, \exp, 0, 1], #[0.25, 4, \exp, 0, 1], nil, \bipolar]);


Instr("grain.note_monoph", { |freq, gate, freqlag, bufnum, basefreq, env, centerPos, centerrand, trigrate, trigrandfreq, trigrandamt, dur, panWidth, panBias, velsens, amp, ampkeyscale|
 var trig = Impulse.kr(trigrate + LFNoise1.kr(trigrandfreq, trigrandamt)),
 rate = Lag.kr(freq, freqlag) / basefreq,
 pan = TRand.kr(-1.0, 1.0, trig).madd(panWidth, panBias).clip(-1.0, 1.0);
 
 centerPos = centerPos * BufDur.ir(bufnum) + TRand.kr(centerrand.neg, centerrand, trig);
 amp = amp * Sensitivity.kr(1, Latch.kr(gate, gate), velsens);
 amp = amp * (ampkeyscale / rate)
 * EnvGen.kr(env, gate, doneAction:2);
 
 dur = (dur / rate).min(0.12);
 
 amp * TGrains.ar(2, trig, bufnum, rate, centerPos, dur, pan, 1.0, interp:2)
}, [\freq, \amp, \freqlag, \mybuf, \freq, EnvSpec(Env.adsr), nil, #[0.00001, 1.0, \exp], #[10, 50, \lin, 0, 25], #[1, 15], #[0, 15], #[0.005, 1.0, \exp], nil, \bipolar, \unipolar, \amp, [0.1, 10, \exp, 0, 1]]);

Instr("grain.note_mono_sweep", { |freq, freqenv|
 Instr.wrap("grain.note_monoph", [freq * EnvGen.kr(freqenv, 1)])
}, [\freq, EnvSpec(Env.one)]);

Instr("grain.note_grit", { |trigrate, trigrandfreq, trigrandamt, dur, graindurmul = 0.01|
 Instr.wrap("grain.note_monoph", [nil, nil, nil, nil, nil, nil, nil, nil, 
 trigrate, trigrandfreq, trigrandamt,
 XLine.kr(dur * graindurmul, dur, Rand(2.0, 6.0))
 ])
}, [#[10, 50, \lin, 0, 25], #[1, 15], #[0, 15], #[0.005, 1.0, \exp]]);

Instr("grain.prob", { |bufnum, timebuf, ampbuf, trigfreq, ratelo, ratehi, offset, randomWidth, indexstart, indexend, graindur, amp, time, env|
 var trig = Impulse.kr(trigfreq),
 numpts = BufFrames.kr(timebuf),
 index = Line.kr(indexstart, indexend, time),
 distanceFromInt = (index + 0.5) % 1.0 - 0.5,
 rate = TRand.kr(ratelo, ratehi, trig),
 pan = LFDNoise1.kr(LFNoise1.kr(0.5).range(0.5, 5)),
 centerPos;

 index = (index + (TExpRand.kr(0.0, randomWidth, trig) * distanceFromInt.sqrt
 * Select.kr(TRand.kr(0.0, 1.99999, trig), #[1, -1]))).round(1.0);
 index = Clip.kr(index, 0, numpts-1);

 centerPos = Index.kr(timebuf, index) + offset;
 amp = amp / Index.kr(ampbuf, index);
 
 TGrains.ar(2, trig, bufnum, rate, centerPos, graindur, pan, amp, interp:2)
 * EnvGen.kr(env, timeScale: time, doneAction:2);
}, [\mybuf, \mybuf, \mybuf, #[5, 30, \lin, 0, 15], #[0.9, 1.1111, \exp, 0, 1], #[0.9, 1.1111, \exp, 0, 1], [0, 0.1, \lin, 0, 0.025], [0, 10, \lin, 0, 2], nil, nil, [0.003, 0.15, \exp, 0, 0.05], \amp, nil, EnvSpec(Env(#[0, 1, 1, 0], #[0.01, 0.98, 0.01], -3))]);

Instr("grain.xfade", { |bufnum, timebuf, ampbuf, trigfreq, ratelo, ratehi, offset, indexstart, indexend, graindur, amp, time, env, panfreq, pancenter, panwidth, pandispwidth, numChannels|
 var trig = Impulse.kr(trigfreq),
 numpts = BufFrames.kr(timebuf),
 index = Line.kr(indexstart, indexend, time),
 xfade = index % 1.0,
 rate = TRand.kr(ratelo, ratehi, trig),
 pan = (LFDNoise1.kr(panfreq.dereference.value, panwidth, pancenter)
 + TRand.kr(pandispwidth.neg, pandispwidth, trig)).clip(-1, 1),
 centerPos;

 index = index + #[0, 1];

 centerPos = Index.kr(timebuf, index) + offset;
 // equal power crossfade
 amp = amp / Index.kr(ampbuf, index) * ([1-xfade, xfade].sqrt);
 
 Mix(TGrains.ar(numChannels, trig, bufnum, rate, centerPos, graindur, pan, amp, interp:2))
 * EnvGen.kr(env, timeScale: time, doneAction:2);
}, [\mybuf, \mybuf, \mybuf, #[5, 30, \lin, 0, 15], #[0.9, 1.1111, \exp, 0, 1], #[0.9, 1.1111, \exp, 0, 1], #[0, 0.1, \lin, 0, 0.025], nil, nil, #[0.003, 0.15, \exp, 0, 0.05], \amp, nil, EnvSpec(Env(#[0, 1, 1, 0], #[0.01, 0.98, 0.01], -3)), ObjectSpec({ LFNoise1.kr(0.5).range(0.5, 5) }), \bipolar, \unipolar, #[0, 1], StaticSpec(2, 8, \lin, 1, 2)]);


// plays exactly one grain in response to a trigger

Instr("grain.grain1", { |bufnum, numCh, gate = 1, rateStart, rateEnd, startPos, loop, env, time, doneAction = 0, rateEnvFunc, amp = 1|
 var rateEnv, rate; 
 
 // allow user to pass in an envelope responsive to user inputs
 // that requires a function which receives arguments
 // Patch treats function args as Pfunc so you have to pass in `{ }
 rateEnv = rateEnvFunc.dereference.value(rateStart, rateEnd, time);
 rate = EnvGen.kr(rateEnv, gate, timeScale: time);
 
 env = env.dereference.value(time, gate);
 
 PlayBuf.ar(numCh, bufnum, rate * BufRateScale.kr(bufnum), gate, startPos * BufFrames.kr(bufnum), loop)
 * EnvGen.kr(env, gate, timeScale: time, doneAction: doneAction)
 * amp
}, [\mybuf, \numChannels, TrigSpec.new, NoLagControlSpec(0.1, 10, \exp, 0, 1), NoLagControlSpec(0.1, 10, \exp, 0, 1), nil, NoLagControlSpec(0, 1, \lin, 1, 0), EnvSpec(Env.linen(0.1, 0.8, 0.1)), NoLagControlSpec(0, 60, \exp, 0, 1), NoLagControlSpec(0, 13, \lin, 1, 0), ObjectSpec({ |rateStart, rateEnd| Env([rateStart, rateStart, rateEnd], #[0, 1]) }), nil]);


Instr("grain.grain1pan", { |gate, panStart, panEnd, time, panEnvFunc|
 var panEnv = panEnvFunc.dereference.value(panStart, panEnd, time),
 pan = EnvGen.kr(panEnv, gate, timeScale: time),
 sig = Instr.wrap("grain.grain1", [nil, 1, gate, nil, nil, nil, nil, nil, time]);
 
 Pan2.ar(sig, pan);
}, [TrigSpec.new, NoLagControlSpec(-1.0, 1.0, default: 0), NoLagControlSpec(-1.0, 1.0, default: 0), NoLagControlSpec(0, 60, \exp, 0, 1), ObjectSpec({ |start, end| Env([start, start, end], #[0, 1]) })]);

