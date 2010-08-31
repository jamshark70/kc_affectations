// everybody needs these...



s.waitForBoot {

	~master ?? { ~master = MixerChannel(\master, s, 2, 2, level: 1) };
	
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
	
	SynthDef(\returnPeak, { |bufnum, start, frames, trigid|
		var	term = Line.ar(0, 1, frames / BufSampleRate.ir(bufnum)),
			sig = PlayBuf.ar(1, bufnum, rate: BufRateScale.ir(bufnum), startPos: start),
			peak = Peak.ar(sig),
			done = Done.kr(term) + Done.kr(sig);
		SendTrig.kr(done, trigid, peak);
		FreeSelf.kr(done);
	}).add;

	Library.put(\affectations, \commonLoaded, true);

	topEnvironment[\rvbEvent] = ().proto_((
		glrvbout: ~glrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels },
		lcrvbout: ~lcrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels },
		distFar: 20
	));
	
};


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
			var result = SynthDef.wrap(ugenFunc, rates), out, pan, outctl;
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
		}, /*#[0.1],*/ metadata: metadata);  // 0.1 == lag on 'distance'
	} => Func(\addRvbOut);

	Proto {
		~prep = { |args|
			if(args.respondsTo(\keysValuesDo)) {
				currentEnvironment.putAll(args);
			};
			~locks = IdentitySet.new;
			// this way, makeStuff can have whatever args it needs
			// and it will pull them from the environment (after being put there by putAll)
			currentEnvironment.env.use { ~makeStuff.valueEnvir };
			currentEnvironment
		};
	
		~numCh = 1;
		~rate = \audio;
		~server = { Server.default };
	
		// user overrides
		~makeStuff = { |numCh, rate, server|
			~server = server.value;
			if((~bus = Bus.perform(rate, ~server, numCh)).isNil) {
				Error("couldn't get % bus".format(rate)).throw;
			};
			~bus //.debug("made");
		};
	
		~freeStuff = {
			~bus /*.debug("freed")*/ .free;
			~killNodes.do(_.free);
		};
	
		~addNode = { |node|
			var	endFunc = e { |obj, what|
				if(what == \n_end) {
					node.removeDependant(endFunc);
					~removeLock.(node);
				};
			};
			~locks.add(node);
			NodeWatcher.register(node);
			node.addDependant(endFunc);
		};
	
		~removeLock = { |obj|
			~locks.remove(obj);
			if(~locks.isEmpty) {
				~freeStuff.();
			};
		};
	} => PR(\busLock);
	
	PR(\busLock).clone {
		~busFreeDelay = 1;
		~freeStuff = {
			~stopThings.do(_.stop);
			~killNodes.do(_.free);
			AppClock.sched(~busFreeDelay, e { ~bus.free });
		};
	} => PR(\busFxPatLock);
	
	(parent: ProtoEvent(\polySynthPlayer).v.parent.copy.putAll((
		lockKey: \busLock,
		superPlay: ProtoEvent(\polySynthPlayer).v[\play],
		play: {
			var	chan = ~chan;
			~numCh ?? { ~numCh = ~chan.inChannels };
			~lock = PR(~lockKey).copy.prep((
				numCh: ~numCh, server: ~chan.server
			));
			~bus = ~lock.bus;
			~target = ~chan.synthgroup;
			~chan = nil;
			~superPlay.();
	
			if(~node.notNil and: { (~node.tryPerform(\isEmpty) ? false).not }) {
				~playExtraProcess.(chan);
				~node.do { |node| ~lock.addNode(node) };
			} {
				~lock.freeStuff;
			};
			if(~tempo.isNumber) { thisThread.clock.tempo = ~tempo }
		},
		playExtraProcess: { |chan|
			if(~lpcEv.size > 0) {
				~lpcEv.putAll((
					bus: chan.inbus,
					target: chan.effectgroup,
					chan: nil,
					inbus: ~lock.bus,
					collIndex: ~collIndex,
						// effectgroup might have post-lpc effect nodes (chorus etc.)
						// so put lpc's up front
					addAction: ~lpcEv[\addAction] ?? { \addToHead }
				))
				// cuz parent: don't work in putAll #@$*$&*$&@#312
				.parent_(ProtoEvent(~lpcProto ?? { \singleSynthPlayer }).v.parent)
				.play;
				~lpcEv[\node].do { |node| ~lock.addNode(node) };
			} {
				~sendNode = Synth("mixers/Send" ++ ~numCh,
					[busin: ~lock.bus, busout: chan.inbus, level: 1],
					chan.effectgroup
				);
				~lock.killNodes = ~sendNode;
			};
		} //,
	// 	notifyDependents: {
	// 		~node.do { |node| ~lock.addNode(node) };
	// 	}
	))) => ProtoEvent(\polySynthBusLock);
	
	(parent: ProtoEvent(\polySynthBusLock).v.parent.copy.putAll((
		lockKey: \busFxPatLock,
		playExtraProcess: { |chan|
			~lock.busFreeDelay = ~busFreeDelay ? 1;
			if(~fxPatEv.size > 0 and: { ~fxPatEv[\pat].notNil }) {
				~fxPatEv[\streamPlayer] = ~fxPatEv[\pat].play(
					thisThread.clock,
					Event(
						proto: (
							bus: chan.inbus,
							target: chan.effectgroup,
							chan: nil,
							inbus: ~lock.bus,
							lock: ~lock,
							collIndex: ~collIndex,
								// effectgroup might have post-lpc effect nodes (chorus etc.)
								// so put lpc's up front
							addAction: ~fxPatEv[\addAction] ?? { \addToHead }
						),
						parent: ProtoEvent(~fxProto ?? { \singleSynthPlayer }).v.parent.copy
					),
					~fxPatEv[\quant]
				);
				~lock.stopThings = [~fxPatEv[\streamPlayer]];
			} {
				~sendNode = Synth("mixers/Send" ++ ~numCh,
					[busin: ~lock.bus, busout: chan.inbus, level: 1],
					chan.effectgroup
				);
				~lock.killNodes = ~sendNode;
			};
		}
	))) => ProtoEvent(\polySynthFxPatLock);
	
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

	topEnvironment[\sampleDir] = thisProcess.nowExecutingPath.dirname.dirname +/+ "samples";

};

true   // avoid stupid "found nil" warning