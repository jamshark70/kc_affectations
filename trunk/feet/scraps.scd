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

