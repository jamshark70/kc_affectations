// everybody needs these...

// work around crappy Cocoa limitation - I do not miss SC.app AT ALL
var screenBounds = Window.screenBounds;

s.latency = 0.075;

s.waitForBoot {

	~master ?? { ~master = MixerChannel(\master, s, 2, 2, level: 1) };

	// don't want reverb on netbook
	if(screenBounds.height > 600) {
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
			~lcrvb.doWhenPlaying {
				NotificationCenter.notify(\lcrvb, \lcrvbexists);
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

	Library.put(\rvbs, (
		glrvbmc: topEnvironment[\glrvbmc],
		lcrvbmc: topEnvironment[\lcrvbmc],
		master: topEnvironment[\master]
	));

	topEnvironment[\rvbEvent] = ().proto_((
		glrvbout: ~glrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels },
		lcrvbout: ~lcrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels },
		distFar: 20
	));

};


if(Library.at(\affectations, \commonLoaded) != true) {

	{	|vpi|
		~ctlGuiKeys.do { |key| key.envirGet => VP(vpi) };
	} => Func(\bpUseGui);

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
		~isPattern = true;
		~asStream = { |inval|
			r { ~embedInStream.(inval) }
		};
	} => PR(\rewriter);

	// Pxrand is not quite what I want: not (n) embeds, but (n) durations per weight
	Proto {
		~prep = { |list, weights, repeats = 1|
			~list = list;
			~weights = weights;
			~repeats = repeats;
			currentEnvironment
		};
		~embedInStream = { |inval|
			var item, itemStream,
			weightStream = ~weights.asStream,
			currentWeights,
			index = weightStream.next(inval).windex,
			totalweight, rnd, runningsum;
	
			block { |break|
				~repeats.value(inval).do({ |i|
					item = ~list.at(index);
					if(item.isNil) { break.(inval) };
					// Pn is redundant for patterns
					// but necessary for numbers or other non-streams
					itemStream = Pn(item, 1).asStream;
					// don't need 'item' var anymore, can reuse for outputs
					while { (item = itemStream.next(inval)).notNil } {
						inval = item.yield;
						currentWeights = weightStream.next(inval);
						if(currentWeights.isNil) { break.(inval) };
					};
	
					totalweight = 1.0 - currentWeights[index];
					rnd = totalweight.rand;
					runningsum = 0;
					while {
						index = (index + 1) % currentWeights.size;
						runningsum = runningsum + currentWeights[index];
						runningsum < rnd
					};
				});
				inval
			};
		};
		~asStream = { Routine({ |inval| ~embedInStream.(inval) }) };
		~canEmbed = true;
		~isPattern = true;
	} => PR(\pwxrandn);

	{ |name, ugenFunc, metadata, rates, lagDistance(false)|
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
		}, if(lagDistance) { #[0.1] } { nil }, metadata: metadata);  // 0.1 == lag on 'distance'
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
			~lock ?? { ~lock = PR(~lockKey).copy.prep((
				numCh: ~numCh, server: ~chan.tryPerform(\server) ?? { Server.default }, rate: ~busRate ? \audio
			)) };
			~bus = ~lock.bus;
			~target = ~chan.synthgroup;
			~chan = nil;
			~superPlay.();

			if(~node.notNil and: { (~node.tryPerform(\isEmpty) ? false).not }) {
				~playExtraProcess.(chan);
				~node.do { |node| ~lock.addNode(node) };
			} {
				if(~autoFreeIfNoNode != false) { ~lock.freeStuff };
			};
			if(~tempo.isNumber) { thisThread.clock.tempo = ~tempo }
		},
		playExtraProcess: { |chan|
			if(~lpcEv.size > 0) {
				~lpcEv.putAll((
					bus: chan.inbus,
					target: chan.effectgroup,
					// chan: nil,
					inbus: ~lock.bus,
					collIndex: ~collIndex,
						// effectgroup might have post-lpc effect nodes (chorus etc.)
						// so put lpc's up front
					addAction: ~lpcEv[\addAction] ?? { \addToHead }
				))
				.put(\chan, nil)  // can't set to nil in putAll
				// cuz parent: don't work in putAll #@$*$&*$&@#312
				.parent_(ProtoEvent(~lpcProto ?? { \singleSynthPlayer }).v.parent)
 				.play;
				if(~lpcEv[\killNode] == true) {
					~lpcEv[\node].do { |node|
						if((~lock.killNodes.tryPerform(\includes, node) ? false).not) {
							~lock.killNodes = ~lock.killNodes.add(node)
						};
					};
				} {
					~lpcEv[\node].do { |node| ~lock.addNode(node) };
				}
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
		play: {
			var	chan = ~chan;
			~numCh ?? { ~numCh = ~chan.inChannels };
			~lock ?? { ~lock = PR(~lockKey).copy.prep((
				numCh: ~numCh, server: ~chan.tryPerform(\server) ?? { Server.default }, rate: ~busRate ? \control
			)) };
			// ~bus = ~lock.bus;
			// ~target = ~chan.synthgroup;
			// ~chan = nil;
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
					bus: ~lock.bus,
					target: if(chan.notNil) { chan.synthgroup } { ~target },
					// inbus: ~lock.bus,
					collIndex: ~collIndex,
						// effectgroup might have post-lpc effect nodes (chorus etc.)
						// so put lpc's up front
					addAction: ~lpcEv[\addAction] ?? { \addToHead }
				))
				.put(\chan, nil)  // can't set to nil in putAll
				// cuz parent: don't work in putAll #@$*$&*$&@#312
				.parent_(ProtoEvent(~lpcProto ?? { \singleSynthPlayer }).v.parent)
				.play;
				// ~lpcEv[\node].do { |node| ~lock.addNode(node) };
				~lock.killNodes = ~lpcEv[\node];
			};
		}
	))) => ProtoEvent(\polySynthKrBusLock);

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
		~def = \xy1;
		~synthArgs = [];
		~prep = {
			~group = Group.before(s.asTarget);

			SynthDef("xy1", { |distNear = 5, distFar = 20, mul = 0.25, send = 0, out = 0,
				lowDur = 0.25, hiDur = 0.9, lowRDur = 0.6, hiRDur = 2.0|
				var	theta, r, x, y;
				theta = DemandEnvGen.kr(
					Dwhite(-2pi, 2pi, inf),
					Dwhite(lowDur, hiDur, inf),
					Env.shapeNumber(\sine)
				);
				r = DemandEnvGen.kr(
					Dwhite(0.1, 1.0, inf),
					Dwhite(0.0, 1.0, inf).linexp(0, 1, lowRDur, hiRDur),
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
					Synth(\xy1, [mul: 1, send: 0, out: xybus] ++ ~synthArgs, ~group);
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
			// if(~clients.includes(name)) {
			// 	"% is already used by %.".format(~collIndex.asCompileString, name.asCompileString).warn
			// } {
				~clients.add(name);
				~makeSynths.();
			// };
		};

		~notUsedBy = { |name|
			~clients.remove(name);
			if(~clients.isEmpty) {
				~removeSynths.()
			}
		};
	} => PR(\trajectories);

	topEnvironment[\sampleDir] = thisProcess.nowExecutingPath.dirname.dirname +/+ "samples";
	if(MBM.exists(0).not) { MIDIBufManager(nil, nil) => MBM.prNew(0) };



// events transmit data to Lorne

Event.addEventType(\dataWrap, {
	~type = ~evType;
	~play.value;  // do real action
	\eventDataToViz.eval;
});


Library.put(\defaultVizKeys, [
	{ ~collIndex.hash },
	\soundID,
	// general case - save for later
	// {	var	server;
	// 	~latency ?? {
	// 		if(~server.size > 0) {
	// 			server = ~server.first;
	// 		} {
	// 			server = ~server ?? { Server.default };
	// 		};
	// 		server.latency
	// 	}
	// },
	s.latency,  // but I know this won't change, so save some time
	{ ~freq.asArray[0].tryPerform(\explin, 20, 20000, -1.0, 1.0) },
	{ ~sustain ?? { ~time } },
	\amp,
	\pan,
	\distance
]);

Library.put(\defaultVoicerVizKeys, Library.at(\defaultVizKeys).copy.putEach(
	#[2, 3, 4, 5],
	[
		// { ~latency ?? { ~voicer.target.server.latency } },
		s.latency,
		{ ~newFreq.asArray[0].tryPerform(\explin, 20, 20000, -1.0, 1.0) },
		{ ~length },
		\gate
	]
));

{	var	path, parms, val, addr, server, mapped, getmapped = false;
	if(~dataToViz ? true and: {
		(addr = ~vizAddr ?? { Library.at(\vizAddr) }).notNil
	}) {
		~vizKeys ?? { ~vizKeys = Library.at(\defaultVizKeys) };
		// don't need string parm names
		// array: [value | lookup symbol | func]
		// Lorne should interpret -inf as 'not populated'
		parms = ~vizKeys.collect { |item|
			val = (if(item.isSymbol) { item.envirGet }
				{ item.value }) ? -inf;
			if(val.size > 0) { val[0] } { val };  // NO ARRAYS
		};
		mapped = parms.collect { |val|
			// only symbols will be converted to strings
			if(val.isSymbol and: { (val = val.asString)[0].toLower == $c }) {
				getmapped = true;
				val
			} // { nil }
		};
		if(parms.notNil) {
			fork {
				var cond, getbuses;
				if(getmapped) {
					cond = Condition.new;
					getbuses = mapped.select(_.notNil).collect { |str| str[1..].asInteger };
					OSCresponderNode(s.addr, '/c_set', { |time, resp, msg|
						var j = 2;
						if(msg[1, 3..] == getbuses) {
							mapped.do { |map, i|
								if(map.notNil) { parms[i] = msg[j]; j = j + 2 };
							};
							resp.remove;
							cond.unhang;
						};
					}).add;
					s.sendMsg(\c_get, *getbuses);
					cond.hang;
				};

				path = (~vizPath.collect(_.valueEnvir) ?? { #[note] }).asArray;
				if(path.size > 1 and: { path[1].isInteger.not}) {
					path[1] = path[1].hash  // Lorne wants numbers
				};
				addr.sendBundle(0, (path ++ parms).asOSCArgArray);
				// ((~vizPath.collect(_.valueEnvir) ? #[note]).asArray ++ parms).asOSCArgArray.postln;
			};
		};
	};
} => Func(\eventDataToViz);

// copy-and-paste for voicer events: "avoid early optimization!"
{	var	path, parms, val, addr, server, mapped, getmapped = false;
	if(~dataToViz ? true and: {
		(addr = ~vizAddr ?? { Library.at(\vizAddr) }).notNil
	}) {
		~vizKeys ?? { ~vizKeys = Library.at(\defaultVoicerVizKeys) };
		// don't need string parm names
		// array: [value | lookup symbol | func]
		// Lorne should interpret -inf as 'not populated'
		parms = ~vizKeys.collect { |item|
			val = (
				if(item.isSymbol) {
					// a symbolic item is either in the event as a key,
					// or it could be a voicer global control
					// if it isn't a GC, the inner func will be nil.value --> nil
					// which then falls back to -inf below
					item.envirGet ?? {
						~voicer.globalControls[item].value
					}
				} { item.value }
			) ? -inf;
			if(val.size > 0) { val[0] } { val };  // NO ARRAYS
		};
		mapped = parms.collect { |val|
			// only symbols will be converted to strings
			if(val.isSymbol and: { (val = val.asString)[0].toLower == $c }) {
				getmapped = true;
				val
			} // { nil }
		};
		if(parms.notNil) {
			fork {
				var cond, getbuses;
				if(getmapped) {
					cond = Condition.new;
					getbuses = mapped.select(_.notNil).collect { |str| str[1..].asInteger };
					OSCresponderNode(s.addr, '/c_set', { |time, resp, msg|
						var j = 2;
						if(msg[1, 3..] == getbuses) {
							mapped.do { |map, i|
								if(map.notNil) { parms[i] = msg[j]; j = j + 2 };
							};
							resp.remove;
							cond.unhang;
						};
					}).add;
					s.sendMsg(\c_get, *getbuses);
					cond.hang;
				};

				path = (~vizPath.collect(_.valueEnvir) ?? { #[note] }).asArray;
				if(path.size > 1 and: { path[1].isInteger.not}) {
					path[1] = path[1].hash  // Lorne wants numbers
				};
				addr.sendBundle(0, (path ++ parms).asOSCArgArray);
				// ((~vizPath.collect(_.valueEnvir) ? #[note]).asArray ++ parms).asOSCArgArray.postln;
			};
		};
	};
} => Func(\voicerDataToViz);


// wrapper for custom events
{	|key, newKey|
	var	protoEv;
	if(ProtoEvent.exists(key)) {
		protoEv = ProtoEvent(key);
		if(protoEv[\originalPlayFunction].isNil) {
			protoEv = protoEv.copy;
			protoEv[\originalPlayFunction] = protoEv[\play];
			protoEv[\play] = { |server|
				~originalPlayFunction.(server);
				\eventDataToViz.eval;
			};
			newKey ?? { newKey = (key ++ "Data").asSymbol };
			protoEv => ProtoEvent(newKey);
		} {
			"ProtoEvent(%) is already wrapped - don't rewrap.".format(key.asCompileString).warn;
			nil
		}
	} {
		"ProtoEvent(%) doesn't exist, can't wrap.".format(key.asCompileString).warn;
		nil
	};
} => Func(\dataWrapProtoEvent);

#[default, polySynthPlayNotify, polySynthPlayer, polySynthTrigger, singleSynthPlayNotify, singleSynthPlayer, singleSynthTrigger].do { |key|
	\dataWrapProtoEvent.eval(key);
};


ProtoEvent(\voicerNote).copy.putAll((
	originalPlayFunction: ProtoEvent(\voicerNote).v[\play],
	play: { |server|
		~originalPlayFunction.(server);
		\voicerDataToViz.eval;
	}
)) => ProtoEvent(\voicerNoteData);

// don't want to go all the way to the top to define these temp vars
{
	var k = ProtoEvent.keys, evkeys;
	ProtoEvent.composite(
		(evkeys =
			ProtoEvent(\monoSupport).v.parent.keys.asArray
			.select(k.includes(_))
			.collect { |key| (key ++ "Data").asSymbol }
		).swap(0, evkeys.indexOf(\singleSynthTriggerData))
	) => ProtoEvent(\monoSupportData);
}.value;


// triggers from remote c_set messages

Proto {
	~event = (eventKey: \dummy);
	~alwaysReset = true;
	~busIndex = 4095;
	~message = \trigbus;
	~replyID = 1;
	~prep = {
		~bus = SharedBus(\control, ~busIndex, 1, s);
		SynthDef(~message.asSymbol, { |bus, replyID = 1|
			var	trig = InTrig.kr(~busIndex, 1);
			SendReply.kr(trig, ~message, trig, replyID);
		}).add;
		~userprep.();
	};
	~freeCleanup = { ~userfree.() };
	~preparePlay = {
		~node ?? { ~node = Synth(~message, [bus: ~bus, replyID: ~reply]) };
		~userPreparePlay.(~node);
	};
	~stopCleanup = {
		~userStopCleanup.(~node);
		~node !? { ~node.free; ~node = nil };
	};

	~asPattern = {
		Pbind(\delta, 1)
	};
} => PR(\busTrig);

{ |source, class, key, adverb, parms|
	if(class.exists(key).not) {
		source.chuck(class.new(key), adverb, parms);
	};
} => Func(\chuckIf);

// \chuckIf.eval(PR(\armsSkidMel), BP, \am, nil, (
// 	glrvbmc: ~glrvbmc,
// 	lcrvbmc: ~lcrvbmc,
// 	master: ~master
// ));

~trigParms = (
	// sbounds: screenBounds,
	// play: \dummy,
	setDoneSignal: {
		~doneSignal = OSCresponderNode(s.addr, '/event', e { |t, r, m|
			r.remove;
			~stop.();
		}).add;
		// defer(e {
		// 	~window = Window("GO", Rect(~sbounds.right - 120, ~sbounds.height - 150, 120, 60));
		// 	Button(~window, ~window.view.bounds.insetBy(2, 2))
		// 		.states_([["event"]])
		// 		.action_(e { ~stop.() });
		// 	~window.front.userCanClose_(false);
		// });
		BP(\segTrig).eventActive(e { ~stop.() });
	},
	clearDoneSignal: {
		defer(e {
			// ~window.close;
			~doneSignal.remove;
			BP(\segTrig).eventActive(nil);
		})
	},
	func: \dummy
);

{	|item|
	// var	sbounds = screenBounds;
	~trigResp = OSCresponderNode(s.addr, '/segment', e { |t, r, m|
		var	inSeg = m[3], i;
		case { inSeg == item[\id] or: { inSeg == 99999 } } {
			r.remove;
			// stop section, section sequencer will advance
			// false = not a manual stop, don't kill non-sync commands
			~stop.(nil, ~isLastSection ? false);
		}
		{ inSeg > item[\id] } {
			if((i = topEnvironment[\seq].sections.detectIndex { |sect|
				sect.segID == inSeg
			}).notNil) {
				"skipping to %\n".postf(inSeg);
				r.remove;
				topEnvironment[\seq].gotoSection(i);  // this stops cur sect
			} {
				"Segment % doesn't exist; still waiting for segment %\n"
				.postf(inSeg, item[\id])
			};
		}
		{ "Trigger segment % ignored; waiting for segment %\n"
			.postf(inSeg, item[\id])
		};
	}).add;
	// defer(e {
	// 	~window = Window("move on",
	// 		Rect(sbounds.right - 120, sbounds.height - 300, 120, 60));
	// 	Button(~window, ~window.view.bounds.insetBy(2, 2))
	// 		.states_([["to seg %".format(item[\id])]])
	// 		.action_(e { ~stop.(nil, ~isLastSection ? false) });
	// 	~window.front.userCanClose_(false)
	// 		.onClose_(e { ~window = nil });
	// });
	BP(\segTrig).segActive(e { ~stop.(nil, ~isLastSection ? false) }, item[\id]);
} => Func(\nextThingTrig);

{	~trigResp.remove;
	// ~window !? { defer(e { ~window.close }) };
	BP(\segTrig).segActive(nil);
	~currentTriggerItem = nil;  // what a horrendous, god-awful hack
	~cleanupTrigger.(nil, (manualStop: ~isLastSection ? false));
} => Func(\clearNextTrig);

PR(\tlSection).clone {
	~stop = { |notifyTime, manualStop = true|
		var	stopParms;
		if(~isRunning.()) {
			~status = \idle;
			stopParms = (manualStop: manualStop ? true); //.debug("stop parms");
			~currentIterator.stop(stopParms);
			if(manualStop) { ~savedCmds.do(_.stop(stopParms)) };
			~done.(manualStop);
			~clearDoneSignal.();
			~clock.schedAbs((notifyTime ?? { ~clock.beats }), e {
				currentEnvironment.changed(\done, ~savedCmds);
			});
			if(thisThread === ~seqPlayer) {
				nil.yield
			} {
				~seqPlayer.stop;
			};
		}; // { manualStop.debug("stop called but section not running - manualStop is") };
	};
	~done = { |manualStop| ~cleanupTrigger.(nil, (manualStop: manualStop)) };
	~cleanupTrigger = { |triggerID, parms|
		if(~currentTriggerItem.notNil) {
			~currentIterator.stop(parms);
			~currentTriggerItem[\clear].(~currentTriggerItem, triggerID, parms);
			~currentTriggerItem = nil;
		};
	};
	~makeSeqPlayer = {
//		~seqStream ?? { ~seqStream = ~seqPattern.().asStream };
			// should always reset: start from beginning of section every time you play
		~seqStream = ~seqPattern.().asStream;
			// ~condition is used elsewhere, not here, but needs to exist
		~condition ?? { ~condition = Condition.new };
		Routine({ |inval|
			var	item, delta;
			loop {
				item = ~seqStream.next(~seqEventProto);
				if(item.notNil) {
					delta = ~playItem.(item);
					delta.yield;	// playItem returns time to wait
				} {
					// always stop last section as if manually stopped
					// (forcing all children to stop)
					~stop.(nil, ~isLastSection ? false)
				};
			}
		})
	};
} => PR(\tlsAff);

PR(\sectionSequencer).clone({
	~startLoadingAt = 0;
	~gotoSection = { |section|
		var	toStop = ~sections[~currentSection];
// [~currentSection, section].debug(">> gotoSection (current, next)");
		if(~isRunning.()) {
			// "loading resources (playing)".debug;
			~loadResources.(section, ~currentSection);
			~nextSectionToPlay = section;
			toStop.stop(nil, false);  // will advance by ~update
		} {
			// "loading resources (not playing)".debug;
			~currentSection = section;
			~loadResources.(section/*, ~currentSection*/);
		};
		currentEnvironment.changed(\section, section);
// [~currentSection, section].debug("<< gotoSection (current, next)");
	};
	~loadResources = { |section, startAt|
		if(startAt.isNil or: { startAt < ~currentSection }) {
			if((startAt = ~startLoadingAt.detectIndex { |item| item > ~currentSection }).notNil) {
				startAt = ~startLoadingAt[max(0, startAt - 1)];
			} {
				startAt = ~startLoadingAt.last;
			};
			// startAt.debug("loadResources auto-chose startAt");
		};

		// section.debug(">> loadResources");
		(startAt .. section).do({ |sect|
			if((~sections[sect].tryPerform(\isLoaded) ? true).not
				/*.debug("section % needs to load".format(sect))*/) {
					~sections[sect].prInitProc;
				};
		});
		// debug("<< loadResources");
	};
	~countOffAndGo = {
		var	clock = ~clock.value;
		~sections.last.isLastSection = true;
		thisThread.clock.sched(0, ~sectionRoutine = Routine({
			~status = \playing;
			while { ~isRunning.() and: { ~currentSection < ~sections.size } } {
				/*~savedCmds.*/debug("playing section %".format(~sections[~currentSection].name));
				~sections[~currentSection].play(~savedCmds);
				//"section sequencer: set savedCmds to nil".debug;
				~savedCmds = nil;
				// ~update method below will catch notifications
				~sections[~currentSection].addDependant(currentEnvironment);
				~loadResources.(~currentSection + 1);
				// note, this doesn't force-stop the routine
				// just pauses it
				nil.yield;
			};
			~stop.(true);	// stop last section
		}));
	};
	// ~superStop = ~stop;
	// ~stop = { |lastSection(false)|
	// 	lastSection.debug(">> ~seq stop (last sect)");
	// 	~superStop.(lastSection);
	// 	~nextSectionToPlay = nil;
	// 	(~currentSection+1).debug("stop is calling loadResources for");
	// 	~loadResources.(~currentSection+1);
	// 	lastSection.debug("<< ~seq stop (last sect)");
	// };

	// yes, I am copying ANOTHER method wholesale...
	// ~sectionRoutine.stop at the end prevents clearing ~nextSection...
	// and loading resources. I wish I had expletives enough for this.
	~stop = { |lastSection = false|
// lastSection.debug(">> sectionSequencer:stop");
		if(~status == \countingOff) {
			~status = \idle;
			~countOffRoutine.stop;
			currentEnvironment.changed(\stop);
			currentEnvironment.changed(\countoff, nil);
		} {
			~sections[~currentSection].stop/*(nil, manualStop)*/;
			~sections[~currentSection].removeDependant(currentEnvironment);
				// must force manual stop for last section at end of piece
				// but this didn't work
			if(lastSection ? false) { ~sections.last.stop(nil, true) };
			~status = \idle;
			~currentSection = ~startingSection;
			currentEnvironment.changed(\stop);
			currentEnvironment.changed(\section, ~currentSection);
			~savedCmds = nil;
			~nextSectionToPlay = nil;
			// (~currentSection+1).debug("stop is calling loadResources for");
			~loadResources.(~currentSection+1);
			~sectionRoutine.stop;
			~sectionRoutine = nil;
		};
// "<< sectionSequencer:stop".debug;
	};
	~update = { |obj, what, args|
		var	section;
		// [obj, what, args].debug("section sequencer got update");
		if(obj === ~sections[~currentSection]) {
			switch(what)
			{ \done } {
				// args.debug("section sequencer update - savedCmds");
				~savedCmds = args;
				obj.removeDependant(currentEnvironment);
				if(~isRunning.()) {
					~currentSection = ~nextSectionToPlay ?? { ~currentSection + 1 };
					~nextSectionToPlay = nil;
					// ~currentSection.debug("section done, moving to");
					currentEnvironment.changed(\section, ~currentSection);
					~clock.value.sched(0, ~sectionRoutine);
				};
			}
			{ \initNext } {
				if(~sections[~currentSection + 1].notNil) {
					~sections[~currentSection + 1].prInitProc;
				}
			}
			{ \unload } {
				args.tryPerform(\at, \name).asArray.do { |sectName|
					if((section = ~sections.detect { |sct| sct.name == sectName }).notNil) {
						section.prUnload;
					}
				};
			}
		};
	};
}) => PR(\affSectSeq);


// and, another pathetically stupid bug in my library that I have to fix
// here to avoid an svn update for Lorne

PR(\gcAutoSynthCmd).fire = { |parms|
	if(~gc.isFunction) { ~gc = ~gc.value };
	if(~gc.notNil) {
		~server = ~gc.server;
		~target = ~target ?? { ~server.asTarget };
		// NO, DON'T OVERWRITE THE DAMN OUTNAME IF IT'S SUPPLIED!!!
		~outName ?? { ~outName = parms.tryPerform(\at, \outName) ? \out };
		~outName.envirPut(~gc.index);
		~gc.stopAuto.watch;	// should replace existing automation
		~superFire.(parms);
		~gc.autoSynth = ~node;
	};
};

// definition in my Instr lib is wrong; this is easier to transport to others
Instr([\busfx, \chorus2band], { arg bus, numChan, predelay, speed, depth,
		ph_diff, /*width,*/ crossover, xfade;
	var in, lo, hi;
	in = In.ar(bus, 1);
	lo = LPF.ar(in, crossover);
	hi = in - lo; // HPF.ar(in, crossover);
	hi = Array.fill(numChan, { |i|
		predelay = predelay + depth;
		DelayC.ar(hi, 0.5, SinOsc.kr(speed, ph_diff * i,
		depth, predelay));
	}).scramble;
	lo = lo + hi;
	XFade2.ar(in, lo, xfade * 2 - 1)
}, [\audiobus, StaticSpec(1, 8, \lin, 1, 1), #[0.0001, 0.2, \exponential, 0, 0.001], #[0.001, 10, \exponential], #[0.0001, 0.25, \exponential], #[0, 2pi], /*#[0, 1],*/ \freq, #[0, 1]]);

PR(\abstractProcess).clone {
	~alwaysReset = true;
	~autoPlay = true;
	~event = (eventKey: \singleSynthPlayNotify);
	~dk = \di;
	~latest = 0 ! 28;
	~prep = {
		if(BP.exists(~dk).not) {
			"Load BP(%) first.".format(~dk.asCompileString).warn
		} {
			#[bus, trigbus, recvBus, numCh, outCh].do { |key| key.envirPut(BP(~dk)[key]) };
		};

		~def = ~makeDef.();
		~userprep.();

		BP(~dk).addDependant(currentEnvironment);
	};
	~freeCleanup = {
		BP(~dk).removeDependant(currentEnvironment);
		~userfree.();
	};
	~update = { |obj, what, more|
		case
		{ obj.tryPerform(\collIndex) == ~dk } {
			case { ~autoPlay and: { what == \play } } { BP(~collIndex).play }
				{ more == \stopped } { BP(~collIndex).stop }
		}
	};

	~makeDef = {
		SynthDef(("datafetcher" ++ ~outCh).asSymbol, { |bus, useTrigBus, recvBus, trigbus,
			replyID|
			var	sig = In.kr(bus, ~outCh),
				trig = Select.kr(useTrigBus, [
					InTrig.kr(recvBus, 1),
					In.kr(trigbus, 1)
				]) > 0;  // force trig to be exactly 0 or 1
			SendReply.kr(trig, '/datafetch', sig, replyID);
		}).add
	};
	~makeResponder = { |node|
		var	self = currentEnvironment;
		OSCpathResponder(s.addr, ['/datafetch', (node ?? { ~node }).nodeID], { |time, resp, msg|
			self[\latest] = msg[3..];
			NotificationCenter.notify(self[\collIndex], \data, self[\latest]);
		}).add;
	};

	// ~preparePlay = {
	// };
	~stopCleanup = {
		~node !? {
			// + 0.5 - try to prevent race condition where synth is freed before creation
			~node.server.makeBundle(~node.server.latency + 0.5, { ~node.free });
			~node = nil
		};
		~resp.do(_.remove); ~resp = nil;
	};
	~recvEventNotify = { |node|
		~node = node;
		~resp = ~makeResponder.(node);
	};
	~asPattern = {
		Pseq([
			(instrument: ~def.name,
				bus: ~bus, useTrigBus: BP(~dk).playTestFile.binaryValue, recvBus: ~recvBus,
				trigbus: ~trigbus, replyID: ~replyID ? 0, addAction: \addToTail,
				delta: 2
			).putAll(~synthEventParms.()),
			Pn((instrument: \rest, delta: 2), inf)
		])
	};
	~synthEventParms = ();
} => PR(\dataReader);


(thisProcess.nowExecutingPath.dirname +/+ "transports.scd").loadPath;

};

true   // avoid stupid "found nil" warning