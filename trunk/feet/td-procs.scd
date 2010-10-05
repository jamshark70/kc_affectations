// process-izing feet sketches

// leaning
(
PR(\abstractProcess).clone {
	~event = (eventKey: \leaning);
	~stepKey = \st;

	~selector = Pseq([Pn(0, { rrand(2, 4) * 2 }), 1], inf);
	~clickProb = 0.75.asPattern.coin;
	~numKlank = Pwxrand(#[1, 2, 3, 4], #[5, 3, 2, 1].normalizeSum, inf);

	~gate = 0.1;
	~deg = (Pwhite(35, 45, inf) +.x Pseries(0, Prand(#[-1, -2, -3], 2))).clump(2);
	~freq = Pfunc { |ev| Mode(\g).cps(ev[\deg]) };
	~delta = Pwhite(0.2, 0.4, inf) * Pseq(#[1, 2.1], inf);
	~sustain = Pwhite(1.5, 4.5, inf);
	~bufbase = Plazy({ Prand(VC(~vcKey).env.wt.flop[0], inf) });
	~envAtk = 0.05;
	~envDcy = 0.12;
	~fenv_tscale = Pkey(\sustain);
	~fenvProp = 0.07;
	~lpcEv = Pbind(
		\instrument, \krwobble,
		\speedEnv, Pfunc({ Env(#[1.2, 5, 0.7], #[0.3, 0.7]) }),
		\widthEnv, Pfunc({ Env(#[1, 1.05, 1], #[0.7, 0.3], \exp) })
	);

	~klankprob = 1;
	~klanknewDelta = Pexprand(0.09, 0.14, inf);
	~klankfreq = Pexprand(700, 1100, inf);
	~klanktimeMul = 0.05;
	~klankkAmp = Pexprand(0.6, 1.0, inf);
	~klankharm = (1, 3 .. 9);
	~klankyEnds = #[5, 20];
	~klanknumEv = Pwhite(9, 17, inf);
	~klankstart = Plazy({ Prand(BP(~stepKey).pt, inf) * 44100 });
	~klankdelta = max(0.15, (Pkey(\newDelta) * Pkey(\numEv)) + Pwhite(-0.8, 0.8, inf));
	~restdelta = Pwhite(2.0, 5.0, inf);

	~asPattern = {
		~numKlankStream ?? { ~makeStreamForKey.(\numKlank) };
		Pswitch1([
			Pbind(
				\protoEvent, \polySynthKrBusLock,
				\chan, ~event[\voicer].bus.asMixer,
				\instrument, ~event[\voicer].nodes[0].defname.asSymbol,
				\busRate, \control,
				\numCh, 1,
				\freqmul, { ~lock.bus.asMap },  // asControlInput .value's this
				\gate, BPStream(\gate),
				\deg, BPStream(\deg),
				\freq, BPStream(\freq),
				\delta, BPStream(\delta),
				\sustain, BPStream(\sustain),
				\bufbase, BPStream(\bufbase, resetSource: true),
				\envAtk, BPStream(\envAtk),
				\envDcy, BPStream(\envDcy),
				\fenv_tscale, BPStream(\fenv_tscale),
				\fenvProp, BPStream(\fenvProp),
				\lpcEv, BPStream(\lpcEv) <> Pfunc { |inev| inev.copy[\chan] = nil }
			),
			Pif(BPStream(\clickProb),
				Pbind(
					\protoEvent, \runKlankMachine,
					\stepKey, BPStream(\stepKey),
					\gest, \klankMachine,
					\numEv, BPStream(\klanknumEv),
					\prob, BPStream(\klankprob),
					\newDelta, BPStream(\klanknewDelta),
					\freq, BPStream(\klankfreq),
					\timeMul, BPStream(\klanktimeMul),
					\kAmp, BPStream(\klankkAmp),
					\harm, BPStream(\klankharm),
					\yEnds, BPStream(\klankyEnds),
					\start, BPStream(\klankstart, resetSource: true),
					\delta, BPStream(\klankdelta)
				),
				Pbind(
					\protoEvent, \dummy,
					\delta, BPStream(\restdelta)
				)
			)
		], BPStream(\selector))
	};

	~bindVoicer = { |voicer|
		var	vc = VC.all.detect { |obj| obj.v === voicer };
		if(vc.notNil) {
			~vcKey = vc.collIndex.debug("set vcKey");
		} {
			"% is not in the VC collection. BP(%) will not work."
			.format(voicer, ~collIndex.asCompileString);
			~vcKey = nil;
		};
	};
} => PR(\leaning);
)

Fact(\waterpad) => VC(\wp);

BP(\ln).free;
PR(\leaning) => BP(\ln);
VC(\wp) => BP(\ln);
0 => BP(\ln);

BP(\st).autoRun = false;

p = BP(\ln);
p.sustain = Pwhite(1.5, 4.5, inf);

p.klankkAmp = Pexprand(0.6, 1.0, inf);
p.clickProb = 0.75.asPattern.coin;

p.selector = Pseq([Pn(0, { rrand(2, 4) * 2 }), 1], inf);

p.numKlank = Pwxrand(#[1, 2, 3, 4], #[5, 3, 2, 1].normalizeSum, inf).asStream;

p.klankdelta = (Pkey(\newDelta) * Pkey(\numEv)) + Pwhite(0.25, 1.2, inf);
p.klankdelta = Pwhite(2.0, 5.5, inf);

p.klankdelta = Pkey(\newDelta) * Pkey(\numEv) * Pwhite(0.4, 0.75, inf);
p.restdelta = Pwhite(3.0, 5.5, inf);

// faster
p.clickProb = true;
p.selector = Plazy({ Pseq([Pn(0, { rrand(1, 3) * 2 }), Pn(1, { ~numKlankStream.next })], inf) });
p.klankdelta = Pkey(\newDelta) * Pkey(\numEv) * Pwhite(0.4, 0.75, inf);


/**** TODO Falling */

// like leaning, but more klank events
// pattern for frequency - usually dropping(?)

p.clickProb = true;
p.klanknumEv = Pwhite(18, 40, inf);
p.klanknewDelta = Pfunc({ |ev|
	Pgeom.fromEndpoints(rrand(0.06, 0.08), rrand(0.22, 0.32), ev[\numEv])
	* Pexprand(0.75, 1.33, inf)
});
p.klankfreq = Pfunc({ |ev|
	var	top = exprand(900, 1400),
		curve = [top, top * rrand(0.2, 0.4), rrand(3.0, 5.5)].asSpec;
	Pseries.fromEndpoints(0, 1, ev[\numEv]).collect(curve.map(_))
});
p.klankkAmp = Pfunc({ |ev|
	Pseries.fromEndpoints(exprand(0.6, 1.0), rrand(0.04, 0.08), ev[\numEv]) // * exprand(0.6, 1.0)
});
p.klankdelta = Pwhite(5.0, 8.0, inf);

p.selector = 0;
p.override(\selector, Pn(1, 1));

SynthDef(\krfall, { |outbus, low = 0.5, sustain = 1, proportion = 0.5, halfWidth = 0.1|
	var	remaining = 1 - proportion;
	halfWidth = min(halfWidth, min(proportion, remaining));
	Out.kr(outbus, EnvGen.kr(
		Env(
			[1, 1, low, low, (low-1) * Rand(0.6, 0.8) + 1],
			[proportion - halfWidth, halfWidth * 2, remaining - halfWidth, 0.5],
			\sin
		),
		timeScale: sustain
	));
}).add;

p.lpcEv = Plazy({ Pbind(
	\instrument, \krfall,
	// \low, Pexprand(0.8, 1.25, inf) * 0.5,
	\low, BPStream(\fallLow),
	\proportion, Pwhite(0.5, 0.8, inf),
	\halfWidth, Pwhite(0.2, 0.48, inf)
) });

p.fallLow = 1;
p.override(\fallLow, Pexprand(0.6, 0.8, 6));  // maybe
p.fallLow = Pexprand(0.6, 0.8, inf);


p.delta = Pseq([
	Pwhite(0.2, 0.4, inf) * Pseq(#[1, 2.1], { rrand(1, 4) }),
	Pwhite(0.8, 2.5, { rrand(1, 3)  })
], inf);
p.sustain = ;


(
(make: { |name|
	BP(name).free;
	PR(\leaning).chuck(BP(name), nil, (
		// use .override to trigger falling klanks
		selector: 0,
		// use .override, or replace, for falling chords
		fallLow: 1,
		clickProb: true,
		klanknumEv: Pwhite(18, 40, inf),
		klanknewDelta: Pfunc({ |ev|
			Pgeom.fromEndpoints(rrand(0.06, 0.08), rrand(0.22, 0.32), ev[\numEv])
			* Pexprand(0.75, 1.33, inf)
		}),
		klankfreq: Pfunc({ |ev|
			var	top = exprand(900, 1400),
			curve = [top, top * rrand(0.2, 0.4), rrand(3.0, 5.5)].asSpec;
			Pseries.fromEndpoints(0, 1, ev[\numEv]).collect(curve.map(_))
		}),
		klankkAmp: Pfunc({ |ev|
			Pseries.fromEndpoints(exprand(0.6, 1.0), rrand(0.02, 0.04), ev[\numEv])
		}),
		klankdelta: Pwhite(5.0, 8.0, inf),
		lpcEv: Plazy({ Pbind(
			\instrument, \krfall,
			// \low, Pexprand(0.8, 1.25, inf) * 0.5,
			\low, BPStream(\fallLow),
			\proportion, Pwhite(0.5, 0.8, inf),
			\halfWidth, Pwhite(0.2, 0.48, inf)
		) }),
		delta: Pseq([
			Pwhite(0.2, 0.4, inf) * Pseq(#[1, 2.1], { rrand(1, 4) }),
			Pwhite(0.8, 2.5, { rrand(1, 3)  })
		], inf)
	));
	0 => BP(name);
}, type: \bp) => Fact(\fallingBP);
)

Fact(\fallingBP) => BP(\fall);
VC(\wp) => BP(\fall);

p = BP(\fall);

p.override(\fallLow, Pexprand(0.6, 0.8, rrand(2, 10)));  // maybe
p.fallLow = Pexprand(0.6, 0.8, inf);

p.override(\selector, Pn(1, 1));


/**** TODO Conflict */



/* slinky */
();

p = BP(\st);
p.autoRun = true;

f = {
	var	numEv = rrand(9, 17),
		numInChord = rrand(2, 3),
		startDelta = rrand(0.35, 0.6);
	BP(\st).runGesture((
		gest: \klankMachine,
		numEv: numEv,
		newDelta: Pgeom.fromEndpoints(startDelta, rrand(0.05, 0.09), numEv),
		timeMul: startDelta / Pkey(\delta),
		freq: (Pseries(
			rrand(28, 33) - 7,
			Pwrand(#[1, 2], #[0.7, 0.3], inf),
			inf
		) -.x Pclump(numInChord, Pseries(
			0, Pwrand(#[1, 2, 3], #[1, 4, 3].normalizeSum, numInChord), inf
		))).collect { |deg| Mode(\g).cps(deg) },
		harm: Pstutter(Pwhite(3, 7, inf), Pfunc({ [(1..5) * ({ exprand(0.8, 1.25) } ! 5).put(0, 1)] })),
		xEnds: { rrand(-1.0, 1.0) } ! 2,
		yEnds: [rrand(15.0, 20.0), rrand(5.0, 8.0)]
	));
};
y = f.();

p.use { y = y.asStream };
p.use { z = y.next(p.event.copy) };

z.play;
z.node
z.filtFreq

p.event

PeakMonitor(~glrvbmc)


BP(\st).runGesture((
	gest: \lauraslide,
	notesKey: \lauraslide, // ~notesKeys.next,
	ampAdjust: 0.11,
	numEv: rrand(11, 19)
));