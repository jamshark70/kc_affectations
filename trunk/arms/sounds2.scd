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
m = MixerChannel(\test1, s, 1, 2, outbus: ~master);
n = MixerChannel(\test2, s, 2, 2, outbus: ~master);
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
	amp = 0.1, aenv, numOverlaps = 3|
	var	sig, chSig, rfreq, overlapTrigs/*, time*/;

// 	sig = PinkNoise.ar;
	sig = COsc.ar(noisebuf, nfreq, beats);
	chSig = sig;
	2.do {
		chSig = DelayL.ar(chSig, 0.1, SinOsc.kr(chSpeed, Rand(0.0, 0.8pi), chDepth, chPre));
		sig = sig + chSig;
	};
// 	time = TRand.kr(0.2, 0.8, trig);
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
	chDepth = 0.05, chSpeed = 1.2, chPre = 0.06,
	loffreq = 440, hiffreq = 440, rdecay = 0.01,
	time = 1, amp = 1, pan, gate = 1|
	var	sig;
	sig = WrapInstr("skidtest").valueArray([
		noisebuf, nfreq, beats, t_trig, chDepth, chSpeed, chPre,
		{ |trig, decay|
			var	proportion = TRand.kr(0.02, 0.9, trig); //,
//				low = TRand.kr(300, 600, trig);
			Env([loffreq, hiffreq, loffreq],
				[proportion, 1 - proportion] * decay, \exp)
		}, rdecay, time, amp,
		{ |trig, decay|
			var	proportion = TRand.kr(0.02, 0.9, trig);
			Env([0, 1, 0], [proportion, 1 - proportion] * decay, #[3, -3])
		},
		/*numOverlaps:*/ 3
	]);
	sig = sig * EnvGen.kr(Env(#[1, /*1,*/ 0.1], [/*1,*/ 0.1], releaseNode: 0 /*1*/), gate, doneAction: 2);
	Pan2.ar(sig, Lag.kr(pan, time));
}, nil, (nil ! 11) ++ #[0.1]).add;

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

s.sendMsg(\n_trace, 1002);

PeakMonitor(~master);
PeakMonitor(~glrvbmc);

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

z = Proto {
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
				PR(\rewriter).copy.prep(Pseq(row, 1), Pfuncn({ rrand(1, 3) }, 1), [
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
	~prep = {
		~degreeStream = ~degree.asStream;
	};
	~next = { |inval| ~degreeStream.next(inval) };
	~reset = { ~prep.value };
};
z.prep;

q = Penvir((dspec: #[5, 20, -8].asSpec), Pmono(\skidtest,
	\noisebuf, b,
	\nfreq, Pdefn(\nfreq),
	\delta, Plazy { rrand(0.12, 0.22).debug("\ndelta").loop },// Pdefn(\delta),
	// \delta, Plazy { rrand(0.45, 0.75).loop },// Pdefn(\delta),
	\time, Pdefn(\time),
	\trig, 1,
	\hiffreq, Plazy { (z.next.degreeToKey(#[0, 2, 4, 5, 7, 9, 11]) + 67).debug("midinote").midicps.loop },
	\loffreq, Pkey(\hiffreq) * Pexprand(1.03.reciprocal, 1.03, inf),
	\rdecay, Pdefn(\rdecay),
	\amp, 8.dbamp, //1,
	\pan, Plazy {
		var p1 = rrand(0.6, 1.0) * #[-1, 1].choose;
		Pseries.fromEndpoints(p1, p1.neg, ~num = rrand(8, 18))
	},
	\distance, Plazy { ~dspec.map(Pseries.fromEndpoints(0, 1, ~num)) },
	\distNear, 5, \distFar, 20,
	\glrvbout, ~glrvbmc.inbus,
	\lcrvbout, ~lcrvbmc.inbus
));


p = n.play(Pspawner({ |sp|
	z.reset;
	loop {
		sp.par(q);
		sp.wait(rrand(0.4, 1.5))
	}
}));

p.stop;

Pdefn(\rdecay, 1);
Pdefn(\time, Pkey(\delta) * g.asPattern);

g.free;
g = GenericGlobalControl(\timemul, nil, 1, #[0.5, 4, \exp]); g.gui;

o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;

o = OSCresponderNode(s.addr, '/n_go', { |t, r, m|
	r.remove;
	{ s.sendMsg(\n_trace, m[1]) }.defer(1)
}).add;



// self-triggering

\addRvbOut.eval(\skidtest, { |noisebuf, nfreq = 440, beats = 4.64,
	chDepth = 0.05, chSpeed = 1.2, chPre = 0.06,
	loffreq = 440, hiffreq = 440, rdecay = 0.01,
	loTime = 0.12, hiTime = 0.22, timeMul = 1,
	amp = 1, pan, sustain = 1|
	var	sig,
		ddelta = Dstutter(2, Dwhite(0.0, 1.0, inf).linexp(0, 1, loTime, hiTime)),
		trig = TDuty.kr(ddelta, 0, ddelta),
		time = Latch.kr(trig, trig) * timeMul;
	sig = WrapInstr("skidtest").valueArray([
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

SynthDef(\xy, { |x1, x2, y1, y2, sustain = 1, out|
	Out.kr(out, [
		Line.kr(x1, x2, sustain, doneAction: 2),
		Line.kr(y1, y2, sustain)
	]);
}).add;

g.free;
g = GenericGlobalControl(\timemul, nil, 1, #[0.5, 4, \exp]); g.gui;

Pdefn(\nfreq, Pexprand(40.0, 1800.0, inf));
Pdefn(\rdecay, 1);
Pdefn(\delta, Pwhite(0.4, 1.5, inf));
Pdefn(\sustain, Pkey(\delta) * Pwhite(3.0, 6.0, inf));
Pdefn(\timeMul, g.asMap);

c = 2;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m|
	c = c - 1;
	if(c == 0) { r.remove };
	s.sendMsg(\n_trace, m[1])
}).add;

z.reset;
p = n.play(
	Pfunc { |ev|
		var x1 = rrand(0.6, 1.0) * #[-1, 1].choose;
		//ev.debug("\n\nsource event");
		(instrument: \xy, out: ev[\xylock].bus, sustain: ev[\sustain],
			x1: x1, x2: x1.neg, y1: 5, y2: 20,
			delta: 0
		)/*.debug("\nxy event")*/.yield;
		thisThread.clock.sched(0, {
			ev[\xylock].addNode(Synth.basicNew(\dummy, s, ev[\id][0]));
			//ev[\xylock].listVars;
			nil
		});
		ev
	}
	<>
	Pbind(
		\instrument, \skidtest,
		\noisebuf, b,
		\nfreq, Pdefn(\nfreq),
		\delta, Pdefn(\delta),
		\sustain, Pdefn(\sustain),
		\loTime, Pexprand(0.12, 0.22, inf),
		\hiTime, Pkey(\loTime),
		\timeMul, Pdefn(\timeMul),
		\hiffreq, Pfunc { (z.next.degreeToKey(#[0, 2, 4, 5, 7, 9, 11]) + 67).midicps },
		\loffreq, Pkey(\hiffreq) * Pexprand(1.03.reciprocal, 1.03, inf),
		\rdecay, Pdefn(\rdecay),
		\xylock, Pfunc { PR(\busLock).copy.prep((numCh: 2, rate: \control)) },
		#[pan, distance], Pfunc { |ev|
			(ev[\xylock].bus.index + #[0, 1]).collect { |i| ("c" ++ i).asSymbol }
		},
		\distNear, 5, \distFar, 20,
		\glrvbout, ~glrvbmc.inbus,
		\lcrvbout, ~lcrvbmc.inbus,
		\amp, 8.dbamp
	)
);

p.stop;

p.isPlaying