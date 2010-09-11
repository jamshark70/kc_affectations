// sounds for torso


MIDIPort.init([2]);
MIDIPort.autoFreeSockets = false;

s.options.preferredDeviceFunc_(nil).device_("Aggregate Device");

BP.loadGui;

MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

(Document.current.path.dirname.dirname +/+ "common/common-defs.scd").loadPath;
(Document.current.path.dirname +/+ "torso-defs.scd").loadPath;

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


[~glrvb, ~lcrvb].do(_.run(false)); [~glrvbmc, ~lcrvbmc].do(_.mute(true));
[~glrvb, ~lcrvb].do(_.run(true)); [~glrvbmc, ~lcrvbmc].do(_.mute(false));


VoicerProxy.new => VP.prNew(0);
4.do { VP(0).v.addControlProxy(VoicerGCProxy(nil, VP(0).v), addAlways: true) };
VP(0).v.gui;



// bells
a = m.play {
	var	n = 10,
		exc = LPF.ar(PinkNoise.ar, 2500)
			* Decay2.kr(Impulse.kr(0), 0.01, 0.1),
		fspec = #[80, 240, \exp].asSpec,
		freqs = { |i| ExpRand(*fspec.map([i, i+1] / n)) } ! n,
		sig = Klank.ar(`[
			freqs,
			1 ! n,
			freqs.linlin(80, 240, 4.0, 9.0, \none)
		], exc) / 50;
	Peak.ar(sig).poll(TDelay.ar(Impulse.ar(0), 0.05));
	DetectSilence.ar(sig, amp: 0.001, doneAction: 2);
	Limiter.ar(sig)
};

a.free;

f = { |n = 10|
	SynthDef(("bell" ++ n).asSymbol, { |outbus, atten = 0.02, time = 9, pan = 0,
		fLow = 80, fHigh = 240, dLow = 0.45, dHigh = 1.0,
		beaterFilt = 2500, beaterDec = 0.1,
		chfreq = 0.6, chamt = 0.002, chdly = 0.008|
		var	//n = 10,
			exc = LPF.ar(PinkNoise.ar, beaterFilt)
				* Decay2.kr(Impulse.kr(0), 0.01, beaterDec),
			fpoints = (0..n).linlin(0, n, fLow, fHigh),
			freqs = ({ |i| ExpRand(*fpoints[[i, i+1]]) } ! n).clump(2).flop,
			sig = freqs.collect { |farray|
				Klank.ar(`[
					farray,
					atten ! n,
					farray.linlin(fLow, fHigh, dLow, dHigh, \none)
				], exc, decayscale: time)
			},
			panFreq = Rand(0.4, 1.2);
//		Peak.ar(sig).poll(TDelay.ar(Impulse.ar(0), 0.05));
		sig = sig.collect { |chan, i|
			Pan2.ar(chan, SinOsc.kr(panFreq, pi * i))
		}.sum;
		sig = 0.5 * (sig
			+ DelayL.ar(sig, chamt + chdly + 0.05, SinOsc.kr(chfreq, 0, chamt, chdly)));
		DetectSilence.ar(sig, amp: 0.001, doneAction: 2);
		sig = Limiter.ar(sig);
//		sig = Pan2.ar(sig, pan);
		Out.ar(outbus, sig);
	}).add
};

f.(10);

SynthDescLib.at(\bell10).controls.do(_.postln); ""

\addRvbOut.eval(\dbell10, SynthDescLib.at(\bell10).def.func).add;

a = m.play(\bell10, [time: 15]);

g = { |i|
	GenericGlobalControl(i.asSymbol, nil, #[0.075, 0.035][i], #[0.001, 0.75, exp]);
} ! 2;

w = ResizeFlowWindow("test", Rect(900, 100, 400, 400));
["glrvb", "lcrvb"].do { |str, i|
	StaticText(w, 100@20).string_(str).align_(\right);
	g[i].gui(w);
	w.startRow;
};
w.recursiveResize.front;


p = n.play(Pbind(
	\instrument, \dbell10,
	\time, Pwhite(9.0, 18.0, inf),
	\delta, Pkey(\time) * Pexprand(0.8, 1.1, inf), // + Pwhite(0.2, 1.0, inf),
	\fLow, Pexprand(40, 70, inf), //Pwhite(40, 75).midicps,
	\fHigh, Pkey(\fLow) * Pwhite(4.0, 11.0, inf),
	\beaterFilt, Pexprand(1500, 5000, inf),
	\atten, 0.025,
	\distance, Pwhite(5.0, 20.0, inf).trace(prefix: "dist: "),
	\chfreq, Pwhite(0.3, 0.8, inf),
	#[glrvbamt, lcrvbamt], #[0.395, 0.232] //,
	// #[glrvbamt, lcrvbamt], g.collect(_.asMap)
), (protoEvent: ().proto_(~rvbEvent.proto)));

p.stop;

p.event = (p.event.copy[\atten] = 0.1);


o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;

o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;

a = m.play { SinOsc.ar(XLine.kr(200, 40, 12), 0, 0.2) };
a.free;

(
BP(\b).free;
PR(\basicSynthChooser).chuck(BP(\b), nil, (
	event: (eventKey: \singleSynthPlayer),
	master: ~master, glrvbmc: ~glrvbmc, lcrvbmc: ~lcrvbmc,
	userprep: {
		#[glrvbmc, lcrvbmc].do { |key|
			key.envirGet.tryPerform(\receivesSignalFrom, ~chan);
		};
		~event.proto = topEnvironment[\rvbEvent].proto;
		~event.put(\glrvbamt, 0.395).put(\lcrvbamt, 0.232);
	},
	userfree: {
		#[glrvbmc, lcrvbmc].do { |key|
			key.envirGet.tryPerform(\stopsReceivingFrom, ~chan);
		};
	},
	sustain: Pwhite(9.0, 18.0, inf),
	delta: Pif(Pwhite(0.0, 1.0, inf) < 0.2, Pwhite(1.5, 4.0, inf), Pwhite(10.0, 16.0, inf)),
	objects: { (
		lowbell: (
			def: \addRvbOut.eval(\dbell10, { |outbus, atten = 0.02, time = 9, //pan = 0,
				fLow = 80, fHigh = 240, dLow = 0.45, dHigh = 1.0,
				beaterFilt = 2500, beaterDec = 0.1,
				chfreq = 0.6, chamt = 0.002, chdly = 0.008,
				pan = 0, panWidth = 1, panFreq = 1|
				var	n = 10,
					exc = LPF.ar(PinkNoise.ar, beaterFilt)
						* Decay2.kr(Impulse.kr(0), 0.01, beaterDec),
					fpoints = (0..n).linlin(0, n, fLow, fHigh),
					freqs = ({ |i| ExpRand(*fpoints[[i, i+1]]) } ! n).clump(2).flop,
					sig = freqs.collect { |farray|
						Klank.ar(`[
							farray,
							atten ! n,
							farray.linlin(fLow, fHigh, dLow, dHigh, \none)
						], exc, decayscale: time)
					}; //,
					// panFreq = Rand(0.4, 1.2);
				sig = sig.collect { |chan, i|
					Pan2.ar(chan, SinOsc.kr(panFreq, pi * i, panWidth, pan).clip(-1, 1))
				}.sum;
				sig = 0.5 * (sig
					+ DelayL.ar(sig, chamt + chdly + 0.05, SinOsc.kr(chfreq, 0, chamt, chdly)));
				DetectSilence.ar(sig, amp: 0.001, doneAction: 2);
				sig = Limiter.ar(sig);
				Out.ar(outbus, sig);
			}),
			args: [
				time: BPStream(\sustain),
				// delta: Pkey(\time) * Pexprand(0.8, 1.1, inf), // + Pwhite(0.2, 1.0, inf),
				fLow: Pexprand(40, 70, inf), //Pwhite(40, 75).midicps,
				fHigh: Pkey(\fLow) * Pwhite(4.0, 11.0, inf),
				beaterFilt: Pexprand(1500, 5000, inf),
				atten: 0.025,
				distance: Pwhite(5.0, 20.0, inf),
				pan: Pif(Pkey(\fLow) >= 120, Pwhite(-1.0, 1.0, inf), 0),
				panWidth: 1,
				chfreq: Pwhite(0.3, 0.8, inf)
			]
		)
	) }
));
0 => BP(\b);
)

p = BP(\b);
p.lowbellfLow = Pif(Pkey(\delta) < 5, Pexprand(120, 300, inf), Pexprand(40, 70, inf));

p.delta = Pif(Pwhite(0.0, 1.0, inf) < 0.5, Pwhite(1.5, 4.0, inf), Pwhite(10.0, 16.0, inf));

p.delta = Pseq([Pwhite(1.2, 2.5, { rrand(3, 8) }), Pwhite(10.0, 16.0, { rrand(1, 3) })], inf);

p.delta = Pseq([
	Plazy({
		var	last = rrand(0.9, 1.2);
		Pgeom.fromEndpoints(rrand(1.8, 2.6), last, rrand(4, 9)) ++ Pn(last*0.5, 1)
	}),
	Pwhite(10.0, 16.0, 1)
], inf);


// washes - feet pad didn't make the cut there, try to reuse here
// pad is reusable, maybe change wavetables and rethink fx

(
(
keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	var out;

	WrapInstr([\osc2, \vosc3map2], { |freq, bufbase, numbufs, basefreq, topfreq, gate, freqmul = 1|
		var	baselog = log2(basefreq),
			newfreq = freq * freqmul,
			freqmap = ((log2(newfreq) - baselog) / (log2(topfreq) - baselog)
				* (numbufs - 1)).clip(0, numbufs - 1.001);
		WrapInstr.wrap([\osc2, \vosc3], [newfreq, gate, bufbase, freqmap]);
	}, [\freq, [0, 1000, \linear, 1, 0], [0, 20, \lin, 1, 0], \freq, \freq, NoLagControlSpec(0, 1), #[0.5, 2, \exp, 0, 1]]);
	
	WrapInstr("osc2.vosc3mapfiltenv", { |gate = 1, ffreq, rq, fenv, fenv_sens, fenv_vsens, fenv_tscale = 1, pan = 0|
		var	sig = WrapInstr.wrap("osc2.vosc3map2", (nil ! 5) ++ [gate]),
			glatch = Latch.kr(gate, gate),
			feg = EnvGen.kr(fenv, gate, timeScale: fenv_tscale);
		feg = (feg - 1) * Sensitivity.kr(1, glatch, fenv_vsens) * fenv_sens + 1;
		sig = RLPF.ar(sig, (ffreq * feg).clip(20, 18000), rq);
		Pan2.ar(sig, pan)
	}, [#[0, 1], \freq, \myrq, EnvSpec(Env.one), #[0, 1], #[0, 1], #[0.1, 10, \exp]]);

	~target = MixerChannel(name, s, 2, 2, level: -27.dbamp, outbus: ~master, completionFunc: { |chan|
//		~mono2Stereo = chan.playfx('1to2');
		StaticEQ(1, \eq, 589.41, -6.457.dbamp, 1, \hishelf, 6947.785, 2.047.dbamp, 1).play(chan);
		~ch = chan.playfx(Instr("busfx.chorus2"), #[0, 2, 2, 3, 0.0040240867741694, 0.11364637357074, 0.0036090192987437, 1.1344639929904, 0.72629173909809]);
		~ch.doWhenPlaying { ~ch.synth.moveToTail(chan.effectgroup) };
		// spatialization strategy isn't compatible with channel fx
		chan.newPostSend(~glrvbmc, 0.21);
		chan.newPostSend(~lcrvbmc, 0.98);  // rather soupy but sounds ok
	});

	~wt = #[squareAmps, sawtoothAmps].collect { |selector|
		\makeWavetables.eval(8, s, 2048, nil, { |nh|
			var	a = Array.perform(selector, nh), i = (0, 2 .. a.size-1).scramble;
			i.keep((i.size * rrand(0.1, 0.2)).asInteger).do { |ind| a[ind] = 0 };
			a
		});
	};
	out = Voicer(16, WrapInstr("osc2.vosc3mapfiltenv"), [bufbase: ~wt.first.first.bufnum, numbufs: `(~wt.first.size), basefreq: `(48.midicps), topfreq: `(127.midicps), env: Env.adsr(1.6, 0.8, 0.6, 2.5), fenv: Env(#[1, 40, 1], #[3.5, 4.0].normalizeSum, \sin), fenv_tscale: (3.5+4.0), detune: 1.003, /* ffreq: 900,*/ fenv_sens: 0.8, fenv_vsens: 1, vsens: 0.2], target: ~target);
// 	out.mapGlobal(\ffreq, nil, 400, \freq);
// 	out.mapGlobal(\rq, nil, 1, \myrq);
	out.mapGlobal(\clevel, nil, 1, \amp);
	out.mapGlobal(\density, nil, 0.8, #[0.5, 3.0]);
	out.mapGlobal(\freqmul, nil, 1, #[0.5, 2.0, exp], allowGUI: false);
	out
},
free: {
	[~target, ~wt].free
},
type: \vc) => Fact(\wtpadnofx);
)


Fact(\wtpadnofx) => VC(\wp);
VC(\wp) => VP(0);

SynthDescLib.at(VC(\wp).v.nodes[0].defname.asSymbol).msgFuncKeepGate = true;
SynthDescLib.at(VC(\wp).v.nodes[0].defname.asSymbol).msgFunc.postcs

VC(\wp).env.wt

();
p = Pbind(
	\type, \voicerNote,
	\voicer, VC(\wp).v,
	\degree, Pwhite(0, 7, inf),
	\octave, 5 + Pwrand(#[-1, 0, 1, 2], #[1, 3, 3, 2].normalizeSum, inf),
	\delta, Pexprand(0.5, 1.2, inf),
	\legato, Pwhite(3.0, 6.0, inf),
	\fenv_tscale, Pkey(\delta) * Pkey(\legato),
	// \gate, Pwhite(0.1, 0.8, inf),
	\bufbase, Pstutter(Pwhite(5, 12, inf), Pseq(VC(\wp).env.wt.flop[0], inf)),
	\angle, Ptime().neg * 2pi / 15 - 0.5pi,  // 15sec cycle
	\pan, cos(Pkey(\angle)),
	\gate, sin(Pkey(\angle)).linlin(-1, 1, 0.9, 0.1),
	\vsens, 0.5
).play;

p.stop;
VC(\wp).env.stopfx;

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;

o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;



VC(\wp).env.playfx;
VC(\wp).env.fx.trace

u = VC(\wp).env.levelSync;
u.remove;


Fact(\waterch) => BP(\wc);
BP(\wc) => VC(\wp);
0 => BP(\wc);

p = BP(\wc);
p.child.argPairs = [fenv_tscale: Pkey(\length)];

VC(\wp).v.trace

Proto {
	~asWarp = { currentEnvironment };
	~array = [0.0, 1.0];  // linear
	~map = { |value| ~array.blendAt(value * (~array.size-1)) };
	~unmap = { |value| ~array.indexInBetween(value) / (~array.size-1) };
	~asSpecifier = 'Custom';
} => PR(\arrayWarp);

w = PR(\arrayWarp).copy;
w.map(0.75)
w.array = #[0, 10];

w.array = #[-400, 0, -4].asSpec.map((0, 0.02 .. 1.0))
++ #[0, 400, 4].asSpec.map((0, 0.02 .. 1.0));

w.array.plot

g = GenericGlobalControl(\shift, nil, 0, [-400, 400, PR(\arrayWarp).copy.array = #[-400, 0, -4].asSpec.map((0, 0.02 .. 1.0)) ++ #[0, 400, 4].asSpec.map((0, 0.02 .. 1.0))]);

g.gui;

q = VC(\wp).env.target.playfx { |outbus|
	var	sig = In.ar(outbus, 1);
	sig + FreqShift.ar(sig, g.kr, 0, 0.5.sqrt);
};

q.moveToHead(VC(\wp).env.target.effectgroup);

q.trace;

q.free;

g.spec = #[0, 800];
g.free;

q = VC(\wp).env.target.playfx(Instr("busfx.fshift", { |bus, numCh, freq, wet|
	var	sig = In.ar(bus, numCh),
	fx = FreqShift.ar(sig, freq);
	XFade2.ar(sig, fx, wet.madd(2, -1))
}, [\audioBus, \numChannels, #[0, 900], nil]), [0, 1]);
q.doWhenPlaying { q.synth.moveToHead(VC(\wp).env.target.effectgroup) };
q.gui;

q.synth.trace
s.sendMsg(\n_free, 1007)

// overlapping pitch shifters!
(
BP(\shfx).free;
PR(\basicSynthChooser).chuck(BP(\shfx), nil, (
	chan: VC(\wp).env.target,
	isFx: true,
	userprep: {
		~overlap = GenericGlobalControl(\overlap, nil, 0.7, #[0.7, 6.0, \exp]);
		~event = ~event.copy.put(\addAction, \addToHead);
	},
	useGui: { |vp| ~overlap => VP(vp) },
	userfree: { ~overlap.free },
	delta: Pwhite(3.0, 8.0, inf),
	sustain: Plazy { Pkey(\delta) * ~overlap },
	objects: { (
		shift: (
			def: (
				Instr("busfx.fshift", { |bus, numCh, freq1, freq2, wet1, wet2, wetProp = 0.5, time = 1|
					var	sig = In.ar(bus, numCh),
						freq = XLine.kr(freq1, freq2, time),
						fx = FreqShift.ar(sig, freq),
						weteg = EnvGen.kr(Env([wet1, wet2, wet1], [wetProp, 1-wetProp], \sin),
							timeScale: time, doneAction: 2);
					XFade2.ar(sig, fx, weteg.madd(2, -1))
				}, [\audioBus, \numChannels, #[0, 900], #[0, 900], nil, nil, nil, #[0.1, 50]]);
				Patch("busfx.fshift", [nil, 1], ReplaceOut)
			),
			args: [
				time: Pkey(\sustain),
				freq1: Pwhite(0.0, 900.0, inf),
				freq2: Pwhite(0.0, 900.0, inf),
				wet1: 0, wet2: 1,
				wetProp: Pwhite(0.2, 0.8, inf)
			]
		)
	) }
));
0 => BP(\shfx);
)

Spec.specs[\audiobus].postcs

q = BP(\shfx);
q.shiftfreq1 = Pwhite(0.0, 900.0, inf);
q.shiftfreq2 = Pwhite(0.0, 900.0, inf);


// nice that it works but maybe not this piece

WrapInstr("test.piano", { |freq, gate|
	var vel = Latch.kr(gate, gate) * 127,
		sig = MdaPiano.ar(freq, gate, vel /*, decay: 0.8, release: 0.8, hard: 0.8, velhard: 0.8, muffle: 0.8, velmuff: 0.8, velcurve: 0.8, stereo: 0.2, tune: 0.5, random: 0.1, stretch: 0.1, sustain: 0, mul: 1, add: 0*/ );
	DetectSilence.ar(sig, 0.001, doneAction: 2);
	sig
}, [\freq, NoLagControlSpec(0, 1)]);

v.free;
v = Voicer(20, WrapInstr("test.piano"), target: n);

z = v.gate(440, 2, 1.0);
z.trace;

p = Pbind(
	\type, \voicerNote,
	\voicer, v,
	// ok
	\degree, 22 - Pexprand(1, 36, inf).trunc,
	// crash
	// \degree, 7 - Pexprand(-14, 21, inf).trunc,
	\delta, Pwrand([Pn(0.125, 2), 0.25, 0.5, 0.75], #[1, 3, 2, 1].normalizeSum, inf),
	\legato, Prand(#[0.5, 0.9, 1.8], inf),
	\gate, Pexprand(0.4, 1.0, inf)
).play;

p.stop;

e = p.asStream.next(());


// fm for inharmonic -> harmonic spectra
~cb = Buffer.alloc(s, 2048, 1);
~mb = Buffer.alloc(s, 2048, 1);

~cb.sine1(#[1]);
~mb.sine1(#[1]);

Library.at(WrapInstr, \osc2).keys.asArray.sort;
WrapInstr("osc2.fm1porta").openFile;
WrapInstr("osc2.fm1porta").listArgs;

//v = MonoPortaVoicer(1, WrapInstr("osc2.fm1porta"), [car_buf: ~cb, mod_buf: ~mb, ], target: m);
v = WrapInstr("osc2.fm1porta").miditestMono(0, [car_buf: ~cb, mod_buf: ~mb, ], target: m);

v.trigger(440, 0.8);
v.globalControls[\mod_ratio].watch.automate(\ctlEnv, [connect: 0, env: Env(#[2.7, 2.0], #[8])]);
v.globalControls[\mod_ratio].autoSynth.trace;

v.releaseAll;
v.globalControls[\mod_ratio].stopWatching;

(
p = (Pfunc { |ev|
	if(ev[\autoEv][\shouldPlay]) {
		ev[\autoEv].put(\delta, 0) /*.debug("\n\nauto")*/ .yield;
	};
	ev.put(\autoEv, nil) //.debug("\nnote")
}
<>
Pbind(
	\type, \voicerNote,
	\voicer, v,
	// \reartic, 0.3.asPattern.coin,  // OMG this really works!
	\n, Pwhite(2, 5, inf),
	\rearticNext, Pseq([Pn(false, { |ev| ev[\n] }), true], inf),
	\legato, Pif(Pkey(\rearticNext), 0.9, 1.1),
	\delta, Pwhite(1.5, 2.5, inf),
	\freqlag, Pkey(\delta) * Pkey(\legato) * 0.8, // Pwhite(0.4, 0.7, inf),
	\degree, Paccumbounce(0, 14, Pwrand(#[-2, -1, 1, 2], #[1, 2, 3, 2].normalizeSum, inf), inf),
	\autoEv, Pbind(
		\type, \note,
		\instrument, \ctlEnv,
		\outbus, v.globalControls[\mod_ratio].bus,
		\connect, 0,
		\env, Pfunc { Env([rrand(0.7, 1.35), 1] * v.globalControls[\mod_ratio].value, #[1]) },
		// HACK, not right
		\time, Pkey(\delta) * Pkey(\legato) * Pkey(\n),
		\shouldPlay, Pseq([true, Pdelay(Pkey(\rearticNext), 1)], 1)
	)
)).play;
)

p.stop;
v.panic;


WrapInstr("osc2.fm2carporta", { arg freq, freqlag, gate, car_env, mod_env, mod_lev, mod_ratio,
		detune, car_detune, car_buf, mod_buf, car_vs, mod_vs, basefreq, keyscale, pan;
	var sig, mod, car_amp, mod_amp;
	freq = Lag.kr(freq, freqlag);

	// stolen from arms: 
	car_eg = Select.kr(Impulse.kr(0), [LocalIn.kr(1), 0]);
		// once envelope starts going down, attack phase is over
	hit1 = PulseCount.kr(HPZ1.kr(car_eg) < 0) > 0;
	timeScale = Select.kr(hit1, [attackTimeScale, decayTimeScale]);

	car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
	mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
		* EnvGen.kr(mod_env, gate);
	mod_lev = mod_lev * basefreq / ((keyscale * freq) + (basefreq * (1 - keyscale)));
	mod = Osc.ar(mod_buf, freq.madd(mod_ratio * [1, car_detune],
		detune * [1, -1]), 0, mod_amp * mod_lev);
	freq = freq * [1, car_detune];
	sig = Mix(Osc.ar(car_buf, freq + (mod * freq), 0, car_amp))
		* EnvGen.kr(car_env, gate, doneAction:2);
	Pan2.ar(sig, pan)
}, [\freq, \unipolar, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0.01, 300, \exponential], [1, 12, \linear, 0, 1], [-5, 5, \linear, 0, 0], \mydetune, \mybuf, \mybuf, nil, nil, \freq, [0.001, 1.0, \exp], nil]);

WrapInstr("osc2.fm2carporta").listArgs

v = WrapInstr("osc2.fm2carporta").miditestMono(0, [car_buf: ~cb, mod_buf: ~mb, car_vs: `0.8, mod_vs: `0, basefreq: `440, pan: `0, freqlag: KrNumberEditor(0.88709676265717).lag_(nil), mod_lev: 1.4667257941895, mod_ratio: 2, detune: 2.234, car_detune: 1.003, keyscale: 0.001], target: n);

v.unmapGlobal(\freqlag);

~cb.sine1(Array.squareAmps(5));
~cb.sine1(Array.sawtoothAmps(5));
~cb.sine1(#[1]);

~mb.sine1(Array.sawtoothAmps(5));
~mb.sine1(#[1]);

~cb.plotWavetable;

Signal.square(512, 5).plot

v.trace;


VC(\tmel).free;
Fact(\armsChordVC).chuck(VC(\tmel), nil, (
	defaultCarDetune: 1.005716,
	defaultDetune: 2.234,
	car_amps: Array.squareAmps(5),
	mod_amps: Array.sawtoothAmps(5), //#[1],
	car_env: Env.adsr(0.5, 0.8, 0.75, 1.0),            
	mod_env: Env.adsr(0.01, 2.5, 0.75, 1, curve: -2.5),
	keyScale: 0.3669,
	defaultCarVs: 0.145,
	defaultModVs: 0.21,
	isMono: true,
	customize: { |v|
		v.mapGlobal(\mod_ratio, nil, 3, #[1, 10, \exp]);
		v.mapGlobal(\mod_lev, nil, 3.3, #[0.01, 15, \exp]);
		// v.mapGlobal(\distance, nil, 10, #[5, 20]);
		// v.mapGlobal(\pan, nil, 0, \bipolar);
	}
));

VC(\tmel).env.cb.plotWavetable

v = VC(\tmel).v;
v.globalControls[\mod_ratio].watch;
v.globalControls[\mod_ratio].value = 3


// improved: attack speed follows gate
(
p = (Pfunc { |ev|
	var aev = ev[\autoEv];
	if(ev[\autoEv][\shouldPlay]) {
		ev[\autoEv].put(\delta, 0)/*.debug("\n\nauto")*/.yield;
	};
	ev.put(\autoEv, nil) //.debug("\nnote")
}
<>
Pbind(
	\type, \voicerNote,
	\voicer, v,
	// \reartic, 0.3.asPattern.coin,  // OMG this really works!
	\n, Pwhite(2, 5, inf),
	\rearticNext, Pseq([Pn(false, { |ev| ev[\n] }), true], inf),
	\legato, Pif(Pkey(\rearticNext), 0.9, 1.1),
	\delta, Pwhite(1.5, 2.5, inf),
	\freqlag, Pkey(\delta) * Pkey(\legato) * 0.8, // Pwhite(0.4, 0.7, inf),
	\degree, Paccumbounce(0, 14, Pwrand(#[-2, -1, 1, 2], #[1, 2, 3, 2].normalizeSum, inf), inf),
	\gate, Pclutch(Pwhite(0.2, 0.9, inf), Pdelay(Pkey(\rearticNext))),
	\attackTimeScale, Pkey(\gate).linlin(0, 1, 4, 0.4),
	\autoEv, Pbind(
		\type, \note,
		\instrument, \ctlEnv,
		\outbus, v.globalControls[\mod_ratio].bus,
		\connect, 0,
		\env, Pfunc { Env([rrand(0.7, 1.35), 1] * v.globalControls[\mod_ratio].value, #[1]) },
		// HACK, not right
		\time, Pkey(\delta) * Pkey(\legato) * Pkey(\n),
		\shouldPlay, Pseq([true, Pdelay(Pkey(\rearticNext), 1)], 1),
		\group, VC(\tmel).env.target.synthgroup,
		\addAction, \addBefore
	)
)).play(protoEvent: ().proto_(~rvbEvent.proto));
)

p.stop;
BusDict

v.trace


VC(\tmel).env.mb.sine1(Array.sawtoothAmps(5));
VC(\tmel).env.mb.sine1(#[1]);


(
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);
	~continuous = false;

	~prep = {
		~event.proto_(topEnvironment[\rvbEvent].proto);
		~reset.();
	};

	~rewriteProb = 0.3;
	~rewriteLevel = Pseq([1, 2, Pwhite(1, 3, inf)], 1);
	~phraseIndex = Pfunc { ~phrases.size.rand };
	~phrases = [
		#[7, 8],
		#[7, 5, 7, 6] 
	];
	~octOffset = 35;
	~mode = \d;
	~dur = Pexprand(1.2, 3.0, inf);
	~amp = 0.3;
	~frlagProp = Pwhite(0.5, 0.8, inf);
	~freqlag = Plazy({ Pfunc({ |ev| ev[\note].length }) * BPStream(\frlagProp) });

	~asPattern = {
		var	phr;
		// ~makeStreams.();
		Pseq([
			Plazy({ |ev|
				if((phr = ~makePhrase.(ev)).notNil) { phr }
					{ BP(~collIndex).stop(0); nil }  // force stop
			}),
			Plazy({ |ev|
				if(~continuous) {
					Event.silent(~restStream.next(ev))
				} {
					BP(~collIndex).stop(0); nil
				}
			})
		], inf)
	};

	~makePhrase = { |ev|
		// one buslock per phrase; need to know total dur in advance
		var	phrI = ~phraseIndexStream.next,
			notes, durs, lock,
			once = true;
		if(phrI.notNil) {
			lock = PR(\busLock).copy.prep((numCh: 2, rate: \control));
			notes = \patRejectLastN.eval(~rewriters[phrI].asStream, 1).all;
			durs = ~durStream.nextN(notes.size, ev);
			notes = [notes, durs, durs + 0.01, 0.5].asNotes;
			Pfunc({ |ev|
				var xyEv;
				if(once) {
					xyEv = ~xyPatStream.next(ev);
					xyEv !? {  // DON'T YIELD NIL!!!
						xyEv.put(\delta, 0)
						.put(\chan, nil)
						.put(\bus, lock/*.listVars*/.bus)
						.put(\parent, ProtoEvent(\singleSynthPlayer).v.parent)
						.yield
					};
					xyEv = ~envPatStream.next(ev);
					xyEv !? {  // DON'T YIELD NIL!!!
						xyEv.put(\delta, 0)
						.put(\chan, nil)
						.put(\bus, ev[\voicer].globalControls[\mod_ratio].bus)
						.put(\parent, ProtoEvent(\singleSynthPlayer).v.parent)
						.yield
					};
					// why? event must .play before ev[\id] is available
					thisThread.clock.sched(0.01, {
						lock.addNode(ev[\voicer].latest.synth);
						nil
					});
					once = false;
				};
				ev
			})
			<>
			Pbind(
				\note, Pseq(notes, 1) + BPStream(\octOffset),
				\mode, BPStream(\mode),
				\totalDur, durs.sum,
				\freqlag, BPStream(\freqlag),
				#[pan, distance], (lock.bus.index + #[0, 1]).collect { |i| ("c" ++ i).asSymbol },
				\finalAmp, BPStream(\amp)
			)
		};  // else returns nil, stopping the process
	};

	~pan1 = Pwhite(0.6, 1.0, inf) * Prand(#[-1, 1], inf);
	~pan2 = Pkey(\x1).neg;
	~yNear = 5;
	~yFar = 20;
	~xyProportion = Pwhite(0.6, 0.9, inf);
	~xyDef = \xylin;

	~xyPat = Plazy({ Pbind(
		\instrument, BPStream(\xyDef),
		// CHANGE ME!
		\sustain, Pkey(\totalDur) * BPStream(\xyProportion),
		\x1, BPStream(\pan1),
		\x2, BPStream(\pan2),
		\y1, BPStream(\yNear),
		\y2, BPStream(\yFar)
	) });

	~envDef = \ctlEnv;
	~modREnv = Pfunc { Env([rrand(2.0, 4.0), 3], #[1], \sin) };
	~envPat = Plazy({ Pbind(
		\instrument, BPStream(\envDef),
		// CHANGE ME!
		\time, Pkey(\totalDur) * BPStream(\xyProportion),
		\connect, 0,
		\env, BPStream(\modREnv)
	) });

	~streamKeys = #[xyPat, envPat, rewriteLevel, rest, phraseIndex, dur];
	~makeStreams = {
		~streamKeys.do { |key|
			(key ++ "Stream").asSymbol.envirGet ?? { ~makeStreamForKey.(key) };
		}
	};

	~makeRewriters = {
		var	self = currentEnvironment, rew;
		~rewriters = ~phrases.collect { |row|
			rew = PR(\rewriter).copy.prep(Pseq(row, 1), Pfuncn(e { ~rewriteLevelStream.next }, 1), [
				(_.notNil) -> { |item, level, inval|
					// self: this runs inside the rewriter Proto object
					if(self[\rewriteProb].coin) {
						item + [0, rrand(1, 3) * #[-1, 1].choose].rotate(2.rand)
					} { [item] }
				}
			]).keepLowerLevels_(true);
		};
	};

	~reset = {
		~makeStreams.();
		~makeRewriters.();
	};
		
} => PR(\torsoMel);
)

BP(\tm).free;
PR(\torsoMel) => BP(\tm);
BP(\tm) => VC(\tmel);
0 => BP(\tm);

BP(\tm).event.put(\glrvbamt, 0.2).put(\lcrvbamt, 0.1);

VC(\tmel).v.latest.synth.dependants

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;

o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;
