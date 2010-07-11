
var	temp, temp2;

~clock108 ?? {
	~clock108 = TempoClock(108/60).permanent_(true);
	~clock108.schedAbs(~clock108.nextBar, { ~clock108.beatsPerBar = 3 });
};

if(Mode.exists(\c).not) {
	#[c, db, d, eb, e, f, gb, g, ab, a, bb, b].do { |key, i|
		Mode(\default).v.copy.root_(i) => Mode(key);
		Mode(key).v.transposeRoot(0) => Mode((key ++ "0").asSymbol);
	};
};


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
			[~tempoCtl, ~holdPctCtl, ~chan, ~chan2, ~egbuf].free;
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


// choral

if(MBM.exists(0).not) { MIDIBufManager(chan: nil) => MBM.prNew(0) };

~ratios = [1, 4/3 * 4/5, 9/8, 6/5, 5/4, 4/3, 9/8 * 5/4, 3/2, 4/3 * 6/5, 4/3 * 5/4, 16/9, 3/2 * 5/4];
~tun = CompositeTuning([
	TuningRatios(12, tunings: ~ratios),
	TuningRatios(12, tunings: ~ratios.copy.putEach(#[5, 9, 10], [27/20, 27/16, 9/5]))
]).root_(8).calibrate(32.midicps, 32);

~tprop = (type: \c, voice: \tenor);
~aprop = (type: \c, voice: \alto);

MIDIRecBuf(\t1, [#[56, 58, 56], 16, 15.5, 0.5].asNotes, ~tprop) => MBM(0);
MIDIRecBuf(\a1, [#[68, 66.01, 68], 16, 15.5, 0.5].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\a1b, [#[68, 66.01, 68] - 5, 16, 15.5, 0.5].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\t2, [
	#[56, 58, 56, 54, 56, 61, 58, 56],
	#[1, 0.5, 0.5, 0.5, 0.5, 1, 2, 0.1],
	#[1, 0.5, 0.5, 0.5, 0.5, 1, 2, 3],
	0.5
].asNotes, ~tprop) => MBM(0);

MIDIRecBuf(\a2, [
	#[63, 65.01, 63, 61, 63, 68, 65.01, 63],
	#[1, 0.5, 0.5, 0.5, 0.5, 1, 2, 0.1],
	#[1, 0.5, 0.5, 0.5, 0.5, 1, 2, 3],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\a2b, [
	#[63, 65.01, 63, 61, 63, 68, 65.01, 67, 68],
	#[1, 0.5, 0.5, 0.5, 0.5, 1, 1, 1, 0.1],
	#[1, 0.5, 0.5, 0.5, 0.5, 1, 1, 1, 3],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\a2c, [
	#[68, 67, 68, 70, 72, 68, 67, 68],
	#[1, 0.5, 0.5, 0.5, 0.5, 2, 1, 0.1],
	#[1, 0.5, 0.5, 0.5, 0.5, 2, 1, 3],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\a2d1, [
	#[68, 67, 68, 70, 72, 68, 67, 67, 65, 68],
	#[1, 0.5, 0.5, 0.5, 0.5, 1.5, 0.5, 0.5, 0.5, 0.1],
	#[1, 0.5, 0.5, 0.5, 0.5, 1.5, 0.12, 0.4, 0.4, 3],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\a2d2, [
	// 61: better to tune Db vs. Ab rather than Bb
	#[63, 61, 63, 68, 65, 61, 63],
	#[1, 0.5, 1, 0.5, 1, 2, 0.1],
	#[1, 0.5, 1, 0.5, 1, 2, 3],
	0.5
].asNotes, ~aprop) => MBM(0);


MIDIRecBuf(\t3, [
	#[56, 58, 60, 61.01, 63, 61, 60, 58, 56],
	#[1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 2, 0.1],
	#[1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 2, 3],
	0.5
].asNotes, ~tprop) => MBM(0);

MIDIRecBuf(\a31, [
	#[63, 62, 63, 65.01, 67, 65, 63, 62, 63],
	#[1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 2, 0.1],
	#[1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 2, 3],
	0.5
].asNotes, ~aprop) => MBM(0);

MBM(0)[\a2c].copy.name_(\a32) => MBM(0);


// more complex cadence formulas than PR(\cadences) can handle
MIDIRecBuf(\a41, [
	#[63, 65.01, 67, 68],
	(temp = #[1, 2, 2, 4] * ({ rrand(2.0, 4.2) } ! 3); temp2 = temp.copy.put(3, 0.1)),
	temp, 0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\t4, [
	#[60, 58, 56],
	[temp2[0], temp2[1] + temp2[2], temp2[3]],
	[temp[0], temp[1] + temp[2], temp[3]],
	0.5
].asNotes, ~tprop) => MBM(0);

MIDIRecBuf(\a42, [
// 	#[63, 61.01, [61.01, 63], [60, 63]],
// 	[temp2[0], temp2[1], temp2[2], temp2[3]],
// 	[temp[0], temp[1], temp[2], temp[3]],
	#[63, 61.01, 60],
	[temp2[0], temp2[1] + temp2[2], temp2[3]],
	[temp[0], temp[1] + temp[2], temp[3]],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\a42b, [
	#[63, 61.01, [61.01, 63], [60, 63]],
	[temp2[0], temp2[1], temp2[2], temp2[3]],
	[temp[0], temp[1], temp[2], temp[3]],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\b4, [
	#[r, r, 51, 44],
// 	[temp2[0] + temp2[1], temp2[2], temp2[3]],
// 	[temp[0] + temp[1], temp[2], temp[3]],
	temp2, temp,
	0.5
].asNotes, (type: \c, voice: \bass, xfer: \lpfxfer2)) => MBM(0);




SynthDef(\lpfxfer2, { |inbus, outbus, ffreq = 2000, lpfxAmp = 0.3|
	Out.ar(outbus, LPF.ar(In.ar(inbus, 1), ffreq, lpfxAmp) ! 2);
}).add;

SynthDef(\formantXfer2, { |inbus, outbus, t_trig = 0, slideTime = 1, amp = 1, lpfreq = 2000|
	var	ffreqs = NamedControl.kr(\ffreqs, Array.series(5, 400, 400)),
		amps = NamedControl.kr(\amps, 1 ! 5),
		qs = NamedControl.kr(\qs, 0.1 ! 5),
		sig = In.ar(inbus, 1); //,
//		noise = PinkNoise.ar(noiseAmp * Amplitude.kr(sig));
	ffreqs = ffreqs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
	amps = amps.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
	qs = qs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
	sig = LPF.ar(sig, lpfreq);
	sig = BBandPass.ar(sig /*+ noise*/, ffreqs, qs, amps).sum;
	Out.ar(outbus, (sig * amp) ! 2);
}).add;


WrapInstr("analog.sawB", { |freq, gate = 1, detune = 1.003, ffreq = 2000, vsens = 0.5
	att = 0.1, dec = 0.2, sus = 0.6, rel = 0.5, fLowRatio = 0.05|
	var	amp = (Latch.kr(gate, gate) - 1) * vsens + 1,
		sig = Saw.ar(freq * [1, detune], amp).sum,
		env = Env.adsr(att, dec, sus, rel),
		eg = EnvGen.kr(env, gate, doneAction: 2),
		fcurve = EnvGen.kr(Env([fLowRatio, 1], [att], \exp));
	LPF.ar(sig, ffreq * fcurve, eg)
}, [\freq, NoLagControlSpec(0, 1), \mydetune, \freq, nil, #[0.01, 20.0], #[0.01, 20.0], #[0, 1], #[0.01, 20.0]]);

PR(\abstractProcess).clone {
	~event = (eventKey: \polySynthFxPatLock, addAction: \addToHead);

	~seqKeys = #[t1, a1];
	~att = 1; // Pkey(\sustain) * 0.3;
	~dec = 1; // Pkey(\sustain) * 0.1;
	~rel = 1; // Pkey(\sustain) * 0.4;
	~fLow = 0.05;
	~rhyScale = 1;
	~legato = 0.93;
	~tempoPat = 42/60;

	~lpfxferFreq = 900;
	~lpfxferAmp = 0.3;

	~prep = {
		~chan = MixerChannel(~collIndex, s, 2, 2, outbus: ~master ?? { topEnvironment[\master] },
			completionFunc: { |chan|
				~chorus = chan.playfx(Instr("busfx.chorus2"), [0, 2, 2, 3, 0.036937527208376, 0.11364637357074, 0.0062137993811117, 0.69813170599922, 0.82540422302882]);
			});

		~def = WrapPatch("analog.sawB", [nil, nil, nil, `18000, 0.8])
			.asSynthDef.add;
		~defname = ~def.name.asSymbol;
		SynthDescLib.at(~defname).msgFuncKeepGate = true;

		~alto = ~formantKeys.("alto");
		~tenor = ~formantKeys.("tenor");
		~bass = ~formantKeys.("bass");
	};

	~freeCleanup = { [~chan/*, ~noiseCtl*/].free };

	~fx = \none; // Pfunc { ~fxPool.keys.choose };
	~fxProto = \monoSupport;
	~vowel = Pclutch(Pxrand(['A', 'E', 'I', 'O', 'U'], inf), Pdiff(Ptime()) > 0);

	~lpfEnv = {
		var	up = rrand(0.3, 0.7);
		Env([200, 14000, 200], [up, 1-up], \exp);
	};

	~ratios = [1, 4/3 * 4/5, 9/8, 6/5, 5/4, 4/3, 9/8 * 5/4,
		3/2, 4/3 * 6/5, 4/3 * 5/4, 16/9, 3/2 * 5/4];
	~tun = CompositeTuning([
		TuningRatios(12, tunings: ~ratios),
		TuningRatios(12, tunings: ~ratios.copy.putEach(#[5, 9, 10], [27/20, 27/16, 9/5]))
	]).root_(8).calibrate(32.midicps, 32);

	// NOTE: These will be evaluated in the Proto's context
	~fxPool = (
		rainbow: { |ev|
			var	up = rrand(0.3, 0.6);
			Pbind(
				\instrument, \ringzFadePan,
				\ffreq, Env(#[2500, 9000, 2500], [up, 1-up] * ev[\sustain], \sine),
				\filtAtk, Pexprand(0.08, 0.2, inf),
				\filtDcy, Pkey(\filtAtk) + Pwhite(0.05, 0.3, inf),
				\time, Pwhite(1.8, 3.2, inf),
				\delta, Pexprand(0.25, 0.8, inf),
				\pan, Pwhite(0.7, 1.0, inf) * Prand(#[-1, 1], inf),
				\amp, 0.05
			)
		},
		rainbow1: { |ev|
			var	up = rrand(0.15, 0.75), atk;
			Pn((
				instrument: \ringzFadeEnv,
				freqEnv: Env(#[2500, 9000, 2500], [up, 1-up] * ev[\sustain], \sine),
				filtAtk: atk = exprand(0.08, 0.2),
				filtDcy: atk + rrand(0.05, 0.3),
				time: ev[\sustain],
				delta: 1,
				pan: rrand(0.7, 1.0) * #[-1, 1].choose,
				amp: 0.05
			), 1)
		}
	);

	~formantKeys = { |string|
		FormantTable.keys.select { |key| key.asString.contains(string) }.asArray
	};

	~asPattern = {
		var	self = currentEnvironment, resp, pat = ~moreHorribleIndirectionPattern.();
		(if(~useLpf ? false) { 
			Pfset({ ~lpfbus = Bus.control(s, 1) },
				Ptpar([
					0, pat,
					0.01, Pfuncn { |ev|
						(	type: \on, instrument: \ctlEnv, outbus: ev[\lpfbus],
							time: self[\phraseDur] + self[\relStream].next(ev),
							connect: 0, env: self.lpfEnv,
							group: self.chan.synthgroup,
							callback: { |event|
								resp = OSCpathResponder(s.addr, ['/n_end', event[\id][0]], {
									ev[\lpfbus].free; resp.remove;
								}).add
							},
							delta: 0
						).parent_(nil)  // force default parent event
					},  // else nil
				])
			)
		} { pat });
	};

	// I wish I had time to refactor this... but, it stays.
	~moreHorribleIndirectionPattern = {
		~fxStream ?? { ~makeStreamForKey.(\fx) };
		~lpfxferFreqStream ?? { ~makeStreamForKey.(\lpfxferFreq) };
		~lpfxferAmpStream ?? { ~makeStreamForKey.(\lpfxferAmp) };
		~vowelStream ?? { ~makeStreamForKey.(\vowel) };
		// currentEnvironment is a Proto; doesn't work for valueEnvir
		Plazy { |ev|
			Pbind(\tempo, Pclutch(~tempoPat.(ev), Pdiff(Ptime()) > 0))
			<>
			~patternTemplate.(ev)
		}.collect { |ev| ~preprocessNote.(ev) }
	};

	~evalEnvir = { |key| currentEnvironment.env.use { key.envirGet.valueEnvir } };

	~patternTemplate = { |ev|
		Ppar(
			~seqKeys.collect { |key|
				~currentKey = key;
				Pbind(
					\instrument, ~defname,
					// valueEnvir to allow subclasses to get arguments dynamically
					\note, ~evalEnvir.(\notePattern),
					\rhyScale, BPStream(\rhyScale),
					\delta, Pfunc { |ev| ev[\note].dur * ev[\rhyScale] },
					\legato, BPStream(\legato),
					\sustain, Pfunc { |ev| ev[\note].length * ev[\rhyScale] * ev[\legato] },
					\att, BPStream(\att), \dec, BPStream(\dec), \rel, BPStream(\rel),
					\fLowRatio, BPStream(\fLow),
					\chan, ~chan,
					\numCh, 1,
					\fxKey, BPStream(\fx),
					\fxProto, BPStream(\fxProto),
					\busFreeDelay, 3.2,
					\fxPatEv, Pbind(
						\syllable, ~evalEnvir.(\vocKey),
						\pat, Pfunc { |ev|
							var	fspecs = FormantTable.at(ev[\syllable]),
								fxPat, lockref;
							fxPat = ~fxPool[ev[\fxKey]].(ev);
							Pseq([
								Pn(~xferEvent.(ev, fspecs, lockref = `nil, key), 1),
								if(fxPat.notNil) {
									Pfindur(ev[\sustain],
										fxPat <> Pbind(\protoEvent, \singleSynthPlayNotify,
											\lock, Pfunc { lockref.value }))
								}
							])
						}
					)
				)
			}
		)
	};

	~notePattern = { |currentKey|
		var	mb = MBM(0)[currentKey];
		mb = mb.asPattern;
		if(~filterNotePat.notNil) { mb = ~filterNotePat.(mb) };
		~phraseDur = 0;
		mb.do { |note| ~phraseDur = ~phraseDur + note.length };
		mb
	};
	~vocKey = { |currentKey|
		var	prefix = MBM(0)[currentKey].properties[\voice];
		~vowelStream.collect { |vowel| (prefix ++ vowel).asSymbol }
	};
	~xferKey = { |currentKey| MBM(0)[currentKey].properties[\xfer] ?? { \formantXfer2 } };

	~preprocessNote = { |ev|
		var	note;
		// yeah, isKindOf = bad, but this could be called with an Event.silent
		if((note = ev[\note]).isKindOf(SequenceNote)) {
			if(note.freq.isSymbol) {
				ev[\instrument] = \rest;
//				ev = Event.silent(note.dur)
			} {
				ev.freq_(note.freq.asArray.collect(~tun.cps(_)))
					/*.sustain_(note.length)*/
					.gate_(note.gate)
			};
		}; // { "not a sequencenote".postln; note.postcs };
		ev
	};

	~xferEvent = { |ev, fspecs, lockref, key|
		(
			protoEvent: \singleSynthPlayNotify,
			instrument: ~xferKey.(key), //~evalEnvir.(\xferKey),
			ffreq: ~lpfxferFreqStream.next(ev),
			lpfxAmp: ~lpfxferAmpStream.next(ev),
			ffreqs: fspecs[0],
			amps: fspecs[1],
			qs: fspecs[2],
			sustain: nil,
			delta: 0.1,
			collIndex: ~collIndex,
			notifyDependents: {
				lockref.value = ~lock;
				~lock.killNodes = ~lock.killNodes.add(~node);
			},
			lpfreq: ev[\lpfbus] !? { ev[\lpfbus].asMap }
		)
	};
} => PR(\counterpoint);

();
PR(\counterpoint).clone {
	~parentBP = \c;
	~importKeys = #[chan, alto, tenor, defname, tun];
	~prep = {
		if(BP.exists(~parentBP).not) {
			Error("BP(%) must be created first".format(~parentBP.asCompileString)).throw;
		};
		~importKeys.do { |key| key.envirPut(BP(~parentBP)[key]) };
		~reset.();
	};
	~freeCleanup = 0;

	~fx = \vowelChange;
	~useLpf = true;

	~fxPool = (
		vowelChange: { |ev|
			var	prefix = ev[\syllable].asString.drop(-1);
			Pbind(
				\protoEvent, \singleSynthTrigger,
				\node, Pfunc { |ev| ev[\lock].killNodes.asArray.detect(_.isKindOf(Synth)) },
				\trig, 1,
				#[ffreqs, amps, rqs], Pnsym(
					Pxrand(#['A', 'E', 'I', 'O', 'U'], inf)
						.collect { |vowel| (prefix ++ vowel).asSymbol },
					FormantTable
				),
				\delta, Pexprand(0.8, 1.8, inf),
				\slideTime, Pkey(\delta) * Pwhite(0.4, 0.7, inf)
			)
		}
	);

	// the meat!
	~seqKeys = #[not_applicable];
	~parmKeys = #[p5, sharp, shortFirst, dur, legato, gate, shortDur, oneNote];
	~oneNote = Pwhite(0.0, 1.0, inf) < 0.5; //true;
	~p5 = Pwhite(0.0, 1.0, inf) < 0.5; //false;  // false == 8ve
	~sharp = Pwhite(0.0, 1.0, inf) < 0.5; //true;  // true == raise cadence note
	~shortFirst = Pwhite(0.0, 1.0, inf) < 0.5; //true;
	~dur = Pwhite(0.65, 1, inf) *.x Pwhite(12.0, 16.0, { |num| num });
	~shortDur = Pwhite(1.2, 2.2, inf);
	~legato = 1; //Pwhite(1.02, 1.1, inf);
	~gate = Pif(Pfunc { |n| n > 1 },
		Pseq(#[0.6, 1.0, 0.6], inf) * Pwhite(0.5, 0.7, inf),
		Pwhite(0.4, 1.0, inf)
	);

	// important: must output SequenceNotes
	~notePattern = { //|p5, sharp, shortFirst|
		// 61.01 is needed for Bb/Db and Bb/Gb
		// .01 has no effect on D-nat or G-nat (already tuned pure against Bb)
		var	freqs = if(~oneNoteStream.next) { #[[56], [63]] } {
				[	#[56, 58, 56],
					[63, 61.01 + ~sharpStream.next.binaryValue, 63]
				]
			},
			fsize = freqs[0].size,
			durs = { ~durStream.next(fsize) } ! fsize, notes;

//		if(~p5Stream.next.not) { freqs = freqs.copy.put(1, freqs[1] + 5) };
		switch(~p5Stream.next)
			{ 0 } { freqs = freqs.copy.put(1, freqs[1] + 5) }
			{ 2 } { freqs = freqs.copy.add(freqs[1] + 5) };

		if(~shortFirstStream.next) { durs[0] = ~shortDurStream.next(fsize) };
		~phraseDur = durs.sum;	// BAD HACK
		notes = freqs.flop.collect { |f, i|
			SequenceNote(f, durs[i], durs[i] * ~legatoStream.next, ~gateStream.next(fsize))
		};
		notes.last.dur_(0.1);
		Pseq(notes, 1)
	};

	// not using MIDIRecBufs for this so I must override these funcs too
	~vocKey = {
		var	prefix = ["tenor", "alto"].choose;
		~vowelStream.collect { |vowel| (prefix ++ vowel).asSymbol }
	};
	~xferKey = \formantXfer2;

	// behaves badly if parms are not reset too
	~reset = { ~parmKeys.do { |key| ~makeStreamForKey.(key) } };
} => PR(\cadences);


SynthDef(\bufGrainPanFmlet, { |start, time, bufnum, pan, rate = 1, amp = 1,
		attack = 0.001, decay = 0.02, outbus,
		ffreq = 2000, fatk = 0.01, fdec = 0.1, wet = 1|
	var sig, sig2, eg;
	sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0);
	eg = EnvGen.kr(Env.linen(attack, time, decay), doneAction:2);
	sig2 = Limiter.ar(Formlet.ar(sig, ffreq, fatk, fdec));
	sig = LPF.ar(sig, wet.linexp(0, 1, 18000, ffreq));
	sig = XFade2.ar(sig, sig2, wet.madd(2, -1));
	Out.ar(outbus, Pan2.ar(sig, pan, amp * eg));
}).add;


(keys: #[master, rvbmc],
copyKeys: #[buffers, chan, postMCCreation, calcBar, bar, amps],  // you can override this
sourceFreesMe: true,
bp: \t1,
make: { |name|
	var	parms = ~parms ?? { () }, upd;
	BP(name).free;
	~keys.do { |key| parms[key] ?? { parms.put(key, key.envirGet) } };
	~copyKeys.do { |key| parms[key] ?? { parms.put(key, BP(~bp)[key]) } };
	PR(\bufPerc).chuck(BP(name), nil, parms);
	// copies have to go away because they depend on the source's buffers, mixer etc.
	if(~sourceFreesMe ? true) {
		upd = Updater(BP(~bp), { |obj, what|
			if(what == \free) {
				upd.remove;
				BP(name).free;
			}
		});
	};
	BP(name)
}, type: \bp) => Fact(\copyBufPerc);


(
keys: #[master, rvbmc, clock108],
make: { |name|
	BP(name).free;
	PR(\bufPerc).chuck(BP(name), nil, (
		master: ~master, rvbmc: ~rvbmc,
		alwaysReset: true,
		reset: { ~pbindPreAction.reset },
		bufPaths: ["~/sounds/drums/Udu/uduSLAP1.wav".standardizePath],
		baseIndices: #[0, 8],
		baseAmp: 1,
		postMCCreation: {
			var	zero = 0 ! 12, temp;
			~pbindPreAction = Routine(~calcBar);
			~bases = { |i|
				temp = zero.copy;
				~baseIndices.size.do { |j|
					if((i bitAnd: (1 << j)) > 0) {
						temp.put(~baseIndices[j], ~baseAmp)
					};
				};
				temp
			} ! (1 << ~baseIndices.size);
			~indices = { |num|
				~bases.collectIndices({ |array| array.count(_ > 0) == num });
			} ! (~baseIndices.size + 1)		
		},
		postBufferLoad: {
			~chan.newPostSend(~rvbmc, 0.391);
			~fdecCtl = GenericGlobalControl(\fdec, nil, 0.5,  #[0.01, 1.0, exp]);
			~ffLowCtl = GenericGlobalControl(\fLow, nil, 2, #[1, 32, \lin, 1]);
			~ffRangeCtl = GenericGlobalControl(\fRange, nil, 8, #[0, 32, \lin, 1]);
			~wetCtl = GenericGlobalControl(\wet, nil, 1);

			~ffreq = 52 * Pwhite(~ffLowCtl, ~ffLowCtl.asPattern + ~ffRangeCtl + 0.99).trunc;
			~argPairs = [
				ffreq: BPStream(\ffreq),
				fdec: ~fdecCtl, 
				wet: ~wetCtl.asMap
			];
			// sibling processes may not init until I'm done
			NotificationCenter.notify(name, \ready);
		},
		useGui: { |vpi| #[fdecCtl, ffLowCtl, ffRangeCtl, wetCtl].do { |key| key.envirGet => VP(vpi) } },
		free: { [~fdecCtl, ~ffLowCtl, ~ffRangeCtl, ~wetCtl].free },
		amps: 0,
		bar: Pseq(#[0, 1], inf),
		calcBar: {
			var	bar = BPStream(\bar, resetSource: true).asStream,
			count = Pseries(0, 1, inf).asStream;
			// 		"reset".debug(~collIndex);
			loop {
				~amps = ~bases[bar.next];
				~barHook.(count.next);
				0.yield;
			}
		},
		barHook: {
			~rates = #[0.5, 0.6];
			if (~amps[0] == 0) { ~rates.rotate(-1) }
			{ ~rates };
		},

		def: \bufGrainPanFmlet
	));
	~clock108 => BP(name);
}, type: \bp) => Fact(\drum1);

(
keys: #[master, rvbmc, clock108],
source: \t1,
make: { |name|
	BP(name).free;
	if (BP.exists(~source)) {
		if (BP(~source)[\argPairs].notNil) {
			~makeBP.(name);
		} {
			NotificationCenter.registerOneShot(~source, \ready, name, e {
				~makeBP.(name);
			});
			BP(name)
		}
	} {
		"% not loaded, cannot load %".format(~source, name).warn;
	}
},
makeBP: { |name|
	Fact(\copyBufPerc).chuck(BP(name), nil, (
		copyKeys: Fact(\copyBufPerc).copyKeys ++ #[fdecCtl, ffLowCtl, ffRangeCtl, wetCtl, def],
		bp: ~source,
		parms: (
			alwaysReset: true,
			reset: { ~pbindPreAction.reset },
			baseIndices: #[2, 6],
			baseAmp: 1,
			rates: #[1.25],
			postBufferLoad: {
				~ffreq = 52 * Pwhite(~ffLowCtl, ~ffLowCtl.asPattern + ~ffRangeCtl + 0.99).trunc;
				~argPairs = [
					ffreq: BPStream(\ffreq),
					fdec: ~fdecCtl,
					wet: ~wetCtl.asMap
				];
			}	
		)
	));
// 	BP(name).dump;
// 	BP(name).v.tryPerform(\listVars);
	~clock108 => BP(name);
}, type: \bp) => Fact(\drum2);

(
keys: #[master, rvbmc, clock108],
source: \drum1,
make: Fact(\drum2).v[\make],
makeBP: { |name|
	var parms;
	BP(name).free;
	parms = (
		alwaysReset: true,
		reset: { ~pbindPreAction.reset },
		postBufferLoad: {
			~ffreqCtl = GenericGlobalControl(\ffreq, nil, 2000, \freq);
			~argPairs = [ffreq: ~ffreqCtl.asMap];
		},
		useGui: { |vpi| ~ffreqCtl => VP(vpi) },
		free: { ~ffreqCtl.free },
		bufPaths: "~/sounds/drums/Udu/*FING*".pathMatch,
		amps: 0,
		barHook: {
			~bufs = { ~buffers.size.rand } ! ~amps.count(_ > 0);
		},
		baseIndices: #[1, 4, 7, 10],
		baseAmp: 3.7,
		def: \bufGrainPanRLPF
	);
	#[postMCCreation, calcBar].do { |key| parms.put(key, BP(~source)[key]) };
	
	PR(\bufPerc).chuck(BP(name), nil, parms);
	~clock108 => BP(name);
}, type: \bp) => Fact(\drum3);
