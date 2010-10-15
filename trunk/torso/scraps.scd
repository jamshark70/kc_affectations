numCombs: 10,
cFundamental: 67.midicps,
cStep: 67.midicps / 4,	// i.e., 67.midicps is 4th partial, next comb will be 5th
cLevelRatio: 1.5.dbamp,

	// note, this is a mono -> stereo effect
	~combsdef = SynthDef(("combsfx" ++ name).asSymbol, { |outbus, density = 2, clevel = 0.3,
		attack = 0.1, decay = 0.4, combDecay = 2, bigDelay = 1, bigDecay = 20, gate = 1,
		i_littleDelayB0, i_bigDelayB|
		var	sig = In.ar(outbus, 1),
			extendsig = BufCombN.ar(i_bigDelayB, sig, bigDelay, bigDecay),
			shuf = Dshuf((0 .. ~numCombs - 1), 1),
			initPulse = Impulse.kr(0),
			order = { Demand.kr(initPulse, 0, shuf) } ! ~numCombs,
			freqs = Select.kr(order, Array.series(~numCombs, ~cFundamental, ~cStep).reciprocal),
			pulses = { Dust.kr(density) } ! ~numCombs,
			decays = Decay2.kr(pulses, attack, decay),
			combs = BufCombL.ar(i_littleDelayB0 + (0 .. ~numCombs - 1),
				(sig + extendsig) * decays, freqs, combDecay),
			weteg = EnvGen.kr(Env.asr(0.1, 1, 0.5), gate, doneAction: 2);
		combs = Splay.ar(combs, levelComp: false);
		ReplaceOut.ar(outbus, Limiter.ar(combs * clevel * weteg))
	}).add;
	SynthDef('1to2', { |outbus| ReplaceOut.ar(outbus, In.ar(outbus, 1) ! 2) }).add;

	~combsMC = MixerChannel(name ++ "comb", s, 2, 2, level: ~target.level * ~cLevelRatio, outbus: ~master, completionFunc: { |chan|
		chan.newPostSend(~glrvbmc, 0.8);
	});
	~target.doWhenReady {
		~target.newPreSend(~combsMC, 0);
		~target.newPostSend(~glrvbmc, 0.21);
		~target.newPostSend(~lcrvbmc, 0.98);
	};

	~levelSync = Updater(~target.controls[\level], e { |levelCtl, parms|
		if(parms[\what] == \value) { ~combsMC.level = levelCtl.value * ~cLevelRatio }
	});

	~bigdelay = Buffer.alloc(s, 44100, 1);
	~littledelays = Buffer.allocConsecutive(~numCombs, s, (s.sampleRate / ~cFundamental).roundUp);

playfx: { |self| self.use {
	~fx ?? {
		~fx = ~combsMC.playfx(~combsdef.name, [
			clevel: ~value.globalControls[\clevel],  // automagically asMap's
			density: ~value.globalControls[\density],
			i_littleDelayB0: ~littledelays.first, i_bigDelayB: ~bigdelay
		]);
		~target.preSends[0].levelAuto(\ctlPoint, [value: 1, time: 0.25, curve: 2.1]);
	};
} },
stopfx: { |self| self.use {
	~fx !? {
		~target.preSends[0].levelAuto(\ctlPoint, [value: 0, time: 0.25, curve: -2.1]);
		~fx.release;
		~fx = nil;
	}
} },





PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);

	~asPattern = {
		Pbind(
			\freq,
			\dur,
			\length,
			\gate,
			\freq2,
			
		)
	};
};
