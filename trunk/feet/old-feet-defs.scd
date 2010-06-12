
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


// pad

WrapInstr("osc2.vosc3panslide", { |freq, startFreq, slideTime = 0, slideTrig = 1|
	freq = EnvGen.kr(Env([startFreq, freq], [slideTime], \sin), slideTrig);
	WrapInstr.wrap("osc2.vosc3panfilt", [freq]);
}, [NoLagControlSpec.newFrom(\freq.asSpec), NoLagControlSpec.newFrom(\freq.asSpec), NoLagControlSpec(0, 2), TrigSpec.new]);

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

	~target = MixerChannel(name, s, 2, 2, level: -17.dbamp, outbus: ~master /*, completionFunc */);
	out = Voicer(15, WrapInstr("osc2.vosc3panslide"), [bufbase: `(~wt.first.bufnum), numbufs: `(~wt.size)/*, bufmod: KrNumberEditor(0, [0, ~wt.size-1.001])*/, env: Env.adsr(1.6, 0.1, 0.8, 3.2), detune: 1.003, slideTime: 0.7, ffreq: 3000, vsens: `0.6, slideTrig: SimpleTrigger.new], target: ~target);
	out.mapGlobal(\bufmod, nil, 0, [0, ~wt.size-1.001]);
	out.mapGlobal(\ffreq, nil, 2100, \freq);
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
	~longDur = Pwhite(16, 30, inf);
	~longHold = Pwhite(0.4, 0.6, inf);
	~preRest = Pwhite(0, 7, inf);
	~gate = Pseq(#[1, 1, 0.001], inf);

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
			\durArray, Pstutter(3,
				Ptuple([BPStream(\preRest), BPStream(\shortDur), BPStream(\longDur)], inf)),
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

// SynthDef(\bufGrainPanKlank, { |start, time, bufnum, pan, rate = 1, amp = 1,
// 		attack = 0.001, decay = 0.02, outbus, ffreq = 2000, filtAttack = 0.1, filtDecay = 1.0|
// 	var harm = \harm.kr((1..5)),
// 		amps = \amps.kr((1..5).reciprocal),
// 		decays = \decays.kr(1 ! 5),
// 		sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
// 			* EnvGen.kr(Env.linen(attack, time, decay)),
// 		// Klank(decay) - Klank(attack) is like a bank of Formlets
// 		filt = Klank.ar(`[harm, amps, decays], sig, freqscale: ffreq, decayscale: filtDecay)
// 			- Klank.ar(`[harm, amps, decays], sig, freqscale: ffreq, decayscale: filtAttack);
// 	sig = Limiter.ar(sig + filt);
// 	DetectSilence.ar(sig, 0.001, doneAction: 2);
// 	Out.ar(outbus, Pan2.ar(sig, pan, amp));
// }).add;

SynthDef(\bufGrainPanKlank, { |start, time, bufnum, pan, rate = 1, amp = 1,
		attack = 0.001, decay = 0.02, outbus, ffreq = 2000, filtAttack = 0.1, filtDecay = 1.0,
//		filtAmp = 1,
		shapebuf = -1, shapeXf = 1, chorusFreq = 0.05, chorusAmt = 0.02, chorusDelay = 0.03,
		lpfreq = 2000, lprq = 1|
	var harm = \harm.kr((1..5)),
		amps = \amps.kr((1..5).reciprocal),
		decays = \decays.kr(1 ! 5),
		chorusAmps = \chorusAmps.kr(1 ! 3),
		sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
			* EnvGen.kr(Env.linen(attack, time, decay)),
		// Klank(decay) - Klank(attack) is like a bank of Formlets
		filt = Klank.ar(`[harm, amps, decays], sig, freqscale: ffreq, decayscale: filtDecay)
			- Klank.ar(`[harm, amps, decays], sig, freqscale: ffreq, decayscale: filtAttack),
		shaped, dly, cfreqRand = chorusFreq * 0.2;
	sig = (sig + Limiter.ar(filt)); // * filtAmp;
	shaped = Select.ar(shapebuf < 0, [Shaper.ar(shapebuf, sig), sig]);
	sig = XFade2.ar(sig, shaped, shapeXf);
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
	sig = RLPF.ar(sig, lpfreq, lprq);
	DetectSilence.ar(sig, 0.001, doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, amp));
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

PR(\abstractProcess).clone {
	~bufPath = "58454_sinatra314_footsteps_wooden_floor_loop.wav";

	~event = (eventKey: \singleSynthPlayer);
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
		});
		~path = (if(thisProcess.platform.name == \osx) {
			"/Users/dewdrop/sounds/fx/footsteps"
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
				\amp, parms[\numWalkers].reciprocal, // ~amp.(i, parms),
				\filtAttack, BPStream(\klankAttack),
				\filtDecay, BPStream(\accDecay),
//				\filtAmp, parms[\numWalkers].reciprocal,
				\ffreq, BPStream(\combFreq),
				\lpfreq, ~hiFilt,
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
				// ~def uses ffreq; klank synth uses lpfreq
				\ffreq, Pif(Pbinop('==', Pkey(\instrument), ~def), ~loFilt, BPStream(\combFreq)),
				\lpfreq, ~hiFilt,
				\chorusAmt, BPStream(\syncopChorusAmt),
				\chorusDelay, Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf)
			)
		},
		stepsacc: { |i, parms|
			~gestures[\accsteps].value(i, parms, Pseq([Pn(~def, parms[\dur] - 1), \bufGrainPanKlank]))
// 			Pbindf(~gestures[\accsteps].value(i, parms),
// 				\instrument, Pseq([Pn(~def, parms[\dur] - 1), \bufGrainPanKlank])
// 			)
		},
		stepsaccUnpitched: { |i, parms|
			Pbindf(~gestures[\accsteps].value(i, parms,
				Pseq([Pn(~def, parms[\dur] - 1), \bufGrainPanKlank])),
				\filtDecay, Pkey(\filtAttack)
			)
		},

		accstepsUnpitched: { |i, parms|
			Pbindf(~gestures[\accsteps].value(i, parms), \filtDecay, Pkey(\filtAttack))
		},
		accrestUnpitched: { |i, parms|
			Pbindf(~gestures[\accrest].value(i, parms), \filtDecay, Pkey(\filtAttack))
		},

		allAcc: { |i, parms|
			~gestures[\accsteps].value(i, parms, \bufGrainPanKlank)
		},

		oneKlank: { |i, parms|
			Pbind(
				\instrument, \bufGrainPanKlank,
				\delta, 1,
				\amp, ~amp.(i, parms),
//				\amp, Pif(Pbinop('==', Pkey(\instrument), ~def), ~amp.(i, parms), parms[\numWalkers].reciprocal),
				\ffreq, BPStream(\combFreq),
				\filtAttack, 0.01,
				\filtDecay, Env(#[0.01, 0.01, 2.0], [parms.preSyncop, parms.dur - parms.preSyncop], \exp),
//				\filtAmp, parms[\numWalkers].reciprocal,
				\lpfreq, 3500
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
				// ~def uses ffreq; klank synth uses lpfreq
// 				\ffreq, Pif(Pbinop('==', Pkey(\instrument), ~def), ~loFilt, BPStream(\combFreq)),
				\ffreq, Pif(Pbinop('==', Pkey(\instrument), ~def), ~loFilt,
					~syncopCombFreq.(i, parms).collect { |notenum, ev|
						ev[\mode].asMode.cps(notenum)
					}
				),
				\lpfreq, ~hiFilt,
				\chorusAmt, BPStream(\syncopChorusAmt),
				\chorusDelay, Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf),
				\chorusAmps, ~chorusAmps
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
		oneComb: { |i, parms|
			Pbind(
				\instrument, Pseq([
					Pn(~def, parms[\preSyncop] + 1),
					\bufGrainPanComb,
					Pn(~def, inf)
				], 1),
				\delta, Pseq([Pn(1, parms[\preSyncop]), 1.5, Pn(1, inf)], 1),
				\amp, ~amp.(i, parms),
				\ffreq, Pseq([Pn(~loFilt, parms[\preSyncop] + 1),
					Pfin(1, BPStream(\combFreq)), Pn(~hiFilt, inf)], 1),
				\filtDecay, BPStream(\filtDecay),
				\filtAmp, BPStream(\filtAmp)
			)
		},
		combMel: { |i, parms|
			Pbind(
				\instrument, Pseq([
					Pn(~def, parms[\preSyncop] + 1),
					Pn(\bufGrainPanComb, inf)
				], 1),
				\delta, Pseq([Pn(1, parms[\preSyncop]), 1.5, Pn(1, inf)], 1),
				\amp, ~amp.(i, parms),
				\ffreq, Pseq([Pn(~loFilt, parms[\preSyncop] + 1),
					BPStream(\combFreq)], 1),
				\filtDecay, BPStream(\filtDecay),
				\filtAmp, BPStream(\filtAmp)
			)
		},
		combMelRandPan: { |i, parms|
			Pbindf(~gestures[\combMel].value(i, parms), \pan, Pwhite(-1.0, 1.0, inf))
		}
	);

		// was Pkey(\delta) + Pkey(\prevDelta) >= 3, not general enough
	~syncopInstr = Pif(Pfunc { |ev|
		(thisThread.clock.beats + ~leadTime - ~quant.phase % 1) > 0
	}, \bufGrainPanKlank, Pfunc { ~def });

	~mode = \default;
	~combMel = Paccumbounce(28, 49, Pwhite(-7, 7, inf).reject(_ == 0));
	~filtDecay = 1.0;
	~filtAmpSpec = #[0, 1, -6].asSpec;
	~filtAmp = Pkey(\filtDecay).collect(~filtAmpSpec.map(_));

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

	~asPattern = {
		~numWalkersStream ?? { ~makeStreamForKey.(\numWalkers) };
		~durStream ?? { ~makeStreamForKey.(\dur) };
		~preSyncStream ?? { ~makeStreamForKey.(\preSync) };
// 		~whichSyncStream ?? { ~makeStreamForKey.(\whichSync) };
		~gestureStream ?? { ~makeStreamForKey.(\gesture) };
		~gestureArrayStream ?? { ~makeStreamForKey.(\gestureArray) };
		~numSyncopStream ?? { ~makeStreamForKey.(\numSyncop) };
// 		~modeStream ?? { ~makeStreamForKey.(\mode) };
		PnNilSafe(Plazy { |inval|
			var	dur = ~durStream.next,
				preSyncop, parms, gestArray;
			block { |break|
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
// is this check really needed? maybe not
//						if(gestArray.size < parms[\numWalkers]) { break.(nil) };
						parms.put(\gestureArray, gestArray)
							.put(\preSyncop, preSyncop.roundUp(1));
						Pfindur(dur, Ppar(
							gestArray.collect { |gesture, i|
								~oneWalkerPattern.(
									gesture,
									i,
									parms
								)
							}
						))
					} {
						// numWalkers = 0, just rest
						// empty array in Ppar would fail anyway
						Event.silent(dur)
					};
				} {
					// force reset of subpatterns - we don't know which one(s) ended early
					// returning 'nil' makes PnNilSafe stop
					~durStream = nil;
					~numWalkersStream = nil;
					~preSyncStream = nil;
					~gestureStream = nil;
					~gestureArrayStream = nil;
					~numSyncopStream = nil;
				};
			}
		}, inf)
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
} => PR(\steps1);
