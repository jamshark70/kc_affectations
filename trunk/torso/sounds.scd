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
~cRvbMc => MCG(4);

PeakMonitor(m);
PeakMonitor(n);
PeakMonitor(~master);
PeakMonitor(~glrvbmc);


[~glrvb, ~lcrvb].do(_.run(false)); [~glrvbmc, ~lcrvbmc].do(_.mute(true));
[~glrvb, ~lcrvb].do(_.run(true)); [~glrvbmc, ~lcrvbmc].do(_.mute(false));

~cavernousRvb.run(false); ~cRvbMc.mute(true);
~cavernousRvb.run(true); ~cRvbMc.mute(false);

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
	defaultCarDetune: 1.0066,
	defaultDetune: 2.234,
	car_amps: Array.squareAmps(5),
	mod_amps: Array.sawtoothAmps(5), //#[1],
	car_env: Env.adsr(0.5, 0.8, 0.75, 1.0),            
	mod_env: Env.adsr(0.01, 2.5, 0.75, 1, curve: -2.5),
	keyScale: 0.3669,
	defaultCarVs: 0.145,
	defaultModVs: 0.145,
	isMono: true,
	cRvbMc: topEnvironment[\cRvbMc],
	customize: { |v|
		~target.newPostSend(~cRvbMc, 1.2);
		v.mapGlobal(\mod_ratio, nil, 3, #[1, 10, \exp]);
		v.mapGlobal(\mod_lev, nil, 1.6, #[0.01, 15, \exp]);
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
	~alwaysReset = false;
	~continuous_ = { |bool = false|
		~continuous = ~alwaysReset = bool;
		currentEnvironment
	};		

	~prep = {
		~event.proto_(topEnvironment[\rvbEvent].proto.copy.putAll((distNear: 5, distFar: 50)));
		~reset.();
	};

	~rewriteProb = 0.3;
	~rewriteLevel = Pwhite(1, 3, inf); // Pseq([1, 2, Pwhite(1, 3, inf)], 1);
	~phraseIndex = Pfunc { ~phrases.size.rand };
	~phrases = [
		#[7, 8],
		#[7, 4, 5, 7, 8],
		#[7, 5, 7, 6],
		#[7, 4, 2, 5, 6]
	];
	~octOffset = 35;
	~mode = \d;
	~dur = Pexprand(1.2, 3.0, inf);
	~amp = 0.3;
	~frlagProp = Pwhite(0.5, 0.8, inf);
	~freqlag = Plazy({ Pfunc({ |ev| ev[\note].length }) * BPStream(\frlagProp) });
	~gate = 0.2;
	~rest = 3;

	~asPattern = {
		var	phr;
		~makeStreams.();
		Pseq([
			Plazy({ |ev|
				if((phr = ~makePhrase.(ev)).notNil) { phr }
					{ BP(~collIndex).stop(0); nil }  // force stop
			}),
			Plazy({ |ev|
				if(~continuous) {
					// currentEnvironment.listVars;
					Pn((note: SequenceNote(#[], ~restStream.next(ev), 1, 1)), 1)
					// (freq: #[], delta: ~restStream.next(ev))
					// Event.silent(~restStream.next(ev))
				} {
					BP(~collIndex).stop(0); nil
				}
			})
		], inf)/*.collect { |ev|
			ev.tryPerform(\at, \note).postcs;
			ev
		}*/
	};

	~makePhrase = { |ev|
		// one buslock per phrase; need to know total dur in advance
		var	phrI = ~phraseIndexStream.next,
			notes, durs, lock,
			once = true;
		if(phrI.notNil) {
			lock = PR(\busLock).copy.prep((numCh: 2, rate: \control));
			notes = \patRejectLastN.eval(~rewriters[phrI].asStream, 1).all;
			ev[\noteCount] = notes.size;
			durs = ~durStream.nextN(ev[\noteCount], ev);
			notes = [notes, durs, durs + 0.01, ~gateStream.next(ev)].asNotes;
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
	~yNear = 22;
	~yFar = 50;
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
	~randModStart = Pwhite(2.0, 4.0, inf);
	~modREnv = Pfunc { |ev| Env([~randModStartStream.next(ev), 3], #[1], \sin) };
	~envProportion = Pwhite(0.4, 0.7, inf);
	~envPat = Plazy({ Pbind(
		\instrument, BPStream(\envDef),
		\time, Pkey(\totalDur) * BPStream(\envProportion),
		\connect, 0,
		\env, BPStream(\modREnv)
	) });

	~streamKeys = #[xyPat, envPat, rewriteLevel, rest, phraseIndex, dur, randModStart, gate];
	~makeStreams = { |forceReset = false|
		~streamKeys.do { |key|
			if(forceReset or: { (key ++ "Stream").asSymbol.envirGet.isNil }) {
				~makeStreamForKey.(key)
			};
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
		~makeStreams.(true);
		~makeRewriters.();
	};
		
} => PR(\torsoMel);
)

BP(\tm).free;
PR(\torsoMel) => BP(\tm);
BP(\tm) => VC(\tmel);
0 => BP(\tm);

BP(\tm).randModStart = 3.0;
// BP(\tm).rest = 3.0;
BP(\tm).continuous = true;

BP(\tm).randModStart = Pwhite(2.0, 4.0, inf);

BP(\tm).event.put(\glrvbamt, 0.2).put(\lcrvbamt, 0.1);

p = BP(\tm);
p.gate.postcs

p.yNear = Pwhite(8.0, 14.0, inf);

p.yNear = 22;
p.yFar = 50;
p.amp = 0.15;
p.event.proto = ~rvbEvent.proto.copy.putAll((
	distNear: 5, distFar: 50//, glrvbout: 8, lcrvbout: 8
));

p.dur = Pif(0.2.asPattern.coin, Pwhite(1.5, 2.7, inf), Pexprand(0.8, 1.8, inf));

BP(\tm).dur = Pseq([
	Pwhite(1.9, 3.2, 1),
	Pswitch1([
		Pwhite(1.9, 2.6, inf),
		Pexprand(0.4, 0.7, inf),
		Pexprand(0.9, 1.4, inf)
	], Pwrand(#[0, 1, 2], #[1, 3, 5].normalizeSum, { |ev| ev[\noteCount] - 2 })),
// 	Pfin({ |ev| ev[\noteCount] - 2 },
// 		Pif(0.08.asPattern.coin, Pwhite(1.9, 3.2, inf), Pexprand(0.7, 1.5, inf))
// 	),
	Pwhite(1.9, 3.2, 1)
], inf);

p.rewriteProb = 0.7;

p.event.put(\glrvbamt, nil).put(\lcrvbamt, nil);

PeakMonitor(~cRvbMc)
PeakMonitor(VC(\tmel).env.target);
VC(\tmel).env.target.postSends[0].level = 1.2;

~cavernousRvb.synth.trace;

Instr("busfx.freeverb2").listArgs
r = VC(\tmel).env.target.playfx(Instr("busfx.freeverb2"), [0]);
r.gui;

r.free;

~lcrvb.synth.trace

p.event.distNear

Instr("busfx.chorus2").listArgs
q = VC(\tmel).env.target.playfx(Instr("busfx.chorus"), [0, 2]); q.gui;

q.run(false);
q.run(true);

FxPatch(
	[ 'busfx', 'chorus' ], [ 22, 2, 0.031797551618235, 0.1, 0.005, 1.0134169548268, 0.0 ]
)

FxPatch(
	[ 'busfx', 'chorus2' ], [ 22, 2, 2, 3, 0.035944798179937, 0.32819277562721, 0.012095071265366, 2.0268339681703, 0.41011271794916 ]
)

VC(\tmel).v.latest.synth.dependants
VC(\tmel).v.latest.synth.trace

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;

o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;


// tinkles - reuse bells?
// this is quite nice, connection to low bells
Fact(\bells) => BP(\b);
p = BP(\b);

p.lowbellfLow = Pexprand(1600, 2400, inf);
p.lowbellfHigh = Pkey(\fLow) * Pwhite(5.0, 8.0);
p.delta = Pexprand(0.12, 0.6, inf);
p.sustain = Pwhite(3.0, 7.0, inf);

p.override(\lowbellfLow, Pgeom.fromEndpoints(90, 900, 18));

20000/8

p.lowbellfHigh.postcs

// rather quiet; even 0.1 is OK
p.lowbellatten = 0.05

PeakMonitor(BP(\b).chan)

// rework Klank as effect for chord process
(
(
//keys: #[master, glrvbmc, lcrvbmc],
parentChan: nil,
longDelayMax: 8,
longDelayTime: 8,
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		event: (eventKey: \singleSynthPlayer),
		alwaysReset: true,
		chan: ~parentChan,
		longDelayMax: ~longDelayMax,
		longDelayTime: ~longDelayTime,
		isFx: true,
		// master: ~master, glrvbmc: ~glrvbmc, lcrvbmc: ~lcrvbmc,
		userprep: {
			if(~chan.isNil) {
				Error("Could not instantiate Fact(\\bellfx) -- parent mixerchannel not supplied")
				.throw;
			};
			~longDelayBuf = Buffer.allocConsecutive(~chan.outChannels, s, (~longDelayMax * s.sampleRate).nextPowerOfTwo, 1);
			~delayBus = Bus.audio(s, ~chan.outChannels);
			~attenCtl = GenericGlobalControl(\atten, nil, 0.15, #[0.01, 0.35, \exp]);
			~event.put(\chan, nil).put(\atten, ~attenCtl.asMap);
			// #[glrvbmc, lcrvbmc].do { |key|
			// 	key.envirGet.tryPerform(\receivesSignalFrom, ~chan);
			// };
			// ~event.proto = topEnvironment[\rvbEvent].proto;
			// ~event.put(\glrvbamt, 0.395).put(\lcrvbamt, 0.232);
		},
		userfree: {
			[~longDelayBuf, ~delayBus, ~attenCtl].free;
			// 	#[glrvbmc, lcrvbmc].do { |key|
			// 		key.envirGet.tryPerform(\stopsReceivingFrom, ~chan);
			// 	};
		},
		delta: Pexprand(0.12, 0.6, inf),
		sustain: Pwhite(3.0, 7.0, inf),
		preparePlay: {
			~dlySynth ?? {
				~dlySynth = SynthDef(\bufdelay2, { |inbus, outbus, buf, delaytime|
					Out.ar(outbus,
						BufDelayL.ar(buf + #[0, 1], In.ar(inbus, 2), delaytime: delaytime)
					)
				}).play(~chan.effectgroup, [
					inbus: ~chan.inbus, outbus: ~delayBus,
					buf: ~longDelayBuf, delaytime: ~longDelayTime
				], \addToHead);
			}
		},
		stopCleanup: {
			~dlySynth !? { ~dlySynth.free; ~dlySynth = nil; }
		},
		objects: { (
			lowbell: (
				def: SynthDef(\bellfx10, { |inbus, outbus, atten = 0.02, time = 9, //pan = 0,
					fLow = 80, fHigh = 240, dLow = 0.45, dHigh = 1.0,
					beaterFilt = 18000, beaterDec = 0.1,
					// chfreq = 0.6, chamt = 0.002, chdly = 0.008,
					pan = 0, panWidth = 1, panFreq = 1,
					wet = 0.8|
					var	n = 10,
						in = In.ar(inbus, 2),
						initTrig = Impulse.kr(0),
						exc = LPF.ar(in, beaterFilt)
							* Decay2.kr(initTrig, 0.01, beaterDec),
						fpoints = (0..n).linlin(0, n, fLow, fHigh),
						freqs = ({ |i| ExpRand(*fpoints[[i, i+1]]) } ! n).clump(2).flop,
						sig = freqs.collect { |farray, i|
							Klank.ar(`[
								farray,
								atten ! n,
								farray.linlin(fLow, fHigh, dLow, dHigh, \none)
							], exc[i], decayscale: time)
						}; //,
						// panFreq = Rand(0.4, 1.2);
					sig = sig.collect { |chan, i|
						Pan2.ar(chan, SinOsc.kr(panFreq, pi * i, panWidth, pan).clip(-1, 1))
					}.sum;
					// sig = 0.5 * (sig
					// 	+ DelayL.ar(sig, chamt + chdly + 0.05, SinOsc.kr(chfreq, 0, chamt, chdly)));
					// DetectSilence.ar(sig, amp: 0.001, doneAction: 2);
					sig = Limiter.ar(sig);
					Line.kr(0, 1, time, doneAction: 2);
					Out.ar(outbus, sig);  // use atten to control level
					// wet = EnvGen.kr(Env([0.001, wet, 0.001], [0.01, time], \exp),
					// 	doneAction: 2).madd(2, -1);
					// ReplaceOut.ar(outbus, XFade2.ar(in, sig, wet));
				}),
				args: [
					inbus: Pn(~delayBus, inf),
					target: Pfunc { ~dlySynth },
					bus: ~chan.inbus,
					addAction: \addAfter,
					time: BPStream(\sustain),
					// delta: Pkey(\time) * Pexprand(0.8, 1.1, inf), // + Pwhite(0.2, 1.0, inf),
					fLow: Pexprand(1600, 2400, inf),
					fHigh: Pkey(\fLow) * Pwhite(5.0, 8.0),
// 					atten: 0.1,
					beaterFilt: Pexprand(1500, 5000, inf),
					pan: 0,
					panWidth: 1
				]
			)
		) }
	));
	0 => BP(name);
}, type: \bp) => Fact(\bellfx);
)

BP(\bfx).free;
Fact(\bellfx).chuck(BP(\bfx), nil, (parentChan: VC(\wp).env.target));

p = BP(\bfx);

p.lowbellfLow = Pexprand(1600, 2400, inf);
p.lowbellfHigh = Pkey(\fLow) * Pwhite(5.0, 8.0);
p.delta = Pexprand(0.12, 0.6, inf);
p.sustain = Pwhite(3.0, 7.0, inf);

p.sustain = Pkey(\delta) * Pwhite(3.0, 7.0, inf);

p.lowbellatten = 0.25;

p.debug = true;
p.debug = false;

p.event.addAction = \addToHead;

p.dlySynth.trace

~master.startRecord;

BP(#[wc, bfx]).play(0);
p.lowbellfLow = Pexprand(1600, 2400, inf);
p.lowbellfHigh = Pkey(\fLow) * Pwhite(5.0, 8.0);
p.delta = Pexprand(0.12, 0.6, inf);
p.sustain = Pwhite(3.0, 7.0, inf);

BP(#[wc, bfx]).stop;

~master.stopRecord;

BP.all.stop;

BP(\shfx).event.chan = nil;
BP(\shfx).event.putAll((target: VC(\wp).env.ch.synth, bus: VC(\wp).env.target.inbus, addAction: \addBefore));

BP(\shfx).event.chan = VC(\wp).env.target;
BP(\shfx).event.addAction = \addToHead;

VC(\wp).env.target.postSettings



/**** TODO Steady pitches with modulation based on movement ****/
();

Instr(\innermod, { |freq = 261, amp = 0.1, ffreq = 4000, centerMul = 3, rq = 0.8,
	ringfreq = 440|
	var	sig = LPF.ar(Saw.ar(freq * #[1, 1.004]).sum, ffreq, amp),
		modsig = BPF.ar(sig, freq * centerMul, rq),
		remainder = sig - modsig;
	modsig = modsig * SinOsc.ar(ringfreq);
	/*remainder +*/ modsig
}, [\freq, \amp, \freq, #[1, 10, \exp], #[2.0, 0.5, \exp], \freq]);

Instr(\innermod, { |freq = 261, amp = 0.1, ffreq = 4000, centerMul = 3, rq = 0.8,
	fshift = 0, remainderMix = 0.5|
	var	sig = LPF.ar(Saw.ar(freq * #[1, 1.004]).sum, ffreq, amp),
		modsig = BPF.ar(sig, freq * centerMul, rq),
		remainder = sig - modsig;
	modsig = FreqShift.ar(modsig, fshift);
	(remainder * remainderMix) + modsig
}, [\freq, \amp, \freq, #[1, 10, \exp], #[2.0, 0.5, \exp], #[-150, 150]]);

// maybe ok with a non-saw wave
Instr(\innermod, { |freq = 261, amp = 0.1, ffreq = 4000, centerMul = 3, rq = 0.8,
	dly = 0.005, dlyFreq = 10, decay = 0, remainderMix = 0.5|
	var	sig = LPF.ar(Saw.ar(freq * #[1, 1.004]).sum, ffreq, amp),
		modsig = BPF.ar(sig, freq * centerMul, rq),
		remainder = sig - modsig;
	dly = dly * 0.5;
	modsig = modsig + AllpassC.ar(modsig, 0.2, SinOsc.ar(dlyFreq, 0, dly, dly), decay);
	(remainder * remainderMix) + modsig
}, [\freq, \amp, \freq, #[1, 10, \exp], #[2.0, 0.5, \exp], #[0.00001, 0.1, \exp], #[0.1, 100, \exp], #[0.0001, 3, \exp], nil]);


a = m.play(Instr(\innermod)); a.gui;

a.synth.trace

s.bufferAllocator.debug
(0..9).do { |i| s.sendMsg(\b_free, i) };
s.bufferAllocator.free(0)

// screw it, I'm not finding the right transfer funcs
b.free;
b = Buffer.allocConsecutive(10, s, 1024, 1, { |buf, i|
	var	partials = (2, 4 .. 14+(i*2)), //.scramble[ .. rrand(8, 14)],
		amps = (0 ! 33).putEach(partials, { rrand(0.5, 1.0) } ! partials.size);
	buf.chebyMsg(amps);
});


b.free;
b = Buffer.allocConsecutive(10, s, 1024, 1, { |buf|
	var	partials = (2, 4 .. 32).scramble[ .. rrand(8, 14)],
		amps = (0 ! 33).putEach(partials, { rrand(0.5, 1.0) } ! partials.size),
		transfer = Signal.sineFill(512, amps),
		line = Signal.chebyFill(512, #[1]);
	transfer = transfer * (1 - line.abs) + line;
	// buf.sine1Msg(amps);
	buf.setnMsg(0, transfer.asWavetable)
});


b.choose.plotWavetable;


Instr(\innermod, { |freq = 261, amp = 0.1, ffreq = 4000, centerMul = 3, rq = 0.8,
	baseBuf = 0, shaperIndex = 0, shapeMix = 0.5, remainderMix = 0.5|
	var	sig = LPF.ar(Saw.ar(freq * #[1, 1.004]).sum, ffreq, amp),
		modsig = BPF.ar(sig, freq * centerMul, rq),
		remainder = sig - modsig,
		isOdd = shaperIndex.wrap(0, 2).trunc,
		shaperIndexInt = shaperIndex.trunc,
		frac = (shaperIndex - shaperIndex.trunc(2)).fold(0, 1),
		// indexby2 = shaperIndex.fold(0, 2),
		// by2by2 = indexby2.trunc(2),
		// frac = (indexby2 - by2by2).fold(0, 1),
		shapers = Shaper.ar(baseBuf + shaperIndexInt + [isOdd, 1-isOdd], modsig),
		modded = XFade2.ar(shapers[0], shapers[1], frac.madd(2, -1));
	modsig = XFade2.ar(modsig, modded, shapeMix.madd(2, -1));
	(remainder * remainderMix) + modsig
}, [\freq, \amp, \freq, #[1, 10, \exp], #[2.0, 0.5, \exp], \mybuf, \mybuf, nil, nil]);

a = m.play(Instr(\innermod), (nil ! 5) ++ [b.first.bufnum, KrNumberEditor(0, [0, b.size - 1.001])]); a.gui;

a.synth.trace

// more promising
// make speeds modulatable
Instr(\innermod, { |freq = 261, amp = 0.1, ffreq = 4000,
	numbands = 10, centerMul = 25, rq = 0.04, speedMul = 1,
	fshift = 0, modMix = 1, remainderMix = 0.5|
	var	sig = LPF.ar(Saw.ar(freq * #[1, 1.004]).sum, ffreq, amp),
		lfnoises = LFDNoise3.kr(({ Rand(0.2, 12) } ! numbands) * speedMul),
		bpfreqs = lfnoises.exprange(freq, freq*centerMul.clip(20, 20000)),
		modsig = BPF.ar(sig, bpfreqs, rq),
		modsigsum = modsig.sum,
		remainder = sig - modsigsum,
		fshifts = lfnoises.scramble * fshift,
		modded = FreqShift.ar(modsig, fshifts).sum;
		modsig = XFade2.ar(modsigsum, modded, modMix.madd(2, -1));
	(remainder * remainderMix) + modsig
}, [\freq, \amp, \freq, StaticSpec(1, 20, \lin, 1), #[1, 50, \exp], #[2.0, 0.01, \exp], #[0.001, 2, \exp], #[-150, 150], nil, nil]);

a = m.play(Instr(\innermod)); a.gui;

a.synth.trace

PeakMonitor(m);

Instr("busfx.innermod1", { | /*bus,*/ inbus, numChan = 1,
	numbands = 10, freq = 261, centerMul = 25, rq = 0.04, speedMul = 1,
	fshift = 0, modMix = 1, remainderMix = 0.5|
	var	sig = In.ar(inbus, numChan).asArray,
		lfnoises = LFDNoise3.kr(({ Rand(0.2, 12) } ! numbands) * speedMul),
		bpfreqs = lfnoises.exprange(freq, freq*centerMul.clip(20, 20000)),
		modsig = sig.collect { |chan| BPF.ar(chan, bpfreqs, rq) },
		modsigsum = modsig.flop.sum,
		remainder = sig - modsigsum,
		fshifts = lfnoises.scramble * fshift,
		modded = modsig.collect { |chan| FreqShift.ar(chan, fshifts).sum };
		modsig = XFade2.ar(modsigsum, modded, modMix.madd(2, -1));
	(remainder * remainderMix) + modsig
}, [/*\audiobus,*/ \audiobus, StaticSpec(1, 8, \lin, 1), StaticSpec(1, 20, \lin, 1), \freq, #[1, 50, \exp], #[2.0, 0.01, \exp], #[0.001, 2, \exp], #[-150, 150], nil, nil]);


Instr("busfx.innermod1pan", { | /*bus,*/ inbus, numChan = 1,
	numbands = 10, freq = 261, centerMul = 25, rq = 0.04, speedMul = 1,
	fshift = 0, modMix = 1, remainderMix = 0.5, pan = 0|
	var	sig = In.ar(inbus, numChan).asArray,
		lfnoises = LFDNoise3.kr(({ Rand(0.2, 12) } ! numbands) * speedMul),
		bpfreqs = lfnoises.exprange(freq, freq*centerMul.clip(20, 20000)),
		modsig = sig.collect { |chan| BPF.ar(chan, bpfreqs, rq) },
		modsigsum = modsig.flop.sum,
		remainder = sig - modsigsum,
		fshifts = lfnoises.scramble * fshift,
		modded = modsig.collect { |chan| FreqShift.ar(chan, fshifts).sum };
		modsig = XFade2.ar(modsigsum, modded, modMix.madd(2, -1));
	sig = (remainder * remainderMix) + modsig;
	if(sig.size == 1) { sig = sig[0] };
	Pan2.ar(sig, pan);
}, [/*\audiobus,*/ \audiobus, StaticSpec(1, 8, \lin, 1), StaticSpec(1, 20, \lin, 1), \freq, #[1, 50, \exp], #[2.0, 0.01, \exp], #[0.001, 2, \exp], #[-150, 150], nil, nil, \bipolar]);

Pan2.ar(SinOsc.ar, 0).debug("OK");
Pan2.ar([SinOsc.ar], 0).debug("equivalent graph but different result");

Out.ar(0, Pan2.ar([SinOsc.ar], 0))

Instr("busfx.innermod1").listArgs;

// maybe... wtpad is not compatible here
\addRvbOut.eval(\innermod1, { |outbus, freq = 261, centerMul = 25, rq = 0.04, speedMul = 1, fshift = 0, modMix = 1, remainderMix = 0.5, pan = 0|
	var	sig = Instr("busfx.innermod1").valueArray([outbus, 1, 6, freq, centerMul, rq, speedMul, fshift, modMix, remainderMix]);
	Pan2.ar(sig, pan)
}).add;

d = Patch("busfx.innermod1", [/*nil,*/ nil, 2, 4]/*, outClass: ReplaceOut*/).asSynthDef;
d.add;

Error.debug = true;
Error.debug = false;


d.inspect

Fact(\wtpadnofx) => VC(\wtp);
VC(\wtp) => VP(0);

SynthDescLib.at(VC(\wtp).v.nodes[0].defname.asSymbol).msgFuncKeepGate = true;

VC(\wtp).env.target.postSettings

e = (
	instrument: VC(\wtp).v.nodes[0].defname,
	chan: VC(\wtp).v.bus.asMixer,
	bufbase: VC(\wtp).env.wt.first.first.bufnum,
	ffreq: 4000,
	freq: 440,
	gate: 1,
	sustain: 3,
	lpcEv: (
		instrument: d.name,
		remainderMix: 0.25,
		fshift: 140,
		// pan: -0.5,
		killNode: true
	)
).parent_(ProtoEvent(\polySynthBusLock).v.parent).play;

e.lpcEv.node.trace

s.sendMsg(\n_trace, 1011);
s.sendMsg(\n_free, 1013, 1014);
s.sendMsg(\n_free, 1018, 1016);

s.audioBusAllocator.debug;
MixerChannel.servers[s].keys

s.audioBusAllocator.free(26);


p = Pwhile1({ |ev, next| next.delta > 0.05 }, PR(\psetp2).copy.prep(
	Pbind(
		\top, Pvbrown(40, 52, Pwhite(1, 3, inf), inf),
		\lock, Pfunc { PR(\busLock).copy.prep((numCh: 2, rate: \audio)) },
		\chan, VC(\wtp).v.bus.asMixer,
		\bufbase, VC(\wtp).env.wt.first.first.bufnum,
		\autoFreeIfNoNode, false,
		\addAction, \addToHead,
		\lpcEv, (
			instrument: d.name,
			remainderMix: 0.25,
			fshift: 140,
			// pan: -0.5,
			killNode: true
		)
	),
	Pseq([
		Pbind(
			\instrument, VC(\wtp).v.nodes[0].defname,
			\ffreq, 4000,
			\freq, (Pkey(\top) - Pseries(0, Pwhite(1, 3, { rrand(4, 7) })))
				.collect { |deg| Mode(\d).cps(deg) },
			\gate, 0.6,
			\delta, Pwhite(0.5, 1.5, inf),
			\sustain, 4.5,
			\lpcProto, Pif(Pseries(0, 1, inf) > 0, \dummy, \singleSynthPlayer)
		),
		Pbind(
			\instrument, \rest,
			\delta, Pwhite(5.0, 8.0, 1)
		)
	], 1)
).outerOverridesInner_(false));

// p.outerOverridesInner = false;

q = p.asStream;
e = q.next(());

e.parent_(ProtoEvent(\polySynthBusLock).v.parent).play;

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;

q = p.asPattern.play(protoEvent: ProtoEvent(\polySynthBusLock).copy);

s.audioBusAllocator.debug;

(26..36).do({ |i| s.audioBusAllocator.free(i) });

q = p.asPattern.asEventStreamPlayer(ProtoEvent(\polySynthBusLock).copy);
u.remove;
u = Updater(q, { |... args| args.debug("update") });

q.play; q.dump;
q.stop;

(1005..1015).do(s.sendMsg(\n_free, _));

q.inspect

/**** TODO Stephen's solo [0/2] ****/
/***** TODO Hopping movement *****/
/***** TODO Arm raising *****/
/**** TODO Energy exchanges ****/
/**** TODO Rework past inversion material ****/
/**** TODO Poses/changing places ****/
/**** TODO Ilana's solo - probably mostly inner-modulation sounds ****/
/**** TODO S&L duet - maybe tinkly things growing into inner-mods ****/
