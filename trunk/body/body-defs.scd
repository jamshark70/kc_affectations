

PR(\abstractProcess).clone {
	~event = (eventKey: \polySynthKrBusLock);
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
			instrument: VC(~vcKey).v.nodes[0].defname
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


