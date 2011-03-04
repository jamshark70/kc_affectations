
/*
PR(\steps1) api requirements:
dur == nil, stop
dur is positive, numWalkers is 0, rest for dur
numWalkers == nil, stop
0 <= numWalkers < 1.0, treat as ratio of dur
numWalkers >= 1.0, treat as exact beats presyncop

gsel: call gSelector
if a gSelector uses ~gestureStream, it must put something in parms \numSyncop
*/

// just in case... (won't load twice if already loaded)
(thisProcess.nowExecutingPath.dirname.dirname +/+ "common/common-defs.scd").loadPath;


topEnvironment[\feetdir] ?? {
	topEnvironment[\feetdir] = thisProcess.nowExecutingPath
		?? { Document.current.tryPerform(\path) };
	if(topEnvironment[\feetdir].notNil) {
		topEnvironment[\feetdir] = topEnvironment[\feetdir].dirname;
	} {
		switch(thisProcess.platform.name)
			{ \osx } {
				topEnvironment[\feetdir] = "~/SCServer/trax/kc.git/trunk/feet".standardizePath;
			}
			{ \linux } {
				topEnvironment[\feetdir] = "~/share/SuperCollider/scd/kc.git/trunk/feet".standardizePath;
			};
	};
};


// pad

WrapInstr("osc2.vosc3panslide", { |freq, startFreq, slideTime = 0, slideTrig = 1, panS, panE|
	var	pan = EnvGen.kr(Env([panS, panE], [slideTime], \sin), slideTrig);
	freq = EnvGen.kr(Env([startFreq, freq], [slideTime], \sin), slideTrig);
	WrapInstr.wrap("osc2.vosc3panfilt", [freq, nil ! 7, pan].flat);
}, [NoLagControlSpec.newFrom(\freq.asSpec), NoLagControlSpec.newFrom(\freq.asSpec), NoLagControlSpec(0, 2), TrigSpec.new, NoLagControlSpec(-1, 1), NoLagControlSpec(-1, 1)]);

(keys: #[master, rvbmc],
make: { |name|
	var	nh = (s.sampleRate * 0.5 / 85.midicps).trunc,
		normalSpectrum = (1..nh).reciprocal,
		rwidth = 4,  // number above and below center to randomize
		// actually i/(rwidth*2) * 2pi but /2 *2 cancel out
		template = { |i| (i/rwidth * pi).cos.neg * 0.5 + 0.5 } ! (rwidth*2 + 1),
		out;

	~wt = Buffer.allocConsecutive(8, s, 2048, 1, { |buf, i|
		var	low = i.linlin(0, 7, 0, nh - (rwidth*2) - 1),
		spectrum = normalSpectrum.copy;
		template.do { |randAmt, i|
			spectrum[low + i] = spectrum[low + i] + randAmt.rand;
		};
		buf.sine1Msg(spectrum)
	});

	~target = MixerChannel(name, s, 2, 2, level: -17.dbamp, outbus: ~master, completionFunc: { |chan|
		~ch = chan.playfx(Instr("busfx.chorus2"), [18, 2, 2, 2, 0.0084255985991258, 0.077426358822457, 0.005573957308325, 0.61086524860099, 0.825]);
		chan.newPostSend(~rvbmc, 0.405);
	});
	out = Voicer(15, WrapInstr("osc2.vosc3panslide"), [bufbase: `(~wt.first.bufnum), numbufs: `(~wt.size)/*, bufmod: KrNumberEditor(0, [0, ~wt.size-1.001])*/, env: Env.adsr(1.6, 0.1, 0.8, 3.2), detune: 1.003, slideTime: 0.7, ffreq: 3000, vsens: `0.6, slideTrig: SimpleTrigger.new], target: ~target);
	out.mapGlobal(\bufmod, nil, 2.314, [0, ~wt.size-1.001]);
	out.mapGlobal(\ffreq, nil, 900, \freq);
	out.mapGlobal(\rq, nil, 1, \myrq);

	out
}, free: { [~target, ~wt].free }, type: \voicer) => Fact(\slidePad);


// bass

WrapInstr("osc2.vosc3fbassBufAtk", { |freq, freqlag, gate, bufbase, numbufs = 2, bufmod, env, vsens, detune, ffreq, rq, msens = 0, bufmAttack = 0.01, bufmDecay = 0.07, lfbuf, t_gate = 1|
	var	maxBufAdd = numbufs - 1.001,
		envRange = maxBufAdd - bufmod,
		envtop = envRange * Sensitivity.kr(1, Latch.kr(t_gate, t_gate), msens);
	var sig, amp, buf;
	amp = Sensitivity.kr(1, Latch.kr(gate, gate), vsens);
		// the bufenv should know how many buffers it's covering
		// but, bufmod might be rising making the range invalid
	buf = bufbase + bufmod
		+ (envtop * EnvGen.kr(Env([0, 1, 0.001], [bufmAttack, bufmDecay], -4), t_gate));
	freq = Lag.kr(freq, freqlag);
	// SinOsc is to reinforce fundamental when higher bufnums deemphasize it
	sig = VOsc3.ar(buf, freq/detune, freq, freq*detune) + Osc.ar(lfbuf, freq);
	RLPF.ar(sig * amp * EnvGen.kr(env, gate, doneAction:2), ffreq, rq)
}, [\freq, nil, \amp, #[0, 1000, \linear, 1, 0], #[0, 1000, \linear, 1, 0], #[0, 20], EnvSpec(Env.adsr), [0, 1], \mydetune, \freq, \myrq, \unipolar, #[0.002, 1, \exp], #[0.002, 1, \exp], \mybuf, TrigSpec()]);

(keys: #[master, rvbmc],
make: { |name|
	var	out;
	~target = MixerChannel(name, s, 1, 2, level: -16.dbamp, outbus: ~master);
	if(VC.exists(\sp).not) {
		"Fact(%) requires buffers from VC('sp') - creating now.\n".postf(~collIndex.asCompileString);
		Fact(\slidePad) => VC(\sp);
	};
	~bufs = VC(\sp).env.wt;
	~lfbuf = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg((1..5).reciprocal) });
	out = MonoPortaVoicer(1, WrapInstr("osc2.vosc3fbassBufAtk"), [numbufs: `(~bufs.size), vsens: 1, bufbase: `(~bufs.first.bufnum), env: Env.adsr(0.01, 0.2, 0.6, 1.2), lfbuf: ~lfbuf, vsens: 0, msens: 1, bufmAttack: 0.1, bufmDecay: 0.8, detune: 1.003], target: ~target);
	out.mapGlobal(\ffreq, nil, 1200, \freq);	// around 220 is nice and mellow
	out.mapGlobal(\bufmod, nil, 0, #[0, 6.998]);
	out.portaTime = 1.2;
	out
},
free: { [~target, ~lfbuf].free },
type: \vc) => Fact(\feetbass);

PR(\abstractProcess).clone {
	~alwaysReset = true;
	~event = (eventKey: \voicerNote);
	~bassID = \currentBassNote;

	~rootRange = NumericRange(11, 23);
	~root = Pvbrown(11, 23, Pwhite(1, 3, inf), inf, 14);
	~interval = Pwhite(1, 5, inf);
	~upOrDown = Prand(#[-1, 1], inf);
	~upOrDownFix = Pif(
		Pfunc { |ev|
			~rootRange.inrange(ev[\target] + (ev[\interval] * ev[\upOrDown]))
		},
		Pkey(\upOrDown),
		Pkey(\upOrDown).neg
	);

	~shortDur = Pwhite(2, 3, inf);
	~longDur = Pwhite(16, 24, inf);
	~longHold = Pwhite(0.4, 0.6, inf);
	~preRest = Pwhite(0, 7, inf);
	~gate = Pseq(#[1, 1, 0.001], inf);
	~minBeforeReset = 16;

	~asPattern = {
		Pbind(
			\bassID, BPStream(\bassID),
			\target, Pstutter(3, BPStream(\root)),
			\interval, Ppatlace([0, BPStream(\interval), 0], inf),
			\upOrDown, BPStream(\upOrDown),
			\upOrDownFix, BPStream(\upOrDownFix),
			\freq, Pseq([
				#[],	// rest
				Pfinval(2, Pkey(\target) + (Pkey(\interval) * Pkey(\upOrDownFix)))
			], inf),
			\durArray, Pif(
				Pfunc { |ev| ~resetTime.isNil or: { (~resetTime - thisThread.beats) >= ~minBeforeReset } },
				Pstutter(3,
					Ptuple([BPStream(\preRest), BPStream(\shortDur), BPStream(\longDur)], inf))
			),
			\totalDur, Pfunc { |ev| ev[\durArray].sum },
			\dur, Pn(Plazy { |ev| Pseq(ev[\durArray], 1) }, inf),
			\legato, Ppatlace([1, 1.01, BPStream(\longHold)], inf),
			\length, Pkey(\dur) * Pkey(\legato),
			\gate, BPStream(\gate, resetSource: true),
			\mode, \g,
			\midi, false,
			\note, Pstutter(3, Pfunc { |ev|
				SequenceNote(ev[\target], ev[\totalDur], ev[\length], ev[\gate])
			})
		);
	};
} => PR(\slideBass);

(
make: { |name|
	BP(name).free;
	PR(\slideBass) => BP(name);
	if(VC.exists(\bs)) { VC(\bs) => BP(name) };
	1 => BP(name);
	BP(name).leadTime = 0.1;
},
type: \bp) => Fact(\slideBass);

if(MBM.exists(0).not) { MIDIBufManager(chan: nil) => MBM.prNew(0) };

MIDIRecBuf(\ch1, [
	#[74, 76,  74, 79, 78],
	#[1, 2,  1, 1, 2],
	1, 0.5
].asNotes, (mode: \g, type: \ch, useOwnMode: true)) => MBM(0);

{ |notes, parentEv|
	var	numEv = notes.estimateLength,
		parentDelta = parentEv[\delta],
		totaldur = numEv * parentDelta + 6.0;
	Ptuple([parentDelta, Pseries(totaldur, parentDelta.neg, numEv), 0.5], 1)
} => MicRh(\slideArpeg);

{ |notes| Pseq(notes, 1) } => ArpegPat(\asis1);

{ |notes|
	var	iter = { |remain, out|
			var	last, goodRemain, test, testRemain;
			if(remain.isEmpty) { out.yield } {
				last = out.last.asFloat;
				goodRemain = remain.select({ |n| (n.asFloat absdif: last) <= 7 });
				if(goodRemain.size == 0) { nil } {
					goodRemain.scramble.do { |n|
						test = out ++ n;
						testRemain = remain.copy;
						testRemain.remove(n);
						iter.(testRemain, test);
					}
				}
			};
		}, rem1, start, result;
	// routine is basically an early-exit mechanism
	result = r {
		notes.scramble.do { |stn|
			start = [stn];
			rem1 = notes.copy;
			rem1.remove(stn);
			iter.(rem1, start)
		};
	}.next;
	Pseq(result ?? { notes.scramble }, 1)
} => ArpegPat(\smallInt1);


(
make: { |name|
	\newCh.eval(name, \arpeg1, \macroRh, MBM(0)[\ch1], nil, Pn(#[2.5, inf], inf), \slideArpeg, \asis1, nil, \g);
	BP(name).topNote = PR(\patternTop).copy.make {
		~deg = Pvbrown(37, 48, Pwhite(1, 4, inf), start: { rrand(40, 44) });
		~mode = \g;
	};
	BP(name).put(\reset, BP(name).v[\reset] <> { ~topNote.reset });

	// this exploits the fact that argPairs resets for each chord
	// each chord will always start with startFreq == freq
	BP(name).child.argPairs = [
		mnote: Pkey(\note).asFloat,
		startNote: Penvir((),
			Pseq([
				Pfinval(1, Pkey(\mnote)).collect { |note| ~startNote = note },
				Pfunc { |ev|
					~startNote <!! (~startNote = ev[\note].asFloat)
				}
			], 1)
		),
		#[mfreq, startFreq], Pfunc { |ev| ev[\mode].asMode.cps([ev[\mnote], ev[\startNote]]) },
		slideTrig: 1,
		maxfreq: max(Pkey(\mfreq), Pkey(\startFreq)),
		minfreq: min(Pkey(\mfreq), Pkey(\startFreq)),
		// lower bound is 1.0 b/c max/min can never divide a smaller by a larger number
		slideTime: (Pkey(\maxfreq) / Pkey(\minfreq)).explin(1.0, 2.0, 0.7, Pkey(\dur) / Ptempo(), \max)
	];
},
type: \bp
) => Fact(\slideChords);



// footstep counterpoint

SynthDef(\bufGrainPanFilt, { |start, time, bufnum, pan, rate = 1, amp = 1, ampMap = 1,
		attack = 0.001, decay = 0.02, outbus, ffreq = 2000|
	var sig;
	sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
		* EnvGen.kr(Env.linen(attack, time, decay), doneAction:2);
	sig = LPF.ar(sig, ffreq);
	Out.ar(outbus, Pan2.ar(sig, pan, amp * ampMap));
}).add;

SynthDef(\bufGrainPanComb, { |start, time, bufnum, pan, rate = 1, amp = 1, ampMap = 1,
		attack = 0.001, decay = 0.02, outbus, ffreq = 2000, filtDecay = 0.1, filtAmp = 1|
	var sig;
	sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
		* EnvGen.kr(Env.linen(attack, time, decay));
	// 0.06 ~= 16 Hz, likely as low a freq as you'll need
	sig = Limiter.ar(sig + CombL.ar(LeakDC.ar(sig), 0.06, ffreq.reciprocal, filtDecay, filtAmp));
	DetectSilence.ar(sig, 0.001, doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, amp * ampMap));
}).add;

SynthDef(\bufGrainPanKlank, { |start, time, bufnum, pan, rate = 1, amp = 1, ampMap = 1,
		attack = 0.001, decay = 0.02, outbus, filtFreq = 2000, filtAttack = 0.1, filtDecay = 1.0,
		filtAmp = 1,
		chorusFreq = 0.05, chorusAmt = 0.02, chorusDelay = 0.03,
		ffreq = 2000, lprq = 1|
	var harm = \harm.kr((1..5)),
		amps = \amps.kr((1..5).reciprocal),
		decays = \decays.kr(1 ! 5),
		chorusAmps = \chorusAmps.kr(1 ! 3),
		sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
			* EnvGen.kr(Env.linen(attack, time, decay)),
		// Klank(decay) - Klank(attack) is like a bank of Formlets
		filt = Klank.ar(`[harm, amps, decays], sig, freqscale: filtFreq, decayscale: filtDecay)
			- Klank.ar(`[harm, amps, decays], sig, freqscale: filtFreq, decayscale: filtAttack),
		shaped, dly, cfreqRand = chorusFreq * 0.2;
	sig = sig + (Limiter.ar(filt) * filtAmp);
	dly = sig;
	chorusAmps.do { |amp|
		dly = DelayL.ar(dly, chorusDelay + chorusAmt,
			SinOsc.kr(
				chorusFreq + Rand(cfreqRand.neg, cfreqRand),
				Rand(0, 2pi),
				chorusAmt, chorusDelay
			)) * amp;
		sig = sig + dly;
	};
	sig = RLPF.ar(sig, ffreq, lprq);
	DetectSilence.ar(sig, 0.001, doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, amp * ampMap));
}).add;

SynthDef(\bufGrainPanKlShp, { |start, time, bufnum, pan, rate = 1, amp = 1, ampMap = 1,
		attack = 0.001, decay = 0.02, outbus, filtFreq = 2000, filtAttack = 0.1, filtDecay = 1.0,
		filtAmp = 1,
		shapebuf = 0, shapeXf = 1, chorusFreq = 0.05, chorusAmt = 0.02, chorusDelay = 0.03,
		ffreq = 2000, lprq = 1|
	var harm = \harm.kr((1..5)),
		amps = \amps.kr((1..5).reciprocal),
		decays = \decays.kr(1 ! 5),
		chorusAmps = \chorusAmps.kr(1 ! 3),
		sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
			* EnvGen.kr(Env.linen(attack, time, decay)),
		// Klank(decay) - Klank(attack) is like a bank of Formlets
		filt = Klank.ar(`[harm, amps, decays], sig, freqscale: filtFreq, decayscale: filtDecay)
			- Klank.ar(`[harm, amps, decays], sig, freqscale: filtFreq, decayscale: filtAttack),
		shaped, dly, cfreqRand = chorusFreq * 0.2;
	sig = sig + (Limiter.ar(filt) * filtAmp);
	shaped = Shaper.ar(shapebuf, sig.clip(-1.0, 1.0));
	sig = LeakDC.ar(XFade2.ar(sig, shaped, shapeXf));
	dly = sig;
	chorusAmps.do { |amp|
		dly = DelayL.ar(dly, chorusDelay + chorusAmt,
			SinOsc.kr(
				chorusFreq + Rand(cfreqRand.neg, cfreqRand),
				Rand(0, 2pi),
				chorusAmt, chorusDelay
			)) * amp;
		sig = sig + dly;
	};
	sig = RLPF.ar(sig, ffreq, lprq);
	DetectSilence.ar(sig, 0.001, doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, amp * ampMap));
}).add;

SynthDef(\bufGrainPanKlRing, { |start, time, bufnum, pan, rate = 1, amp = 1, ampMap = 1,
		attack = 0.001, decay = 0.02, outbus, filtFreq = 2000, filtAttack = 0.1, filtDecay = 1.0,
		filtAmp = 1,
		fShiftWidth = 0.05, mixProb = 0.5, movingProb = 0.22,
		ffreq = 2000, lprq = 1|
	var harm = \harm.kr((1..5)),
		amps = \amps.kr((1..5).reciprocal),
		decays = \decays.kr(1 ! 5),
		sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
			* EnvGen.kr(Env.linen(attack, time, decay)),
		// Klank(decay) - Klank(attack) is like a bank of Formlets
		filt = Klank.ar(`[harm, amps, decays], sig, freqscale: filtFreq, decayscale: filtDecay)
			- Klank.ar(`[harm, amps, decays], sig, freqscale: filtFreq, decayscale: filtAttack);
	sig = sig + (Limiter.ar(filt) * filtAmp);
	sig = (sig * (Rand(0, 1) < mixProb)) + FreqShift.ar(sig,
		Select.ar(Rand(0, 1) < movingProb, [
			Line.ar(*([({ Rand(-0.2, 0.2) } ! 2) * filtFreq] ++ filtDecay)),
			TExpRand.ar(-0.2, 0.2, 1) * filtFreq
		])
	);
	sig = RLPF.ar(sig, ffreq, lprq);
	DetectSilence.ar(sig, 0.001, doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, amp * ampMap));
}).add;


SynthDef(\pvplayPan, { |outbus, pvbuf, startFrame, time = 1, rate = 1, amp = 1, ampMap = 1, pan,
	attack = 0.01, decay = 0.05, shiftS = 0, shiftE = 0|
	var	fft = PV_PlayBuf(LocalBuf(Index.kr(pvbuf, 0), 1), pvbuf, rate, startFrame, loop: 0),
		sig;
	fft = PV_BinShift(fft, 1, Line.kr(shiftS, shiftE, time));
	sig = IFFT(fft, 1)
		* EnvGen.kr(Env.linen(attack, time - attack - decay, decay), doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, amp * ampMap));
}).add;

SynthDef(\pvplayPanEnvShift, { |outbus, pvbuf, startFrame, time = 1, rate = 1, amp = 1, ampMap = 1, pan,
	attack = 0.01, decay = 0.05 /*, shiftS = 0, shiftE = 0, shiftFreq = 1 */|
	var	fft = PV_PlayBuf(LocalBuf(Index.kr(pvbuf, 0), 1), pvbuf, rate, startFrame, loop: 0),
		sig,
		env = NamedControl.kr(\env, (0 ! 40).overWrite(Env.zero.asArray));
		// lowShift = min(shiftS, shiftE),
		// hiShift = max(shiftS, shiftE);
	fft = PV_BinShift(fft, 1, EnvGen.kr(env, timeScale: time));
	sig = IFFT(fft, 1)
		* EnvGen.kr(Env.linen(attack, time - attack - decay, decay), doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, amp * ampMap));
}).add;


// amp is per-event control; ampMap should be mapped to kr bus for continuous volume control
SynthDef(\pvplayStereo, { |outbus, pvbuf, startFrame, time = 1, rate = 1, amp = 1, pan,
	attack = 0.01, decay = 0.05, shiftS = 0, shiftE = 0, ampMap = 1|
	var	frSize = Index.kr(pvbuf, 0),
		even = PV_PlayBuf(LocalBuf(frSize, 1), pvbuf, rate, startFrame, loop: 0),
		odd, sig;
	even = PV_BinShift(even, 1, Line.kr(shiftS, shiftE, time));
	odd = PV_Copy(even, LocalBuf(frSize, 1));
	even = PV_EvenBin(even <! odd);
	odd = PV_OddBin(odd);
	sig = Limiter.ar(IFFT([even, odd], 1) * amp * ampMap)
		* EnvGen.kr(Env.linen(attack, time - attack - decay, decay), doneAction: 2);
	Out.ar(outbus, Balance2.ar(sig[0], sig[1], pan));
}).add;

SynthDef(\bufGrainPanPhaser, { |start, time, bufnum, pan, amp = 1, ampMap = 1,
		rate1 = 1, rate2 = 1, proportion = 0.5,
		attack = 0.001, decay = 0.02, outbus, rgate = 1,  // gate just for quick release
		filtDelay = 0.005, filtSpeed = 0.1, filtWidth = 0.003, filtDecay = 0.1, filtAmp = 1|
	var sig, ffreq,
		rate = EnvGen.kr(Env([rate1, rate2, rate1], [proportion, 1-proportion], \lin),
			timeScale: time);
	sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0);
	sig = Limiter.ar(sig * amp, 0.99) * EnvGen.kr(Env.linen(attack, time, decay), rgate);
	ffreq = SinOsc.kr(filtSpeed, 0, filtWidth, filtDelay);
	// 0.06 ~= 16 Hz, likely as low a freq as you'll need
	sig = sig + AllpassL.ar(LeakDC.ar(sig), 0.06, ffreq, filtDecay, filtAmp);
	DetectSilence.ar(sig, 0.001, 0.3, doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, ampMap));
}).add;

SynthDef(\krwobble, { |outbus, sustain = 1|
	var	envOne = Env.one.asArray,
		speedEnv = NamedControl.kr(\speedEnv, (0 ! 32).overWrite(envOne)),
		speed = EnvGen.kr(speedEnv, timeScale: sustain),
		widthEnv = NamedControl.kr(\widthEnv, (0 ! 32).overWrite(envOne)),
		width = EnvGen.kr(widthEnv, timeScale: sustain),
		fmul = LFDNoise1.kr(speed).exprange(width.reciprocal, width);
	Out.kr(outbus, fmul);
}).add;


{	|name = \waterfx, numCh = 2, numFr = 256, lo = 1, hi = 7, mid = 1.32432|
	SynthDef(name, { |thresh = 1, wet = 1, outbus, gate = 1|
		var	sig = In.ar(outbus, numCh), sig2,
			fft = FFT({ LocalBuf(numFr, 1) } ! numCh, sig, 0.25, 1),
			fft2 = PV_Copy(fft, { LocalBuf(numFr, 1) } ! numCh),
			// most of this crap will be calculated in the client first,
			// but I wrote it this way for testing and see no need to change it
			// it does basically the same thing as a CurveWarp
			// it's to map the exponential threshold range 0.01 .. 1.0
			// onto an amplitude compensation curve
			ga = mid - lo,
			gb = lo - hi,
			gc = hi - mid,
			sqrterm = sqrt(gb.squared - (4 * ga * gc)),
			qresult = (sqrterm - gb) / (2 * ga),
			grow = if(qresult.rate == \scalar) {
				if(qresult.abs == 1.0) {
					((gb.neg - sqrterm) / (2 * ga)).squared
				} {
					qresult.squared
				};
			} {
				Select.kr(BinaryOpUGen('==', qresult.abs, 1.0), [qresult.squared, ((gb.neg - sqrterm) / (2 * ga)).squared])
			},
			x = (thresh.log / 0.01.log),
			curveA = (hi-lo) / (1.0 - grow),
			curveB = lo + curveA,
			ampComp = curveB - (curveA * pow(grow, x)),
			threshScale = (SampleRate.ir * 0.5 / numFr);
	// 		ampComp = 1; // ((thresh.reciprocal.log / 100.log) * 12).dbamp;
		fft = PV_PartialSynthF(fft, thresh * threshScale, numFrames: 2);
		fft2 = PV_PartialSynthF(fft2, thresh.linlin(0.01, 1, 0.005 * threshScale, 0), numFrames: 2);
		// as threshold goes down, remove the steadiest partials too to expose the watery fft artefacts
		fft = PV_MagSubtract(fft, fft2);
		sig2 = IFFT(fft, 1) * ampComp;
		wet = wet * EnvGen.kr(Env(#[1, 0], #[0.2], releaseNode: 0), gate, doneAction: 2);
		ReplaceOut.ar(outbus, XFade2.ar(sig, sig2, wet.madd(2, -1)));
	}, metadata: (specs: (thresh: #[0.01, 1, \exp], wet: \bipolar)));
} => Func(\makeWateryFx);


#[bufGrainPanFilt, bufGrainPanComb, bufGrainPanKlank, pvplayPan, pvplayPanEnvShift, pvplayStereo, bufGrainPanKlShp, bufGrainPanPhaser, bufGrainPanKlRing].do { |name|
	\addRvbOut.eval((name ++ "Dist").asSymbol, SynthDescLib.at(name).def.func).add;
};


// opening blast!
(
keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		event: (eventKey: \singleSynthPlayNotifyData, vizPath: #[perc]),
		sfpath: topEnvironment[\feetdir].dirname +/+ "samples/feet/58454_sinatra314_footsteps_wooden_floor_loop.wav",
		pvpath: topEnvironment[\feetdir].dirname +/+ "samples/feet/58454_sinatra314_footsteps_wooden_floor_loop-pv512.aiff",
		inChannels: 2,
		master: ~master,
		glrvbmc: ~glrvbmc,
		lcrvbmc: ~lcrvbmc,
		requiredKeys: #[readyToPlay],
		readyToPlay: nil,
		alwaysReset: true,
		numSplashEv: 5,
		maxSynths: 5,
		trajectoryKey: \traj,
		initAmp: 0.36,
		userprep: {
			var	sf;

			[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\receivesSignalFrom, ~chan));

			~pvbuf = Buffer.readAndQuery(s, ~pvpath.standardizePath, completionFunc: e {
				~pvbuf.getn(0, 3, e { |val|
					~fftSize = val[0];
					~hop = val[1];
					~winType = val[2];
					~numPvFrames = (~pvbuf.numFrames - 3) / ~fftSize;
					// [~fftSize, ~hop, ~winType, ~numPvFrames].debug("pv specs");
					~readyToPlay = true;
					~externalInitFuncs.do(_.value);
				});
			});
			if((sf = SoundFile.openRead(~sfpath.standardizePath)).notNil) {
				~sfdur = sf.duration;
			} {
				"Couldn't get duration from %. ~sfdur remains empty.".format(~sfpath).warn;
			};
			~readLabels.();
			~activeSynths = IdentitySet.new;
			~ampCtl = GenericGlobalControl(\amp, nil, ~initAmp, \amp);
		},
		useGui: { |vpi| ~ampCtl => VP(vpi) },
		userfree: {
			[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\stopsReceivingFrom, ~chan));
			~xys.do(_.releaseBus(~collIndex));
			[~pvbuf, ~ampCtl].free;
		},
		stopCleanup: {
			// must check: trajectories could have been .free'd
			if(BP.exists(~trajectoryKey)) {
				BP(~trajectoryKey).notUsedBy(~collIndex);
			};
		},
		recvEventNotify: { |node|
			var	self, ufunc;
			if(node.isKindOf(Synth)) {
				self = currentEnvironment;
				ufunc = { |obj, what|
					if(what == \n_end) {
						obj.removeDependant(ufunc);
						self[\activeSynths].remove(obj);
						if(self[\isPlaying].not and: { self[\activeSynths].isEmpty
								and: { BP.exists(self[\trajectoryKey]) } }) {
							BP(self[\trajectoryKey]).notUsedBy(self.collIndex);
						};
					}
				};
				~activeSynths.add(node);
				NodeWatcher.register(node);
				node.addDependant(ufunc);
			};
		},
		synth: \pv,
		objects: (
			pv: (
				def: \pvplayStereoDist,
				args: [
					distNear: 5, distFar: 20,
					glrvbout: ~glrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels },
					lcrvbout: ~lcrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels },
					pvbuf: Plazy { ~pvbuf.asPattern },
					pt: Plazy { Pn(Pshuf(~pt, 1), inf) },
					startFrame: Plazy { Pkey(\pt) * (~numPvFrames / ~sfdur) },
					#[pan, distance]: Plazy { Pseq(BP(~trajectoryKey).xymaps, inf) },
					shiftS: Pif(Ptime() <= 36, Pwhite(8, 30, inf) * Env(#[1, 0], #[36], \lin)),
					shiftE: Pkey(\shiftS) * Pwhite(0.1, 0.4, inf),
					rate: Pif(Pwhite(0.0, 1.0, inf) < 0.1, Pwhite(0.05, 0.09, inf), Pexprand(Env(#[0.05, 1], #[90], \exp), 1.0, inf)),
					time: 0.25 / Pkey(\rate),
					decay: Pkey(\time) * 0.14,
					amp: Pif(Pkey(\rate) < 0.1, 4, 1) * Env([0, 2, 2, 0], #[3, 26, 7], #[2.1, 0, -2.1]),
					ampMap: Plazy { Pn(~ampCtl.asMap, inf) },
					delta: Ptempo() * max(Pwhite(0.3, 0.6, inf) * Pseq([
						Pn(1, { rrand(2, 5) }),
						Pexprand(0.05, 0.2, { rrand(8, 14) })
					], inf), Pkey(\time) * 0.1),
					instrument: Pfunc { |ev|
						if(~activeSynths.size < ~maxSynths) { ev[\instrument] } { \rest }
					},
					soundID: Pkey(\pan).collect { |map| map.asString[1..].asFloat }
				]
			)
		),
		superPattern: PR(\basicSynthChooser).v[\asPattern],
		splashPattern: {
			Pbind(
				\instrument, \pvplayStereoDist,
				\pvbuf, ~pvbuf,
				\rate, Pgeom.fromEndpoints(1, 0.02, ~numSplashEv),
				\time, 0.6 / Pkey(\rate),
				\decay, Pkey(\time) * 0.14,
				\amp, 12.dbamp,
				\ampMap, ~ampCtl.asMap,
				\pt, Pn(Pshuf(~pt, 1), inf),
				\startFrame, BPStream(\pvstartFrame),
				\pan, Pstutter(2, Pseries.fromEndpoints(-1.0, 0, (~numSplashEv * 0.5).roundUp.asInteger))
					* Pseq(#[1, -1], inf, { 2.rand }),
				\distance, Pseries.fromEndpoints(15, 5, ~numSplashEv),
				\glrvbout, ~glrvbmc.inbus, \glrvbamt, 0.3,
				\lcrvbout, ~lcrvbmc.inbus,
				\chan, ~chan,
				\delta, 0
			)
		},
		asPattern: {
			Pseq([
				Pfuncn({
					BP(~trajectoryKey).isUsedBy(~collIndex);
					Event.silent(0)
				}),
				~splashPattern.(),
				Event.silent(rrand(0.15, 0.45)),
				~superPattern.()
			])
		},
		processLabels: PR(\steps1).v[\processLabels],
		readLabels: PR(\steps1).v[\readLabels],
		labelPath: {
			~sfpath.dirname +/+ ~sfpath.basename[.. ~sfpath.basename.indexOf($_)] ++ "labels3.txt"
		},
		reset: {
			var	str;
			currentEnvironment.env.keys.do { |key|
				if((str = key.asString).contains("Stream")) {
					~makeStreamForKey.(str[ .. str.size - 7].asSymbol);
				}
			}
		},
		registerInitFunc: { |func|
			if(~readyToPlay ? false) {
				func.value
			} {
				~externalInitFuncs = ~externalInitFuncs.add(func);
			};
		}
	));
	0 => BP(name);
}, type: \bp) => Fact(\opening);


PR(\abstractProcess).clone {
	~bufPath = "58454_sinatra314_footsteps_wooden_floor_loop.wav";

// 	~event = (eventKey: \singleSynthPlayer);
	~event = (eventKey: \polySynthPlayerData);
	~quant = #[1, -0.25].asTimeSpec;
	~alwaysReset = true;
	~def = \bufGrainPanFilt;

	~shapeBufSpecs = [
		cheby: #[1],	// 'identity' transfer func
		cheby: #[1, 0, 1],
		cheby: Array.squareAmps(9),
		sine1: #[-1],
		sine1: (1..5).reciprocal.neg,
		sine1: -1 ! 4
	];

	~prep = {
		var	basepath;
		~chan = MixerChannel(~collIndex, s, 2, 2, outbus: topEnvironment[\master], completionFunc: { |chan|
			chan.playfx(Instr.at("busfx.limiter"), [0, 2, 0.99]);
			chan.newPostSend(~rvbmc, 0.075);
		});
		~path = (if(thisProcess.platform.name == \osx) {
			"/Users/dewdrop/SCServer/trax/kc.git/trunk/samples/feet"
//			"/Users/dewdrop/sounds/fx/footsteps"
		} {
//			"/media/DLM/trax/kc/samples/feet"
			basepath = (thisProcess.nowExecutingPath ?? { Document.current.path });
			if(basepath.notNil) { basepath.dirname.dirname +/+ "samples/feet" }
				{ "/media/DLM/trax/kc/samples/feet" }
		}) +/+ ~bufPath;
		// completionFunc: ~start pattern depends on buf samplerate
		~buf = Buffer.readAndQuery(s, ~path/*, completionFunc: e {
			~start = ~start.();
			~ratefix = ~ratefix.();
		}*/);

		~readLabels.();

		~combFreq = BPStream(\combMel).collect { |degree, event| event[\mode].asMode.cps(degree) };

		~shapeBufs = Array(~shapeBufSpecs.size);
		~shapeBufSpecs.pairsDo { |method, amps|
			~shapeBufs.add(Buffer.alloc(s, 2048, 1, completionMessage: { |buf|
				buf.perform((method ++ "Msg").asSymbol, amps);
			}));
		};

		~gestureArray = Pnsym1(BPStream(\gsel), ~gSelectors);

		~klankDcyCtl = GenericGlobalControl(\klankDecay, nil, 0.011, #[0.01, 0.75, \exp]);
		~klankDecay ?? { ~klankDecay = ~klankDcyCtl.asPattern };

		~waterfxdef = ("waterfx" ++ ~collIndex).asSymbol;
		\makeWateryFx.eval(~waterfxdef).add;
		~wetCtl = GenericGlobalControl(\fxwet, nil, 0);
		~threshCtl = GenericGlobalControl(\fxthresh, nil, 1, #[0.01, 1, \exp]);

		currentEnvironment
	};

	~labelPath = {
		~path.dirname +/+ ~path.basename[.. ~path.basename.indexOf($_)] ++ "labels3.txt"
	};
	~readLabels = {
		~pt = TabFileReader.read(~labelPath.());
		~processLabels.();
	};
	~processLabels = {
		var	orig = ~pt, flop = orig.flop;
		~pt = flop[0].asFloat;
		~peaks = flop[#[3, 4]].collect(_.tryPerform(\asFloat));
		~ptd = ~pt.differentiate.drop(1);
		~pt = ~pt.drop(1);
		~mean = ~ptd.mean;
	};

	~useGui = { |vpIndex|
		~klankDcyCtl => VP(vpIndex);
		~wetCtl => VP(vpIndex);
		~threshCtl => VP(vpIndex);
	};

	~freeCleanup = {
		[~chan, ~buf, ~shapeBufs, ~klankDcyCtl, ~wetCtl, ~threshCtl].free;
	};

	~stopCleanup = {
		(e {
			if(~isPlaying.not) { ~stopfx.() };
		}).defer(2.0);
	};

	~lastEventTime = 0;
	~lastItems = IdentitySet.new;

	~numWalkers = 3;
	~numSyncop = 1;

	~dur = Pwhite(18, 30, inf);
	~preSync = Pwhite(0.3, 0.6, inf);

	~gesture = \combMel;
	~gestureOne = \one;
	~gsel = \one;
	~gSelectors = (
		one: Pfunc { |inval|
			(~gestureOne ! inval[\numWalkers])
		},
		unison: Pfunc { |inval|
			inval[\numSyncop] = 0;
			(~gestureStream.next(inval) ! inval[\numWalkers])
		},
		oneSyncop: Pfunc { |inval|
			inval[\numSyncop] = 1;
			(~gestureOne ! inval[\numWalkers])
				.put(inval[\numWalkers].rand, ~gestureStream.next(inval))
		},
		manySyncop: Pfunc { |inval|
			var	out = (~gestureOne ! inval[\numWalkers]),
			pool = Array.series(inval[\numWalkers], 0, 1).scramble;
			inval[\numSyncop] = ~numSyncopStream.next(inval);
			inval[\numSyncop].do { |i|
				out.put(pool[i], ~gestureStream.next(inval))
			};
			out//.debug("gestures")
		}
	);

	~gestures = (
		one: { |i, parms| Pbind(\delta, 1, \amp, ~amp.(i, parms), \ffreq, ~loFilt) },

		accrest: { |i, parms|
			Pbind(
				\instrument, Pseq(#[bufGrainPanKlank, rest]),
				\delta, Pseq([1, parms[\dur] - 1], 1),
// 				\amp, parms[\numWalkers].reciprocal, // ~amp.(i, parms),
				\amp, ~amp.(i, parms),
				\filtAttack, BPStream(\klankAttack),
				\filtDecay, BPStream(\accDecay),
//				\filtAmp, parms[\numWalkers].reciprocal,
// 				\filtAmp, BPStream(\filtAmp),
				\filtFreq, BPStream(\combFreq),
				\ffreq, ~hiFilt,
				\chorusAmt, BPStream(\syncopChorusAmt),
				\chorusDelay, Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf)
			)
		},
		accsteps: { |i, parms, instrOverride|
			Pbind(
				\instrument, instrOverride ?? { Pseq([\bufGrainPanKlank, Pn(~def, inf)]) },
				\delta, 1,
				\amp, ~amp.(i, parms),
//				\amp, Pif(Pbinop('==', Pkey(\instrument), ~def), ~amp.(i, parms), parms[\numWalkers].reciprocal).trace(prefix: "amp: "),
				\filtAttack, BPStream(\klankAttack),
				\filtDecay, BPStream(\accDecay),
//				\filtAmp, parms[\numWalkers].reciprocal,
// 				\filtAmp, BPStream(\filtAmp),
				// ~def uses ffreq; klank synth uses ffreq
				\filtFreq, Pif(Pbinop('==', Pkey(\instrument), ~def), ~loFilt, BPStream(\combFreq)),
				\ffreq, ~hiFilt,
				\chorusAmt, BPStream(\syncopChorusAmt),
				\chorusDelay, Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf)
			)
		},
		stepsacc: { |i, parms|
			Pbindf(~gestures[\accsteps].value(i, parms, Pseq([Pn(~def, parms[\dur] - 1), \bufGrainPanKlank]))/*,
				\amp, Pkey(\amp) * -5.dbamp*/)
		},
		stepsaccUnpitched: { |i, parms|
			Pbindf(~gestures[\accsteps].value(i, parms,
				Pseq([Pn(~def, parms[\dur] - 1), \bufGrainPanKlank])),
				\filtDecay, Pkey(\filtAttack)//,
//				\amp, Pkey(\amp) * 5.dbamp
			)
		},

// filtAmp will NOT help with unpitched variants
// because filtAttack == filtDecay cancels out the filter!
		accstepsUnpitched: { |i, parms|
			Pbindf(~gestures[\accsteps].value(i, parms),
				\filtDecay, Pkey(\filtAttack)//,
//				\amp, Pkey(\amp) * 5.dbamp
			)
		},
		accrestUnpitched: { |i, parms|
			Pbindf(~gestures[\accrest].value(i, parms),
				\filtDecay, Pkey(\filtAttack)//,
//				\amp, Pkey(\amp) * 5.dbamp
			)
		},

		allAcc: { |i, parms|
			Pbindf(~gestures[\accsteps].value(i, parms, \bufGrainPanKlank),
				\amp, Pkey(\amp) * -5.dbamp)
		},

		oneKlank: { |i, parms|
			Pbind(
				\instrument, \bufGrainPanKlank,
				\delta, 1,
				\amp, ~amp.(i, parms),
//				\amp, Pif(Pbinop('==', Pkey(\instrument), ~def), ~amp.(i, parms), parms[\numWalkers].reciprocal),
				\filtFreq, BPStream(\combFreq),
				\filtAttack, 0.01,
				\filtDecay, Env(#[0.01, 0.01, 2.0], [parms.preSyncop, parms.dur - parms.preSyncop], \exp),
//				\filtAmp, parms[\numWalkers].reciprocal,
				\ffreq, 3500
			)
		},

		syncopTemplate: { |i, parms, deltaPat, instrOverride|
			Pbind(
				\delta, deltaPat,
//				\prevDelta, Pdelay(Pkey(\delta), 1),
				\instrument, instrOverride ?? { BPStream(\syncopInstr) },
				\amp, ~amp.(i, parms),
				\filtAttack, BPStream(\klankAttack),
				\filtDecay, BPStream(\klankDecay),
// skip amp control: this is less likely to play multiple klanks at the same time
//				\filtAmp, parms[\numWalkers].reciprocal,
				// ~def uses ffreq; klank synth uses ffreq
// 				\ffreq, Pif(Pbinop('==', Pkey(\instrument), ~def), ~loFilt, BPStream(\combFreq)),
				\filtFreq, Pif(Pbinop('==', Pkey(\instrument), ~def), ~loFilt,
					~syncopCombFreq.(i, parms).collect { |notenum, ev|
						ev[\mode].asMode.cps(notenum)
					}
				),
				\ffreq, ~hiFilt,
				\chorusAmt, BPStream(\syncopChorusAmt),
				\chorusDelay, Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf),
				\chorusAmps, [~chorusAmps]
// 				\rate, Pkey(\rate)
// 					* Pif(Ptime() < parms[\preSyncop], 1, Pstutter(1e6, BPStream(\syncopRateMul)))
			)
		},

		halfSyncop: { |i, parms|
			~gestures[\syncopTemplate].(i, parms, Pseq([Pn(1, parms[\preSyncop]), 1.5, Pn(1, inf)], 1)/*.trace(prefix: "halfSyncop: ")*/)
		},
		triplet4: { |i, parms|
			~gestures[\syncopTemplate].(
				i, parms, Pseq([Pn(1, parms[\preSyncop]), Pn(2/3, inf)], 1)/*.trace(prefix: "triplet4: ")*/,
				Pseq([Pn(~def, parms[\preSyncop]), Pn(\bufGrainPanKlank, inf)])
			)
		},
		dot8: { |i, parms|
			~gestures[\syncopTemplate].(
				i, parms, Pseq([Pn(1, parms[\preSyncop]), Pn(0.75, inf)], 1)/*.trace(prefix: "dot8: ")*/,
				Pseq([Pn(~def, parms[\preSyncop]), Pn(\bufGrainPanKlank, inf)])
			)
		},
		running: { |i, parms|
			~gestures[\syncopTemplate].(
				i, parms, Pseq([Pn(1, parms[\preSyncop]), Pn(rrand(3, 5).reciprocal, inf)], 1)/*.trace(prefix: "running: ")*/,
//				~def
				Pseq([Pn(~def, parms[\preSyncop]), Pn(\bufGrainPanKlank, inf)])
			)
		},
		tripping: { |i, parms|
			Pbindf(
				~gestures[\syncopTemplate].(
					i, parms,
					Pseq([
						Pn(1, parms[\preSyncop]),
						Pwxrand([
							Pseq([0.5, 0.25, 0.25], 1),
							0.25, 0.5, 0.75, 1.0
						], #[3, 1, 2, 2, 2].normalizeSum, inf)
					], 1)/*.trace(prefix: "tripping: ")*/,
//					~def
					Pseq([Pn(~def, parms[\preSyncop]), Pn(\bufGrainPanKlank, inf)])
				),
				\time, min(~maxSustains[~def], Pkey(\delta) * 0.8 - ~quant.phase) / Ptempo()
			)
		},
		someSyncops: { |i, parms|
			var prob;
			~syncProbStream ?? { ~makeStreamForKey.(\syncProb) };
			prob = ~syncProbStream.next(parms);
			~gestures[\syncopTemplate].(i, parms,
				Pseq([
					Pn(1, parms[\preSyncop]),
					Pwrand([1, Pseq(#[1.5, 1.5, 1], 1)], [1 - prob, prob], inf)
				], 1)
			)
		},

		blox: { |i, parms|
			// must not have more than one walker
			if(i == 0) {
				Pbind(
					\instrument, \bufGrainPanKlank,
					\pan, Pwhite(-1.0, 1.0, inf),
		//			\amp, ~amp.(i, parms),
					\bloxNum, Pwhite(3, 6, inf),
					\mnotesStep, Pwrand(#[-1, 0, 1], #[0.1, 0.5, 0.4], inf),
					\mnotes, Pscratch(
						Pvbrown(43, 54, Pwhite(1, 3, inf), inf) -.x Pclump(Pkey(\bloxNum), Pseries(0, Pwrand(#[1, 2, 3], #[0.1, 0.45, 0.45], inf), Pkey(\bloxNum).asStream)),
						Pkey(\mnotesStep),
						memorySize: 30
					),
					\mode, BPStream(\bloxMode),
					\filtFreq, Pfunc { |ev| ev[\mnotes].unmapMode(ev[\mode]).midicps },
					\filtAttack, BPStream(\klankAttack),
					\filtDecay, BPStream(\klankDecay), // Pkey(\filtAttack) + 0.08,
					\chorusAmt, 0, //BPStream(\syncopChorusAmt),
					\chorusDelay, 0, //Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf)
					\chorusAmps, [0 ! 3],
					\ffreq, ~hiFilt,
					\delta, Pstutter(Pwhite(3, 10, inf), 4 / Pxrand((4..10), inf)),
						// Pif allows Pgeom to run when delta does not change
						// Pdiff is always 0 for the first event in a given Pn iteration!
					\amp, PnNilSafe(
						Pif(Pbinop('==', Pdiff(Pkey(\delta)), 0), Pgeom.fromEndpoints(1, 0.15, 10))
					)
				)
			} {
				Event.silent(parms[\dur])
			}
		}
	);

		// was Pkey(\delta) + Pkey(\prevDelta) >= 3, not general enough
	~syncopInstr = Pif(Pfunc { |ev|
		(thisThread.clock.beats + ~leadTime - ~quant.phase % 1) > 0
	}, \bufGrainPanKlank, Pfunc { ~def });

	~mode = \g;
	~combMel = Paccumbounce(28, 49, Pwhite(-7, 7, inf).reject(_ == 0));
	~filtDecay = 1.0;
	~filtAmpSpec = [7.dbamp, -5.dbamp, \exp].asSpec;
//	~filtAmp = Plazy { Pkey(\filtDecay).collect(~filtAmpSpec.map(_)) };

	~modes0 = Mode.keys.asArray.select { |m| m.asString.last == $0 };
	~bloxMode = Pclutch(Prand(~modes0, inf), Pkey(\mnotesStep).abs > 0);

	~syncProb = 0.1;

	~syncopChorusAmt = Pwhite(0.002, 0.012, inf);
	~chorusAmps = (2..4).reciprocal;
	~klankAttack = 0.01;
//	~klankDecay = 0.01;
// 	~syncopRateMul = Pwhite(1.2, 2.0, inf);
	~syncopCombFreq = { |i, parms|
		Pscratch(
			Pwhite(37, 46, inf) +.x Pseq([0, Pwhite(2, 5, 1)], 1),
			// this is the movement-direction pattern: -1, +1 or 0
			// we do 12-24 forward/backward movements (to repeat or bounce between notes)
			// then a pair of forward moves to get new pitches
			Pseq([
				Pfinval({ rrand(12, 24) },
					Pswitch1([Pseq(#[1, -1], inf), 0], Pseq([0, Prand(#[0, 1], inf)], 1))),
				1, 1, // choose two new pitches
			], inf),
			memorySize: 20
		)
	};

/* deprecated, simpler syncopcombfreq
	{ |i, parms|
		Prand(rrand(28, 46) + [0, rrand(2, 6)], inf)
	};
*/

	~loFilt = 2400;
	~hiFilt = 18000;
	~index = Plazy { Pwhite(0, ~ptd.size - 1, inf) };
	~delta = { |key, parms|
		Plazy { ~deltas[key].(parms).asPattern }
	};
	~rate = 1.25;
	~ratefix = Plazy { Pindex(~ptd, Pkey(\i), inf) / ~mean };
	~eventLag = Pwhite(0.0, 0.03, inf);
	~start = Plazy { (Pindex(~pt, Pkey(\i), inf) + (Pfunc { BP(~collIndex).quant.phase } / Ptempo() * Pkey(\rate))) * ~buf.sampleRate };

	~pan = { |i, parms|
		if(parms[\numWalkers] > 1) {
			i.linlin(0, parms[\numWalkers] - 1, -1, 1)
		} {
			0
		}
	};

	~amp = 1;

	~maxSustains = (
		bufGrainPanFilt: 0.8,
		bufGrainPanComb: 0.4,
		bufGrainPanKlank: 0.4,
		default: 0.8
	);

	~oneWalkerPattern = { |gesture, i, parms|
		Pbind(
			\time, Pif(Pfunc { |ev| ev[\time].isNil },
				min(
					Pfunc { |ev| ~maxSustains[ev[\instrument]] ?? { ~maxSustains[\default] } },
					Pkey(\delta)
				) / Ptempo(),
				Pkey(\time)
			)
		)
		<>
		~gestures[gesture].value(i, parms)
		<>
		Pbind(
			\instrument, ~def,
			\bufnum, ~buf,
			\gesture, gesture,
			// random indices, but a value must not repeat any chosen at the current timepoint
			\i, BPStream(\index).reject { |x|
				if(thisThread.clock.beats == ~lastEventTime) {
					if(~lastItems.includes(x)) {
						true
					} {
						~lastItems.add(x);
						false
					}
				} {
					~lastItems.clear.add(x);
					// this needs to be set only when the two are not equal
					// and that happens only in this false branch
					~lastEventTime = thisThread.clock.beats;
					false
				};
			}, // .collect { |x| x.debug(thisThread.clock.beats.asString); x },
			\rate, BPStream(\ratefix) * BPStream(\rate),
			\attack, 0.005,
			// note, phase is expected to be -1..0 so '+' really subtracts
			\start, BPStream(\start),
			\lag, BPStream(\eventLag),
			\mode, if(parms[\gestureArray][i] != \one) { Pstutter(1e6, BPStream(\mode)) } { \default },
			\chan, ~chan,

			// klank synth crashes in linux if bufnum is -1; gesture can override
			\shapebuf, ~shapeBufs.first,
 			\pan, ~pan.(i, parms)
		)
		<>
		parms
	};

	// this is the hook for a visual-event dispatcher to get the next composite pattern
	~oneAggregateGesture = { |inval|
		var	dur, preSyncop, parms, gestArray, result;

		~numWalkersStream ?? { ~makeStreamForKey.(\numWalkers) };
		~durStream ?? { ~makeStreamForKey.(\dur) };
		~preSyncStream ?? { ~makeStreamForKey.(\preSync) };
// 		~whichSyncStream ?? { ~makeStreamForKey.(\whichSync) };
		~gestureStream ?? { ~makeStreamForKey.(\gesture) };
		~gestureArrayStream ?? { ~makeStreamForKey.(\gestureArray) };
		~numSyncopStream ?? { ~makeStreamForKey.(\numSyncop) };
// 		~modeStream ?? { ~makeStreamForKey.(\mode) };

		result = block { |break|
			dur = ~durStream.next;
			if(dur.notNil and: { dur > 0 }) {
				parms = (dur: dur, numWalkers: ~numWalkersStream.next(inval));
				if(parms[\numWalkers].isNil) { break.(nil) };
				if(parms[\numWalkers] > 0) {
					preSyncop = ~preSyncStream.next(dur);
					if(preSyncop.isNil) { break.(nil) };
					if(preSyncop < 1.0) {
						preSyncop = (dur * ~preSyncStream.next(dur)).roundUp(1);
					};
					gestArray = ~gestureArrayStream.next(parms).asArray;
					if(gestArray.size < parms[\numWalkers]
						or: { gestArray.any(_.isNil) }) { break.(nil) };
					parms.put(\gestureArray, gestArray)
						.put(\preSyncop, preSyncop.roundUp(1));
					/*Pfindur*/ Psync(Ppar(
						gestArray.collect { |gesture, i|
							~oneWalkerPattern.(
								gesture,
								i,
								parms
							)
						}
					), dur, dur)
				} {
					// numWalkers = 0, just rest
					// empty array in Ppar would fail anyway
					Event.silent(dur)
				};
			};
		};
		result ?? {
			// force reset of subpatterns - we don't know which one(s) ended early
			// returning 'nil' makes PnNilSafe in ~asPattern stop
			~durStream = nil;
			~numWalkersStream = nil;
			~preSyncStream = nil;
			~gestureStream = nil;
			~gestureArrayStream = nil;
			~numSyncopStream = nil;
			nil
		};
	};

	~asPattern = {
		PnNilSafe(Plazy { |inval|
			~oneAggregateGesture.(inval)
		}, inf)
/*.collect { |ev|
	if(ev[\instrument] != ~def) { [ev[\gesture], ev[\amp]].debug("gesture, amp") };
	ev
}*/
	};

	~playfx = {
		~fx ?? {
			s.makeBundle(0.1, {
				~fx = ~chan.playfx(~waterfxdef, [wet: ~wetCtl.asMap, thresh: ~threshCtl.asMap])
			});
		};
	};

	~stopfx = {
		~fx !? { ~fx.release; ~fx = nil };
	};
}.putAll((master: ~master, rvbmc: ~rvbmc)) => PR(\steps1);



(
keys: #[master, rvbmc],
make: { |name|
PR(\steps1).chuck(BP(name), nil, (
	bufPath: "16771__dobroide__20060307-comp1.swamp.wav",
	requiredKeys: #[peakReady],
	master: ~master,
	rvbmc: ~rvbmc,

	ratefix: 1,	// removes need for ~ptd
//	index: Plazy { Pwhite(0, ~pts.size - 1, inf) },
	// "wet" footsteps only
	index: Plazy { \patRejectLastN.eval(Prand(~pt.collectIndices { |it| it.name.contains("wet") }, inf), 5) },
	start: Plazy { (Pindex(~pts, Pkey(\i), inf) + (Pfunc { BP(~collIndex).quant.phase } / Ptempo() * Pkey(\rate))) * ~buf.sampleRate },
	amp: Pfunc { |ev| ~pt[ev[\i]].peak.reciprocal },
	muffleFactor: 0.05,
	loFilt: 15000,
	rate: 1,

	processLabels: {
		var	a;

		~pt = ~pt.collect { |row, i|
			2.do { |i| row[i] = row[i].asFloat };
			a = (pre: row[0], step: row[1], name: row[2]);
			if(i < (~pt.size-1)) {
				a.put(\timeToNext, ~pt[i+1][0].asFloat - row[0])
					// pv buffer coordinates are normalized 0..1 -> 0..b.dur
					// each pvbuf's duration is timeToNext + 0.2
					.put(\pvpre, 0.1 / (a.timeToNext + 0.2))
					.put(\pvstep, (a.step - a.pre + 0.1) / (a.timeToNext + 0.2))
			};
			a
		};
		~pts = ~pt.collect(_.step);

		~pvbufs = (~path.dirname +/+ "16771_wet_pvs/*.aiff").pathMatch.collect { |path, i|
			Buffer.readAndQuery(s, path, completionFunc: e { |buf|
				buf.get(0, e { |fsize|
					~pt[path.basename[0..1].asInteger].pvFrames_((buf.numFrames - 3) / fsize)
						.pvIndex_(i)
				});
			});
		};

//		~ptw = ~pts.select { |num, i| ~pt[i].name.contains("wet") };
//		~ptd = ~pts.differentiate.drop(1);
		fork {
			var	count = ~pt.size, env = currentEnvironment;
			~chan.server.sync;
			~pt.do { |pt, i|
				var syn = Synth(\returnPeak, [bufnum: ~buf.bufnum, start: pt.pre * 44100,
					frames: 44100 * (if(~pt[i+1].notNil) { (~pt[i+1].pre - pt.pre) } { ~buf.duration - pt.pre })
				]);
				OSCpathResponder(s.addr, ['/tr', syn.nodeID], { |t, r, m|
					pt.peak = m[3];
					r.remove;
					count = count - 1;
					if(count == 0) { "peak values are ready".postln; env[\peakReady] = true };
				}).add;
				0.1.wait;
			};
//			try { ~chan.postSends[0].level = 0.2 } { "watersteps: couldn't set send level".debug };
		};
		~gestures.put(\stepsrest, { |i, parms|
			Pbind(
				#[delta, instrument], Pseq([
					Pn([1, ~def], parms[\preSyncop]),
					[parms[\dur] - parms[\preSyncop], \rest]
				]),
				\amp, ~amp.(i, parms),
				\ffreq, ~loFilt
			)
		})
		.put(\stepsmuffled, { |i, parms|
			Pbindf(~gestures[\one].(i, parms),
				\ffreq, Pseq([Pn(~loFilt, parms[\preSyncop]), ~loFilt * BPStream(\muffleFactor)])
			)
		})
		.put(\onept5, { |i, parms|
			parms[\preSyncop] = parms[\dur] - (parms[\dur] - parms[\preSyncop]).roundUp(3);
			Pbindf(~gestures[\one].(i, parms), \delta, Pseq([Pn(1, parms[\preSyncop]), Pn(1.5, inf)]))
		})
		.put(\somept5, { |i, parms|
			Pbindf(~gestures[\one].(i, parms),
				\delta, Pseq([
					Pn(1, { rrand(4, 10) }),
					Pn(1.5, { rrand(1, 3) * 2 })
				], inf)
			)
		})
		.put(\onept5stretch, { |i, parms|
			parms[\preSyncop] = parms[\dur] - (parms[\dur] - parms[\preSyncop]).roundUp(3);
			Pbindf(~gestures[\one].(i, parms),
				\delta, Pseq([Pn(1, parms[\preSyncop]), Pn(1.5, inf)]),
				\instrument, Pif(Pkey(\delta) > 1, \pvplayPan, ~def),
				\pt, Pindex(~pt, Pkey(\i), inf),
				\pvbuf, Pfunc { |ev| ~pvbufs[ev[\pt].pvIndex] },
				\rate, Pkey(\delta).reciprocal,
				\time, Pkey(\delta) * (0.9 / thisThread.clock.tempo),
				\startFrame, Pfunc { |ev|
					(ev[\pt].pvstep + (~quant.phase / (ev[\pt].timeToNext + 0.2) * ev[\rate]))
						* ev[\pt].pvFrames
				},
				\amp, Pkey(\pt).collect(_.peak).reciprocal
			)
		})
		.put(\stepsStretch, { |i, parms|
			Pif(Pkey(\delta) > 1,
				Pbind(
					\instrument, \pvplayStereo,
					\time, (Pkey(\delta) + 2) * Pkey(\time),  // where time comes from Pbindf
					\startFrame, Pfunc { |ev|
						(ev[\pt].pvstep + (~quant.phase / (ev[\pt].timeToNext + 0.2) * ev[\rate]))
							* ev[\pt].pvFrames
					},
					\decay, Pkey(\time) * 0.5,
					\amp, Pkey(\pt).collect(_.peak).reciprocal * 1,
					\pan, Pkey(\pan) * 0.2
				),
				Pfunc { |ev| ev }	// delta <= 1, pass event thru unmodified
			)
			<>
			Pbindf(~gestures[\one].(i, parms),
				\delta, Pseq([Pn(1, parms[\preSyncop]), 0, parms[\dur] - parms[\preSyncop]]),
				\time, 0.99 / thisThread.clock.tempo,
				\pt, Pindex(~pt, Pkey(\i), inf),
				\pvbuf, Pfunc { |ev| ~pvbufs[ev[\pt].pvIndex] },
				\rate, max(Pkey(\delta), 1).reciprocal
			)
		});
		~freeCleanup = { ~pvbufs.free } <> ~freeCleanup;
	}
));
},
type: \bp) => Fact(\watersteps);


(
keys: #[master, rvbmc],
filename: "L_7304__ingeos___stream_underwater_Ruisseau_de_Ponchale_Les_Peyroux_23_St_Goussaud_France.aiff",
make: { |name|
	var	basepath;
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		filename: ~filename,
		buf: ~buf,
		myBuf: false,
		userprep: {
			~buf ?? {
				~bufpath = (if(thisProcess.platform.name == \osx) {
						"/Users/dewdrop/SCServer/trax/kc.git/trunk/samples/feet"
// 						"/Users/dewdrop/sounds/fx/water"
					} {
						basepath = (thisProcess.nowExecutingPath ?? { Document.current.path });
						if(basepath.notNil) { basepath.dirname.dirname +/+ "samples/feet" }
							{ "/media/DLM/trax/kc/samples/feet" }
					}) +/+ ~filename;
				~buf = Buffer.readAndQuery(s, ~bufpath/*, completionFunc: e {}*/);
				~myBuf = true;
			};
			~event.put(\bufnum, ~buf.bufnum);
			~rq = GenericGlobalControl(\rq, nil, 0.14236, \myrq);
			~stdArgs = ~stdArgs.();
			~originalSigBus = BusDict.audio(s, 2, name.asString + "save original signal");
			~chan.doWhenReady {
				~chan.newPostSend(~rvbmc, 0.4);
				Synth('mixers/Send2', [busin: ~chan.inbus, busout: ~originalSigBus, level: 1],
					~chan.effectgroup, \addBefore);
			};
		},
		inChannels: 2,
		master: ~master,
		rvbmc: ~rvbmc,
		userfree: {
			if(~myBuf) { ~buf.free };
			[~rq, ~originalSigBus].free;
			BP(~collIndex).releaseDependants;
		},
		stopCleanup: {
			~playingRingz !? { s.sendMsg(\n_set, ~playingRingz, \quickRelease, 0) };
		},

		// one and only one instance of ringz synth at a time
		synth: Plazy {
			Pwrand(#[bpf, ringz], #[0.97, 0.03], inf).reject { |key|
				~playingRingz.notNil and: { key == \ringz }
			}
		},
//		playingRingz: false,

		delta: Pexprand(0.25, 1.5, inf).round(0.25), //Pwhite(2.0 * 0.2, 5.0 * 0.6, inf) * Ptempo(),
		overlap: Pexprand(1.5, 2.5, inf), //Pwhite(0.6.reciprocal, 5, inf),
		rate: Pexprand(3/4, 4/3, inf), //1,
		start: Pwhite(0, Plazy { ~buf.numFrames - (Pkey(\time) /*/ Ptempo()*/ * Pkey(\rate) * ~buf.sampleRate) }, inf),
		attack: 0.7, decay: 0.9,
		amp: 2.4,

		fenvmul: Env(#[0, 1], #[1]),
		envprob: 1,

		// build the real array in ~userprep (so BPS's have the right environment)
		stdArgs: { [
			time: Pkey(\delta) * BPStream(\overlap) / Ptempo(),
			rate: BPStream(\rate),
			start: BPStream(\start),
			attack: BPStream(\attack), decay: BPStream(\decay),
			amp: BPStream(\amp),
		] },

		objects: { (
			bpf: (
				def: SynthDef(\bufGrainPanBPF, { |start, time, bufnum, panS, panE, rate = 1, amp = 1,
						attack = 0.001, decay = 0.02, outbus, ffreq = 2000, rq = 1|
					var sig, pan;
					sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
						* EnvGen.kr(Env.linen(attack, 1, decay), timeScale: time, doneAction:2);
					sig = BPF.ar(sig, ffreq, rq);
					pan = Line.kr(panS, panE, time);
					Out.ar(outbus, Pan2.ar(sig, pan, amp));
				}),
				args: ~stdArgs ++ [
					ffreq: Ppatlace([Pexprand(1500, 3000, inf), Pexprand(3600, 7000, inf)], inf, { 2.rand }),
					rq: ~rq.asMap,
					panS: Pwhite(0.6, 1.0, inf) * Prand(#[-1, 1], inf),
					panE: Pif(Pwhite(0.0, 1.0, inf) < 0.15,
						Pwhite(0.6, 1.0, inf) * Pkey(\panS).sign.neg,
						Pkey(\panS)
					)
				]
			),
			bpfperc: (
				def: SynthDef(\bufGrainPanBPFPerc, { |start, time, bufnum, panS, panE, rate = 1, amp = 1,
						attack = 0.05, /*decay = 0.95,*/ outbus, ffreq = 2000, rq = 1|
					var sig, pan;
					sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
						* EnvGen.kr(Env.perc(attack, 1 - attack), timeScale: time, doneAction:2);
					sig = BPF.ar(sig, ffreq, rq);
					pan = Line.kr(panS, panE, time);
					Out.ar(outbus, Pan2.ar(sig, pan, amp));
				}),
				args: ~stdArgs[2..3] ++ [
					delta: Pwrand([Pn(0.25, 2), 0.5, 0.75], #[0.1, 0.55, 0.35], inf),
					time: 0.2 / Ptempo(),
//					overlap: 0.1 / Pkey(\delta),
					attack: 0.05,
					amp: 5,
					ffreq: Ppatlace([Pexprand(1500, 3000, inf), Pexprand(3600, 7000, inf)], inf, { 2.rand }),
					rq: ~rq.asMap,
					panS: Pwhite(0.6, 1.0, inf) * Prand(#[-1, 1], inf),
					panE: Pif(Pwhite(0.0, 1.0, inf) < 0.15,
						Pwhite(0.6, 1.0, inf) * Pkey(\panS).sign.neg,
						Pkey(\panS)
					)
				]
			),
			ringz: (
				def: SynthDef(\bufGrainRingz, { |start, time, bufnum, panC = 0, panS = 1, rate = 1, amp = 1,
					i_fund = 440, rdecay = 0.2,
					attack = 0.001, decay = 0.02, outbus, quickRelease = 1|
					var sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0),
						eg = EnvGen.kr(Env.linen(attack, 1, decay),
							gate: Select.kr(quickRelease, [(decay*time).neg - 1, 1]),
							timeScale: time
						),
						initPulse = Impulse.kr(0),
						fenv = \fenv.kr(Env.one.asArray.extend(32, 0)),
						feg = EnvGen.kr(fenv, timeScale: time * (attack + 1 + decay)),
						fcurve = i_fund * feg,
						n = 5,
						// to shuffle Ringz array dynamically on each synth node init
						// must use one and only one Dshuf, but multiple Demand's
						shuf = Dshuf((1..n), 1),
						fmul = { Demand.kr(initPulse, 0, shuf) } ! n;
					sig = Ringz.ar(sig * eg,
						({ ExpRand(0.9, 0.9.reciprocal) } ! n) * fmul * fcurve,
						rdecay
					);
					sig = Splay.ar(sig, panS, amp, panC);
				//	DetectSilence.ar(sig.sum * egdone, 0.001, doneAction: 2);
					FreeSelf.kr(TDelay.kr(Done.kr(eg), rdecay));
					Out.ar(outbus, Limiter.ar(sig));
				}),
				args: ~stdArgs ++ [
					fund: Pexprand(150, 600, inf),
					panC: Pwhite(-0.4, 0.4, inf),
					panS: 1 - Pkey(\panC).abs,
					rdecay: Pexprand(0.06, 0.3, inf),
					amp: 0.02,
					time: Pkey(\delta) * Pwhite(15.0, 25.0, inf) / Ptempo(),
					start1: Pwhite(0, Plazy { ~buf.numFrames - ((1 + Pkey(\attack) + Pkey(\decay)) * Pkey(\time) * Pkey(\rate) * ~buf.sampleRate) }, inf),
					checkStart: Pfunc { |ev|
						if(ev[\start1] < 0) {
							ev[\rate] = ~buf.duration / (ev[\time] * (1 + ev[\attack] + ev[\decay]));
							ev[\start] = 0
						} { ev[\start] = ev[\start1] };
						ev[\start]
					},
					fenv: Pif(Pwhite(0.0, 1.0, inf) < BPStream(\envprob),
						Pfunc {
							var	n = rrand(5, 8);
							Env(
								{ |i|
									(rrand(-1.0, 1.0) * ~fenvmul.at(i / (n-1)))
									.linexp(-1, 1, 0.5, 2.0)
								} ! n,
								({ rrand(0.1, 1.0) } ! (n-1)).normalizeSum,
								\sin
							)
						},
						Env.one
					),
					// I need to know the ID to track when the synth ends
					id: Pfunc {
						var	id = s.nextNodeID;
						~playingRingz = id; //.debug("playingRingz");
						OSCpathResponder(s.addr, ['/n_end', id], e { |time, resp, msg|
							resp.remove;
							~playingRingz = nil//.debug("playingRingz");
						}).add;
						id
					}
				]
			)
		) },
		rhythmicize: { |beats(80)|
			~override.(\synth, Pif(Ptime() < beats, \bpfperc), false, { "rhythm done".postln; });
			~bpfperctime = Env(#[2.5, 0.4, 2.5], #[0.375, 0.625] * beats, #[-2, 2]).asStream / Ptempo.new;
			~bpfpercamp = Env(#[5, 9, 5], #[0.375, 0.625] * beats, #[2, -2]);
			~bpfpercpanS = 0; ~bpfpercpanE = 0;
			BP(#[brookPL, brookPR]).do { |bp, i|
				bp.bpfperctime_(0.4 / Ptempo()).bpfpercamp_(Pseg(
					Pseq([0, 9, 9, 0]),
					Pseq([#[0.375, 0.625, 0.25] * beats, 1].flat),
					Pseq([2, 0, -2, 0])
				)).delta_(BP(\brook).bpfpercdelta);
				bp.play(1);
			};
		}
	));
	1 => BP(name);
},
type: \bp) => Fact(\brook);


{	var	e;
	fork {
		if(BP.exists(\brook).not) {
			Fact(\brook) => BP(\brook);
			1.0.wait;
		};
		e = (
			delta: Pwrand([Pn(0.25, 2), 0.5, 0.75], #[0.1, 0.55, 0.35], inf),
			synth: \bpfperc,
			// addFunc doesn't really work with a proto
			// but userfree is an internal 'method' so it's ok here
			userfree: BP(\brook).v[\userfree].addFunc {
				BP(\brook).removeDependant(currentEnvironment)
			},
			update: { |obj, what, more|
				if(more == \stopped) { BP(~collIndex).stop(1) }
			}
		);
		BP(#[brookPL, brookPR]).free;
		Fact(\brook).chuck(BP(\brookPL), nil, (buf: BP(\brook).buf));
		Fact(\brook).chuck(BP(\brookPR), nil, (buf: BP(\brook).buf));
		BP(#[brookPL, brookPR]).do { |bp, i|
			bp.bpfpercpanS_(i*2-1).bpfpercpanE_(bp.bpfpercpanS);
			bp.v.putAll(e);
			BP(\brook).addDependant(bp.v);
		};
	};
} => Func(\makeBrookLR);



// water chords
(
keys: #[master, glrvbmc, lcrvbmc],
numCombs: 10,
cFundamental: 67.midicps,
cStep: 67.midicps / 4,	// i.e., 67.midicps is 4th partial, next comb will be 5th
cLevelRatio: 1.5.dbamp,
make: { |name|
	var out;

	WrapInstr([\osc2, \vosc3map2], { |freq, bufbase, numbufs, basefreq, topfreq, gate, freqmul = 1, env|
		var	baselog = log2(basefreq),
			newfreq = freq * freqmul,
			freqmap = ((log2(newfreq) - baselog) / (log2(topfreq) - baselog)
				* (numbufs - 1)).clip(0, numbufs - 1.001);
		WrapInstr.wrap([\osc2, \vosc3], [newfreq, gate, bufbase, freqmap, env]);
	}, [\freq, [0, 1000, \linear, 1, 0], [0, 20, \lin, 1, 0], \freq, \freq, NoLagControlSpec(0, 1), #[0.5, 2, \exp, 0, 1], EnvSpec(Env.adsr)]);

	WrapInstr("osc2.vosc3mapfiltenv", { |gate = 1, ffreq, rq, env, fenv, fenv_sens, fenv_vsens, fenv_tscale = 1, pan = 0|
		var	sig = WrapInstr.wrap("osc2.vosc3map2", (nil ! 5) ++ [gate, nil, env.dereference.value]),
			glatch = Latch.kr(gate, gate),
			feg = EnvGen.kr(fenv.dereference.value, gate, timeScale: fenv_tscale);
		feg = (feg - 1) * Sensitivity.kr(1, glatch, fenv_vsens) * fenv_sens + 1;
		sig = RLPF.ar(sig, (ffreq * feg).clip(20, 18000), rq);
		Pan2.ar(sig, pan)
	}, [#[0, 1], \freq, \myrq, EnvSpec(Env.adsr), EnvSpec(Env.one), #[0, 1], #[0, 1], #[0.1, 10, \exp]]);

	// note, this is a mono -> stereo effect
	~combsdef = SynthDef(("combsfx" ++ name).asSymbol, { |outbus, density = 2, clevel = 0.3,
		attack = 0.1, decay = 0.4, combDecay = 2, bigDelay = 1, bigDecay = 20, gate = 1,
		i_littleDelayB0, i_bigDelayB|
		var	sig = In.ar(outbus, 1),
			extendsig = BufCombN.ar(i_bigDelayB, sig, bigDelay, bigDecay),
			shuf = Dshuf((0 .. ~numCombs - 1), 1),
			initPulse = Impulse.kr(0),
			order = { Demand.kr(initPulse, 0, shuf) } ! ~numCombs,
			freqs = Select.kr(order, Array.series(~numCombs, ~cFundamental, ~cStep).reciprocal),
			pulses = { Dust.kr(density) } ! ~numCombs,
			decays = Decay2.kr(pulses, attack, decay),
			combs = BufCombL.ar(i_littleDelayB0 + (0 .. ~numCombs - 1),
				(sig + extendsig) * decays, freqs, combDecay),
			weteg = EnvGen.kr(Env.asr(0.1, 1, 0.5), gate, doneAction: 2);
		combs = Splay.ar(combs, levelComp: false);
		ReplaceOut.ar(outbus, Limiter.ar(combs * clevel * weteg))
	}).add;
	SynthDef('1to2', { |outbus| ReplaceOut.ar(outbus, In.ar(outbus, 1) ! 2) }).add;

	~target = MixerChannel(name, s, 2, 2, level: -27.dbamp, outbus: ~master, completionFunc: { |chan|
//		~mono2Stereo = chan.playfx('1to2');
		StaticEQ(1, \eq, 589.41, -6.457.dbamp, 1, \hishelf, 6947.785, 2.047.dbamp, 1).play(chan);
		~ch = chan.playfx(Instr("busfx.chorus2"), #[0, 2, 2, 3, 0.0040240867741694, 0.11364637357074, 0.0036090192987437, 1.1344639929904, 0.72629173909809]);
		~ch.doWhenPlaying { ~ch.synth.moveToTail(chan.effectgroup) };
	});
	~combsMC = MixerChannel(name ++ "comb", s, 2, 2, level: ~target.level * ~cLevelRatio, outbus: ~master, completionFunc: { |chan|
		chan.newPostSend(~glrvbmc, 0.8);
	});
	~target.doWhenReady {
		~target.newPreSend(~combsMC, 0);
		~target.newPostSend(~glrvbmc, 0.21);
		~target.newPostSend(~lcrvbmc, 0.98);
	};

	~levelSync = Updater(~target.controls[\level], e { |levelCtl, parms|
		if(parms[\what] == \value) { ~combsMC.level = levelCtl.value * ~cLevelRatio }
	});

	~wt = #[squareAmps, sawtoothAmps].collect { |selector|
		\makeWavetables.eval(8, s, 2048, nil, { |nh|
			var	a = Array.perform(selector, nh), i = (0, 2 .. a.size-1).scramble;
			i.keep((i.size * rrand(0.1, 0.2)).asInteger).do { |ind| a[ind] = 0 };
			a
		});
	};
	~bigdelay = Buffer.alloc(s, 44100, 1);
	~littledelays = Buffer.allocConsecutive(~numCombs, s, (s.sampleRate / ~cFundamental).roundUp);
	out = Voicer(16, WrapInstr("osc2.vosc3mapfiltenv"), [
		bufbase: ~wt.first.first.bufnum,
		numbufs: `(~wt.first.size),
		basefreq: `(48.midicps),
		topfreq: `(127.midicps),
		// env: Env.adsr(1.6, 0.8, 0.6, 2.5),
		env: `{
			var	attack = NamedControl.kr(\envAtk, 1.6),
			decay = NamedControl.kr(\envDcy, 0.8);
			Env.adsr(attack, decay, 0.6, 2.5)
		},
		// fenv: Env(#[1, 40, 1], #[3.5, 4.0].normalizeSum, \sin),
		fenv: `{
			var proportion = NamedControl.kr(\fenvProp, 3.5 / (3.5 + 4.0));
			Env(#[1, 40, 1], [proportion, 1 - proportion], \sin)
		},
		fenv_tscale: (3.5+4.0),
		detune: 1.003,
		/* ffreq: 900,*/
		fenv_sens: 0.8,
		fenv_vsens: 1,
		vsens: 0.2
	], target: ~target);
// 	out.mapGlobal(\ffreq, nil, 400, \freq);
// 	out.mapGlobal(\rq, nil, 1, \myrq);
	out.mapGlobal(\clevel, nil, 1, \amp);
	out.mapGlobal(\density, nil, 0.8, #[0.5, 3.0]);
	out.mapGlobal(\freqmul, nil, 1, #[0.5, 2.0, exp], allowGUI: false);
	SynthDescLib.at(out.nodes[0].defname.asSymbol).msgFuncKeepGate = true;
	out
},
free: { ~levelSync.remove; [~target, ~combsMC, ~wt, ~bigdelay, ~littledelays].free },
playfx: { |self| self.use {
	~fx ?? {
		~fx = ~combsMC.playfx(~combsdef.name, [
			clevel: ~value.globalControls[\clevel],  // automagically asMap's
			density: ~value.globalControls[\density],
			i_littleDelayB0: ~littledelays.first, i_bigDelayB: ~bigdelay
		]);
		~target.preSends[0].levelAuto(\ctlPoint, [value: 1, time: 0.25, curve: 2.1]);
	};
} },
stopfx: { |self| self.use {
	~fx !? {
		~target.preSends[0].levelAuto(\ctlPoint, [value: 0, time: 0.25, curve: -2.1]);
		~fx.release;
		~fx = nil;
	}
} },
type: \vc) => Fact(\waterpad);



(keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		event: (eventKey: \polySynthPlayerData),
		bufSource: \op,
		inChannels: 2,
		master: ~master,
		glrvbmc: ~glrvbmc,
		lcrvbmc: ~lcrvbmc,
		alwaysReset: true,
		userprep: {
			if(BP.exists(~bufSource) and: { BP(~bufSource).v[\pvbuf].notNil }) {
				~pvbuf = BP(~bufSource).pvbuf;
				~pt = BP(~bufSource).pt;
				~peaks = BP(~bufSource).peaks;
			} {
				"Couldn't load BP(%); BP(%) not ready".format(~collIndex.asCompileString, ~bufSource.asCompileString).warn;
			};
			~ampCtl = GenericGlobalControl(\amp, nil, 0.75, #[0, 1, \amp]);
			~event.putAll((distNear: 5, distFar: 20,
				glrvbout: ~glrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels },
				lcrvbout: ~lcrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels },
				pvbuf: ~pvbuf, ampMap: ~ampCtl.asMap
			));
		},
		userfree: { ~ampCtl.free },
		useGui: { |vpi| ~ampCtl => VP(vpi) },
		synth: \pvc,
		delta: 1.5,
		panWidth: 0.3,
		panCenter: Pn(Pseries.fromEndpoints(0, 0.9, 3), inf),
		objects: (
			pvc: (
				def: \addRvbOut.eval(\pvplayPanC, { |pvbuf, startFrame, time = 1, rate = 1,
						amp = 1, ampMap = 1, pan,
						attack = 0.01, decay = 0.05,
						numTeeth = 20, cphase = 0, cwidth = 0.5, crate = 0|
					var	fft = PV_PlayBuf(LocalBuf(Index.kr(pvbuf, 0), 1),
							pvbuf, rate, startFrame, loop: 0),
						sig;
					cphase = (Sweep.kr(rate: crate) + cphase).wrap(0.0, 1.0);
					fft = PV_RectComb(fft, numTeeth, cphase, cwidth);
					sig = IFFT(fft, 1)
						* EnvGen.kr(Env.linen(attack, time - attack - decay, decay, curve: #[4, 0, -4]),
							doneAction: 2);
					Pan2.ar(sig, pan, amp * ampMap);
				}),
				args: [
					\num, 3,
					\i, Plazy { Pn(Pshuf((0 .. ~pt.size-1), 1), inf) }.clump(Pkey(\num)),
					\spread, Pn(Pseries(-1, 2 / (Pkey(\num)-1), Pkey(\num).asStream), inf).clump(Pkey(\num)),
					\pan, (Pkey(\spread) * BPStream(\panWidth) + BPStream(\panCenter)).clip(-1.0, 1.0),
					\distance, Pseries.fromEndpoints(5, 20, 3),
					\time, 0.25,
					\eTopRatio, 0.8,
					#[attack, decay], Ptuple([Pkey(\eTopRatio), 1 - Pkey(\eTopRatio)], inf) * Pkey(\time),
					\playspeed, Pwhite(1.2, 1.9, inf),
					\startFrame, Plazy { (Pindex(~pt, Pkey(\i), inf) + (Pkey(\time) * Pkey(\playspeed))) }
						* (BP(\op).numPvFrames / z.duration),
					\rate, Pkey(\playspeed).neg,
					\amp, Plazy { Pindex(~peaks[1], Pkey(\i), inf) }.reciprocal / Pkey(\num) * 20.dbamp,
					\cwidth, Pgeom.fromEndpoints(1.0, 0.3, 3),
					\crate, Pgeom.fromEndpoints(0.1, 15, 3),
					\cphase, Pwhite(0.0, 0.98, inf)
				]
			)
		),
		reset: {
			var	str;
			currentEnvironment.env.keys.do { |key|
				if((str = key.asString).contains("Stream")) {
					~makeStreamForKey.(str[ .. str.size - 7].asSymbol);
				}
			}
		}
	));
	0 => BP(name);
}, type: \bp) => Fact(\stopturn);


(
keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;

	PR(\basicBufferPlayer).chuck(BP(name), nil, (
		event: (
			eventKey: \polySynthPlayerData,
			instrument: \bufGrainPanFiltDist,
			vizPath: #[perc]
		),
		soundID: Pseries(0, 1, inf),
		alwaysReset: true,

		bufPaths: [topEnvironment[\feetdir].dirname +/+ "samples/feet/58454_sinatra314_footsteps_wooden_floor_loop.wav"],
		pvSource: \op,

		inChannels: 2,
		master: ~master,
		glrvbmc: ~glrvbmc,
		lcrvbmc: ~lcrvbmc,

		autoRun: true,

		gest: Pfunc { ~gestures.keys.choose },
		defaultParms: nil,
		initAmp: 0.3,

		early: 0.1,
		buf: 0,
		ptIndex: Plazy { Pwhite(0, ~pt.size-2, inf) },
		start: Pfunc { |ev|
			(~pt[ev[\pt]] - ((ev[\early] ?? { ev[\parms][\early] ?? { ~early } }) * ev[\rate]))
				* ~buffers[ev[\bufIndex]].sampleRate
		},
		time: 0.4,
		rate: Pexprand(0.9, 1.7, inf),
		ffreq: 18000,
		fastDelta: Pexprand(0.08, 0.3, inf),
		amp: Pindex(Pfunc { |ev|
			var	early = ev[\early] ?? { ev[\parms][\early] ?? { ~early } };
			~peaks[(early <= 0).binaryValue]
		}, Pfinval(1, Pkey(\pt)), inf).reciprocal, //.trace(prefix: "amp: "),
		numEv: Pwhite(5, 12, inf),
		gDelta: Pwhite(0.5, 2.5, inf),
		distNear: 5,
		distFar: 20,

		slowDelta: Pn(Plazy { |ev| Pn(rrand(0.3, 0.6), ev[\parms][\numEv] ? 1) }, inf),
		slowRate: Pwhite(0.5, 0.8, inf),
		slowShift: Pexprand(1, 15, inf) - 3,

		rewriteEmbedder: { |int, in, level|
			if(int.every(_.inclusivelyBetween(-16, 16))) {
				Ptuple([
					Pseq(int, 1),
					Pseq([in[1], Pn(level+1, inf)], 1)
				], 1)
			} {
				Pn([0, 0], 0)	// <-- drop this branch totally
			}
		},
			// w/o Plazy, rewriteEmbedder would come from the wrong environment
		kfreq: Plazy {
			PR(\rewriter).copy.prep(Ptuple([Pseq([4, 7, 6], 1), 1], 1), Pseries(0, 1, inf), [
				{ |in| in[0] < 0 } -> { |in, level|
					var int = if(0.5.coin) { #[3, -1] /*.debug(">>> add motive")*/ }
						{ { #[-1, 1, 2, 3].choose } ! rrand(1, 3) };
					~rewriteEmbedder.(([in[0]] ++ int).integrate, in, level);
				},
				{ |in| in[0] > 10 } -> { |in, level|
					var int = if(0.5.coin) { #[-3, 1] /*.debug(">>> add motive")*/ }
						{ { #[-3, -2, -1, 1].choose } ! rrand(1, 3) };
					~rewriteEmbedder.(([in[0]] ++ int).integrate, in, level);
				},
				{ true } -> { |in, level|
					var int = if(0.45.coin) { #[[-3, 1], [3, -1]].choose/*.debug(">>> add motive")*/ }
						{ { #[-2, -1, 1, 2].choose } ! rrand(1, 3) };
					~rewriteEmbedder.(([in[0]] ++ int).integrate, in, level);
				}
			]).keepLowerLevels_(true).rewriteEmbedder_(~rewriteEmbedder)
		},
		nextLowerInt: Pseries({ rrand(1, 3) }, Prand(#[-2, -1, 1, 2], inf), inf)
			.fold(-10, 10).reject { |x, ev| x >= ev[\filtDegree] } - Pkey(\filtDegree),
		chordInt: Pwhite(-3, -1, inf),
		chordN: 0,
		kdecay: Pexprand(0.011, 0.1, inf),
		kamp: 1,
		defaultKlankHarm: (1..5),
		defaultKlankAmps: (1..5).reciprocal,
		defaultKlankDecays: 1 ! 5,
		defaultChorusAmps: (1..3).reciprocal * 0.3,

		// for three-inversions
		runningNotes: (
			lauraslide: Pseries(
				{ rrand(-7, 0) },
				Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
				Pkey(\numEv).asStream
			),
			inversion1: Pseries(
				{ rrand(-3, 4) },
				Pstutter(
					Pseq([Pfuncn({ |ev| (ev[\numEv] * 0.6).round }), 100], 1),
					Pseq([1, -1], 1)
				) * Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
				Pkey(\numEv).asStream
			),
			inversion2: Pseries(
				{ rrand(0, 8) },
				Pstutter(
					Pseries(1, 1, inf),
					Pseq([1, -1], inf, 0 /*, { 2.rand }*/)
				) * Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
				Pkey(\numEv).asStream
			)
		),

		snareRhythms: (
			one: Pn(1, 1),
			dot: Pseq(#[0.75, 0.25], 1),
			revdot: Pseq(#[0.25, 0.75], 1),
			rattata: Pseq(#[0.5, 0.25, 0.25], 1),
			ratatat: Pseq(#[0.25, 0.25, 0.5], 1),
			syncop: Pseq(#[0.25, 0.5, 0.25], 1),
			tripletHead: Pseq([Pn(1/6, 3), 0.5], 1),
			tripletTail: Pseq([0.5, Pn(1/6, 3)], 1),
			triplets: Pn(1/6, 6)				
		),

		postMCCreation: { |chan|
			[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\receivesSignalFrom, ~chan));

			~chan.playfx(Instr("busfx.limiter"), [0, 2, 0.99, 0.05]);

			~ampCtl = GenericGlobalControl(\amp, nil, ~initAmp, \amp);
			~kAmpCtl = GenericGlobalControl(\kAmp, nil, 1, \amp);
			~ffreqCtl = GenericGlobalControl(\ffreq, nil, 18000, \freq);
			~pitchProbCtl = GenericGlobalControl(\pitchProb, nil, 0.15);
			~event.putAll((
				// just in case reverb channels don't exist,
				// push them to hw input buses (to suppress output)
				glrvbout: ~glrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels },
				lcrvbout: ~lcrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels },
				chan: ~chan,
				ampMap: ~ampCtl.asMap
			));
			~readLabels.();

			if(BP.exists(~pvSource)) {
				BP(~pvSource).registerInitFunc(e {
					#[pvbuf, fftSize, hop, numPvFrames].do { |key|
						key.envirPut(BP(~pvSource)[key]);
					}
				});
			} {
				"BP(%) not found; can't use any pv gestures.".format(~pvSource.asCompileString).warn
			};

			~shapebuf = Buffer.sendCollection(s,
				(Pseries.fromEndpoints(-1.0, 1.0, 512).asStream.all * 6.1887796806608).distort
				.as(Signal).asWavetable, wait: 0.05
			);
		},
		useGui: { |vpi| [~ampCtl, ~kAmpCtl, ~ffreqCtl, ~pitchProbCtl].do { |gc| gc => VP(vpi) } },
		free: {
			[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\stopsReceivingFrom, ~chan));
			[~ampCtl, ~kAmpCtl, ~ffreqCtl, ~shapebuf, ~pitchProbCtl].free;
		},
		stopCleanup: {
			~spawner = nil;
			~autoRunner = nil;
			~mSpeedPlayer.stop;
			~mSpeedPlayer = nil;
			~ffreqCtl.stopAuto;
		},

		// external hook to drop a gesture in!
		runGesture: { |parms, holdForStop = false, holdID|
			var	stream;
			if(~isPlaying) {
				parms ?? { parms = () };
				parms[\gest] ?? { parms[\gest] = ~gestStream.next };
				if(parms[\gest].notNil) {
					parms[\numEv] ?? { parms[\numEv] = ~numEvStream.next };
					stream = ~makeGesture.(parms);
					if(holdForStop) {
						stream = CleanupStream(stream.asStream, e {
							~streamsToStop.remove(stream);
							~endStreamHook.(stream, holdID);
						});
						~streamsToStop.add(stream);
					};
					~spawner.par(stream);
				} {
					"BP(%): runGesture failed; gesture is empty and ~gest pattern ended.\n"
					.postf(~collIndex.asCompileString);
				};
			} {
				"BP(%) is not playing, can't run a gesture".format(~collIndex.asCompileString).warn;
			};
		},
		streamsToStop: IdentitySet.new,
		stopSavedStreams: {
			if(~spawner.notNil) {
				~streamsToStop.copy.do { |stream| ~spawner.suspend(stream) };
			};
			~streamsToStop = IdentitySet.new;
		},

		makeGesture: { |parms|
			Pchain(
				~gestures[parms[\gest]].value(parms),
				~baseValuePat.value(parms),
				(parms: parms, soundID: ~soundIDStream.next)
			)
		},

		xyPat: { |parms|
			Ptuple([
				if(parms[\xEnds].notNil) {
					Pseries.fromEndpoints(*(parms[\xEnds] ++ parms[\numEv]))
				} {
					Pseries.fromEndpoints(
						rrand(-1.0, 0.2), rrand(0.2, 1.0), parms[\numEv]
					) * #[-1, 1].choose
				},
				if(parms[\yEnds].notNil) {
					Pseries.fromEndpoints(*(parms[\yEnds] ++ parms[\numEv]))
				} {
					Pseries.fromEndpoints(rrand(~distNear, ~distFar), rrand(~distNear, ~distFar),
						parms[\numEv]
					)
				}
			])
		},

		gestures: (
			clatter: { |parms|
				Pbind(
					#[pan, distance], ~xyPat.(parms),
					\delta, BPStream(\fastDelta),
					\amp, BPStream(\amp)
				)
			},
			oneKlank: { |parms|
				Pbind(
					\vizPath, #[note],
					\vizKeys, Library.at(\defaultVizKeys).copy.put(3, \filtFreq),
					\instrument, Pn(\bufGrainPanKlankDist, 1),
					\delta, 0.5,
					\amp, (parms[\mainAmp] ? 1) * BPStream(\amp),
					#[filtDegree, level], BPStream(\kfreq),
					\filtFreq, Pkey(\filtDegree).collect { |deg| Mode(parms[\mode] ?? { \g }).cps(deg + 35) },
					\filtAttack, 0.01,
					\filtDecay, parms[\kdecay] ?? { BPStream(\kdecay) },
					\filtAmp, BPStream(\kamp),
					\chorusFreq, parms[\chorusFreq] ?? { Pstutter(inf, Pwhite(0.05, 0.11, inf)) },
					\chorusAmt, parms[\chorusAmt] ?? { 0.02 },
					\chorusDelay, parms[\chorusDelay] ?? { 0.03 },
					\chorusAmps, parms[\chorusAmps] ?? { [~defaultChorusAmps] },
					\harm, parms[\harm] ?? { [~defaultKlankHarm] },
					\amps, parms[\amps] ?? { [~defaultKlankAmps] },
					\decays, parms[\decays] ?? { [~defaultKlankDecays] },
					\pan, rrand(-1.0, 1.0),
					\distance, Pkey(\level).linlin(1, 6, ~distNear, ~distFar)
				)
			},
			klankHarmonize: { |parms|
				parms[\mode] ?? { parms[\mode] = \g };
				Pbind(
					\nextLower, BPStream(\nextLowerInt),
					\chord, Pclump(BPStream(\chordN), BPStream(\chordInt)),
					\filtFreq, Ptuple([Pkey(\filtDegree), Pkey(\nextLower), Pkey(\chord)], inf)
						.collect { |item| Mode(parms[\mode]).cps(item.flat.integrate + 35) }
				)
				<> ~gestures[\oneKlank].(parms)
			},
			oneKlankSteps: { |parms|
				Pseq(
					#[oneKlank, clatter].collect { |key| ~gestures[key].(parms) },
					1
				)
			},
			klankHrmSteps: { |parms|
				Pseq(
					#[klankHarmonize, clatter].collect { |key| ~gestures[key].(parms) },
					1
				)
			},
			decay: { |parms|
				parms[\numEv] = rrand(18, 28);
				parms[\yEnds] = [rrand(0.3, 0.4), rrand(0.75, 1.0)].linlin(0, 1, ~distNear, ~distFar);
				Pbind(
					#[pan, distance], ~xyPat.(parms),
					\early, 0,
					\pt, Pstutter(inf, BPStream(\ptIndex).reject(#[3, 10, 14].includes(_))),
					\start, Pstutter(inf, BPStream(\start)),
					\delta, rrand(0.06, 0.09),//.debug("decay delta"),
					\time, Pkey(\delta) * rrand(1.75, 2.2), //rrand(0.6, 0.8),
					\rate, Pstutter(inf, Pkey(\rate)),
					\amp, Pstutter(inf, BPStream(\amp)) / Pindex(~ampCorrections, Pkey(\pt), inf)
						* Pgeom.fromEndpoints(1, -25.dbamp, parms[\numEv]) * -6.dbamp,
					\ffreq, Pstutter(inf, Pkey(\ffreq))
						* Pgeom.fromEndpoints(1, rrand(0.005, 0.012), parms[\numEv])
				);
			},
			slowSteps: { |parms|
				Pbind(
					\instrument, \pvplayPanDist,
					\pvbuf, ~pvbuf,
					\pt, BPStream(\ptIndex).clump(3),
					\start, ~start,
					\startFrame, Pkey(\start) / ~buffers[0].numFrames * ~numPvFrames,
					#[pan, distance], ~xyPat.(parms),
					\delta, BPStream(\slowDelta),
					\rate, BPStream(\slowRate).clump(3),
					\time, Pkey(\delta),
					\amp, BPStream(\amp) * (-4.dbamp),
					\shiftS, BPStream(\slowShift).clump(3),
					\shiftE, Pkey(\shiftS)
				)
			},
			slowStepStretch: { |parms|
				parms[\xEnds] ?? {
					parms[\xEnds] = [rrand(0.5, 1.0) * #[-1, 1].choose, 0]
				};
				parms[\yEnds] ?? {
					parms[\yEnds] = [rrand(0.5, 1.0).linlin(0.0, 1.0, ~distNear, ~distFar), ~distNear]
				};
				parms[\delta] ?? {
					parms[\delta] = (BPStream(\slowDelta)
						* Pgeom.fromEndpoints(1.8, rrand(0.5, 0.7), parms[\numEv])
					)
				};
				Pbind(
					\instrument, \pvplayPanDist,
					\early, 0,
					\pvbuf, ~pvbuf,
					\pt, BPStream(\ptIndex).clump(3),
					\start, ~start,
					\startFrame, Pkey(\start) / ~buffers[0].numFrames * ~numPvFrames,
					#[pan, distance], Pseq([
						Pfinval(parms[\numEv] /* - 1 */, ~xyPat.(parms)),
						[#[-1, 0, 1], ~distNear]
					]),
					\delta, Pseq([parms[\delta], 0.4], 1),
					\rate, Pseq([
						Pfinval(parms[\numEv] /* - 1 */, BPStream(\slowRate).clump(3)),
						Pwhite(0.04, 0.1, 1)
					]),
					\time, Pseq([
						Pfinval(parms[\numEv] /* - 1 */, Pkey(\delta)),
						Pkey(\delta) / Pkey(\rate)
					]),
					\amp, BPStream(\amp) * -4.dbamp,
					\origShiftS, BPStream(\slowShift).clump(3),
					\shiftS, Pkey(\origShiftS) + Pseq([
						Pfinval(parms[\numEv] /* - 1 */, 0),
						Pwhite(3, 9, 1)
					]),
					\shiftE, Pkey(\origShiftS)
				) //.collect { |ev| if(ev[\shiftS][0] > ev[\origShiftS][0]) { ev.postcs } { ev } }
			},
			clatterDecay: { |parms|
				Pseq(#[clatter, decay].collect { |key| ~gestures[key].(parms) }, 1)
			},
			klankDecay: { |parms|
				Pseq(#[oneKlankSteps, decay].collect { |key| ~gestures[key].(parms) }, 1)
			},
			klankMachine: { |parms|
				var	instr = parms[\instr] ?? {
						if(parms[\shapebuf].notNil) { \bufGrainPanKlShpDist }
							{ \bufGrainPanKlankDist }
					},
					list = [
						#[pan, distance], parms[\xyPat] ?? { ~xyPat.(parms) },
						\instrument, Pif((parms[\prob] ? 1).asPattern.coin, instr, \rest),
						\delta, parms[\newDelta] ? 0.5,
						// exciter time only - note dur is from filtDecay
						\time, parms[\excTime] ?? { min(0.15, Pkey(\delta) * 0.7) },
						\rate, parms[\rate] ? 1,
						\filtFreq, parms[\freq] ? Plazy { |ev| Pn(~kfreqStream.next(ev), inf) },
						\filtDecay, Pkey(\delta) * (parms[\timeMul] ? 1),
						\filtAttack, Pkey(\filtDecay) * (parms[\filtAttackRatio] ? 0.05),
						\filtAmp, parms[\kAmp] ?? { ~kAmpCtl.asMap },
						\ffreq, ~ffreqCtl.asMap,
						\lprq, 0.32, //~rqCtl.asMap,
						\amp, parms[\mainAmp] ? 0.5,
						\harm, parms[\harm] ?? {
							Pstutter(Pwhite(3, 6, inf), Pwrand([
								(1..5),
								(1, 3 .. 9),
								Pfuncn({ (1..5) * ({ rrand(0.9, 1.111) } ! 5).put(0, 1) })
							], #[0.4, 0.4, 0.2], inf).collect([_]))
						},
						\amps, Pkey(\harm).reciprocal,
						\chorusDelay, parms[\chorusDelay] ? 0.03,
						\chorusAmt, parms[\chorusAmt] ? 0.02,
						\chorusAmps, [parms[\chorusAmps] ? #[1, 1, 1]],
						\glrvbamt, parms[\glrvbamt] ? 0.075,
						\lcrvbamt, parms[\lcrvbamt] ? 0.035
					];
				if(parms[\start].notNil) {
					list = list ++ [start: parms[\start]];
				};
				if(parms[\shapebuf].notNil) {
					list = list ++ [
						shapebuf: parms[\shapebuf],
						shapeXf: parms[\shapeXf] ? 1
					]
				};
				Pbind(*list)
			},
			klankMachineLWp: { |parms|
				var	pat = ~gestures[\klankMachine].value(parms),
				ppairs = pat.patternpairs,
				filtFreqI = ppairs.indexOf(\filtFreq),
				filtDecayI = ppairs.indexOf(\filtDecay);
				if(filtFreqI.notNil and: { filtDecayI.notNil }) {
					#[0, 1].do { |i|
						ppairs.swap(filtFreqI + i, filtDecayI + i);
					};
					Pbind(*ppairs) // .pairsDo { |key, val| (key -> val).postcs }
				} { nil };
			},
			lauraslide: { |parms|
				Pbind(
					\numEv, parms[\numEv],
					\instrument, Pn(\bufGrainPanKlankDist, parms[\numEv]),
					\delta, 0.4 * Pexprand(0.8, 1.25, inf)
					* Pgeom.fromEndpoints(parms[\startDelta] ?? { rrand(0.35, 0.6) }, rrand(0.1, 0.2),
						parms[\numEv]),
					\amp, BPStream(\amp) * (parms[\ampAdjust] ? 0.04),  // filters are LOUD
					\numNotes, parms[\numNotesPat] ?? { Pwrand(#[1, 2, 3], #[1, 4, 3].normalizeSum, inf) },
					\filtDegree, (~runningNotes[parms[\notesKey] ? \lauraslide].value(parms)
						+.x Pseries(0, Pwrand(#[-1, -2, -3], #[1, 2, 2].normalizeSum, Pkey(\numNotes).asStream), inf))
					.clump(Pkey(\numNotes)),
					\filtFreq, Pkey(\filtDegree).collect { |deg| Mode(\g).cps(deg + 35) },
					\filtAttack, 0.01,
					\filtDecay, Pseries.fromEndpoints(0.2, 2.75, parms[\numEv]),
					\filtAmp, BPStream(\kamp),
					\chorusFreq, parms[\chorusFreq] ?? { Pstutter(inf, Pwhite(0.05, 0.11, inf)) },
					\chorusAmt, parms[\chorusAmt] ?? { 0.02 },
					\chorusDelay, parms[\chorusDelay] ?? { 0.03 },
					\chorusAmps, parms[\chorusAmps] ?? { [~defaultChorusAmps] },
					\harm, parms[\harm] ?? { [~defaultKlankHarm] },
					\amps, parms[\amps] ?? { [~defaultKlankAmps] },
					\decays, parms[\decays] ?? { [~defaultKlankDecays] },
					\pan, sin(Pseries(0, Pseries.fromEndpoints(0.08, 0.33, parms[\numEv]), inf) * 2pi)
					* #[-1, 1].choose,
					\distance, Pseries.fromEndpoints(parms[\startY] ? 20, 5, parms[\numEv])
				)
			}
		),

		autoRunPat: Prout({
			loop {
				~runGesture.(~defaultParms.().copy);
				~spawner.wait(~gDeltaStream.next());
			}
		}),
		addAutoRun: {
			// returns the stream, so I can kill it in the spawner by .suspend
			if(~isPlaying and: { ~autoRunner.isNil }) {
				~autoRunner = ~spawner.par(~autoRunPat);
			} {
				"BP(%): Couldn't do autoRun (not playing or already autorunning)"
				.format(~collIndex.asCompileString).warn;
			};
		},
		removeAutoRun: {
			if(~isPlaying and: { ~autoRunner.notNil }) {
				~spawner.suspend(~autoRunner);
				~autoRunner = nil;
			}
		},
		asPattern: {
			~numEvStream ?? { ~makeStreamForKey.(\numEv) };
			~gDeltaStream ?? { ~makeStreamForKey.(\gDelta) };
			~gestStream ?? { ~makeStreamForKey.(\gest) };
			~soundIDStream ?? { ~makeStreamForKey.(\soundID) };
			Pspawner { |sp|
				~spawner = sp;
				if(~autoRun) {
					"BP(%): autoRun enabled\n".postf(~collIndex.asCompileString);
					~autoRunner = sp.par(~autoRunPat);
				};
				loop {
					sp.wait(0.1);
				}
			}
		},
		baseValuePat: {
			Pbind(
				\distNear, Pfunc { ~distNear },
				\distFar, Pfunc { ~distFar },
				\bufIndex, Plazy { BPStream(\buf) },
				\bufnum, Pfunc { |ev| ~buffers[ev[\bufIndex]].bufnum },
				\pt, Plazy { BPStream(\ptIndex) },
				\rate, Plazy { BPStream(\rate) },
				\start, Plazy { BPStream(\start) },
				\time, Plazy { BPStream(\time) },
				\ffreq, Plazy { BPStream(\ffreq) } //,
			)
		},
		processLabels: PR(\steps1).v[\processLabels],
		readLabels: PR(\steps1).v[\readLabels],
		labelPath: {
			~bufPaths[0].dirname
				+/+ ~bufPaths[0].basename[.. ~bufPaths[0].basename.indexOf($_)]
				++ "labels3.txt"
		},

		// oh earth mother, this is a damnably wretched hack but I had to do SOMETHING!!
		ampCorrections: #[0.28807148337364, 0.17774771153927, 0.36427477002144, 0.12500120289816, 0.38182136416435, 0.18799524009228, 0.58741980791092, 0.052831564053287, 0.20307244360447, 0.24629978835583, 0.42413705587387, 0.16614802181721, 0.30681470036507, 0.090353488922119, 0.089508562163331, 0.12378922104836, 0.42652836441994, 0.83408385515213, 0.15755517780781, 0.15393386781216, 0.15342317521572, 0.43515829067847, 0.074556715786457, 0.24919280409813, 0.6793058514595, 0.092316187918186, 0.26444959640503, 0.052370578050613],
		listGest: { ~gestures.keys.asArray.sort.do(_.postln); "" },

		mSpeedNotes: [
			#[40, 50, 59, 66, 79, 85],
			#[43, 52, 54, 59, 69, 78],
			#[45, 55, 62, 73, 76, 83]
		].mapMode(\d),
		mSpeedDelta: Pwhite(1.4, 3.0, inf),
		multiSpeedParms: Plazy({
			Pbind(
				\collIndex, ~collIndex,
				\play, {
					BP(~collIndex).runGesture(currentEnvironment, true)
				},
				\gest, \klankMachine,
				\yEnds, #[5, 20],
				\range, Pn(Pshuf((0..5), 1), inf),
				\notes, Pstutter(
					Pwhite(6, 14, inf),
					Pxrand(~mSpeedNotes, inf).collect { |array|
						~currentMSNotes = array;
						BP(~collIndex).changed(\msNotes, array);
						array
					}
				),
				\newDelta, Pkey(\range).linexp(0, 5, 1.2, 0.09) * Pwhite(1.0, 1.2, inf),
				\numEv, (8 / Pkey(\newDelta)).round,
				\prob, Pkey(\range).linlin(0, 5, 1, 0.66),
				\freq, Pfunc({ |ev|
					var i = ev[\range],
					n = ev[\numEv],
					n1 = (n * rrand(0.4, 0.65)).roundUp,
					n2 = ((n - n1) * 0.5).trunc,
					adder = Pwrand(#[0, 1, 2, 3], #[1.5, 2, 2, 1].normalizeSum, n2);
					if(i >= 4) {
						adder = Pfinval(n2, Ppatlace([adder, 0, 0], inf))
					};
					Pseries(ev[\notes][i], Pseq([
						Pn(0, n1),
						adder,
						adder.neg
					])).collect { |deg| Mode(\d).cps(deg) }
				}),
				\timeMul, 0.5, //1 / (Pkey(\range) + 1),
				\delta, BPStream(\mSpeedDelta)
			)
		}),
		addMultiSpeed: { |overrides|
			var parms;
			~multiSpeedParmsStream ?? { ~makeStreamForKey.(\multiSpeedParms) };
			if(~ffreqCtl.autoSynth.isNil) {
				~ffreqCtl.automate({ LFNoise1.kr(1.8).exprange(3000, 6000) },
					target: ~chan.synthgroup, addAction: \addToHead);
			};
			parms = ~multiSpeedParmsStream.next(());
			if(parms.notNil) {
				if(overrides.notNil) { parms.putAll(overrides) };
				~runGesture.(parms, true);
			};
		},
		autoRunMultiSpeed: { |play(true)|
			if(play and: { ~mSpeedPlayer.isNil }) {
				~mSpeedPlayer = ~multiSpeedParms.play;
			} {
				~mSpeedPlayer.stop;
				~mSpeedPlayer = nil;
			}
		},
		snareParms: { |parms(Event.new)|
			parms[\numEv] ?? { parms[\numEv] = 25 };
			(	gest: \klankMachine,
				prob: 1,
				excTime: 0.08,
				newDelta: Pfinval({ |ev| ev[\parms][\numEv] }, Pnsym(
					parms[\rhythms] ?? { Pfsm([
						(0..7),
						one: (1..8).dup(2).flat ++ #[0],
						dot: #[1, 3, 4, 5],
						revdot: #[0, 2, 4, 5, 6],
						rattata: #[0, 1, 3, 5, 7],
						ratatat: #[0, 1, 2, 3, 5, 6, 8],
						syncop: #[0, 1, 3],
						tripletHead: #[6, 8, 0],
						tripletTail: #[7, 8, 0],
						triplets: #[0]
					]) }, ~snareRhythms
				) * (parms[\tempo] ?? { (60/104) })),
				// ominous
				freq: parms[\freq] ?? { \patRejectLastN.eval(Pwhite(34, 52, inf), 3).clump(3).midicps },
				timeMul: 0.03,
				kAmp: parms[\kAmp] ?? {
					if(parms[\numEv] > 1) {
						Pseries.fromEndpoints(parms[\startAmp] ? 0.07, 1.0, parms[\numEv] ? 25)
					} { 1 }
				},
				harm: [(1, 3 .. 9)],
				mainAmp: parms[\mainAmp] ? 0.15,
				yEnds: #[18, 5],
				numEv: parms[\numEv] ? 25,
				start: ~pt.choose * 44100,
				rate: 1.2, //Pexprand(0.6, 0.8, inf),
				shapebuf: ~shapebuf,
				chorusAmps: #[[0.4, 0.4, 0.4]],
				glrvbamt: 0.25,
				lcrvbamt: 0.14
			)
		},
		setLauraWps: { |noteArray|
			5.do { |i|
				("laurawp" ++ i).asSymbol.envirPut(Pser(noteArray, { rrand(3, 6) }) ++ Pn(Pshuf(noteArray, 1), inf));
			};
		},
		lauraWpPitchPool: Pn(Pseries(0, 1, 5), inf),
		runLauraWp: { |parms( () ), holdForStop = true|
			~runGesture.((
				instr: parms[\instr],
				gest: parms[\gest] ? \klankMachine,
				newDelta: parms[\newDelta] ?? {
					Pexprand(0.24, 0.48, { parms[\numEv] ?? { rrand(3, 7) } })
				},
				excTime: 0.15,
				timeMul: parms[\timeMul] ?? { Env(#[0.01, 0.3], #[20], 4.5).asStream / Pkey(\delta) },
				filtAttackRatio: parms[\filtAttackRatio] ?? { 0.01 / Pkey(\filtDecay) },
				freq: parms[\freq] ?? {
					BPStream(("laurawp" ++ ~lauraWpPitchPoolStream.next).asSymbol)
				},
				mainAmp: parms[\mainAmp] ?? { Env(#[1, 0.1, 1], #[2.5, 9.5], \exp) },
				kAmp: parms[\kAmp] ? 1,
				harm: parms[\harm],  // if nil, remains nil in the parms dict passed thru
				// default xyPat uses \numEv, but we don't know how long newDelta pat will run
				xyPat: Ptuple([
					Pseg(
						Pwhite(0.6, 1.0, inf) * Prand(#[-1, 1], inf),
						Pexprand(0.5, 2.0, inf)
					),
					Pseg(
						Pwhite(5.0, 20.0, inf),
						Pexprand(0.5, 2.0, inf)
					)
				], 1)
			), holdForStop);
		}
	));
	0 => BP(name);
}, type: \bp) => Fact(\openingSteps);



// chords (arm movements)
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);
	~prep = {
		// urgh, I need a different ~canStream method but chucking overwrites my choice!
		~canStream = {
			~event[\voicer].isKindOf(Voicer)  // don't try to play if VC doesn't exist
		};
		~atkProbCtl = GenericGlobalControl(\atkProb, nil, 0.25);
	};
	~freeCleanup = { ~atkProbCtl.free };
	~useGui = { |vpi| ~atkProbCtl => VP(vpi) };

	// ~top = Pwhite(36, 44, inf);
	// can't replace by Pseq - Paccumbounce loses continuity
	~top = Pswitch1([
		Pwhite(36, 44, inf),
		Paccumbounce(36, 44, Pwrand(#[-2, -1, 1, 2], #[1, 2, 3, 2].normalizeSum, inf), inf)
	], Psmartstutter(Pfunc { |which| (which * 3 + 1) * rrand(2, 5) }, Pseq(#[1, 0], inf)));

	~numNotes = Pwrand(#[2, 3], #[0.8, 0.2], inf);
	// ~intervals = Pexprand(1, 6, inf).round;
	~intervals = Pwrand((1..6), #[1, 3, 2, 2, 1, 1].normalizeSum, inf);
	~degree = Pkey(\top) -.x Pseries(0, Plazy { |ev| Pfinval(ev[\numNotes], ~intervals) }, inf)
		.clump(Pkey(\numNotes));
	~mode = \g;
	~bufbase = Plazy { Prand(~bufBases, inf) };
	~amp = Pexprand(0.5, 1, inf);
	~delta = Pwrand(#[0.25, 0.5, 0.75, 1], #[1, 4, 3, 1].normalizeSum, inf)
		* Pif(Pkey(\attackNote), 1, 4);
	~sustain = Pexprand(2.2, 5.6, inf); //Pexprand(1.7, 4.2, inf);
	~gate = 0.1;
	~ffreq = Pexprand(90.0, 400.0, inf);
	~rq = 0.4;
	~fenv_vsens = 0;
	~fenv_tscale = Pif(Pkey(\attackNote), Pwhite(0.25, 0.6, inf), Pwhite(0.75, 1.0, inf));
	~fenv_sens = Pif(Pkey(\attackNote), Pexprand(0.1, 0.25, inf), Pexprand(0.15, 0.7, inf));
	~pan = (
		Pn(Pser(#[-1, 1, 0], Pkey(\numNotes).asStream), inf)  // orientation
		*
		Pstutter(Pkey(\numNotes), Pwhite(0.4, 0.8, inf))  // width
	).clump(Pkey(\numNotes)).collect(_.scramble);

	~attackNote = Plazy { ~atkProbCtl.asPattern.coin };  // 0.1.asPattern.coin;
	~envAtk = Pif(Pkey(\attackNote), Pwhite(0.02, 0.05, inf), 1.6);
	~envDcy = Pif(Pkey(\attackNote), Pwhite(0.15, 0.4, inf), 0.8);
	~fenvProp = Pif(Pkey(\attackNote), Pwhite(0.07, 0.18, inf), 0.466667);

	~asPattern = {
		/*Debug*/Pbind(
			\attackNote, BPStream(\attackNote),
			\top, BPStream(\top),
			\numNotes, BPStream(\numNotes),
			\freq, BPStream(\degree),
			\mode, BPStream(\mode),
			\bufbase, BPStream(\bufbase),
			\amp, BPStream(\amp),
			\delta, BPStream(\delta),
			\length, Pkey(\delta) * BPStream(\sustain),
			\gate, BPStream(\gate),
			\ffreq, BPStream(\ffreq),
			\rq, BPStream(\rq),
			\fenv_sens, BPStream(\fenv_sens),
			\fenv_vsens, BPStream(\fenv_vsens),
			\fenv_tscale, Pkey(\length) * BPStream(\fenv_tscale),
			\envAtk, BPStream(\envAtk),
			\envDcy, BPStream(\envDcy),
			\fenvProp, BPStream(\fenvProp),
			\pan, BPStream(\pan)
		)
	};

	// process needs buffer info from VC chucked in
	~bindVC = { |vc|
		if(try({ vc.env.wt[0][0] }).notNil) {
			~bufBases = vc.env.wt.collect { |w| w.first.bufnum }
		} {
			"VC(%) is not compatible with BP(%) - wt needs to be a 2-d array of buffers."
			.format(vc.collIndex.asCompileString, ~collIndex.asCompileString).warn;
		};
		~makeSreamForKey.(\bufbase);  // force Plazy to rebuild stream with new bufnums
	};
} => PR(\feetChords);

(
make: { |name|
	BP(name).free;
	PR(\feetChords) => BP(name);
	0 => BP(name);
}, type: \bp) => Fact(\feetChordBP);



// leaning

(play: {
	BP(~stepKey).runGesture(currentEnvironment)
}) => ProtoEvent(\runKlankMachine);
ProtoEvent.composite(#[polySynthKrBusLock, runKlankMachine, dummy]) => ProtoEvent(\leaning);

PR(\abstractProcess).clone {
	~event = (eventKey: \leaning);
	~stepKey = \st;

	~selector = Pseq([Pn(0, { rrand(2, 4) * 2 }), 1], inf);
	~clickProb = 0.75.asPattern.coin;
	~numKlank = Pwxrand(#[1, 2, 3, 4], #[5, 3, 2, 1].normalizeSum, inf);

	~gate = 0.1;
	~deg = (Pwhite(35, 45, inf) +.x Pseries(0, Prand(#[-1, -2, -3], 2))).clump(2);
	~freq = Pfunc { |ev| Mode(\g).cps(ev[\deg]) };
	~delta = Pwhite(0.2, 0.4, inf) * Pseq(#[1, 2.1], inf);
	~sustain = Pwhite(1.5, 4.5, inf);
	~bufbase = Plazy({ Prand(VC(~vcKey).env.wt.flop[0], inf) });
	~envAtk = 0.05;
	~envDcy = 0.12;
	~fenv_tscale = Pkey(\sustain);
	~fenvProp = 0.07;
	~lpcEv = Pbind(
		\instrument, \krwobble,
		\speedEnv, Pfunc({ Env(#[1.2, 5, 0.7], #[0.3, 0.7]) }),
		\widthEnv, Pfunc({ Env(#[1, 1.05, 1], #[0.7, 0.3], \exp) })
	);

	~klankprob = 1;
	~klanknewDelta = Pexprand(0.09, 0.14, inf);
	~klankfreq = Pexprand(700, 1100, inf);
	~klanktimeMul = 0.05;
	~klankkAmp = Pexprand(0.6, 1.0, inf);
	// OMFG, the lack of []'s caused FIVE TIMES AS MANY SYNTHS as expected
	~klankharm = [(1, 3 .. 9)];
	~klankyEnds = #[5, 20];
	~klanknumEv = Pwhite(9, 17, inf);
	~klankstart = Plazy({ Prand(BP(~stepKey).pt, inf) * 44100 });
	~klankdelta = max(0.15, (Pkey(\newDelta) * Pkey(\numEv)) + Pwhite(-0.8, 0.8, inf));
	~restdelta = Pwhite(2.0, 5.0, inf);

	~asPattern = {
		~numKlankStream ?? { ~makeStreamForKey.(\numKlank) };
		Pswitch1([
			Pbind(
				\protoEvent, \polySynthKrBusLock,
				\chan, ~event[\voicer].bus.asMixer,
				\instrument, ~event[\voicer].nodes[0].defname.asSymbol,
				\busRate, \control,
				\numCh, 1,
				\freqmul, { ~lock.bus.asMap },  // asControlInput .value's this
				\gate, BPStream(\gate),
				\deg, BPStream(\deg),
				\freq, BPStream(\freq),
				\delta, BPStream(\delta),
				\sustain, BPStream(\sustain),
				\bufbase, BPStream(\bufbase, resetSource: true),
				\envAtk, BPStream(\envAtk),
				\envDcy, BPStream(\envDcy),
				\fenv_tscale, BPStream(\fenv_tscale),
				\fenvProp, BPStream(\fenvProp),
				\lpcEv, BPStream(\lpcEv) <> Pfunc { |inev| inev.copy[\chan] = nil }
			),
			Pif(BPStream(\clickProb),
				Pbind(
					\protoEvent, \runKlankMachine,
					\stepKey, BPStream(\stepKey),
					\gest, \klankMachine,
					\numEv, BPStream(\klanknumEv),
					\prob, BPStream(\klankprob),
					\newDelta, BPStream(\klanknewDelta),
					\freq, BPStream(\klankfreq),
					\timeMul, BPStream(\klanktimeMul),
					\kAmp, BPStream(\klankkAmp),
					\harm, BPStream(\klankharm),
					\yEnds, BPStream(\klankyEnds),
					\start, BPStream(\klankstart, resetSource: true),
					\delta, BPStream(\klankdelta)
				),
				Pbind(
					\protoEvent, \dummy,
					\delta, BPStream(\restdelta)
				)
			)
		], BPStream(\selector))
	};

	~bindVoicer = { |voicer|
		var	vc = VC.all.detect { |obj| obj.v === voicer };
		if(vc.notNil and: { vc.exists }) {
			~vcKey = vc.collIndex.debug("set vcKey");
		} {
			"% is not in the VC collection. BP(%) will not work."
			.format(voicer, ~collIndex.asCompileString);
			~vcKey = nil;
		};
	};
} => PR(\leaning);



SynthDef(\krfall, { |outbus, low = 0.5, sustain = 1, proportion = 0.5, halfWidth = 0.1|
	var	remaining = 1 - proportion;
	halfWidth = min(halfWidth, min(proportion, remaining));
	Out.kr(outbus, EnvGen.kr(
		Env(
			[1, 1, low, low, (low-1) * Rand(0.6, 0.8) + 1],
			[proportion - halfWidth, halfWidth * 2, remaining - halfWidth, 0.5],
			\sin
		),
		timeScale: sustain
	));
}).add;

(make: { |name|
	BP(name).free;
	PR(\leaning).chuck(BP(name), nil, (
		// use .override to trigger falling klanks
		selector: 0,
		// use .override, or replace, for falling chords
		fallLow: 1,
		clickProb: true,
		klanknumEv: Pwhite(12, 22, inf),
		klanknewDelta: Pfunc({ |ev|
			Pgeom.fromEndpoints(rrand(0.09, 0.12), rrand(0.25, 0.32), ev[\numEv])
			* Pexprand(0.75, 1.33, inf)
		}),
		klankfreq: Pfunc({ |ev|
			var	top = exprand(900, 1400),
			curve = [top, top * rrand(0.2, 0.4), rrand(3.0, 5.5)].asSpec;
			Pseries.fromEndpoints(0, 1, ev[\numEv]).collect(curve.map(_))
		}),
		klankkAmp: Pfunc({ |ev|
			Pseries.fromEndpoints(exprand(0.6, 1.0), rrand(0.02, 0.04), ev[\numEv])
		}),
		klankdelta: Pwhite(5.0, 8.0, inf),
		lpcEv: Plazy({ Pbind(
			\instrument, \krfall,
			// \low, Pexprand(0.8, 1.25, inf) * 0.5,
			\low, BPStream(\fallLow),
			\proportion, Pwhite(0.5, 0.8, inf),
			\halfWidth, Pwhite(0.2, 0.48, inf)
		) }),
		delta: Pseq([
			Pwhite(0.2, 0.4, inf) * Pseq(#[1, 2.1], { rrand(1, 4) }),
			Pwhite(0.8, 2.5, { rrand(1, 3)  })
		], inf)
	));
	0 => BP(name);
}, type: \bp) => Fact(\fallingBP);


(
keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		event: (eventKey: \singleSynthPlayNotify),
		inChannels: 2,
		master: ~master,
		glrvbmc: ~glrvbmc,
		lcrvbmc: ~lcrvbmc,
		trajectoryKey: \traj,
		alwaysReset: true,

		userprep: {
			[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\receivesSignalFrom, ~chan));
			if(BP.exists(\st) and: { BP(\st)[\buffers].tryPerform(\at, 0).notNil }) {
				~buf = BP(\st)[\buffers][0]
			} {
				~buf = Buffer.readAndQuery(s, topEnvironment[\sampleDir] +/+ "feet/58454_sinatra314_footsteps_wooden_floor_loop.wav");
				~iLoadedBuf = true;
			};
			~decayCtl = GenericGlobalControl(\decayIndex, nil, 0, #[0, 2, \lin]);
			~ampCtl = GenericGlobalControl(\amp, nil, 1, \amp);
			~deltaDistribCtl = GenericGlobalControl(\deltaD, nil, 6, #[1.2, 6, \exp]);
			~maxSynthsCtl = GenericGlobalControl(\maxSynths, nil, 1, #[1, 12, \lin, 1]);
			~synths = IdentitySet.new;
			~xymaps = Pseq(BP(~trajectoryKey).xymaps, inf);
			~event.proto = topEnvironment[\rvbEvent].proto;
			~commonArgs = ~commonArgs.value;
		},
		useGui: { |vpi|
			[~decayCtl, ~ampCtl, ~deltaDistribCtl, ~maxSynthsCtl].do { |gc| gc => VP(vpi) };
		},
		userfree: {
			if(~iLoadedBuf == true) { ~buf.free };
			BP(~trajectoryKey).notUsedBy(~collIndex);
			[~decayCtl, ~ampCtl, ~deltaDistribCtl, ~maxSynthsCtl].free;
		},

		preparePlay: { BP(~trajectoryKey).isUsedBy(~collIndex) },

		recvEventNotify: { |synth|
			if(synth.notNil) {
				~synths = ~synths.add(synth);
				OSCpathResponder(s.addr, ['/n_end', synth.nodeID], e { |time, resp, msg|
					resp.remove;
					~synths.remove(synth);
					if(~synths.size <= 0 and: { ~isPlaying.not }) {
						BP(~trajectoryKey).notUsedBy(~collIndex);
					}
				}).add;
			};
		},
		stopCleanup: {
			if(~synths.size <= 0) { BP(~trajectoryKey).notUsedBy(~collIndex) };
		},
		// do NOT fold this into stopCleanup because maybe I don't want it automatically
		stopNodes: { |releaseTime = 0.5|
			releaseTime = -1 - releaseTime;
			~synths.do(_.set(\rgate, releaseTime));
		},

		cosEnv: Env(#[0, 1, 0], #[1, 1], \sin),
		synth: Pif(
			Pfunc({ ~synths.size < ~maxSynthsCtl.value }),
			Pwrand(#[lessPh, midPh, morePh],
				Pfunc({
					((#[0, 1, 2] - ~decayCtl.value) * 0.6 + 1)
					.collect { |i| ~cosEnv.at(i.clip(0, 2)) }
					.normalizeSum
				}),
				inf
			),
			\rest
		),

		// delta: (1.5+3.4) - Pexprand(1.5, 3.4, inf), // Pwhite(0.8, 1.6, inf),
		delta: Plazy({ Pbeta(1, 4.8, ~deltaDistribCtl, 1, inf) }),

		// // Beta distrib. with a & b < 1.0 is u-shaped, tends toward extremes
		// // but I didn't like it
		// rate1: Pbeta(2.0, 5.0, 0.8, 0.8, inf),
		// rate2: Pbeta(2.0, 5.0, 0.8, 0.8, inf),
		// proportion: Pwhite(0.02, 0.98, inf),
		rate1: Pwhite(0.87, 1.2, inf),
		rate2: Pkey(\rate1) * Pwhite(1.6, 2.5, inf),
		proportion: Pwhite(0.3, 0.7, inf),
		// derived algebraically from
		// factor * rate1 + (1/2 * factor * (r2-r1)) = bufdur
		factor: Pkey(\bufdur) * 2 / (Pkey(\rate1) + Pkey(\rate2)),
		// factor: Pkey(\bufdur) / Pkey(\rate),
		attack: 0.3,
		decay: 0.3,
		time: Pkey(\factor) - Pkey(\attack) - Pkey(\decay),
		amp: 2,
		pan: Pwhite(0.6, 1.0, inf) * Prand(#[-1, 1], inf),

		commonArgs: { [
			#[pan, distance], BPStream(\xymaps),
			\bufnum, ~buf,
			\bufdur, Pfunc({ ~buf.duration }),
			\rate1, BPStream(\rate1),
			\rate2, BPStream(\rate2),
			\factor, BPStream(\factor),
			\proportion, BPStream(\proportion),
			\amp, BPStream(\amp),
			\ampMap, ~ampCtl.asMap,
			\attack, BPStream(\attack) * Pkey(\factor),
			\decay, BPStream(\decay) * Pkey(\factor),
			\time, BPStream(\time)
		] },

		// filtDecay low, not much effect; 0.2, buzzy; 0.9, really wobbly
		objects: { (
			lessPh: (
				def: \bufGrainPanPhaserDist,
				args: ~commonArgs ++ [
					\filtDelay, Pwhite(0.005, 0.02, inf),
					\filtSpeed, Pwhite(3.0, 10.0, inf),
					\filtWidth, Pkey(\filtDelay) * Pwhite(0.7, 0.95, inf),
					\filtDecay, Pwhite(0.02, 0.09, inf)
				]
			),
			midPh: (
				def: \bufGrainPanPhaserDist,
				args: ~commonArgs ++ [
					\filtDelay, Pwhite(0.005, 0.02, inf) + 0.01,
					\filtSpeed, Pwhite(3.0, 10.0, inf),
					\filtWidth, Pkey(\filtDelay) * Pwhite(0.7, 0.95, inf),
					\filtDecay, Pwhite(0.18, 0.3, inf)
				]
			),
			morePh: (
				def: \bufGrainPanPhaserDist,
				args: ~commonArgs ++ [
					\filtDelay, Pwhite(0.005, 0.02, inf) + 0.02,
					\filtSpeed, Pwhite(3.0, 10.0, inf),
					\filtWidth, Pkey(\filtDelay) * Pwhite(0.7, 0.95, inf),
					\filtDecay, Pwhite(0.7, 0.95, inf)
				]
			)			
		) }
	));
	0 => BP(name);
}, type: \bp) => Fact(\ilanaSteps);
