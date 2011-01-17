var xf = { arg old, new, xfade;
// (old * (1-xfade) + (new * xfade))
 (new-old) * xfade + old // one fewer BinaryOpUGen
};


WrapInstr([\busfx, \limiter], { arg bus, numChannels, level, lookAhead, gain;
 Limiter.ar(In.ar(bus, numChannels), level, lookAhead) * gain;
}, #[\mybuf, \numChannels, [0, 1, \linear, 0, 1], [0.001, 0.1], [0.1, 10, \exponential, 0, 1]]);

WrapInstr([\busfx, \compander], { arg bus, numChannels, thresh, slopeBelow, slopeAbove, clampTime, relaxTime, postGain;
 var sig;
 sig = In.ar(bus, numChannels);
 Compander.ar(sig, sig, thresh, slopeBelow, slopeAbove, clampTime, relaxTime, postGain);
}, [\audiobus, nil, [0, 1, \linear, 0, 0.5], [0.1, 10, \exponential, 0, 1], [0.1, 10, \exponential, 0, 1], [0.001, 5, \exponential], [0.001, 5, \exponential], [0.1, 10, \exponential, 0, 1]]);

WrapInstr([\busfx, \companderd], { arg bus, numChannels, thresh, slopeBelow, slopeAbove, clampTime, relaxTime, postGain;
 var sig;
 sig = In.ar(bus, numChannels);
 CompanderD.ar(sig, thresh, slopeBelow, slopeAbove, clampTime, relaxTime, postGain);
}, [\audiobus, nil, [0, 1, \linear, 0, 0.5], [0.1, 10, \exponential, 0, 1], [0.1, 10, \exponential, 0, 1], [0.001, 5, \exponential], [0.001, 5, \exponential], [0.1, 10, \exponential, 0, 1]]);

WrapInstr("busfx.normalizer", { |bus, numChannels, level = 1, threshlo = 0.1, threshhi = 0.15, dur = 0.01|
 var sig = In.ar(bus, numChannels),
 amp = Amplitude.kr(sig);
 sig = XFade2.ar(sig, Normalizer.ar(sig, level, dur),
 LinLin.kr(amp, 0.1, 0.15, -1, 1).clip(-1, 1))
}, [\audiobus, \numChannels, \amp, \amp, \amp, [0.001, 1, \exp, 0, 0.1]]);

WrapInstr([\busfx, \dist], { arg bus, numChan, preGain, /*clipthresh,*/ postGain;
 (In.ar(bus, numChan) * preGain).distort * postGain;
}, [\audiobus, \numChannels, [0.05, 20, \exponential, 0, 1], [0.05, 20, \exponential, 0, 1], [0,1]]);


WrapInstr([\busfx, \chorus], { arg bus, numChan, predelay, speed, depth, ph_diff, xfade;
 var in, sig;
 in = In.ar(bus, numChan);
 in.isKindOf(Collection).if({
 sig = in.collect({ arg ch, i; // ch is one channel
 DelayC.ar(ch, 0.5, SinOsc.kr(speed, ph_diff * i, depth, predelay));
 });
 }, {
 sig = DelayC.ar(in, 0.5, SinOsc.kr(speed, ph_diff, depth, predelay));
 });
 XFade2.ar(in, sig, xfade * 2 - 1);
// xf.value(in, sig, xfade) // when felix has XOut working, this can be better
}, [\audiobus, \numChannels, [0.0001, 0.2, \exponential, 0, 0.001], [0.001, 10, \exponential], [0.0001, 0.25, \exponential], [0, 2*pi], [0, 1]]);

//WrapInstr([\busfx, \chorus2], { arg bus, numChan, numDelays, predelay, speed, depth, ph_diff, xfade;
// var in, sig, mods;
// in = In.ar(bus, numChan);
// mods = { |i|
// SinOsc.kr(speed * rrand(0.9, 1.1), ph_diff * i, depth, predelay);
// } ! (numDelays * numChan);
// sig = DelayC.ar(in, 0.5, mods);
// Mix(sig.clump(numChan))
//// indexBase = (0, numChan .. mods.size-1);
//// fxout = { |i| Mix(sig[indexBase + i]) } ! numChan;
//// xf.value(in, fxout, xfade) // when felix has XOut working, this can be better
//}, [\audiobus, \numChannels, \numChannels, [0.0001, 0.2, \exponential, 0, 0.001], [0.001, 10, \exponential], [0.0001, 0.25, \exponential], [0, 2*pi], [0, 1]]);

// allows mono-to-stereo
WrapInstr([\busfx, \chorus2], { arg bus, numInChan, numOutChan, numDelays, predelay, speed, depth, ph_diff, preamp;
 var in, sig, mods;
 in = In.ar(bus, numInChan) * preamp;
 mods = { |i|
 SinOsc.kr(speed * rrand(0.9, 1.1), ph_diff * i, depth, predelay);
 } ! (numDelays * numOutChan);
 sig = DelayC.ar(in, 0.5, mods);
 Mix(sig.clump(numOutChan))
}, [\audiobus, \numChannels, \numChannels, \numChannels, [0.0001, 0.2, \exponential, 0, 0.001], [0.001, 10, \exponential], [0.0001, 0.25, \exponential], [0, 2*pi], [0.1, 10, \exp, 0, 1]]);


WrapInstr([\busfx, \chorus2band], { arg bus, numChan, predelay, speed, depth,
 ph_diff, /*width,*/ crossover, xfade;
 var in, lo, hi;
 in = In.ar(bus, 1);
 lo = LPF.ar(in, crossover);
 hi = HPF.ar(in, crossover);
 lo = DelayC.ar(lo, 0.1, SinOsc.kr(speed, ph_diff, depth, predelay));
 hi = Array.fill(numChan, { |i|
 predelay = predelay + depth;
 DelayC.ar(hi, 0.5, SinOsc.kr(speed, ph_diff * i, depth, predelay));
 }).scramble;
// // apply width: catch degenerate cases first
// // reduces to stereo--I'll fix later
// width.switch(
// 0, { hi = Mix.ar(hi) ! numChan }, // no width, collapse into 1 channel and expand
// 1, { nil } // max width, leave alone
// { }
// );
 lo = lo + hi;
 XFade2.ar(in, lo, xfade * 2 - 1)
// (lo - in) * xfade + in
}, #[\audiobus, \numChannels, [0.0001, 0.2, \exponential, 0, 0.001], [0.001, 10, \exponential], [0.0001, 0.25, \exponential], [0, 2pi], /*[0, 1],*/ \freq, [0, 1]]);

WrapInstr([\busfx, \chorus2band2], { arg bus, numChan, numDelays, predelay, speed, depth,
 ph_diff, /*width,*/ crossover, xfade;
 var in, lo, hi, sig, mods, indexBase;
 in = In.ar(bus, 1);
 lo = LPF.ar(in, crossover);
 hi = HPF.ar(in, crossover);
// lo = DelayC.ar(lo, 0.1, SinOsc.kr(speed, ph_diff, depth, predelay));
 mods = { |i|
 SinOsc.kr(speed * rrand(0.9, 1.1), ph_diff * i, depth, predelay); } ! (numDelays * numChan);
 sig = DelayC.ar(hi, 0.5, mods);
 indexBase = (0, numChan .. mods.size-1);
 hi = { |i| Mix(sig[indexBase + i]) } ! numChan;
 lo = lo + hi;
 XFade2.ar(in, lo, xfade * 2 - 1)
// (lo - in) * xfade + in
}, #[\audiobus, \numChannels, \numChannels, [0.0001, 0.2, \exponential, 0, 0.001], [0.001, 10, \exponential], [0.0001, 0.25, \exponential], [0, 2pi], /*[0, 1],*/ \freq, [0, 1]]);


WrapInstr([\busfx, \fbchorus], { arg bus, numChan, predelay, speed, depth, ph_diff, decaytime, xfade;
 var in, sig;
 in = In.ar(bus, numChan);
 in.isKindOf(Collection).if({
 sig = in.collect({ arg ch, i; // ch is one channel
 // was AllpassL
 CombL.ar(ch, 0.5, SinOsc.kr(speed, ph_diff * i, depth, predelay), decaytime);
// DelayC.ar(ch, 0.5, SinOsc.kr(speed, ph_diff * i, depth, predelay));
 });
 }, {
 sig = CombL.ar(in, 0.5, SinOsc.kr(speed, ph_diff, depth, predelay), decaytime);
// sig = DelayC.ar(in, 0.5, SinOsc.kr(speed, ph_diff, depth, predelay));
 });
 XFade2.ar(in, sig, xfade * 2 - 1);
// xf.value(in, sig, xfade) // when felix has XOut working, this can be better
}, [\audiobus, \numChannels, [0.002, 0.2, \exponential, 0, 0.01], [0.001, 10, \exponential], [0.0001, 0.25, \exponential], [0, 2*pi], [0.001, 10, \exponential]]);


// better for long reverbs
WrapInstr([\busfx, \rvb_allpass], { arg bus, numChan, maxDelay, preDelay, decay, numRefl, random;
 var sig, new,
 trigrand = Impulse.kr(0);
 (random.rate == \control).if({ trigrand = trigrand + HPZ1.kr(random).abs });
 sig = In.ar(bus, numChan);
 new = sig;
 numRefl.do({
 new = AllpassN.ar(new, maxDelay,
 Array.fill(numChan, { TRand.kr(0.0, random, trigrand) }) + preDelay, decay);
 });
 new
}, [\audiobus, \numChannels, [0.25, 2], [0.001, 1.5, \exponential, 0, 0.05], [0.01, 10, \exponential, 0, 0.25], [1, 10, \linear, 1, 4], NoLagControlSpec(0.001, 1, \exponential, 0, 0.03), TrigSpec()]);

WrapInstr([\busfx, \rvb_allpass2], { arg bus, numChan, maxDelay, preDelay, decay, numRefl, random;
 var sig, new, dlys,
 trigrand = Impulse.kr(0);
 (random.rate == \control).if({ trigrand = trigrand + HPZ1.kr(random).abs });
 sig = In.ar(bus, numChan);
 new = sig;
 dlys = Array.fill(numRefl, {
 new = AllpassN.ar(new, maxDelay, Array.fill(numChan, { TRand.kr(0.0, random, trigrand) }) + preDelay, decay); });
 Mix.ar(dlys * Array.series(numRefl, 1, (numRefl+1).reciprocal.neg))
}, [\audiobus, \numChannels, [0.25, 2], [0.001, 1.5, \exponential, 0, 0.05], [0.01, 10, \exponential, 0, 0.25], [1, 10, \linear, 1, 4], NoLagControlSpec(0.001, 1, \exponential, 0, 0.03), TrigSpec()]);


// better for tight reverbs
// this can introduce a *nasty* DC component, hence LeakDC
WrapInstr([\busfx, \rvb_comb], { arg bus, numChan, maxDelay, preDelay, decay, numRefl, random;
 var sig, new,
 trigrand = Impulse.kr(0);
 (random.rate == \control).if({ trigrand = trigrand + HPZ1.kr(random).abs });
 sig = In.ar(bus, numChan);
 new = Mix.arFill(numRefl, {
 CombN.ar(sig, maxDelay, Array.fill(numChan, { TRand.kr(0.0, random, trigrand) }) + preDelay, decay);
 });
 LeakDC.ar(new)
}, [\audiobus, \numChannels, [0.25, 2], [0.001, 1.5, \exponential, 0, 0.05], [0.01, 10, \exponential, 0, 0.25], [1, 10, \linear, 1, 4], NoLagControlSpec(0.001, 1, \exponential, 0, 0.03), TrigSpec()]);


// bit more cpu but nicer sound

WrapInstr("busfx.freeverb2", { |bus, mix = 0.25, room = 0.15, damp = 0.5, amp = 1|
 var in = In.ar(bus, 2);
 FreeVerb2.ar(in[0], in[1], mix, room, damp, amp);
}, [\mybus, nil, nil, nil, nil]);


// some delays

WrapInstr([\busfx, \singleDelay], { arg bus, numChan, delayClass, maxTime, time, mul, add;
 delayClass.ar(In.ar(bus, numChan), maxTime, time, mul, add)
}, [\audiobus, \numChannels, ObjectSpec(CombL), [0.25, 20], [0.0001, 20]]);

WrapInstr([\busfx, \combDelay], { arg bus, numChan, delayClass, maxTime, time, decay, mul, add;
 delayClass.ar(In.ar(bus, numChan), maxTime, time, decay, mul, add)
}, [\audiobus, \numChannels, ObjectSpec(CombL), [0.25, 20], [0.0001, 20], [0.0001, 20]]);

WrapInstr([\busfx, \pingpong], { arg bus, numChan, bufnum, time, feedback, rotate;
 PingPong.ar(bufnum, In.ar(bus, numChan), time, feedback, rotate);
}, #[\audiobus, \numChannels, nil, [0, 20], [0, 1], [0, 20, \linear, 1, 1]]);

// ringmods

WrapInstr([\busfx, \ring1], { arg bus, numChan, freq, mod_amp, xfade;
 var sig, new;
 sig = In.ar(bus, numChan);
 new = sig * SinOsc.ar(freq, 0, mod_amp);
 XFade2.ar(sig, new, xfade * 2 - 1)
// xf.value(sig, new, xfade)
}, [\audiobus, \numChannels, \freq, \amp, \amp]);


WrapInstr([\busfx, \rlpf], { |bus, numChan, freq, rq, xfade|
 var sig, new;
 sig = In.ar(bus, numChan);
 new = RLPF.ar(sig, freq, rq);
 (xfade == 1).if({ new }, { XFade2.ar(sig, new, xfade * 2 - 1) });
// xf.value(sig, new, xfade)
}, [\audiobus, \numChannels, \freq, \myrq, \amp]);

WrapInstr([\busfx, \rhpf], { |bus, numChan, freq, rq, xfade|
 var sig, new;
 sig = In.ar(bus, numChan);
 new = RHPF.ar(sig, freq, rq);
 (xfade == 1).if({ new }, { XFade2.ar(sig, new, xfade * 2 - 1) });
// xf.value(sig, new, xfade)
}, [\audiobus, \numChannels, \freq, \myrq, \amp]);


WrapInstr([\busfx, \lpf], { |bus, numChan, freq, rq, xfade|
 var sig, new;
 sig = In.ar(bus, numChan);
 new = LPF.ar(sig, freq, rq);
 (xfade == 1).if({ new }, { XFade2.ar(sig, new, xfade * 2 - 1) });
// xf.value(sig, new, xfade)
}, [\audiobus, \numChannels, \freq, \myrq, \amp]);


// basic vocoder
// this needs a lot of help with amplitude scaling
// eventually I want to implement crossfading
// problem - I want to normalize the voc input but Normalizer does not handle low amps well
// I could normalize against the sum of the band amplitudes, and clip a low threshold?

WrapInstr("busfx.vocoder", { |vocbus, vocChannels, bus, inChannels, bands, lowBand, hiBand, rq, ampcorrexn = 1|
 var sig, centerFreqs, splitFilt, amp;
 var sig2, inSplit, resynth;
 // analysis phase
 sig = In.ar(vocbus, vocChannels);
 centerFreqs = Array.geom(bands, lowBand, (hiBand / lowBand) ** (bands-1).reciprocal);
 splitFilt = BPF.ar(sig, centerFreqs, rq);
 amp = Amplitude.ar(splitFilt);
 
 // resynthesis phase
 sig2 = In.ar(bus, inChannels);
 inSplit = sig2.asArray.collect({ |channel| BPF.ar(channel, centerFreqs, rq, amp) });
 resynth = Mix.ar(inSplit.flop);
 resynth * ampcorrexn
}, [\audiobus, \numChannels, \audiobus, \numChannels, StaticSpec(1, 50, \linear, 1, 30), \freq, \freq, #[1, 0.005, \exponential, 0, 1], \amp, #[0.1, 10, \exp, 0, 1], #[0.1, 10, \exp, 0, 1], #[0.001, 5, \exp], #[0.001, 5, \exp], #[0.1, 10, \exp, 0, 1], \unipolar, \unipolar, [0.02, 50, \exp, 0, 1]]);

WrapInstr("busfx.vocoder-xfade", { |vocbus, vocChannels, bus, inChannels, bands, lowBand, hiBand, rq, ampcorrexn = 1, xfade = 1|
 var sig, centerFreqs, splitFilt, amp;
 var sig2, inSplit, resynth;
 // analysis phase
 sig = In.ar(vocbus, vocChannels);
 centerFreqs = Array.geom(bands, lowBand, (hiBand / lowBand) ** (bands-1).reciprocal);
 splitFilt = BPF.ar(sig, centerFreqs, rq);
 amp = Amplitude.ar(splitFilt, 0.003, 0.003);
 
 // resynthesis phase
 sig2 = In.ar(bus, inChannels);
 inSplit = sig2.asArray.collect({ |channel| BPF.ar(channel, centerFreqs, rq, amp) });
 resynth = Mix.ar(inSplit.flop) * ampcorrexn;
 XFade2.ar(sig2, resynth, xfade);
}, [\audiobus, \numChannels, \audiobus, \numChannels, StaticSpec(1, 50, \linear, 1, 30), \freq, \freq, #[1, 0.005, \exponential, 0, 1], [0.005, 200, \exp, 0, 1], \bipolar]);


// let me try fft style
// ineffective, doesn't sound "synthy" enough
WrapInstr("busfx.fftvoc", { |vocbus, vocChannels, vocfftbuf, bus, inChannels, infftbuf, thresh, slopeBelow, slopeAbove, clampTime, relaxTime, cmpgain|
 var sig, fft, sig2, infft, amp;
 
 sig = In.ar(vocbus, vocChannels);
 sig = Compander.ar(sig, sig, thresh, slopeBelow, slopeAbove, clampTime, relaxTime, cmpgain);
 amp = Amplitude.kr(sig);
 sig = XFade2.ar(sig, Normalizer.ar(sig),
 // LinLin does not clip (see source)
 LinLin.kr(amp, 0.1, 0.15, -1, 1).clip(-1, 1));
 fft = sig.asArray.collect({ |chan, i| FFT(vocfftbuf + i, chan) });
 fft = PV_MagSmear(fft, 6);
 
 sig2 = In.ar(bus, inChannels);
 infft = sig2.asArray.collect({ |chan, i| FFT(infftbuf + i, chan) });
 
 infft = PV_MagMul(infft, fft);
 IFFT(infft)
}, [\audiobus, \numChannels, \mybuf, \audiobus, \numChannels, \mybuf, \unipolar, #[0.1, 10, \exp, 0, 1], #[0.1, 10, \exp, 0, 1], #[0.001, 5, \exp], #[0.001, 5, \exp], #[0.1, 10, \exp, 0, 1]]);

