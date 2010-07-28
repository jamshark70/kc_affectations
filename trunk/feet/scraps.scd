		Pbind(
			\instrument, ~def,
			\bufnum, ~buf,
			\delta, delta,
			\time, min(1, Pkey(\delta)) / Ptempo(),
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
			\amp, amp,
			\pan, pan,
			\lag, BPStream(\eventLag),

			\chan, ~chan,
			*extraPairs
		)




/*
	[	bpCmd: (name: \st, quant: `nil, prepareBP: { |bp|
			bp.klankDcyCtl.value = 0.011;
			bp.gsel = Ppatlace([\unison, Pseq([Pn(\oneSyncop, 3), Pn(\manySyncop, inf)], 1)], inf);
			bp.numWalkers = Pstutter(2, Pseq([3, 3, 3, Pn(5, inf)], 1));
			// numSyncop doesn't get called when gsel is oneSyncop
			bp.numSyncop = 2; // Pseq(#[/*1, 1, 1,*/ 2, 2, 2], 2);
			bp.dur = Pseq([4, Pwhite(12, 20, 1)], inf);
				// >= 1 is number of beats
			bp.preSync = Pwhite(1, Pfunc { |dur| min(4, dur) }, inf);
			bp.gesture = Pswitch1([
				\stepsaccUnpitched, 
				Pseq([
					\halfSyncop, \halfSyncop, 
					\patRejectLastN.eval(Ppatlace([Prand(#[halfSyncop, dot8, triplet4], inf), Prand(#[halfSyncop, dot8, triplet4, running, tripping])], inf), 2)
				], 1)
				// 'which' arg of Pswitch1 generates syncop gestures according to numsycop
			], Pseq([0, Pn(1, Pkey(\numSyncop).asStream)], inf)); //.trace(prefix: "gesture: ");
			bp.mode = Pif(
				Pfunc { |ev| #[someSyncops, halfSyncop, dot8, triplet4, running, tripping].includes(ev[\gesture]) },
				Pseq([Pn(\g, 5), Ppatlace([\g, \patRejectLastN.eval(Pxrand(Mode.keys.asArray.reject(#[cmin, default, g, g0].includes(_)), inf), 5)], inf)], 1),
				\g
			)/*.trace(prefix: "mode: ")*/;
		}),
// 		2,
// 		{ BP(\st).gestureOne = \accstepsUnpitched; 0 }
	],
	16,
*/


// 	\sync,
// 	funcCmd: { t.stop },



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



// debugging st
p.asPattern = {
		~numWalkersStream ?? { ~makeStreamForKey.(\numWalkers) };
		~durStream ?? { ~makeStreamForKey.(\dur) };
		~preSyncStream ?? { ~makeStreamForKey.(\preSync) };
// 		~whichSyncStream ?? { ~makeStreamForKey.(\whichSync) };
		~gestureStream ?? { ~makeStreamForKey.(\gesture) };
		~gestureArrayStream ?? { ~makeStreamForKey.(\gestureArray) };
		~numSyncopStream ?? { ~makeStreamForKey.(\numSyncop) };
// 		~modeStream ?? { ~makeStreamForKey.(\mode) };
		PnNilSafe(Plazy { |inval|
			var	dur = ~durStream.next.debug("dur"),
				preSyncop, parms, gestArray, result;
			result = block { |break|
				if(dur.notNil and: { dur > 0 }) {
					parms = (dur: dur, numWalkers: ~numWalkersStream.next(inval).debug("numw"));
					if(parms[\numWalkers].isNil) { break.(nil) };
					if(parms[\numWalkers] > 0) {
						preSyncop = ~preSyncStream.next(dur).debug("presync");
						if(preSyncop.isNil) { break.(nil) };
						if(preSyncop < 1.0) {
							preSyncop = (dur * ~preSyncStream.next(dur)).roundUp(1);
						};
						gestArray = ~gestureArrayStream.next(parms).asArray.debug("garray");
						if(gestArray.size < parms[\numWalkers]
							or: { gestArray.any(_.isNil) }) { break.(nil) };
						parms.put(\gestureArray, gestArray)
							.put(\preSyncop, preSyncop.roundUp(1));
						Pfindur(dur, Ppar(
							gestArray.collect { |gesture, i|
								~oneWalkerPattern.(
									gesture,
									i,
									parms
								).debug("onew"++i)
							}
						))
					} {
						// numWalkers = 0, just rest
						// empty array in Ppar would fail anyway
						Event.silent(dur)
					};
				};
			};
			result ?? {
"RESULT WAS NIL, CLEARING STREAMS".debug;
				// force reset of subpatterns - we don't know which one(s) ended early
				// returning 'nil' makes PnNilSafe stop
				~durStream = nil;
				~numWalkersStream = nil;
				~preSyncStream = nil;
				~gestureStream = nil;
				~gestureArrayStream = nil;
				~numSyncopStream = nil;
				nil
			};
		}, inf)
/*.collect { |ev|
	if(ev[\instrument] != ~def) { [ev[\gesture], ev[\amp]].debug("gesture, amp") };
	ev
}*/
	};

p.gestures[\one].postcs



p.oneWalkerPattern = { |gesture, i, parms|
		DebugPbind(
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
		DebugPbind(
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



// 			Pbind(
// 				\instrument, Pseq([\bufGrainPanKlankDist, Pkey(\instrument)], 1),
// 				#[pan, distance], ~xyPat.(parms),
// 				\delta, BPStream(\fastDelta),
// 				\amp, BPStream(\amp),
// 				\filtFreq, Pstutter(inf, BPStream(\kfreq)),
// 				\filtAttack, 0.01,
// 				\filtDecay, BPStream(\kdecay),
// 				\filtAmp, BPStream(\kamp),
// 				\chorusFreq, parms[\chorusFreq] ?? { Pstutter(inf, Pwhite(0.05, 0.11, inf)) },
// 				\chorusAmt, parms[\chorusFreq] ?? { 0.02 },
// 				\chorusDelay, parms[\chorusFreq] ?? { 0.03 },
// 				\chorusAmps, parms[\chorusAmps] ?? { [~defaultChorusAmps] },
// 				\harm, parms[\harm] ?? { [~defaultKlankHarm] },
// 				\amps, parms[\amps] ?? { [~defaultKlankAmps] },
// 				\decays, parms[\decays] ?? { [~defaultKlankDecays] }
// 			)
