

// basic bell

a = {
	var	exc = BrownNoise.ar(1) * Decay2.kr(Impulse.kr(0), 0.3, 0.8),
		sig = Klank.ar(`[
			{ ExpRand(60, 400) } ! 5,
			0.25 ! 5,
			30 ! 5
		], exc);
	DetectSilence.ar(sig, 0.001, doneAction: 2);
	Limiter.ar(sig) ! 2
}.play;

a.trace

a.free;