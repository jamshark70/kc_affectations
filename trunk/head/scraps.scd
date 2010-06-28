				indices = (0..17).scramble.keep((i*1.5).round.asInteger);
			indices.do { |i| amps[i] = rrand(0.0, 0.1) };

//[test = ~fullSet.any { |x| ~activeRatios.includes(x).not }, (~fullSet - ~activeRatios).size > 0, not(~fullSet == ~activeRatios), ~fullSet.class, ~activeRatios.class, ~fullSet.size, ~activeRatios.size].debug("tests");


			result = Pfset(
				{ self.activeRatios.add(ratio) },
				Pfin(repeats, Pbind(
					\instrument, \partial1bgated,
					\ratio, ratio,
					\freq, BPStream(\fund) * ratio,
					\egRate, ~tempoCtl.asMap,
					\egRateMul, ratio,
					\delta, ratio.reciprocal,
					\sustain, Pkey(\delta) * 0.5,
					\egBuf, ~egbuf,
					\chan, ~chan
				)),
				{ self.activeRatios.remove(ratio) }
			);


