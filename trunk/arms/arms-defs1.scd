// defs for the actual arms section, not the silly prototype


// just in case... (won't load twice if already loaded)
(thisProcess.nowExecutingPath.dirname.dirname +/+ "common/common-defs.scd").loadPath;


// melody (axial)

// this voicer is more synth-y, use later in the section
(keys: #[master, glrvbmc, lcrvbmc],
env: Env.adsr(0.4, 0, 1, 1.2),
bufenv: Env.zero,
isMono: true,
harmonicAmps: { |numharm|
	var	array = Array.triangleAmps(numharm),
	tweak = ((numharm div: 5) + 1 .. (numharm-1)), i;
	min(10, numharm div: 5).do {
		i = tweak.takeAt(tweak.size.rand);
		if(i.notNil) {
			array[i] = array[i] * exprand(2.5, 6.0) * (i+1);
		};
	};
	array
},
make: { |name|
	var	out, initArgs;
	~wt = \makeWavetables.eval(8, s, 2048, 48, ~harmonicAmps);
	~target = MixerChannel(name, s, 2, 2, outbus: ~master, completionFunc: { |chan|
		// eq?
		~chorus = chan.playfx(WrapInstr("busfx.chorus2"), [0, 2, 2, 3, 0.01285261232269, 0.077426358822457, 0.00860870962377, 0.87266466760906, 0.15647481535888]);
	});
	[~glrvbmc, ~lcrvbmc].do { |mc| mc.tryPerform(\receivesSignalFrom, ~target) };

	out = \addRvbOut.eval(name ++ "Def", { |freq, freqlag = 0.1,
		vsens = 0.84722220897675, detune = 1.003, bufbase = 0,
		ffreq = 2423, rq = 1, pan, gate = 1, ampMul = 1|
		var	laggedfreq = Lag.kr(freq, freqlag),
			// bufbase = ~wt.first.bufnum,
			numbufs = ~wt.size,
			basefreq = 48.midicps,
			topfreq = 132.midicps,
			baselog = log2(basefreq),
			freqmap = ((log2(laggedfreq) - baselog) / (log2(topfreq) - baselog)
				* (numbufs - 1)).clip(0, numbufs - 1.001),
			amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate),
			buf = bufbase + freqmap + EnvGen.kr(~bufenv, gate),
			sig = VOsc3.ar(buf, laggedfreq/detune, laggedfreq, laggedfreq*detune, amp)
				* EnvGen.kr(~env.value, gate, doneAction:2);
		Pan2.ar(RLPF.ar(sig, ffreq, rq), pan, ampMul)
	}, nil, if(~isMono, { (nil!5) ++ #[0.1, 0.1] }, nil), ~isMono).add;
	SynthDescLib.at(out.name.asSymbol).msgFuncKeepGate = true;

// 	out = MonoPortaVoicer(1, WrapInstr("osc2.vosc3mapfporta"), [bufbase: `(~wt.first.bufnum), numbufs: `(~wt.size), basefreq: `(48.midicps), topfreq: `(132.midicps), env: Env.adsr(0.4, 0, 1, 1.2), ffreq: 2423.054873855, rq: 1, vsens: 0.84722220897675, detune: 1.003], target: ~target);
	initArgs = [ffreq: 2423.054873855, rq: 1, vsens: 0.84722220897675, detune: 1.003,
		bufbase: ~wt.first.bufnum];
	if(~isMono) {
		out = MonoPortaVoicer(1, out.name, initArgs, target: ~target);
	} {
		out = Voicer(25, out.name, initArgs, target: ~target);
	};
	// no global maps - this is mostly to generate the synthdef
// 	SynthDescLib.at(out.nodes[0].defname.asSymbol).msgFuncKeepGate = true;
	out
},
free: {
	[~glrvbmc, ~lcrvbmc].do { |mc| mc.tryPerform(\stopsReceivingFrom, ~target) };
	[~target, ~wt].free
},
maps: { |self| self[\value].globalControls.collectAs({ |gc| if(gc.name != \detune) { [gc.name, gc.asMap] } }, Array).select(_.notNil).flat },
type: \voicer) => Fact(\armsmelVC);


// this is the more airy synth for the start of this section
WrapInstr("arms.airskid", { |noisebuf, nfreq = 440, beats = 1,
	trig = 1, chDepth = 0.003, chSpeed = 0.1, chPre = 0.01,
	fenv, rdecay = 0.01, time = 0.1, filterFunc,
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
	sig = filterFunc.dereference.value(sig, rfreq, rdecay);
	// sig = Ringz.ar(sig, rfreq, rdecay);
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
	}), #[0.01, 1.0, \exp], #[0.01, 1.0, \exp],
	ObjectSpec(`{ |sig, rfreq, rdecay|
		Ringz.ar(sig, rfreq, rdecay)
	}),
	#[0.1, 10, \exp], EnvSpec(Env.perc(0.01, 0.99)),
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
		}, rdecay, time, { |sig, rfreq, rdecay|
			Ringz.ar(sig, rfreq, rdecay)
		}, amp,
		{ |trig, decay|
			var	proportion = TRand.kr(0.02, 0.9, trig);
			Env([0, 1, 0], [proportion, 1 - proportion] * decay, #[3, -3])
		},
		/*numOverlaps:*/ 3
	]);
	sig = sig * EnvGen.kr(Env.linen(0.1, sustain, 0.1, curve: -2), doneAction: 2);
	Pan2.ar(sig, pan);
}).add;


\addRvbOut.eval(\combskid, { |noisebuf, nfreq = 440, beats = 4.64,
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
		}, rdecay, time,
		/*filterFunc:*/ { |sig, rfreq, rdecay|
			var	dt = rfreq.reciprocal,
				lpffreq = NamedControl.kr(\lpffreq, 4000);
			LPF.ar(CombL.ar(sig, dt + 0.1, dt, rdecay), lpffreq)
		},
		amp,
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
		~lpffreqCtl = GenericGlobalControl(\lpffreq, nil, 4000, \freq);
	};
	~useGui = { |vpi| [~timeMulCtl, ~lpffreqCtl].do { |gc| gc => VP(vpi) } };

	~freeCleanup = {
		[~glrvbmc, ~lcrvbmc].do { |mc| mc.tryPerform(\stopsReceivingFrom, ~chan) };
		[~buf, ~chan, ~timeMulCtl, ~lpffreqCtl].free;
	};

	~nfreq = Pexprand(40.0, 1800.0, inf);
	~rdecay = 1;
	~delta = Pwhite(0.4, 1.5, inf);
	~sustain = Pkey(\delta) * Pwhite(3.0, 6.0, inf);
	~loTime = Pexprand(0.12, 0.22, inf);
	~hiTime = Pkey(\loTime);
	~amp = 0.9; // 8.dbamp;

	~rewriteProb = 0.3;
	~rewriteLevel = Plazy({
		Pseq([0, 0, 1, 2, Pwhite(1, 3, inf)], 1);
	});
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
	~lpffreq = Plazy { Pn(~lpffreqCtl.asMap, inf) };
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
				// this works if ev[\node] is either a node or array of nodes
				ev[\node].do { |node| ev[\xylock].addNode(node) };
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
			\lpffreq, BPStream(\lpffreq),
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
			distNear: 5, distFar: 20,
			bufbase: VC(~vcKey).env[\wt].first.bufnum
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
	~degree = Plazy({
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
	});

	~dur = Pwrand(#[1, 2], #[0.9, 0.1], inf);
// 	~legato = Pwrand(#[1.01, 0.9, 0.4], #[0.7, 0.2, 0.1], inf); // 1.01;
	~gate = 0.8;
	~amp = -14.dbamp;
	~freqlag = 0.3;
	~detune = 1.003;
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
			\root, 7,
			\midi, (BPStream(\degree).degreeToKey(#[0, 2, 4, 5, 7, 9, 11]) + 67),
			\freq, Pkey(\midi).midicps,
			\delta, BPStream(\dur),
// 			\legato, BPStream(\legato),
			\freqlag, BPStream(\freqlag),
			\detune, BPStream(\detune),
			\gate, BPStream(\gate),
			\ffreq, BPStream(\ffreq),
			\rq, BPStream(\rq),
			\pan, BPStream(\pan),
			\distance, BPStream(\distance),
			\chan, VC(\am).env.target,
			\ampMul, BPStream(\amp)
		).collect { |ev| ~lastEvent = ev; ev }
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
	~target = MixerChannel(name, s, 2, 2/*, level: -17.dbamp*/, outbus: ~master,
		completionFunc: { |chan|
			~chorus = chan.playfx(Instr("busfx.chorus"), [0, 2, 0.011924888841111, 0.15615231995716, 0.0044072173729238, 1.1, 0.5]);
			StaticEQ(2, \hishelf, 3654.349, 4.274.dbamp, 1, \eq, 301.329, -5.641.dbamp, 1.286)
				.play(chan);
			~chorus.doWhenPlaying { ~chorus.synth.moveToHead(chan.effectgroup) };
		});
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


// from violin piece - modified
(keys: #[master, glrvbmc, lcrvbmc],
numRows: 8,
numCols: 8,
env: Env.adsr(1, 0.4, 0.8, 1.2, curve: -2),
fenv: Env.one,
graphInsert: nil,
makeTempAmps: {
	{ |i| Array.triangleAmps((20000 / ((4+i) * 12).midicps).asInteger) } ! ~numRows
},
randomizeAmps: { |amps|
	amps + ({ 0.12.rand2 } ! amps.size)
},
spatialize: true,
make: { |name|
	var	tempAmps = ~makeTempAmps.(),
		ugenfunc,
		out;

	~target = MixerChannel(name, s, 2, 2, outbus: ~master, completionFunc: { |chan|
		var	patch = chan.playfx(Instr("busfx.chorus2"), [0, 1, 2, 3, 0.006957213735427, 0.1708276390401, 0.0034747717625074, 1.1689647098094, 0.3]);
		patch.doWhenPlaying({
			patch.synth.moveToTail(chan.effectgroup);
		});
		// EQ?
	});
	[~glrvbmc, ~lcrvbmc].do { |mc|
		mc.tryPerform(\receivesSignalFrom, ~target);
	};

		// generate a matrix of buffers
		// if numCols is 8, 0-7 have the most partials, 8-15 have fewer, etc.
		// each column is randomized differently for more animation in higher partials
	~bufs = Buffer.allocConsecutive(~numRows * ~numCols, s, 2048, 1);
	fork {
		~bufs.do({ |buf, i|
			var	amps = tempAmps[i div: ~numCols];
0.06.wait;
			buf.sine1(~randomizeAmps.(amps, i))
		});
"done generating buffers".debug;
	};

	WrapInstr([\osc2, \vosc3matrix], { arg freq, gate, bufbase, bufmod, env, vsens, detune,
		ffreq, rq, fenv, fenvsens = 1,
		numrows, numcols, basefreq, topfreq,
		attackTimeScale, decayTimeScale;
		var	sig1, sig2, amp, buf;
		var	baselog = log2(basefreq),
			freqmap = ((log2(freq) - baselog) * (numrows / (log2(topfreq) - baselog)))
				.clip(0, numrows - 2.001),
			fmapfloor = freqmap.floor,
			fmapfrac = freqmap - fmapfloor,
			detunedown = freq/detune,
			detuneup = freq*detune,
			// env timescale handling: [0] is filter eg, [1] is amp
			envs = LocalIn.kr(2),
			eg_test = envs.collect { |eg| Select.kr(Impulse.kr(0), [eg, 0]) },
			// once envelope starts going down, attack phase is over
			hit1 = PulseCount.kr(HPZ1.kr(eg_test) < 0) > 0,
			timeScales = Select.kr(hit1, [attackTimeScale, decayTimeScale]);
		amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
		buf = bufbase + (fmapfloor * numcols) + bufmod;
		#sig1, sig2 = VOsc3.ar([buf, buf+numcols], detunedown, freq, detuneup);
		eg_test = [fenv, env].collect { |e, i|
			EnvGen.kr(e, gate, timeScale: timeScales[i], doneAction: 2 * i);
		};
		LocalOut.kr(eg_test);
		ffreq = (ffreq * Sensitivity.kr(1, eg_test[0], fenvsens)).clip(20, 20000);
		RLPF.ar(XFade2.ar(sig1, sig2, fmapfrac.madd(2, -1), amp),
			ffreq, rq, mul: eg_test[1]);
	}, [\freq, \amp, #[0, 1000, \linear, 1, 0], #[0, 20], EnvSpec(Env.adsr), #[0, 1], #[0.9, 1.1, \linear, 0, 1], \freq, #[1, 0.001], EnvSpec(Env.one), nil, #[0, 20, \lin, 1, 0], #[0, 20, \lin, 1, 0], \freq, \freq, #[0.01, 10, \exp, 0, 1], #[0.01, 10, \exp, 0, 1]]);

	~defname = (name ++ "def").asSymbol;
	ugenfunc = { |pan, finalAmp = 1, freq = 440, freqlag = 0, gate = 1, ffreq = 14000, rq = 1, vsens = 0.8, fenvsens = 1, attackTimeScale = 1, decayTimeScale = 1|
		var	sig = WrapInstr("osc2.vosc3matrix").valueArray([
			Lag.kr(freq, freqlag), gate,
			~bufs[0].bufnum,  // bufbase
			{	var	rate = Rand(0.7, 1.4),
					dur = rate.reciprocal,
					pulse = Impulse.kr(rate),
					buf = Demand.kr(pulse, 0, Dseq([
						Dwhite(0.0, ~numCols * 0.25, 1),
						Dwhite(~numCols * 0.7, ~numCols-1.001, 1)
					], inf));
				EnvGen.kr(Env([Rand(~numCols * 0.7, ~numCols-1.001), buf], [dur]), pulse)
			},
			~env,
			vsens, /*detune:*/ 1.003,
			ffreq, rq, ~fenv, fenvsens,
			~numRows, ~numCols,
			/*basefreq:*/ 48.midicps, /*topfreq:*/ (11*12).midicps,
			attackTimeScale, decayTimeScale
		]);
		~graphInsert !? { sig = ~graphInsert.(sig) };
		Pan2.ar(sig, pan, finalAmp)
	};
	if(~spatialize != false) {
		\addRvbOut.eval(~defname, ugenfunc).add;
	} {
		SynthDef(~defname, { |outbus|
			Out.ar(outbus, SynthDef.wrap(ugenfunc))
		}).add;
	};

	out = Voicer(25, ~defname, target: ~target);
	
	out.mapGlobal(\ffreq, nil, 14000, \freq);
	out.mapGlobal(\rq, nil, 1.0, \myrq);
	// out.mapGlobal(\fenvsens, nil, 1.0, #[0.1, 15, \exp]);
	
	// ~target.doWhenReady({ |chan|
	// 	chan.playfx({ |outbus|
	// 		RLPF.ar(In.ar(outbus, 1),
	// 			out.globalControls[\ffreq].kr, 
	// 			out.globalControls[\rq].kr
	// 		)
	// 	})
	// });
	
	out
}, free: { [~target, ~bufs].free }, type: \voicer) => Fact(\shimmerpad);



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
	~amp = -14.dbamp;

	~mod_lev = Pkey(\distance).linlin(Pkey(\distNear), Pkey(\distFar), 2.5, 1);
	~mod_ratio = 1;
	~radius = sin(Ptime() * 2pi / 11.3247623) * 0.5 + (0.5 * Pkey(\rotSpeed) / Pfunc { ~maxRotSpeed });
// 	~radius = sin(Ptime() * 2pi / 11.3247623) * 0.2 + (0.8 * Pkey(\rotSpeed));

//	~dur = Pwrand(#[1, 2], #[0.9, 0.1], inf) * Pkey(\rotSpeed).linexp(0.1, Pfunc { ~maxRotSpeed }, 0.4, 0.08);

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
			angleBus: Bus.control(s, 1 /*, name + "angle"*/)/*.debug("anglebus")*/,
			rotSpeedBus: Bus.control(s, 1 /*, name + "rotSpeed"*/)/*.debug("rotspeedbus")*/,
			yxRatioBus: Bus.control(s, 1 /*, name + "rotSpeed"*/)/*.debug("yxratiobus")*/,
			shouldFreeGCs: true,
			initChords: {
				~fullCh = self[\fullCh];
			},
			chord: (~chordStream ?? { ~makeStreamForKey.(\chord) }).next,
			startAuto: ~startAuto
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

	~bpsKeys = #[radius, /*chord,*/ chordItem, row, midinote, gate, mod_lev, mod_ratio, dur, sustain, attScale, decScale, arpeg, maxRotSpeed, speedMul, durxfer, amp];

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

	// TEMPORARY FOR RECORDING ONLY
	~startAuto = {
		var	time = ~chordTimeStream.next, proportion = rrand(0.7, 0.85), upd;
		~automationTime = time;  // communicate back
		fork {
			~rotSpeed.automate({
				Line.kr(0, 1, time, doneAction: 2);
				LFDNoise1.kr(Rand(0.8, 1.5)).range(1.8, 3.0)
			},
				[time: time],
				~event[\voicer].tryPerform(\bus).tryPerform(\asMixer)
					.tryPerform(\fadergroup),
				\addToHead);
			s.sync;
			~angle.automate(\angleAuto,
				[speedMul: ~speedMul.asMap, speedBus: ~rotSpeed.bus],
				~rotSpeed.autoSynth, \addAfter);
			~yxRatio.automate({
					EnvGen.kr(Env([Rand(0, 2.5), Rand(3.5, 5), Rand(0, 2.5)], [proportion, 1 - proportion], \sine))
				},
				nil,
				~rotSpeed.autoSynth, \addAfter);
			NodeWatcher.register(~rotSpeed.autoSynth);
			upd = Updater(~rotSpeed.autoSynth, e { |obj, what|
				if(what == \n_end) {
					upd.remove;
					if(BP.exists(~collIndex)) {
						BP(~collIndex).stop(0);
					};
				};
			});
		};
	};

	// ~startAuto = {
	// 	var	time = ~chordTimeStream.next, proportion = rrand(0.7, 0.85);
	// 	s.makeBundle(nil, {
	// 		~rotSpeed.automate(\rotSpeedAuto,
	// 			[inbus: BP(\di).bus.index + 4, time: time, proportion: proportion],
	// 			~event[\voicer].tryPerform(\bus).tryPerform(\asMixer).tryPerform(\fadergroup),
	// 			\addToHead);
	// 		~angle.automate(\angleAuto,
	// 			[speedMul: ~speedMul.asMap, speedBus: ~rotSpeed.bus],
	// 			~rotSpeed.autoSynth, \addAfter);
	// 		~yxRatio.automate(\yxRatioAuto, 
	// 			[inbus: BP(\di).bus.index + 7],
	// 			~rotSpeed.autoSynth, \addAfter);
	// 	});
	// 	OSCpathResponder(s.addr, ['/n_end', ~rotSpeed.autoSynth.nodeID], e { |time, resp, msg|
	// 		resp.remove;
	// 		if(BP.exists(~collIndex)) {
	// 			BP(~collIndex).stop(0);
	// 		};
	// 	}).add;
	// };

	~stopCleanup = {
		s.makeBundle(0.1, {
			[~angle, ~rotSpeed, ~yxRatio].do { |gc| gc.stopAuto.stopWatching }
		});
	};

	// f'ed up: it's possible to free the bus while autosynth is still going
	// shouldn't be, but it's happening: a MC grabs a bus that's still automated
	// so I'll just fricken' work around it by holding the bus numbers a bit longer
	~freeCleanup = {
		var gcs;
		if(~shouldFreeGCs ? true) {
			gcs = [~angle, ~rotSpeed, ~yxRatio];
			{ gcs.free }.defer(0.2);
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
				\mod_ratio, BPStream(\mod_ratio),
				\dur, BPStream(\dur),
				\length, BPStream(\sustain),
				\attackTimeScale, BPStream(\attScale),
				\decayTimeScale, BPStream(\decScale),
				\finalAmp, BPStream(\amp)
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
		startFrame: 0,
		userprep: {
			~buf = Buffer.readAndQuery(s, ~path);
			~maxVel = GenericGlobalControl(\maxVel, nil, 9, #[0, 20, lin]);
			~maxRatio = GenericGlobalControl(\maxRatio, nil, 5.1, #[0.05, 15, exp]);
	
			SynthDef("data" ++ ~numCh, { |buf, outbus, frameRate = 30, startFrame = 0, loop = 0|
				var	fr = BufFrames.ir(buf),
					dur = fr / frameRate,
					notLoop = loop <= 0,
					end = fr + (10000 * notLoop),
					stopper = Line.kr(0, 1, dur - (startFrame / frameRate), doneAction: notLoop*2),
					ph = Phasor.kr(0, frameRate * ControlDur.ir, start: startFrame, end: end),
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
			topEnvironment[\seq] !? {
				topEnvironment[\seq].addDependant(currentEnvironment)
			};
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
			topEnvironment[\seq] !? {
				topEnvironment[\seq].removeDependant(currentEnvironment)
			};
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
						startFrame: ~startFrame,
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



// support for sunrise, hand stacking
// writing my own WeighBag alternative cuz the original sux
Proto {
	~prep = { |array, counts|
		~array = array;
		~counts = counts;
		~weights = counts.normalizeSum;
		~numItems = counts.sum;
		currentEnvironment
	};
	~add = { |item, num = 1|
		var	i = ~array.indexOf(item);
		if(i.notNil) {
			~counts[i] = ~counts[i] + num;
			~numItems = ~numItems + num;
		} {
			~array = ~array.add(item);
			~counts = ~counts.add(num);
		};
		~weigh.();
	};
	~get = { |i| ~array[i] };
	~remove = { |item, num = 1|
		var	i = ~array.indexOf(item);
		if(i.notNil) {
			if(~counts[i] > num) {
				~counts[i] = ~counts[i] - num
			} {
				~array.removeAt(i);
				~counts.removeAt(i);
			};
			~weigh.();
		};
	};
	~choose = { ~array.wchoose(~weights) };

	~weigh = {
		~numItems = ~counts.sum;
		~weights = ~counts / ~numItems;
	};
} => PR(\fixedWeighBag);



{ |array, weights|
	var	bag = PR(\fixedWeighBag).prep(array, weights),
		balCounts = bag.counts div: 2,
		bcsum = balCounts.sum,
		indices = balCounts.collectIndices(_ > 0),
		i,
		result = Array(weights.sum);
	// first half, use half of each
	bcsum.do {
		result.add(bag.get(i = indices.wchoose(balCounts.normalizeSum)));
		bag.remove(result.last);
		balCounts[i] = balCounts[i] - 1;
	};
	while { bag.numItems > 0 } {
		result.add(bag.choose);
		bag.remove(result.last);
	};
	result
} => Func(\shufBalance);



// sunrise

PR(\abstractProcess).clone {
	~alwaysReset = true;
	~printStopMsg = false;
	~event = (eventKey: \voicerNote);
	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;
		~ampCtl = GenericGlobalControl(\ampMul, nil, -18.dbamp, \amp);
	};
	~ctlGuiKeys = #[ampCtl];
	~useGui = Func(\bpUseGui).v;
	~freeCleanup = { ~ampCtl.free };

	~pan = 0;
	~distance = 5;
	~dur = Pseg(
		Pseq(#[0.5, 0.1, 0.5], 1),
		3, \exp
	);
	~freq = Pseries(26,
		Pseq(\shufBalance.eval([-1, 1, 2, 3], [6, 9, 11, 4]), 1)
			* Pif(Pkey(\diff) > 0, -1, 1),
		inf
	);
	~mode = \g;
	~gate = Pkey(\dur).linlin(0.1, 0.5, 0.6, 0.2);
	~mod_lev = 2.5;
	~count = Pseries(1, 1, inf);
	~length = Pif(Pkey(\count) < 18, Pwhite(2.0, 3.5, inf),
		(Pwhite(3.6, 4.8, inf) - Pseries(0, Pkey(\dur), inf))); //.trace,
	~attackTimeScale = 1;
	~decayTimeScale = 1;

	~asPattern = {
		Pbind(
			\finalAmp, ~ampCtl.asMap,
			\pan, BPStream(\pan),
			\distance, BPStream(\distance),
			\dur, BPStream(\dur),
			\diff, Pdiff(Pkey(\dur)),
			\freq, BPStream(\freq),
			\mode, BPStream(\mode),
			\gate, BPStream(\gate),
			\mod_lev, BPStream(\mod_lev),
			\count, BPStream(\count),
			\length, BPStream(\length),
			\attackTimeScale, BPStream(\attackTimeScale),
			\decayTimeScale, BPStream(\decayTimeScale)
		)
	};

	~reset = Func(\resetBPStreams).v;
} => PR(\sunrise);


// hand stacking
// need Psetp but for multiple key-value pairs

Proto {
	~canEmbed = true;
	~outerOverridesInner = true;
	~prep = { |outerPat, innerPat, envir|
		~outerPat = outerPat;
		~innerPat = innerPat;
		~envir = envir ?? { currentEnvironment };
		currentEnvironment
	};
	~embedInStream = { |inval|
		var self = currentEnvironment,
			outerStream = ~envir.use { self[\outerPat].asStream },
			innerStream,
			outerEvent, innerEvent;
		while { (outerEvent = outerStream.next(inval)).notNil } {
			innerStream = ~envir.use { self[\innerPat].asStream };
			while { (innerEvent = innerStream.next(inval.copy.putAll(outerEvent))).notNil } {
				if(self[\outerOverridesInner] == true) { innerEvent.putAll(outerEvent) };
				inval = innerEvent.yield;
			};
		};
		inval
	};
	~asStream = { Routine { |inval| ~embedInStream.(inval) } };
	~asPattern = { Prout(e { |inval| ~embedInStream.(inval) }) };
	~play = { |clock, protoEvent, quant|
		~asPattern.().play(clock, protoEvent, quant)
	};
} => PR(\psetp2);


PR(\abstractProcess).clone {
	~alwaysReset = true;
	~reset = Func(\resetBPStreams).v;
	~printStopMsg = false;
	~event = (eventKey: \voicerNote);
	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;
		~ymaxCtl = GenericGlobalControl(
			\ymax,
			SharedBus.new(\control, BP(\di).bus.index + 3, 1, s),
			0, \bipolar
		).watch;
		~ampCtl = GenericGlobalControl(\ampMul, nil, -18.dbamp, \amp);
	};
	~ctlGuiKeys = #[ampCtl, ymaxCtl];
	~useGui = Func(\bpUseGui).v;
	~freeCleanup = { [~ampCtl, ~ymaxCtl].free };

	// ~root = Pstutter(Pwrand(#[1, 2], #[0.8, 0.2], inf), Pseq([
	// 	Pwhile1({ |inval, next| next < 40 },
	// 		Pseries(26, Pwrand(#[1, 2, 3], #[1, 4, 3].normalizeSum, inf), inf)
	// 	),
	// 	Pwhile1({ |inval, next| next >= 21 },
	// 		Pseries(40, Pwrand(#[-1, -2, -3], #[1, 4, 3].normalizeSum, inf), inf)
	// 	)
	// ]));
	~root = Plazy({ ~ymaxCtl.asPattern.linlin(-0.7, -0.3, 23.5, 39.49).round });
	~num = Pexprand(2.5, 6.499, inf).round;

	~angle = Pseries(
		{ 2pi.rand },
		Pwhite(0.1, 0.4, inf) * Pstutter(inf, Prand(#[-1, 1], 1)),
		inf
	);
	~radius = Paccumbounce(0.2, 1, Pexprand(0.04, 0.1, inf)).asStream;
	~pan = cos(Pkey(\angle)) * Pkey(\radius);
	~distance = (sin(Pkey(\angle)) * Pkey(\radius)).linlin(-1, 1, 5, 20);
	~dur = Plazy({ |ev|
		Pgeom.fromEndpoints(rrand(0.2, 0.32), rrand(0.09, 0.14), ev[\num])
		* Pexprand(0.75, 1.333, inf)
	});
	~freq = Pwhile1({ |ev, next| next <= 54 },
		Pkey(\root) + Pseries(0,
			Pwrand(#[1, 2, 3, 4], #[1, 4, 3, 2].normalizeSum, inf), Pkey(\num).asStream)
	);
	~mode = \g;
	~gate = 0.5;
	~mod_lev = 2.5;
	~length = Pwhite(3.0, 4.5, inf) - Pseries(0, Pkey(\dur), inf);
	~attackTimeScale = 0.25;
	~decayTimeScale = 1;
	~rest = Pwhite(0.15, 0.35, 1);

	~asPattern = {
		var	self = currentEnvironment;
		~restStream ?? { ~makeStreamForKey.(\rest) };
		PR(\psetp2).copy.prep(
			Pbind(
				\root, BPStream(\root, envir: self),
				\num, BPStream(\num, envir: self)
			),
			Pseq([
				Pbind(
					\finalAmp, ~ampCtl.asMap,
					\angle, BPStream(\angle, envir: self),
					\radius, BPStream(\radius, envir: self),
					\pan, BPStream(\pan, envir: self),
					\distance, BPStream(\distance, envir: self),
					\dur, BPStream(\dur, true, envir: self),
					\freq, BPStream(\freq, true, envir: self),
					\mode, BPStream(\mode, true, envir: self),
					\length, BPStream(\length, true, envir: self),
					\gate, BPStream(\gate, true, envir: self),
					\mod_lev, BPStream(\mod_lev, true, envir: self),
					\attackTimeScale, BPStream(\attackTimeScale, true, envir: self),
					\decayTimeScale, BPStream(\decayTimeScale, true, envir: self)
				),
				Pbind(
					\freq, #[],
					\dur, Pfuncn(e { ~restStream.next }),
					\length, 0.2,
					\gate, 0.1
				)
			], 1)
		)
	};
} => PR(\stacking);



// partnering/inversions

PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);
	~autoRun = false;
	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;
		~ampCtl = GenericGlobalControl(\ampMul, nil, -18.dbamp, \amp);
	};
	~ctlGuiKeys = #[ampCtl];
	~useGui = Func(\bpUseGui).v;
	~freeCleanup = { ~ampCtl.free };

	~gest = Pseq(#[inversion1, inversion2, lauraslide], inf);
	~numEv = Pwhite(12, 19, inf);
	~totalDur = Pwhite(2.5, 4.0, inf);
	~rest = Pwhite(0.8, 1.6, inf);

	~pan = { |parms|
		Pseries.fromEndpoints(rrand(-1.0, -0.5), rrand(0.5, 1.0), parms[\numEv])
			* #[-1, 1].choose;
	};
	~distance = { |parms|
		Pseries.fromEndpoints(rrand(15.0, 18.0), rrand(5.0, 7.0), parms[\numEv])
	};
	~dur = { |parms|
		Pgeom.fromEndpoints(rrand(0.12, 0.22), rrand(0.06, 0.09), parms[\numEv])
			* Pexprand(0.75, 1.333, inf);
	};
	~freq = { |parms|
		Pwhile1({ |ev, next| next <= 54 },
			~slideNotes[parms[\gest]].value(parms) + 28)
	};
	~mode = \g;
	~ffreq = Pfunc { |ev| Mode(ev[\mode]).cps(ev[\freq]) * 4 };
	~gate = Pkey(\freq).linlin(14, 54, 0.1, 0.8);
// 	~mod_lev = 2.5;
	~length = { |parms|
		(Pwhite(0.8, 1.2, inf) * parms[\totalDur]) - Pseries(0, Pkey(\dur), inf);
	};
	~attackTimeScale = Pkey(\gate).linlin(0.1, 0.8, 1.4, 0.15);
	~decayTimeScale = 1;

	~slideNotes = (
		lauraslide: Pseries(
			{ rrand(-7, 0) },
			Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
			Pkey(\numEv).asStream
		),
		inversion1: Pseries(
			{ rrand(-3, 4) },
			Pstutter(
				Pseq([Pfuncn({ |ev| (ev[\numEv] * 0.6).round }), 100], 1),
				Pseq([1, -1], 1)
			) * Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
			Pkey(\numEv).asStream
		),
		inversion2: Pseries(
			{ rrand(0, 8) },
			Pstutter(
				Pseries(1, 1, inf),
				Pseq([1, -1], inf, 0 /*, { 2.rand }*/)
			) * Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
			Pkey(\numEv).asStream
		)
	);

	~runGesture = { |parms|
		if(~spawner.notNil) {
			~spawner.par(~makePhrase.(parms));
		} {
			"BP(%): Not playing; can't run phrase.".format(~collIndex.asCompileString).warn;
		};
	};

	~makePhrase = { |parms(Event.new)|
		block { |break|
			var val;
			#[gest, numEv, totalDur].do { |key|
				parms[key] ?? {
					if((val = (key ++ "Stream").asSymbol.envirGet.next(parms)).isNil) {
						break.(nil)
					};
					parms[key] = val;
				};
				("phraseStats" ++ key).asSymbol.envirPut(parms[key]);
			};
			Pbind(
				\parms, parms,
				\numEv, parms[\numEv],
				\finalAmp, ~ampCtl.asMap,
				\pan, ~pan.(parms),
				\distance, ~distance.(parms),
				\dur, ~dur.(parms),
				\freq, ~freq.(parms),
				\mode, BPStream(\mode),
				\ffreq, BPStream(\ffreq),
				\gate, BPStream(\gate),
				\length, ~length.(parms),
				\attackTimeScale, BPStream(\attackTimeScale),
				\decayTimeScale, BPStream(\decayTimeScale)
			)
		}
	};

	~asPattern = {
		#[gest, numEv, totalDur, rest].do { |key|
			(key ++ "Stream").asSymbol.envirGet ?? {
				~makeStreamForKey.(key)
			};
		};
		Pspawner({ |sp|
			~spawner = sp;
			if(~autoRun) {
				"BP(%): autoRun enabled\n".postf(~collIndex.asCompileString);
				loop {
					sp.seq(~makePhrase.());
					sp.wait(~restStream.next());
				}
			} {
				loop {
					sp.wait(0.1);
				}
			}
		})
	};
} => PR(\armsInv);



// Shiva

(
make: {
	3.collect { |i|
		var	bp = PR(\melody) => BP(("am" ++ i).asSymbol);
		bp.pan = #[0, -0.8, 0.8][i];
		0 => bp;

		bp.event.distFar_(50).lcrvbamt_(0.035).ampMul_(nil);
		bp.gate = Penvir((), Pseg(
			Pstutter(2, Pseq([
				Pexprand(0.1, 0.22, 1),
				Pwhite(0.6, 0.9, 1)
			], inf)),
			// hold, then slide
			Ppatlace([
				Pwhite(3.0, 8.0, inf),
				Pwhite(1.1, 2.2, inf)
			], inf)
		).collect { |val|
			if(~once.isNil) { val.debug("starting from scratch"); ~once = true };
			val
		});
		bp.distance = Pkey(\gate).linlin(0.1, 0.75, 45, 8);
	};
},
type: \bp) => Fact(\shivaBPs);


(play: {
// currentEnvironment.debug;
	min(3, ~i).do { |j|
		BP(("am" ++ j).asSymbol).triggerOneEvent(0);
	};
	if(~playtc and: { BP.exists(\tc) }) { BP(\tc).triggerOneEvent(0.1) };
}) => ProtoEvent(\amTrig);

PR(\abstractProcess).clone {
	~event = (eventKey: \amTrig);
	~quant = NilTimeSpec.new;

	~playtc = 0.5.asPattern.coin;
	~delta = Pwhite(1.5, 3.0, inf);
	~i = Pseries(1, 1, inf);

	~asPattern = {
		Pbind(
			\i, BPStream(\i),
			\playtc, BPStream(\playtc),
			\delta, BPStream(\delta)
		)
	};
	~stopCleanup = {
		BP(#[am0, am1, am2, tc]).stop(0);
	};

	~reset = {
		BP(#[am0, am1, am2, tc]).do(_.reset);
	};
} => PR(\shivaTrig);


PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);
	~bpFilter = { |key|
		key = key.asString;
		key[..1] == "am" and: { key[2..].every(_.isDecDigit) }
	};
	~prep = {
		~setBPs.();
		~event.proto = topEnvironment[\rvbEvent].proto;
	};
	~setBPs = { |bpFilter(~bpFilter)|
		~bps = BP.all.select { |bp| bpFilter.(bp.collIndex) };
	};

	~stopCleanup = {
		~event[\voicer].tryPerform(\releaseAll);
	};

	~mode = \g;
	~freq = Pfunc { |ev|
		var	result = Array.new(~bps.size), midi;
		~bps.do { |bp|
			if(bp[\node].notNil and: { (midi = bp[\lastEvent].tryPerform(\at, \midi)).notNil }) {
				result.add(midi.mapMode(ev[\mode]));
			};
		};
		result
	};
	~dur = 4;
	~length = inf;
	~gate = 0.1;
	~attackTimeScale = 2.5;
	~decayTimeScale = 2.5;
	~finalAmp = -6.dbamp;
	~distance = Pwhite(12.0, 18.0, inf);
	~pan = Pwhite(-0.7, 0.7, inf);
	~fenvsens = 0;

	~asPattern = {
		Pbind(
			\mode, BPStream(\mode),
			\freq, BPStream(\freq),
			\dur, BPStream(\dur),
			\length, BPStream(\length),
			\gate, BPStream(\gate),
			\attackTimeScale, BPStream(\attackTimeScale),
			\decayTimeScale, BPStream(\decayTimeScale),
			\finalAmp, BPStream(\finalAmp),
			\distance, BPStream(\distance),
			\pan, BPStream(\pan),
			\fenvsens, BPStream(\fenvsens)
		).collect { |ev|
			~lastEvent !? {
				~lastEvent[\nodes].do { |node, i|
					// releases only if node hasn't been stolen
					node.release(0, (~lastEvent[\lag] ? 0) + (node.server.latency ? 0),
						~lastEvent[\newFreq].wrapAt(i))
				};
			};
			~lastEvent = ev;
			ev
		}
	};
} => PR(\thinChords);



// 3 levels
(
keys: #[master, glrvbmc, lcrvbmc],
make: {
	3.collect { |i|
		PR(\armsSkidMel).chuck(BP((\sm ++ i).asSymbol), nil, (
			master: ~master,
			glrvbmc: ~glrvbmc,
			lcrvbmc: ~lcrvbmc,
			amp: 0.9,
			rewriteLevel: Pseq([0, 1, 2, Pwhite(1, 3, inf)], 1),
			loTime: Pwhite(0.22, 0.45, inf),
			hiTime: Pkey(\loTime) * Pexprand(1.0, 1.25, inf)
		)).prepareForPlay;
	};
}, type: \bp) => Fact(\threelevBP);


(play: {
// currentEnvironment.debug;
	min(3, ~i).do { |j|
		2.do { BP(("sm" ++ j).asSymbol).triggerOneEvent(0) };
	};
	if(~playtc and: { BP.exists(\tc) }) { BP(\tc).triggerOneEvent(0.1) };
}) => ProtoEvent(\l3Trig);


(make: { |name|
BP(name).free;
PR(\shivaTrig).chuck(BP(name), nil, (
	event: (eventKey: \l3Trig),
	playtc: false,
	i: 3
));
}, type: \bp) => Fact(\l3Trig);



// s & i
PR(\abstractProcess).clone {
	~event = (eventKey: \monoSupport);
	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;		
	};

	~mode = \g;
	~high = Pseq([0, 1, Pseq([Pn(0, { rrand(1, 5) }), Pn(1, { rrand(1, 2) })], inf)], 1);
	~prevHigh = Pdelay(Pkey(\high));
	~top = Pswitch1([
		Paccumbounce(30, 40, Pwrand(#[-1, 1, 2, 3], #[3, 3, 2, 1].normalizeSum, inf)),
		Paccumbounce(38, 47, Pwrand(#[-1, 1, 2, 3], #[3, 3, 2, 1].normalizeSum, inf))
	], Pkey(\high));
	~degree = (Pkey(\top) -.x Pseries(0, Pwrand(#[1, 2, 3], #[1, 3, 2].normalizeSum, 3)))
		.clump(3);
	~freq = Pfunc { |ev| Mode(ev[\mode]).cps(ev[\degree].scramble) };
	~delta = Pwhite(1, 4, inf);
	~freqlag = min(Pkey(\delta) * 0.6, 1.1); // Pkey(\delta) * 0.6;
	~finalAmp = -12.dbamp;
	~protoEvent = Pseq([
		\polySynthPlayNotify,
		Pif(Pkey(\prevHigh) > 0, \polySynthPlayNotify, \polySynthTrigger)
	], 1);
	~sustain = Pif(Pkey(\high) > 0, Pkey(\delta) - 0.6, inf);
	~lag = Pif(Pbinop('==', Pkey(\protoEvent), \polySynthPlayNotify), 0,
		Pn(Pseries(0, Pwhite(0.12, 0.25, inf), 3).clump(3), inf));

	~recvEventNotify = { |node| ~node = node };
	~stopCleanup = { if(~node.notNil) { ~node.do(_.release) }; ~node = nil };

	~asPattern = {
		Pbind(
			\instrument, ~event[\voicer].nodes[0].defname,
			\node, Pfunc { ~node ? 0 },
			\chan, ~event[\voicer].nodes[0].bus.asMixer,
			\ffreq, ~event[\voicer].globalControls[\ffreq].asMap,
			\rq, ~event[\voicer].globalControls[\rq].asMap,
			\high, BPStream(\high),
			\prevHigh, BPStream(\prevHigh),
			\mode, BPStream(\mode),
			\top, BPStream(\top),
			\degree, BPStream(\degree),
			\freq, BPStream(\freq),
			\delta, BPStream(\delta),
			\freqlag, BPStream(\freqlag),
			\finalAmp, BPStream(\finalAmp),
			\protoEvent, BPStream(\protoEvent),
			\sustain, BPStream(\sustain),
			\lag, BPStream(\lag)
		).collect { |ev|
			var	sustain;
			if(ev[\prevHigh] > 0) {
				// listeners are free to ignore
				BP(~collIndex).changed(\modeChanged, ev[\mode]);
			};
			if((sustain = ev[\sustain]).notNil and: { sustain != inf }) {
				thisThread.clock.sched(sustain, e {
					// ~node may have been cleared before getting here
					if(~node.size > 0 or: { ~node.isKindOf(Node) }) {
						Func(\schedEventBundleArray).doAction(s.latency, 0, s,
							[\n_set, ~node.asArray.asOSCArgArray, \gate, 0].flop, true);
					};
					nil
				});
			};
			ev
		}
	};
} => PR(\siDuet);


// laura manipulation
(
keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;
	PR(\armsSkidMel).chuck(BP(name), nil, (
		master: ~master,
		glrvbmc: ~glrvbmc,
		lcrvbmc: ~lcrvbmc,
		amp: 0.4,
		def: \combskid,
		rdecay: 2,
		hiffreq: Pfunc { |ev| Mode(ev[\mode]).cps(ev[\degree] + 28) },
		lpffreq: Pexprand(1200, 7000, inf)
	));
	BP(name).chan.doWhenReady {
		BP(name).chan.playfx { |outbus|
			LeakDC.ar(In.ar(outbus, 2));  // combs have BAD dc
		};
	};
	0 => BP(name);
}, type: \bp) => Fact(\lauraManip);


// Stephen solo
(
keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;
	PR(\armsSkidMel).chuck(BP(name), nil, (
		event: (eventKey: \polySynthPlayer),
		master: ~master,
		glrvbmc: ~glrvbmc,
		lcrvbmc: ~lcrvbmc,
		amp: 0.4,
		// def: \combskid,
		// rdecay: 2,
		hiffreq: Pfunc({ |ev|
			var deg = ev[\degree];
			deg = deg + (#[0] ++ ({ #[-1, -2, -3].wchoose(#[0.3, 0.5, 0.4]) } ! 2).integrate);
			Mode(ev[\mode]).cps(deg + 42)
		}),
		lpffreq: Pexprand(1200, 7000, inf),
		delta: Pwhite(1.5, 4.0, inf),
		sustain: Pkey(\delta) * Pwhite(1.8, 2.5, inf)
	));
	0 => BP(name);
}, type: \bp) => Fact(\stephenSolo);


// cradling/drawing bow
PR(\abstractProcess).clone {
	~event = (eventKey: \monoSupport);
	~autoRun = false;
	~alwaysReset = true;

	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;
		~distCtl = GenericGlobalControl(\distance, nil, 5, #[5, 20]);
	};
	~useGui = { |vpi| ~distCtl => VP(vpi) };
	~freeCleanup = { ~distCtl.free };

	~topArrays = Pseq([
		#[35, 40],
		#[35, 41],
		#[37, 42, 43, 38, 33],
		Pfunc({
			Pseq([
				Paccumbounce(31, 38,
					Pwrand(#[-1, 1, 2, 3], #[3, 3, 2, 1].normalizeSum, inf) * #[-1, 1].choose,
					rrand(1, 5)
				),
				Pwhite(40, 47, 1)
			], 1)
		})
	], 1);
	~rest = 1;
	~mode = \g;
	~chordAdd = Pseries(0, Pwxrand(#[1, 2, 3, 4], #[2, 3, 2, 0.5].normalizeSum, 3)).clump(3);
	~freq = Pfunc { |ev| Mode(ev[\mode]).cps(ev[\degree].scramble) };
	~deltaBase = 1.2;
	~delta = Plazy({ Pif(Pkey(\last), 2, 1) * BPStream(\deltaBase) });
	~freqlag = 0.2;
	~finalAmp = -12.dbamp;
	~sustain = Pif(Pkey(\last), Pkey(\delta) - 0.6, inf);
	~distance = Plazy({ Pn(~distCtl.asMap, inf) });
	~pan = Pwhite(0.5, 0.9, inf) * Pfunc { #[-1, 0, 1].scramble };

	~runGesture = {
		if(~spawner.notNil) {
			~spawner.seq(~makePhrase.());
		} {
			"BP(%): Not playing; can't run phrase.".format(~collIndex.asCompileString).warn;
		};
	};

	~makePhrase = { |degrees|
		var	num;
		degrees ?? { degrees = ~topArraysStream.next };
		if(degrees.notNil) {
			degrees = degrees.dereference;
			if(degrees.isArray) { degrees = Pseq(degrees, 1) };
			num = degrees.estimateLength;
			Pbind(
				\instrument, ~event[\voicer].nodes[0].defname,
				\node, Pfunc { ~nodes ? 0 },
				\chan, ~event[\voicer].bus.asMixer,
				\last, Pseq([Pn(false, num-1), true], 1),
				\protoEvent, Pseq([
					\polySynthPlayNotify,
					Pn(\polySynthTrigger, inf)
				], 1),
				\mode, BPStream(\mode),
				\top, degrees,
				\degree, Pkey(\top) -.x ~chordAdd,
				\freq, BPStream(\freq),
				\delta, BPStream(\delta),
				\freqlag, BPStream(\freqlag),
				\finalAmp, BPStream(\finalAmp),
				\sustain, BPStream(\sustain),
				\pan, ~panStream.next,
				\distance, ~distanceStream.next
			).collect({ |ev|
				var	sustain;
				if((sustain = ev[\sustain]).notNil and: { ev[\sustain] != inf }) {
					thisThread.clock.sched(sustain, e {
						Func(\schedEventBundleArray).doAction(s.latency, 0, s,
							[\n_set, ~nodes.asArray.asOSCArgArray, \gate, 0].flop, true);
						~nodes = nil;
					});
				};
				ev
			})
		}
	};

	~recvEventNotify = { |nodes, event|
		~nodes = nodes;
	};
	~stopCleanup = {
		~nodes !? {
			~nodes[0].server.listSendBundle(~nodes[0].server.latency,
				~nodes.collect { |node| node.releaseMsg })
		};
		~nodes = nil;
	};

	~asPattern = {
		~topArraysStream ?? { ~makeStreamForKey.(\topArrays) };
		~restStream ?? { ~makeStreamForKey.(\rest) };
		~panStream ?? { ~makeStreamForKey.(\pan) };
		~distanceStream ?? { ~makeStreamForKey.(\distance) };
		Pspawner({ |sp|
			~spawner = sp;
			if(~autoRun) {
				"BP(%): autoRun enabled\n".postf(~collIndex.asCompileString);
				loop {
					sp.seq(~makePhrase.());
					sp.wait(~restStream.next());
				}
			} {
				loop {
					sp.wait(0.1);
				}
			}
		})
	};

	~reset = { ~makeStreamForKey.(\topArrays) };
} => PR(\rockingChords);



// melody for locomotive bits
// also introduces rhythm

(keys: #[master, glvrbmc, lcrvbmc],
make: { |name|
	var	out;
	~cb = Buffer.allocConsecutive(8, s, 1024, 1, { |buf, i|
		buf.sine1Msg(((0..i) + 1).reciprocal)
	});
	~target = MixerChannel(name, s, 2, 2, outbus: ~master);
	[~glvrbmc, ~lcrvbmc].do { |mc| mc.tryPerform(\receivesSignalFrom, ~target) };

	WrapInstr("osc2.fm10mod", { |freq, gate, car_env, mod_env, mod_lev, mod_ratio,
		detune, plusdetune,
		basefreq, keyscale,
		car_buf, car_vs, mod_vs,
		envTimeScale = 1 /*, blipDensity = 1, blipProb = 0.05, blipDur = 0.8 */|
		var sig, mod, car_amp, mod_amp, mod_freqs, mod_masks, blipTrig, blipTrigs, mod_blips;
		var	cbChanged = (HPZ1.kr(car_buf).abs > 0) + Impulse.kr(0),
			lastCb = Latch.kr(Delay1.kr(car_buf), cbChanged),
			evenOdd = PulseCount.kr(cbChanged) % 2,
			xfade = Lag.kr(evenOdd, 0.2).madd(2, -1),
			// the new bufnum in this array is always pointed to by evenOdd
			bufnums = Select.kr([1-evenOdd, evenOdd], [lastCb, car_buf]);
		car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
		mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate);
		mod_env = mod_env.dereference.value(mod_amp, mod_vs, gate);
		mod_amp = mod_amp * EnvGen.kr(mod_env, gate, timeScale: envTimeScale);
		mod_lev = mod_lev * basefreq / ((keyscale * freq) + (basefreq * (1 - keyscale)));
		// b/c of *.t, mod is a 2D array: [[normal pitch harmonic, detuned harmonic], ...]
		mod_freqs = (freq * mod_ratio + plusdetune) * (1..10) *.t [1, detune];
		mod_masks = mod_freqs.flop[0] < 20000;
		// blipTrig = Dust.kr(blipDensity);
		// blipTrigs = (TRand.kr(0, 1, blipTrig ! 10) <= blipProb) * blipTrig;
		// mod_blips = Decay2.kr(
		// 	blipTrigs,
		// 	blipDur * 0.2, blipDur * 0.8, 0.9, 0.1);
		mod = SinOsc.ar(mod_freqs, 0,
			mod_masks * mod_amp * mod_lev
			* LFDNoise1.kr(LFNoise1.kr({ ExpRand(0.1, 0.5) } ! 10).range(0.5, 5)).range(0, 1)
			// * mod_blips
		).sum;
		sig = bufnums.collect { |bufnum|
			Osc.ar(bufnum, (freq * [1, detune]) * (mod + 1), 0, car_amp).sum
		};
		XFade2.ar(sig[0], sig[1], xfade)
			* EnvGen.kr(car_env, gate, timeScale: envTimeScale, doneAction:2)
	}, [\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), #[0.01, 300, \exponential], #[0.25, 20, \linear, 0.5, 1], \mydetune, #[-5, 5, \linear, 0, 0], \freq, #[0.001, 1.0, \exp], NoLagControlSpec(0, 128, \lin, 1), nil, nil, #[0.1, 10, \exp, 0, 1] /*, #[0.1, 20, \exp], nil, #[0.05, 2.0, \exp]*/]);

	~def = \addRvbOut.eval(name ++ "def", { |freq, freqlag = 0.1, gate = 1,
		mod_lev = 20, mod_ratio = 1, detune = 1.006, car_buf,
		car_vs = 0.55, mod_vs = 0.8, envTimeScale = 1,
		pan = 0, mainAmp = 1 //,
		/*blipDensity = 1, blipProb = 0.05, blipDur = 0.8*/|
		// WrapInstr("osc2.fm10mod").listArgs
		var sig = WrapInstr("osc2.fm10mod").valueArray([
				Lag.kr(freq, freqlag), gate,
				Env.adsr(0.05, 0.15, 0.6, 0.12),
				`{ |mod_amp, mod_vs, gate|
					Env([0, mod_amp, 0.1, 0], [0.05, 0.1, 0.3], -4, releaseNode: 2)
					// Env.adsr(0.05, 0.1, 0.1, 0.3)
				},
				mod_lev, mod_ratio, detune,
				-1.456, // plusdetune
				48.midicps, // basefreq
				0.319, // keyscale
				car_buf, car_vs, mod_vs, envTimeScale //,
				// blipDensity, blipProb, blipDur
			]);
		Pan2.ar(sig, pan, mainAmp)
	}).add;

	out = MonoPortaVoicer(1, ~def.name, topEnvironment[\rvbEvent].proto.asKeyValuePairs ++ [glrvbamt: 0.3, lcrvbamt: 0.16, envTimeScale: 4.34], target: ~target).portaTime_(0.12);
	out.mapGlobal(\distance, nil, 10, #[5, 20]);
	out.mapGlobal(\pan, nil, 0, \bipolar);
	out
},
free: { [~cb, ~target].free },
type: \voicer) => Fact(\locomoLead);


PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote, mainAmp: -12.5.dbamp);
	~mode = \g;
	~alwaysReset = true;
	~printStopMsg = false;

	// ~prep = {
	// 	~event.proto = topEnvironment[\rvbEvent].proto;
	// };

	~freq = Pseq([
		Plazy({ ~ascent }),
		Plazy({ ~topDegree })
	], 1);
	~topDegree = 45;
	~ascent = Pwhile1({ |inevent, next| next < ~topDegree },  // 45 == 84.mapMode(\g)
		Pscratch(
			Pseries({ rrand(24, 28) }, Pwrand(#[-1, 1, 2, 3], #[0.7, 4, 3, 1].normalizeSum, inf), inf),
			Penvir((prev: -1, sideEffect: { |x| x }),  // sideEffect ignores args
				Pseq([
					Pn(1, { rrand(3, 5) }),
					Pwrand(#[-2, -1, 1], #[0.03, 0.07, 0.9], inf).reject { |val|
						~sideEffect.(val.isNegative and: { ~prev.isNegative },
							~prev = val);
					}
				])
			)
		)
	);

	~dur = Pswitch([Pn(0.25, 2), 0.5, 0.75, 1],
		Penvir((prev: -1, count: 0, countLimits: #[2, 3, 2, 1], sideEffect: { |x| x }),
			Pwrand([0, 1, 2, 3], #[1.4, 4, 2, 1].normalizeSum, inf).select { |val|
				~sideEffect.(~prev != val or: { ~count < ~countLimits[val] }, (
					if(~prev != val) {
						~prev = val;
						~count = 1;
					} {
						~count = ~count + 1
					};
				))
			}
		)
	);

	~length = Pkey(\dur) * Pwrand(#[0.7, 0.98, 1.01], #[0.1, 0.1, 0.8], inf);
	~gate = Pexprand(0.1, 0.65, inf);
	// Plazy: you have time to chuck a voicer in before resolving this pattern
	~car_buf = Plazy({
		var vc = VC.collection.detect { |vc| vc.value === ~event.voicer };
		if(vc.notNil and: { vc.env[\cb].notNil }) {
			Prand(vc.env.cb, inf)
		} {
			"BP(%).car_buf expects an array of buffers in the VC's ~cb variable. It's not there."
				.format(~collIndex.asCompileString).warn;
			nil
		};
	});
	~mod_ratio = Pwhite(3, 7, inf); // Pwhite(2, 7, inf) * 0.5;
	~mod_lev = Pkey(\gate).linexp(0, 1, 7, 25);

	~bpsKeys = #[mode, freq, dur, length, gate, car_buf, mod_ratio, mod_lev];
	~reset = {
		~bpsKeys.do { |key| ~makeStreamForKey.(key) };
	};

	~asPattern = {
		Pbind(
			\mode, BPStream(\mode),
			\freq, BPStream(\freq),
			\dur, BPStream(\dur),
			\length, BPStream(\length),
			\gate, BPStream(\gate),
			\car_buf, BPStream(\car_buf),
			\mod_ratio, BPStream(\mod_ratio),
			\mod_lev, BPStream(\mod_lev)
		)
	};
} => PR(\locoMel);



PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote, distFar: 100, lcrvbamt: 0.01);
	~printStopMsg = false;
	~alwaysReset = true;
	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;
		#[scaleLen, numDescents, numDecays, startDeg].do { |key| ~makeStreamForKey.(key) };
		~ampMul = GenericGlobalControl(\ampMul, nil, 0.26, [0, 12.dbamp, \amp]);
		~event.ampMul = ~ampMul.asMap;
		~addedWavetables = IdentitySet.new;
	};
	~freeCleanup = {
		~removeWavetables.();
		~ampMul.free;
	};

	~addWtToVoicer = { |key, ampFunc|
		if(ampFunc.notNil and: { ~vc.notNil }) {
			if(~vc.env[key].notNil) { ~vc.env[key].free };  // remove old buffers
			~vc.env[key] = \makeWavetables.eval(8, s, 2048, 48, ampFunc);
			~addedWavetables.add(key);
		} {
			"BP(%).addWtToVoicer: Either you didn't give an ampFunc or this BP has no voicer"
			.format(~collIndex.asCompileString).warn;
		};
	};
	~removeWavetables = {
		if(~addedWavetables.notEmpty and: { ~vc.exists }) {
			~addedWavetables.do { |key| ~vc.env[key].free; ~vc.env[key] = nil };
			~addedWavetables.clear;
		} {
			if(~addedWavetables.notEmpty) {
				"BP(%): Uh-oh... wavetables were added and VC was freed before cleanup. Leak?"
				.format(~collIndex.asCompileString).warn;
			}
		};
	};
	~bindVoicer = { |voicer|
		var	vc = VC.collection.detect { |vc| vc.v === voicer };
		if(vc.notNil) {
			~removeWavetables.();
			~vc = vc;
		} {
			~event.voicer = ~vc.v;
			"Voicer % isn't in the VC collection - can't chuck in!".format(voicer).warn;
		};
		currentEnvironment
	};

	~numDescents = 7;
	~scaleLen = Pwhite(2, 5, inf);
	~numDecays = Pwhite(5, 12, inf);
	~startDeg = Pwhite(47, 51, inf);
	~wtKey = \wt;

	~bufbase = Pfunc({ |ev|
		if(~vc.env[ev[\wtKey]].notNil) { ~vc.env[ev[\wtKey]].first.bufnum } { -1 }
	});

	~mode = \g0;
	~freq = Pseq([
		(
			Pseries({ |ev| ~startDegStream.next(ev) }, 
				Pwhite(-4, -2, { |ev| ~numDescentsStream.next(ev) }))
				.collect { |bot| ~bot = bot }
			+.x
			Pseries(0, 1, { |ev| ~scaleSize = ~scaleLenStream.next(ev) })
				.collect { |scale| ~scale = scale }
		)
		+.x
		Pif(
			Pfunc({ ~scale < (~scaleSize - 1) }),
			Pn(0, 1),
			Pwrand([0, Pseq([0, Pwhite(-6, -3, 1), -1], 1)], [0.6, 0.4], 1)
		),
		Plazy({ |ev|
			var	num = ~numDecaysStream.next(ev);
			~decay = num * 2;
			(~bot + ~scaleSize) + Pseq([0, #[-6, -5/*, -3*/].choose], num, 2.rand)
		})
	], 1);

	// ~dur = Pseq([0.5, Pn(0.25, { #[0, 1, 2, 3].wchoose(#[0.1, 0.4, 0.3, 0.2]) })], inf);
	~complexDur = PR(\pwxrandn).copy.prep([
		0.5, 0.75, 1,
		Pn(0.25, { #[1, 2, 3].wchoose(#[0.45, 0.35, 0.2]) })
	], Pstutter((Pwhite(6, 12, 3) * Pseq(#[1, 2, 20], 1)), Pseq([
		// #[0.45, 0.45, 0.1],
		// #[0.3, 0.3, 0.4]
		#[5, 5, 3, 1].normalizeSum,
		#[2, 1, 0.2, 4].normalizeSum
	], inf)), inf);
	~simpleDur = PR(\pwxrandn).copy.prep([
		0.5, 0.75, 1,
		Pn(0.25, { #[1, 2, 3].wchoose(#[0.45, 0.35, 0.2]) })
	], #[2, 1, 0.2, 4].normalizeSum, inf);
	~dur = ~simpleDur;
	~length = Pkey(\dur) * 2.5;
	~gate = Pif(Pkey(\dur) > 0.25, Pexprand(0.6, 0.9, inf), Pexprand(0.1, 0.35, inf));
	~angle = Plazy({ (Ptime() * (2pi/rrand(2.5, 7.5))) * #[-1, 1].choose });
	~decayCurve = Pseq([
		Pwhile1({ ~decay.isNil }, 1),
		Plazy({ Pgeom.fromEndpoints(1, 0.05, ~decay) })
	], 1);
	~pan = Pkey(\angle).sin * Pkey(\decayCurve);
	~origDistance = (Pkey(\angle).cos * Pkey(\decayCurve))
		.linlin(-1, 1,
			Pkey(\decayCurve).explin(0.05, 1, 100, 14),
			Pkey(\decayCurve).explin(0.05, 1, 100, 5)
		);
	~distance = ~origDistance;

	~ffreq = Pnsym1(Pkey(\wtKey), (
		wt: 12258,
		wt2: Pexprand(1000, 5000, inf),
		wt3: Pexprand(1000, 5000, inf)
	));
	~rq = Pif(Pbinop('==', Pkey(\wtKey), \wt), 1, Pexprand(0.25, 0.9, inf));
	// ~ffreq = 12258;
	// ~rq = 1;

	// see ~decayCurve for why
	~preparePlay = {
		~decay = nil;
		~resetStreams.do { |key| ~makeStreamForKey.(key) };
	};
	~resetStreams = #[freq, dur, length, gate, distFar, angle, decayCurve, pan, distance, mode];

	~asPattern = {
		Pbind(
			\mode, BPStream(\mode),
			\freq, BPStream(\freq),
			\dur, BPStream(\dur),
			\length, BPStream(\length),
			\gate, BPStream(\gate),
			\angle, BPStream(\angle/*, resetSource: true*/),
			\decayCurve, BPStream(\decayCurve),
			\pan, BPStream(\pan),
			\distance, BPStream(\distance),
			\wtKey, BPStream(\wtKey),
			\bufbase, BPStream(\bufbase),
			\ffreq, BPStream(\ffreq),
			\rq, BPStream(\rq)
		)
	};
} => PR(\bellMel);

(make: { |name|
	BP(name).free;
	BP(name).free;
	PR(\bellMel) => BP(name);
	if(VC.exists(\bmel)) {
		VC(\bmel) => BP(name);
		BP(name).addWtToVoicer(\wt2, { |numharm| Array.sawtoothAmps(numharm) });
		BP(name).addWtToVoicer(\wt3, { |numharm| Array.squareAmps(numharm) });
		BP(name).wtKey = Prand(#[wt, wt2, wt3], inf);
	} {
		"BP(%): VC(\\bmel) doesn't exist - didn't add extra wavetables."
		.format(name.asCompileString).warn;
	};
	0 => BP(name);
}, type: \bp) => Fact(\bmelBP);


// bass (starts in S&I)


(keys: #[master, glrvbmc],
make: { |name|
	var	v;
	WrapInstr("osc2.slidefm2", { |freq, gate, freqlag, mod_ratio, mrlag, pan = 0|
		var	sig = WrapInstr("osc2.fm2car").wrap([Lag.kr(freq, freqlag), gate, nil, nil, nil,
			Lag.kr(mod_ratio, mrlag)]);
		Pan2.ar(sig, pan)
	}, [\freq, NoLagControlSpec(0, 1, \lin, 0, 1), #[0, 2], #[0.5, 10.5, \lin, 0.5, 1], #[0, 2], \bipolar]);

	SynthDef(\hpfxfer, { |xferbus, outbus, ffreq = 300, level = 1|
		var	sig = In.ar(outbus, 2);
		Out.ar(xferbus, HPF.ar(sig, ffreq, level))
	}).add;

	~cb = Buffer.alloc(s, 2048, 1, { |buf| buf.sine1Msg(#[1, 0.5]) });
	~mb = Buffer.alloc(s, 2048, 1, { |buf| buf.sine1Msg(#[1]) });

	~target = MixerChannel(name, s, 2, 2, level: -12.dbamp, outbus: ~master,
		completionFunc: { |chan|
			// post-fader custom send
			~xfer = Synth(\hpfxfer, [xferbus: ~glrvbmc.inbus, ffreq: 290, level: 0.337],
				chan.synth, \addAfter);
			~chorus = chan.playfx(Instr("busfx.chorus2band"), [0, 2, 0.010549016482685, 0.13459606816896, 0.0082830816073226, 0.0, 290.0, 0.5]);
			chan.sendsSignalTo(~glrvbmc);
		}
	);
	
	v = MonoPortaVoicer(1, WrapInstr("osc2.slidefm2"), [car_buf: ~cb, mod_buf: ~mb ?? { ~cb }, basefreq: `440, keyscale: `0, freqlag: 0.8503937007874, mrlag: 0.283, mod_lev: 3.4531104925503 / 0.4, detune: 0.35433070866142, car_detune: 1.0044526098252, car_env: Env.adsr(0.01, 0.25, 0.6, 1.2), mod_env: Env.adsr(0.01, 0.04, 0.4, 1.5), car_vs: 0.26771653543307, mod_vs: 0.5748031496063], target: ~target);
	// gc's?

	v
},
free: { [~target, ~cb, ~mb].free }, type: \voicer) => Fact(\armsBass);


PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);
	~alwaysReset = true;
	~printStopMsg = false;

	// ~prep = {};

	~mode = \g0;
	~freq = Pseries({ rrand(21, 28) }, Prand(#[5, 6, 8, 9, 10, 11].neg, 2), 2);
	~freq = Plazy({
		var	top = rrand(21, 28);
		Pseq([top, top - (#[5, 6, 8, 9, 10, 11].select { |x| (top-x) > 12 }).choose], 1)
	});
	~dur = Plazy({
		Pseq([rrand(2, 4), rrand(8, 12)], 1) * 0.5
	});
	~length = Pkey(\dur) * 1.01;  // ensure slide
	~gate = 0.5;
	~freqlag = 1.8;
	~mrlag = Pkey(\freqlag) * 0.75;
	~mod_ratio = Pwhite(2, 7, inf);

	~preparePlay = {
		~decay = nil;
		~resetStreams.do { |key| ~makeStreamForKey.(key) };
	};
	~resetStreams = #[freq, dur, length, gate, mode/*, distFar, angle, decayCurve, pan, distance*/];

	~asPattern = {
		Pbind(
			\mode, BPStream(\mode),
			\freq, BPStream(\freq),
			\dur, BPStream(\dur),
			\length, BPStream(\length),
			\gate, BPStream(\gate),
			\freqlag, BPStream(\freqlag),
			\mrlag, BPStream(\mrlag),
			\mod_ratio, BPStream(\mod_ratio)
		)
	};
} => PR(\armsbass);


