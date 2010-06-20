				indices = (0..17).scramble.keep((i*1.5).round.asInteger);
			indices.do { |i| amps[i] = rrand(0.0, 0.1) };
