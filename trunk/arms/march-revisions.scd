MIDIPort.init(#[3]);

BP.loadGui;

MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

// (Document.current.path.dirname.dirname +/+ "common/common-defs.scd").loadPath;
(Document.current.path.dirname +/+ "arms-defs1.scd").loadPath;

~master.doWhenReady { PeakMonitor(~master) };


m = MixerChannel(\test1, s, 1, 2/*, level: 0.1*/, outbus: ~master);
n = MixerChannel(\test2, s, 2, 2/*, level: 0.1*/, outbus: ~master);
m => MCG(0); n => MCG(1);

[m, n].do { |mx|
	// mx.outbus = ~master;
	mx.sendsSignalTo(~glrvbmc);
	mx.sendsSignalTo(~lcrvbmc);
};

~master => MCG(7);
~glrvbmc => MCG(5);
~lcrvbmc => MCG(6);

PeakMonitor(m);
PeakMonitor(n);
PeakMonitor(~master);
PeakMonitor(~glrvbmc);
PeakMonitor(~lcrvbmc);


[~glrvb, ~lcrvb].do(_.run(false)); [~glrvbmc, ~lcrvbmc].do(_.mute(true));
[~glrvb, ~lcrvb].do(_.run(true)); [~glrvbmc, ~lcrvbmc].do(_.mute(false));


[~glrvb/*, ~lcrvb*/].do(_.run(false)); [~glrvbmc/*, ~lcrvbmc*/].do(_.mute(true));
[~glrvb/*, ~lcrvb*/].do(_.run(true)); [~glrvbmc/*, ~lcrvbmc*/].do(_.mute(false));

[/*~glrvb,*/ ~lcrvb].do(_.run(false)); [/*~glrvbmc,*/ ~lcrvbmc].do(_.mute(true));
[/*~glrvb,*/ ~lcrvb].do(_.run(true)); [/*~glrvbmc,*/ ~lcrvbmc].do(_.mute(false));



VoicerProxy.new => VP.prNew(0);
4.do { VP(0).v.addControlProxy(VoicerGCProxy(nil, VP(0).v), addAlways: true) };
VP(0).v.gui;



// sound suitable for rhythms?
// no, that's boring (so far)

Fact(\shimmerpad).chuck(VC(\sp), nil, (
	env: Env.adsr(0.5, 0.4, 0.8, 1.8, curve: -2),
	fenv: Env.adsr(0.5, 0.5, 0.1, 3, peakLevel: 1, bias: 1) //.postcs
));

VC(\sp) => VP(1);

VC(\sp).v.unmapGlobal(\ffreq);
VC(\sp).v.unmapGlobal(\fenvsens);
VC(\sp).v.mapGlobal(\vsens, nil, 0.8);

k = VoicerMIDISocket(0, VP(1).v);

VC(\sp).v.mapGlobal(\attackTimeScale, nil, 1, #[0.1, 10, \exp]);
VC(\sp).v.mapGlobal(\decayTimeScale, nil, 1, #[0.1, 10, \exp]);



// melodic sound for locomotive section

a = m.play { Pulse.ar(440 * [1, 1.005], 0.5, mul: 0.25).sum };
a.free;

// don't like the pwm - pulse may be salvageable
WrapInstr("analog.pwmlead", { |freq, gate = 1, detune = 1, env, vsens,
	pwcenter = 0.5, pwrange = 0, pwrate = 8, pwmod,
	xover = 4000, dropPct = 0, //preamp = 1,
	ffreq, rq, fenv, fenvsens|
	var	amp = (Latch.kr(gate, gate) - 1) * vsens + 1,
		pwidth = pwmod.dereference.value(pwcenter, pwrange, pwrate).clip(0.01, 0.99),
		sig = Pulse.ar(freq * [1, detune], pwidth, amp).sum,
		sigLow = LPF.ar(sig, xover),
		sigHigh = HPF.ar(sig, xover),
		// postAmp = (preamp+1) / preamp,
		fcurve = ffreq * ((EnvGen.kr(fenv, gate) - 1) * fenvsens + 1);
 	// sigHigh = (sigHigh * preamp).distort * postAmp;
	sigHigh = WaveLoss.ar(sigHigh, dropPct, outof: 100, mode: 2);
	sig = sigLow + sigHigh;
	sig = RLPF.ar(sig, fcurve, rq);
	sig * EnvGen.kr(env, gate, doneAction: 2)
}, [\freq, NoLagControlSpec.new, \mydetune, EnvSpec(Env.adsr), #[0, 1],
	#[0, 1], #[0, 1], #[0.1, 50, \exp], ObjectSpec({ |pwcenter, pwrange, pwrate|
		// { LFDNoise1.kr(pwrate, pwrange, pwcenter) } ! 2
		SinOsc.kr(pwrate, [0, Rand(*([0.2, 0.8] * pi))], pwrange, pwcenter)
	}),
	\freq, #[0, 100, \lin, 1], //#[0.1, 30, \exp],
	\freq, \myrq, EnvSpec(Env.one), #[0, 1]
]);


WrapInstr("analog.pwmlead", { |freq, gate = 1, detune = 1, env, vsens,
	pwcenter = 0.5, pwrange = 0, pwrate = 8, pwmod,
	xover = 4000, pitchratio = 1, zc = 1, // dropPct = 0, //preamp = 1,
	ffreq, rq, fenv, fenvsens|
	var	amp = (Latch.kr(gate, gate) - 1) * vsens + 1,
		pwidth = pwmod.dereference.value(pwcenter, pwrange, pwrate).clip(0.01, 0.99),
		sig = Pulse.ar(freq * [1, detune], pwidth, amp).sum,
		sigLow = LPF.ar(sig, xover),
		sigHigh = sig - sigLow, // HPF.ar(sig, xover),
		// postAmp = (preamp+1) / preamp,
		fcurve = ffreq * ((EnvGen.kr(fenv, gate) - 1) * fenvsens + 1);
 	// sigHigh = (sigHigh * preamp).distort * postAmp;
	sigHigh = Squiz.ar(sigHigh, pitchratio, zc);
	sig = sigLow + sigHigh;
	sig = RLPF.ar(sig, fcurve, rq);
	sig * EnvGen.kr(env, gate, doneAction: 2)
}, [\freq, NoLagControlSpec.new, \mydetune, EnvSpec(Env.adsr), #[0, 1],
	#[0, 1], #[0, 1], #[0.1, 50, \exp], ObjectSpec({ |pwcenter, pwrange, pwrate|
		// { LFDNoise1.kr(pwrate, pwrange, pwcenter) } ! 2
		SinOsc.kr(pwrate, [0, Rand(*([0.2, 0.8] * pi))], pwrange, pwcenter)
	}),
	\freq, #[0.1, 10, \exp], #[1, 15, \lin, 1],
	\freq, \myrq, EnvSpec(Env.one), #[0, 1]
]);

MIDIPort.autoFreeSockets = true;

WrapInstr("analog.pwmlead").listArgs;

v = WrapInstr("analog.pwmlead").miditest(0, [detune: `1.004, vsens: `0, /*pwcenter: `0.5, pwrange: `0.4, pwrate: `1.1,*/ ffreq: 15000, fenvsens: `0], target: m);

v = WrapInstr("analog.pwmlead").miditest(0, [detune: `1.004, vsens: `0, fenvsens: `0, \pwcenter, 0.039370078740157, \pwrange, 0.015748031496063, \pwrate, 0.45583083694134, \xover, 6738.9006044243, \pitchratio, 1.8190411331788, \zc, 2, \ffreq, 5134.271312622, \rq, 1], target: m);

// got some grit to it
\pwcenter, 0.50393700787402,
\pwrange, 0.05511811023622,
\pwrate, 0.58218681211427,
\xover, 3146.8815005712,
\pitchratio, 4.3430544633167,
\zc, 1,
\ffreq, 4361.2669750127,
\rq, 1,



// try variable-spectrum fm

WrapInstr("osc2.fm1").openFile;

// nice potential with (10.rand)+0.5 mod_ratios, esp 2.5
// tweak envelope, this is getting there
WrapInstr("osc2.fm10mod", { |freq, gate, car_env, mod_env, mod_lev, mod_ratio, detune, plusdetune,
	basefreq, keyscale,
	car_buf, car_vs, mod_vs,
	envTimeScale = 1|
	var sig, mod, car_amp, mod_amp, mod_freqs, mod_masks;
	var	cbChanged = (HPZ1.kr(car_buf).abs > 0) + Impulse.kr(0),
		lastCb = Latch.kr(Delay1.kr(car_buf), cbChanged),
		evenOdd = PulseCount.kr(cbChanged) % 2,
		xfade = Lag.kr(evenOdd, 0.2).madd(2, -1),
		// the new bufnum in this array is always pointed to by evenOdd
		bufnums = Select.kr([1-evenOdd, evenOdd], [lastCb, car_buf]);
	car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
	mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate);
	mod_env = mod_env.dereference.value(mod_amp, mod_vs, gate);
	mod_amp = mod_amp
		* EnvGen.kr(mod_env, gate,
			timeScale: envTimeScale);
	mod_lev = mod_lev * basefreq / ((keyscale * freq) + (basefreq * (1 - keyscale)));
	// b/c of *.t, mod is a 2D array: [[normal pitch harmonic, detuned harmonic], ...]
	mod_freqs = (freq * mod_ratio + plusdetune) * (1..10) *.t [1, detune];
	mod_masks = mod_freqs.flop[0] < 20000;
	mod = SinOsc.ar(mod_freqs, 0,
		mod_masks * mod_amp * mod_lev * LFDNoise1.kr({ ExpRand(0.5, 5) } ! 10).range(0, 1)).sum;
	sig = bufnums.collect { |bufnum|
		Osc.ar(bufnum, (freq * [1, detune]) * (mod + 1), 0, car_amp).sum
	};
	XFade2.ar(sig[0], sig[1], xfade)
		* EnvGen.kr(car_env, gate, timeScale: envTimeScale, doneAction:2)
}, [\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), #[0.01, 300, \exponential], #[0.25, 20, \linear, 0.5, 1], \mydetune, #[-5, 5, \linear, 0, 0], \freq, #[0.001, 1.0, \exp], NoLagControlSpec(0, 128, \lin, 1), nil, nil, #[0.1, 10, \exp, 0, 1]]);

WrapInstr("osc2.fm10mod").listArgs;

~cb.free;
~cb = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg(#[1]) });
~cb.plotWavetable;

~cb = Buffer.allocConsecutive(4, s, 1024, 1, { |buf, i| buf.sine1Msg(((0..i) + 1).reciprocal) });
~cb[3].plotWavetable;

MIDIPort.at(0).init(/*MIDIPort.at(0).channel*/);
v = WrapInstr("osc2.fm10mod").miditestMono(0, [car_buf: ~cb.first.bufnum,
	car_env: Env.adsr(0.05, 0.15, 0.6, 0.12),
	mod_env: `{ |mod_amp, mod_vs, gate|
		Env([0, mod_amp, 0.1, 0], [0.05, 0.1, 0.3], -4, releaseNode: 2)
		// Env.adsr(0.05, 0.1, 0.1, 0.3)
	},
	mod_lev: 2.9356523833632, detune: 1.0060766515078, plusdetune: -1.4566929133858,
	keyscale: `0.31910749729236, basefreq: `(48.midicps)
], target: m);

v.trace;
v.panic;

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;

v.globalControls[\car_buf].watch.automate { TIRand.kr(0, 3, Impulse.kr(2)) };
v.globalControls[\car_buf].autoSynth.trace

v.globalControls[\car_buf].stopAuto;

k = MIDIPort.search(v);

v.unmapGlobal(\mod_ratio);
v.unmapGlobal(\car_buf);

v.unmapGlobal(\mod_lev);

k.noteOnArgsPat = Pbind(\car_buf, Pwhite(0, 3, inf) + ~cb.first.bufnum, \mod_ratio, Pwhite(2, 7, inf) * 0.5/*, \mod_lev, 2.935 / max(0.1, v.globalControls[\mod_vs].asPattern)*/);

k.active

// clumsy api but clever, that...
MIDIPort.at(0).init(MIDIPort.at(0).channel);
MIDIPort.at(0).inspect




// jack2 tuning, never mind...
(
~srvupd = Proto {
	~prep = { |server|
		~server = server ?? { ~server };
		~server.addDependant(currentEnvironment);
		~ready = true;
	};
	~free = { ~server.removeDependant(currentEnvironment) };

	~update = { |obj, what|
		var	pipe;
		if(what == \counts) {
			if(obj.avgCPU >= 20) {
				if(~ready) {
					~ready = false;
					fork {
						// test only: var pipe, obj = s;
						pipe = Pipe("top -b -n 1", "r");
						if(pipe.isOpen) {
							"\n\nCPU SPIKE: % pct\n\n".postf(obj.avgCPU);
							protect {
								block { |break|
									17.do {
										(pipe.getLine ?? { break.() }).postln;
									};
								};
							} { pipe.close };
						};
					};
				};
			} {
				~ready = true;
			};
		};
	};
};
)

~srvupd.prep(s);
~srvupd.free;



(
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
)

();
VC(\lm).free;
Fact(\locomoLead) => VC(\lm);
VC(\lm) => VP(0);

// fucking goddamn hell
MIDIPort.at(0).init;

k.free;
k = VoicerMIDISocket(0, VP(0).v);

VC(\lm).v.unmapGlobal(\pan);

(WrapInstr("osc2.fm10mod").argNames.size-3 .. WrapInstr("osc2.fm10mod").argNames.size-1).do { |i|
VC(\lm).v.mapGlobal(WrapInstr("osc2.fm10mod").argNames[i], nil, WrapInstr("osc2.fm10mod").specs[i].default, WrapInstr("osc2.fm10mod").specs[i]);
};
#[distance, blipDensity, blipProb, blipDur].do { |key| k.addControl(nil, key) };

// because, for whatever reason, k.addControl doesn't update the gui right
// k.addControl(nil, \envTimeScale, 1, #[0.1, 10, \exp]);
VC(\lm).v.mapGlobal(\envTimeScale, nil, 1, #[0.1, 10, \exp]);

// but, for some reason, this is fine???!!!
#[distance, pan, envTimeScale].do { |key| k.addControl(nil, key) };


VC(\lm).v.setArgDefaults([glrvbamt: 0.3, lcrvbamt: 0.16]);
VC(\lm).v.nodes[0].initArgs;

VC(\lm).v.setArgDefaults([mod_lev: 20]);

();
k.noteOnArgsPat = Pbind(
	\car_buf, Prand(VC(\lm).env.cb, inf),
	\mod_ratio, Pwhite(2, 7, inf) * 0.5,
	\mod_lev, Pkey(\velocity).linexp(0, 127, 7, 25)
);

VC(\lm).v.trace;

VC(\lm).globalControls[\blipDensity].bus.get(_.postln);

z = VC(\lm).trigger(440, 0.1);

VC(\lm).globalControls[\blipDensity]


p = Pseq([
	Pbind(
		\voicer, VC(\lm).v,
		\mode, \g,
		\freq, Pseq([
			Pwhile1({ |inevent, next| next < 45 },  // 45 == 84.mapMode(\g)
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
			),
			45  // always end with C
		], 1),
		\dur, Pswitch([Pn(0.25, 2), 0.5, 0.75, 1],
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
		),
		\length, Pkey(\dur) * Pwrand(#[0.7, 0.98, 1.01], #[0.1, 0.1, 0.8], inf),
		\gate, Pexprand(0.1, 0.65, inf),
		\car_buf, Prand(VC(\lm).env.cb, inf),
		\mod_ratio, Pwhite(2, 7, inf) * 0.5,
		\mod_lev, Pkey(\gate).linexp(0, 1, 7, 25)
	), (note: #[[], 1, 1, 0.1].asSequenceNote)
], inf).play(protoEvent: ProtoEvent(\voicerNote).copy);

p.stop;

VC(\lm).v.globalControls.do { |gc| [gc.name, gc.bus].postln }; ""

// hack, only works if distance and pan have consecutive bus #'s
VC(\lm).v.globalControls[\distance].automate {
	var	angle = Phasor.kr(0, LFDNoise1.kr(0.5).range(0.8, 1.4), 0, 2pi * ControlRate.ir)
	* (ControlDur.ir.neg);
	[angle.sin.linlin(-1, 1, 5, 20), angle.cos]
};

VC(\lm).v.globalControls.do(_.watch);

VC(\lm).v.globalControls[\distance].stopAuto;
VC(\lm).v.globalControls.do(_.stopWatching);


(
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);
	~mode = \g;
	~alwaysReset = true;
	// ~printStopMsg = false;

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
	~car_buf = Prand(VC(\lm).env.cb, inf);
	~mod_ratio = Pwhite(2, 7, inf) * 0.5;
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
)

BP(\lm).free;
PR(\locoMel) => BP(\lm);
VC(\lm) => BP(\lm);
1 => BP(\lm);


// bell-ish melody sounds?
VC(\bmel).free;
Fact(\armsmelVC).chuck(VC(\bmel), nil, (
	env: { var length = NamedControl.kr(\length, 0); Env.perc(0.01, length) },
	// env: Env.adsr(0.01, 2.5, 0.05, 1.2),
	isMono: false
));
VC(\bmel).v.setArgDefaults([ffreq: 12258]);

VC(\bmel).env.target.inspect

k = VoicerMIDISocket(0, VC(\bmel).v);

VP(0).v.voicer = nil;
VC(\bmel) => VP(0);

k.addControl(\mw, \ffreq, 2423, \freq);
k.removeControl(\ffreq);
VC(\bmel).unmapGlobal(\ffreq);

TempoClock.tempo = 84/60;

// just need the pattern now... stepwise up, angular down?
// maybe close - need a tail pattern after +.x +.x
(
p = Pbind(
	\voicer, VC(\bmel).v,
	\mode, \g,
	\freq, ((Pseries(46, Pwhite(-4, -2, 7)).trace(prefix: "top: ") +.x Pseries(0, 1, { rrand(2, 5) }).trace(prefix: "scale: "))
		+.x Pwrand([0, Pseq([0, Pwhite(-6, -3, 1), -1], 1)], [0.9, 0.1], 1).trace(prefix: "add: ")).trace(prefix: "\tfinal: "),
	\dur, Pseq([0.5, Pn(0.25, { #[0, 1, 2, 3].wchoose(#[0.1, 0.4, 0.3, 0.2]) })], inf),
	\length, Pkey(\dur) * 2.5,
	\gate, Pif(Pkey(\dur) > 0.25, 0.8, Pexprand(0.1, 0.35, inf))
)/*.trace(\freq)*/.play(protoEvent: ProtoEvent(\voicerNote).copy);
)

(
p = Penvir((),
	Pbind(
		\voicer, VC(\bmel).v,
		\mode, \g,
		\freq, Pseq([
			(
				Pseries(46, Pwhite(-4, -2, 7)).collect { |bot| ~bot = bot }
				+.x
				Pseries(0, 1, { ~scaleSize = rrand(2, 5) }).collect { |scale| ~scale = scale }
			)
			+.x
			Pif(
				Pfunc({ ~scale < (~scaleSize - 1) }),
				Pn(0, 1),
				Pwrand([0, Pseq([0, Pwhite(-6, -3, 1), -1], 1)], [0.6, 0.4], 1)
			),
			Plazy({
				var	num = rrand(5, 12);
				~decay = num * 2;
				(~bot + ~scaleSize) + Pseq([0, #[-6, -5/*, -3*/].choose], num, 2.rand)
			})
		], 1),
		\dur, Pseq([0.5, Pn(0.25, { #[0, 1, 2, 3].wchoose(#[0.1, 0.4, 0.3, 0.2]) })], inf),
		\length, Pkey(\dur) * 2.5,
		\gate, Pif(Pkey(\dur) > 0.25, 0.8, Pexprand(0.1, 0.35, inf)),

		\distFar, 100,
		\lcrvbamt, 0.01,
		\angle, Ptime() * (2pi/5) - 0.5pi,
		\decayCurve, Pseq([
			Pwhile1({ ~decay.isNil }, 1),
			Plazy({ Pgeom.fromEndpoints(1, 0.05, ~decay) })
		], 1),
		\pan, Pkey(\angle).sin * Pkey(\decayCurve),
		\distance, (Pkey(\angle).cos * Pkey(\decayCurve))
			.linlin(-1, 1,
				Pkey(\decayCurve).explin(0.05, 1, 100, 14),
				Pkey(\decayCurve).explin(0.05, 1, 100, 5)
			).trace
	)
).play(protoEvent: ProtoEvent(\voicerNote).copy.proto_(~rvbEvent.proto));
)

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;

p.stop;


(
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote, distFar: 100, lcrvbamt: 0.01);
	~printStopMsg = false;
	~alwaysReset = true;
	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;
		#[scaleLen, numDescents, numDecays, startDeg].do { |key| ~makeStreamForKey.(key) };
		~ampMul = GenericGlobalControl(\ampMul, nil, 6.dbamp, [0, 12.dbamp, \amp]);
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
		if(~addedWavetables.notNil and: { ~vc.exists }) {
			~addedWavetables.do { |key| ~vc.env[key].free; ~vc.env[key] = nil };
			~addedWavetables.clear;
		} {
			"BP(%): Uh-oh... wavetables were added and VC was freed before cleanup. Leak?"
			.format(~collIndex.asCompileString).warn;
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
	~dur = PR(\pwxrandn).copy.prep([
		0.5, 0.75, 1,
		Pn(0.25, { #[1, 2, 3].wchoose(#[0.45, 0.35, 0.2]) })
	], Pstutter((Pwhite(6, 12, 3) * Pseq(#[1, 2, 20], 1)), Pseq([
		// #[0.45, 0.45, 0.1],
		// #[0.3, 0.3, 0.4]
		#[5, 5, 3, 1].normalizeSum,
		#[2, 1, 0.2, 4].normalizeSum
	], inf)), inf);
	~length = Pkey(\dur) * 2.5;
	~gate = Pif(Pkey(\dur) > 0.25, Pexprand(0.6, 0.9, inf), Pexprand(0.1, 0.35, inf));
	~angle = Plazy({ (Ptime() * (2pi/rrand(2.5, 7.5))) * #[-1, 1].choose });
	~decayCurve = Pseq([
		Pwhile1({ ~decay.isNil }, 1),
		Plazy({ Pgeom.fromEndpoints(1, 0.05, ~decay) })
	], 1);
	~pan = Pkey(\angle).sin * Pkey(\decayCurve);
	~distance = (Pkey(\angle).cos * Pkey(\decayCurve))
		.linlin(-1, 1,
			Pkey(\decayCurve).explin(0.05, 1, 100, 14),
			Pkey(\decayCurve).explin(0.05, 1, 100, 5)
		);

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
)

VC(\bmel).free;
Fact(\armsmelVC).chuck(VC(\bmel), nil, (
	env: { var length = NamedControl.kr(\length, 0); Env.perc(0.01, length) },
	// env: Env.adsr(0.01, 2.5, 0.05, 1.2),
	isMono: false
));
VC(\bmel).v.setArgDefaults([ffreq: 12258]);

TempoClock.tempo = 96/60;

BP(\bmel).free;
PR(\bellMel) => BP(\bmel);
VC(\bmel) => BP(\bmel);
0 => BP(\bmel);

BP(\bmel).printStopMsg = true;
BP(\bmel).printStopMsg = false;

BP(\bmel).event.ampMul = 6.dbamp;

// scaleLen, numDescents, numDecays

BP(\bmel).numDescents = Pwhite(4, 8, inf);
BP(\bmel).numDecays = Pwhite(4, 10, inf);
BP(\bmel).scaleLen = Pwhite(2, 4, inf);

BP(\bmel).numDescents = 5;  // 1 to start; reduce scaleLen when increasing this
BP(\bmel).numDecays = 2;  // 0 is ok, 2+ is ok
BP(\bmel).scaleLen = Pwhite(3, 5, inf);

// original
BP(\bmel).dur = Pseq([0.5, Pn(0.25, { #[0, 1, 2, 3].wchoose(#[0.1, 0.4, 0.3, 0.2]) })], inf);
BP(\bmel).gate = Pif(Pkey(\dur) > 0.25, 0.8, Pexprand(0.1, 0.35, inf));
BP(\bmel).length = Pkey(\dur) * 2.5;

// not quite what I want: not (n) embeds, but (n) durations per weight
BP(\bmel).dur = Pwxrand([
	0.5, 0.75,
	Pn(0.25, { #[1, 2, 3].wchoose(#[0.45, 0.35, 0.2]) })
], Pstutter(Pwhite(8, 16, 3).trace(prefix: "n: "), Pseq([
	#[0.425, 0.425, 0.15],
	#[0.3, 0.3, 0.4]
], inf).trace(prefix: "seq: ")), inf);


BP(\bmel).dur = Pwxrand([0.5, 0.75, Pn(0.25, { #[0, 1, 2, 3].wchoose(#[0.1, 0.4, 0.3, 0.2]) })], #[0.4, 0.2, 0.4], inf);
BP(\bmel).gate = Pif(Pkey(\dur) > 0.25, Pexprand(0.6, 0.9, inf), Pexprand(0.1, 0.35, inf));

BP(\bmel).dur = Pwxrand([0.5, 0.75, Pn(0.25, { #[1, 2, 3].wchoose(#[0.45, 0.35, 0.2]) })], #[0.425, 0.425, 0.15], inf);

BP(\bmel).angle = Plazy({ (Ptime() * (2pi/rrand(2.5, 7.5))) * #[-1, 1].choose });

BP(\bmel).origPat = BP(\bmel).v[\asPattern];
BP(\bmel).v[\asPattern] = { ~origPat.().trace(#[angle, pan, distance]) };
BP(\bmel).asPattern = BP(\bmel).v[\origPat];

BP(\bmel).mode = \g0;
\convertMode.eval(0, \g, \g0);  // == 4
BP(\bmel).startDeg = BP(\bmel).startDeg + 4;

// BP(\bmel).resetStreams = BP(\bmel).resetStreams ++ [\mode];

// actually I really hate this
BP(\bmel).mode = Pseq([
	Pn(\g0, { rrand(8, 14).debug("g") }),
	Pstutter(Pwhite(5, 9, 1).trace(prefix: "other: "), Prand(Mode.keys.asArray.select { |key|
		(key != \g0) and: { key.asString.last == $0 }
	}, 1))
], inf);

BP(\bmel).mode = Pstutter(1e6, Prand(Mode.keys.asArray.select { |key| key.asString.last == $0 }, 1));

VC(\bmel).env.wt2 = \makeWavetables.eval(8, s, 2048, 48, { |numharm| Array.sawtoothAmps(numharm) });
VC(\bmel).env.wt3 = \makeWavetables.eval(8, s, 2048, 48, { |numharm| Array.squareAmps(numharm) });

VC(\bmel).v.unmapGlobal(\ffreq);
VC(\bmel).v.mapGlobal(\ffreq, nil, 12000, \freq);

c.free;
c = VoicerMIDIController(\omni, \mw, VC(\bmel).v.globalControls[\ffreq]);

VC(\bmel).v.globalControls[\ffreq].inspect

BP(\bmel).wtKey = \wt2;
BP(\bmel).wtKey = Prand(#[wt, wt2, wt3], inf);

BP(\bmel).ffreq = Pnsym1(Pkey(\wtKey), (
	wt: 12258,
	wt2: Pexprand(1000, 5000, inf),
	wt3: Pexprand(1000, 5000, inf)
));

BP(\bmel).rq = Pif(Pbinop('==', Pkey(\wtKey), \wt), 1, Pexprand(0.25, 0.9, inf));


// try on-the-fly reset
BP(\bmel).play(0);

BP(\bmel).preparePlay;


// if I'm going to do this, I need lags on most of the args
// boring sound, forget it
VC(\cmel).free;
Fact(\armsmelVC).chuck(VC(\cmel), nil, (
	// env: { var length = NamedControl.kr(\length, 0); Env.perc(0.01, length) },
	harmonicAmps: { |numharm| Array.sawtoothAmps(numharm) },
	env: Env.adsr(0.1, 0.3, 0.6, 0.3),
	isMono: true
));
VC(\cmel).v.setArgDefaults([ffreq: 3000]);

VC(\cmel) => BP(\bmel);
BP(\bmel).length = Pkey(\dur) * Pwrand(#[0.8, 1.01], #[0.1, 0.9], inf);

BP(\bmel).ffreq = Pexprand(1000, 5000, inf);
BP(\bmel).rq = Pexprand(0.25, 0.9, inf);

s.bufferAllocator.debug;



// Pxrand is not quite what I want: not (n) embeds, but (n) durations per weight
Proto {
	~prep = { |list, weights, repeats = 1|
		~list = list;
		~weights = weights;
		~repeats = repeats;
		currentEnvironment
	};
	~embedInStream = { |inval|
		var item, itemStream,
			weightStream = ~weights.asStream,
			currentWeights,
			index = weightStream.next(inval).windex,
			totalweight, rnd, runningsum;

		block { |break|
			~repeats.value(inval).do({ |i|
				item = ~list.at(index.debug("index"));
				if(item.isNil) { break.(inval) };
				// Pn is redundant for patterns
				// but necessary for numbers or other non-streams
				itemStream = Pn(item, 1).asStream;
				// don't need 'item' var anymore, can reuse for outputs
				while { (item = itemStream.next(inval)).notNil } {
					inval = item.yield;
					currentWeights = weightStream.next(inval);
					if(currentWeights.isNil) { break.(inval) };
				};

				totalweight = 1.0 - currentWeights[index];
				rnd = totalweight.rand;
				runningsum = 0;
				while {
					index = (index + 1) % currentWeights.size;
					runningsum = runningsum + currentWeights[index];
					runningsum < rnd
				};
			});
			inval
		};
	};
	~asStream = { Routine { |inval| ~embedInStream.(inval) } };
	~canEmbed = true;
	~isPattern = true;
} => PR(\pwxrandn);


x = PR(\pwxrandn).copy;
x.env[\isPattern]

x.isPattern

PR(\pwxrandn).inspect

Proto.findRespondingMethodFor(\isPattern)

// BP(\bmel).durStream.instVarAt(1).def.dumpByteCodes

BP(\bmel).dur = PR(\pwxrandn).copy.prep([
	0.5, 0.75, 1,
	Pn(0.25, { #[1, 2, 3].wchoose(#[0.45, 0.35, 0.2]) })
], Pstutter((Pwhite(6, 12, 3) * Pseq(#[1, 2, 20], 1)), Pseq([
	// #[0.45, 0.45, 0.1],
	// #[0.3, 0.3, 0.4]
	#[5, 5, 3, 1].normalizeSum,
	#[2, 1, 0.2, 4].normalizeSum
], inf)), inf);

q = p.asStream;
r = q.all;

r.plot


// test move to defs
BP(\bmel).free;
VC(\bmel).free;

VC(\bmel).free;
Fact(\armsmelVC).chuck(VC(\bmel), nil, (
	env: { var length = NamedControl.kr(\length, 0); Env.perc(0.01, length) },
	// env: Env.adsr(0.01, 2.5, 0.05, 1.2),
	isMono: false
));
VC(\bmel).v.setArgDefaults([ffreq: 12258]);

Error.debug = true;
Error.debug = false;

Fact(\bmelBP) => BP(\bmel);


// bass - try sliding both freq and ratio
~cb = Buffer.alloc(s, 2048, 1, { |buf| buf.sine1Msg(#[1]) });
~mb = Buffer.alloc(s, 2048, 1, { |buf| buf.sine1Msg(#[1]) });

~cb.sine1(#[1, 0.5]);
~cb.sine1((1..4).reciprocal);
~mb.sine1(#[1]);

// no no no!
// ~cb.sine1(#[1]);
// ~mb.sine1((1..4).reciprocal);



WrapInstr("osc2.slidefm1", { |freq, gate, freqlag, mod_ratio, mrlag|
	WrapInstr("osc2.fm2car").wrap([Lag.kr(freq, freqlag), gate, nil, nil, nil,
		Lag.kr(mod_ratio, mrlag)])
}, [\freq, NoLagControlSpec(0, 1, \lin, 0, 1), #[0, 2], #[0.5, 10.5, \lin, 0.5, 1], #[0, 2]]);

WrapInstr("osc2.slidefm1").listArgs;

MIDIPort.at(0).init;
v = WrapInstr("osc2.slidefm1").miditestMono(0, [car_buf: ~cb, mod_buf: ~mb ?? { ~cb }, basefreq: `440, keyscale: `0, freqlag: 0.8503937007874, mrlag: 0.283, mod_lev: 3.4531104925503 / 0.4, detune: 0.35433070866142, car_detune: 1.0044526098252, car_env: Env.adsr(0.01, 0.25, 0.6, 0.2), mod_env: Env.adsr(0.01, 0.04, 0.4, 0.35)], target: m);

k = MIDIPort.search(v);
v.unmapGlobal(\mod_ratio);
k.removeControl(\mod_ratio);

k.noteOnArgsPat = Pbind(\mod_ratio, Pwhite(0, 4, inf) + 0.5).trace(\mod_ratio);

k.noteOnArgsPat = Pbind(\mod_ratio, Pwhite(2, 7, inf));
k.noteOnArgsPat = Pbind(\mod_ratio, Pwhite(4, 14, inf) * 0.5);

Library.at(WrapInstr, \osc2).keys
WrapInstr("osc2.fm2car").openFile;

[WrapInstr("osc2.fm2car").argNames, WrapInstr("osc2.fm2car").specs].flop.inspect

v.trace


\freqlag, 0.8503937007874,
\mrlag, 0.283,
\mod_lev, 8.6327762313757,
\detune, 0.35433070866142,
\car_detune, 1.0044526098252,
\car_vs, 0.26771653543307,
\mod_vs, 0.5748031496063,


Instr([\busfx, \chorus2band], { arg bus, numChan, predelay, speed, depth,
		ph_diff, /*width,*/ crossover, xfade;
	var in, lo, hi;
	in = In.ar(bus, 1);
	lo = LPF.ar(in, crossover);
	hi = in - lo; // HPF.ar(in, crossover);
	hi = Array.fill(numChan, { |i|
		predelay = predelay + depth;
		DelayC.ar(hi, 0.5, SinOsc.kr(speed, ph_diff * i,
		depth, predelay));
	}).scramble;
	lo = lo + hi;
	XFade2.ar(in, lo, xfade * 2 - 1)
}, [\audiobus, StaticSpec(1, 8, \lin, 1, 1), [0.0001, 0.2, \exponential, 0, 0.001], [0.001, 10, \exponential], [0.0001, 0.25, \exponential], [0, 2pi], /*[0, 1],*/ \freq, [0, 1]]);

p = m.playfx(Instr("busfx.chorus2band"), [0, 1]); p.gui;

FxPatch(
	[ 'busfx', 'chorus2band' ], [ 22, 1, 0.010549016482685, 0.13459606816896, 0.0082830816073226, 0.0, 290.0, 0.5 ]
)


p.run(false);
p.run(true);

g = GenericGlobalControl(\x, nil, 200, \freq); g.gui;

a.free;
a = m.playfx { |outbus| HPF.ar(In.ar(outbus, 1), g) };

a.run(false);
a.run(true);


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

	// ~cb.sine1(#[1, 0.5]);
	// ~cb.sine1((1..4).reciprocal);
	// ~mb.sine1(#[1]);

	~target = MixerChannel(name, s, 2, 2, outbus: ~master, completionFunc: { |chan|
		// post-fader custom send
		~xfer = Synth(\hpfxfer, [xferbus: ~glrvbmc.inbus, ffreq: 290, level: 0.337],
			chan.synth, \addAfter);
		~chorus = chan.playfx(Instr("busfx.chorus2band"), [0, 2, 0.010549016482685, 0.13459606816896, 0.0082830816073226, 0.0, 290.0, 0.5]);
		chan.sendsSignalTo(~glrvbmc);
	});

	v = MonoPortaVoicer(1, WrapInstr("osc2.slidefm2"), [car_buf: ~cb, mod_buf: ~mb ?? { ~cb }, basefreq: `440, keyscale: `0, freqlag: 0.8503937007874, mrlag: 0.283, mod_lev: 3.4531104925503 / 0.4, detune: 0.35433070866142, car_detune: 1.0044526098252, car_env: Env.adsr(0.01, 0.25, 0.6, 1.2), mod_env: Env.adsr(0.01, 0.04, 0.4, 1.5), car_vs: 0.26771653543307, mod_vs: 0.5748031496063], target: ~target);
	// gc's?

	v
},
free: { [~target, ~cb, ~mb].free }, type: \voicer) => Fact(\armsBass);

VC(\abs).free;
Fact(\armsBass) => VC(\abs);

/*
k = VoicerMIDISocket(0, VC(\abs).v);

VC(\abs).v.setArgDefaults([car_vs: 0.26771653543307, mod_vs: 0.5748031496063]);

// tuning, don't need now
g = GenericGlobalControl(\level, nil, 0.1, \amp); g.gui;
VC(\abs).env.xfer.set(\level, g.asMap);
*/

36.mapMode(\g0);  // == 21

(
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
)

BP(\abs).free;
PR(\armsbass) => BP(\abs);
VC(\abs) => BP(\abs);
1 => BP(\abs);
BP(\abs) => MT(1);

p = BP(\abs);

p.freqlag = 1.8;
p.mrlag = Pkey(\freqlag) * 0.75;

\chuckIf.eval(Fact(\shimmerpad), VC, \sp, nil, (
	env: Env.adsr(0.5, 0.4, 0.8, 1.8, curve: -2),
	fenv: Env.adsr(0.5, 0.5, 0.1, 3, peakLevel: 1, bias: 1)
).putAll(Library.at(\rvbs)));

\chuckIf.eval(PR(\siDuet), BP, \sid);
VC(\sp) => BP(\sid);
BP(\sid).finalAmp = 0.05; // 0.037;
BP(\sid).delta = Pif(Pkey(\high) > 0, Pwhite(3, 5, inf),
	Pwrand(#[1, 2, 3, 4], (1..4).reciprocal, inf)
);
1 => BP(\sid);

BP(\sid).finalAmp = 0.1;

p.freq = Plazy({
	var	top = rrand(21, 28);
	Pseq([top, top - (#[5, 6, 8, 9, 10, 11].select { |x| (top-x) > 12 }).choose], 1)
});

32.7032.cpsmidi.round.mapMode(p.mode);

p.origPattern = p[\asPattern];
p.asPattern = { ~origPattern.().trace(#[dur, length]) };

p.event.adjustLengthToRealDelta = false;

~saveAddr = s.addr;
~debugAddr = DebugNetAddr("127.0.0.1", 57110);

s.addr = ~debugAddr;
s.addr = ~saveAddr;

BP(\sid).mode = Pclutch(
	Pseq([
		\g,
		Pxrand(Mode.keys.asArray.select { |key|
			key.asString.last.inclusivelyBetween($a, $g)
		}, inf)
	], 1),
	Pif(Pkey(\prevHigh) > 0, max(0, Pwhite(-0.8, 0.2, inf)) > 0, false)
);


u.remove;
u = Updater(BP(\sid), { |obj, what, mode|
	var	newmode;
	if(what == \modeChanged) {
		BP(\abs).mode = (mode ++ "0").asSymbol;
	};
});


// prep for post-manipulation blowout
VC(\lm).free;
Fact(\locomoLead) => VC(\lm);

VC(\lm).v.nodes[0].initArgs
VC(\lm).v.nodes[0].initArgDict.as(Event)

// locoMel mainAmp == -12.5.dbamp

p = VC(\lm).env.target.play(Pmono(VC(\lm).v.nodes[0].defname,
	\freq, 59.midicps,
	\car_buf, Prand(VC(\lm).env.cb, inf),
	\mod_lev, Pexprand(7, 25, inf),
	\mod_ratio, Pwhite(2, 7, inf),
	// \dur, Pwrand(#[0.25, 0.5, 0.75], #[0.4, 0.4, 0.2], inf),
	\dur, Pseq([
		Pwhite(3, 7, 1) * 0.5,
		Pseq([
			Pn(0.25, { rrand(2, 5) }),
			Pwrand(#[0.5, 0.75, 1.0, 1.5], #[0.3, 0.3, 0.3, 0.1], { rrand(1, 3) })
		], inf)
	], 1),
	\gate, 0.8,
	\mainAmp, -12.5.dbamp
) <> VC(\lm).v.nodes[0].initArgDict.as(Event)/*, ()*/);

p.stop


(
PR(\abstractProcess).clone {
	~event = (eventKey: \default, distFar: 100);
	~alwaysReset = true;
	~printStopMsg = false;
	~vcKey = \lm;  // change to lcm later

	~prep = {
		if(~iMadeMixer = ~chan.isNil) {
			~chan = MixerChannel(~collIndex, s, 2, 2, outbus: topEnvironment[\master]/*, level: */);
			#[glrvbmc, lcrvbmc].do { |key|
				topEnvironment[key].tryPerform(\receivesSignalFrom, ~chan);
			};
		};
		~event.proto = (
			group: ~chan.synthgroup.nodeID,
			out: ~chan.inbus.index,
			outbus: ~chan.inbus.index
		).putAll(topEnvironment[\rvbEvent].proto).putAll(VC(~vcKey).v.nodes[0].initArgDict);
		~mainAmpCtl = GenericGlobalControl(\mainAmp, nil, -12.5.dbamp, \amp);
	};
	~freeCleanup = {
		if(~iMadeMixer) { ~chan.free };
		~mainAmpCtl.free
	};

	~freq = 59.midicps * Pexprand(1.007.reciprocal, 1.007, inf);
	~car_buf = Plazy({ Prand(VC(~vcKey).env.cb, inf) });
	~mod_lev = Pexprand(7, 25, inf);
	~mod_ratio = Pwhite(2, 7, inf);
	~dur = Pseq([
		Pwhite(3, 7, 1) * 0.5,
		Pseq([
			Pn(0.25, { rrand(2, 5) }),
			Pwrand(#[0.5, 0.75, 1.0, 1.5], #[0.3, 0.3, 0.3, 0.1], { rrand(1, 3) })
		], inf)
	], 1);
	~gate = 0.8;
	~mainAmp = -12.5.dbamp;

	~reset = Func(\resetBPStreams);

	~onePattern = { |fmul = 1|
		Pmono(VC(~vcKey).v.nodes[0].defname,
			\freq, ~freq * fmul,
			\car_buf, ~car_buf,
			\mod_lev, ~mod_lev,
			\mod_ratio, ~mod_ratio,
			\dur, ~dur,
			\gate, ~gate,
			\mainAmp, ~mainAmpCtl.asMap, // BPStream(\mainAmp)
			\distance, Plazy({ Env(#[75, 5], [rrand(8.0, 12.0)]) }),
			\pan, Pbrown(-1, 1, 0.25)
		)
		// Pmono(VC(~vcKey).v.nodes[0].defname,
		// 	\freq, BPStream(\freq),
		// 	\car_buf, BPStream(\car_buf),
		// 	\mod_lev, BPStream(\mod_lev),
		// 	\mod_ratio, BPStream(\mod_ratio),
		// 	\dur, Pconst(tdur, BPStream(\dur)),
		// 	\gate, BPStream(\gate),
		// 	\mainAmp, ~mainAmpCtl.asMap // BPStream(\mainAmp)
		// )
	};

	~asPattern = {
		var	tdur;
		~totalDurStream ?? { ~makeStreamForKey.(\totalDur) };
		~thisTotalDur = tdur = ~totalDurStream.next;

		Pspawner({ |sp|
			var fmul = Pstutter(Pwhite(3, 5, inf), Pseries(1, 1, inf)).asStream;
			loop {
				sp.par(~onePattern.(fmul.next));
				sp.wait(rrand(5, 10) * 0.25);
			}
		});

		// Pseq([
		// 	(	instrument: \ctlEnv,
		// 		group: ~chan.synthgroup, addAction: \addBefore,
		// 		out: ~mainAmpCtl.index, outbus: ~mainAmpCtl.index,
		// 		time: tdur, delta: 0, connect: 0,
		// 		env: Env(#[0.05, 1] * -12.5.dbamp, #[1], \exp)
		// 	),
		// 	Pfindur(tdur,
		// 		Ptpar([[0, (tdur * rrand(0.1, 0.25)).round(0.25)], ~onePattern.()].flop.flat)
		// 	)
		// ], 1)
	};
} => PR(\bAnacrusis);
)

BP(\bana).free;
PR(\bAnacrusis) => BP(\bana);
0 => BP(\bana);

BP(\bana).totalDur = Pwhite(8, 12, inf);

BP(\bana).totalDur = 20;

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;


BP(\bana).freq = 59.midicps * Pexprand(1.007.reciprocal, 1.007, inf);

BP(\bana).event.lcrvbamt = 0.1;



// test revised dataIn
// so far, too dependent on velocity -- need other measures
Fact(\dataIn).chuck(BP(\di), nil, (playTestFile: true, readFrame: 138));

BP(\di).startFrame = (9 * 60 + 30) * 30;

BP(\di).startFrame = (10 * 60 + 51) * 30;

BP(\di).playTestFile = true;

\chuckIf.eval(Fact(\armsChordVC), VC, \ac, nil, Library.at(\rvbs));
\chuckIf.eval(PR(\armsChord), BP, \acDisp, nil, (
	angleBus: BP(\di).bus.index + 1, // ??
	rotSpeedBus: BP(\di).bus.index + 4
));
BP(\acDisp) => VC(\ac);
0 => BP(\acDisp);

p = BP(\acDisp);
p.startAuto = p[\saveStartAuto] ? p[\startAuto];
p.row = p[\saveRow] ? p[\row];
p.chord = p[\saveChord] ? p[\chord];
p.fullCh.removeAt(\diss1);
p.fullCh.removeAt(\diss2);
p.amp = 0.dbamp;

BP(\di).playTestFile = true;

Fact(\acTrig).chuck(BP(\act), nil, (delta: Pwhite(1.5, 4.5, inf)));

BP(\di).setStartTime(10, 0);
BP(\di).startTime;

BP(#[di, act]).play(0);

BP(#[di, act]).stop(0);

BP.keys.do { |key|
	if("acDisp[0-9]+".matchRegexp(key.asString)) { BP(key).stop(0) };
};

// keep quiet! the naughty way
s.sendMsg(\d_free, VC(\ac).v.nodes[0].defname);

(
var	p = BP(BP(\acDisp).lastSpawned);
#[rotSpeed, angle, yxRatio].do { |key|
	p[key].autoSynth.tryPerform(\trace);
};
)


// tuning
yxRatio -> row
rotSpeed -> gate
rotSpeed -> dur
rotSpeed -> attScale

BP(#[di, act]).play(0);

BP(\act).stop(0);
u.remove;
u = Updater(BP(BP(\acDisp).lastSpawned), { |obj, what, more|
	if(more == \stopped) {
		u.remove;
		BP(\di).stop;
	}
});

u.remove;
u = Updater(BP(\act), { |obj, what, more|
	var	updater;
	if(more == \stopped) {
		"will stop BP('di') after BP(%) finishes\n".postf(BP(\acDisp).lastSpawned.asCompileString);
		updater = Updater(BP(BP(\acDisp).lastSpawned), { |obj, what, more|
			if(more == \stopped) {
				updater.remove;
				BP(\di).stop;
			}
		});
	};
});

BP.keys.do { |key|
	if("acDisp[0-9]+".matchRegexp(key.asString)) { BP(key).stop(0) };
};

BP(#[di, act]).play(0);

BP(\acDisp).maxRotSpeed = 1.35;
BP(\acDisp).maxSpeedInput = 1;
BP(\acDisp).typicalRotSpeed = 1.35;
BP(\di).maxRatio.value = 1.5;

BP(\acDisp).durxfer.postcs
BP(\acDisp).durxfer = Env(#[1.0, 0.5, 0.15], #[0.45, 0.9], \lin);
BP(\acDisp).dur = Pwrand(#[0.5, 1], #[0.9, 0.1], inf) * (Pkey(\rotSpeed).collect { |rs|
	~durxfer.at(rs/*.debug("speed")*/)
}); //.trace(prefix: "dur");

// bias it to skip row 0 if yx is high enough
BP(\acDisp).row = Plazy({
	(Pwhite(0, 1, inf) + Pkey(\yxRatio).linlin(0, BP(\di).maxRatio, 0, 1.99)).collect(_.asInteger)
});

BP(\acDisp).durxfer.times.sum
BP(\acDisp).durxfer.postcs

p.gate = Pexprand(0.05, 0.2, inf) * Pkey(\rotSpeed).linlin(0.1, Pfunc({ ~typicalRotSpeed }), 3, 4);

p.amp = -10.dbamp;

p.typicalRotSpeed = 0.5;
p.bpsKeys = p.bpsKeys.add(\typicalRotSpeed);

p.maxRotSpeed
p.listVars;

BP.all.do(_.reset);

TempoClock.default.dumpQueue;
TempoClock.default.clear;

u.remove;
BP.all.free; VC.all.free;


// armsInv
BP(\di).setStartTime(10, 48);

BP(\di).buf.get(0, { |d| z = d });
(11*60+10) + z

y = BP(\di).startFrame;

f = SoundFile.openRead(BP(\di).buf.path);
f.isOpen

f.seek(y);
f.readData(d = FloatArray.newClear(10));

f.seek(10, origin: 1);
f.seek(-1, origin: 1);

f.seek(BP(\di).startFrame);
f.readData(d = FloatArray.newClear(10 * 30 * 30));  // 10 samp/frame * 30 sec * 30 frames/sec

d.size

e = d.as(Array);
e = e.clump(12).flop;
e[8].size
e[8].plot;

e[9].plot;

e[4].plot;

e[[2, 4, 3]].flop.flat.plot(numChannels: 3, minval: -1, maxval: 1);
e[[5, 7, 6]].flop.flat.plot(numChannels: 3, minval: -1, maxval: 1);

f.dump
f.close;

e[1].detectIndex(_ > 0)

// now use this to get y position --> pitch
BP(\di).setStartTime(11, 7);

BP(\di).latestData

\chuckIf.eval(Fact(\shimmerpad), VC, \sp, nil, (
	env: Env.adsr(0.5, 0.4, 0.8, 1.8, curve: -2),
	fenv: Env.adsr(0.5, 0.5, 0.1, 3, peakLevel: 1, bias: 1)
).putAll(Library.at(\rvbs)));
\chuckIf.eval(PR(\armsInv), BP, \ai);
BP(\ai).ampCtl.value = 0.115; // 0.045;
VC(\sp) => BP(\ai);
0 => BP(\ai);

p = BP(\ai);
p.autoRun = true;

p.direction = -1;
p.directionStream;

p.slideNotes = (
	lauraslide: Pseries(
		{ |ev|
			if(ev[\parms][\direction].isPositive)
			{ rrand(-7, 0) } { rrand(7, 14) }
		},
		Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf) * Pfunc({ |ev| ev[\parms][\direction] }),
		Pkey(\numEv).asStream
	), // .trace(prefix: "ls: "),
	inversion1: Pseries(
		{ |ev|
			if(ev[\parms][\direction].isPositive)
			{ rrand(-3, 4) } { rrand(10, 17) }
		},
		Pstutter(
			Pseq([Pfuncn({ |ev| (ev[\numEv] * 0.6).round }), 100], 1),
			Pseq([1, -1], 1) * Pfunc({ |ev| ev[\parms][\direction] })
		) * Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
		Pkey(\numEv).asStream
	), // .trace(prefix: "i1: "),
	inversion2: Pseries(
		{ rrand(0, 8) },  // direction doesn't matter
		Pstutter(
			Pseries(1, 1, inf),
			Pseq([1, -1], inf, 0 /*, { 2.rand }*/)
		) * Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
		Pkey(\numEv).asStream
	)
);

p.update = { |obj, what, more|
	switch(obj)
	{ BP(\di) } {
		if(more == \stopped) {
			~prevY = -0.01;
			~thisY = 0;
		}
	}
	{ BP(\di).bus } {
		~prevY = ~thisY;
		~thisY = what[7];
	}
};

BP(\di).addDependant(BP(\ai).v);
BP(\di).bus.addDependant(BP(\ai).v);

p.direction = Pfunc({ (~thisY > ~prevY).binaryValue * 2 - 1 });
BP(\di).dependants

BP(\di).removeDependant(BP(\ai).v);
BP(\di).bus.removeDependant(BP(\ai).v);

p.gest.postcs
p.gest = Pseq(#[inversion1, lauraslide], inf);

BP(\di).play; BP(\ai).play(DelayTimeSpec(0.1));

BP.all.stop;


// later partnering
BP(\di).setStartTime(12, 2);

(
\chuckIf.eval(Fact(\armsmelVC), VC, \bmel, nil, (
	env: { var length = NamedControl.kr(\length, 0); Env.perc(0.01, length) },
	// env: Env.adsr(0.01, 2.5, 0.05, 1.2),
	isMono: false
));
VC(\bmel).v.setArgDefaults([ffreq: 12258]);

\chuckIf.eval(Fact(\bmelBP), BP, \bmel);
0 => BP(\bmel);

topEnvironment[\clock96] ?? {
	topEnvironment[\clock96] = TempoClock(96/60);
};
topEnvironment[\clock96] => BP(\bmel);

BP(\bmel).dur = BP(\bmel).simpleDur;
BP(\bmel).ampMul.value = 0.5;
BP(\bmel).numDescents = Pwhite(3, 5, inf);
BP(\bmel).numDecays = Pwhite(4, 7, inf);
BP(\bmel).distance = BP(\bmel).origDistance;
)

a.trace


a.set(\t_trig, 1);

(
fork {
	var	c = Condition.new, u, start;
	BP(\di).play;
	0.01.wait;
	NodeWatcher.register(BP(\di).v[\fixer]);
	u = Updater(BP(\di).v[\fixer], { |obj, what|
		if(what == \n_go) { u.remove; c.unhang };
	});
	c.hang;
	a = { |inbus, t_trig = 0|
		var	vel = In.kr(inbus-2, 1),
			vdecay = Decay.kr(vel, 0.5),
			vcheck = vel > 0.6;  // this is OK to trigger melody but I'm curious...
		var	area = In.kr(inbus, 1).abs + In.kr(inbus + 2, 1).abs,
			slope = RunningSum.kr(Slope.kr(area), 60) / 60,
			acheck = (slope > 0.5) * (area > 1.7);
		// Poll.kr(/*t_trig*/ Impulse.kr(10), [area, slope]);
		SendReply.kr(/*vcheck **/ acheck, "/vel1trig", [area, slope]);
		0
	}.play(BP(\di).fixer, addAction: \addAfter, args: [inbus: BP(\di).bus.index + 10]);

	o.remove;
	start = Main.elapsedTime;
	o = OSCresponderNode(s.addr, '/vel1trig', { |t, r, m|
		[t - start, m].postln;
		if(BP(\bmel).isPlaying.not) { BP(\bmel).play };
	}).add;
};
)

a.free; BP(\di).stop; o.remove;

a.trace;

60/11



// look at perimeter for L's solo
BP(\di).visualizer = {
	~boundsColor = ~boundsColor ?? { Color.red(alpha: 0.15) };
	~velColor = ~velColor ?? { Color.blue(alpha: 0.3) };
	~uvBackColor = ~uvBackColor ?? { Color.gray(0.9) };
	~velSpec = ~velSpec ?? { #[3, 18, -4].asSpec };
	defer(e {
		~win = ResizeFlowWindow("test", Rect(900, 100, 300, 300))
		.onClose_(e { ~closeWin.() });
		~uv = UserView(~win, 200@200)
		.background_(~uvBackColor)
		.drawFunc_(e { |view|
			var	data = ~latestData.copy,
			// velSize = data[8] * 2 + 3;  // max approx = 18
			velSize = ~velSpec.map(data[8]);
			(5..7).do { |i| data[i] = data[i].neg };
			Pen.color_(~boundsColor)
			.fillRect(Rect.newSides(*(data[#[2, 7, 4, 5]] * 100 + 100)))
			.color_(~velColor)
			.fillOval(Rect.aboutPoint(Point(*(data[#[3, 6]] * 100 + 100)),
				velSize, velSize));
		});
		~win.startRow;
		~tv = StaticText(~win, 200@30)
		.font_(Font.default.copy.size_(18))
		.align_(\center)
		.background_(Color.white);
		~win.startRow;
		~vs = EZSlider(~win, 200@30, "velocity", #[0, 8]);
		~win.startRow;
		~ps = EZSlider(~win, 200@30, "perimeter", #[0, 4]);
		~win.startRow;
		~yx = EZSlider(~win, 200@30, "y/x", #[0.01, 100, \exp]);
		~win.recursiveResize.front;

		KrBusWatcher.newFrom(s).updateFreq_(~vizRate ? 10);
	});
};

BP(\di).upd.remove;
BP(\di).use {
	~upd = Updater(~bus, e { |obj, data|
		var tv, uv, vs, ds, ps, yx, mins, secs;
		~latestData = data;
		~win !? {
			tv = ~tv; uv = ~uv; vs = ~vs; ps = ~ps; yx = ~yx; ds = ~dataSpecs;
			defer {
				vs.value = data[8];
				ps.value = data[10] + data[12];
				yx.value = (data[12] / max(data[10], 0.01)).abs;
				uv.refresh;
				mins = data[0] div: 60;
				secs = (data[0] % 60).trunc;
				tv.string = "%%:%%".format(
					if(mins < 10) { $0 } { "" },
					mins,
					if(secs < 10) { $0 } { "" },
					secs
				);
			};
		};
	});
};

BP(\di).visualizer;

// look at velocity slope for L's solo
BP(\di).visualizer = {
	~boundsColor = ~boundsColor ?? { Color.red(alpha: 0.15) };
	~velColor = ~velColor ?? { Color.blue(alpha: 0.3) };
	~uvBackColor = ~uvBackColor ?? { Color.gray(0.9) };
	~velSpec = ~velSpec ?? { #[3, 18, -4].asSpec };
	defer(e {
		~win = ResizeFlowWindow("test", Rect(900, 100, 300, 300))
		.onClose_(e { ~closeWin.() });
		~uv = UserView(~win, 200@200)
		.background_(~uvBackColor)
		.drawFunc_(e { |view|
			var	data = ~latestData.copy,
			// velSize = data[8] * 2 + 3;  // max approx = 18
			velSize = ~velSizeSpec.map(data[8]);
			(5..7).do { |i| data[i] = data[i].neg };
			Pen.color_(~boundsColor)
			.fillRect(Rect.newSides(*(data[#[2, 7, 4, 5]] * 100 + 100)))
			.color_(~velColor)
			.fillOval(Rect.aboutPoint(Point(*(data[#[3, 6]] * 100 + 100)),
				velSize, velSize));
		});
		~win.startRow;
		~tv = StaticText(~win, 200@30)
		.font_(Font.default.copy.size_(18))
		.align_(\center)
		.background_(Color.white);
		~win.startRow;
		~vs = EZSlider(~win, 200@30, "velocity", #[0, 8]);
		~win.startRow;
		~vsl = EZSlider(~win, 200@30, "vel slope", #[-10, 10]);
		~win.startRow;
		~yx = EZSlider(~win, 200@30, "y/x", #[0.01, 100, \exp]);
		~win.recursiveResize.front;

		KrBusWatcher.newFrom(s).updateFreq_(~vizRate ? 10);
	});
};

BP(\di).upd.remove;
BP(\di).use {
	~upd = Updater(~bus, e { |obj, data|
		var tv, uv, vs, ds, vsl, yx, mins, secs;
		~latestData = data;
		~win !? {
			tv = ~tv; uv = ~uv; vs = ~vs; vsl = ~vsl; yx = ~yx; ds = ~dataSpecs;
			defer {
				vs.value = data[8];
				vsl.value = data[25];
				yx.value = (data[13] / max(data[12], 0.01)).abs;
				uv.refresh;
				mins = data[0] div: 60;
				secs = (data[0] % 60).trunc;
				tv.string = "%%:%%".format(
					if(mins < 10) { $0 } { "" },
					mins,
					if(secs < 10) { $0 } { "" },
					secs
				);
			};
		};
	});
};

BP(\di).visualizer;

BP(\di).free;
Fact(\dataIn).chuck(BP(\di), nil, (playTestFile: true, readFrame: 138));
Fact(\dataIn).chuck(BP(\di), nil, (playTestFile: true, readFrame: 138, frameRate: 44100/1024));

BP(\di).setStartTime(14, 57);  // L's solo
BP(\di).setStartTime(15, 23);

BP(\di).play;
Server.killAll;

BP(\di).fixer.trace;

BP(\di).stop;

// states:
// tall, decreasing velocity
// tall, increasing velocity
// squat, low vel
// squat, high vel

u.remove;
u = Updater(BP(\di), { |obj, what, more|
	if(more == \stopped) { a.free }
});

// velocity is wiggly; how often does its slope switch sign?
// sometimes 2 1's or 2 0's in a row??
a = {
	var vslope = In.kr(BP(\di).busIndex(\vavg) + 14, 1),
		sign = vslope.sign,
		// sign changed, and is non-zero
		trig = (sign * HPZ1.kr(sign)).abs > 0,
		rawtime = Timer.kr(trig),
		longtrig = trig * (rawtime > 0.12),
		// apparently this is the ONLY FUCKING WAY to remember previous values on demand
		membuf = LocalBuf(1),
		prevSign = Demand.kr(longtrig, 0, Dbufrd(membuf, 0)),
		thisSign = Latch.kr(sign, longtrig);
	Demand.kr(longtrig <! prevSign, 0, Dbufwr(thisSign, membuf, 0));
	longtrig = longtrig * BinaryOpUGen('!=', prevSign, thisSign);
	//Poll.kr(longtrig, Timer.kr(longtrig));
	SendReply.kr(longtrig, '/timer', [Timer.kr(longtrig), sign, thisSign, prevSign]);
	//SendReply.kr(trig, '/timer', [rawtime, sign]);
	//Poll.kr(trig, rawtime);
	0
}.play(addAction: \addToTail);

a.free;

a.trace;

o.remove;
o = OSCresponderNode(s.addr, '/timer', { |t, r, m| m.postln }).add;

o = OSCresponderNode(s.addr, '/timer', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;

s.sendMsg(\n_free, 1024);

BP(\di).latestData[9+16];

(
w = ResizeFlowWindow("temp", Rect(10, 50, 150, 100));
Button(w, 60@20)
.states_([["GO"]])
.action_({ BP(\acDisp).spawnChild(0) });
w.recursiveResize.front;
)

p = BP(\acDisp);
p.row.postcs;

p.row = Plazy({
	(/*Pwhite(0, 1, inf) +*/ Pkey(\yxRatio).linlin(0, BP(\di).maxRatio, 0, 2.99)).trunc
});

BP(BP(\acDisp).lastSpawned).yxRatio.autoSynth.trace;


(
fork {
	var	c = Condition.new, u, start;
	BP(\di).play;
	0.01.wait;
	NodeWatcher.register(BP(\di).v[\fixer]);
	u = Updater(BP(\di).v[\fixer], { |obj, what|
		switch(what)
			{ \n_go } { c.unhang }
			{ \n_end } { u.remove; a.free };
	});
	c.hang;
	// // not bad as a bass trigger
	// a = { |inbus, t_trig = 0|
	// 	var	yx = (In.kr(inbus + 2, 1) / max(0.01, In.kr(inbus, 1))).abs,
	// 		trig = yx < 1.2,
	// 		timer = Timer.kr(trig),
	// 		thintrig = trig * (timer > 1.5),
	// 		thintimer = Timer.kr(thintrig);
	// 	Poll.kr(thintrig, [thintimer, yx]);
	// 	0
	// }.play(BP(\di).fixer, addAction: \addAfter, args: [inbus: BP(\di).bus.index + 10]);

	a = ~master.play({ |inbus|
		var	vel = In.kr(inbus, 1),
			avgSamps = 0.15 * ControlRate.ir;
		vel = RunningSum.kr(vel, avgSamps) / avgSamps;
		vel = #[0, 18, -4].asSpec.map(vel);
		SinOsc.ar(vel.linexp(0, 18, 100, 600)) ! 2
	}, [inbus: BP(\di).bus.index + 8]);

	// o.remove;
	// start = Main.elapsedTime;
	// o = OSCresponderNode(s.addr, '/vel1trig', { |t, r, m|
	// 	[t - start, m].postln;
	// 	if(BP(\bmel).isPlaying.not) { BP(\bmel).play };
	// }).add;
};
)

a.free; BP(\di).stop; // o.remove;

s.sendMsg(\n_free, 1027);


// for laura's solo: bouncy chords
// Env.perc is too sharp
\chuckIf.eval(Fact(\shimmerpad), VC, \sp2, nil, (
	env: {
		var t = NamedControl.kr(\sustain, 0.1);
		Env.perc(0.01, t, curve: -1.2) // Env(#[0, 1, 0.4, 0], [] * t)
	},
	fenv: {
		var t = NamedControl.kr(\sustain, 0.1);
		Env(#[0.25, 1, 0.25], [0.01, t], \exp)
	},
	bufmod: { NamedControl.kr(\bufmod, 0) }
).putAll(Library.at(\rvbs)));

VC(\sp2).v.globalControls.do { |gc| VC(\sp2).v.unmapGlobal(gc.name) };

TempoClock.tempo = 96/60;

p = Pbind(
	\voicer, VC(\sp2).v,
	\freq, (Pwhite(35, 42, inf) -.x Pseries(0, Pwrand(#[1, 2, 3], #[1, 3, 3], 3), 3)).clump(3),
	\mode, \g,
	\dur, Pseq([0.5, Pn(0.25, { rrand(0, 3) })], inf),
	\length, Pkey(\dur) * 16,
	\bufmod, Pwhite(0, 6.99, inf),
	\gate, 0.4,
	\attackTimeScale, 0.1,
	\decayTimeScale, 0.1,
	\ffreq, Pexprand(900, 6000, inf),
	\rq, 0.5 - Pexprand(0.01, 0.45, inf)
).play(protoEvent: ProtoEvent(\voicerNote).copy.proto_(~rvbEvent.proto));

p.stop;

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;


(
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);

	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;
	};

	~freq = (Pwhite(35, 42, inf) -.x Pseries(0, Pwrand(#[1, 2, 3], #[1, 3, 3], 3), 3)).clump(3);
	~mode = \g;
	~dur = Pseq([0.5, Pn(0.25, { rrand(0, 3) })], inf);
	~length = Pkey(\dur) * 16;
	~bufmod = Pwhite(0, 6.99, inf);
	~gate = 0.4;
	~attackTimeScale = 0.1;
	~decayTimeScale = 0.1;
	~ffreq = Pexprand(900, 6000, inf);
	~rq = 0.5 - Pexprand(0.01, 0.45, inf);
	~distance = 5;
	~pan = 0;

	~asPattern = {
		Pbind(
			\freq, BPStream(\freq),
			\mode, BPStream(\mode),
			\dur, BPStream(\dur),
			\length, BPStream(\length),
			\sustain, Pkey(\length) / Ptempo(),
			\bufmod, BPStream(\bufmod),
			\gate, BPStream(\gate),
			\attackTimeScale, BPStream(\attackTimeScale),
			\decayTimeScale, BPStream(\decayTimeScale),
			\distance, BPStream(\distance),
			\pan, BPStream(\pan),
			\ffreq, BPStream(\ffreq),
			\rq, BPStream(\rq)
		)
	};
} => PR(\armsFastCh);
)

BP(\afc).free;
PR(\armsFastCh) => BP(\afc);
VC(\sp2) => BP(\afc);
1 => BP(\afc);

p = BP(\afc);

p.attackTimeScale = 1;
p.decayTimeScale = 1;
p.length = Pkey(\dur);

p.ffreq = Pwhite(1200, 12000, inf);
p.ffreq = Pif(0.15.asPattern.coin, Pwhite(900, 1400, inf), Pwhite(2400, 12000, inf));
p.rq = Pif(0.15.asPattern.coin, Pwhite(0.05, 0.15, inf), Pwhite(0.5, 0.9, inf));

p.top = \patRejectLastN.eval(Pwhite(32, 47, inf), 4);
p.intervals = Pseries(0, Pwrand(#[1, 2, 3], #[1, 3, 3].normalizeSum, 3), 3);
p.freq = Plazy({ (BPStream(\top) -.x BPStream(\intervals, resetSource: true)).clump(3) });

p.dur = Pwrand([
	Pseq([Pn(0.25, { rrand(0, 3) }), 0.5], { rrand(3, 5) }),
	Pseq(#[0.75, 0.5], { rrand(3, 5) }, { 2.rand })
], #[0.8, 0.2], inf);

p.length = min(Pkey(\dur) * 0.9, 0.5);

p.distance = 20;
p.distance = 5;

p.pan = Pwhite(-0.8, 0.8, inf) + Pn(Pshuf(#[-0.2, 0, 0.2], 1).clump(3), inf);

p.pan = -1;

p.startDeg = Pwhite(39, 50, inf);
p.numDescents = Pwhite(3, 6, inf);
p.scaleLen = Pwhite(3, 5, inf);
p.numDecays = Pif(0.2.asPattern.coin, Pwhite(3, 7, inf), 0);

p.top = Pseq([
		(
			Pseries({ |ev| ~startDegStream.next(ev) },
				Pwhite(-4, -2, { |ev| ~numDescentsStream.next(ev) }))
				.collect { |bot| if(bot >= 28) { ~bot = bot } { nil } }
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
			~decay = num;
			(~bot + ~scaleSize) + Pseq([0, #[-6, -5/*, -3*/].choose], num, 2.rand)
		})
	], inf);

BP(\di).setStartTime(14, 57);  // L's solo

// really, half-perimeter
p.perimeterCtl = GenericGlobalControl(\perim, nil, 0, #[0, 4]);
p.v[\freeCleanup] = { ~perimeterCtl.free };

p.perimeterCtl.automate({ |inbus|
	In.kr(inbus, 1).abs + In.kr(inbus + 2, 1).abs
}, [inbus: BP(\di).busIndex(\xspan)], p.event.voicer.bus.asMixer.fadergroup, \addToHead);

p.perimeterCtl.watch;
p.perimeterCtl.gui;

p.perimeterCtl.stopAuto;
p.perimeterCtl.stopWatching;

BP(\di).fixer.trace;

p.distance = p.perimeterCtl.asPattern.linlin(0.4, 1.6, 20, 5);

BP(#[di, afc]).play;

BP(#[di, afc]).stop;

// pitch contour from height



BP(\bmel).use {
	BP(\bmel).origDistance = (Pkey(\angle).cos * Pkey(\decayCurve))
	.linlin(-1, 1,
		Pkey(\decayCurve).explin(0.05, 1, 100, 14),
		Pkey(\decayCurve).explin(0.05, 1, 100, 5)
	).linlin(5, 100, Pfunc({ BP(\di).latestData[~dataIndices[2]].linlin(0, 4, 70, 5) }), 100);
};

BP(\bmel).use {
		~dataIndices = #[xmin, xmax, yspan].collect { |name|
			BP(\di).busIndex(name) - BP(\di).bus.index
		};
};



// find extra points at right edge
a = {
	var	buses = BP(\di).recvBus.index + #[0, 3],
	sig = In.kr(buses, 1),  // [phase, xmax]
	realTime = Index.kr(BP(\di).buf, sig[0].trunc * BP(\di).buf.numChannels);
	SendReply.kr(sig[1] > 0.95, '/highx', [realTime, sig[1]]);
	0
}.play(addAction: \addToTail);

a.trace;
a.free;

o.remove;
o = OSCresponderNode(s.addr, '/highx', { |t, r, m| m.postln }).add;

BP(\di).buf.get(0, { |d| x = d });
x

BP(\di).buf.get(935*12, { |d| [d, d-x].postln });


Proto { ~dataAt = { 20.0.rand } } => BP(\yxtrk);

// forget velocity, use y/x ratio
z = Pwhile1({ |in, next| next <= 53 }, Pseries(21, Pwrand(#[1, 2, 3], #[0.1, 0.5, 0.4], inf), inf)).asStream.all;

s.latency = 0.075;

BP(\di).setStartTime(14, 50);

(
// counterintuitively, if thresh is too low (1.0-2.0), it is NOT more sensitive
// because it's more likely to have recent values above the threshold
var	lastTrigTime = 0, esp, thresh = 4,
	protoEv = ProtoEvent(\voicerNote).copy.proto_(~rvbEvent.proto.copy.put(\lcrvbamt, 0.035).put(\distFar, 45)),
	modes = Mode.keys.select { |key| key != \g0 and: { key.asString.last == $0 } }.asArray;
BP(\di).play;
p = Pbind(
	\voicer, VC(\ac).v,
	\esphash, Pfunc({ esp.hash }),
	\lasthash, Pdelay(Pkey(\esphash), 1),
	\newesp, Pseq([true, Pbinop('!=', Pkey(\esphash), Pkey(\lasthash))], 1),
	\degrees, Pclutch(
		Pn(Pwhile1({ |in, next| next <= 53 },
			Pseries(
				\patRejectLastN.eval(Pwhite(19, 25, inf), 3).asStream,
				Pwrand(#[1, 2, 3], #[0.1, 0.5, 0.4], inf), inf
			)
		).clump(500), inf),
		Pkey(\newesp)
	),
	\mode, \g0,
	\yx, Pfunc({ BP(\yxtrk).dataAt(0).clip(0, 12) }),
	\attackTimeScale, Pif(Pkey(\newesp), 0.1, 1),
	\randomizer, Pif(Pkey(\newesp), 0, Pkey(\yx).linlin(0, 12, 0, 5)),
	\base, Pif(Pkey(\newesp), 0, Pkey(\yx).linlin(0, 12, 0, Pfunc({ |ev| ev[\degrees].size - 6 }))),
	#[i, ok], Pfunc({ |ev|
		var	i, rand, base = ev[\base], randTop = ev[\randomizer],
			test = { |hz| ev[\voicer].nodes.any { |n| n.isPlaying and: { n.frequency == hz } } };
		block { |break|
			3.do {
				rand = randTop.rand;
				i = (base + rand).round;
				if(test.(Mode(ev[\mode]).cps(ev[\degrees][i])).not) {
					// ev[\i] = (ev[\base] + rand).round;
					break.([i, true])
				};
			};
			[-1, false]
		}
	}),
	\freq, Pif(Pkey(\ok), Pindex(Pkey(\degrees), Pfinval(1, Pkey(\i)), inf), #[]),  // #[] == rest
	\dur, Pkey(\yx).linexp(0, 20, 0.5, 0.1) * Pexprand(3/4, 4/3, inf),
	\length, Pkey(\dur) * Pkey(\yx).linlin(0, 20, 8, 3) * Pexprand(3/4, 4/3, inf),
	\gate, Pif(Pkey(\newesp), 0.8, Pexprand(0.2, 0.4, inf)),
	// random around xavg
	\pan, Pfunc({ BP(\dr).latest[3] + (0.5.rand2 * BP(\dr).latest[12]) }),
	\distance, Pfunc({ BP(\dr).latest[13].linlin(0, 1, 45, 5) }),
	\eventTransmit, Pif(Pkey(\newesp), Pfunc({ |ev| esp.changed(\event, ev); 0 }), 0)
).asStream;

u.remove;
u = Updater(BP(\yxtrk), { |obj, what, median|
	var	espUpd;
	switch(what) { \yxraw } {
		if(median > thresh and: { esp.clock.beats - lastTrigTime > 0.12 and: {
			BP(\yxtrk).rbuf.count(_ > thresh) < 4
		} }) {
			lastTrigTime = esp.clock.beats;
			esp.stop;
			VC(\ac).releaseAll(s.latency);
			esp = EventStreamPlayer(p, protoEv).play;
			espUpd = Updater(esp, { |obj, what, event|
				if(what == \event) {
					espUpd.remove;
					(	voicer: VC(\abs).v,
						mode: event[\mode],
						freq: event[\degrees][0],
						delta: 1,
						length: rrand(2.5, 5.5),
						gate: 0.9
					).parent_(protoEv.parent)
					.play;
				}
			});
		};
	}
	{ \stop } { esp.stop }
});

esp = EventStreamPlayer(p, protoEv).play;
)

BP(\di).stop;

BP(\di).setStartTime(14, 0);

(
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);
	~alwaysReset = true;
	~trigKey = \lsyx;
	~dataKey = \dr;
	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto.copy
			.put(\lcrvbamt, 0.035).put(\distFar, 45);
	};

	~preparePlay = {
		~noteRoutine = ~noteStrm.();
	};
	~stopCleanup = {
		~esp.stop;
	};
	~nextNoteNow = {
		if(~isPlaying) {
			~esp.stop;
			~event[\voicer].releaseAll;
			~esp = EventStreamPlayer(~noteRoutine, ~event).play;
		} { "BP(%) can't go, not playing".format(~collIndex.asCompileString).warn; };
	};

	~degrees = Pclutch(
		Pn(Pwhile1({ |in, next| next <= 53 },
			Pseries(
				\patRejectLastN.eval(Pwhite(19, 25, inf), 3).asStream,
				Pwrand(#[1, 2, 3], #[0.1, 0.5, 0.4], inf), inf
			)
		).clump(500), inf).collect { |degs| ~degArray = degs },
		Pkey(\newesp)
	);
	~mode = \g0;
	~yx = Pfunc({ BP(~trigKey).median.clip(0, 12) });
	~attackTimeScale = Pif(Pkey(\newesp), 0.1, 1);
	// ~randomizer = Pif(Pkey(\newesp), 0, Pkey(\yx).linlin(0, 12, 0, 5));
	// ~base = Pif(Pkey(\newesp), 0, Pkey(\yx).linlin(0, 12, 0, Pfunc({ |ev| ev[\degrees].size - 6 })));
	~randomizer = Pkey(\yx).linlin(0, 12, 0, 5);
	~base = Pkey(\yx).linlin(0, 12, 0, Pfunc({ |ev| ev[\degrees].size - 6 }));
	~iok = Pfunc({ |ev|
		var	i, rand, base = ev[\base], randTop = ev[\randomizer],
			test = { |hz| ev[\voicer].nodes.any { |n| n.isPlaying and: { n.frequency == hz } } };
		block { |break|
			3.do {
				rand = randTop.rand;
				i = (base + rand).round;
				if(test.(Mode(ev[\mode]).cps(ev[\degrees][i])).not) {
					// ev[\i] = (ev[\base] + rand).round;
					break.([i, true])
				};
			};
			[-1, false]
		}
	});
	// #[] == rest
	~freq = Pif(Pkey(\ok), Pindex(Pkey(\degrees), Pfinval(1, Pkey(\i)), inf), #[]);
	~dur = Pkey(\yx).linexp(0, 12, 0.5, 0.1) * Pexprand(3/4, 4/3, inf);
	~length = Pkey(\dur) * Pkey(\yx).linlin(0, 20, 8, 6);
	~gate = Pif(Pkey(\newesp), 0.8, Pexprand(0.2, 0.4, inf));
	// random around xavg
	~pan = Pfunc({ BP(\dr).latest[3] + (0.5.rand2 * BP(\dr).latest[12]) });
	~distance = Pfunc({ BP(\dr).latest[13].linlin(0, 1, 45, 5) });

	~noteStrm = {
		CleanupStream(Pbind(
			\esphash, Pfunc({ ~esp.hash }),
			\lasthash, Pdelay(Pkey(\esphash), 1),
			\newesp, Pseq([true, Pbinop('!=', Pkey(\esphash), Pkey(\lasthash))], 1),
			\degrees, BPStream(\degrees, resetSource: true),
			\mode, BPStream(\mode, resetSource: true),
			\yx, BPStream(\yx, resetSource: true),
			\attackTimeScale, BPStream(\attackTimeScale, resetSource: true),
			\randomizer, BPStream(\randomizer, resetSource: true),
			\base, BPStream(\base, resetSource: true),
			#[i, ok], BPStream(\iok, resetSource: true),
			\freq, BPStream(\freq, resetSource: true),
			\dur, BPStream(\dur, resetSource: true),
			\length, BPStream(\length, resetSource: true),
			\gate, BPStream(\gate, resetSource: true),
			\pan, BPStream(\pan, resetSource: true),
			\distance, BPStream(\distance, resetSource: true),
			\eventTransmit, Pif(Pkey(\newesp), Pfunc({ |ev| ~esp.changed(\event, ev); 0 }), 0)
		).asStream, { ~preparePlay.() });  // rebuild stream if it runs out of events
	};

	~asPattern = {
		var	self = currentEnvironment;
		Pseq([
			(play: { self.nextNoteNow }, dur: 4),
			Pn((freq: #[], dur: 4, length: 1, gate: 1), inf)
		], 1)
	};
} => PR(\yxswirls);
)

BP(\dr).free;
PR(\dataReader) => BP(\dr);
0 => BP(\dr);

BP(\lsyx).free;
Fact(\lsoloTrig) => BP(\lsyx);

BP(\yxsw).free;
PR(\yxswirls) => BP(\yxsw);
VC(\ac) => BP(\yxsw);
0 => BP(\yxsw);

s.latency = 0.075;

u.remove;
u = Updater(BP(\lsyx), { |obj, what, more|
	case { what == \play } { BP(\yxsw).play }
		{ more == \stopped } { BP(\yxsw).stop };
});

BP(\lsyx).doTrig = {
	var espUpd;
	BP(\yxsw).nextNoteNow;
	espUpd = Updater(BP(\yxsw).esp, { |obj, what, event|
		if(what == \event) {
			espUpd.remove;
			(	voicer: VC(\abs).v,
				mode: event[\mode],
				freq: event[\degrees][0] - 7,
				delta: 1,
				length: rrand(3.5, 5.5),
				gate: 0.4
			).parent_(ProtoEvent(\voicerNote).v.parent)
			.play;
		}
	});
};

VC(\abs).portaTime = 0.8;

p = BP(\yxsw);

p.dur = Pkey(\yx).linexp(0, 12, 0.5, 0.1) * Pexprand(3/4, 4/3, inf);
p.length = Pkey(\dur) * Pkey(\yx).linlin(0, 20, 8, 6); // * Pexprand(3/4, 4/3, inf);

p.randomizer = Pkey(\yx).linlin(0, 12, 0, 5);
p.base = Pkey(\yx).linlin(0, 12, 0, Pfunc({ |ev| ev[\degrees].size - 6 }));

p.length = Pwhite(1.5, 2.5, inf);

Object.dependantsDictionary.keys.select(_.isKindOf(EventStreamPlayer)).copy.do(_.releaseDependants);

// flourish when laura goes to the floor

v = VC(\bmel).v;

(type: \voicerNote, voicer: v, scale: Mode(\g0).scale, octave: 0,
degree: Pwhile1({ |in, next| next <= 53 },
	Pseries(
		\patRejectLastN.eval(Pwhite(26, 31, inf), 3).asStream,
		Pwrand(#[1, 2, 3], #[0.1, 0.5, 0.4], inf), inf
	)
).clump(500).asStream.next, gate: 0.1, length: 5, strum: 0.05).play;

(
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);
	~alwaysReset = true;
	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto.copy
			.put(\lcrvbamt, 0.015).put(\distFar, 45);
		~makeStreamForKey.(\top);
	};

	~top = \patRejectLastN.eval(Pwhite(47, 53, inf), 3);
	~freq = Plazy({
		~chordNotes = Pwhile1({ |in, next| next >= 25 },
			Pseries(
				{ |ev| ~topStream.next(ev) },
				Pwrand(#[-1, -2, -3], #[0.1, 0.5, 0.4], inf), inf
			)
		).asStream.all;
		Pseq(~chordNotes, 1)
	});
	~dur = max(0.1, Pgeom({ rrand(0.25, 0.35) }, Pstutter(200, Pwhite(0.84, 0.9, inf)), inf));
	~length = 7;
	~gate = 0.6;
	~pan = Plazy({
		var	start = BP(\di).latestData[3];
		Pseries.fromEndpoints(start, start.sign.neg, ~chordNotes.size);
	});
	~distance = Plazy({ Pseries.fromEndpoints(5, 40, ~chordNotes.size) });
	~ampMul = 2.2;
	~mode = \g0;

	~asPattern = {
		Pbind(
			\freq, BPStream(\freq, resetSource: true),
			\dur, BPStream(\dur, resetSource: true),
			\length, BPStream(\length, resetSource: true),
			\gate, BPStream(\gate, resetSource: true),
			\distance, BPStream(\distance, resetSource: true),
			\pan, BPStream(\pan, resetSource: true),
			\ampMul, BPStream(\ampMul),
			\mode, BPStream(\mode)
		)
	};
} => PR(\bellFlourish);
)

BP(\bfl).free;
PR(\bellFlourish) => BP(\bfl);
VC(\bmel) => BP(\bfl);
0 => BP(\bfl);

BP(\bfl).gate = 0.6;

// shorten dur
BP(\bfl).dur = max(0.1, Pgeom({ rrand(0.25, 0.35) }, Pstutter(200, Pwhite(0.84, 0.9, inf)), inf));

BP(\bfl).freq = Plazy({
	~chordNotes = Pwhile1({ |in, next| next >= 25 },
		Pseries(
			{ |ev| ~topStream.next(ev) },
			Pwrand(#[-1, -2, -3], #[0.1, 0.5, 0.4], inf), inf
		)
	).asStream.all;
	Pseq(~chordNotes, 1)
});

BP(\bfl).pan = Plazy({
	var	start = BP(\di).latestData[3];
	Pseries.fromEndpoints(start, start.sign.neg, ~chordNotes.size);
});
BP(\bfl).distance = Plazy({ Pseries.fromEndpoints(5, 40, ~chordNotes.size) });

BP(\bfl).printStopMsg = false;

BP(\bfl).event.proto.put(\lcrvbamt, 0.015);

VC(\sp).free;
Fact(\shimmerpad).chuck(VC(\sp), nil, (
	env: Env.adsr(0.5, 0.4, 0.8, 1.8, curve: -2),
	fenv: {
		var	peak = NamedControl.kr(\fenvpeak, 1);
		Env.adsr(0.5, 0.5, 0.1, 3, peakLevel: peak, bias: 1)
	},
	globalFilter: false
));


(type: \voicerNote, voicer: VC(\sp).v, scale: Mode(\g0).scale, octave: 0,
degree: Pwhile1({ |in, next| next <= 53 },
	Pseries(
		\patRejectLastN.eval(Pwhite(26, 31, inf), 3).asStream,
		Pwrand(#[1, 2, 3], #[0.1, 0.5, 0.4], inf), inf
	)
).clump(500).asStream.next, gate: 0.8, finalAmp: 0.05,
attackTimeScale: 3, decayTimeScale: 7, ffreq: 800, fenvpeak: 14000/800 - 1, rq: 0.3, sustain: 5)
.proto_(~rvbEvent.proto)
.play;

VC(\sp).v.nodes.detect(_.isPlaying).synth.trace;

p = (Pbind(
	\voicer, VC(\sp).v,
	\mode, \g0,
	\freq, Pn(Pseries(
		Pwhite(40, 53, inf).asStream,
		Pwrand(#[-1, -2, -3], #[0.1, 0.5, 0.4], inf),
		{ rrand(4, 7) }
	).clump(500), inf),
	\dur, Pwhite(3.5, 6.5, inf),
	\length, Pwhite(3.0, 7.0, inf),
	\gate, 0.8,
	\pan, Pwhite(0.5, 1.0, inf) * Prand(#[-1, 1], inf),
	\distance, Pwhite(5.0, 20.0, inf),
	\ffreq, Pexprand(400, 1200, inf),
	\fenvpeak, (14000 / Pkey(\ffreq)) - 1
) <> (finalAmp: 0.05, attackTimeScale: 2.5, decayTimeScale: 4, rq: 0.3))
.trace
.play(protoEvent: ProtoEvent(\voicerNote).copy.proto_(~rvbEvent.proto));

p.stop;

(
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);
	~alwaysReset = true;
	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto.copy
			.put(\lcrvbamt, 0.015).put(\distFar, 45);
		~makeStreamForKey.(\top);
	};

	~mode = \g0;
	~freq = Pseq([
		Pfuncn({ BP(\bfl).chordNotes }, 1),
		Pn(Pseries(
			Pwhite(40, 53, inf).asStream,
			Pwrand(#[-1, -2, -3], #[0.1, 0.5, 0.4], inf),
			{ rrand(4, 7) }
		).clump(500), inf)
	], 1);
	~dur = Pwhite(3.5, 6.5, inf);
	~length = Pwhite(3.0, 7.0, inf);
	~gate = 0.8;
	~pan = Pwhite(0.5, 1.0, inf) * Prand(#[-1, 1], inf);
	~distance = Pwhite(5.0, 20.0, inf);
	~ffreq = Pexprand(400, 1200, inf);
	~fenvpeak = (14000 / Pkey(\ffreq)) - 1;
	~finalAmp = 0.4;
	~attackTimeScale = 4.5;
	~decayTimeScale = 4;
	~rq = 0.3;

	~asPattern = {
		Pbind(
			\freq, BPStream(\freq, resetSource: true),
			\dur, BPStream(\dur, resetSource: true),
			\length, BPStream(\length, resetSource: true),
			\gate, BPStream(\gate, resetSource: true),
			\distance, BPStream(\distance, resetSource: true),
			\pan, BPStream(\pan, resetSource: true),
			\finalAmp, BPStream(\finalAmp),
			\mode, BPStream(\mode),
			\ffreq, BPStream(\ffreq),
			\fenvpeak, BPStream(\fenvpeak),
			\attackTimeScale, BPStream(\attackTimeScale),
			\decayTimeScale, BPStream(\decayTimeScale),
			\rq, BPStream(\rq)
		)
	};
} => PR(\quietChords);
)

BP(\qc).free;
PR(\quietChords) => BP(\qc);
VC(\sp) => BP(\qc);
0 => BP(\qc);

BP(\qc).reset;
BP(\qc).triggerOneEvent(0);

BP(\qc).finalAmp = 0.6;
BP(\qc).attackTimeScale = 4.5;

BP(\qc).pan = Pseq([
		Pfuncn({ |ev| (-1.0, (ev[\freq].size - 1).reciprocal - 1 .. 1.0).scramble }),
		Pwhite(0.5, 1.0, inf) * Pseq(#[-1, 1], inf, { 2.rand })
], 1).trace(prefix: "pan: ");


// lsolo melody
BP(\lm).free;

(
(make: { |name|
	BP(name).free;
	PR(\locoMel).chuck(BP(name), nil, (
		numDescents: 4,
		scaleLen: Pwhite(2, 5, inf),
		numDecays: Pwhite(2, 3, inf),
		startDeg: Pwhite(41, 48, inf),
		freq: Pseq([
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
				(~bot + ~scaleSize) + Pseq([0, #[-6, -5/*, -3*/].choose], num, 0 /* 2.rand */)
			})
		], 1),
		preparePlay: {
			~decay = nil;
			~clock.schedAbs(~eventSchedTime, e {
				~event[\voicer].globalControls[\distance].automate(\ctlEnv, [
					env: Env(#[5, 25], [rrand(12.0, 19.0)], rrand(1.0, 2.2)),
					connect: 0
				], addAction: \addToHead);
			});
		},
		dur: Pswitch([Pn(0.25, 2), 0.5, 0.75, 1, Pwhite(4, 7, 1) * 0.5],
			Penvir((prev: -1, count: 0, countLimits: #[2, 3, 2, 1, 1],
				collIndex: name,  // tricky! no good way to get this after-the-fact
				sideEffect: { |x| x }),
				Pseq([
					Pwhite(1, 3, 1),
					Pwrand([0, 1, 2, 3, 4], #[3, 9, 15, 12, 5].normalizeSum, inf)
					.reject { |index| (index == 4) and: { BP(~collIndex)[\decay].notNil } }
				])
				.select { |val|
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
		),
		length: Pif(
			(Pkey(\dur) > 1),
			min(Pkey(\dur) - 0.5, Pwhite(1.75, 2.75, inf)),
			Pkey(\dur) * Pwrand(#[0.7, 0.98, 1.01], #[0.1, 0.1, 0.8], inf)
		)
		));
	0 => BP(name);
}, type: \bp) => Fact(\lsoloMel);
)

BP(\lsm).free;
Fact(\lsoloMel) => BP(\lsm);
VC(\lm) => BP(\lsm);

p = BP(\lsm);

p.numDescents = 4;
p.scaleLen = Pwhite(2, 5, inf);
p.numDecays = Pwhite(2, 3, inf);
p.startDeg = Pwhite(47, 51, inf);

p.startDeg = Pwhite(41, 48, inf);

#[numDescents, scaleLen, numDecays, startDeg].do { |key| p.makeStreamForKey(key) };

p.startDegStream.next

p.freq = Pseq([
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
		(~bot + ~scaleSize) + Pseq([0, #[-6, -5/*, -3*/].choose], num, 0 /* 2.rand */)
	})
], 1);

p.length.postcs
p.dur.postcs

// well THAT'S just a bit obscure...
p.dur.which.pattern.pattern.weights_(#[1, 3, 5, 4].normalizeSum);
p.dur = p.dur;

SynthDef(\lsmPanAuto, { |outbus, freqStart = 0.8, freqEnd = 0.1, time = 1|
	Out.kr(outbus, SinOsc.kr(
		Line.kr(freqStart, freqEnd, time),
		Rand(0, 2pi),
		Line.kr(1.0, 0.05, time, doneAction: 2)
	))
}).add;


p.preparePlay = {
	~decay = nil;
	~clock.schedAbs(~eventSchedTime, e {
		var	time = rrand(12.0, 19.0);
		~event[\voicer].globalControls[\distance].automate(\ctlEnv, [
			env: Env(#[5, 25], [time], 4.5 /* rrand(1.0, 2.2) */),
			connect: 0
		], addAction: \addToHead);
		~event[\voicer].globalControls[\pan].automate(\lsmPanAuto, [
			time: time, freqStart: rrand(0.4, 0.6), freqEnd: 0.05
		], addAction: \addToHead);
	});
};

p.dur = Pswitch([Pn(0.25, 2), 0.5, 0.75, 1, Pwhite(4, 7, 1) * 0.5],
	Penvir((prev: -1, count: 0, countLimits: #[2, 3, 2, 1, 1], sideEffect: { |x| x }),
		Pseq([
			Pwhite(1, 3, 1),
			Pwrand([0, 1, 2, 3, 4], #[3, 9, 15, 12, 5].normalizeSum, inf)
			.reject { |index| (index == 4) and: { BP(~collIndex)[\decay].notNil } }
		])
		.select { |val|
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
p.dur.which.envir.put(\collIndex, \lsm);

p.length = Pif(
	(Pkey(\dur) > 1),
	min(Pkey(\dur) - 0.5, Pwhite(1.75, 2.75, inf)),
	Pkey(\dur) * Pwrand(#[0.7, 0.98, 1.01], #[0.1, 0.1, 0.8], inf)
);

VC(\lm).v.nodes[0].initArgs
VC(\lm).v.setArgDefaults([distFar: 40, lcrvbamt: 0.016]);
VC(\lm).v.gui;

VC(\lm).v.globalControls[\distance].spec = #[5, 40];
VC(\lm).v.globalControls[\distance].watch;
VC(\lm).v.globalControls[\distance].stopWatching;

VC(\lm).v.globalControls[\pan].watch;
VC(\lm).v.globalControls[\pan].stopWatching;

BP(\lsm).event.mainAmp = (-12.5.dbamp) * 3.dbamp;

q = VC(\lm).env.target.playfx(Instr("busfx.chorus"), [0, 2]); q.gui;
FxPatch(
	[ 'busfx', 'chorus' ], [ 22, 2, 0.047017811977867, 0.15505157392993, 0.0037810721153976, 1.0471975824055, 1.0 ]
)

q = VC(\lm).env.target.playfx(Instr("busfx.chorus2"), [0, 2, 2, 3]); q.gui;

p.event.putAll((glrvbamt: 0.5, lcrvbamt: 0.1));

q.synth.trace

VC(\lm).env.target.play { SinOsc.ar(440, 0, EnvGen.kr(Env.perc(0.01, 0.08), doneAction: 2)) ! 2 };

p.play;
q.run(false);
q.run(true);

BP(\qc).triggerOneEvent(0);
VC(\sp).v.nodes.detect(_.isPlaying).synth.trace;

// who has eq?
MixerChannel.servers[s].detect({ |mc| mc.fadergroup.nodeID == 18 });

p.gate = 0.3;

MultiEQ(2).edit(VC(\lm).env.target);
MultiEQ(2).edit(VC(\sp).env.target);

BP(\qc).pan = BP(\qc).pan.trace(prefix: "pan: ");

BP(\qc).pan = Pseq([
		Pfuncn({ |ev| (-1.0, (ev[\freq].size - 1).reciprocal - 1 .. 1.0).scramble }),
		Pwhite(0.5, 1.0, inf) * Pseq(#[-1, 1], inf, { 2.rand })
	], 1);
