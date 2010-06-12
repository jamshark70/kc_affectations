// todo: work on pitch material (divide between line IDs?)
// klanky one, when decay is very short, sounds like pizz! - does not sound good low, though

// next:
// better pitch control?
// waveshaping?
// harmonies with steps
// steps --> water



ChuckableBrowser.newWindow;
SynthDescLib.global.browse;
Object.browse;
s.queryAllNodes;

MIDIPort.init([1]);
MIDIPort.resetAll;

\makeEmptyMixer8.eval;

(
[m, n].free;
m = MixerChannel(\test1, s, 1, 2);
n = MixerChannel(\test2, s, 2, 2);
//MixingBoard(\test, nil, m, n);

b = MixingBoard.new;
8.do { |i|
	MixerChannelGUI.new(nil, b) => MCG.prNew(i);
	if(MIDIPort.initialized) {
		MixerMIDIControl(\omni, nil, MCG(i).v);
	};
	b.add(MCG(i).v);
};

m => MCG(0); n => MCG(1);
//~master => MCG(7);

{ MixingBoard.at(0).refresh }.defer(4.0);
)

MixingBoard.at(0).refresh;

// in case I forgot to init midi first
8.do { |i| MixerMIDIControl(\omni, nil, MCG(i).v); };



// footstep counterpoint
// pr: manage rhythmic counterpoint
// user's responsibility to make sure leadTime = 0.5 * maxLag * tempo
(
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
		shapebuf = -1, shapeXf = 1, chorusFreq = 0.05, chorusAmt = 0.02, chorusDelay = 0.03,
		lpfreq = 2000, lprq = 1|
	var harm = \harm.kr((1..5)),
		amps = \amps.kr((1..5).reciprocal),
		decays = \decays.kr(1 ! 5),
		sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
			* EnvGen.kr(Env.linen(attack, time, decay)),
		// Klank(decay) - Klank(attack) is like a bank of Formlets
		filt = Klank.ar(`[harm, amps, decays], sig, freqscale: ffreq, decayscale: filtDecay)
			- Klank.ar(`[harm, amps, decays], sig, freqscale: ffreq, decayscale: filtAttack),
		shaped, dly, cfreqRand = chorusFreq * 0.2;
	sig = Limiter.ar(sig + filt);
	shaped = Select.ar(shapebuf < 0, [Shaper.ar(shapebuf, sig), sig]);
	sig = XFade2.ar(sig, shaped, shapeXf);
	dly = sig;
	3.do {
		dly = DelayL.ar(dly, chorusDelay + chorusAmt,
			SinOsc.kr(
				chorusFreq + Rand(cfreqRand.neg, cfreqRand),
				Rand(0, 2pi),
				chorusAmt, chorusDelay
			));
		sig = sig + dly;
	};
// 	sig = LeakDC.ar(sig);
	sig = RLPF.ar(sig, lpfreq, lprq);
	DetectSilence.ar(sig, 0.001, doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, amp));
}).add;

PR(\abstractProcess).clone {
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
		~chan = MixerChannel(~collIndex, s, 2, 2);
		~path = (if(thisProcess.platform.name == \osx) {
			"/Users/dewdrop/sounds/fx/footsteps"
		} {
			"/media/DLM/trax/kc/samples/feet"
		}) +/+ "58454_sinatra314_footsteps_wooden_floor_loop.wav";
		~buf = Buffer.readAndQuery(s, ~path);

		~pt = TabFileReader.read(~path.dirname +/+ "58454_labels.txt").flop[0].asFloat;
		~ptd = ~pt.differentiate.drop(1);
		~pt = ~pt.drop(1);
		~mean = ~ptd.mean;

		~combFreq = BPStream(\combMel).collect { |degree| ~mode.asMode.cps(degree) };

		~shapeBufs = Array(~shapeBufSpecs.size);
		~shapeBufSpecs.pairsDo { |method, amps|
			~shapeBufs.add(Buffer.alloc(s, 2048, 1, completionMessage: { |buf|
				buf.perform((method ++ "Msg").asSymbol, amps);
			}));
		};

		~gestureArray = Pnsym1(BPStream(\gsel), ~gSelectors);

		currentEnvironment
	};

	~freeCleanup = {
		[~chan, ~buf, ~shapeBufs].free;
	};

	~lastEventTime = 0;
	~lastItems = IdentitySet.new;

	~numWalkers = 3;
// 	~numWalkers_ = { |numW|
// 		~numWalkers = numW;
// 		if(BP(~collIndex).isPlaying) {
// 			"BP(%): numWalkers changed, but won't take effect until after stopping."
// 				.format(~collIndex.asCompileString).warn;
// 		};
// 		currentEnvironment
// 	};

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
			(~gestureStream.next(inval) ! inval[\numWalkers])
		},
		oneSyncop: Pfunc { |inval|
			(~gestureOne ! inval[\numWalkers])
				.put(inval[\numWalkers], ~gestureStream.next(inval))
		},
		manySyncop: Pfunc { |inval|
			var	out = (~gestureOne ! inval[\numWalkers]),
			pool = Array.series(inval[\numWalkers], 0, 1).scramble;
			~numSyncopStream.next(inval).do { |i|
				out.put(pool[i], ~gestureStream.next(inval))
			};
			out//.debug("gestures")
		}
	);

	~gestures = (
		one: { |i| Pbind(\delta, 1, \amp, ~amp.(i), \ffreq, ~loFilt) },

		accrest: { |i, parms|
			Pbind(
				\instrument, Pseq(#[bufGrainPanKlank, rest]),
				\delta, Pseq([1, parms[\dur] - 1], 1),
				\amp, ~amp.(i),
				\filtAttack, BPStream(\klankAttack),
				\filtDecay, BPStream(\klankDecay),
				\ffreq, BPStream(\combFreq),
				\lpfreq, ~hiFilt,
				\chorusAmt, BPStream(\syncopChorusAmt),
				\chorusDelay, Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf)
			)
		},
		accsteps: { |i, parms|
			Pbind(
				\instrument, Pseq([\bufGrainPanKlank, Pn(~def, inf)]),
				\delta, 1,
				\amp, ~amp.(i),
				\filtAttack, BPStream(\klankAttack),
				\filtDecay, BPStream(\klankDecay),
				// ~def uses ffreq; klank synth uses lpfreq
				\ffreq, Pif(Pbinop('==', Pkey(\instrument), ~def), ~loFilt, BPStream(\combFreq)),
				\lpfreq, ~hiFilt,
				\chorusAmt, BPStream(\syncopChorusAmt),
				\chorusDelay, Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf)
			)
		},

		oneKlank: { |i, parms|
			Pbind(
				\instrument, \bufGrainPanKlank,
				\delta, 1,
				\amp, ~amp.(i),
				\ffreq, BPStream(\combFreq),
				\filtAttack, 0.01,
				\filtDecay, Env(#[0.01, 0.01, 2.0], [parms.preSyncop, parms.dur - parms.preSyncop], \exp),
				\lpfreq, 3500
			) 
		},
		halfSyncop: { |i, parms| 
			Pbind(
				\instrument, Pseq([Pn(~def, parms[\preSyncop] + 1), Pn(\bufGrainPanKlank, inf)]),
				\delta, Pseq([Pn(1, parms[\preSyncop]), 1.5, Pn(1, inf)], 1),
				\amp, ~amp.(i),
				\filtAttack, BPStream(\klankAttack),
				\filtDecay, BPStream(\klankDecay),
				// ~def uses ffreq; klank synth uses lpfreq
				\ffreq, Pif(Pbinop('==', Pkey(\instrument), ~def), ~loFilt, BPStream(\combFreq)),
				\lpfreq, ~hiFilt,
				\chorusAmt, BPStream(\syncopChorusAmt),
				\chorusDelay, Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf)
			)
		},
		triplet4: { |i, parms|
			Pbind(
				\instrument, Pseq([Pn(~def, parms[\preSyncop]), Pn(\bufGrainPanKlank, inf)]),
				\delta, Pseq([Pn(1, parms[\preSyncop]), Pn(2/3, inf)], 1),
				\amp, ~amp.(i),
				\filtAttack, BPStream(\klankAttack),
				\filtDecay, BPStream(\klankDecay),
				// ~def uses ffreq; klank synth uses lpfreq
				\ffreq, Pif(Pbinop('==', Pkey(\instrument), ~def), ~loFilt, BPStream(\combFreq)),
				\lpfreq, ~hiFilt,
				\chorusAmt, BPStream(\syncopChorusAmt),
				\chorusDelay, Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf)
			)
		},
		someSyncops: { |i, parms|
			var prob;
			~syncProbStream ?? { ~makeStreamForKey.(\syncProb) };
			prob = ~syncProbStream.next(parms);
			Pbind(
				\delta, Pseq([
					Pn(1, parms[\preSyncop]),
					Pwrand([1, Pseq(#[1.5, 1.5, 1], 1)], [1 - prob, prob], inf)
				], 1),
				\prevDelta, Pdelay(Pkey(\delta), 1),
				\instrument, Pif(Pkey(\delta) + Pkey(\prevDelta) >= 3, \bufGrainPanKlank, ~def),
				\amp, ~amp.(i),
				\filtAttack, BPStream(\klankAttack),
				\filtDecay, BPStream(\klankDecay),
				// ~def uses ffreq; klank synth uses lpfreq
				\ffreq, Pif(Pbinop('==', Pkey(\instrument), ~def), ~loFilt, BPStream(\combFreq)),
				\lpfreq, ~hiFilt,
				\chorusAmt, BPStream(\syncopChorusAmt),
				\chorusDelay, Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf)
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
				\amp, ~amp.(i),
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
				\amp, ~amp.(i),
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

	~mode = \default;
	~combMel = Paccumbounce(28, 49, Pwhite(-7, 7, inf).reject(_ == 0));
	~filtDecay = 1.0;
	~filtAmpSpec = #[0, 1, -6].asSpec;
	~filtAmp = Pkey(\filtDecay).collect(~filtAmpSpec.map(_));

	~syncProb = 0.1;

	~syncopChorusAmt = Pwhite(0.002, 0.012, inf);
	~klankAttack = 0.01;
	~klankDecay = 0.01;

	~loFilt = 2400;
	~hiFilt = 18000;
	~index = Plazy { Pwhite(0, ~ptd.size - 1, inf) };
	~delta = { |key, parms|
		Plazy { ~deltas[key].(parms).asPattern }
	};
	~rate = 1.25;
	~eventLag = Pwhite(0.0, 0.03, inf);

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
			\rate, Pindex(~ptd, Pkey(\i), inf) / ~mean * BPStream(\rate),
			\attack, 0.005,
			// note, phase is expected to be -1..0 so '+' really subtracts
			\start, (Pindex(~pt, Pkey(\i), inf) + (BP(~collIndex).quant.phase / Ptempo() * Pkey(\rate))) * ~buf.sampleRate,
			\lag, BPStream(\eventLag),
			\chan, ~chan,

			// klank synth crashes in linux if bufnum is -1; gesture can override
			\shapebuf, ~shapeBufs.first,
 			\pan, ~pan.(i, parms)
		)
	};

	~asPattern = {
		~numWalkersStream ?? { ~makeStreamForKey.(\numWalkers) };
		~durStream ?? { ~makeStreamForKey.(\dur) };
		~preSyncStream ?? { ~makeStreamForKey.(\preSync) };
// 		~whichSyncStream ?? { ~makeStreamForKey.(\whichSync) };
		~gestureStream ?? { ~makeStreamForKey.(\gesture) };
		~gestureArrayStream ?? { ~makeStreamForKey.(\gestureArray) };
		~numSyncopStream ?? { ~makeStreamForKey.(\numSyncop) };
		PnNilSafe(Plazy { |inval|
			var	dur = ~durStream.next,
				preSyncop, parms, gestArray;
			if(dur.notNil and: { dur > 0 }) {
				parms = (dur: dur, numWalkers: ~numWalkersStream.next(inval));
				if(parms[\numWalkers] > 0) {
					preSyncop = (dur * ~preSyncStream.next(dur)).roundUp(1);
					gestArray = ~gestureArrayStream.next(parms).asArray;
					parms.put(\gestureArray, gestArray)
						.put(\preSyncop, (dur * ~preSyncStream.next(dur)).roundUp(1));
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
		}, inf)
	};
} => PR(\steps1);
)

TempoClock.tempo = 110/60;

BP(\st).free;

PR(\steps1) => BP(\st);
if(MCG.exists(2)) { BP(\st) => MCG(2) };
BP(\st).leadTime = 0.015 * (110/60);
#[1, -0.18, 0, true] => BP(\st);
BP(\st).chan.level = -10.dbamp;

// try some counts
// steps, steps, rest, steps, steps, acc+steps, acc+steps, acc, acc
BP(\st).dur = Pseq(#[/*8, 32, 6,*/ 8, 5, 7, 4, 4, 4], 1);
BP(\st).numWalkers = Pseq(#[/*1, 2, 0,*/ 2, 3, 3, 3, 3, 3], 1);
// gestureStream is not called for a rest segment
BP(\st).gesture = Pclutch(Pseq(#[/*one, one, /*one,*/ */ one, one, accsteps, accsteps, accrest, accrest], 1), Ptime().differentiate > 0).trace(prefix: "gesture: ");
BP(\st).gsel = \unison;
BP(\st).klankDecay = 0.011;

BP(\st).gesture.inspect

BP(\st).gSelectors.unison = Pfunc { |inval|
			(~gestureStream.next(inval) ! inval[\numWalkers])
		};
BP(\st).gestures.accrest = { |i, parms|
			Pbind(
				\instrument, Pseq(#[bufGrainPanKlank, rest]),
				\delta, Pseq([1, parms[\dur] - 1], 1),
				\amp, ~amp.(i),
				\filtAttack, BPStream(\klankAttack),
				\filtDecay, BPStream(\klankDecay),
				\ffreq, BPStream(\combFreq),
				\lpfreq, ~hiFilt,
				\chorusAmt, BPStream(\syncopChorusAmt),
				\chorusDelay, Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf)
			)
		};
BP(\st).gestures.accsteps = { |i, parms|
			Pbind(
				\instrument, Pseq([\bufGrainPanKlank, Pn(~def, inf)]),
				\delta, 1,
				\amp, ~amp.(i),
				\filtAttack, BPStream(\klankAttack),
				\filtDecay, BPStream(\klankDecay),
				// ~def uses ffreq; klank synth uses lpfreq
				\ffreq, Pif(Pbinop('==', Pkey(\instrument), ~def), ~loFilt, BPStream(\combFreq)),
				\lpfreq, ~hiFilt,
				\chorusAmt, BPStream(\syncopChorusAmt),
				\chorusDelay, Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf)
			)
		};

BP(\st).gesture = \oneKlank;
BP(\st).gesture = \halfSyncop;
BP(\st).gestureOne = \oneKlank;
BP(\st).numWalkers = 5;

BP(\st).gesture = \someSyncops;
BP(\st).gestureOne = \someSyncops;
BP(\st).syncProb = 0.25;


// testing new counterpoint gestures
BP(\st).dur = 16;
BP(\st).preSync = 0.25;
BP(\st).numWalkers = 1;
BP(\st).gsel = \oneSyncop;
BP(\st).gestureOne = \one;

BP(\st).gesture = Pwrand(#[halfSyncop, triplet4], #[0.75, 0.25], inf);
BP(\st).gesture = Pseq(#[halfSyncop, triplet4], inf);
BP(\st).gesture = \halfSyncop;
BP(\st).gesture = \running;
BP(\st).gesture = \tripping;

BP(\st).numWalkers = 2;

// overlaying above rhythms
BP(\st).numWalkers = 5;
BP(\st).numSyncop = 2;  // try 2?
BP(\st).gsel = \manySyncop;
BP(\st).gestureOne = \one;
//BP(\st).gesture = \patRejectLastN.eval(Prand(#[halfSyncop, dot8, triplet4, running, tripping], inf));

BP(\st).gesture = \patRejectLastN.eval(Ppatlace([Prand(#[halfSyncop, dot8, triplet4], inf), Prand(#[halfSyncop, dot8, triplet4, running, tripping])], inf), 2)/*.trace(prefix: "gesture: ")*/;

//BP(\st).syncopRateMul = 1;// Pwhite(1.5, 3.0, inf);
BP(\st).klankDecay = 0.015;
BP(\st).mode = \patRejectLastN.eval(Pxrand(Mode.keys.asArray.reject(#[cmin, default].includes(_)), inf), 5)/*.trace(prefix: "mode: ")*/;

BP(\st).saveGestureArray = BP(\st).gestureArray;
BP(\st).gestureArray = BP(\st).gestureArray.trace(prefix: "gesturearray: ");

BP(\st).gestureArray = BP(\st).saveGestureArray;

BP(\st).syncopCombFreq = { |i, parms|
		Prand(rrand(37, 46) + [0, rrand(2, 5)], inf)
	};

BP(\st).syncopCombFreq = { |i, parms|
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

BP(\st).syncopCombFreq.value.asStream.nextN(50)

BP(\st).chorusAmps = (2..4).reciprocal;

BP(\st).eventStreamPlayer.nextBeat

g = GenericGlobalControl(\decay, nil, 0.015, #[0.01, 0.03, \exp]);
g.gui;
BP(\st).klankDecay = g.asPattern;

g.spec = #[0.01, 0.5, \exp].asSpec;


// clusters of syncop, with unifying points
BP(\st).gsel = Pseq(#[unison, manySyncop], inf);
BP(\st).gesture = Pswitch1([\oneKlank, \patRejectLastN.eval(Ppatlace([Prand(#[halfSyncop, dot8, triplet4], inf), Prand(#[halfSyncop, dot8, triplet4, running, tripping], inf)], inf), 2)], Pseq([0, Pn(1, { |ev| ev[\numSyncop] })], inf));
BP(\st).dur = Pseq([1, Pwhite(6, 16, 1)], inf);
BP(\st).preSync = 0;
BP(\st).preSync = Pfunc(2 / _);


// better: 2 beat 'one' anacrusis to klank "stomp"
BP(\st).gsel = Pseq(#[manySyncop, one, unison], inf);
// note, gsel == \one does not poll the 'gesture' stream
BP(\st).gesture = Pswitch1([\oneKlank, \patRejectLastN.eval(Ppatlace([Prand(#[halfSyncop, dot8, triplet4], inf), Prand(#[halfSyncop, dot8, triplet4, running, tripping], inf)], inf), 2)], Pseq([Pn(1, { |ev| ev[\numSyncop] }), 0], inf));
BP(\st).dur = Pseq([Pwhite(6, 16, 1), 2, 1], inf);
BP(\st).preSync = 0;
BP(\st).preSync = Pfunc(2 / _);



q = Pseq([0, Pn(1, { |ev| ev[\numSyncop] })], inf).asStream;
q.next((numSyncop: 2));

q = Pswitch1([\oneKlank, \patRejectLastN.eval(Ppatlace([Prand(#[halfSyncop, dot8, triplet4], inf), Prand(#[halfSyncop, dot8, triplet4, running, tripping])], inf), 2)], Pseq([0, Pn(1, { |ev| ev[\numSyncop] })], inf)).asStream;
q.next((numSyncop: 2));


// formalize syncops
// BP(\st).gSelectors[\manySyncop].postcs
XBP(\st).numSyncop = 1;

BP(\st).dur = Pwhite(7, 16, inf); // Pseq(#[], 1);
BP(\st).numWalkers = Pseq(#[], 1);
// gestureStream is not called for a rest segment
BP(\st).gesture = Pclutch(Pseq(#[halfSyncop], 1), Ptime().differentiate > 0);
BP(\st).gsel = \unison;
BP(\st).klankDecay = 0.011;



BP(\st).numSyncop = Pwhite(1, 2, inf);
BP(\st).gestureArray = Pfunc { |inval|
	var	out = (~gestureOne ! ~numWalkers),
		pool = Array.series(~numWalkers, 0, 1).scramble;
// 	~numSyncopStream ?? { ~makeStreamForKey.(\numSyncop) };
	~numSyncopStream.next(inval).do { |i|
		out.put(pool[i], ~gestureStream.next(inval))
	};
	out.debug("gestures")
};

BP(\st).gestureArray.postcs;
BP(\st).gestureArray = BP(\st).gestureArray.trace(prefix: "gestures: ");

BP(\st).play(doReset: true);
BP(\st).stop;

BP(\st).maxSustains[\bufGrainPanKlank] = 0.4;
BP(\st).maxSustains[\bufGrainPanFilt] = 0.8;
BP(\st).maxSustains[\default] = 0.8;

g.dump

g.free;
g = GenericGlobalControl(\cdcy, nil, 0.05, #[0.01, 2.0, \exp]);
g.gui;
BP(\st).filtDecay = g;

BP(\st).filtAmpSpec = #[0, 1, -10].asSpec;

SynthDef(\bufGrainPanKlank, { |start, time, bufnum, pan, rate = 1, amp = 1,
		attack = 0.001, decay = 0.02, outbus, ffreq = 2000, filtDecay = 0.1|

n.play(\bufGrainPanKlank, [start: BP(\st).pt.choose * 44100, time: 0.6, bufnum: BP(\st).buf, ffreq: 400, filtAttack: 0.5, filtDecay: 1.0, harm: #[1, 4, 7, 10, 13], amps: #[1, 3, 5, 7, 9].reciprocal]);

BP(\st).shapeBufs.last.plotWavetable

BP(\st).gestures.oneKlank = { |i, parms|
			Pbind(
				\instrument, \bufGrainPanKlank,
				\delta, 1,
				\amp, ~amp.(i),
				\ffreq, BPStream(\combFreq),
				\filtAttack, 0.01,
				\filtDecay, Env(#[0.01, 0.01, 2.0], [parms.preSyncop, parms.dur - parms.preSyncop], #[0, 4]),
				\shapebuf, ~shapeBufs.choose,
\shapeXf, -0.7,
				\lpfreq, 3500
			) 
		};

BP(\st).syncopChorusAmt = 0.005;
BP(\st).syncopChorusAmt = Pwhite(0.002, 0.012, inf);

BP(\st).klankAttack = 0.01;
BP(\st).klankDecay = 0.05;

BP(\st).gestures.halfSyncop = { |i, parms| 
	Pbind(
		\instrument, Pseq([Pn(~def, parms[\preSyncop] + 1), Pn(\bufGrainPanKlank, inf)]),
		\delta, Pseq([Pn(1, parms[\preSyncop]), 1.5, Pn(1, inf)], 1),
		\amp, ~amp.(i),
		\filtAttack, BPStream(\klankAttack),
		\filtDecay, BPStream(\klankDecay),
		// ~def uses ffreq; klank synth uses lpfreq
		\ffreq, Pif(Pbinop('==', Pkey(\instrument), ~def), ~loFilt, BPStream(\combFreq)),
		\lpfreq, ~hiFilt,
		\chorusAmt, BPStream(\syncopChorusAmt),
		\chorusDelay, Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf)
	)
};

BP(\st).gestures.triplet4 = { |i, parms|
			Pbind(
				\instrument, Pseq([Pn(~def, parms[\preSyncop]), Pn(\bufGrainPanKlank, inf)]),
				\delta, Pseq([Pn(1, parms[\preSyncop]), Pn(2/3, inf)], 1),
				\amp, ~amp.(i),
				\filtAttack, BPStream(\klankAttack),
				\filtDecay, BPStream(\klankDecay),
				// ~def uses ffreq; klank synth uses lpfreq
				\ffreq, Pif(Pbinop('==', Pkey(\instrument), ~def), ~loFilt, BPStream(\combFreq)),
				\lpfreq, ~hiFilt,
				\chorusAmt, BPStream(\syncopChorusAmt),
				\chorusDelay, Pkey(\chorusAmt) * Pwhite(1.1, 2.0, inf)
			)
		};
