MIDIPort.init(#[3]);

BP.loadGui;

MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

(Document.current.path.dirname.dirname +/+ "common/common-defs.scd").loadPath;
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
