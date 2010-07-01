

SynthDef(\simpleLPCfxPan, { |inbus, outbus, lpcbuf, voxdur = 1, start, end = 1, time = 1, amp = 1, freq = 440, noiseMul = 1, hpf = 1600, xfscale = 0.25, lpf = 15000, pan = 0, attack = 0.05, decay = 0.05|
	var	src = In.ar(inbus, 1),
		// note, ar because LPCVals.ar with .kr pos input is broken
		pos = Line.ar(start, end, time) / voxdur,
 		lpcv = LPCVals.ar(lpcbuf, pos),
 		noise = HPF.ar(WhiteNoise.ar(noiseMul), hpf),
		sig = LPCSynth.ar(lpcbuf, XFade2.ar(src, noise, (xfscale * lpcv[2]).madd(2, -1)), pos, amp * lpcv[1]),
		eg = EnvGen.kr(Env.linen(attack, time - attack - decay, decay), doneAction: 2);
	sig = LPF.ar(sig, lpf);
	sig = LeakDC.ar(sig);
	Out.ar(outbus, Pan2.ar(Limiter.ar(sig * eg), pan));
}).add;



// bus lock object - release bus when all the locking objects are gone
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




// harmonic series drones
SynthDef(\partial1bgated, { |outbus, freq = 440, amp = 1,
	egRate = 1, egRateMul = 1, egSusPt = 0.5, egBuf,
	panWidth = 0, panCtr = 0, gate = 1|
	var	sig = FSinOsc.ar(freq, 0, amp),
		swRate = egRate * egRateMul,
		posTest = Select.kr(Impulse.kr(0), [LocalIn.kr(1), 0]),
		notReachedSusPt = BinaryOpUGen('==', sign(egSusPt - posTest), swRate.sign),
		egpos = Sweep.kr(1, swRate * (((gate <= 0) + notReachedSusPt) > 0)),
		eg = BufRd.kr(1, egBuf, egpos * BufFrames.ir(egBuf), loop: 0, interpolation: 2),
		pan = LFNoise1.kr(swRate, panWidth, panCtr).clip(-1.0, 1.0);
	LocalOut.kr(egpos);
	FreeSelf.kr(egpos >= 1.0);
	OffsetOut.ar(outbus, Pan2.ar(sig * eg, pan));
}).add;


(keys: #[master],
make: { |name|
	var	master = ~master;	// to get master into the Proto environment
	BP(name).free;
	Proto {
		~fund = 32.midicps;
		~event = (eventKey: \singleSynthPlayNotify);
		~quant = NilTimeSpec.new;
		~initTempo = 0.1;
		~tempoSpec = #[0.01, 10, \exp].asSpec;
		~alwaysReset = true;

		~prep = {
			~clock = TempoClock(~initTempo, queueSize: 2048).permanent_(true);
			~tempoCtl = GenericGlobalControl(\tempo, nil, ~initTempo, ~tempoSpec);
			~upd = Updater(~tempoCtl, e { |obj, msg|
				if(msg[\what] == \value) {
					~clock.tempo = obj.value
				};
			});

			// how much of a note's duration to hold in the middle
			~holdPctCtl = GenericGlobalControl(\holdPct, nil, 0);

			~chan = MixerChannel(~collIndex, s, 2, 2, outbus: master);
			~chan2 = MixerChannel(~collIndex ++ "2", s, 2, 2, outbus: master, completionFunc: { |chan|
				// adding harmonics increases volume a lot
				// this reduces the amp variation from about 20dB to about 6
				chan.playfx(Instr("busfx.companderd"), [0, 2, 0.03, 1.0, 0.10660504994928, 0.0022888750750465, 0.1821720077621, 7.2629183877784, 0.005]);
			});
			~egbuf = Buffer.alloc(s, 1024, 1, { |buf|
				buf.setnMsg(0, Env(#[0, 1, 0], #[0.5, 0.5], \sine).discretize(1024))
			});
		};

		~asPattern = {
			Pseq([
				Pfuncn {
					~goTime = thisThread.beats;
					0
				},
				Pbind(
					\instrument, \partial1bgated,
					\freq, ~fund,
					\egRate, ~tempoCtl.asMap,
					\egRateMul, (1 - ~holdPctCtl.asPattern).max(0.001).reciprocal,
					\delta, 1,
					\sustain, ((~holdPctCtl.asPattern - 1) * 0.5 + 1) * Pkey(\delta),
					\amp, 1,
					\egBuf, ~egbuf,
					\chan, ~chan
				)
			])
		};

		~useGui = { |vpi| ~tempoCtl => VP(vpi); ~holdPctCtl => VP(vpi) };
		
		~freeCleanup = {
			~upd.remove;
			~clock.stop;
			[~tempoCtl, ~holdPctCtl, ~chan, ~egbuf].free;
		}
	} => BP(name);
},
type: \bp) => Fact(\mstClock);

PR(\abstractProcess).clone {
	~event = (eventKey: \singleSynthPlayNotify);
	~cl = \mstClock;
	~alwaysReset = true;
	~quant = NilTimeSpec.new;

	~low = 2;
	~high = 32;
	~rat = Pwhile1({ |in, item| item <= ~high }, Pseries(~low, 1, inf))
		++ (Pexprand(Pfunc { ~low }, Pfunc { ~high }, inf)
			.round(1).reject { |x| ~activeRatios.includes(x) });
	~numEv = Pfunc { |ratio| ratio } * Pwhite(1.5, 4) * Pseries(1, 0.02, inf);

	~prep = {
		~clImport.();
		~procInit.();

		~makeGResponder.();
		currentEnvironment
	};

	~procInit = {
		~activeRatios = Set.new;
		~fullSet = (~low .. ~high).asFloat.as(Set);
	};

	~clImportKeys = #[clock, tempoCtl, fund, chan2, egbuf, holdPctCtl];
	~clImport = {
		~clImportKeys.do { |key|
			key.envirPut(BP(~cl)[key])
		};
		// HACK
		~chan = ~chan2;
	};

	~freeCleanup = {
		~removeGResponder.();
		~procFree.();
	};

	~stopCleanup = {
		~activeRatios = Set.new;
	};

	~low_ = { |newLow = 2|
		var	minI = ~fullSet.minItem;
		if(newLow < minI) {	// extending low range lower
			(newLow .. minI - 1).do { |i| ~fullSet.add(i.asFloat) }
		} {
			if(newLow > minI) {
				(minI .. newLow - 1).do { |i| ~fullSet.remove(i.asFloat) }
			}
		};
		~low = newLow;
		currentEnvironment
	};

	~high_ = { |newHigh = 2|
		var	maxI = ~fullSet.maxItem;
		if(newHigh < maxI) {
			(newHigh + 1 .. maxI).do { |i| ~fullSet.remove(i.asFloat) }
		} {
			if(newHigh > maxI) {
				(maxI + 1 .. newHigh).do { |i| ~fullSet.add(i.asFloat) }
			}
		};
		~high = newHigh;
		currentEnvironment
	};

	~asPattern = {
		~makeStreamForKey.(\rat);
		~makeStreamForKey.(\numEv);
		Pspawner({ |sp|
			~spawner = sp;
			~spawnerStarted = thisThread.beats;	// for scheduling
			
			// busywait to reduce scheduling latency for new streams
			sp.par(Pbind(
				\instrument, \rest,
				\delta, 0.1 * Ptempo()
			));
			~initStreams.(sp);
		});
	};

	~oneStream = { |ratio = 1, repeats = 1, pbindf|
		var	self = currentEnvironment,
			result = Pbind(
				\instrument, \partial1bgated,
				\ratio, ratio,
				\freq, BPStream(\fund) * ratio,
				\egRate, ~tempoCtl.asMap,
				\egRateMul, ratio,
				\delta, ratio.reciprocal,
				\sustain, Pkey(\delta) * 0.5,
				\egBuf, ~egbuf,
				\chan, ~chan
			);
		if(pbindf.notNil) {
			result = Pbindf(result, *pbindf)
		};
		if(repeats.notNil) { result = Pfin(repeats, result) };
		// note, this doesn't call endhook if the process is stopped manually
		// (you should supply stopCleanup to handle it for that case)
		result = CleanupStream(result.asStream, e {
			~streamEndHook.(result, ratio);
		});
	};

	// this can be called by any gesture-trigger responder
	~addAStream = {
		var	ratio, numEv, test, stream;
		// 'any' test is slightly slower than != but !='s size check is not safe
		if(~isPlaying and: { ~fullSet.any { |item| ~activeRatios.includes(item).not } }) {
			ratio = ~ratStream.next;
			stream = ~spawner.par(
				~oneStream.(ratio, numEv = ~numEvStream.next(ratio).asInteger,
					[	amp: ~makeAmpPattern.(numEv),
						panCtr: rrand(ratio / ~high - 0.4, ratio / ~high) * #[-1, 1].choose,
						panWidth: (1 - Pkey(\panCtr).abs) * (ratio / ~high)
					]),
				0.1);
			~streamHook.(stream, ratio);
		};
	};

	~makeAmpPattern = { |numEv| Pgeom.fromEndpoints(1, rrand(0.02, 0.18), numEv) };

	~streamHook = { |stream, ratio|
		~activeRatios.add(ratio);
	};
	~streamEndHook = { |stream, ratio|
		~activeRatios.remove(ratio);
		if(~activeRatios.isEmpty) { BP(~collIndex).changed(\allChildrenStopped) };
	};

	~makeGResponder = {
		~window = ResizeFlowWindow(~collIndex, Rect.aboutPoint(Window.screenBounds.center, 75, 25));
		~btn = Button(~window, Rect(0, 0, 140, 40))
			.states_([["GO"], ["full", Color.black, Color.new255(255, 200, 200)]])
			.font_(Font.default.copy.size_(28))
			.action_(e { |view|
				if(~addAStream.().isNil) {
					(e { view.value = 0 }).defer(0.5);
				} {
					view.value = 0;
				};
			});
		~window.recursiveResize.front;
	};

	~removeGResponder = { 
		if(~window.notNil and: { ~window.isClosed.not }) { ~window.close };
	};
} => PR(\hs1);

PR(\hs1).clone {
	~alwaysReset = true;
	~minTop = 2;
	~maxTop = 32;
	~procInit = {
		~lowhCtl = GenericGlobalControl(\lowh, nil, ~minTop, [~minTop, ~maxTop, \lin, 1]);
		~tophCtl = GenericGlobalControl(\numh, nil, ~minTop, [~minTop, ~maxTop, \lin, 1]);

		// see pattern for sync with master clock
		~quant = NilTimeSpec.new;
	};
	~procFree = { [~lowhCtl, ~tophCtl].free };
	~useGui = { |vpi| ~lowhCtl => VP(vpi); ~tophCtl => VP(vpi) };
	~makeGResponder = 0;
	~removeGResponder = 0;

	~panGen = Pif(Pfunc { |num| num > 1 }, Prand(#[lr, rl, ctrout, scatter], inf), \zero);
	~lr = Plazy { |num| Pseries.fromEndpoints(-1.0, 1.0, num) };
	~rl = Plazy { |num| Pseries.fromEndpoints(1.0, -1.0, num) };
	~ctrout = Plazy { |num| Pseries.fromEndpoints(0.0, 1.0, num) * Pseq(#[-1, 1], inf, { 2.rand }) };
	~scatter = Pwhite(-1.0, 1.0, inf);
	~zero = 0;

	~asPattern = {
		~makeStreamForKey.(\panGen);
		Pspawner { |sp|
			var	num, panGen;
			if((num = thisThread.beats - BP(~cl).goTime) > 0) {
				sp.wait((num.trunc - num + 1));
				loop {
					num = ~tophCtl.value.asInteger - ~lowhCtl.value.asInteger + 1;
					panGen = ~panGenStream.next(num).envirGet.asStream;
					sp.par(
						Ptpar((~lowhCtl.value.asInteger .. ~tophCtl.value.asInteger).collect({ |i|
							[	(1 - i.reciprocal),
								Pbind(
									\chan, ~chan,
									\instrument, Pn(\partial1bgated, 2),
									\numHold, 1, //if(i == 0, 1, max(num / 4, 1)),
									\ratio, i,
									\freq, ~fund * Pkey(\ratio),
									\egRate, ~tempoCtl.asMap,
									\egRateMul, i,
									\egBuf, ~egbuf,
									// empirically, unity gain is about 4dB too loud
									\amp, -4.dbamp,
									\delta, Pkey(\egRateMul).reciprocal * Pkey(\numHold),
									\sustain, Pkey(\delta) * (1 - (0.5 / Pkey(\numHold))),
									\panCtr, panGen.next(num),
									\panWidth, 0
								)
							]
						}).flat, 1
					));
					sp.wait(2);
				}
			}; // else, do nothing and spawner ends
		};
	};
} => PR(\hsSweep);

PR(\hs1).clone {
	~minTop = 2;
	~maxTop = 40;
	~procInit = {
		~tophCtl = GenericGlobalControl(\numh, nil, ~minTop, [~minTop, ~maxTop, \lin, 1]);
		~tophCtl.addDependant(currentEnvironment);
		// 0 is a dummy value
		~hStreams = Array.newClear(~maxTop + 1).overWrite(0 ! ~minTop);

		~offsetCtl = GenericGlobalControl(\offset, nil, 0.5, #[0, 0.5]);
		~sawCtl = GenericGlobalControl(\sawPct, nil, 0);

		// see pattern for sync with master clock
		~quant = NilTimeSpec.new;
	};
	~procFree = { [~tophCtl, ~offsetCtl, ~sawCtl].free };
	~useGui = { |vpi| ~tophCtl => VP(vpi); ~offsetCtl => VP(vpi); ~sawCtl => VP(vpi) };
	~makeGResponder = 0;
	~removeGResponder = 0;

	~stopCleanup = {
		(~minTop .. ~maxTop).do { |i| ~hStreams[i] = nil };
	};

	// inherit asPattern from hs1:
	// this process uses the same technique of adding harmonics dynamically

	// this can be called by any gesture-trigger responder
	~addAStream = { |ratio = 2|
		var	stream, sync;
		if(~hStreams[ratio].isNil) {
			sync = ((0.1 * ~clock.tempo) + ~clock.beats - BP(~cl).goTime).roundUp(ratio.reciprocal)
				+ BP(~cl).goTime - ~clock.beats;
			stream = ~spawner.par(~oneStream.(ratio, nil, 
				[	timingOffset: (1 - (ratio+1).reciprocal) * ~offsetCtl.asPattern,
					panCtr: 0,
					panWidth: ratio / ~tophCtl.value,
					// when ~sawCtl hits 1.0, output should be a sawtooth spectrum
					amp: Pnaryop('blend', 1.0, [ratio.reciprocal, ~sawCtl])
				]),
				sync
			);
			~streamHook.(stream, ratio);
		};
	};

	~initStreams = {
		(~minTop .. ~tophCtl.value.asInteger).do { |i|
			~addAStream.(i)
		};
	};

	~streamHook = { |stream, ratio|
		~hStreams[ratio] = stream;
	};
	~streamEndHook = { |stream, ratio|
		~hStreams[ratio] = nil;
	};

	// changing tophCtl value calls back here:
	~update = { |obj, msg|
		var	i;
		if(~isPlaying and: { obj === ~tophCtl and: { msg[\what] == \value } }) {
			if((i = ~hStreams.indexOf(nil)).isNil) {
				i = ~maxTop + 1;
			};
			if(i <= obj.value) {
				// add streams
				(i .. obj.value.asInteger).do { |ratio|
					~addAStream.(ratio)
				};
			} {
				if(i > (obj.value + 1)) {
					// remove streams
					(obj.value.asInteger + 1 .. i - 1).do { |ratio|
						~spawner.suspend(~hStreams[ratio]);
						~hStreams[ratio] = nil;
					};
				};
			};
		};
	};
} => PR(\hsDrone);

(make: { |name|
	BP(name).free;
	Proto {
		~quant = 0;
		~delta = Pexprand(0.04, 0.2, inf) * Plazy { Env(#[20, 1], #[120], \exp).asStream };
		~event = (play: {
			BP(\hs).addAStream;
		});
		~asPattern = {
			Pbind(\delta, BPStream(\delta, resetSource: true))
		};
	} => BP(name)
}, type: \bp) => Fact(\hstrig);

(make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		chan: BP(\mstClock).chan2,
		isFx: true,
		alwaysReset: true,
		event: (eventKey: \monoSupport),
		userprep: {
			~fmtKeys = FormantTable.keys.select { |k| k.asString.contains("tenor") }.asArray;
		},
		delta: Pexprand(0.1, 0.9, inf), // Pexprand(1.0, 4.0, inf),
		formant: Plazy { Pxrand(~fmtKeys, inf) },
		fadeIn: 8,
		fadeOut: 4,
		objects: (
			fmt: (
				def: SynthDef(\formantfx2, { |inbus, outbus, t_trig = 0, slideTime = 1, gate = 1,
						amp = 1, fadeIn = 5, fadeOut = 5|
					var	ffreqs = NamedControl.kr(\ffreqs, Array.series(5, 400, 400)),
						amps = NamedControl.kr(\amps, 1 ! 5),
						qs = NamedControl.kr(\qs, 0.1 ! 5),
						sig = In.ar(inbus, 2), sig2,
						wet = Linen.kr(gate, fadeIn, 1, fadeOut, doneAction: 2);
					ffreqs = ffreqs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
					amps = amps.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
					qs = qs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
					sig2 = BBandPass.ar(sig, ffreqs, qs, amps).sum * amp;
					sig = XFade2.ar(sig, sig2, wet.madd(2, -1));
					ReplaceOut.ar(outbus, sig);
				}),
				args: [
					protoEvent: Pseq([\singleSynthPlayNotify, Pn(\singleSynthTrigger, inf)]),
					#[ffreqs, amps, qs], Pnsym(BPStream(\formant), FormantTable),
					ffreqs: Pkey(\ffreqs) * Pexprand(0.95, 0.95.reciprocal, inf).clump(5),
					trig: 1,
					slideTime: Pkey(\delta) * Pwhite(0.4, 0.8, inf),
					inbus: Plazy { Pn(~chan.inbus, inf) },
					node: Pfunc { ~node ? 0 },
					sustain: inf,
					amp: 12.5.dbamp,
					fadeIn: BPStream(\fadeIn),
					fadeOut: BPStream(\fadeOut)
				]
			)
		),
		recvEventNotify: { |node, event|
			~node = node;
		},
	 	stopCleanup: { ~node.release; ~node = nil; ~makeStreamForKey.(\fmtprotoEvent) }
	));
}, type: \bp) => Fact(\formantfx1);

