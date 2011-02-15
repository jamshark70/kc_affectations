var	temp, temp2;

// just in case... (won't load twice if already loaded)
(thisProcess.nowExecutingPath.dirname.dirname +/+ "common/common-defs.scd").loadPath;

if(~clock108.isNil or: { ~clock108.isRunning.not }) {
	~clock108 = TempoClock(108/60).permanent_(true);
	~clock108.schedAbs(~clock108.nextBar, { ~clock108.beatsPerBar = 3 });
};

if(Mode.exists(\c).not) {
	#[c, db, d, eb, e, f, gb, g, ab, a, bb, b].do { |key, i|
		Mode(\default).v.copy.root_(i) => Mode(key);
		Mode(key).v.transposeRoot(0) => Mode((key ++ "0").asSymbol);
	};
};

s.waitForBoot {
	SynthDef(\simpleLPCfxPan, { |inbus, outbus, lpcbuf, voxdur = 1, start, end = 1, time = 1, amp = 1, freq = 440, noiseMul = 1, hpf = 1600, xfscale = 0.25, lpf = 15000, pan = 0, attack = 0.05, decay = 0.05, postAmp = 1|
		var	src = In.ar(inbus, 1),
			// note, ar because LPCVals.ar with .kr pos input is broken
			pos = Line.ar(start, end, time) / voxdur,
	 		lpcv = LPCVals.ar(lpcbuf, pos),
	 		noise = HPF.ar(WhiteNoise.ar(noiseMul), hpf),
			sig = LPCSynth.ar(lpcbuf, XFade2.ar(src, noise, (xfscale * lpcv[2]).madd(2, -1)), pos, amp * lpcv[1]),
			eg = EnvGen.kr(Env.linen(attack, time - attack - decay, decay), doneAction: 2);
		sig = LPF.ar(sig, lpf);
		sig = LeakDC.ar(sig);
		Out.ar(outbus, Pan2.ar(Limiter.ar(sig * eg), pan, postAmp));
	}).add;
	
	SynthDef(\simpleLPCfxPan2, { |inbus, outbus, lpcbuf, voxdur = 1, start, end = 1, time = 1, amp = 1, freq = 440, noiseMul = 1, hpf = 1600, xfscale = 0.25, lpf = 15000, pan = 0, pan2 = 0, attack = 0.05, decay = 0.05, postAmp = 1|
		var	src = In.ar(inbus, 1),
			// note, ar because LPCVals.ar with .kr pos input is broken
			pos = Line.ar(start, end, time) / voxdur,
	 		lpcv = LPCVals.ar(lpcbuf, pos),
	 		noise = HPF.ar(WhiteNoise.ar(noiseMul), hpf),
			sig = LPCSynth.ar(lpcbuf, XFade2.ar(src, noise, (xfscale * lpcv[2]).madd(2, -1)), pos, amp * lpcv[1]),
			eg = EnvGen.kr(Env.linen(attack, time - attack - decay, decay), doneAction: 2);
		sig = LPF.ar(sig, lpf);
		sig = LeakDC.ar(sig);
		Out.ar(outbus, Pan2.ar(Limiter.ar(sig * eg), Line.kr(pan, pan2, time), postAmp));
	}).add;
	
	SynthDef(\oscbloop1, { |outbus, bufnum, freq1 = 50, freq2 = 900, fcurve = 0, time = 1, fHoldPct = 0,
		amp1 = 1, amp2 = 1, noiseBlend = 0.1, noiseFmul = 1, noisePreamp = 1, rq = 1.0,
		normAmp = 0.5, beats = 0.1|
		var	freq = EnvGen.kr(Env([freq1, freq1, freq2], [fHoldPct, 1 - fHoldPct], fcurve),
				timeScale: time),
			preAmp = Line.kr(amp1, amp2, time),
			sig = BPF.ar(COsc.ar(bufnum, freq, beats), freq, rq, noisePreamp),
			postAmp = normAmp / preAmp * (preAmp+1),
			env = NamedControl.kr(\env, (0 ! 20).overWrite(Env.linen(0.01, 0.98, 0.01).asArray)),
			eg = EnvGen.kr(env, timeScale: time, doneAction: 2);
		Out.ar(outbus, sig.distort * postAmp * eg);
	}).add;
	
	
	// harmonic series drones
	SynthDef(\partial1bgated, { |outbus, freq = 440, amp = 1, ampFilt = 1,
		filtSensBus = 0, filtMul = 1,
		egRate = 1, egRateMul = 1, egSusPt = 0.5, egBuf,
		panWidth = 0, panCtr = 0, gate = 1|
		var	sig = FSinOsc.ar(freq, 0, amp),
			swRate = egRate * egRateMul,
			posTest = Select.kr(Impulse.kr(0), [LocalIn.kr(1), 0]),
			notReachedSusPt = BinaryOpUGen('==', sign(egSusPt - posTest), swRate.sign),
			egpos = Sweep.kr(1, swRate * (((gate <= 0) + notReachedSusPt) > 0)),
			eg = BufRd.kr(1, egBuf, egpos * BufFrames.ir(egBuf), loop: 0, interpolation: 2),
			pan = LFNoise1.kr(swRate, panWidth, panCtr).clip(-1.0, 1.0),
			sens = In.kr(filtSensBus, 1),
			postamp = ampFilt * sens.linlin(0, 1, 1, filtMul);
		LocalOut.kr(egpos);
		FreeSelf.kr(egpos >= 1.0);
		OffsetOut.ar(outbus, Pan2.ar(sig * eg, pan, postamp));
	}).add;
};


(keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	var	master = ~master,	// to get master into the Proto environment
		glrvbmc = ~glrvbmc,
		lcrvbmc = ~lcrvbmc;
	BP(name).free;
	Proto({
		~fund = 32.midicps;
		~event = (eventKey: \singleSynthPlayNotify);
		~quant = NilTimeSpec.new;
		~initTempo = 0.1;
		~tempoSpec = #[0.01, 10, \exp].asSpec;
		~alwaysReset = true;

		~master = master;	// to get master into the Proto environment
		~glrvbmc = glrvbmc;
		~lcrvbmc = lcrvbmc;

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

			#[glrvb, lcrvb].do { |rvb|
				var	rvbmc = (rvb ++ "mc").asSymbol.envirGet;
				~event.put((rvb ++ "out").asSymbol,
					rvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels });
				[~chan, ~chan2].do { |mc|
					rvbmc.tryPerform(\receivesSignalFrom, mc);
				};
			};
			~event.put(\distNear, 5).put(\distFar, 20);

			~egbuf = Buffer.alloc(s, 1024, 1, { |buf|
				buf.setnMsg(0, Env(#[0, 1, 0], #[0.5, 0.5], \sine).discretize(1024))
			});
		};

		~asPattern = {
			Pseq([
				Pfuncn({
					~goTime = thisThread.beats;
					0
				}),
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
			[~glrvbmc, ~lcrvbmc].do { |rvb|
				[~chan, ~chan2].do { |mc|
					rvb.tryPerform(\stopsReceivingFrom, mc);
				};
			};
		}
	}) => BP(name);
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
		++ (Pexprand(Pfunc({ ~low }), Pfunc({ ~high }), inf)
			.round(1).reject { |x| ~activeRatios.includes(x) });
	~numEv = Pfunc({ |ratio| ratio }) * Pwhite(1.5, 4) * Pseries(1, 0.02, inf);

	~prep = {
		~ampCtl = GenericGlobalControl(\amp, nil, 0.2, \amp);

		~clImport.();
		~procInit.();

		~makeGResponder.();
		currentEnvironment
	};

	~procInit = {
		~activeRatios = Set.new;
		~fullSet = (~low .. ~high).asFloat.as(Set);
	};

	~clImportKeys = #[clock, event, tempoCtl, fund, chan2, egbuf, holdPctCtl];
	~clImport = {
		~clImportKeys.do { |key|
			key.envirPut(BP(~cl)[key])
		};
		// HACK
		~chan = ~chan2;
	};

	~freeCleanup = {
		~removeGResponder.();
		~ampCtl.free;
		~procFree.();
	};
	~useGui = { |vpi| ~ampCtl => VP(vpi) };

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
				\instrument, \partial1bgatedDist,
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
		if(repeats.notNil) {
//			result = Pfin(repeats, result)
			result = Pbindf(result, \distance, Pseries.fromEndpoints(5, 20, repeats));
		};
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
						panWidth: (1 - Pkey(\panCtr).abs) * (ratio / ~high),
						distance: ~makeDistPattern.(numEv)
					]),
				0.1);
			~streamHook.(stream, ratio);
		};
	};

//	~makeAmpPattern = { |numEv| Pgeom.fromEndpoints(1, rrand(0.02, 0.18), numEv) };
	~makeAmpPattern = { ~ampCtl.asMap };
	~makeDistPattern = { |numEv| Pgeom.fromEndpoints(5, rrand(16.0, 20.0), numEv) };

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

		~ampCtl.value = 0.185;

		// see pattern for sync with master clock
		~quant = NilTimeSpec.new;
	};
	~procFree = { [~lowhCtl, ~tophCtl].free };
	~useGui = { |vpi| ~lowhCtl => VP(vpi); ~tophCtl => VP(vpi); ~ampCtl => VP(vpi) };
	~makeGResponder = 0;
	~removeGResponder = 0;

	~panGen = Pif(Pfunc({ |num| num > 1 }), Prand(#[lr, rl, ctrout, scatter], inf), \zero);
	~lr = Plazy({ |num| Pseries.fromEndpoints(-1.0, 1.0, num) });
	~rl = Plazy({ |num| Pseries.fromEndpoints(1.0, -1.0, num) });
	~ctrout = Plazy({ |num| Pseries.fromEndpoints(0.0, 1.0, num) * Pseq(#[-1, 1], inf, { 2.rand }) });
	~scatter = Pwhite(-1.0, 1.0, inf);
	~zero = 0;
	~distEnv = Env(#[15, 5], #[1], #[-4.5]);

	~asPattern = {
		~makeStreamForKey.(\panGen);
		Pspawner({ |sp|
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
									\instrument, Pn(\partial1bgatedDist, 2),
									\numHold, 1, //if(i == 0, 1, max(num / 4, 1)),
									\ratio, i,
									\freq, ~fund * Pkey(\ratio),
									\egRate, ~tempoCtl.asMap,
									\egRateMul, i,
									\egBuf, ~egbuf,
									// empirically, unity gain is about 4dB too loud
									\amp, ~ampCtl.asMap, // -4.dbamp,
									\delta, Pkey(\egRateMul).reciprocal * Pkey(\numHold),
									\sustain, Pkey(\delta) * (1 - (0.5 / Pkey(\numHold))),
									\panCtr, panGen.next(num),
									\panWidth, 0,
									\distance, ~distEnv.at(i / (num-1))
								)
							]
						}).flat, 1
					));
					sp.wait(2);
				}
			}; // else, do nothing and spawner ends
		});
	};
} => PR(\hsSweep);

PR(\hs1).clone {
	~minTop = 2;
	~maxTop = 40;
	~filtMul = 12.5.dbamp;
	~fmtProc = \fmt;
	~trajectoryKey = \traj;
	~procInit = {
		~tophCtl = GenericGlobalControl(\numh, nil, ~minTop, [~minTop, ~maxTop, \lin, 1]);
		~tophCtl.addDependant(currentEnvironment);
		// 0 is a dummy value
		~hStreams = Array.newClear(~maxTop + 1).overWrite(0 ! ~minTop);

		if(BP.exists(~fmtProc)) {
			~fmtBus = BP(~fmtProc).fmtBus;
			~fmtMaps = { |i| ("c" ++ (~fmtBus.index + i)).asSymbol } ! ~fmtBus.numChannels;
		} {
			"BP(%) not found - formant buses not available".format(~fmtProc.asCompileString).warn;
		};

		~offsetCtl = GenericGlobalControl(\offset, nil, 0.5, #[0, 0.5]);
		~sawCtl = GenericGlobalControl(\sawPct, nil, 0);

		// see pattern for sync with master clock
		~quant = NilTimeSpec.new;
	};
	~procFree = {
		~tophCtl.removeDependant(currentEnvironment);
		[~tophCtl, ~offsetCtl, ~sawCtl].free
	};
	~useGui = { |vpi| ~tophCtl => VP(vpi); ~offsetCtl => VP(vpi); ~sawCtl => VP(vpi); ~ampCtl => VP(vpi) };
	~makeGResponder = 0;
	~removeGResponder = 0;

	~preparePlay = {
		BP(~trajectoryKey).isUsedBy(~collIndex);
		~traj ?? { ~traj = Pn(Pshuf(BP(~trajectoryKey).xymaps, 1), inf) };
		BP(~fmtProc).initializeAmps;
	};
	~stopCleanup = {
		(~minTop .. ~maxTop).do { |i| ~hStreams[i] = nil };
		if(BP.exists(~trajectoryKey)) { BP(~trajectoryKey).notUsedBy(~collIndex) };
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
					amp: Pnaryop('blend', 1.0, [ratio.reciprocal, ~sawCtl]) * ~ampCtl.asMap,
					ampFilt: ~fmtMaps[ratio - ~minTop],
					filtSensBus: BP(~fmtProc).sensCtl.index,
					filtMul: ~filtMul,
					#[pan, distance], ~trajStream.next
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
	Proto({
		~quant = 0;
		~delta = Pexprand(0.04, 0.2, inf) * Plazy({ Env(#[20, 1], #[120], \exp).asStream });
		~event = (play: {
			BP(\hs).addAStream;
		});
		~asPattern = {
			Pbind(\delta, BPStream(\delta, resetSource: true))
		};
	}) => BP(name)
}, type: \bp) => Fact(\hstrig);

(
transitionStates: 5,
//partials: ,	// you can override
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		chan: BP(\mstClock).chan2,
		isFx: true,
		alwaysReset: true,
// 		event: (eventKey: \monoSupport),
		event: (eventKey: \polySynthPlayer),
		userprep: {
			~fmtKeys = FormantTable.keys.select { |k| k.asString.contains("tenor") }.asArray;
			~makeEnvTable.();
			~fmtBus = Bus.control(s, ~partials.size).setn(1 ! ~partials.size);
			~sensCtl = GenericGlobalControl(\sensitivity, nil, 0);
			~event.put(\chan, nil)	// needed for kr synth chooser
				.put(\target, ~chan.fadergroup).put(\addAction, \addToHead);
		},
		userfree: {
			[~fmtBus, ~sensCtl].free
		},
		delta: Pexprand(0.1, 0.9, inf), // Pexprand(1.0, 4.0, inf),
		formant: Plazy({ Pxrand(~fmtKeys, inf) }),
		fadeIn: 12,
		fadeOut: 8,
		initializeAmps: { ~fmtBus.setn(1 ! ~partials.size) },
		preparePlay: {
			~initializeAmps.();
			~sensCtl.automate(\ctlEnv, [connect: 0, env: Env(#[0, 1], [~fadeIn], 0)],
				~chan.fadergroup, \addToHead)
		},
		doFadeOut: {
			~sensCtl.automate(\ctlEnv, [connect: 1, env: Env(#[1, 0], [~fadeOut], 0)],
				~chan.fadergroup, \addToHead);
			~event.copy.putAll((
				instrument: \ctlPoint, chan: nil,
				bus: ~fmtBus.index + (0 .. (~fmtBus.numChannels - 1)),
				value: 1, time: ~fadeOut, immediateOSC: true,
				target: ~chan.synthgroup, addAction: \addBefore
			)).play;
		},
		stopCleanup: { ~doFadeOut.() },
		objects: (
			fmtAmps: (
				def: SynthDef(\ctlEnvSens, { |outbus, levelScale = 1, levelBias = 0, time = 1, connect = 1,
							sens = 1|
						var	env = \env.kr(0 ! 40), sig;	// enough for 10 breakpoints
						env[0] = Select.kr(connect > 0, [env[0], In.kr(outbus, 1)]);
						sig = EnvGen.kr(env, 1, levelScale, levelBias, time, doneAction: 2);
						ReplaceOut.kr(outbus, (sig - 1) * sens + 1);
					}),
				args: [
					bus: Plazy({ Pn(~fmtBus.index + (0 .. (~fmtBus.numChannels - 1)), inf) }),
					key2: BPStream(\formant),
					key1: Pdelay(Pkey(\key2)),
					env: Pfunc({ |ev| ~fmtAmps[ev[\key1]].tryPerform(\at, ev[\key2]) }),
					time: Pkey(\delta) * Pwhite(0.4, 0.8, inf),
					sens: Plazy({ Pn(~sensCtl.asMap, inf) })
				]
			) //,
/*			fmt: (
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
					inbus: Plazy({ Pn(~chan.inbus, inf) }),
					node: Pfunc({ ~node ? 0 }),
					sustain: inf,
					amp: 12.5.dbamp,
					fadeIn: BPStream(\fadeIn),
					fadeOut: BPStream(\fadeOut)
				]
			)
*/
		),
// 		recvEventNotify: { |node, event|
// 			~node = node;
// 		},
// 	 	stopCleanup: { ~node.release; ~node = nil; ~makeStreamForKey.(\fmtprotoEvent) },

		transitionStates: ~transitionStates,
		partials: ~partials,
		makeEnvTable: {
			~fmtAmps = IdentityDictionary.new;
			~partials ?? { ~partials = 32.midicps * (2..32) };
			Routine({
				var	current, f1, f2;
				~fmtKeys.do { |key|
					~fmtAmps.put(key, current = IdentityDictionary.new);
					current.put(key, 
						~asOneAmpEnv.(~calcFormantResp.(FormantTable.at(key), ~partials)));
					~fmtKeys.do { |key2|
						if(key != key2) {
							// have we already calculated this transition, but in reverse?
							if(~fmtAmps.tryPerform(\at, key2).tryPerform(\at, key).notNil) {
								current.put(key2, ~fmtAmps[key2][key].collect { |env|
									env.copy.levels_(env.levels.reverse)
								})
							} {
								f1 = FormantTable.at(key);
								f2 = FormantTable.at(key2);
								current.put(key2,
									~asTransitionEnv.({	|i|
										~calcFormantResp.(f1.blend(f2, i / (~transitionStates - 1)),
											~partials);
									} ! ~transitionStates)
								)
							}
						}
					};
					if(thisThread.isKindOf(Routine)) { 0.004.wait };
				};
				"fmtAmps ready".postln;
			}).play(AppClock)
		},
		asOneAmpEnv: { |fmtAmps|
			fmtAmps.collect { |amp| Env(amp ! 2, #[1]) }
		},
		asTransitionEnv: { |ampMatrix|
			var	time = (1 ! (ampMatrix.size - 1)).normalizeSum;
			ampMatrix.flop.collect { |ampcurve| Env(ampcurve, time) }
		},
		calcFormantResp: { |fmttable, freqs|
			var	resp = 0 ! freqs.size;
			fmttable.flop.do { |flt|
				resp = resp + (flt[1] * ~calcFiltResp.(flt[0], flt[2], freqs));
			};
			resp
		},
		calcFiltResp: { |center, bw, freq|
			var w0, sin_w0, alpha, a0, b0rz, b1, b2, sr, a1, a2, cos_w0, w, sin_w, cos_w, out;
			sr  = 44100;
			w0 = pi * 2 * center / 44100;
			sin_w0 = w0.sin;
			cos_w0 = w0.cos;
			alpha = sin_w0 * sinh(0.34657359027997 * bw * w0 / sin_w0);
			b0rz = (1 + alpha).reciprocal;
			a0 = alpha * b0rz;
			b1 = cos_w0 * 2 * b0rz;
			b2 = (1 - alpha) * b0rz.neg;
		
			a1 = 0.0;
			a2 = a0.neg;
			b1 = b1.neg;
			b2 = b2.neg;
		
			out = freq.asArray.collect { |freq|
				w = 2pi * freq / 44100;
				sin_w = w.sin;
				cos_w = w.cos;
			
				sqrt(
					squared(
						(a0 * squared(cos_w))
						- (a0 * squared(sin_w))
						+ (a1 * cos_w) 
						+ a2
					)
					+ squared(
						(2 * a0 * cos_w * sin_w)
						+ (a1 * (sin_w))
					)
				)
				/ 
				sqrt(
					squared(
						squared(cos_w)
						- squared(sin_w)
						+ (b1 * cos_w)
						+ b2
					)
					+ squared(
						(2 * cos_w * sin_w)
						+ (b1 * sin_w)
					)
				)
			};
			if(freq.size == 0) { out[0] } { out }
		}
			
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



s.waitForBoot {
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
};

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

	~fx = \none;
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
					0.01, Pfuncn({ |ev|
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
					}),  // else nil
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
		Plazy({ |ev|
			Pbind(\tempo, Pclutch(~tempoPat.(ev), Pdiff(Ptime()) > 0))
			<>
			~patternTemplate.(ev)
		}).collect { |ev| ~preprocessNote.(ev) }
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
					\delta, Pfunc({ |ev| ev[\note].dur * ev[\rhyScale] }),
					\legato, BPStream(\legato),
					\sustain, Pfunc({ |ev| ev[\note].length * ev[\rhyScale] * ev[\legato] }),
					\att, BPStream(\att), \dec, BPStream(\dec), \rel, BPStream(\rel),
					\fLowRatio, BPStream(\fLow),
					\chan, ~chan,
					\numCh, 1,
					\fxKey, BPStream(\fx),
					\fxProto, BPStream(\fxProto),
					\busFreeDelay, 3.2,
					\fxPatEv, Pbind(
						\syllable, ~evalEnvir.(\vocKey),
						\pat, Pfunc({ |ev|
							var	fspecs = FormantTable.at(ev[\syllable]),
								fxPat, lockref;
							fxPat = ~fxPool[ev[\fxKey]].(ev);
							Pseq([
								Pn(~xferEvent.(ev, fspecs, lockref = `nil, key), 1),
								if(fxPat.notNil) {
									Pfindur(ev[\sustain],
										fxPat <> Pbind(\protoEvent, \singleSynthPlayNotify,
											\lock, Pfunc({ lockref.value })))
								}
							])
						})
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
				\node, Pfunc({ |ev| ev[\lock].killNodes.asArray.detect(_.isKindOf(Synth)) }),
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
	~gate = Pif(Pfunc({ |n| n > 1 }),
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


s.waitForBoot {
	SynthDef(\bufGrainPanFmlet, { |start, time, bufnum, pan, rate = 1, amp = 1,
			attack = 0.001, decay = 0.02, outbus,
			ffreq = 2000, ffreq2 = -1, fcurve = 2.1, fatk = 0.01, fdec = 0.1, wet = 1,
			hpFreq = -1, lpFreq = 18000|
		var sig, sig2, eg;
		sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0);
		sig = Select.ar(hpFreq < 0, [HPF.ar(sig, hpFreq.clip(20, 20000)), sig]);
		eg = EnvGen.kr(Env.linen(attack, time, decay) /*, doneAction:2 */);
		ffreq2 = Select.kr(ffreq2 < 0, [ffreq2, ffreq]);
		ffreq = EnvGen.kr(Env([ffreq, ffreq2], [time], fcurve * sign(ffreq2 - ffreq)));
		sig2 = Limiter.ar(Formlet.ar(sig, ffreq, fatk, fdec));
		// this filter is so the dry sound doesn't interfere with the resonated one
		sig = LPF.ar(sig, wet.linexp(0, 1, 18000, ffreq));
		sig = XFade2.ar(sig, sig2, wet.madd(2, -1));
		// I also want to make the whole thing sound duller at times
		sig = LPF.ar(sig, lpFreq);
		Out.ar(outbus, Pan2.ar(sig, pan, amp * eg));
		Line.kr(0, 1, time + fdec, doneAction: 2);
	}).add;

	#[bufGrainPanFmlet, bufGrainRLPFPan, partial1bgated, simpleLPCfxPan, simpleLPCfxPan2].do { |key|
		\addRvbOut.eval((key ++ "Dist").asSymbol, SynthDescLib.at(key).def.func).add;
	};
};


(keys: #[master, glrvbmc, lcrvbmc],
copyKeys: #[master, glrvbmc, lcrvbmc, buffers, chan, postMCCreation, calcBar, bar, amps],  // you can override this
sourceFreesMe: true,
bp: \drum1,
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
keys: #[master, glrvbmc, lcrvbmc, clock108],
make: { |name|
	BP(name).free;
	PR(\bufPerc).chuck(BP(name), nil, (
		master: ~master, glrvbmc: ~glrvbmc, lcrvbmc: ~lcrvbmc,
		alwaysReset: true,
		reset: { ~pbindPreAction.reset },
		bufPaths: [(topEnvironment[\sampleDir] +/+ "head/uduSLAP1.wav").standardizePath],
		baseIndices: #[0, 8],
		baseAmp: 1,
		postMCCreation: {
			var	zero = 0 ! 12, temp;
			#[glrvbmc, lcrvbmc].do { |key|
				key.envirGet.tryPerform(\receivesSignalFrom, ~chan);
			};
			~event.put(\glrvbout, ~glrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels })
				.put(\lcrvbout, ~lcrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels })
				.put(\distFar, 20);
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
// 			if(~iMadeMixer ? false) {
// 				~chan.newPostSend(~rvbmc, 0.391);
// 			};
			~fdecCtl ?? { ~fdecCtl = GenericGlobalControl(\fdec, nil, 0.5,  #[0.01, 1.0, exp]) };
			~ffLowCtl ?? { ~ffLowCtl = GenericGlobalControl(\fLow, nil, 2, #[1, 32, \lin, 1]) };
			~ffRangeCtl ?? { ~ffRangeCtl = GenericGlobalControl(\fRange, nil, 8, #[0, 32, \lin, 1]) };
			~wetCtl ?? { ~wetCtl = GenericGlobalControl(\wet, nil, 1) };
			~distCtl ?? { ~distCtl = GenericGlobalControl(\dist, nil, 5, #[5, 20]) };
			~finalLpfCtl ?? {
				~finalLpfCtl = GenericGlobalControl(\finalLpf, nil, 18000, \freq)
			};
			~event.put(\distance, ~distCtl.asMap).put(\lpFreq, ~finalLpfCtl.asMap);

			~ffreq = 52 * Pwhite(~ffLowCtl, ~ffLowCtl.asPattern + ~ffRangeCtl + 0.99).trunc;
			~argPairs = ~argPairs ++ [
				ffreq: Pif(Pkey(\bufIndex) > 0, 18000, BPStream(\ffreq)),
				fdec: ~fdecCtl, 
				wet: Pif(Pkey(\bufIndex) > 0, 0, ~wetCtl.asMap)
			];
			// sibling processes may not init until I'm done
			NotificationCenter.notify(name, \ready);
		},
		useGui: { |vpi| #[fdecCtl, ffLowCtl, ffRangeCtl, wetCtl].do { |key| key.envirGet => VP(vpi) } },
		free: {
			[~glrvbmc, ~lcrvbmc].do { |mc|
				mc.tryPerform(\stopsReceivingFrom, ~chan);
			};
			[~fdecCtl, ~ffLowCtl, ~ffRangeCtl, ~wetCtl, ~distCtl, ~finalLpfCtl].free
		},
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

		def: \bufGrainPanFmletDist
	));
	topEnvironment[\clock108] => BP(name);
}, type: \bp) => Fact(\drum1);

(
keys: #[master, glrvbmc, lcrvbmc, clock108],
source: \drum1,
make: { |name|
	BP(name).free;
	if(BP.exists(~source)) {
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
		copyKeys: Fact(\copyBufPerc).copyKeys ++ #[fdecCtl, ffLowCtl, ffRangeCtl, wetCtl, distCtl, def, finalLpfCtl],
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
				~event.put(\distance, ~distCtl.asMap).put(\lpFreq, ~finalLpfCtl.asMap);
			}	
		)
	));
// 	BP(name).dump;
// 	BP(name).v.tryPerform(\listVars);
	topEnvironment[\clock108] => BP(name);
}, type: \bp) => Fact(\drum2);

(
keys: #[master, glrvbmc, lcrvbmc, clock108],
source: \drum1,
make: Fact(\drum2).v[\make],
makeBP: { |name|
	var parms;
	BP(name).free;
	parms = (
		alwaysReset: true,
		master: ~master, glrvbmc: ~glrvbmc, lcrvbmc: ~lcrvbmc,
		source: ~source,
		reset: { ~pbindPreAction.reset },
		postBufferLoad: {
			#[glrvbmc, lcrvbmc].do { |key|
				key.envirGet.tryPerform(\receivesSignalFrom, ~chan);
			};
			~distCtl = BP(~source).distCtl;
			~finalLpfCtl = BP(~source).finalLpfCtl;
			~event.put(\distance, ~distCtl.asMap).put(\lpFreq, ~finalLpfCtl.asMap);

			~ffreqCtl = GenericGlobalControl(\ffreq, nil, 2000, \freq);
			~argPairs = [ffreq: ~ffreqCtl.asMap];
			NotificationCenter.notify(name, \ready);
		},
		useGui: { |vpi| ~ffreqCtl => VP(vpi) },
		free: { [~ffreqCtl, ~finalLpfCtl].free },
		bufPaths: (topEnvironment[\sampleDir] +/+ "head/*eq-FING*").pathMatch,
		amps: 0,
		barHook: {
			~bufs = { ~buffers.size.rand } ! ~amps.count(_ > 0);
		},
		baseIndices: #[1, 4, 7, 10],
		baseAmp: 1 /* finger-amp */,
		def: \bufGrainRLPFPanDist
	);
	#[postMCCreation, calcBar].do { |key| parms.put(key, BP(~source)[key]) };

	PR(\bufPerc).chuck(BP(name), nil, parms);
	topEnvironment[\clock108] => BP(name);
}, type: \bp) => Fact(\drum3);


// drum4-6
(keys: #[master, glrvbmc, lcrvbmc, clock108],
source: #[drum1, drum3],
make: { |name|
	BP(name).free;
	if(~source.asArray.every { |src| BP.exists(src) }) {
		if(BP(~source.last)[\argPairs].notNil) {
			~makeBP.(name);
		} {
			NotificationCenter.registerOneShot(~source.last, \ready, name, e {
				~makeBP.(name);
			});
			BP(name)
		}
	} {
		"% not loaded, cannot load %".format(~source, name).warn;
	}
},
makeBP: { |name|
	BP(name).free;
	PR(\basicBufferPlayer).chuck(BP(name), nil, (
		bufPaths: nil,
		buffers: ~source.asArray.collect { |bp| BP(bp).buffers }.flat,
		def: \bufGrainPanFmletDist, //\bufGrainRLPFPanDist,
		chan: ~chan,
		inChannels: 2,
		copyCtls: #[fdecCtl, ffLowCtl, ffRangeCtl, wetCtl, distCtl, finalLpfCtl],
		ctlSource: \drum1,
		postMCCreation: {
			#[glrvbmc, lcrvbmc].do { |key|
				key.envirGet.tryPerform(\receivesSignalFrom, ~chan);
			};
			~copyCtls.do { |ckey| ckey.envirPut(BP(~ctlSource)[ckey]) };
			~finalLpfCtl ?? {
				~finalLpfCtl = GenericGlobalControl(\finalLpf, nil, 18000, \freq)
			};
			~event.put(\distance, ~distCtl.asMap).put(\lpFreq, ~finalLpfCtl.asMap);
			~event.put(\glrvbout, ~glrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels })
				.put(\lcrvbout, ~lcrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels })
				.put(\distFar, 20);
		},
		postBufferLoad: BP(\drum1).v[\postBufferLoad],
// 		free: {},
		master: ~master, glrvbmc: ~glrvbmc, lcrvbmc: ~lcrvbmc,
		delta: Pseq(#[0.25, 0.25, 0.5, 0.5], inf),
		bufIndex: Ppatlace([0, Pxrand((1..4), inf)], inf),
		time: Pfunc({ |ev| ~buffers[ev[\bufIndex]].duration }),
		timeConversion: { |time| time * thisThread.clock.tempo },
		amp: Pseq(#[1, 1 /* finger-amp */], inf),
		rate: Place(#[[0.5, 0.6, 0.6, 0.5], 1], inf),
		start: 0,
		pan: ~pan ? 0,
		ffreq: 18000,
		argPairs: [pan: Plazy({ BPStream(\pan) })],
		reset: {
			var	str;
			currentEnvironment.env.keys.do { |key|
				if((str = key.asString).contains("Stream")) {
					~makeStreamForKey.(str[ .. str.size - 7].asSymbol);
				}
			}
		}
	));
	topEnvironment[\clock108] => BP(name);
}, type: \bp) => Fact(\drum4);



// drum7+8

Fact(\drum4).v.copy.putAll((
quant: -1,
makeBP: { |name|
	BP(name).free;
	PR(\drumSubdiv).chuck(BP(name), nil, (
		master: ~master, glrvbmc: ~glrvbmc, lcrvbmc: ~lcrvbmc,
		gest: \ostFilt2,
		source: ~source,
		ctlSource: ~ctlSource	// use same controls as ctlSource
	));
	~quant => BP(name);
	topEnvironment[\clock108] => BP(name);
})) => Fact(\drum7);

// Fact(\drum7) => BP(\drum7);
// Fact(\drum7).chuck(BP(\drum8), nil, (ctlSource: \drum7, quant: #[-1, 1.25]));


PR(\abstractProcess).clone {
	~event = (eventKey: \polySynthPlayer, instrument: \bufGrainRLPFPanDist //,
		// printStoppedStream: true,    // debugging
		// printAllStreamsOnStop: false
	);
	~source = #[drum1, drum3];
	~alwaysReset = true;

	~prep = {
		~chan = MixerChannel(~collIndex, s, 2, 2, outbus: ~master);
		#[glrvbmc, lcrvbmc].do { |key|
			key.envirGet.tryPerform(\receivesSignalFrom, ~chan);
		};
		~event[\chan] = ~chan;
		~buffers = ~source.collect { |key| BP(key).buffers }.flat;
		~pan = 0;
		~lpfreq = 15000;
		~gest_.(~gest);

		~other = if(~collIndex == \drum7) { \drum8 } { \drum7 };
		// ~n is a pattern
		~n = ~n.select { |n|
//[n, BP(~other)[\lastSubdiv], ~lastSubdivTime, BP(~other)[\lastSubdivTime]].debug("test" + ~collIndex);
			n != BP(~other)[\lastSubdiv] or: { ~lastSubdivTime == BP(~other)[\lastSubdivTime] }
		};

		if(~ctlSource.isNil) {
			~accWetCtl = GenericGlobalControl(\accWet, nil, 0.75);
			~fmltWetCtl = GenericGlobalControl(\fmltWet, nil, 0.1);
			~fmltDcyCtl = GenericGlobalControl(\fmltDcy, nil, 0.1, #[0.01, 1, \exp]);
			~ostFiltCtl = GenericGlobalControl(\ostFiltProb, nil, 0.1);
			~ost2AmpCtl = GenericGlobalControl(\ost2Amp, nil, 0, \amp);
			~distCtl = GenericGlobalControl(\distance, nil, 5, #[5, 20]);
			~finalLpfCtl = GenericGlobalControl(\finalLpf, nil, 18000, \freq);
			~messedUpMulCtl = GenericGlobalControl(\messDMul, nil, 1, #[1, 4]);
		} {
			#[accWetCtl, fmltWetCtl, fmltDcyCtl, ostFiltCtl, ost2AmpCtl, distCtl, finalLpfCtl, messedUpMulCtl].do { |k|
				k.envirPut(BP(~ctlSource)[k]);
			};
		};
		~event.put(\distance, ~distCtl.asMap).put(\lpFreq, ~finalLpfCtl.asMap);
		~event.put(\glrvbout, ~glrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels })
			.put(\lcrvbout, ~lcrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels })
			.put(\distFar, 20);
	};

	~freeCleanup = {
		~chan.free;
		if(~ctlSource.isNil) {
			[~accWetCtl, ~fmltWetCtl, ~fmltDcyCtl, ~ostFiltCtl, ~ost2AmpCtl, ~lpfFreqCtl, ~messedUpMulCtl].free;
		};
	};
	~useGui = { |vpi|
		if(~ctlSource.isNil) {
			[/*~accWetCtl,*/ ~fmltWetCtl, ~fmltDcyCtl, ~ostFiltCtl, ~ost2AmpCtl].do { |gc|
				gc => VP(vpi)
			}
		};
	};

	~gest_ = { |gpat|
		\gest.envirPut(gpat.asPattern.collect { |g| ~lastGest = g; g });
		currentEnvironment
	};
	~gest = Pstutter(Pwhite(1, 5, inf), Pseq(#[ost, nhigh], inf));
	~n = Pwhite(2, 8, inf);
	~factor = Pif(Pkey(\n) <= 5, Prand(#[1, 2], inf), Prand(#[2, 4], inf));
	~numBars = Pwhite(2, 4, inf);
	~numAcc = Pwhite(2, 4, inf);
	~restBeats = Pwhite(3, 8, inf) * 0.5;
	~ostFiltFreq = Pswitch1([
		Plazy({ BPStream(\accFreq) }),
		Plazy({ BPStream(\accFreq) * 2.5 * ~fmltWetCtl })
	], Pdict(Dictionary[0.5 -> 0, 0.6 -> 0, 1.0 -> 1], Pkey(\rate), inf, 1));

	~messedUpRatios = Prand([3/2, 4/3, 5/4, 6/5, 9/8], inf);
	~messedUpNumEv = Pwhite(3, 9, inf);
	~messedUpBeats = Plazy({ Pwhite(1, 6, inf) * ~messedUpMulCtl.asPattern.round });

	~gestures = (
		ost: Pbind(
			\delta, Pseq(#[0.25, 0.25, 0.5, 0.5], 2),
			\bufIndex, Ppatlace([0, Pxrand((1..4), inf)], inf),
			\amp, Pseq(#[1, 1 /* finger-amp */], inf),
			\rate, Place(#[[0.5, 0.6, 0.6, 0.5], 1], inf),
			\start, 0,
			\pan, Plazy({ BPStream(\pan) }),
			\ffreq, Plazy({ BPStream(\lpfreq) })
		),
		ost1: Pbind(
			\delta, Pseq(#[0.25, 0.25, 0.5, 0.5], 1),
			\bufIndex, Ppatlace([0, Pxrand((1..4), inf)], inf),
			\amp, Pseq(#[1, 1 /* finger-amp */], inf),
			\rate, Place(#[[0.5, 0.6], 1], inf),
			\start, 0,
			\pan, Plazy({ BPStream(\pan) }),
			\ffreq, Plazy({ BPStream(\lpfreq) })
		),
		ostFilt: Plazy({ |ev|
			Pbindf(~gestures[\ost],
				\instrument, \bufGrainPanFmletDist,
				\wet, Pif(Pbinop('and', ~ostFiltCtl.asPattern.coin, Pkey(\bufIndex) <= 0),
					~fmltWetCtl, 0),
				\ffreq, BPStream(\ostFiltFreq),
				\fdec, ~fmltDcyCtl
			)
		}),
		ostFilt2: Plazy({
			Pbind(
				\instrument, \bufGrainPanFmletDist,
				\delta, Pn(0.25, 12), //Pseq(#[0.25, 0.25, 0.5, 0.5], 2),
				\bufIndex, Pswitch1([0, Pxrand((1..4), inf)],
					Pseq(#[0, 1, 0, 0, 1, 1], inf)
				),
				\amp, Pif(Pkey(\bufIndex) > 0, 1 /* finger-amp */, 1)
					* Pswitch1([1, ~ost2AmpCtl], Pseq(#[0, 0, 0, 1, 0, 1], inf)),
				\rate, Pif(Pkey(\bufIndex) > 0, 1, Pseq(#[0.5, 0.5, 0.6, 0.6, 0.6, 0.5])),
				\start, 0,
				\pan, BPStream(\pan),
				\wet, Pif(Pbinop('and', ~ostFiltCtl.asPattern.coin, Pkey(\bufIndex) <= 0),
					~fmltWetCtl, 0),
				\ffreq, BPStream(\ostFiltFreq),
				\fdec, ~fmltDcyCtl
			)
		}),
		ostFilt2Sync: Plazy({ |ev|
			~gestures[\barsync].(Pn(~gestures[\ostFilt2], inf))
		}),
		ostFilt2Quant: Plazy({ |ev|
			~gestures[\quantsync].(Pn(~gestures[\ostFilt2], inf))
		}),
		ostFiltIn: Plazy({ |ev|
			var	numBars = ~numBarsStream.next(ev);
			Pbindf(Pn(~gestures[\ost], numBars),
				\instrument, \bufGrainPanFmletDist,
				\wet, Env([0, ~fmltWetCtl.value], [numBars * 3]),
				\ffreq, Env([52 * rrand(10, 18), 208].rotate(2.rand), [numBars * 3], \exp),
				\fdec, ~fmltDcyCtl
			)
		}),
		ostFiltOut: Plazy({ |ev|
			var	numBars = ~numBarsStream.next(ev);
			Pbindf(Pn(~gestures[\ost], numBars),
				\instrument, \bufGrainPanFmletDist,
				\wet, Env([~fmltWetCtl.value, 0], [numBars * 3]),
				\ffreq, Env([52 * rrand(10, 18), 208].rotate(2.rand), [numBars * 3], \exp),
				\fdec, ~fmltDcyCtl
			)
		}),
		ostFiltSwell: Plazy({ |ev|
			var	numBars = ~numBarsStream.next(ev);
			Pbindf(Pn(~gestures[\ost], numBars),
				\instrument, \bufGrainPanFmletDist,
				\wet, Env([0, ~fmltWetCtl.value, 0], (numBars * 1.5) ! 2),
				\ffreq, Env([52 * rrand(10, 18), 208].rotate(2.rand), [numBars * 3], \exp),
				\fdec, ~fmltDcyCtl
			)
		}),
		nhigh: Plazy({ |ev| Ppar(~nhighList.(ev)) }),
		ngap: Plazy({ |ev|
			var pats = ~nhighList.(ev), prob = rrand(0.4, 0.8);
			Ppar(pats.collect { |pat|
				Pbindf(pat,
					\instrument, Pseq([\bufGrainPanFmletDist,
						Pif(Pwhite(0.0, 1.0, inf) < prob, \bufGrainPanFmletDist, \rest)
				]))
			})
		}),
		nhighAcc: Plazy({ |ev|
			Ppar(~nhighList.(ev) ++ ~accEvent.(ev))
		}),
		ngapAcc: Plazy({ |ev|
			var pats = ~nhighList.(ev), prob = rrand(0.4, 0.8);
			Ppar((pats.collect { |pat|
				Pbindf(pat,
					\instrument, Pseq([\bufGrainPanFmletDist,
						Pif(Pwhite(0.0, 1.0, inf) < prob, \bufGrainPanFmletDist, \rest)
				]))
			}) ++ ~accEvent.(ev))
		}),
		oneAcc: Plazy({ |ev|
			~accEvent.(ev, Pn(~restBeatsStream.next(ev), 1))
		}),

		fiveTemplate: {
			|	delta(Pseq(#[3, 2], { rrand(2, 4) })),
				rate(Pswitch1([0.75, 0.9, Pseq(#[1.25, 1], inf)], Pkey(\flag))),
				double(Pwhite(0.0, 1.0, inf) < 0.02),
				ffreq(52 * Pwhite(4, 8, inf) *.x Pgeom(1, Pwhite(0.7, 0.9), Pkey(\num).asStream))
			|
			var	lg;
			Plazy({ |ev|
				Pfunc({ |ev|
					if(ev[\double]) {
						ev[\delta] = ev.delta * 0.5;
						ev.copy.yield;
					};
					ev
				})
				<>
				Pbind(
					\instrument, \bufGrainPanFmletDist,
					\delta, 0.25,
					\flag, 0,
					\num, Psmartstutter(Pfunc(_.value),
						delta.collect { |num, ev|
							if(ev[\flag] == 0) {
								ev[\flag] = if(num == 1) { 1 } { 2 };
							};
							num
						}
					),
					\prevFlag, Pdelay(Pkey(\flag)),
					\busyFlag, Pfunc({ |ev| ev[\flag] + ev[\prevFlag] > 0 }),
					\bufIndex, Pclutch(Pxrand((1..4), inf), Pkey(\busyFlag)),
					\amp, Pswitch1(#[0.4, 1 /* finger-amp */], Pkey(\flag).sign),
					\rate, rate,
					\start, 0,
					\pan, BPStream(\pan),
					\ffreq, ffreq,
					\double, double,
			 		\wet, case
						{ (lg = ~lastGest.asString).contains("1Acc") }
							{	Pseries.fromEndpoints(0, ~fmltWetCtl.value,
									delta.asStream.nextN(100, ev).select(_.notNil).sum)
							}
						{ lg.contains("Acc") } { 0 }
						{ ~fmltWetCtl }
				)
			});
 		},
		five: Plazy({ |ev|
			~gestures[\fiveTemplate].(
				Prand([
					Pseq([Psetpre(\flag, 3, Pn(3, 1)), 2], 1), 
					Pseq([Psetpre(\flag, 3, Pn(2, 1)), 1, 2], 1)
				], 1 /* { rrand(2, 4) } */),
				Pswitch1([0.75, 0.9, 1, 1.25], Pkey(\flag))
			)
		}),		
		seven: Plazy({ |ev|
			~gestures[\fiveTemplate].(
				Prand([
					Pseq([Psetpre(\flag, 3, Pn(3, 1)), 2, 2], 1), 
					Pseq([Psetpre(\flag, 3, Pn(2, 1)), 1, 2, 2], 1)
				], 1 /* { rrand(2, 4) } */),
				Pswitch1([0.75, 0.9, 1, 1.25], Pkey(\flag))
			)
		}),
		fiveAcc: Plazy({ |inEv|
			var	accStream = ~accEvent.(inEv, 0).asStream;
			~gestures[\five].collect { |ev|
				if(ev[\flag] > 1) {
					inEv = accStream.next(inEv).yield;
				};
				ev
			};
		}),
		sevenAcc: Plazy({ |inEv|
			var	accStream = ~accEvent.(inEv, 0).asStream;
			~gestures[\seven].collect { |ev|
				if(ev[\flag] > 1) {
					inEv = accStream.next(inEv).yield;
				};
				ev
			};
		}),
		five1Acc: Plazy({ |inEv|
			var	accStream = ~accEvent.(inEv, Pn(0, 1)).asStream, accEv;
			~gestures[\five].collect { |ev|
				if(ev[\flag] > 1 and: { (accEv = accStream.next(inEv)).notNil }) {
					inEv = accEv.yield;
				};
				ev
			};
		}),
		seven1Acc: Plazy({ |inEv|
			var	accStream = ~accEvent.(inEv, Pn(0, 1)).asStream, accEv;
			~gestures[\seven].collect { |ev|
				if(ev[\flag] > 1 and: { (accEv = accStream.next(inEv)).notNil }) {
					inEv = accEv.yield;
				};
				ev
			};
		}),
		three: Plazy({
			~gestures[\fiveTemplate].(
				Pwrand([
					Psetpre(\flag, 3, Pn(3, 1)), 
					Pseq([Psetpre(\flag, 3, Pn(2, 1)), 1], 1)
				], #[0.8, 0.2], 1),
				Pswitch1([0.75, 0.9, 1, 1.25], Pkey(\flag))
			)
		}),
		threeAcc: Plazy({ |inEv|
			var	accStream = ~accEvent.(inEv, 0).asStream;
			~gestures[\three].collect { |ev|
				if(ev[\flag] > 1) {
					inEv = accStream.next(inEv).yield;
				};
				ev
			};
		}),
		threePl1: Plazy({ |ev|
			Pseq([
				~accEvent.(ev, Pn(0, 1)),
				~gestures[\fiveTemplate].(
					Pseq([
						1,
						Pwrand([
							Psetpre(\flag, 3, Pn(3, 1)),
							Pseq([Psetpre(\flag, 3, Pn(2, 1)), 1], 1)
						], #[0.8, 0.2], 1),
					]),
					Pswitch1([0.75, 0.9, 1, 1.25], Pkey(\flag))
				)
			])
		}),
		restify: { |pat|
			Pbindf(pat, \instrument, Pif(
				Pfunc({ |ev| ev[\flag].isNil or: { ev[\flag] >= 2 } }),
				Pkey(\instrument), \rest
			))
		},
		barsync: { |pat|
			var	q = thisThread.clock.nextBar - thisThread.beats - ~leadTime;
			// stupid damn floats: 1.99 - 1.99 != 0.0
		 	if(q.abs < 0.002) { q = thisThread.clock.beatsPerBar };
			Psync(pat, q, q);
		},
		quantsync: { |pat|
			var	q = ~quant.nextTimeOnGrid(~clock) - thisThread.beats - ~leadTime;
			if(q.abs < 0.002) {
				q = ~quant.asTimeSpec.quant;
				if(q < 0) { q = q.neg * ~clock.beatsPerBar };
			};
			Psync(pat, q, q);
		},
		threePl1Rest: Plazy({ |ev|
			~gestures[\restify].(~gestures[\threePl1])
		}),
		threePl1Sync: Plazy({ |ev|
			var	psync = ~gestures[\barsync].(Psym(Pseq([\threePl1, Pn(\threeRest, inf)], inf), ~gestures));
			Pbindf(psync,
				\wet, Env([0, ~fmltWetCtl.value], [psync.quant]),
				\ffreq, Env([52 * rrand(10, 21), 208], [psync.quant], \exp)
			)
		}),
		threeRest: Plazy({ |ev|
			~gestures[\restify].(~gestures[\three])
		}),
		threeAccRest: Plazy({ |ev|
			~gestures[\restify].(~gestures[\threeAcc])
		}),
		fiveRest: Plazy({ |ev|
			~gestures[\restify].(~gestures[\five])
		}),
		fiveAccRest: Plazy({ |ev|
			~gestures[\restify].(~gestures[\fiveAcc])
		}),
		sevenRest: Plazy({ |ev|
			~gestures[\restify].(~gestures[\seven])
		}),
		sevenAccRest: Plazy({ |ev|
			~gestures[\restify].(~gestures[\sevenAcc])
		}),
		threesync: Plazy({ |ev|
			~gestures[\barsync].(Psym(Prand(#[three, threeAcc, threeRest], inf), ~gestures))
		}),
		randsync: Plazy({ |ev|
			~gestures[\barsync].(Psym(Prand(#[three, threeAcc, threeRest, five, fiveAcc, seven, sevenAcc], inf), ~gestures));
		}),
		randquant: Plazy({ |ev|
			~gestures[\quantsync].(Psym(Prand(#[three, threeAcc, threeRest, five, fiveAcc, seven, sevenAcc], inf), ~gestures));
		}),

		// new for march: really disintegrate the rhythm
		messedUp: Plazy({ |inEv|
			var	accEv = ~accEvent.(inEv, Pkey(\delta)).asStream,
				once = false,
				dur,
				pat = Pchain(
					Pfunc({ |ev|
						var	x;
						if(ev[\doAccent]) {
							ev = accEv.next(ev).put(\wet, 0.55);
							if(once) { ev } {
								once = true;
								x = ~messedUpRatiosStream.nextN(3, ev);
								x.doAdjacentPairs { |a, b, i| x[i+1] = a*b };
								ev.put(\ffreq, ev[\ffreq] * x)
									.put(\ffreq2, ev[\ffreq2] * x);
							};
						} { ev }
					}),
					Pbind(
						\bufIndex, Pswitch1([0, Pxrand((1..4), inf)],
							Pwrand(#[0, 1], Pif(Pkey(\delta) >= (~messedUpMulCtl.asPattern * 0.25), #[0.75, 0.25], #[0.1, 0.9]), inf)
						),
						// \amp, 1,
						\amp, Pn(Plazy({ |ev|
							var	bool = 0.3.coin;
							if(bool) {
								Pn(1, ev[\numInSeg])
							} {
								Pgeom.fromEndpoints(1, rrand(0.2, 0.5), ev[\numInSeg])
							}
						}), inf),
						\rate, Pif(Pkey(\bufIndex) > 0, 1, Prand(#[0.5, 0.6], inf)),
						\start, 0,
						\pan, Plazy({ BPStream(\pan) }),
						\ffreq, Plazy({ BPStream(\lpfreq) }),
						\wet, 0
					),
					Pbind(
						\doAccent, false,
						\delta, Pn(Plazy({ |ev|
							ev[\numInSeg] = rrand(3, 9);
							ev[\doAccent] = true;
							Pgeom.fromEndpoints(*
								[rrand(0.4, 0.6), rrand(0.08, 0.2)].rotate(2.rand)
								++ [ev[\numInSeg]]
							) * ~messedUpMulCtl
						}), inf)
					)
				);
			if(~leadTime > 0) {
				~lastMessedUpBeats = dur = ~messedUpBeatsStream.next(inEv)
			} {
				dur = BP(~ctlSource).lastMessedUpBeats;
			};
			Pfindur(dur, pat)
		})
	);

	~nhighList = { |ev|
		var n = ~nStream.next(ev),
			factor = ~factorStream.next(ev.put(\n, n)),
			rotate = 2.rand,
			temp,
			femul = rrand(1, 4),
			fenv = ((if(0.8.coin) {
				Env([n, 2], [factor], \exp)
			} {
				Env(temp = [n, 2].rotate(2.rand); temp ++ temp[0], (factor * 0.5) ! 2, \exp)
			}).asStream * femul),
			amul = Pgeom.fromEndpoints(1, 2/n, n),
			ffreq = 52 * [n, fenv];
		// I don't want the same subdivision in both parts unless they start at the same time
		// So, save the subdivision and time so the other can check
		~lastSubdiv = n;
		~lastSubdivTime = thisThread.beats;
		{ |i|
			Pbind(
				\instrument, \bufGrainPanFmletDist,
				\delta, Pn(factor / n, n),
				\bufIndex, Pxrand((1..4), inf),
				\hpFreq, Pif(Pbinop('==', Pkey(\bufIndex), 3), -1, 276),
				\amp, ~fmltWetCtl.asPattern.linexp(0, 1, 1, 0.4, \none) * amul,
				\rate, 1,
				\start, 0,
				\pan, (#[-0.5, 0.5].wrapAt(i + rotate) + BPStream(\pan)).clip(-1, 1),
				\ffreq, ffreq[i],
				\fdec, 0.15 / Pkey(\ffreq).explin(104, 1700, 3, 0.75, \none),
				\wet, ~fmltWetCtl
			)
		} ! 2
	};

	~accRate = Prand(#[0.5, 0.6], inf);
	~accFreq = 52 * Pwhite(2, 5, inf);
	~accFreq2 = (Pkey(\ffreq) * Pwhite(2, 4, inf)).wrap(52, 260);
	~accDec = 0.25;
	~accCurve = Pwhite(3.0, 7.0, inf);
//	~accWet = 0.75;

	~accEvent = { |ev, delta(Pn(0.1, 1))|
		Pbind(
			\instrument, \bufGrainPanFmletDist,
			\delta, delta,
			\bufIndex, 0,
			\amp, 1,
			\rate, BPStream(\accRate),
			\start, 0,
			\pan, BPStream(\pan),
			\ffreq, BPStream(\accFreq),
			\ffreq2, BPStream(\accFreq2),
			\fdec, BPStream(\accDec),
			\fcurve, BPStream(\accCurve),
			\wet, ~accWetCtl // BPStream(\accWet)
		)
	};

	~asPattern = {
		~makeStreamForKey.(\gest);
		~makeStreamForKey.(\n);
		~makeStreamForKey.(\factor);
		~makeStreamForKey.(\numBars);
		~makeStreamForKey.(\restBeats);
		#[messedUpRatios, messedUpNumEv, messedUpBeats, numAcc].do { |key|
			(key ++ "Stream").asSymbol.envirGet ?? { ~makeStreamForKey.(key) };
		};
		// w/o Pif, Event.silent results from Ppar cause this to die
		Pif(Pfunc({ |ev| ev[\type] == \rest }), Pfunc({ |ev| ev }),
			Pbind(
				\bufnum, Pindex(~buffers, Pkey(\bufIndex), inf),
				\time, Pfunc({ |ev| ~buffers[ev[\bufIndex]].asArray.collect(_.duration) })
			)
		)
		<>
		PnNilSafe(
			Plazy({
				thisThread.clock.beats.debug("% beats".format(~collIndex));
				~keepGoing = true;
				Pwhile1({ |proto, ev|
					// ~keepGoing or: { ev.delta == 0 }
					if(~keepGoing) { true }
						{ /*ev.delta.debug("~keepGoing = false; delta"); ev.debug;*/ ev.delta == 0 }
				},
					~gestures[~gestStream.next]
				)
			}),
			inf, 3  // 3 == don't force a stop on the first empty embed
		);
	}
} => PR(\drumSubdiv);



(
keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		master: ~master, glrvbmc: ~glrvbmc, lcrvbmc: ~lcrvbmc,
		dir: (topEnvironment[\sampleDir] ?? { Document.current.path.dirname.dirname +/+ "samples" })
			+/+ "feet",
		lpcPath: "words-ana3.lpc.aif",
		labelPath: "words-labels.txt",
		audioPath: "words-mono.aiff",
		event: (eventKey: \polySynthBusLock),
		tun: PR(\counterpoint).tun,
	
		userprep: {
			~wt = Buffer.allocConsecutive(8, s, 2048, 1, { |buf, i|
				var	amps = 1 ! 18,	// c. 800 Hz top freq, just for test
					indices = (1..17).scramble.keep(rrand(9, 12));
				indices.do { |i| amps[i] = rrand(0.0, 0.1) };
				buf.sine1Msg(amps)
			});
	
			~event.put(\glrvbout, ~glrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels })
				.put(\lcrvbout, ~lcrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels })
				.put(\distFar, 20);

			~lpcb = Buffer.readAndQuery(s, ~dir +/+ ~lpcPath);
			~pt = TabFileReader.read(~dir +/+ ~labelPath);
			~pt = ~pt.do { |pt| #[0, 1, 3, 4].do { |i| pt[i] = pt[i].asFloat } };
			SoundFile.use(~dir +/+ ~audioPath, { |file| ~voxdur = file.duration });

			~ampCtl = GenericGlobalControl(\amp, nil, 1, \amp);
		},
		userfree: { [~wt, ~lpcb, ~ampCtl].free },
	
		degree: Pwhite(36, 44, inf) -.x Pseries(0, Pwhite(1, 7, 2), inf).clump(2),
		mode: \ab,
		bufmod: Pwhite(0, Pfunc({ ~wt.size - 1.001 }), inf),
		amp: Pexprand(0.5, 1, inf),
		delta: Pwrand(#[0.25, 0.5, 0.75, 1], #[1, 4, 3, 1].normalizeSum, inf),
		sustain: Pswitch1([
			Pexprand(0.6, 0.8, inf),
			Pexprand(1.0, 2.7, inf)
		], Pwrand(#[0, 1], #[0.7, 0.3], inf)),
	
		degToCps: Pfunc({ |ev|  // ev[\degree] should be a 2-item array
			var	deg = ev[\degree].unmapMode(ev[\mode]),
				fr = ~tun.cps(deg), ratio;
			if(fr.size > 1) {
				ratio = fr.reduce('/');
				if(ratio < 1.0) { ratio = ratio.reciprocal };
				// if interval is not tuned close to pure, switch to alternate scale
				if(ratio.asFraction[1] > 16) {
					fr = ~tun.cps(deg + 0.01)
				} { fr };
			} {
				fr
			}
		}),
	
		lpcDef: \simpleLPCfxPanDist,
		lpcStart: Pkey(\ptstart), // Pwhite(Pkey(\ptstart), Pkey(\ptend) - Pkey(\time), inf),
		lpcEnd: Pkey(\ptend), // Pkey(\start) + Pkey(\time),
// 		lpcPan: Pwhite(-1.0, 1.0, inf),
		lpcPan: sin(Ptime() * (2pi / rrand(8.8, 11.1))),
		lpcDist: sin(Ptime() * (2pi / rrand(6.8, 10.1))).linlin(-1, 1, 5, 20),
		lpcAtt: 0.05,
		lpcDec: 0.05,
	
		lpcEvPat: Plazy({
			/*Debug*/Pbind(
				\instrument, BPStream(\lpcDef),
				\lpcbuf, ~lpcb,
				\voxdur, ~voxdur,
				\pt, Pxrand(~pt, inf),
				#[ptstart, ptend], Pkey(\pt),
				\start, BPStream(\lpcStart),
				\end, BPStream(\lpcEnd),
				// \time should be populated by sanitizeEvent
				\amp, ~ampCtl.asMap,
				\pan, BPStream(\lpcPan),
				\distance, BPStream(\lpcDist),
				\attack, BPStream(\lpcAtt),
				\decay, BPStream(\lpcDec)
			) <> Pfunc({ |ev| ~sanitizeEvent4lpc.(ev, (distFar: \distFar,
				glrvbout: \glrvbout, lcrvbout: \lcrvbout)) ?? { ev } })
		}),
		objects: { (
			wtblip: (
				def: (  // this looks funny but is legal! expression sequence returns last result
					WrapInstr("osc2.vosc3percEnv", { |egAtk = 0.01, egDcy = 0.2|
						WrapInstr("osc2.vosc3").wrap((nil ! 4) ++ Env.adsr(egAtk, egDcy, 0, 0.01));
					}, nil ! 2);
					WrapPatch("osc2.vosc3percEnv", [nil, nil, nil, KrNumberEditor(1, #[0, 1]).lag_(nil),
						~wt.first.bufnum, nil, nil, nil, `1.003])
				),
				args: [
					degree: BPStream(\degree),
					mode: BPStream(\mode),
					freq: BPStream(\degToCps),
					bufmod: BPStream(\bufmod),
					vsens: 1,
					gate: BPStream(\amp),
					egAtk: 0.01,
					egDcy: Pkey(\sustain)
				]
			)
		) },
	
		superPattern: PR(\basicSynthChooser).v[\asPattern],
		asPattern: {
			/*Debug*/Pbind(\lpcEv, ~lpcEvPat) <> ~superPattern.()
	// 		Pbindf(~superPattern.(),
	// //			\lpcProto, \singleSynthPlayer,
	// 			\lpcEv, ~lpcEvPat
	// 		)
		},
		sanitizeEvent4lpc: { |ev, keys((time: \sustain))|
			var	newEv = ();
			keys.keysValuesDo { |k, v|
				newEv[k] = ev[v];
			};
			newEv
		}
	));
	// will play on same clock as drums, and needs to stay in sync
	1 => BP(name);
}, type: \bp) => Fact(\int);



// face dance

// bloops
(keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		master: ~master,
		glrvbmc: ~glrvbmc,
		lcrvbmc: ~lcrvbmc,
		userprep: {
			~noisedata = Signal.fill(1024, { 1.0.rand2 });
			~noisebuf = Buffer.sendCollection(s, ~noisedata.asWavetable, 1, 0.05);
			~sbufs = Buffer.allocConsecutive(6, s, 1024, 1, { |buf, i|
				buf.chebyMsg((0 ! (i*2+1)).put(i*2, 1).put(0, -1))
			});
			#[glrvbmc, lcrvbmc].do { |key|
				key.envirGet.tryPerform(\receivesSignalFrom, ~chan);
			};
			~event.proto = topEnvironment[\rvbEvent];
		},
		userfree: {
			[~noisebuf, ~sbufs].free;
			#[glrvbmc, lcrvbmc].do { |key|
				key.envirGet.tryPerform(\stopsReceivingFrom, ~chan);
			};
		},
		// synth: ,
		delta: Pwhite(1.2, 2.3, inf),
		buzzEnv: [
			Env.perc(0.05, 0.95),
			Env.perc(0.95, 0.05),
			Env(#[0, 1, 0.25, 1, 0], #[0.05, 0.2, 0.7, 0.05], #[4, -4, 4, -4]),
			Env.linen(0.2, 0.4, 0.4)
		],
	//	sustain: ,
		objects: { (
			sinb: (
				def: \addRvbOut.eval(\dsinbloop, { |freq1 = 50, freq2 = 900, fcurve = 0, time = 1, fHoldPct = 0,
					amp1 = 1, amp2 = 1, noiseBlend = 0.1, noiseFmul = 1, noisePreamp = 1, rq = 1.0,
					normAmp = 0.5, pan = 0, pan2 = 0|
					var	freq = EnvGen.kr(Env([freq1, freq1, freq2], [fHoldPct, 1 - fHoldPct], fcurve),
							timeScale: time),
						preAmp = Line.kr(amp1, amp2, time),
						sig = XFade2.ar(SinOsc.ar(freq), BPF.ar(PinkNoise.ar, freq * noiseFmul, rq, noisePreamp),
							noiseBlend.madd(2, -1), preAmp),
						postAmp = normAmp / preAmp * (preAmp+1),
						env = NamedControl.kr(\env, (0 ! 20).overWrite(Env.linen(0.01, 0.98, 0.01).asArray)),
						eg = EnvGen.kr(env, timeScale: time, doneAction: 2);
					Pan2.ar(sig.distort, Line.kr(pan, pan2, time), postAmp * eg)
				}),
				args: [
					distance: Pexprand(0.01, 1.0, inf).linlin(0.01, 1.0, 20, 5),
					time: Pexprand(0.15, 0.75, inf),
					freq1: Pexprand(150, 400, inf),
					freq2: Pkey(\freq1) * (Pwhite(1.8, 3.0, inf) pow: Prand(#[-1, 1], inf)),
					fcurve: 2.1 * sign(Pkey(\freq2) - Pkey(\freq1)),
					fHoldPct: Pwhite(0.2, 0.8, inf),
					amp1: Pwhite(4.0, 8.0, inf),
					amp2: Pkey(\amp1) * Pwhite(8.0, 20.0, inf),
					noiseBlend: Pexprand(0.1, 0.4, inf),
					noiseFmul: Pwhite(2.0, 5.0, inf),
					noisePreamp: Pwhite(3.0, 9.0, inf),
					rq: 1 - Pexprand(0.05, 0.95, inf),
					normAmp: 0.8,
					pan: Pwhite(0.6, 1.0, inf) * Prand(#[-1, 1], inf),
					pan2: Pwhite(0.6, 1.0, inf) * Pkey(\pan).sign.neg,
					env: Pfunc({ ~buzzEnv.choose })
				]
			),
			oscb: (
				def: \addRvbOut.eval(\doscbloop, { |outbus, bufnum, freq1 = 50, freq2 = 900, fcurve = 0, time = 1, fHoldPct = 0,
					amp1 = 1, amp2 = 1, noiseBlend = 0.1, noiseFmul = 1, noisePreamp = 1, rq = 1.0,
					normAmp = 0.5, pan = 0, pan2 = 0|
					var	freq = EnvGen.kr(Env([freq1, freq1, freq2], [fHoldPct, 1 - fHoldPct], fcurve),
							timeScale: time),
						preAmp = Line.kr(amp1, amp2, time),
						sig = BPF.ar(COsc.ar(bufnum, freq, ExpRand(0.5, 9.0)), freq, rq, preAmp),
						postAmp = normAmp / preAmp * (preAmp+1),
						env = NamedControl.kr(\env, (0 ! 20).overWrite(Env.linen(0.01, 0.98, 0.01).asArray)),
						eg = EnvGen.kr(env, timeScale: time, doneAction: 2);
					Pan2.ar(sig.distort, Line.kr(pan, pan2, time), postAmp * eg)
				}),
				args: [
					bufnum: ~noisebuf,
					distance: Pexprand(0.01, 1.0, inf).linlin(0.01, 1.0, 20, 5),
					time: Pexprand(0.15, 0.75, inf) * 3,
					delta: Pkey(\time) + Pwhite(0.8, 1.8, inf),
					freq1: Pexprand(90, 200, inf),
					freq2: Pkey(\freq1) * (Pwhite(1.8, 3.0, inf) pow: Prand(#[-1, 1], inf)),
					fcurve: 2.1 * sign(Pkey(\freq2) - Pkey(\freq1)),
					fHoldPct: Pwhite(0.2, 0.8, inf),
					amp1: Pwhite(4.0, 8.0, inf),
					amp2: Pkey(\amp1) * Pwhite(8.0, 20.0, inf),
					noiseBlend: Pexprand(0.1, 0.4, inf),
					noiseFmul: Pwhite(2.0, 5.0, inf),
					noisePreamp: Pwhite(3.0, 9.0, inf),
					rq: 1 - Pexprand(0.05, 0.95, inf),
					normAmp: 0.8,
					pan: Pwhite(0.6, 1.0, inf) * Prand(#[-1, 1], inf),
					pan2: Pwhite(0.6, 1.0, inf) * Pkey(\pan).sign.neg,
					env: Pfunc({ ~buzzEnv.choose })
				]
			),
			buzz: (
				def: \addRvbOut.eval(\lowbuzz, { |freq1 = 50, freq2 = 900, fcurve = 0, time = 1,
						fHoldPct = 0, pwidth = 0.1, ffreqMul = 9,
						chspeed = 0.448, chwidth = 0.005275, chdelay = 0.0681, chdecay = 0.75,
						sbufbase, sbufi1, sbufi2, useLine = 1,
						pan = 0, pan2 = 0, amp = 0.75|
					var	freq = EnvGen.kr(Env([freq1, freq1, freq2], [fHoldPct, 1 - fHoldPct], fcurve),
							timeScale: time),
						sig = Pulse.ar(freq, pwidth),
						sbufi = Select.kr(useLine > 0, [
							// ~sbufs exists before this runs
							SinOsc.kr(XLine.kr(Rand(9.0, 15.0), Rand(0.1, 0.5), time))
								.range(0, ~sbufs.size-1.01),
							Line.kr(sbufi1, sbufi2, time),
						]),
						sb1 = sbufi.round(2),
						sbFrac2 = sbufi - sb1,
						sb2 = sb1 + sbFrac2.sign,
						env = NamedControl.kr(\env, (0 ! 20).overWrite(Env.linen(0.02, 0.96, 0.02).asArray));
					sig = LPF.ar(sig, (freq * ffreqMul).clip(20, 18000));
					sig = Shaper.ar(sbufbase + [sb1, sb2], sig.clip(-1.0, 1.0));
					sig = XFade2.ar(*(sig ++ [sbFrac2.abs.madd(2, -1)]));
					sig = sig + CombL.ar(sig, 0.2, SinOsc.kr(chspeed, 0, chwidth, chdelay).min(0.1), chdecay);
					pan = Line.kr(pan, pan2, time);
					Pan2.ar(sig, pan, amp * EnvGen.kr(env, timeScale: time, doneAction: 2))
				}),
				args: [
					distance: Pwhite(5.0, 9.0, inf),
					time: Pexprand(1.2, 2.7, inf),
					delta: Pkey(\time) + Pwhite(0.8, 1.8, inf),
					freq1: Pexprand(45, 70, inf),
					freq2: Pexprand(45, 70, inf),
					pwidth: Pwhite(0.1, 0.4, inf),
					fcurve: 2.1 * sign(Pkey(\freq2) - Pkey(\freq1)),
					fHoldPct: Pif(Pkey(\freq1) > Pkey(\freq2), Pwhite(0.1, 0.4, inf),
						Pwhite(0.6, 0.8, inf)),
					ffreqMul: Pwhite(12.0, 36.0, inf),
					amp: 0.8,
					pan: Pwhite(0.6, 1.0, inf) * Prand(#[-1, 1], inf),
					pan2: Pwhite(0.6, 1.0, inf) * Pkey(\pan).sign.neg,
					sbufbase: ~sbufs.first.bufnum,
					sbufi1: Pwhite(0, ~sbufs.size - 1.01, inf),
					sbufi2: Pwhite(0, ~sbufs.size - 1.01, inf),
					sbufi1: Prand(#[0, 4.99], inf),
					sbufi2: Pif(Pwhite(0.0, 1.0, inf) < 0.6, 4.99 - Pkey(\sbufi1), Pkey(\sbufi1)),
					useLine: Pwhite(-0.5, 1.5, inf),  // 1/4 chance of wobbly
					env: Pfunc({ ~buzzEnv.choose })
				]
			)
		) }
	));
	0 => BP(name);
}, type: \bp) => Fact(\bloops);

// creaks
PR(\abstractProcess).clone {
	~event = (eventKey: \singleSynthPlayer);
	~def = \bufGrain2Dist;
	~dir = topEnvironment[\sampleDir];
	~path = "head/norm-29690_HerbertBoland_Creak_3.wav";

	~coords = Plazy({ Pn(~pt[2][..1], inf) });
	~rate = Pwhite(0.4, 0.75, inf);
	~pct = Pwhite(0.1, 0.17, inf);
	~start = Pfunc({ |ev| (ev[\coords] + (ev[\pct] * #[1, -1])).reduce(\rrand) });
	~end = Pkey(\start) + Pkey(\pct);
	~trail = false;
	~num = 2;
	~gest = \squeaks;
	~rest = Pwhite(1.5, 3.0, inf);
	~dist = Pwhite(5.0, 20.0, inf);
	~amp = 1; // 10.dbamp;
	~delta = Pkey(\time);
	~continuous = false;

	#[master, glrvbmc, lcrvbmc].do { |key|
		key.envirPut(topEnvironment[key]);
	};

	~prep = {
		if(~chan.isNil) {
			~iMadeStuff = true;
			~chan = MixerChannel(~collIndex, s, 2, 2, outbus: ~master);
			#[glrvbmc, lcrvbmc].do { |key|
				key.envirGet.tryPerform(\receivesSignalFrom, ~chan);
			};
			~buf = Buffer.readAndQuery(s, ~dir +/+ ~path);
			\addRvbOut.eval(\bufGrain2Dist, SynthDescLib.at(\bufGrain2).def.func).add;
		} {
			~iMadeStuff = false;
		};
		~event.put(\chan, ~chan).proto_(topEnvironment[\rvbEvent].proto);
		~readLabels.();
	};
	~freeCleanup = {
		if(~iMadeStuff) {
			#[glrvbmc, lcrvbmc].do { |key|
				key.envirGet.tryPerform(\stopsReceivingFrom, ~chan);
			};
			[~buf, ~chan].free;
		};
	};
	~gestures = (
		squeak: { |ev| ~makeOne.(~parmsPatStream.next(ev).put(\num, #[2, 4].choose)) },
		squeakfall: { |ev|
			~makeOne.(~parmsPatStream.next(ev)
				.put(\num, rrand(12, 24))
				.put(\trail, true)
			)
		},
		squeaks: { |ev|
			var	n = rrand(2, 5), parms,
			saveDelta = ~delta, updater;
			// n-1: revert to regular delta in last event
			// ~override.(\delta, Pkey(\time) + Pn(rrand(0.25, 0.55), n-1), false);
			~delta = Pkey(\time) + Pn(rrand(0.05, 0.12), n);
			parms = ~parmsPatStream.next(ev);
			parms.put(\num, n)
				.put(\rate, rrand(0.35, 0.65))
				.put(\pct, rrand(0.06, 0.09) * parms[\rate])
				.put(\coords, ~pt[#[0, 1, 3, 4].choose][..1]);
			updater = Updater(BP(~collIndex), e { |obj, what, more|
				if(more == \stopped) {
					updater.remove;
					~delta = saveDelta;
				}
			});
			~makeOne.(parms);
		},
		smoothsqueaks: { |ev|
			var	n = rrand(2, 6) * 2, parms;
			parms = ~parmsPatStream.next(ev);
			parms.put(\num, n)
				.put(\rate, rrand(0.4, 0.75))
				.put(\pct, rrand(0.07, 0.175) * parms[\rate])
				.put(\coords, ~pt[#[2, 3].choose][..1]);
			~makeOne.(parms)
		}
	);
	~asPattern = {
		~gestStream ?? { ~makeStreamForKey.(\gest) };
		~parmsPatStream ?? { ~makeStreamForKey.(\parmsPat) };
		Pseq([
			Plazy({ |ev|
				var	g = ~gestStream.next(ev);
				g !? { ~gestures[g].value(ev) }
			}),
			Pif(Pfuncn({ ~continuous }), BPStream(\rest), 0)
		], if(~continuous) { inf } { 1 })
	};
	~parmsPat = Plazy({
		Pbind(
			\coords, BPStream(\coords),
			\rate, BPStream(\rate),
			\pct, BPStream(\pct) * Pkey(\rate),
			\start, BPStream(\start),
			\end, BPStream(\end),
			\trail, BPStream(\trail),
			\num, BPStream(\num), //.roundUp(2),
			\dist, BPStream(\dist)
		)
	});
	~makeOne = { |parms|
		var	coords, pct, start, end, rate, num, dist, forwback;
		parms.use {
			coords = ~coords;
			rate = ~rate;
			pct = ~pct;
			start = ~start;
			end = ~end;
			num = ~num;
			dist = ~dist;
			forwback = ~forwback;
		};
		Pseq([
			Pbind(
				\instrument, Pn(~def, num),
				\bufnum, ~buf.bufnum,
				\distance, ~dist, // Pseries.fromEndpoints(startd, 25-startd, num),
				\pan, 0, //rrand(-0.5, 0.5),
				\amp, BPStream(\amp),
				\rate, rate * Pseq(#[1, -1], inf, forwback ? 0),
				\start, ~buf.sampleRate * Pif(Pkey(\rate) > 0, start, end),
				\time, pct / Pkey(\rate).abs,
				\delta, BPStream(\delta),
				#[attack, decay], Pkey(\time) * #[0.12, 0.12]
			),
			(
				type: if(parms[\trail] ? false) { \note } { \rest },
				instrument: ~def,
				bufnum: ~buf.bufnum,
				distance: dist, // 25-startd,
				pan: 0, //rrand(-0.5, 0.5),
				amp: ~ampStream.next,
				// amp: 6.dbamp,
				rate: rate,
				start: ~buf.sampleRate * start,
				time: (1.5 - start) / rate,
				delta: if(parms[\trail] ? false) { (1.5 - start) / rate } { 0 },
				attack: 0.05,
				decay: 0.05
			)
		], 1)
	};
	~readLabels = {
		~pt = TabFileReader.read(~dir +/+ ~path.splitext[0] ++ "-labels.txt");
		~pt.do { |row| 2.do { |i| row[i] = row[i].asFloat } };
	};
} => PR(\creaks);

(keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;
	PR(\creaks).chuck(BP(name), nil, (master: ~master, glrvbmc: ~glrvbmc, lcrvbmc: ~lcrvbmc));
	0 => BP(name);
	BP(name).printStopMsg = false;
}, type: \bp) => Fact(\creaks);


// slurps
(keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		alwaysReset: true,
		event: (eventKey: \singleSynthPlayNotify).proto_(topEnvironment[\rvbEvent].proto),
		inChannels: 2,
		master: topEnvironment[\master],
		glrvbmc: topEnvironment[\glrvbmc],
		lcrvbmc: topEnvironment[\lcrvbmc],
		bufdir: topEnvironment[\sampleDir],
		bufpath: "head/slurpy.aiff",
		userprep: {
			#[glrvbmc, lcrvbmc].do { |key|
				key.envirGet.tryPerform(\receivesSignalFrom, ~chan);
			};
			~buf = Buffer.readAndQuery(s, ~bufdir +/+ ~bufpath);
			~panCtl = GenericGlobalControl(\pan, nil, 0, \bipolar);
			~distCtl = GenericGlobalControl(\distance, nil, 5, #[5, 20]);
			~xymaps = [~panCtl, ~distCtl].collect(_.asMap);
			~fastProbCtl = GenericGlobalControl(\fastProb, nil, 0);
		},
		useGui: { |vpi|
			[~panCtl, ~distCtl, ~fastProbCtl].do { |gc| gc => VP(vpi) };
		},
		userfree: {
			#[glrvbmc, lcrvbmc].do { |key|
				key.envirGet.tryPerform(\stopsReceivingFrom, ~chan);
			};
			[~buf, ~panCtl, ~distCtl, ~fastProbCtl].free;
		},
		preparePlay: {
			~stage = 0;
			~autoSynth ?? {
				~autoSynth = {
					var	angle = Phasor.kr(0, -2pi / 8 * ControlDur.ir, 0, 2pi),
						radius = SinOsc.kr(0.329843287).range(0.3, 1.0);
					Out.kr(~panCtl.bus, angle.cos * radius);
					Out.kr(~distCtl.bus, (angle.sin * radius).linlin(-1, 1, 20, 5));
					Silent.ar(1)
				}.play(~chan.fadergroup, addAction: \addToHead);
			};
		},
		stopCleanup: {
			~autoSynth !? {
				~autoSynth.free;
				~autoSynth = nil;
			}
		},
		lastTrig: {
			~stage = ~stage + 1;
		},
		recvEventNotify: {
			if(~stage > 0) { ~stage = ~stage + 1 };
		},
		objects: (
			bgpan: (
				def: \addRvbOut.eval(\bufGrainPanFiltDist, { |start, time, bufnum, pan, rate = 1, amp = 1, ampMap = 1,
						attack = 0.001, decay = 0.02, outbus, ffreq = 2000|
					var sig;
					sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
						* EnvGen.kr(Env.linen(attack, time, decay), doneAction:2);
					sig = LPF.ar(sig, ffreq);
					Out.ar(outbus, Pan2.ar(sig, pan, amp * ampMap));
				}),
				args: [
					#[pan, distance], Plazy({ Pn(~xymaps, inf) }),
					\bufnum, Plazy({ Pn(~buf, inf) }),
					\time, Pwhite(0.8, 1.8, inf),
					\overlap, Pwhite(2.0, 5.0, inf),
					\delta, Pkey(\time) / Pkey(\overlap),
					\start, Plazy({ Pif(
						Pwhite(0.0, 1.0, inf) < ~fastProbCtl,
						Pwhite(3276, (3276 + 488489) - (Pkey(\time) * ~buf.sampleRate), inf),
						Pwhite(516826, (516826 + 97978) - (Pkey(\time) * ~buf.sampleRate), inf)
					) }),
					\rate, Prand(#[-1, 1], inf),
					\attack, 0.1, \decay, 0.15,
					\ffreq, 15000,
					\datafixes, Pfunc({ |ev|
						switch(~stage)
						{ 0 } {
							if(ev[\rate] < 0) { ev[\start] = ev[\start] + (ev[\time] * ~buf.sampleRate) };
							ev[\time] = ev[\time] - ev[\attack] - ev[\decay];
							0
						}
						{ 1 } {
							ev.putAll((
								start: 516826, time: 165436 / ~buf.sampleRate - 0.25,
								rate: 1
							));
							0
						}
						{ nil };	// all other stages: stop now
					})
				]
			)
		),
		reset: Func(\resetBPStreams).v
	));
	0 => BP(name);
}, type: \bp) => Fact(\slurps);


// words
(keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		event: (eventKey: \polySynthBusLock).proto_(topEnvironment[\rvbEvent].proto),
		dir: topEnvironment[\sampleDir],
		path: "head/questions1.aiff",
		labelPath: { ~dir +/+ "head/questions1-labels.txt" },
		lpcPath: "head/questions1.lpc.aif",
	
		master: topEnvironment[\master],
		glrvbmc: topEnvironment[\glrvbmc],
		lcrvbmc: topEnvironment[\lcrvbmc],
	
		userprep: {
			var	sf;
			~lpcbuf = Buffer.readAndQuery(s, ~dir +/+ ~lpcPath);
			~readLabels.();
			sf = SoundFile.openRead(~dir +/+ ~path);
			if(sf.notNil) {
				~voxdur = sf.duration;
				sf.close;
			} {
				"Could not read duration from %.".format(~dir +/+ ~path).warn;
			};
			#[glrvbmc, lcrvbmc].do { |key|
				key.envirGet.tryPerform(\receivesSignalFrom, ~chan);
			};
			~noisebuf = Buffer.sendCollection(s, Signal.fill(1024, { 1.0.rand2 }).asWavetable, 1, 0.05);
			~pitchbufs = \makeWavetables.eval(8, s, 2048, 48, { |numh| 1 ! numh });
			~pitchProb = GenericGlobalControl(\pitchProb, nil, 0);
			~preAmp = GenericGlobalControl(\preAmp, nil, 1, #[0.05, 20, exp]);
			~postAmp = GenericGlobalControl(\postAmp, nil, 2.1, #[0.05, 20, exp]);
			~distBuses = Bus.control(s, 12);
			~distBusPool = Pseq((0 .. 11) + ~distBuses.index, inf).asStream;
			~xfscale = GenericGlobalControl(\xfscale, nil, 0.1, #[0.001, 0.4, exp]);
		},
		useGui: { |vpi| [~pitchProb, ~preAmp, ~postAmp, ~xfscale].do { |gc| gc => VP(vpi) } },
		userfree: {
			[~lpcbuf, ~noisebuf, ~pitchbufs, ~pitchProb, ~preAmp, ~postAmp, ~distBuses, ~xfscale].free;
			#[glrvbmc, lcrvbmc].do { |key|
				key.envirGet.tryPerform(\stopsReceivingFrom, ~chan);
			};
		},
	
		delta: 1,
		sustain: 1,
		synth: Plazy({ Pif(Pwhite(0.0, 1.0, inf) < ~pitchProb, \pitched, \noisy) }),
	
		freq1: Pexprand(80.0, 250.0, inf),
	// 	freq2: Pkey(\freq1) * Prand(#[0.5, 2.0], inf),
		noiseSlideProb: 0.35,
		freq2: Pkey(\freq1) * Pif(Pfunc({ ~noiseSlideProb.coin }),
			Pexprand(0.75, 1.33, inf), 1),
		fHoldPct: Pwhite(0.15, 0.35, inf),
		fHoldPct: Pwhite(0.35, 0.7, inf),
		fcurve: Pwhite(2.7, 4.5, inf) * (Pkey(\freq2) - Pkey(\freq1)).sign,
	// 	fcurve: 0,
		preamp: 9,
		amp: 10.dbamp,
		noiseenv: Env.linen(0.2, sustainTime: 0.45, releaseTime: 0.35),
		pfreq: (Paccumbounce(25, 39, Pwrand(#[-2, -1, 1, 2], #[0.2, 0.2, 0.3, 0.3], inf), inf)
				+.x Pseries(0, Pwhite(1, 4, 3)))
			.clump(3)
			.collect { |deg, ev| Mode(ev[\mode]).cps(deg) },
		pitchedSlideProb: 0.1,
	
		questionKeys: #["what", "where", "why", "who"],
		word: Plazy({
			var	items = ~pts.select { |pt|
					~questionKeys.includesEqual(pt[\id])
				};
			Prand(items, inf)
		}),
		// don't change this one
		coords: Plazy({ BPStream(\word).collect { |item| [item[\start], item[\end]] } }),
		lpchpf: 20,
		lpclpf: 15000,
	// 	dist: Pwhite(5.0, 20.0, inf),
		dist: Pfunc({ |ev|
			var	bus = ~distBusPool.next; //, start = rrand(10.0, 20.0);
			// use event for server latency
			(instrument: \ctlEnv, outbus: bus, group: ~chan.synthgroup, addAction: \addBefore,
				env: Env(({ rrand(5.0, 20.0) } ! 2), #[1]), connect: 0, time: ev[\time]
			).play;
			("c" ++ bus).asSymbol  // return map indicator
		}),
		pan1: Pwhite(-1.0, 1.0, inf),
		pan2: Pwhite(0.0, 1.0, inf) * Pkey(\pan1).sign.neg,
		lpcEv: Pbind(
			\instrument, \simpleLPCfxPan2Dist,
			\lpcbuf, Plazy({ Pn(~lpcbuf, inf) }),
			\voxdur, Plazy({ Pn(~voxdur, inf) }),
			#[start, end], BPStream(\coords),
			\hpf, BPStream(\lpchpf),
			\lpf, BPStream(\lpclpf),
			\distance, BPStream(\dist),
			\pan1, BPStream(\pan1),
			\pan2, BPStream(\pan2),
			\amp, Plazy({ Pn(~preAmp.asMap, inf) }),
			\xfscale, Plazy({ Pn(~xfscale.asMap, inf) }),
			\postAmp, Plazy({ Pn(~postAmp.asMap, inf) }),
			// filter is sometimes still ringing when 'time' cuts it off
			\time, Pkey(\time) + 0.1
		),
	
		objects: (
			noisy: (
				def: \oscbloop1,
				args: [
					bufnum: Plazy({ Pn(~noisebuf, inf) }),
					freq1: BPStream(\freq1),
					freq2: BPStream(\freq2),
					fcurve: BPStream(\fcurve),
					fHoldPct: BPStream(\fHoldPct),
					delta: Pwhite(3.0, 6.0, inf),
					time: Pkey(\delta).linlin(3.0, 6.0, 4.0, 9.0),
					amp1: BPStream(\preamp),
					amp2: Pkey(\amp1),
					normAmp: 7.dbamp, // BPStream(\amp),
					env: Pfunc({ ~noiseenv }),
					lpcEv: BPStream(\lpcEv) <> Pfunc({ |ev| ~sanitizeEvent.(ev) })
				]
			),
			pitched: (
				def: \oscbloop1,
				args: [
					mode: Pseq([
						Pn(\ab0, { rrand(12, 24) }),
						Pstutter(Pwhite(2, 6, inf), Prand(Mode.keys.asArray.select { |key|
							key != \ab0 and: { key.asString.last == $0 }
						}, { rrand(1, 4) }))
					], inf),
					freq1: BPStream(\pfreq),
					freq2: Pif(Pfunc({ ~pitchedSlideProb.coin }),
						BPStream(\pfreq), Pkey(\freq1)),
					bufnum: Plazy({ Pkey(\freq1).cpsmidi.linlin(48, 48+(12*7),
						~pitchbufs.first.bufnum, ~pitchbufs.first.bufnum + ~pitchbufs.size - 1
					) }),
					fcurve: Pfunc({ |ev|
						rrand(2.7, 4.5) * (ev[\freq1] - ev[\freq2]).sign
					}),
					fHoldPct: BPStream(\fHoldPct),
					delta: Pwhite(1.5, 4.0, inf),
					time: Pkey(\delta) * Pwhite(1.4, 2.1, inf),
					amp1: BPStream(\preamp),
					amp2: Pkey(\amp1),
					normAmp: 17.dbamp, // BPStream(\amp),
					beats: Pkey(\freq1).explin(50, 1200, 1.8, 3.6),
					env: Pfunc({ ~noiseenv }),
					lpcEv: BPStream(\lpcEv) <> Pfunc({ |ev| ~sanitizeEvent.(ev) })
				]
			)
		),
		sanitizeKeys: (time: \time),
		sanitizeEvent: { |ev, keys(~sanitizeKeys)|
			var	newEv = ().proto_(~event.proto);
			keys.keysValuesDo { |k, v|
				newEv[k] = ev[v];
			};
			newEv
		},
	
		readLabels: {
			~pt = TabFileReader.read(~labelPath.());
			~processLabels.();
		},
		processLabels: {
			var temp;
			~pts = ~pt.collect { |row|
				temp = (id: row[2], start: row[0].asFloat, end: row[1].asFloat);
				temp.put(\dur, temp[\end] - temp[\start])
			}
		}
	));
	0 => BP(name);
}, type: \bp) => Fact(\words);
