// regularity for rhythm, maybe Pspawner for receding skids
// not random Ringz frequencies (maybe Klank?)


s.options.preferredDeviceFunc_(nil).device_("Aggregate Device");
BP.loadGui;

ChuckableBrowser.newWindow;
SynthDescLib.global.browse;
Object.browse;
s.queryAllNodes;

MIDIPort.init([1]);
MIDIPort.resetAll;

s.waitForBoot {
	(thisProcess.nowExecutingPath.dirname.dirname +/+ "feet/feet-defs.scd").loadPath;
	(thisProcess.nowExecutingPath.dirname +/+ "arms-defs1.scd").loadPath;
};

(
\makeEmptyMixer8.eval;

[m, n].free;
m = MixerChannel(\test1, s, 1, 2);
n = MixerChannel(\test2, s, 2, 2);
//MixingBoard(\test, nil, m, n);

[~glrvbmc, ~lcrvbmc].do { |rvb|
	[m, n].do { |mc| rvb.tryPerform(\receivesSignalFrom, mc) }
};

m => MCG(0); n => MCG(1);
//~master => MCG(7);
)

MixingBoard.at(0).refresh;

// in case I forgot to init midi first
8.do { |i| MixerMIDIControl(\omni, nil, MCG(i).v); };


[~glrvb, ~lcrvb].do { |patch| patch.run(false) };
[~glrvb, ~lcrvb].do { |patch| patch.run(true) };

[~glrvbmc, ~lcrvbmc, ~master].do { |mc, i| mc => MCG(i+5) };


// 1st arms melody: skidding, clicking sound --> acquires pitch

// skidding first

b = Buffer.alloc(s, 2048, 1);
b.sendCollection(Signal.fill(1024, { 1.0.rand2 }).asWavetable);

b.sendCollection((Signal.fill(1024, { 1.0.rand2 }) * Signal.hammingWindow(1024)).asWavetable);


WrapInstr("skidtest", { |noisebuf, nfreq = 440, beats = 1,
	trig = 1, chDepth = 0.003, chSpeed = 0.1, chPre = 0.01,
	fenv, rdecay = 0.01, time = 0.1,
	amp = 0.1, aenv|
	var	sig, chSig, rfreq/*, time*/;

// 	sig = PinkNoise.ar;
	sig = COsc.ar(noisebuf, nfreq, beats);
	chSig = sig;
	2.do {
		chSig = DelayL.ar(chSig, 0.1, SinOsc.kr(chSpeed, Rand(0.0, 0.8pi), chDepth, chPre));
		sig = sig + chSig;
	};
// 	time = TRand.kr(0.2, 0.8, trig);
	fenv = fenv.dereference.value(trig, time);
	rfreq = EnvGen.kr(fenv, gate: trig);
	sig = Ringz.ar(sig, rfreq, rdecay);
	sig = Limiter.ar(sig);
	aenv = aenv.dereference.value(trig, time);
	sig * amp * EnvGen.kr(aenv, gate: trig, timeScale: time, doneAction: 0)
}, [\mybuf, \freq, #[0.1, 10, \exp],
	TrigSpec.new, #[0.001, 0.5, \exp], #[0.001, 0.5, \exp], #[0.001, 0.5, \exp],
	ObjectSpec(`{ |trig, decay|
		var	proportion = TRand.kr(0.02, 0.9, trig),
			low = TRand.kr(300, 600, trig);
		Env([low, TRand.kr(1200, 2000, trig), low],
			[proportion, 1 - proportion] * decay, \exp)
	}), #[0.01, 1.0, \exp], #[0.01, 1.0, \exp], #[0.1, 10, \exp], EnvSpec(Env.perc(0.01, 0.99))
]);

WrapInstr("skidtest").listArgs;

p = m.play(WrapInstr("skidtest"), [b, nil, nil, SimpleTrigger.new, nil, nil, nil, nil, nil, nil, nil, Env(#[0, 1, 0], #[0.3, 0.7], #[3, -3])]); p.gui;
p.synth.trace

WrapPatch(
	[ 'skidtest' ], [ Buffer.new, KrNumberEditor(440.0, ControlSpec(20, 20000, 'exp', 0, 440, " Hz")), KrNumberEditor(4.6415884089236, ControlSpec(0.1, 10, 'exp', 0.0, 0.1, "")), SimpleTrigger.new, KrNumberEditor(0.003, ControlSpec(0.001, 0.5, 'exp', 0.0, 0.001, "")), KrNumberEditor(0.1, ControlSpec(0.001, 0.5, 'exp', 0.0, 0.001, "")), KrNumberEditor(0.048624623623304, ControlSpec(0.001, 0.5, 'exp', 0.0, 0.001, "")), { |trig, decay|
		var	proportion = TRand.kr(0.02, 0.9, trig),
			low = TRand.kr(300, 600, trig);
		Env([low, TRand.kr(1200, 2000, trig), low],
			[proportion, 1 - proportion] * decay, \exp)
	}, KrNumberEditor(0.01, ControlSpec(0.01, 1.0, 'exp', 0.0, 0.01, "")), KrNumberEditor(0.1, ControlSpec(0.01, 1.0, 'exp', 0.0, 0.01, "")), KrNumberEditor(1.0, ControlSpec(0.1, 10, 'exp', 0.0, 0.1, "")), Env([ 0, 1, 0 ], [ 0.3, 0.7 ], [ 3, -3 ], nil, nil) ]
)

WrapInstr("skidtest").argNames

PeakMonitor(m);

p.synthDef.add;

Pdefn(\delta, Pwhite(0.5, 0.7, inf));
Pdefn(\delta, Pseq([Pexprand(0.12, 0.45, { rrand(2, 12) }), Pwhite(0.25, 0.75, { 2.rand + 1 })], inf));
Pdefn(\time, Pkey(\delta) * Pwhite(0.7, 1.0, inf));
Pdefn(\nfreq, Pexprand(40.0, 1800.0, inf));
Pdefn(\rdecay, Pexprand(0.01, 0.08, inf));

q = Pbind(
	\type, \set,
	\id, p.synth.nodeID,
	\args, #[trig, time, nfreq],
	\trig, 1,
	\delta, Pdefn(\delta),
	\time, Pdefn(\time),
	\nfreq, Pdefn(\nfreq)
).play;

q.stop;

TempoClock.default.clear;


\addRvbOut.eval(\skidtest, { |noisebuf, nfreq = 440, beats = 4.64, t_trig,
	chDepth = 0.05, chSpeed = 1.2, chPre = 0.06, rdecay = 0.01, time = 1, amp = 1, pan,
	gate = 1|
	var	sig;
	sig = WrapInstr("skidtest").valueArray([
		noisebuf, nfreq, beats, t_trig, chDepth, chSpeed, chPre,
		{ |trig, decay|
			var	proportion = TRand.kr(0.02, 0.9, trig),
				low = TRand.kr(300, 600, trig);
			Env([low, TRand.kr(1200, 2000, trig), low],
				[proportion, 1 - proportion] * decay, \exp)
		}, rdecay, time, amp,
		{ |trig, decay|
			var	proportion = TRand.kr(0.02, 0.9, trig);
			Env([0, 1, 0], [proportion, 1 - proportion] * decay, #[3, -3])
		}	
	]);
	sig = sig * EnvGen.kr(Env(#[1, /*1,*/ 0.1], [/*1,*/ 0.1], releaseNode: 0 /*1*/), gate, doneAction: 2);
	Pan2.ar(sig, Lag.kr(pan, time));
}).add;

p = n.play(
	Pfset(nil,
		Pseq([
			(type: \on, instrument: \skidtest, nfreq: 440, delta: 0.2, time: 0.2, trig: 1, gate: 1,
				rdecay: 0.01, amp: 8.dbamp, pan: 0, distance: 12.5,
				distNear: 5, distFar: 20,
				glrvbout: ~glrvbmc.inbus,
				lcrvbout: ~lcrvbmc.inbus,
				callback: { z = ~id.debug("id"); }
			),
			Pbind(
				\type, \set,
				\id, Pfunc { z },
				\args, #[t_trig, time, nfreq, rdecay, pan, distance],
				\delta, Pdefn(\delta),
				\t_trig, 1,
				\time, Pdefn(\time),
				\nfreq, Pdefn(\nfreq),
				\rdecay, Pdefn(\rdecay),
				\pan, Pwhite(-1.0, 1.0, inf),
				\distance, sin(Ptime() * (2pi / 10)).linlin(-1, 1, 5, 20)
			)
		]),
		{ (type: \off, id: z, hasGate: true).play }
	)
);

p.stop;

PeakMonitor(~master);

o.do(_.remove);
o = ['/n_go', '/n_end'].collect { |msg|
	OSCresponderNode(s.addr, msg, { |t, r, m| [t, m].postln }).add;
};


Pmono(\skidtest,
	\noisebuf, b,
	\nfreq, Pdefn(\nfreq),
	\delta, Pdefn(\delta),
	\time, Pdefn(\time),
	\trig, 1,
	\rdecay, Pdefn(\rdecay),
	\amp, 1,
	\pan, Pwhite(-1.0, 1.0, inf),
	\distance, sin(Ptime() * (2pi / 10)).linlin(-1, 1, 5, 20),
	\distNear, 5, \distFar, 20,
	\glrvbout, ~glrvbmc.inbus,
	\lcrvbout, ~lcrvbmc.inbus
));

p.stop;

~master.synth.trace

Pdefn(\delta).source.postcs

// receding
q = Penvir((), Pmono(\skidtest,
	\noisebuf, b,
	\nfreq, Pdefn(\nfreq),
	\delta, rrand(0.16, 0.22),// Pdefn(\delta),
	\time, Pdefn(\time),
	\trig, 1,
	\rdecay, Pdefn(\rdecay),
	\amp, 8.dbamp, //1,
	\pan, Plazy {
		var p1 = rrand(0.6, 1.0) * #[-1, 1].choose;
		Pseries.fromEndpoints(p1, p1.neg, ~num = rrand(8, 18))
	},
	\distance, Plazy { Pseries.fromEndpoints(5, 20, ~num) },
	\distNear, 5, \distFar, 20,
	\glrvbout, ~glrvbmc.inbus,
	\lcrvbout, ~lcrvbmc.inbus
));

p = n.play(Pspawner({ |sp|
	loop {
		sp.par(q);
		sp.wait(rrand(1.0, 2.0))
	}
}));

p.stop;