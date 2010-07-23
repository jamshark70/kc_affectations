
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


if(Mode.exists(\c).not) {
	#[c, db, d, eb, e, f, gb, g, ab, a, bb, b].do { |key, i|
		Mode(\default).v.copy.root_(i) => Mode(key);
		Mode(key).v.transposeRoot(0) => Mode((key ++ "0").asSymbol);
	};
};

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

~master ?? { ~master = MixerChannel(\feetM, s, 2, 2, level: 1) };

// don't want reverb on netbook
if(Window.screenBounds.height > 600) {
	// global reverb
	~glrvbmc ?? {
		~glrvbmc = MixerChannel(\rvb, s, 2, 2, level: 1, outbus: ~master);
	};

	~glrvbmc.doWhenReady {
		if(~glrvb.isNil or: { ~glrvb.isPlaying.not }) {
// 			~glrvb = ~glrvbmc.playfx(Instr("busfx.freeverb2"), #[0] ++
// 				[#[1.0, 0.75, 0.5, 1.0], Instr("busfx.freeverb2").specs[1..]].flop
// 				.collect { |val_spec| KrNumberEditor(*val_spec) }
			~glrvb = ~glrvbmc.playfx(Instr("busfx.freeverb2"), [0, KrNumberEditor(1.0, ControlSpec(0, 1, 'linear', 0, 0.5, "")), KrNumberEditor(0.54166668653488, ControlSpec(0.0, 1.0, 'linear', 0.0, 0.0, "")), KrNumberEditor(0.5, ControlSpec(0.0, 1.0, 'linear', 0.0, 0.0, "")), KrNumberEditor(1.0, ControlSpec(0, 1, 'amp', 0, 0, "")) ]
			);
		};
	};

	// local reverb should be more stereo-separated
	~lcrvbmc ?? {
		~lcrvbmc = MixerChannel(\rvb, s, 2, 2, level: 1, outbus: ~master);
	};

	~lcrvbmc.doWhenReady {
		if(~lcrvb.isNil or: { ~lcrvb.isPlaying.not }) {
			~lcrvb = ~lcrvbmc.playfx(Instr("busfx.rvb_allpass2"), [ 20, 2, KrNumberEditor(0.25, ControlSpec(0.25, 2, 'linear', 0.0, 0.25, "")), KrNumberEditor(0.014025612063518, ControlSpec(0.001, 1.5, 'exp', 0, 0.05, "")), KrNumberEditor(0.17782792880092, ControlSpec(0.01, 10, 'exp', 0, 0.25, "")), 4, KrNumberEditor(0.019573417367152, NoLagControlSpec(0.001, 1, 'exp', 0, 0.03, "")) ]);
		};
	};
};



// trajectories for cheap-ass spatialization
Proto {
	~numSynths = 10;
	~prep = {
		~group = Group.before(s.asTarget);

		SynthDef("xy1", { |distNear = 5, distFar = 20, mul = 0.25, send = 0, out = 0|
			var	theta, r, x, y;
			theta = DemandEnvGen.kr(
				Dwhite(-2pi, 2pi, inf),
				Dwhite(0.25, 0.9, inf),
				Env.shapeNumber(\sine)
			);
			r = DemandEnvGen.kr(
				Dwhite(0.1, 1.0, inf),
				Dwhite(0.0, 1.0, inf).linexp(0, 1, 0.6, 2.0),
				Env.shapeNumber(\sine)
			);
			x = theta.cos * r;
			y = theta.sin * r;
			x = x * mul;
			y = (y * mul).linlin(-1, 1, distNear, distFar);
			SendReply.kr(send * Impulse.kr(10), "/xy", [x, y]);
			Out.kr(out, [x, y]);
		}, #[\ir, \ir]).add;

		~xys = { Bus.control(s, 2) } ! ~numSynths;
		~xymaps = ~xys.collect({ |bus| [bus.asMap, ("c" ++ (bus.index+1)).asSymbol] });
		~clients = IdentitySet.new;
	};

	~freeCleanup = {
		[~group, ~xys].free;
	};

	~makeSynths = {
		~xysynths ?? {
			~xysynths = ~xys.collect { |xybus|
				Synth(\xy1, [mul: 1, send: 0, out: xybus], ~group);
			}
		};
	};

	~removeSynths = {
		~xysynths !? {
			~xysynths.do(_.free);
			~xysynths = nil;
		};
	};

	~isUsedBy = { |name|
		if(~clients.includes(name)) {
			"% is already used by %.".format(~collIndex.asCompileString, name.asCompileString).warn
		} {
			~clients.add(name);
			~makeSynths.();
		}
	};

	~notUsedBy = { |name|
		~clients.remove(name);
		if(~clients.isEmpty) {
			~removeSynths.()
		}
	};
} => PR(\trajectories);


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
				Pfin(2, Pkey(\target) + (Pkey(\interval) * Pkey(\upOrDownFix)))
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
				Pfin(1, Pkey(\mnote)).collect { |note| ~startNote = note },
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

SynthDef(\bufGrainPanFilt, { |start, time, bufnum, pan, rate = 1, amp = 1,
		attack = 0.001, decay = 0.02, outbus, ffreq = 2000|
	var sig;
	sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
		* EnvGen.kr(Env.linen(attack, time, decay), doneAction:2);
	sig = LPF.ar(sig, ffreq);
	Out.ar(outbus, Pan2.ar(sig, pan, amp));
}).add;

SynthDef(\bufGrainPanComb, { |start, time, bufnum, pan, rate = 1, amp = 1,
		attack = 0.001, decay = 0.02, outbus, ffreq = 2000, filtDecay = 0.1, filtAmp = 1|
	var sig;
	sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
		* EnvGen.kr(Env.linen(attack, time, decay));
	// 0.06 ~= 16 Hz, likely as low a freq as you'll need
	sig = Limiter.ar(sig + CombL.ar(LeakDC.ar(sig), 0.06, ffreq.reciprocal, filtDecay, filtAmp));
	DetectSilence.ar(sig, 0.001, doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, amp));
}).add;

SynthDef(\bufGrainPanKlank, { |start, time, bufnum, pan, rate = 1, amp = 1,
		attack = 0.001, decay = 0.02, outbus, filtFreq = 2000, filtAttack = 0.1, filtDecay = 1.0,
		filtAmp = 1,
		/* shapebuf = -1, shapeXf = 1, */ chorusFreq = 0.05, chorusAmt = 0.02, chorusDelay = 0.03,
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
//	shaped = Select.ar(shapebuf < 0, [Shaper.ar(shapebuf, sig), sig]);
//	sig = XFade2.ar(sig, shaped, shapeXf);
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
// 	sig = LeakDC.ar(sig);
	sig = RLPF.ar(sig, ffreq, lprq);
	DetectSilence.ar(sig, 0.001, doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, amp));
}).add;

SynthDef(\pvplayPan, { |outbus, pvbuf, startFrame, time = 1, rate = 1, amp = 1, pan,
	attack = 0.01, decay = 0.05|
	var	fft = PV_PlayBuf(LocalBuf(Index.kr(pvbuf, 0), 1), pvbuf, rate, startFrame, loop: 0),
		sig = IFFT(fft, 1)
			* EnvGen.kr(Env.linen(attack, time - attack - decay, decay), doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, amp));
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

(
{ |name, ugenFunc, metadata, rates|
	var	findCtl = { |cname|
		block { |break|
			UGen.buildSynthDef.children.do { |unit|
				if(unit.isKindOf(Control)) {
					unit.channels.do { |out|
						if(out.name == cname) { break.(out) }
					}
				}
			};
			nil
		}
	};
	SynthDef(name, { |distance = 5, distNear = 5, distFar = 14,
		glrvbout, lcrvbout, glrvbamt = 0.075, lcrvbamt = 0.035,
		attNearFreq = 9000, attFarFreq = 3000,
		attNearDb = -5, attFarDb = -18,
		attNearRs = 2, attFarRs = 2|
		var result = SynthDef.wrap(ugenFunc), out, pan, outctl;
		// don't add a new \pan control if the function already made one
		if((pan = findCtl.(\pan)).isNil) {
			pan = NamedControl(\pan, 0);
		};
		if((outctl = findCtl.(\outbus)).isNil and: { (outctl = findCtl.(\out)).isNil }) {
//			"make out namedcontrol".debug;
			outctl = NamedControl(\out, 0);
		};
		if(result.rate != \audio) {
			// not audio rate, look for Out unit
			// (Out.ar returns 0.0, which is scalar)
			out = UGen.buildSynthDef.children.detect(_.writesToBus);
			if(out.notNil) {
				result = out.inputs[out.inputs.size - out.numAudioChannels .. ];
				UGen.buildSynthDef.children.remove(out);
			} {
				Error("Result of UGen func is not audio rate and has no Out unit").throw;
			};
		};

		distance = distance.clip(distNear, distFar);
		result = result * distNear;
		Out.ar(outctl, result / distance);

//		lcrvbamt = Select.kr(lcrvbamt < 0, [lcrvbamt, glrvbamt]);
		result = BHiShelf.ar(result,
			distance.linexp(distNear, distFar, attNearFreq, attFarFreq),
			distance.linlin(distNear, distFar, attNearRs, attFarRs),
			distance.linlin(distNear, distFar, attNearDb, attFarDb)
		);
		distance = distance.sqrt;
		Out.ar(glrvbout, result * glrvbamt / distance);
		Out.ar(lcrvbout, result * lcrvbamt * (1 - distance.reciprocal));
	}, rates, metadata: metadata);
} => Func(\addRvbOut);
);

#[bufGrainPanFilt, bufGrainPanComb, bufGrainPanKlank, pvplayPan, pvplayStereo].do { |name|
	\addRvbOut.eval((name ++ "Dist").asSymbol, SynthDescLib.at(name).def.func).add;
};


// opening blast!
(
keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		event: (eventKey: \singleSynthPlayNotify),
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
		maxSynths: 8,
		trajectoryKey: \traj,
		initAmp: 0.36,
		userprep: {
			var	sf;

			[~glrvbmc, ~lcrvbmc].do(~chan.sendsSignalTo(_));

			~pvbuf = Buffer.readAndQuery(s, ~pvpath.standardizePath, completionFunc: e {
				~pvbuf.getn(0, 3, e { |val|
					~fftSize = val[0];
					~hop = val[1];
					~winType = val[2];
					~numPvFrames = (~pvbuf.numFrames - 3) / ~fftSize;
					// [~fftSize, ~hop, ~winType, ~numPvFrames].debug("pv specs");
					~readyToPlay = true;
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
			[~glrvbmc, ~lcrvbmc].do(~chan.stopsSendingTo(_));
			~xys.do(_.releaseBus(~collIndex));
			[~pvbuf, ~ampCtl].free;
		},
		preparePlay: {
			BP(~trajectoryKey).isUsedBy(~collIndex);
		},
		recvEventNotify: { |node|
			var	self, ufunc;
			if(node.isKindOf(Synth)) {
				self = currentEnvironment;
				ufunc = { |obj, what|
					if(what == \n_end) {
						obj.removeDependant(ufunc);
						self[\activeSynths].remove(obj);
						if(self[\isPlaying].not and: { self[\activeSynths].isEmpty }) {
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
					glrvbout: ~glrvbmc.inbus,
					lcrvbout: ~lcrvbmc.inbus,
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
					}
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
				~splashPattern.(),
				Event.silent(rrand(0.15, 0.45)),
				~superPattern.()
			])
		},
		processLabels: PR(\steps1).v[\processLabels],
		readLabels: {
			~pt = TabFileReader.read(~sfpath.dirname +/+ ~sfpath.basename[.. ~sfpath.basename.indexOf($_)]
				++ "labels.txt");
			~processLabels.();
		},
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
}, type: \bp) => Fact(\opening);


PR(\abstractProcess).clone {
	~bufPath = "58454_sinatra314_footsteps_wooden_floor_loop.wav";

// 	~event = (eventKey: \singleSynthPlayer);
	~event = (eventKey: \polySynthPlayer);
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

	~readLabels = {
		~pt = TabFileReader.read(~path.dirname +/+ ~path.basename[.. ~path.basename.indexOf($_)]
			++ "labels.txt");
		~processLabels.();
	};
	~processLabels = {
		~pt = ~pt.flop[0].asFloat;
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
				Pfin({ rrand(12, 24) },
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



SynthDescLib.at(\returnPeak) ?? {
	SynthDef(\returnPeak, { |bufnum, start, frames|
		var	term = Line.ar(0, 1, frames / BufSampleRate.ir(bufnum)),
			sig = PlayBuf.ar(1, bufnum, rate: BufRateScale.ir(bufnum), startPos: start),
			peak = Peak.ar(sig),
			done = Done.kr(term) + Done.kr(sig);
		SendTrig.kr(done, 0, peak);
		FreeSelf.kr(done);
	}).add;
};

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
keys: #[master, rvbmc],
numCombs: 10,
cFundamental: 67.midicps,
cStep: 67.midicps / 4,	// i.e., 67.midicps is 4th partial, next comb will be 5th
cLevelRatio: 1.5.dbamp,
make: { |name|
	var out;

	WrapInstr([\osc2, \vosc3map2], { |freq, bufbase, numbufs, basefreq, topfreq, gate|
		var	baselog = log2(basefreq),
			freqmap = ((log2(freq) - baselog) / (log2(topfreq) - baselog)
				* (numbufs - 1)).clip(0, numbufs - 1.001);
		WrapInstr.wrap([\osc2, \vosc3], [freq, gate, bufbase, freqmap]);
	}, [\freq, [0, 1000, \linear, 1, 0], [0, 20, \lin, 1, 0], \freq, \freq, #[0, 1]]);
	
	WrapInstr("osc2.vosc3mapfiltenv", { |gate = 1, ffreq, rq, fenv, fenv_sens, fenv_vsens, fenv_tscale = 1|
		var	sig = WrapInstr.wrap("osc2.vosc3map2", (nil ! 5) ++ [gate]),
			glatch = Latch.kr(gate, gate),
			feg = EnvGen.kr(fenv, gate, timeScale: fenv_tscale);
		feg = (feg - 1) * Sensitivity.kr(1, glatch, fenv_vsens) * fenv_sens + 1;
		RLPF.ar(sig, (ffreq * feg).clip(20, 18000), rq)
	}, [#[0, 1], \freq, \myrq, EnvSpec(Env.one), #[0, 1], #[0, 1], #[0.1, 10, \exp]]);

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
		~ch = chan.playfx(Instr("busfx.chorus2"), #[0, 1, 2, 3, 0.0040240867741694, 0.11364637357074, 0.0036090192987437, 1.1344639929904, 0.72629173909809]);
		~ch.doWhenPlaying { ~ch.synth.moveToTail(chan.effectgroup) };
	});
	~combsMC = MixerChannel(name ++ "comb", s, 2, 2, level: ~target.level * ~cLevelRatio, outbus: ~master, completionFunc: { |chan|
		chan.newPostSend(~rvbmc, 0.8);
	});
	~target.doWhenReady {
		~target.newPreSend(~combsMC, 0);
		~target.newPostSend(~rvbmc, 0.75);
	};

	~levelSync = Updater(~target.controls[\level], e { |levelCtl, parms|
		if(parms[\what] == \value) { ~combsMC.level = levelCtl.value * ~cLevelRatio }
	});

	~wt = \makeWavetables.eval(8, s, 2048, nil, { |nh|
		var	a = Array.squareAmps(nh), i = (0, 2 .. a.size-1).scramble;
		i.keep((i.size * rrand(0.1, 0.2)).asInteger).do { |ind| a[ind] = 0 };
		a
	});
	~bigdelay = Buffer.alloc(s, 44100, 1);
	~littledelays = Buffer.allocConsecutive(~numCombs, s, (s.sampleRate / ~cFundamental).roundUp);
	out = Voicer(16, WrapInstr("osc2.vosc3mapfiltenv"), [bufbase: `(~wt.first.bufnum), numbufs: `(~wt.size), basefreq: `(48.midicps), topfreq: `(127.midicps), env: Env.adsr(1.6, 0.8, 0.6, 2.5), fenv: Env(#[1, 40, 1], #[3.5, 4.0], \sin), vtimespec: #[1, 1, exp].asSpec, detune: 1.003, /* ffreq: 900,*/ fenv_sens: 0.8, fenv_vsens: 1, vsens: 0.2], target: ~target);
	out.mapGlobal(\ffreq, nil, 400, \freq);
	out.mapGlobal(\rq, nil, 1, \myrq);
	out.mapGlobal(\clevel, nil, 1, \amp);
	out.mapGlobal(\density, nil, 0.8, #[0.5, 3.0]);
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


MIDIRecBuf(\waterch, [
	#[40, 47, 57, 62, 78, 61, 71,
		33, 45, 54, 55, 60, 71, 86,
		31, 43, 52, 57, 62, 71, 78, 88],
	#[7, 7, 8].collect { |n| (1 ! (n-1)) ++ #[2] }.flat,
	1, 0.5
].asNotes, (type: \ch, mode: \g)) => MBM(0);

PR(\arpeg1).clone {
	~superAsPattern = ~asPattern;
	~asPattern = { |inEvent|
		~preInsertStream !? {
			inEvent = ~preInsertStream.next(inEvent);
		};
		~superAsPattern.(inEvent);
	};
} => PR(\arpeg1PreInsert);

{ |notes, inEvent| 
	if(notes.isArray) {
		Pn(notes.keep(min(notes.size, inEvent[\numNotes])), 1)
	} {
		Pn(notes.asArray.asNotes.keep(min(notes.size, inEvent[\numNotes])), 1)
	}
} => ArpegPat(\blockNum);

//{ |notes, parentEv| [parentEv[\delta], parentEv[\delta] - 4, 0.4] } => MicRh(\waterch);
{ |notes, parentEv| [parentEv[\delta], parentEv[\delta] - 4, ~gatePatStream.next] } => MicRh(\waterch);

(make: { |name|
	BP(name).free;
	\newCh.eval(name, \arpeg1PreInsert, \macroRh, MBM(0)[\waterch], nil, Pwhite(16, 22, inf), \waterch, \blockNum, nil, \g);
	BP(name).child.makeChordPattern = { Pclutch(Pseq(~chords, inf), Pdelay(Pkey(\numNotes) >= 7)) };
	BP(name).child.gatePat = Pn(Pgeom(0.1, (10 ** (1/9)).reciprocal, { rrand(5, 10) }));
	BP(name).child.argPairs = [fenv_tscale: Pexprand(0.8, 1.8, inf)];
	BP(name).child[\reset] = BP(name).child[\reset] <> {
		~preInsert = Pbind(
			\numNotes, Pseq([
				Pwhile1({ |ev, next| next <= 7 },
					Pseries(Pseq([4, Pwhite(4, 7, inf)]).asStream, 1, inf)),
				Pn(8, 2)
			], inf)
		)
	};
	BP(name).value.reset;
	BP(name)
}, type: \bp) => Fact(\waterch);

