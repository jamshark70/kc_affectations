// defs for the actual arms section, not the silly prototype


// just in case... (won't load twice if already loaded)
(thisProcess.nowExecutingPath.dirname.dirname +/+ "common/common-defs.scd").loadPath;


// melody (axial)

// this voicer is more synth-y, use later in the section
(keys: #[master, glrvbmc, lcrvbmc],
env: Env.adsr(0.4, 0, 1, 1.2),
bufenv: Env.zero,
make: { |name|
	var	out;
	~wt = \makeWavetables.eval(8, s, 2048, 48, { |numharm|
		var	array = Array.triangleAmps(numharm),
			tweak = ((numharm div: 5) + 1 .. (numharm-1)), i;
		min(10, numharm div: 5).do {
			i = tweak.takeAt(tweak.size.rand);
			if(i.notNil) {
				array[i] = array[i] * exprand(2.5, 6.0) * (i+1);
			};
		};
		array
	});
	~target = MixerChannel(name, s, 2, 2, outbus: ~master, completionFunc: { |chan|
		// eq?
		~chorus = chan.playfx(WrapInstr("busfx.chorus2"), [0, 2, 2, 3, 0.01285261232269, 0.077426358822457, 0.00860870962377, 0.87266466760906, 0.15647481535888]);
	});
	[~glrvbmc, ~lcrvbmc].do { |mc| mc.tryPerform(\receivesSignalFrom, ~target) };

	out = \addRvbOut.eval(name ++ "Def", { |freq, freqlag = 0.1,
		vsens = 0.84722220897675, detune = 1.003,// bufmod = 0,
		ffreq = 2423, rq = 1, pan, gate = 1, ampMul = 1|
		var	laggedfreq = Lag.kr(freq, freqlag),
			bufbase = ~wt.first.bufnum,
			numbufs = ~wt.size,
			basefreq = 48.midicps,
			topfreq = 132.midicps,
			baselog = log2(basefreq),
			freqmap = ((log2(laggedfreq) - baselog) / (log2(topfreq) - baselog)
				* (numbufs - 1)).clip(0, numbufs - 1.001),
			amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate),
			buf = bufbase + freqmap + EnvGen.kr(~bufenv, gate),
			sig = VOsc3.ar(buf, laggedfreq/detune, laggedfreq, laggedfreq*detune, amp)
				* EnvGen.kr(~env, gate, doneAction:2);
		Pan2.ar(RLPF.ar(sig, ffreq, rq), pan, ampMul)
	}).add;
	SynthDescLib.at(out.name.asSymbol).msgFuncKeepGate = true;

// 	out = MonoPortaVoicer(1, WrapInstr("osc2.vosc3mapfporta"), [bufbase: `(~wt.first.bufnum), numbufs: `(~wt.size), basefreq: `(48.midicps), topfreq: `(132.midicps), env: Env.adsr(0.4, 0, 1, 1.2), ffreq: 2423.054873855, rq: 1, vsens: 0.84722220897675, detune: 1.003], target: ~target);
	out = MonoPortaVoicer(1, out.name, [ffreq: 2423.054873855, rq: 1, vsens: 0.84722220897675, detune: 1.003], target: ~target);
	// no global maps - this is mostly to generate the synthdef
// 	SynthDescLib.at(out.nodes[0].defname.asSymbol).msgFuncKeepGate = true;
	out
},
free: {
	[~glrvbmc, ~lcrvbmc].do { |mc| mc.tryPerform(\stopsReceivingFrom, ~target) };
	~target.free
},
maps: { |self| self[\value].globalControls.collectAs({ |gc| if(gc.name != \detune) { [gc.name, gc.asMap] } }, Array).select(_.notNil).flat },
type: \voicer) => Fact(\armsmelVC);


// this is the more airy synth for the start of this section
WrapInstr("arms.airskid", { |noisebuf, nfreq = 440, beats = 1,
	trig = 1, chDepth = 0.003, chSpeed = 0.1, chPre = 0.01,
	fenv, rdecay = 0.01, time = 0.1,
	amp = 0.1, aenv, numOverlaps = 3|
	var	sig, chSig, rfreq, overlapTrigs/*, time*/;

	sig = COsc.ar(noisebuf, nfreq, beats);
	chSig = sig;
	2.do {
		chSig = DelayL.ar(chSig, 0.1, SinOsc.kr(chSpeed, Rand(0.0, 0.8pi), chDepth, chPre));
		sig = sig + chSig;
	};
	fenv = fenv.dereference.value(trig, time);
	overlapTrigs = PulseDivider.kr(trig, numOverlaps, (0 .. numOverlaps-1));
	rfreq = EnvGen.kr(fenv, gate: overlapTrigs);
	sig = Ringz.ar(sig, rfreq, rdecay);
	sig = Limiter.ar(sig);
	aenv = aenv.dereference.value(trig, time);
	Mix(sig * amp * EnvGen.kr(aenv, gate: overlapTrigs, timeScale: time, doneAction: 0))
}, [\mybuf, \freq, #[0.1, 10, \exp],
	TrigSpec.new, #[0.001, 0.5, \exp], #[0.001, 0.5, \exp], #[0.001, 0.5, \exp],
	ObjectSpec(`{ |trig, decay|
		var	proportion = TRand.kr(0.02, 0.9, trig),
			low = TRand.kr(300, 600, trig);
		Env([low, TRand.kr(1200, 2000, trig), low],
			[proportion, 1 - proportion] * decay, \exp)
	}), #[0.01, 1.0, \exp], #[0.01, 1.0, \exp], #[0.1, 10, \exp], EnvSpec(Env.perc(0.01, 0.99)),
	StaticSpec(1, 6, \lin, 1)
]);


\addRvbOut.eval(\airskid, { |noisebuf, nfreq = 440, beats = 4.64,
	chDepth = 0.05, chSpeed = 1.2, chPre = 0.06,
	loffreq = 440, hiffreq = 440, rdecay = 0.01,
	loTime = 0.12, hiTime = 0.22, timeMul = 1,
	amp = 1, pan, sustain = 1|
	var	sig,
		ddelta = Dstutter(2, Dwhite(0.0, 1.0, inf).linexp(0, 1, loTime, hiTime)),
		trig = TDuty.kr(ddelta, 0, ddelta),
		time = Latch.kr(trig, trig) * timeMul;
	sig = WrapInstr("arms.airskid").valueArray([
		noisebuf, nfreq, beats, trig, chDepth, chSpeed, chPre,
		{ |trig, decay|
			var	proportion = TRand.kr(0.02, 0.9, trig); //,
			Env([loffreq, hiffreq, loffreq],
				[proportion, 1 - proportion] * decay, \exp)
		}, rdecay, time, amp,
		{ |trig, decay|
			var	proportion = TRand.kr(0.02, 0.9, trig);
			Env([0, 1, 0], [proportion, 1 - proportion] * decay, #[3, -3])
		},
		/*numOverlaps:*/ 3
	]);
	sig = sig * EnvGen.kr(Env.linen(0.1, sustain, 0.1, curve: -2), doneAction: 2);
	Pan2.ar(sig, pan);
}).add;

s.doWhenBooted {
	SynthDef(\xylin, { |x1, x2, y1, y2, sustain = 1, out|
		Out.kr(out, [
			Line.kr(x1, x2, sustain, doneAction: 2),
			Line.kr(y1, y2, sustain)
		]);
	}).add;
};


// airy melody
PR(\abstractProcess).clone {
	~event = (eventKey: \singleSynthPlayer, distNear: 5, distFar: 20);
	~xyDef = \xylin;
	~def = \airskid;

	~prep = {
		~chan = MixerChannel(~collIndex, s, 2, 2, outbus: ~master);
		if(~glrvbmc.notNil) {
			#[glrvbmc, lcrvbmc].do { |key|
				key.envirGet.tryPerform(\receivesSignalFrom, ~chan);
				~event.put((key.asString.drop(-2) ++ "out").asSymbol, key.envirGet.inbus);
			};
		} {
			"BP(%): Spatialization reverbs not found.".format(~collIndex.asCompileString).warn;
		};
		~event[\chan] = ~chan;

		~buf = Buffer.alloc(s, 2048, 1);
		~buf.sendCollection((Signal.fill(1024, { 1.0.rand2 }) * Signal.hammingWindow(1024))
			.asWavetable);

		~timeMulCtl = GenericGlobalControl(\timeMul, nil, 1.6, #[0.5, 3.5]);
	};
	~useGui = { |vpi| ~timeMulCtl => VP(vpi) };

	~freeCleanup = {
		[~glrvbmc, ~lcrvbmc].do { |mc| mc.tryPerform(\stopsReceivingFrom, ~chan) };
		[~buf, ~chan, ~timeMulCtl].free;
	};

	~nfreq = Pexprand(40.0, 1800.0, inf);
	~rdecay = 1;
	~delta = Pwhite(0.4, 1.5, inf);
	~sustain = Pkey(\delta) * Pwhite(3.0, 6.0, inf);
	~loTime = Pexprand(0.12, 0.22, inf);
	~hiTime = Pkey(\loTime);
	~amp = 8.dbamp;

	~rewriteProb = 0.3;
	~rewriteLevel = Pseq([1, 2, Pwhite(1, 3, inf)], 1);
	~phrases = [
		#[2, 5, 4],
		#[2, 7, 6, 4, 8],
		#[2, 5, 6, 4],
		#[9, 8, 3],
		#[8, 11, 10, 5, 2, 3, 4],
		#[-2, -5, 0, 1, 0, 4]
	];
	~degree = Plazy {
		var	self = currentEnvironment;
		Pswitch(
			~phrases.collect { |row|
				PR(\rewriter).copy.prep(Pseq(row, 1), Pfuncn(e { ~rewriteLevelStream.next }, 1), [
					(_.notNil) -> { |item, level, inval|
						// self: this runs inside the rewriter Proto object
						if(self[\rewriteProb].coin) {
							item + [0, rrand(1, 3) * #[-1, 1].choose].rotate(2.rand)
						} { [item] }
					}
				])
			},
			\patRejectLastN.eval(Pseq([0, 1, 2, Prand((0 .. (a.size-1)), inf)]), 1)
		)
	};
	~hiffreq = Pfunc { |ev| Mode(ev[\mode]).cps(ev[\degree] + 35) };
	~loffreq = Pkey(\hiffreq) * Pexprand(1.03.reciprocal, 1.03, inf);
	~mode = \g;

	~pan1 = Pwhite(0.6, 1.0, inf) * Prand(#[-1, 1], inf);
	~pan2 = Pkey(\x1).neg;
	~yNear = 5;
	~yFar = 20;

	~xyPat = Pbind(
		\instrument, BPStream(\xyDef),
		\sustain, Pkey(\sustain),
		\x1, BPStream(\pan1),
		\x2, BPStream(\pan2),
		\y1, BPStream(\yNear),
		\y2, BPStream(\yFar)
	);

	~streamKeys = #[xyPat, rewriteLevel];
	~makeStreams = {
		~streamKeys.do { |key|
			(key ++ "Stream").asSymbol.envirGet ?? { ~makeStreamForKey.(key) };
		}
	};
	~reset = {
		#[degree, rewriteLevel].do { |key| ~makeStreamForKey.(key) };
	};

	~asPattern = {
		~makeStreams.();
		Pfunc { |ev|
			var xyEv = ~xyPatStream.next(ev);
			xyEv !? {  // DON'T YIELD NIL!!!
				xyEv.put(\delta, 0).put(\chan, nil).put(\bus, ev[\xylock].bus)
				.yield
			};
			// why? event must .play before ev[\id] is available
			thisThread.clock.sched(0, {
				ev[\xylock].addNode(ev[\node]);
				nil
			});
			ev
		}
		<>
		Pbind(
			\instrument, BPStream(\def),
			\noisebuf, ~buf,
			\nfreq, BPStream(\nfreq),
			\delta, BPStream(\delta),
			\sustain, BPStream(\sustain),
			\loTime, BPStream(\loTime),
			\hiTime, BPStream(\hiTime),
			\timeMul, ~timeMulCtl,
			\mode, BPStream(\mode),
			\degree, BPStream(\degree),
			\hiffreq, BPStream(\hiffreq),
			\loffreq, BPStream(\loffreq),
			\rdecay, BPStream(\rdecay),
			\xylock, Pfunc { PR(\busLock).copy.prep((numCh: 2, rate: \control)) },
			#[pan, distance], Pfunc { |ev|
				(ev[\xylock].bus.index + #[0, 1]).collect { |i| ("c" ++ i).asSymbol }
			},
			\amp, BPStream(\amp)
		)
	};
} => PR(\armsSkidMel);


// now this really is a bit of silliness, but Pmono[Artic] patterns don't work
// when grabbing events on-demand (it's fine until you need the EventStreamCleanup to fire)
// so, I have to do it myself. grr....

PR(\abstractProcess).clone {
	~event = (eventKey: \monoSupport, immediateOSC: true);
	~vcKey = \am;
	~prep = {
		if(VC.exists(~vcKey).not) {
			"VC(%) doesn't exist. Please create it before using BP(%)."
				.format(~vcKey.asCompileString, ~collIndex.asCompileString).die;
		};
		~event.putAll((
			glrvbout: VC(~vcKey).env[\glrvbmc].tryPerform(\inbus),
			lcrvbout: VC(~vcKey).env[\lcrvbmc].tryPerform(\inbus),
			distNear: 5, distFar: 20
		));
		~makeStreamForKey.(\level);
		currentEnvironment
	};
	~alwaysReset = true;
	~pan = 0;
	~distance = 17;

	~rewriteProb = 0.3;
	~phrases = [
		#[2, 5, 4],
		#[2, 7, 6, 4, 8],
		#[2, 5, 6, 4],
		#[9, 8, 3],
		#[8, 11, 10, 5, 2, 3, 4],
		#[-2, -5, 0, 1, 0, 4]
	];
	~degree = Plazy {
		var	self = currentEnvironment;
		Pswitch(
			~phrases.collect { |row|
				PR(\rewriter).copy.prep(Pseq(row, 1), Pfuncn(e { ~levelStream.next }, 1), [
					(_.notNil) -> { |item, level, inval|
						if(self[\rewriteProb].coin) {
							item + [0, rrand(1, 3) * #[-1, 1].choose].rotate(2.rand)
						} { [item] }
					}
				])
			},
			\patRejectLastN.eval(Pseq([0, 1, 2, Prand((0 .. (a.size-1)), inf)]), 1)
		)
	};

	~dur = Pwrand(#[1, 2], #[0.9, 0.1], inf);
// 	~legato = Pwrand(#[1.01, 0.9, 0.4], #[0.7, 0.2, 0.1], inf); // 1.01;
	~gate = 0.8;
	~freqlag = 0.3;
	~detune = 1.003;
	~gate = 0.8;
	~level = (Pn(0, 3) ++ Pexprand(0.01, 2.99, inf).collect(_.asInteger));
	~ffreq = Pexprand(2300, 8000, inf);
	~rq = Pexprand(0.1, 1.0, inf);

	~recvEventNotify = { |node| ~node = node };
	~stopCleanup = { if(~node.notNil) { ~node.release }; ~node = nil };
	~asPattern = {
		Pbind(
			\instrument, VC(~vcKey).v.nodes[0].defname.asSymbol,
//			\level, BPStream(\level),
			\node, Pfunc { ~node ?? { 0 } },
			\protoEvent, Pif(Pfunc { ~node.isNil }, \singleSynthPlayNotify, \singleSynthTrigger),
			\node, Pfunc { ~node ?? { 0 } },
			\root, 7,
			\freq, (BPStream(\degree).degreeToKey(#[0, 2, 4, 5, 7, 9, 11]) + 67).midicps,
			\delta, BPStream(\dur),
// 			\legato, BPStream(\legato),
			\gate, BPStream(\gate),
			\freqlag, BPStream(\freqlag),
			\detune, BPStream(\detune),
			\gate, BPStream(\gate),
			\ffreq, BPStream(\ffreq),
			\rq, BPStream(\rq),
			\pan, BPStream(\pan),
			\distance, BPStream(\distance),
			\chan, VC(\am).env.target
		)
		// now this is a problem - you don't know when the next trigger is,
		// so you don't know when to release
		// removing for now
// 		.collect { |ev|
// 			if(~node.notNil and: { ev[\legato] < 1 }) {
// 				\schedEventBundleArray.eval(ev[\lag] ? 0, ev[\timingOffset] ? 0,
// 					ev[\server] ?? { Server.default },
// 					[~node.releaseMsg], nil, true
// 				);
// 				~node = nil;
// 			};
// 			ev
// 		};
	};
	~reset = Func(\resetBPStreams).v;
} => PR(\melody);


// chords (locomotive theme)
// reuse spatialization from feet

WrapInstr("osc2.fm2car_stereo", { arg physicalPan = 0, freq, freqlag = 0, gate, car_env, mod_env,
		mod_lev, mod_ratio, detune, car_detune,
		car_buf, mod_buf, car_vs, mod_vs, basefreq, keyscale, attackTimeScale = 1, decayTimeScale = 1, finalAmp = 1;
	var sig, mod, car_amp, mod_amp, timeScale, car_eg, hit1;

	freq = Lag.kr(freq, freqlag);
	car_eg = Select.kr(Impulse.kr(0), [LocalIn.kr(1), 0]);
		// once envelope starts going down, attack phase is over
	hit1 = PulseCount.kr(HPZ1.kr(car_eg) < 0) > 0;
	timeScale = Select.kr(hit1, [attackTimeScale, decayTimeScale]);
	car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
	mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
		* EnvGen.kr(mod_env, gate, timeScale: timeScale);
	mod_lev = mod_lev * basefreq / ((keyscale * freq) + (basefreq * (1 - keyscale)));
	mod = Osc.ar(mod_buf, freq.madd(mod_ratio * [1, car_detune], detune * [1, -1]), 0, mod_amp * mod_lev);
	freq = freq * [1, car_detune];
	car_eg = EnvGen.kr(car_env, gate, timeScale: timeScale, doneAction:2);
	LocalOut.kr(car_eg);
	sig = Mix(Osc.ar(car_buf, freq + (mod * freq), 0, car_amp))
		* car_eg * finalAmp;
	Pan2.ar(sig, physicalPan);
}, [\bipolar, \freq, nil, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0.01, 300, \exponential], [1, 12, \linear, 0, 1], [-5, 5, \linear, 0, 0], \mydetune, \mybuf, \mybuf, nil, nil, \freq, [0.001, 1.0, \exp], #[0.1, 10, \exp, 0, 1], \amp]);


(keys: #[master, glrvbmc, lcrvbmc],
defaultCarDetune: 1.005716,
defaultDetune: 1.25,
car_amps: #[1, 2, 3].reciprocal,
mod_amps: #[1],
car_env: Env.adsr(0.5, 0.8, 0.75, 1.0),
mod_env: Env.adsr(0.01, 2.5, 0.05, 1, curve: -2.5),
keyScale: 0.28621534453893,
defaultCarVs: 0.833,
defaultModVs: 0.819,
isMono: false,
customize: nil,
make: { |name|
	var	args, out;
	~target = MixerChannel(name, s, 2, 2/*, level: -17.dbamp*/, outbus: ~master);
	[~glrvbmc, ~lcrvbmc].do { |mc|
		mc.tryPerform(\receivesSignalFrom, ~target);
	};
	~cb = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg(~car_amps) });
	~mb = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg(~mod_amps) });

	~def = \addRvbOut.eval((name ++ "def").asSymbol, { |pan, freq = 440, freqlag = 0, gate = 1,
			mod_lev = 0.01, mod_ratio = 1, detune = 0, car_detune = 0.99798261661993,
			car_vs = 0, mod_vs = 0,
			attackTimeScale = 1, decayTimeScale = 1, finalAmp = 1|
		WrapInstr("osc2.fm2car_stereo").valueArray([
			pan, freq, freqlag, gate,
			~car_env,
			~mod_env,
			mod_lev, mod_ratio,
			detune, car_detune,
			~cb.bufnum, ~mb.bufnum, car_vs, mod_vs, // 0.66141732283465 /* car_vs */, 0 /* mod_vs */,
			440, ~keyScale, /* basefreq, keyScale */
			attackTimeScale, decayTimeScale, finalAmp
		])
	}).add;
	SynthDescLib.at(~def.name.asSymbol).msgFuncKeepGate = true;

	// default args for voicer: supply reverb targets automatically
	if(~glrvbmc.isKindOf(MixerChannel)) {
		args = [glrvbout: ~glrvbmc.inbus, lcrvbout: ~lcrvbmc.inbus];
	} {
		"VC(%): Spatialization reverbs not found.".format(name.asCompileString).warn;
	};
	if(~isMono ? false) {
		out = MonoPortaVoicer(1, ~def.name, args, target: ~target);
	} {
		out = Voicer(45, ~def.name, args, target: ~target);
	};
	out.mapGlobal(\detune, nil, ~defaultDetune, #[-5, 5]);
	out.mapGlobal(\car_detune, nil, ~defaultCarDetune, \mydetune);
	out.mapGlobal(\car_vs, nil, ~defaultCarVs);
	out.mapGlobal(\mod_vs, nil, ~defaultModVs);
	~customize.(out);
	out
},
free: {
	[~glrvbmc, ~lcrvbmc].do { |mc|
		mc.tryPerform(\stopsReceivingFrom, ~target);
	};
	[~cb, ~mb, ~target].free
}, type: \voicer) => Fact(\armsChordVC);


{ |notes| 
	Penvir((),
		Pwalk(notes, Pwrand([
			Pseq([Pn(1, { ~n = rrand(2, 4) }), Pfuncn { 1 - ~n }], 1),  // 1-n == (n-1).neg
			Pseq([Pn(-1, { ~n = rrand(2, 4) }), Pfuncn { ~n - 1 }], 1),
// 			Pn(-1, { rrand(2, 4) }),
			-2, 2,
		], #[0.4, 0.1, 0.1, 0.4], inf), Pseq(#[1, -1], inf), 0)
	)
} => ArpegPat(\armsCh);



// locomotive theme chords

SynthDef(\rotSpeedAuto, { |inbus, outbus, time = 1, proportion = 0.5|
	ReplaceOut.kr(outbus,
		In.kr(inbus, 1).linlin(0, 1, 0.1, 1.0)
			* EnvGen.kr(Env(#[1, 1, 0.1], [proportion, 1 - proportion]),
				timeScale: time, doneAction: 2)
	);
}).add;

SynthDef(\angleAuto, { |speedMul = 1, speedBus, outbus|
	// leaky integrator is not leaky if coef == 1
	ReplaceOut.kr(outbus, Integrator.kr(In.kr(speedBus, 1) * speedMul * ControlDur.ir, 1).wrap(0, 2pi));
}).add;

SynthDef(\yxRatioAuto, { |inbus, outbus|
	ReplaceOut.kr(outbus, In.kr(inbus, 1))
}).add;


PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote, distNear: 5, distFar: 20, midi: false);
	~alwaysReset = true;

	~chords = (
		// each is mode name (symbol), then midinotes
		c_ish: #[g, 48, 55, 57, 64, 66, 74, 81, 83],
		em: #[g, 52, 59, 60, 67, 69, 74, 78, 79, 83, 93],
		am: #[g, 45, 54, 55, 62, 64, 72, 76, 83],
		g: #[g, 43, 52, 57, 59, 66, 67, 74, 76, 84]
	);

	~chordTime = Pwhite(3.5, 8.0, inf);
	// ~row = Pwhite(0, Pkey(\rotSpeed) * 2.99, inf).collect(_.asInteger);
	~row = Plazy {
		Pwhite(0, Pkey(\yxRatio).linlin(0, BP(\di).maxRatio, 0, 2.99), inf).collect(_.asInteger)
	};
	~chord = Plazy { Pn(Pshuf(~fullCh.keys.asArray, 1), inf) }; // Pstutter(Pwhite(20, 60, inf), Pfunc { ~fullCh.keys.choose });
	~chordItem = Pfunc { |ev|
		if(ev[\chord] != ~lastChord) {
			~lastChord = ev[\chord];
			// force reset - this makes Plazy reevaluate and grab other chord item
			~makeStreamForKey.(\midinote);
		};
		~fullCh[~lastChord]
	};
	~midinote = \patRejectLastN.eval(Plazy { |ev|
		var	arpeg = ~arpegStream.next(ev);
		Pswitch1(ev[\chordItem][\hierarchy].collect { |row|
			ArpegPat(arpeg).asPattern(row)
		}, Pkey(\row))
	}, 1);
	~arpeg = \armsCh;
	~gate = Pexprand(0.05, 0.2, inf) * Pkey(\rotSpeed).linlin(0.1, Pfunc { ~maxRotSpeed }, 0.6, 4);
// 	~gate = 0.2;

	~mod_lev = Pkey(\distance).linlin(Pkey(\distNear), Pkey(\distFar), 2.5, 1);
	~radius = sin(Ptime() * 2pi / 11.3247623) * 0.5 + (0.5 * Pkey(\rotSpeed) / Pfunc { ~maxRotSpeed });
// 	~radius = sin(Ptime() * 2pi / 11.3247623) * 0.2 + (0.8 * Pkey(\rotSpeed));

	~dur = Pwrand(#[1, 2], #[0.9, 0.1], inf) * Pkey(\rotSpeed).linexp(0.1, Pfunc { ~maxRotSpeed }, 0.4, 0.08);

	~durxfer = Env(#[0.7, 0.3, 0.06], #[0.35, 1], #[5, -7]);
	~dur = Pwrand(#[1, 2], #[0.9, 0.1], inf) * (Pkey(\rotSpeed).collect { |rs|
		~durxfer.at(rs)
	});

	~sustain = Pwhite(1.2, 2.0, inf) * 4 / (Pkey(\row) + 4);
// 	~dur = max(0.1, Pkey(\rotSpeed)).reciprocal / 40;
// 	~sustain = Pkey(\dur) * (3 - Pkey(\row));  // hmm... not quite
	~attScale = Pkey(\rotSpeed).linexp(0.1, Pfunc { ~maxRotSpeed }, 0.5, 1);
// 	~attScale = max(0.1, Pkey(\rotSpeed)).reciprocal * 0.2;
	~decScale = Pkey(\attackTimeScale);

	~maxRotSpeed = 1;
	~maxRotSpeed_ = { |speed = 1|
		if(speed != ~maxRotSpeed) {
			~maxRotSpeed = speed;
			~rotSpeed.spec = [0, speed];  // asSpec is automatic
		};
		currentEnvironment
	};
	~speedThresh = 0.15;
	~angleBus = 3997;
	~rotSpeedBus = 4000;

	~prep = {
		~angle = GenericGlobalControl(\angle, ~angleBus.asBus(\control), 0, [0, 2pi]);
		~rotSpeed = GenericGlobalControl(\rotSpeed, ~rotSpeedBus.asBus(\control), 0, [0, ~maxRotSpeed]);
		~yxRatio = GenericGlobalControl(\yxRatio, ~yxRatioBus.asBus(\control), 0, [0, BP(\di).maxRatio.value]);
		~speedMul ?? {
			~speedMul = GenericGlobalControl(\speedMul, nil, 12, #[0.1, 10, exp]);
			~freeSpeedMul = true;
		};
		KrBusWatcher.newFrom(s).updateFreq = 8;
		~initChords.();
		~makeStreamForKey.(\chordTime);
	};

	~copyProc = { |name ((~collIndex ++ UniqueID.next).asSymbol)|
		var	self = currentEnvironment, parms;
		BP(name).free;
		parms = (
			angleBus: Bus.control(s, 1 /*, name + "angle"*/),
			rotSpeedBus: Bus.control(s, 1 /*, name + "rotSpeed"*/),
			yxRatioBus: Bus.control(s, 1 /*, name + "rotSpeed"*/),
			shouldFreeGCs: true,
			initChords: {
				~fullCh = self[\fullCh];
			},
			chord: (~chordStream ?? { ~makeStreamForKey.(\chord) }).next
		);
		// this is so I can change patterns in the dispatcher
		// and they get spawned thru to the children
		~bpsKeys.do { |key| parms[key] = key.envirGet };
		PR(\armsChord).chuck(BP(name), nil, parms);
		~event[\voicer] => BP(name)	// should return BP
	};

	~spawnChild = { |quant = 0|
		var bp = ~copyProc.(),
			lastSpawned = ~lastSpawned,
			upd = Updater(bp, e { |obj, what, more|
				if(more == \stopped) {
					upd.remove;
					if(~lastSpawned == bp.collIndex) { ~lastSpawned = nil };
					if(BP.exists(bp.collIndex)) {
						bp.free;
					};
				}
			});
		// this is a moderately obscene hack
		if(lastSpawned.notNil) {
			// ctlPoint uses replaceOut, will overwrite "real" autoSynth
			Synth(\ctlPoint, [outbus: BP(lastSpawned).rotSpeed.bus, value: 0, time: ~killOldProcTime],
				BP(lastSpawned).rotSpeed.autoSynth, \addAfter);
			thisThread.clock.sched(~killOldProcTime - 0.01, {
				if(BP.exists(lastSpawned)) {
					BP(lastSpawned).rotSpeed.stopAuto
				};
				nil
			});
		};
		~lastSpawned = bp.collIndex;
		bp.play(quant);
	};
	~killOldProcTime = 1.4;

	~bpsKeys = #[radius, /*chord,*/ chordItem, row, midinote, gate, mod_lev, dur, sustain, attScale, decScale, arpeg, maxRotSpeed, speedMul, durxfer];

	// dispatcher will override this to pull prepared fullCh dictionary,
	// rather than rebuilding every time
	~initChords = {
		~fullCh = IdentityDictionary.new;
		~chords.tryPerform(\keysValuesDo, { |key, value|
			~addChord.(key, value)
		});
	};

	~addChord = { |key, value|
		~fullCh.put(key, ~expandChord.(value))
	};

	~expandChord = { |array, adds = #[-7, 0, 7]|
		var	mapped = array[1..].mapMode(array[0]),
			result = (mode: array[0], orig: mapped, allSort: (mapped +.x adds).removeDups.sort,
			hierarchy: adds +.t mapped);
		result.put(\hierarchyDict,
			result[\hierarchy].collectAs({ |row, i| i.asSymbol -> row },
				IdentityDictionary)
		)
		.put(\sortWithLevels, result[\hierarchy].collect { |row, i|
			row.collect { |item| [item, i] }
		}.flatten(1).sort { |a, b| a[0] < b[0] or: { a[0] == b[0] and: { a[1] < b[1] } } });
	};

	~startAuto = {
		var	time = ~chordTimeStream.next, proportion = rrand(0.7, 0.85);
		s.makeBundle(nil, {
			~rotSpeed.automate(\rotSpeedAuto,
				[inbus: BP(\di).bus.index + 4, time: time, proportion: proportion],
				~event[\voicer].tryPerform(\bus).tryPerform(\asMixer).tryPerform(\fadergroup),
				\addToHead);
			~angle.automate(\angleAuto,
				[speedMul: ~speedMul.asMap, speedBus: ~rotSpeed.bus],
				~rotSpeed.autoSynth, \addAfter);
			~yxRatio.automate(\yxRatioAuto, 
				[inbus: BP(\di).bus.index + 7],
				~rotSpeed.autoSynth, \addAfter);
		});
		OSCpathResponder(s.addr, ['/n_end', ~rotSpeed.autoSynth.nodeID], e { |time, resp, msg|
			resp.remove;
			if(BP.exists(~collIndex)) {
				BP(~collIndex).stop(0);
			};
		}).add;
	};

	~stopCleanup = {
		s.makeBundle(0.1, {
			[~angle, ~rotSpeed, ~yxRatio].do { |gc| gc.stopAuto.stopWatching }
		});
	};

	~freeCleanup = {
		if(~shouldFreeGCs ? true) {
			[~angle, ~rotSpeed, ~yxRatio].free;
		};
		if(~freeSpeedMul ? false) { ~speedMul.free };
	};

	~useGui = { |vpi|
		[~angle, ~rotSpeed, ~yxRatio].do { |gc| gc => VP(vpi) };
		if(~freeSpeedMul ? false) { ~speedMul => VP(vpi) };
	};


	~asPattern = {
		~arpegStream ?? { ~makeStreamForKey.(\arpeg) };
		Pseq([
			// workaround scel indent bug
			'Pfuncn'.asClass.new { |ev|
				[~angle, ~rotSpeed, ~yxRatio].do(_.watch);
				~startAuto.();
				Event.silent(0)
			},
			Pbind(
				\angle, ~angle,
				\rotSpeed, ~rotSpeed,
				\yxRatio, ~yxRatio,
				\radius, BPStream(\radius),
				\pan, Pkey(\angle).cos * Pkey(\radius),
				\distance, (Pkey(\angle).sin * Pkey(\radius)).linlin(-1, 1, Pkey(\distNear), Pkey(\distFar)),
				\chord, if(~chord.isSymbol) { ~chord } { BPStream(\chord) },
				\chordItem, BPStream(\chordItem),
				\row, BPStream(\row),
				\freq, BPStream(\midinote),
				\mode, Pfunc { |ev| ev[\chordItem][\mode] },
				\gate, BPStream(\gate),
				\mod_lev, BPStream(\mod_lev),
				\dur, BPStream(\dur),
				\length, BPStream(\sustain),
				\attackTimeScale, BPStream(\attScale),
				\decayTimeScale, BPStream(\decScale)
			) //.trace
		])
	};
} => PR(\armsChord);


// data in

Proto {
	~event = (eventKey: \singleSynthPlayNotify);
	~numCh = 1;
//	~iMadeBus = false;
	~prep = {
		~outCh ?? { ~outCh = ~numCh };
		if(~bus.notNil) {
			~bus = SharedBus.newFrom(~bus, \notMe);
		} {
			~bus = Bus.control(s, max(~numCh, ~outCh));
			// ~iMadeBus = true;
		};
		if(~recvBus.notNil) {
			~recvBus = SharedBus.newFrom(~recvBus, \notMe);
		} {
			~recvBus = Bus.control(s, max(~numCh, ~outCh));
			// ~iMadeBus = true;
		};
		~userprep.();
	};
	~freeCleanup = {
		// if(~iMadeBus) { ~bus.free };
		[~bus, ~recvBus].free;
		~userfree.();
	};
	
	~asPattern = {
		~userPat.() <> ~busyWaitPat.()
	};
	~userPat = Pfunc { |ev| ev };
	~busyWaitPat = {
		Pn((instrument: \rest, delta: 1), inf)
	};
} => PR(\dataIn);


(keys: #[],
filename: "arms/hands-1_data2.wav",
make: { |name|
	BP(name).free;
	PR(\dataIn).chuck(BP(name), nil, (
		alwaysReset: true,
		numCh: 5,
		outCh: 8,
		bus: ~bus,
		recvBus: ~recvBus,
		path: topEnvironment[\sampleDir] +/+ ~filename,
		playTestFile: false,
		userprep: {
			~buf = Buffer.readAndQuery(s, ~path);
			~maxVel = GenericGlobalControl(\maxVel, nil, 9, #[0, 20, lin]);
			~maxRatio = GenericGlobalControl(\maxRatio, nil, 5.1, #[0.05, 15, exp]);
	
			SynthDef("data" ++ ~numCh, { |buf, outbus, frameRate = 30, loop = 0|
				var	fr = BufFrames.ir(buf),
					dur = fr / frameRate,
					notLoop = loop <= 0,
					end = fr + (10000 * notLoop),
					stopper = Line.kr(0, 1, dur, doneAction: notLoop*2),
					ph = Phasor.kr(0, frameRate * ControlDur.ir, start: 0, end: end),
					data = BufRd.kr(~numCh, buf, ph, 0, interpolation: 1);
		
				Out.kr(outbus, data);
			}).add;
	
			SynthDef("datafixer" ++ ~numCh, { |recvBus, writeBus, avgTime = 0.2, stop = 0, maxVel = 1, maxRatio = 10|
				var	data = In.kr(recvBus, ~numCh),
					avgSize = (avgTime * ControlRate.ir).trunc,
					peak;
			
				data[~numCh-1] = RunningSum.kr(data[~numCh-1], avgSize) / avgSize / maxVel;
				FreeSelf.kr(stop);
	
				(~numCh-1).do { |i| data[i] = data[i].madd(0.5, 0.5) };
				// w/o copy, 'data' has 3 more elements than In.kr created
				// this causes In.kr to create 8 OutputProxies where 5 would be correct
				data = data.copy.add(data[1] - data[0]).add(data[3] - data[2]);
				data = data.add(data[6] / max(data[5], 0.01) / maxRatio);
				// peak = Peak.kr(data.last);
				// peak.poll(stop, "peak was");
				
				ReplaceOut.kr(writeBus, data);
			}).add;
	
			~visualizer.();
		},
		visualizer: {
			defer(e {
				~win = ResizeFlowWindow("test", Rect(900, 100, 300, 200))
					.onClose_(e { ~closeWin.() });
				~ms = MultiSliderView(~win, Rect(0, 0, 100, 200))
					.indexThumbSize_(100/~outCh - 4).gap_(4).value_(0 ! ~outCh);
				~win.recursiveResize;
				~win.bounds = ~win.bounds
					.right_(Window.screenBounds.right)
					.bottom_(Window.screenBounds.bottom);
				~win.front;
				
				KrBusWatcher.newFrom(s).updateFreq_(10);
				~upd = Updater(~bus, e { |obj, data|
					var ms = ~ms;
					defer { ms.value = data };
				});
			});
		},
		userfree: {
			[~buf, ~maxVel, ~maxRatio].free;
			~closeWin.();
		},
		preparePlay: {
			~bus.setn(0 ! ~outCh);
			~recvBus.setn(0 ! ~outCh);
			KrBusWatcher.register(~bus)
		},
		stopCleanup: {
			KrBusWatcher.unregister(~bus);
			s.listSendBundle(nil, [
				[error: -1],
				// ~fixer.tryPerform(\freeMsg),
				~fixer.tryPerform(\setMsg, \stop, 1),
				~player.tryPerform(\freeMsg),
				[error: -2]
			].select(_.notNil));
			~fixer = nil;
			~player = nil;
			~bus.setn(0 ! ~outCh);
			~recvBus.setn(0 ! ~outCh);
		},
		recvEventNotify: { |node, ev|
			if(ev[\instrument].asString.contains("fixer")) {
				~fixer = node;
			} {
				~player = node;
			};
		},
		userPat: {
			Pseq([
				(
					instrument: ("datafixer" ++ ~numCh).asSymbol,
					recvBus: ~recvBus, writeBus: ~bus, avgTime: ~avgTime ? 0.2,
					maxVel: ~maxVel.asMap, maxRatio: ~maxRatio.asMap,
					delta: 0.0005, collIndex: ~collIndex, addAction: \addToHead
				),
				Pfuncn({
					(
						instrument: if(~playTestFile) { ("data" ++ ~numCh).asSymbol } { \rest },
						buf: ~buf, loop: 0, bus: ~recvBus,
						delta: ~buf.numFrames / 30,
						target: ~fixer, addAction: \addBefore, collIndex: ~collIndex
					).parent_(ProtoEvent(\singleSynthPlayNotify).parent)
				}, if(~playTestFile) { 1 } { inf })
			], 1)
		},
		closeWin: {
			var	win = ~win;
			win !? {
				defer(e { win.onClose_(nil).close });
				KrBusWatcher.unregister(~bus);
				~upd.remove;
			};
		}
	));
	0 => BP(name);
}, type: \bp) => Fact(\dataIn);

(
delta: Pwhite(2.5, 6.0, inf),
make: { |name|
	var	self = currentEnvironment;
	BP(name).free;
	Proto {
		~quant = NilTimeSpec.new;
		~delta = self[\delta];
		~asPattern = {
			Pbind(
				\play, { BP(\acDisp).spawnChild },
				\delta, BPStream(\delta)
			)
		}
	} => BP(name);
}, type: \bp) => Fact(\acTrig);
