// everybody needs these...


if(Library.at(\affectations, \commonLoaded) != true) {

	#[c, db, d, eb, e, f, gb, g, ab, a, bb, b].do { |key, i|
		Mode(\default).v.copy.root_(i) => Mode(key);
		Mode(key).v.transposeRoot(0) => Mode((key ++ "0").asSymbol);
	};

	// lsys pattern
	Proto {
		~rules = [];
		~defaultRule = (nil -> { |in| in });
		~autoStreamArrays = true;
		~keepLowerLevels = false;
		
		~prep = { |pattern, levelPat, rules|
			~pattern = pattern;
			~levelPat = levelPat;
			rules !? { ~rules = rules };
			currentEnvironment
		};
	
		~embedInStream = { |inval|
			var	levelStream = ~levelPat.asStream,
				level, outputs = List.new;
			while { (level = levelStream.next(inval)).notNil } {
				inval = ~recurse.(inval, ~pattern.asStream, level, outputs);
			};
			inval
		};
	
		~recurse = { |inval, inStream, level, outputs|
			var	rule;
			if(~keepLowerLevels and: { outputs[level].notNil }) {
				inval = Pseq(outputs[level], 1).embedInStream(inval);
			} {
				// mondo sucko that I have to hack into the List
				outputs.array = outputs.array.extend(max(level+1, outputs.size));
				outputs[level] = List.new;
				if(level > 0) {
					r { |inval| ~recurse.(inval, inStream, level-1, outputs) }
					.do { |item|
						case
							{ (rule = ~rules.detect { |assn| assn.key.matchItem(item) }).notNil }
								{ inval = ~rewrite.(item, rule, inval, level, outputs) }
							{ ~defaultRule.key.matchItem(item) }
								{ inval = ~rewrite.(item, ~defaultRule, inval, level, outputs) }
								{ outputs[level].add(item); inval = item.embedInStream(inval) };
					};
				} {
					inval = inStream.collect { |item|
						outputs[level].add(item);
						item
					}.embedInStream(inval);
				};
			};
			inval
		};
	
		~rewrite = { |item, rule, inval, level, outputs|
			var	result = rule.value.value(item, level, inval);
			if(~autoStreamArrays and: { result.isSequenceableCollection }) {
				result = Pseq(result, 1);
			};
			inval = result.asStream.collect { |item| outputs[level].add(item); item }.embedInStream(inval);
		};
		~canEmbed = true;  // allow the Proto to act as a pattern
		~asStream = { |inval|
			r { ~embedInStream.(inval) }
		};
	} => PR(\rewriter);

	SynthDef(\returnPeak, { |bufnum, start, frames, trigid|
		var	term = Line.ar(0, 1, frames / BufSampleRate.ir(bufnum)),
			sig = PlayBuf.ar(1, bufnum, rate: BufRateScale.ir(bufnum), startPos: start),
			peak = Peak.ar(sig),
			done = Done.kr(term) + Done.kr(sig);
		SendTrig.kr(done, trigid, peak);
		FreeSelf.kr(done);
	}).add;

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


	Library.put(\affectations, \commonLoaded, true);
} { true };	// avoid stupid "found nil" warning
