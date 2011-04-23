// just in case... (won't load twice if already loaded)
(thisProcess.nowExecutingPath.dirname.dirname +/+ "common/common-defs.scd").loadPath;


~clock52 ?? { ~clock52 = TempoClock(52/60) };


SynthDef(\finalRotate, { |outbus,
	radiusSpeed = 0.2, radiusLo = 0.5, radiusHi = 1.0,
	angleSpeedLo = 0.1, angleSpeedHi = 0.6, angleSpeedChRate = 0.7,
	distNear = 5, distFar = 20|
	var	radius = LFDNoise1.kr(radiusSpeed).range(radiusLo, radiusHi),
		angle = Integrator.kr(
			LFDNoise1.kr(angleSpeedChRate).range(angleSpeedLo, angleSpeedHi) * ControlDur.ir
		);
	Out.kr(outbus, [
		cos(angle) * radius,
		(sin(angle) * radius).linlin(-1.0, 1.0, distNear, distFar)
	]);
}).add;

\addMovingRvbOut.eval(\bufRollPanDist, { |start, time = 1, bufnum, rate = 1, amp = 1,
		strokeRateStart = 18, strokeRateEnd = 18,
		attack = 0.002, decay = 0.01,	// attack and decay of individual stroke
		pan = 0, panEnd = 0, outbus|
	SynthDescLib.at(\bufRollPanChangeRate).def.func.value(start, time, bufnum, rate, amp, strokeRateStart, strokeRateEnd, attack, decay, pan, panEnd, outbus)
}).add;



PR(\abstractProcess).clone {
	~event = (eventKey: \polySynthKrBusLockData, soundID: 0,
		vizKeys: Library.at(\defaultVizKeys).copy.put(5, \gate)
	);
	~repeats = inf;
	~requiredKeys = #[vcKey];
	~resetSources = true;

	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;
		~ampCtl = GenericGlobalControl(\amp, nil, 0.3, \amp);
	};
	~freeCleanup = { ~ampCtl.free };
	~useGui = { |vp| ~ampCtl => VP(vp) };

	~phraseDur = Pwhite(7.0, 10.0, inf);
	~delta = Pexprand(0.07, 0.6, inf);
	~sustain = Pkey(\phraseDur) - Pseries(0, Pkey(\delta), inf);
	~gate = 0.1;
	~distNear = 50;
	~distFar = 180;
	~ampMul = Plazy({ Pn(~ampCtl.asMap, inf) });
	~mode = \e0;
	~degree = Pseries({ rrand(39, 44) }, Pwrand(#[1, 2, 3], #[0.15, 0.5, 0.35], inf), { rrand(3, 5) });

	~radiusLo = 0.75;
	~radiusSpeed = Pwhite(0.4, 1.4, inf);
	~angleSpeedLo = Prand(#[7.0, -7.0], inf);
	~angleSpeedHi = 14.0 * Pkey(\angleSpeedLo).sign;
	~angleSpeedChRate = Pwhite(0.8, 1.6, inf);
	~lpcEv = Plazy({
		Pbind(
			\instrument, \finalRotate,
			\radiusLo, BPStream(\radiusLo),
			\radiusSpeed, BPStream(\radiusSpeed),
			\angleSpeedLo, BPStream(\angleSpeedLo),
			\angleSpeedHi, BPStream(\angleSpeedHi),
			\angleSpeedChRate, BPStream(\angleSpeedChRate)
		);
	});

	~phrasePat = {
		Pbind(
			\mode, BPStream(\mode, ~resetSources/*, envir: currentEnvironment*/),
			\degree, BPStream(\degree, ~resetSources/*, envir: currentEnvironment*/),
			\freq, Pfunc({ |ev| ev[\mode].asMode.cps(ev[\degree]) }),
			\delta, BPStream(\delta, ~resetSources/*, envir: currentEnvironment*/),
			\sustain, BPStream(\sustain, ~resetSources/*, envir: currentEnvironment*/),
			\gate, BPStream(\gate, ~resetSources/*, envir: currentEnvironment*/),
			\distNear, BPStream(\distNear, ~resetSources/*, envir: currentEnvironment*/),
			\distFar, BPStream(\distFar, ~resetSources/*, envir: currentEnvironment*/),
			\ampMul, BPStream(\ampMul, ~resetSources/*, envir: currentEnvironment*/),
			\lpcEv, BPStream(\lpcEv, ~resetSources/*, envir: currentEnvironment*/),
			\pan, { ~lock.bus.asMap },
			\distance, { ("c" ++ (~lock.bus.index + 1)).asSymbol }
		);
	};
	~asPattern = {
		var	phraseDurPat = Pbind(
			\phraseDur, BPStream(\phraseDur),
			\phraseStartTime, Pfunc({ thisThread.clock.beats })
		);
		PR(\psetp2).copy.prep(
			if(~repeats == inf) {
				PnNilSafe(phraseDurPat, ~repeats)
			} {
				Pfin(~repeats, phraseDurPat)
			},
			Pseq([
				~phrasePat.(),
				Pbind(
					\instrument, \rest,
					\delta, Pfuncn({ |ev| ev[\phraseDur] + ev[\phraseStartTime] - thisThread.clock.beats })
				)
			], 1),
			currentEnvironment  // environment in which 2 patterns will run
		).outerOverridesInner_(false).asPattern
	};

	~bindVoicer = { |vc|
		~vcKey = VC.keys.detect { |key| VC(key).value === vc };
		~event.putAll((
			chan: VC(~vcKey).env.target,
			instrument: VC(~vcKey).v.nodes[0].defname,
			bufbase: VC(~vcKey).env.wt.first.bufnum
		));
	};
} => PR(\finalSus);


// reuse of arms axial
// synthdef like airskid, but inharmonic

\addRvbOut.eval(\bellskid, { |noisebuf, nfreq = 440, beats = 4.64,
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
			Klank.ar(`[
				(1..6) * ({ Rand(0.8, 1.25) } ! 6),
				1 ! 6,
				{ Rand(0.75, 1.25) } ! 6
			], sig, rfreq, 0, rdecay)
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


(
// chan: ,  // FILL IN
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		chan: ~chan,
		isFx: true,
		alwaysReset: true,
 		event: (eventKey: \monoSupport),
		fmtSearch: ~fmtSearch ? "tenor",
		userprep: {
			~fmtKeys = FormantTable.keys.select { |k| k.asString.contains(~fmtSearch) }.asArray;
			~sensCtl = GenericGlobalControl(\sensitivity, nil, 0);
		},
		userfree: {
			~sensCtl.free
		},
		delta: Pexprand(0.1, 0.9, inf), // Pexprand(1.0, 4.0, inf),
		formant: Plazy { Pxrand(~fmtKeys, inf) },
		fadeIn: 12,
		fadeOut: 8,
		recvEventNotify: { |node, event|
			~node = node;
		},
	 	stopCleanup: { ~node.release; ~node = nil; ~makeStreamForKey.(\fmtprotoEvent) },
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
					ReplaceOut.ar(outbus, Limiter.ar(sig));
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
		)
	));
}, type: \bp) => Fact(\formantfx2);


(make: { |name|
	BP(name).free;
	PR(\basicBufferPlayer).chuck(BP(name), nil, (
		event: (eventKey: \singleSynthPlayerData,
			vizKeys: Library.at(\defaultVizKeys).copy
			.put(1, { BP(~collIndex).buffers.indexOf(~buffer) })
			.put(3, { ~filtFreq.asArray[0].tryPerform(\explin, 20, 20000, -1.0, 1.0) }),
			vizPath: #[perc]
		),
		bufPaths: (topEnvironment[\sampleDir] +/+ "head/udu*").pathMatch,
		master: ~master,
		inChannels: 2,
		postMCCreation: {
			~shapebuf = Buffer.sendCollection(s,
				(Pseries.fromEndpoints(-1.0, 1.0, 512).asStream.all * 6.1887796806608).tanh
				.as(Signal).asWavetable, wait: 0.05
			);
			~event.proto = topEnvironment[\rvbEvent].proto;
			~ampCtl = GenericGlobalControl(\amp, nil, 0.5, \amp);
			~event[\chan] = ~chan;		
		},
		free: {
			[~shapebuf, ~ampCtl].free;
		},
		useGui: { |vp| ~ampCtl => VP(vp) },
		def: \bufGrainPanKlShpDist,
		buffer: Plazy({ Prand(~buffers, inf) }),
		bufnum: Pfunc({ |ev| ev[\buffer].bufnum }),
		time: Pfunc({ |ev| ev[\buffer].duration / ev[\rate] }),
		filtFreq: exprand(300, 900),
		filtAttack: 0.002,
		decayMap: Env(#[0.01, 0.18], #[1], 7).asArray,
		filtDecay: Pwhite(0, 1, inf).collect { |dec| ~decayMap.envAt(dec) },
		harm: (1, 3 .. 9) * Pexprand(0.9, 0.111, inf).clump(5),
		chorusAmps: #[0, 0, 0],
		distance: Pwhite(5.0, 18.0, inf),
		pan: Pwhite(-1.0, 1.0, inf),
		amp: Pexprand(0.4, 0.9, inf),
		rate: Pexprand(0.8, 3.3, inf),
		delta: Pseq([
			Pexprand(0.05, 0.2, { rrand(3, 11) }),
			Pwhite(0.3, 0.7, 1)
		], inf),
		asPattern: {
			Pbind(
				\instrument, BPStream(\def),
				\buffer, BPStream(\buffer),
				\bufnum, BPStream(\bufnum),
				\rate, BPStream(\rate),
				\time, BPStream(\time),
				\filtFreq, BPStream(\filtFreq),
				\filtAttack, BPStream(\filtAttack),
				\filtDecay, BPStream(\filtDecay),
				\harm, BPStream(\harm),
				\chorusAmps, BPStream(\chorusAmps),
				\shapebuf, ~shapebuf,
				\ampMap, ~ampCtl.asMap,
				\delta, BPStream(\delta),
				\distance, BPStream(\distance),
				\pan, BPStream(\pan)
			)
		}
	));
	0 => BP(name);
}, type: \bp) => Fact(\messyDrums);



// melody over P4
if(MBM.exists(0).not) { MIDIBufManager(chan: nil) => MBM.prNew(0) };

MIDIRecBuf(\bodymel, [
	#[64, 66,  69, 60,  58, 65, 63, 70, 72, 69,
		74, 67,  70, 60,  58, 65, 63, 66, 57, 59
	],
	#[1, 3,  1, 3,  1, 2, 1, 1, 1, 3,
		1, 3,  1, 3,  1, 1, 1, 2, 3, 16
	],
	#[1.1, 2.9,  1.1, 2.9,  1.1, 1.9, 1.1, 1.1, 1.1, 2.9,
		1.1, 2.9,  1.1, 2.9,  1.1, 1.1, 1.1, 1.9, 3.1, 16
	],
	0.2
].asNotes, properties: (type: \mel)) => MBM(0);


(make: { |name|
	PR(\mel1).chuck(BP(name), nil, (
		event: (eventKey: \voicerNoteData, midi: true, soundID: 0),
		prep: {
			~posBus = Bus.control(s, 2);
			~panCtl = GenericGlobalControl(\pan, ~posBus.index.asBus(\control), 0, \bipolar);
			~distanceCtl = GenericGlobalControl(\distance, (~posBus.index+1).asBus(\control), 0, #[5, 20]);
			~ampCtl = GenericGlobalControl(\amp, nil, 2.25, #[0.1, 10, \exp]);
			~event.proto = topEnvironment[\rvbEvent].proto.copy.put(\glrvbmc, topEnvironment[\cRvbMc]);
		},
		freeCleanup: {
			[~posBus, ~panCtl, ~distanceCtl, ~ampCtl].free;
		},
		useGui: { |vp| [~panCtl, ~distanceCtl, ~ampCtl].do { |gc| gc => VP(vp) }	},
		preparePlay: {
			var	lo;
			~rotSynth ?? {
				~rotSynth = Synth(\finalRotate, [
					\outbus, ~posBus,
					\radiusLo, 0.75,
					\radiusSpeed, rrand(0.4, 1.4),
					\angleSpeedLo, lo = #[2.0, -2.0].choose,
					\angleSpeedHi, 5.5 * lo.sign,
					\angleSpeedChRate, rrand(0.8, 1.6)
				], ~event[\voicer].target, \addToHead);
			}
		},
		stopCleanup: {
			~rotSynth !? {
				~rotSynth.free;
				~rotSynth = nil;
			}
		},
		asPattern: { 
			Pbind(
				#[note, delta], ~asNotePattern.value.collect({ |n| [n, n.dur] }),
				\distance, ~distanceCtl.asMap,
				\pan, ~panCtl.asMap,
				\ampMul, ~ampCtl.asMap
			);
		}
	));
	0 => BP(name);
	MBM(0)[\bodymel] => BP(name);
}, type: \bp) => Fact(\bodymel);



\addRvbOut.eval(\lowdrumslide, { |outbus, bufnum, attackTime = 0.1, rate = 1, start = 0,
	freq = 110, time,
	preamp = 1, amp = 1, xover = 400, pan, ampMap = 1|
	var	atk = PlayBuf.ar(1, bufnum, rate, 1, start, loop: 0)
			* EnvGen.kr(Env.linen(0.01, attackTime, 0.1)) * amp,
		freqenv = NamedControl.kr(\freqenv, (0!20).overWrite(Env.one.asArray)),
		body = SinOsc.ar(freq * EnvGen.kr(freqenv), 0.5pi, preamp).tanh * amp,
		ampenv = NamedControl.kr(\ampenv, (0!20).overWrite(Env(#[0, 1, 0.75, 0], #[0.003, 0.1, 0.887]).asArray)),
		eg = EnvGen.kr(ampenv, timeScale: time, doneAction: 2),
		hpf = HPF.ar(body, xover),
		chorus = DelayL.ar(hpf, 0.005, SinOsc.kr(Rand(0.15, 0.25), 0, Rand(0.001, 0.002), Rand(0.002, 0.003)));
	body = (body-hpf) + hpf + chorus;
	Out.ar(outbus, Pan2.ar((atk + body), pan, eg * ampMap));
}).add;



{	var	avail, playBar = ~playBar.next > 0;
	if(playBar) {
		~amps = ~ampBase.copy;
		avail = (7..15).scramble;
	} {
		~amps = (0!16);
		avail = (3..15).scramble;
	};
	~times = (0 ! 16).put(0, 0.4).put(3, 0.2);
	rrand(0, 4).do { |i|
		~amps[avail[i]] = exprand(0.3, 0.8);
		~times[avail[i]] = exprand(0.06, 0.12);
	};
	~argPairs = ~origArgPairs.copy.put(1, playBar.not.binaryValue);
	\shrinkKeys.eval;
} => Func(\lowdrumgen);

{	|shrink(true)|
	var avail;
	~amps = ~ampBase.copy.put(3, 0.98);
	avail = \getRests.eval.scramble * 2;
	~amps = [~amps, 0].lace(32);
	~times = (0 ! 32).put(0, 0.4).put(6, 0.2);
	rrand(3, 9).do { |i|
		if(0.1.coin and: { avail[i] % 4 == 0 }) {
			~amps[avail[i]] = 1;
			~times[avail[i]] = 0.4;
		} {
			~amps[avail[i]] = exprand(0.3, 0.8);
			~times[avail[i]] = exprand(0.06, 0.12);
			if(0.6.coin) {
				~amps[avail[i] + 1] = ~amps[avail[i]] * 0.65;
				~times[avail[i] + 1] = exprand(0.06, 0.12);
			};
		};
	};
	// ~argPairs = ~origArgPairs.copy.put(1, playBar.not.binaryValue);
	if(shrink) { \shrinkKeys.eval };
} => Func(\ldrFasterGen);

{	var	clearStart;
	\ldrFasterGen.eval(false);
	// clear some
	((clearStart = rrand(0, 22)) .. min(clearStart + rrand(10, 16), ~amps.size-1)).do { |i|
		~amps[i] = 0;
	};
	\shrinkKeys.eval;
} => Func(\ldrFasterGenPartBar);

{	var	starts = Pwhile1({ |in, next| next < 8 }, Pseries(#[0, 1, 2, 3].wchoose(#[0.48, 0.24, 0.16, 0.12]), Pwhite(3, 5, inf), inf)) * 4;
	~amps = 0 ! 32;
	~times = 0 ! 32;
	starts.do { |i|
		min(rrand(2, 5), (32 - i) div: 3).do { |j|
			~amps.overWrite(#[0.99, 0, 0], pos: i + (3*j));
			~times[i + (3*j)] = 0.1;
		}
	};
	if(~amps[0] > 0) {
		~amps[0] = 1;
		~times[0] = 0.4;
	};
	\shrinkKeys.eval;
} => Func(\ldrAccents);


(make: { |name|
	BP(name).free;
	PR(\bufPerc).chuck(BP(name), nil, (
		event: (eventKey: \polySynthPlayerData, grain: true,
			vizPath: #[perc], soundID: 0, pan: 0
		),
		bufPaths: [topEnvironment[\sampleDir] +/+ "head/uduSLAP1.wav"],
		bufCoords: #[[300, -1]],
		alwaysReset: true,
		master: topEnvironment[\master],
		glrvbmc: topEnvironment[\cRvbMc],
		lcrvbmc: topEnvironment[\lcrvbmc],
		inChannels: 2,
		def: \lowdrumslide,
		postMCCreation: {
			~event.proto = topEnvironment[\rvbEvent].proto;
			~event.putAll((glrvbamt: 0.2, lcrvbamt: 0.1));
			[~glrvbmc, ~lcrvbmc].do { |mc| mc.tryPerform(\receivesSignalFrom, ~chan) };
			~distanceCtl = GenericGlobalControl(\distance, nil, 5, #[5, 20]);
			~ampCtl = GenericGlobalControl(\amp, nil, -6.dbamp, \amp);
		},
		free: { [~distanceCtl, ~ampCtl].free },
		pbindPreAction: \lowdrumgen,
		amps: #[0],
		rates: 0.46,
		ampBase: #[1, 0, 0, 1] ++ (0!12),
		playBar: Pseq(#[1, 0], inf).asStream,
		reset: { ~playBar.reset },
		usedKeys: #[times],
		origArgPairs: [
			drop: 0,
			freq: Pseq([40.midicps, Pn(50.midicps, inf)], 1).drop({ |ev| ev[\drop] }),
			freqenv: Pseq([Pfuncn({ ~slideEnv }), Pn(`(Env.one), inf)], 1).drop({ |ev| ev[\drop] }),
			preamp: 4.23,
			distance: Plazy({ Pn(~distanceCtl.asMap, inf) }),
			ampMap: Plazy({ Pn(~ampCtl.asMap, inf) })
		],
		slideEnv: `(Env(#[1, 1, 3], #[0.2, 0.2], 6))
	));
	topEnvironment[\clock52] => BP(name);
}, type: \bp) => Fact(\lowdrum);


{	var	acc = ~accentOptions.choose, avail;
	~amps = ~ampBase.copy;
	~bufs = ~ampBase.copy;
	~pans = ~ampBase.copy;
	avail = (0..31);
	acc.do { |i|
		~amps[i] = 1;
		~bufs[i] = ~buffers.size.rand;
		~pans[i] = 0;
		avail.takeAt(i);
	};
	avail = avail.scramble;
	(~densityCtl.value + 7.rand).do { |i|
		~amps[avail[i]] = exprand(0.3, 0.8);
		~bufs[i] = ~buffers.size.rand;
		~pans[i] = 0.7.rand2;
	};		
	\shrinkKeys.eval;
} => Func(\hidrumgen);


{	var	acc = ~accentOptions.choose * 2, avail,
		num, ampPat, panPat, runsDone = List.new.add(64), nextRun;
	~amps = [~ampBase, 0].lace(~ampBase.size * 2);
	~bufs = ~amps.copy;
	~pans = ~amps.copy;
	~def = \bufGrainPanFiltDist ! ~amps.size;
	~times = ~amps.copy;
	avail = (0, 2 .. ~amps.size-1);
	acc.do { |i|
		~amps[i] = 1;
		~bufs[i] = ~buffers.size.rand;
		~pans[i] = 0;
		~times[i] = ~bufTimes[~bufs[i]] * ~clock.tempo;
		avail.take(i);
	};
	// avail = avail.scramble;
	block { |break|
		(~densityCtl.value + 7.rand).do { |i|
			if(avail.isEmpty) { break.() };
			i = avail.takeAt(avail.size.rand);
			nextRun = runsDone.select(_ > i).minItem;
			num = min(nextRun - i, ~runNumStream.next);
			if(~runProbCtl.coin) {
				if(~rollProbCtl.coin) {
					~def[i] = \bufRollPanDist;
					~times[i] = num * ~divCycle;
					~bufs[i] = ~buffers.size.rand;
					~amps[i] = 1;
					~pans[i] = 0.7.rand2;
					(i .. i+num-1).do { |j|
						avail.take(j);
					};
				} {
					ampPat = Pgeom.fromEndpoints(1, rrand(0.02, 0.08), num).asStream;
					panPat = Pseries.fromEndpoints(0.7.rand2, 0.7.rand2, num).asStream;
					(i .. i+num-1).do { |j|
						~amps[j] = ampPat.next * (0.75.coin.binaryValue);
						~pans[j] = panPat.next;
						~bufs[j] = ~buffers.size.rand;
						~times[j] = ~bufTimes[~bufs[i]] * ~clock.tempo;
						avail.take(j);
					};
				};
				runsDone.add(i);
			} {
				~amps[i] = exprand(0.3, 0.8);
				~bufs[i] = ~buffers.size.rand;
				~pans[i] = 0.7.rand2;
				~times[i] = ~bufTimes[~bufs[i]] * ~clock.tempo;
			};
		};
	};
	\shrinkKeys.eval;
} => Func(\hidrumrollgen);

{	var	clearStart;
	\hidrumrollgen.eval(false);
	// clear some
	((clearStart = rrand(0, 22) * 2) .. min(clearStart + rrand(20, 32), ~amps.size-1)).do { |i|
		~amps[i] = 0;
	};
	\shrinkKeys.eval;
} => Func(\hdrFasterGenPartBar);


{	var count, panStrm = Pseq(#[-1, 1], inf).asStream;
	~amps = BP(\ldr).amps;
	count = ~amps.count(_ > 0);
	~bufs = { ~buffers.size.rand } ! count;
	~pans = { 1.0.rand2 } ! count;
	~def = Pwrand(#[bufGrainPanFiltDist, bufRollPanDist], #[0.66, 0.44], count).asStream.all;
	~rates = 1 ! count;
	~times = ~def.collect { |def, i|
		if(def == \bufGrainPanFiltDist) {
			~bufTimes[~bufs[i]]
		} {
			0.32  // 3/32 between notes == 0.375 beats, little gap
		} * ~clock.tempo;
	};
	\expandKeys.eval;
	(0, 4 .. 31).do { |i|
		if(~amps[i] == 0) {
			~amps[i] = 0.5;
			~bufs[i] = ~buffers.size.rand;
			~pans[i] = panStrm.next;
			~def[i] = \bufGrainPanFiltDist;
			~times[i] = ~bufTimes[~bufs[i]];
		};
		~rates[i] = 1.25;
	};
	\shrinkKeys.eval;
} => Func(\hdrAccents);


(make: { |name|
	BP(name).free;
	PR(\bufPerc).chuck(BP(name), nil, (
		event: (eventKey: \singleSynthPlayerData, grain: true,
			vizPath: #[perc], pan: 0,
			vizKeys: Library.at(\defaultVizKeys).copy.put(1, \bufIndex)
		),
		bufPaths: (topEnvironment[\sampleDir] +/+ "head/*FING*.wav").pathMatch,
		alwaysReset: true,
		master: topEnvironment[\master],
		glrvbmc: topEnvironment[\cRvbMc],
		lcrvbmc: topEnvironment[\lcrvbmc],
		inChannels: 2,
		def: \bufGrainPanFiltDist,
		pbindPreAction: \hidrumgen,
		postMCCreation: {
			~event.proto = topEnvironment[\rvbEvent].proto;
			~event.putAll((glrvbamt: 0.2, lcrvbamt: 0.1));
			[~glrvbmc, ~lcrvbmc].do { |mc| mc.tryPerform(\receivesSignalFrom, ~chan) };
			~distanceCtl = GenericGlobalControl(\distance, nil, 5, #[5, 20]);
			~densityCtl = GenericGlobalControl(\density, nil, 1, #[1, 12, \lin, 1]);
			~ampCtl = GenericGlobalControl(\amp, nil, 1, \amp);
			~rollProbCtl = GenericGlobalControl(\rollProb, nil, 0.05);
			~runProbCtl = GenericGlobalControl(\runProb, nil, 0.05);
			~makeStreamForKey.(\runNum);

			\addMovingRvbOut.eval(\bufRollPanDist, { |start, time = 1, bufnum, rate = 1, amp = 1,
				strokeRateStart = 18, strokeRateEnd = 18,
				attack = 0.002, decay = 0.01,	// attack and decay of individual stroke
				pan = 0, panEnd = 0, outbus|
				SynthDescLib.at(\bufRollPanChangeRate).def.func.value(start, time, bufnum, rate, amp, strokeRateStart, strokeRateEnd, attack, decay, pan, panEnd, outbus)
			}).add;
		},
		useGui: { |vpi|
			[~densityCtl, ~runProbCtl, ~rollProbCtl].do { |gc| gc => VP(vpi) };
		},
		free: { [~distanceCtl, ~densityCtl, ~ampCtl, ~rollProbCtl, ~runProbCtl].free },
		amps: #[0],
		divCycle: 0.125,
		ampBase: (0!32),
		accentOptions: #[[8], [18, 24], [12]],
		usedKeys: #[bufs, pans],
		addArgs: Psym1(Pkey(\instrument), (
			rest: Pfunc({ |ev| ev }),  // no-op, but don't return nil
			bufGrainPanFiltDist: Pbind(
				\distance, Plazy({ Pn(~distanceCtl.asMap, inf) }),
				\ffreq, 18000,
				\ampMap, Plazy({ Pn(~ampCtl.asMap, inf) })
			),
			bufRollPanDist: Plazy({ Pbind(
				\distance1, BPStream(\rolld1),
				\distance2, BPStream(\rolld2),
				\moveTime, BPStream(\rollMoveTime),
				\strokeRateStart, BPStream(\rollStroke1),
				\strokeRateEnd, BPStream(\rollStroke2),
				\pan, BPStream(\rollPan1),
				\panEnd, BPStream(\rollPan2),
				\env, BPStream(\rollEnv)
			) })
		)),
		rolld1: Plazy({ Pn(~distanceCtl.asMap, inf) }),
		rolld2: Pkey(\distance1),
		rollMoveTime: Pkey(\time),
		rollStroke1: Pwhite(35.0, 60.0, inf), // Pwhite(12.5, 18.0, inf),
		rollStroke2: Pkey(\strokeRateStart) * Pwhite(0.04, 0.08, inf), // Pwhite(5.0, 10.0, inf),
		rollPan1: Pkey(\pan),
		rollPan2: Pwhite(0.84, 1.0, inf) * Pkey(\pan).sign.neg,
		rollDefaultEnv: Env(#[0, 1, 0], #[0.01, 0.99], -4),
		rollEnv: Pfunc({ ~rollDefaultEnv }),
		runNum: Pwhite(4, 10, inf),
		argPairs: [pan: Plazy({ ~makePattern.(\pans, 1) })],
		// [
		// 	// distance: Plazy({ Pn(~distanceCtl.asMap, inf) }),
		// 	// ffreq: 18000,
		// 	// ampMap: Plazy({ Pn(~ampCtl.asMap, inf) }),
		// 	pan: Plazy({ Pseq(~pans, 1) })
		// ],
		asPattern: { 
			var	out;
			~prepareForPlay.value;	// one use is streams that must persist past 1 bar
			PnNilSafe(Plazy(e {
				~doPreAction.value;
				out = ~makePbindArray.value;
				out = ~addArgPairs.(out);
				// out = ~doPostAction.(out) ? out;	// do postprocessing on pbind pairs
				~addArgs <> Pbind(*out);
			}), inf);
		}
	));
	topEnvironment[\clock52] => BP(name);
}, type: \bp) => Fact(\hidrum);



PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNoteData, soundID: 0);

	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;
		~event.putAll((glrvbamt: 0.2, lcrvbamt: 0.1));
		[~glrvbmc, ~lcrvbmc].do { |mc| mc.tryPerform(\receivesSignalFrom, ~chan) };
		~distanceCtl = GenericGlobalControl(\distance, nil, 5, #[5, 20]);
		~densityCtl = GenericGlobalControl(\density, nil, 1, #[1, 5, \lin, 1]);
		~ampCtl = GenericGlobalControl(\amp, nil, -7.5.dbamp, \amp);
		~filtWetBiasCtl = GenericGlobalControl(\fwetBias, nil, 0);
		~filtWetTrigCtl = GenericGlobalControl(\fwetTrigAmt, nil, 0);
	};
	~freeCleanup = { [~distanceCtl, ~densityCtl, ~ampCtl, ~filtWetBiasCtl, ~filtWetTrigCtl].free };

	~mode = \d;
	~mod_lev = Pkey(\gate).linlin(0.2, 0.8, 1.2, 3.0); // Pexprand(1.5, 3.0, inf);
	~mod_ratio = 3;
	~pitchBase = #[40, 33, 31].mapMode(\d);
	~timeptBase = #[0, 0.75, 1.5];
	~lengthBase = (0.25!3);
	~ampBase = #[1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0];
	~calcBar = \simpleBassLine; // \makeBassNotes;
	~usedKeys = #[freqs, durs, lengths, gates];
	~barCount = 0;

	~runPool = [
		Ptuple([Pseq(#[1, 2, 1, 1, 1, 2]), Pwrand(#[1, 2], #[0.7, 0.3], inf)]),
		Ptuple([Pseq(#[-1, -2, -1, 1, 2, 1, 2, 1]), Pwrand(#[1, 2], #[0.7, 0.3], inf)]),
		Ptuple([
			Pwrand(#[1, 2], #[0.7, 0.3], { rrand(3, 7) })
			* Pstutter(Pwhite(1, 3, inf), Pseq(#[-1, 1], inf, { 2.rand })),
			Pwrand(#[1, 2], #[0.75, 0.25], inf)
		]),
		Ptuple([
			Pstutter(2, Pxrand(#[1, 2, 3, 4], { rrand(2, 4) }))
			* Pseq(#[1, -1], inf),
			Pseq(#[1, 2], inf)
		])
	];

	~contrastingModes = Mode.keys.select { |key| key.asString.right(2) == "b0" };
	~mode = Pclutch(Pfunc({ ~contrastingModes.choose }), Pdiff(Pkey(\barCount)) > 0)
		.collect { |mode| ~lastMode = mode };

	~asPattern = {
		PnNilSafe(Plazy({
			~barCount = ~barCount + 1;
			~calcBar.eval;
			Pbind(
				\barCount, ~barCount,
				\mode, BPStream(\mode),
				\freq, Pseq(~freqs, 1),
				// durs should always end with 4
				\dur, Pdelta(Pseq(~durs ++ #[4], 1), 4),
				\length, Pseq(~lengths, 1),
				\gate, Pseq(~gates, 1),
				\mod_lev, BPStream(\mod_lev),
				\mod_ratio, BPStream(\mod_ratio),
				\attackTimeScale, 0.1,
				\decayTimeScale, 0.5,
				\distance, ~distanceCtl.asMap,
				\finalAmp, ~ampCtl.asMap
			)
		}), inf);
	};
	~stopCleanup = { ~removeFilt.() };

	~addFilt = {
		var	vc, instr;
		~filter ?? {
			vc = VC.all.detect { |vcobj| vcobj.value === ~event[\voicer] };
			if(vc.notNil) {
				instr = Instr("busfx.trigfilt");
				~filter = vc.env.target.playfx(instr, [0, 2] ++
					([0.3928571427241, 1, 0.01, 0.05718911258037, 0.56170743642834, 1.6313060134497, 60.0, 300.0, 6.1503849450928, 0.34404762983322, ~filtWetBiasCtl, ~filtWetTrigCtl, /*0.29761904478073, 0.19047619402409,*/ 0.38596610570799, 0.74081682278355].collect { |val, i|
						if(val.isNumber) {
							KrNumberEditor(*[val, instr.specs[i+2]].postcs)
						} {
							val
						}
					})
				);
			} { "Voicer not found in VC() pool - can't play effect.".warn };
		};
	};
	~removeFilt = {
		var	oldFilt, upd;
		~filter !? {
			oldFilt = ~filter;
			~filter.synth.set(\gate, 0);
			upd = Updater(~filter.synth, { |obj, what|
				if(what == \n_end) {
					upd.remove;
					oldFilt.free;  // clean up patch infrastructure
				}
			});
			~filter = nil;
		};
	};
} => PR(\bassline);


{	var	avail, last = 16;
	~amps = ~ampBase.copy;
	~freqs = ~pitchBase.copy;
	~durs = ~timeptBase.copy;
	~lengths = ~lengthBase.copy;
	~gates = 0.8 ! 3;
	\expandKeys.eval;
	
	avail = ~amps.collectIndicesOfItem(0).scramble;
	(~densityCtl.value + 3.rand).do { |i|
		i = avail[i];
		~amps[i] = 1;
		~freqs[i] = rrand(15, 26);
		~durs[i] = i * 0.25;
		~gates[i] = exprand(0.4, 0.75);
		~lengths[i] = 0.15;
	};
	~lengths.reverseDo { |len, i|
		if(len > 0) {
			i = 15-i;
			if(0.15.coin) {
				~lengths[i] = rrand(0.1, (last - i) * 0.25 - 0.15);
			};
			last = i;
		};
	};
	
	\shrinkKeys.eval;
} => Func(\makeBassNotes);

{	var	avail;
	~amps = ~ampBase;
	~freqs = ~pitchBase;
	~durs = ~timeptBase;
	~lengths = ~lengthBase;
	~gates = 0.8 ! 3;
} => Func(\simpleBassLine);

{	var arrivalPitches, arrivalTimes,
		avail = \scrambleDistrib.eval((4, 8 .. 31)),
		run, intervalSum, timeSince, last;

	#arrivalPitches, arrivalTimes = (rrand(2, 4) * ~densityCtl.value * 0.2)
	.round.asInteger.collect { |i|
		[rrand(20, 26), avail[i]]
	}.sort { |a, b| a[1] < b[1] }.flop;

	~freqs = [rrand(23, 26), rrand(-5, -2), -1].integrate;
	~durs = Pseries(0, Pwrand(#[0.25, 0.5, 0.75], #[0.1, 0.45, 0.45], 3), 3).asStream.all;
	~amps = (0 ! 32).putEach(~durs * 8, 1);
	~lengths = (0.22 ! 3);
	~gates = 0.8 ! 3;
	\expandKeys.eval;

	~freqs.putEach(arrivalTimes, arrivalPitches);
	~amps.putEach(arrivalTimes, 1);
	~durs.putEach(arrivalTimes, arrivalTimes);
	~lengths.putEach(arrivalTimes, 0.25);
	~gates.putEach(arrivalTimes, 0.8);

	arrivalTimes.do { |time, i|
		timeSince = time - (arrivalTimes[i-1] ? 0);
		run = #[[0, 0]] ++ (Pwhile1({ |in, next|
			timeSince = timeSince - next[1];
			timeSince > 0
		}, ~runPool.choose).asStream.all);
		run = run.integrate.flop;
		// now run[0].last is the offset for the ending pitch
		// and run[1] holds the timepoints
		run[0] = run[0] + arrivalPitches[i] - run[0].last;
		run[1] = run[1] + arrivalTimes[i] - run[1].last;
		~freqs.putEach(run[1], run[0]);
		~durs.putEach(run[1], run[1] * 0.125);
		~amps.putEach(run[1], 1);
		~gates.putEach(run[1].drop(-1), exprand(0.4, 0.75));
		~lengths.putEach(run[1], 0.14);
	};

	last = ~lengths.size;
	~lengths.reverseDo { |len, i|
		if(len > 0) {
			i = 31-i;
			case
				// if next is accented, make sure this note is not legato
				{ ~gates[last] == 0.8 } {
					~lengths[i] = min(~lengths[i], (last - i) * 0.125 - 0.04);
				}
				// randomly throw in some long notes
				{ 0.12.coin } {
					~lengths[i] = min(1.25, (last - i) * 0.125 - 0.02);
				};
			last = i;
		};
	};

	\shrinkKeys.eval;
} => Func(\fasterBassNotes);

{	|array, distrib(Env(#[0, 1], #[1], -4))|
	var j, temp;

	do(array.size-1) { |i|
		j = (distrib.at(1.0.rand) * (array.size - i) + i).asInteger;
		if(j > i) {
			temp = array[j];
			forBy(j-1, i, -1) { |k| array[k+1] = array[k] };
			array[i] = temp;
		};
	};
	array
} => Func(\scrambleDistrib);

{
	~amps = 0 ! 32;
	~freqs = 0 ! 32;
	~lengths = 0 ! 32;
	~gates = 0 ! 32;

	Ppatlace([Place(#[[0.6, 0.5, 0.5, 0.5], 0.1], 4), 0, 0, 0], 8).coin.do { |addNote, i|
		if(addNote) {
			~amps[i] = 1;
			~freqs[i] = rrand(19, 27);
			~lengths[i] = 0.2;
			~gates[i] = 0.8;
		}
	};

	if(~amps.count(_ > 0) == 0) {
		~amps[0] = 1;
		~freqs[0] = rrand(19, 27);
		~lengths[0] = 0.2;
		~gates[0] = 0.8;
	};

	\shrinkKeys.eval;
	~durs = ~amps.collectIndices(_ > 0) * 0.125;
	if(~amps[0] == 0) {
		~durs = ~durs.insert(0, 0);
		~freqs = ~freqs.insert(0, #[]);
		~lengths = ~lengths.insert(0, 0.1);
		~gates = ~gates.insert(0, 0.1);
	};
// [thisThread.beats, ~durs, ~freqs].debug("singleBassNotes durs");
} => Func(\singleBassNotes);


PR(\abstractProcess).clone {
	~event = (eventKey: \monoSupportData, soundID: 0,
		vizKeys: Library.at(\defaultVizKeys).copy
		.put(3, { ~freq1.asArray[0].tryPerform(\explin, 20, 20000, -1.0, 1.0) })
		.put(5, \normAmp)
	);
	~alwaysReset = true;
	~fadeOutTime = 3;

	~prep = {
		~chan = MixerChannel(~collIndex, s, 2, 2, outbus: ~master);
		~event.put(\chan, ~chan);
		~event.proto = topEnvironment[\rvbEvent].proto;
		[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\receivesSignalFrom, ~chan));

		~pitchbufs = \makeWavetables.eval(8, s, 2048, 48, { |numh| 1 ! numh });

		\addRvbOut.eval(\formantfx2Dist, { |inbus, /*outbus,*/ t_trig = 0, slideTime = 1, gate = 1,
			amp = 1, fadeIn = 5, fadeOut = 5, pan = 0, wet = 1|
			var	ffreqs = NamedControl.kr(\ffreqs, Array.series(5, 400, 400)),
				amps = NamedControl.kr(\amps, 1 ! 5),
				qs = NamedControl.kr(\qs, 0.1 ! 5),
				sig = In.ar(inbus, 1), sig2,
				wetenv = Linen.kr(gate, fadeIn, 1, fadeOut, doneAction: 2);
			ffreqs = ffreqs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
			amps = amps.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
			qs = qs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
			sig2 = BBandPass.ar(sig, ffreqs, qs, amps).sum * amp;
			sig = XFade2.ar(sig, sig2, (wet * wetenv).madd(2, -1));
			Pan2.ar(sig, pan)
			// ReplaceOut.ar(outbus, sig);
		}, nil, nil, nil, ReplaceOut).add;

		~distCtl = GenericGlobalControl(\distance, nil, 10, #[5, 20]);
		~panCtl = GenericGlobalControl(\pan, nil, 0, \bipolar);
		~wetCtl = GenericGlobalControl(\wet, nil, 1);
		~event.put(\distance, ~distCtl.asMap).put(\pan, ~panCtl.asMap);

		~notes = IdentitySet.new;
		~fmtKeys = FormantTable.keys.select { |k| k.asString.contains("tenor") }.asArray;
	};

	~freeCleanup = {
		[~chan, ~pitchbufs, ~distCtl, ~panCtl, ~wetCtl].free;
	};

	// notes
	~mode = \e;
	~degree = Pwhite(24, 33, inf);
	~freq1 = Pfunc({ |ev| Mode(ev[\mode]).cps(ev[\degree]) });
	~bufnum = Plazy({ Pkey(\freq1).cpsmidi.linlin(48, 48+(12*7),
		~pitchbufs.first.bufnum, ~pitchbufs.first.bufnum + ~pitchbufs.size - 1
	) });
	~delta = Pwhite(7.5, 15.0, inf);
	~time = Pkey(\delta) * Pwhite(1.2, 1.7, inf);
	~amp1 = 1;
	~normAmp = 1;
	~beats = Pkey(\freq1).explin(50, 1200, 1.8, 3.6);
	~envel = Env.linen(0.3, 0.4, 0.3, 1, \sqr);

	// fx
	~ffreqs = Pkey(\ffreqs) * Pexprand(0.95, 0.95.reciprocal, inf).clump(5);
	~slideTime = Pkey(\delta) * Pwhite(0.4, 0.8, inf);
	~inbus = Plazy({ Pn(~chan.inbus, inf) });
	~fxamp = 12.5.dbamp;
	~fadeIn = 0.01;
	~fadeOut = 0.01;
	~fxDelta = Pexprand(0.1, 0.9, inf); // Pexprand(1.0, 4.0, inf),
	~formant = Plazy({ Pxrand(~fmtKeys, inf) });

	~patKey = \dummy;

	~patterns = Plazy({
		Pbind(
			\protoEvent, \polySynthPlayNotifyData,
			\instrument, \oscbloop1,
			\mode, BPStream(\mode),
			\degree, BPStream(\degree),
			\freq1, BPStream(\freq1),
			\freq2, Pkey(\freq1),
			\bufnum, BPStream(\bufnum),
			\delta, BPStream(\delta),
			\time, BPStream(\time),
			\amp1, BPStream(\amp1),
			\amp2, Pkey(\amp1),
			\normAmp, BPStream(\normAmp),
			\beats, BPStream(\beats),
			\env, Pfunc({ |ev| ~envel.value(ev) })
		)
	});

	~asPattern = {
		Ppar([
			// fx
			Pbind(
				\protoEvent, Pseq([\singleSynthPlayNotifyData, Pn(\singleSynthTriggerData)]),
				\dataToViz, false,
				\isFx, true,
				\instrument, \formantfx2Dist,
				\node, Pfunc({ ~fxnode ? 0 }),
				#[ffreqs, amps, qs], Pnsym(BPStream(\formant), FormantTable),
				\ffreqs, BPStream(\ffreqs),
				\trig, 1,
				\delta, BPStream(\fxDelta),
				\sustain, inf,
				\slideTime, BPStream(\slideTime),
				\inbus, BPStream(\inbus),
				\amp, BPStream(\fxamp),
				\fadeIn, BPStream(\fadeIn),
				\fadeOut, BPStream(\fadeOut),
				\distance, ~distCtl.asMap,
				\pan, ~panCtl.asMap,
				\wet, ~wetCtl.asMap
			),
			// notes
			BPStream(\patterns, resetSource: true) <> Pbind(
				\patKey, BPStream(\patKey),
				\protoEvent, \singleSynthPlayNotifyData
			)
		], 1)
	};

	~stopCleanup = {
		if(~notes.notEmpty) {
			~notes.do { |node| node.release(~fadeOutTime) };
		} {
			~stopFx.()
		};
	};
	~stopFx = {
		~fxnode !? {
			~fxnode.free;
			~fxnode = nil;
		};
	};

	~recvEventNotify = { |node, event|
		// var	upd;
		node.do { |n|
			switch(n.defName.asSymbol)
				{ \formantfx2Dist } {
					~fxnode !? { ~fxnode.free };
					~fxnode = n;
				}
				// default case: it's a note
				{	~notes.add(n);
					n.register;
					Updater(n, e { |obj, what|
						if(what == \n_end) {
							// upd.remove;
							obj.releaseDependants;
							~notes.remove(obj);
							if(~notes.isEmpty) {
								BP(~collIndex).changed(\notesEmpty);
								if(~isPlaying.not) { ~stopFx.() };
							};
						};
					});
				}
		};
	};
} => PR(\lowTonesFmt);


PR(\lowTonesFmt).clone {
	~prep = {
		~chan = MixerChannel(~collIndex, s, 2, 2, outbus: ~master);
		~event.put(\chan, ~chan);
		~event.proto = topEnvironment[\rvbEvent].proto;
		[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\receivesSignalFrom, ~chan));

		~noisedata = Signal.fill(1024, { 1.0.rand2 });
		~noisebuf = Buffer.sendCollection(s, ~noisedata.asWavetable, 1, 0.05);

		SynthDef(\noiseSrc, { |outbus, gate = 1, normAmp = 1, time = 1, hpf = 50|
			var	sig = PinkNoise.ar(normAmp),
				env = NamedControl.kr(\env, (0 ! 24).overWrite(Env.linen(0.3, 0.4, 0.3).asArray)),
				eg = EnvGen.kr(env, gate, timeScale: time, doneAction: 2);
			sig = HPF.ar(sig, hpf);
			Out.ar(outbus, sig * eg)
		}).add;

		~distCtl = GenericGlobalControl(\distance, nil, 10, #[5, 20]);
		~panCtl = GenericGlobalControl(\pan, nil, 0, \bipolar);
		~wetCtl = GenericGlobalControl(\wet, nil, 1);
		~hpfCtl = GenericGlobalControl(\hpf, nil, 50, \freq);
		~event.put(\distance, ~distCtl.asMap).put(\pan, ~panCtl.asMap);

		~notes = IdentitySet.new;
		~fmtKeys = FormantTable.keys.select { |k| k.asString.contains("tenor") }.asArray;

		~event.put(\vizPath, [{
			if(~instrument == \noiseSrc) { \perc } { \note }
		}]);
	};
	~superFreeCleanup = ~freeCleanup;
	~freeCleanup = {
		~superFreeCleanup.();
		~hpfCtl.free;
	};
	// notes
	~delta = Pwhite(7.5, 15.0, inf);
	~time = Pkey(\delta) * Pwhite(1.2, 1.7, inf);
	~envel = Env.linen(0.3, 0.4, 0.3, 1, \sqr);

	~freq1 = Pexprand(80.0, 250.0, inf);
	~noiseSlideProb = 0.35;
	~freq2 = Pkey(\freq1) * Pif(Pfunc({ ~noiseSlideProb.coin }),
		Pexprand(0.75, 1.33, inf), 1);
	~fHoldPct = Pwhite(0.35, 0.7, inf);
	~fcurve = Pwhite(2.7, 4.5, inf) * (Pkey(\freq2) - Pkey(\freq1)).sign;
	~preamp = 9;
	~normAmp = 7.dbamp;
	~noiseenv = Env.linen(0.2, sustainTime: 0.45, releaseTime: 0.35);
	~hpf = Plazy({ Pn(~hpfCtl.asMap, inf) });

	~patKey = Penvir((last: nil ! 2, i: Pseq(#[0, 1], inf).asStream),
		Pif(
			Pfunc({ ~last.includes(\noiseSrc) }),
			\oscbloop1,
			Pwrand(#[oscbloop1, noiseSrc], #[0.8, 0.2], inf)
		).collect { |name| ~last[~i.next] = name; name }
	);

	~patterns = Plazy({
		Psym1(Pkey(\patKey), (
			noiseSrc: Pbind(
				// \protoEvent, \polySynthPlayNotifyData,
				\instrument, \noiseSrc,
				\delta, BPStream(\delta),
				\time, BPStream(\time),
				\normAmp, BPStream(\normAmp),
				\hpf, BPStream(\hpf),
				\env, Pfunc({ |ev| ~envel.value(ev) })
			),
			oscbloop1: Pbind(
				\bufnum, ~noisebuf,
				\instrument, \oscbloop1,
				\freq1, BPStream(\freq1),
				\freq2, BPStream(\freq2),
				\fcurve, BPStream(\fcurve),
				\fHoldPct, BPStream(\fHoldPct),
				\delta, BPStream(\delta),
				\time, BPStream(\time),
				\amp1, BPStream(\preamp),
				\amp2, Pkey(\amp1),
				\normAmp, BPStream(\normAmp),
				\env, Pfunc({ |ev| ~envel.value(ev) })
			)
		))
	});
} => PR(\noiseFmt);


PR(\abstractProcess).clone {
	// this proc leeches off the raw Hz from \sw
	~event = (eventKey: \voicerNote, midiNoteToFreq: { |x| x },
		// but, stupid crappy voicerNote event will try to modally map the Hz
		// if I don't lie to it like this
		midi: true
	);
	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto.copy
			.put(\glrvbout, topEnvironment[\cRvbMc].inbus.index);
		~glrvbamtCtl = GenericGlobalControl(\glrvbamt, nil, 0.15);
	};
	~freeCleanup = {
		~glrvbamtCtl.free;
	};
	~fsrc = \sw;
	~dsrc = \bss;
	~freq = Pfunc({
		var	ev = BP(~fsrc).lastEvent;
		if(ev[\protoEvent] == \dummy) {
			#[]
		} {
			ev[\freq1] ? #[]
		}
	});
	~dur = Pfunc({ BP(~fsrc).lastEvent[\delta] });
	~length = Pexprand(0.15, 0.3, inf); // Pfunc({ BP(~fsrc).lastEvent[\length] ? 1 });
	~gate = Pfunc({ BP(~fsrc).lastEvent[\gate] ? 0.5 });
	~mod_lev = 9;
	~mod_ratio = 1;
	~distance = 5;
	~amp = 0.2;
	~glrvbamt = Plazy({ Pn(~glrvbamtCtl.asMap, inf) }); // 0.1;
	~asPattern = {
		// PnNilSafe(Plazy({
			Pbind(
				\freq, BPStream(\freq),
				\dur, BPStream(\dur), // Pdelta(Pseq(BP(~dsrc).durs ++ #[4], 1), 4),
				\length, BPStream(\length), // Pseq(BP(~dsrc).lengths, 1),
				\gate, BPStream(\gate), // Pseq(BP(~dsrc).gates, 1),
				\mod_lev, BPStream(\mod_lev),
				\mod_ratio, BPStream(\mod_ratio),
				\attackTimeScale, 0.1,
				\decayTimeScale, 0.5,
				\distance, BPStream(\distance), // ~distanceCtl.asMap,
				\glrvbamt, BPStream(\glrvbamt),
				\finalAmp, BPStream(\amp) // ~ampCtl.asMap
			)				
		// }), inf)
	};
} => PR(\chordAcc);
