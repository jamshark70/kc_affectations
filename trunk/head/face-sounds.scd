// synth play for face dance

MIDIPort.init([2]);
MIDIPort.autoFreeSockets = false;

MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

(Document.current.path.dirname.dirname +/+ "common/common-defs.scd").loadPath;

(Document.current.path.dirname +/+ "head-defs.scd").loadPath;
topEnvironment[\dir] = Document.current.path.dirname.dirname +/+ "samples/feet";

m = MixerChannel(\test1, s, 1, 2/*, level: 0.1*/);
n = MixerChannel(\test2, s, 2, 2/*, level: 0.1*/);
m => MCG(0); n => MCG(1);

[m, n].do { |mx|
	mx.outbus = ~master;
	mx.sendsSignalTo(~glrvbmc);
	mx.sendsSignalTo(~lcrvbmc);
};

~master => MCG(7);

PeakMonitor(m);
PeakMonitor(n);
PeakMonitor(~master);
PeakMonitor(~glrvbmc);


[~glrvb, ~lcrvb].do(_.run(false));
[~glrvb, ~lcrvb].do(_.run(true));


// Bloops

// too harsh
a = m.play {
	var	freq = XLine.kr(50, 900, 1, doneAction: 2),
		wMod = Line.kr(0.1, 0.45, 1),
		sig = Pulse.ar(freq, wMod);
	LPF.ar(sig, XLine.kr(14000, 1200, 1))
};

a.free;

a = m.play(Instr("test2", { |freq = 200, preAmp = 1/*, postAmp = 1*/|
	var //freq = XLine.kr(50, 900, 1, doneAction: 2),
		sig = SinOsc.ar(freq, 0, preAmp),
		// this is right! 
		postAmp = 0.5 / preAmp * (preAmp+1),
		dist = sig.distort * postAmp;
	dist
}, [\freq, #[0.05, 20, \exp]/*, #[0.05, 20, \exp]*/]));
a.gui;

o.remove;
o = OSCresponderNode(s.addr, '/amps', { |t, r, m| m[3..].postln }).add;

a = m.play {
	var	freq = XLine.kr(50, 900, 1, doneAction: 2),
		preAmp = Line.kr(0.3, 15.0, 1),
		postAmp = 0.5 / preAmp * (preAmp+1);
	SinOsc.ar(freq, 0, preAmp).distort * postAmp
};

d = \addRvbOut.eval(\dsinbloop, { |freq1 = 50, freq2 = 900, fcurve = 0, time = 1, fHoldPct = 0,
	amp1 = 1, amp2 = 1, noiseBlend = 0.1, noiseFmul = 1, noisePreamp = 1, rq = 1.0,
	normAmp = 0.5, pan1 = 0, pan2 = 0|
	var	freq = EnvGen.kr(Env([freq1, freq1, freq2], [fHoldPct, 1 - fHoldPct], fcurve),
			timeScale: time),
		preAmp = Line.kr(amp1, amp2, time),
		sig = XFade2.ar(SinOsc.ar(freq), BPF.ar(PinkNoise.ar, freq * noiseFmul, rq, noisePreamp),
			noiseBlend.madd(2, -1), preAmp),
		pan = Line.kr(pan1, pan2, time),
		postAmp = normAmp / preAmp * (preAmp+1),
		env = NamedControl.kr(\env, (0 ! 20).overWrite(Env.linen(0.01, 0.98, 0.01).asArray)),
		eg = EnvGen.kr(env, timeScale: time, doneAction: 2);
	Pan2.ar(sig.distort, pan, postAmp * eg)
}).add;

SynthDef(\oscbloop, { |outbus, bufnum, freq1 = 50, freq2 = 900, fcurve = 0, time = 1, fHoldPct = 0,
	amp1 = 1, amp2 = 1, noiseBlend = 0.1, noiseFmul = 1, noisePreamp = 1, rq = 1.0,
	normAmp = 0.5, pan1 = 0, pan2 = 0|
	var	freq = EnvGen.kr(Env([freq1, freq1, freq2], [fHoldPct, 1 - fHoldPct], fcurve),
			timeScale: time),
		preAmp = Line.kr(amp1, amp2, time),
// 		sig = XFade2.ar(COsc.ar(bufnum, freq, ExpRand(0.5, 9.0)),
// 			BPF.ar(PinkNoise.ar, freq * noiseFmul, rq, noisePreamp),
// 			noiseBlend.madd(2, -1), preAmp),
		sig = BPF.ar(COsc.ar(bufnum, freq, ExpRand(0.5, 9.0)), freq, rq, noisePreamp),
		pan = Line.kr(pan1, pan2, time),
		postAmp = normAmp / preAmp * (preAmp+1),
		env = NamedControl.kr(\env, (0 ! 20).overWrite(Env.linen(0.01, 0.98, 0.01).asArray)),
		eg = EnvGen.kr(env, timeScale: time, doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig.distort, pan, postAmp * eg));
}).add;

\addRvbOut.eval(\doscbloop, SynthDescLib.at(\oscbloop).def.func).add;

n.play(~rvbEvent.copy.putAll((
	instrument: \dsinbloop, time: 2,
	freq1: 100, freq2: 500,
	amp1: 3, amp2: 12, distance: 18, pan1: -0.8, pan2: 0.8
)));

e = n.play(~rvbEvent.copy.putAll((
	instrument: \dsinbloop, time: 2,
	freq1: 100, freq2: 500, fHoldPct: 0.8, fcurve: 2.1,
	noiseBlend: 0.1, noiseFmul: 5, noisePreamp: 20,
	amp1: 3, amp2: 12, distance: 18 //, pan1: -0.8, pan2: 0.8
)));

c = Buffer.sendCollection(s, Signal.fill(1024, { 1.0.rand2 }).asWavetable, 1, 0.05, { "done".postln });

e = n.play(~rvbEvent.copy.putAll((
	instrument: \doscbloop, time: 2, bufnum: c, normAmp: 3,
	freq1: 100, freq2: 500, fHoldPct: 0.8, fcurve: 2.1,
	noiseBlend: 0.1, noiseFmul: 5, noisePreamp: 20, rq: 0.1,
	amp1: 3, amp2: 12, distance: 18 //, pan1: -0.8, pan2: 0.8
)));

s.sendMsg(\n_trace, e[\id].first);

p = n.play(Pbind(
	\instrument, \dsinbloop,
	\delta, Pwrand(#[0.25, 0.5, 0.75], #[0.5, 0.35, 0.15], inf),
	\time, 0.2, // Pkey(\delta) * 0.8,
	\fHoldPct, Pwhite(0.2, 0.8, inf),
	\freq1, Pexprand(150, 400, inf),
	\freq2, Pkey(\freq1) * (Pwhite(1.8, 3.0, inf) pow: Prand(#[-1, 1], inf)),
	\fcurve, 2.1 * sign(Pkey(\freq2) - Pkey(\freq1)),
	\amp1, Pexprand(0.7, 1.4, inf),
	\amp2, Pkey(\amp1) * Pwhite(3.0, 7.0, inf),
	\distance, sin(Ptime() * (2pi / 10)),
	\pan1, 0,
	\pan2, 0
), (protoEvent: ~rvbEvent));

p.stop;


// Creaking (eye rolls)

g = GenericGlobalControl(\rt, nil, 0.07, #[0.05, 1, \exp]); g.gui;

// fail
a = m.play {
	var	sig = WhiteNoise.ar,
		freq = LFNoise1.kr(0.5).linexp(-1, 1, 600, 1400),
		trig = Impulse.ar(58),
		amp = EnvGen.ar(Env.perc(), gate: trig, timeScale: 12.reciprocal * 0.8);
	sig = DynKlank.ar(`[
		{ exprand(0.8, 1.25) },
		1 ! 5, g.kr ! 5
	], sig, freqscale: freq);
	Limiter.ar(sig) * amp
}.play;

a.free;



// Low buzzes, analog-y (tongue rolls in mouth)

b.free;
b = Buffer.allocConsecutive(6, s, 1024, 1, { |buf, i|
	buf.chebyMsg((0 ! (i*2+1)).put(i*2, 1).put(0, -1).postln)
});

fork {
	b.reverse.do { |buf| buf.plotWavetable; 0.5.wait }
};

m.scope

g = GenericGlobalControl(\pwidth, nil, 0.5, #[0.05, 0.5]);

p = m.play(Instr("ptest", { |freq, pwidth = 0.5, ffreqMul = 5, sbufbase, sbufi|
	var	sig = Pulse.ar(freq, pwidth),
	sb1 = sbufi.round(2),
	sbFrac2 = sbufi - sb1,
	sb2 = sb1 + sbFrac2.sign;
	sig = LPF.ar(sig, (freq * ffreqMul).clip(20, 18000));
	sig = Shaper.ar(sbufbase + [sb1, sb2], sig.clip(-1.0, 1.0));
	XFade2.ar(*(sig ++ [sbFrac2.abs.madd(2, -1)]))
}, [\freq, #[0.05, 0.5], #[2, 20, \exp], \mybuf, nil]), [nil, g, nil, b.first.bufnum, KrNumberEditor(0, [0, b.size - 1.01])]);
p.gui;

p.synth.trace

g.watch.automate { SinOsc.kr(1).range(0.05, 0.5) };
KrBusWatcher.newFrom(s).updateFreq = 6;
g.stopWatching.stopAuto;

g.dump;

// Wet, slurpy (tongue popping out -- muffle for tongue-in-mouth also)

// eq out electric hum from sample
b.free;
b = Buffer.readAndQuery(s, "~/SCServer/trax/orig-kc/slurpy-norm.aiff".standardizePath);

a = m.play { PlayBuf.ar(1, b, /*1, Impulse.kr(1.9), 519799,*/ loop: 1) };
a.free;

a.trace;

c = m.playfx(Instr("busfx.brickwall", { |bus, numCh, wipe = 0|
	var	sig = In.ar(bus, numCh),
	fft = FFT({ LocalBuf(2048, 1) } ! numCh, sig);
	fft = PV_BrickWall(fft, wipe);
	IFFT(fft)
}, [\audiobus, \numChannels, \bipolar]), [0, 1, KrNumberEditor(0.0001, #[0.0001, 0.1, \exp])]);
c.gui;

c.run(false);
c.run(true);

Instr("busfx.chorus").openFile

MultiEQ(1).edit(m);

s.freqscope;
PeakMonitor(m);

m.stopRecord;
MixerRecorder.dir = thisProcess.platform.recordingsDir;

a = LPCAna(topEnvironment[\sampleDir] +/+ "head/slurpy.aiff");
a.ana(50, 2000, 0.25);
a.saveToFiles(topEnvironment[\sampleDir] +/+ "head/slurpy.lpc");

a.pchcps;

b.free;
b = Buffer.readAndQuery(s, topEnvironment[\sampleDir] +/+ "head/slurpy.lpc.aif");
f = SoundFile.openRead(topEnvironment[\sampleDir] +/+ "head/slurpy.aiff");
c = f.numFrames;
f.close;

y = LPCFile(topEnvironment[\sampleDir] +/+ "head/slurpy.lpc");
y.pchcps;
y.loadToBuffer;
y.nrmerr.maxItem

b.getn(0, 100, _.postln);

z.free;
z = m.play { |amp = 1|
	var	freq, rms, err,
		phase = Phasor.ar(0, 1 / c, 0, 1),
		sig;
	#freq, rms, err = LPCVals.ar(y.buffer, phase);
	err = err.clip(0, 1);
 	sig = Blip.ar(freq, 100, (1 - err) * 0.4) + WhiteNoise.ar(err);
 	LPCSynth.ar(b, sig, phase, rms) * amp;
//	SinOsc.ar(freq, 0, 0.1)
}.play;

z.set(\amp, 100)

z.trace

z.free;

s.sendMsg(\n_free, 1011);

(Document.current.path.dirname.dirname +/+ "feet/feet-defs.scd").loadPath;

SynthDef(\blip, { |outbus, freq = 440, numh = 100, amp = 1, gate = 1|
	var eg = EnvGen.kr(Env.adsr, gate, doneAction: 2);
	Out.ar(outbus, Blip.ar(freq, min(20000 / freq, numh), amp))
}).add;

~lpcEv = (instrument: \simpleLPCfxPan, target: m.effectgroup, /*inbus: bus,*/ bus: m.inbus,
	lpcbuf: b, voxdur: c/44100, start: 0, end: c/44100, time: c/44100,
	hpf: 20, lpf: 6000);

e = (instrument: \blip, freq: 60.midicps * [1, 5/4, 3/2], sustain: c/44100, chan: m, parent: ProtoEvent(\polySynthBusLock).v.parent, collIndex: \dummy, lpcEv: ~lpcEv.copy, amp: 20);

g = e.copy.play;

// already in feet-defs
\addRvbOut.eval(\bufGrainPanFiltDist, { |start, time, bufnum, pan, rate = 1, amp = 1, ampMap = 1,
		attack = 0.001, decay = 0.02, outbus, ffreq = 2000|
	var sig;
	sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
		* EnvGen.kr(Env.linen(attack, time, decay), doneAction:2);
	sig = LPF.ar(sig, ffreq);
	Out.ar(outbus, Pan2.ar(sig, pan, amp * ampMap));
}).add;

// long slurp: 516826 + 165436
// fast slurps: 3276 + 488489

b = Buffer.readAndQuery(s, topEnvironment[\sampleDir] +/+ "head/slurpy.aiff");

g = [
	GenericGlobalControl(\pan, nil, 0, \bipolar),
	GenericGlobalControl(\distance, nil, 5, #[5, 20])
];

w = ResizeFlowWindow("test", Rect(900, 100, 350, 300));
g.do { |gc|
	StaticText(w, 120@20).string_(gc.name).align_(\right);
	gc.gui(w);
	w.startRow;
};
w.recursiveResize.front;

e = (
	instrument: \bufGrainPanFiltDist, pan: g[0].asMap, distance: g[1].asMap,
	bufnum: b, start: 516826, time: 165436/44100, ffreq: 15000,
	chan: m
)
.proto_(~rvbEvent.proto)
.parent_(ProtoEvent(\singleSynthPlayer).v.parent)
.play;

KrBusWatcher.newFrom(s).updateFreq = 8;
g[0].watch.automate { SinOsc.kr(LFNoise1.kr(0.5).range(0.1, 0.8)) };
g[0].watch.automate { SinOsc.kr(0.5) };
g[1].watch.automate { SinOsc.kr(0.08, 0.5pi).range(5, 20) };

a = {
	var	angle = Phasor.kr(0, 2pi / 8 * ControlDur.ir, 0, 2pi),
		radius = SinOsc.kr(0.329843287).range(0.3, 1.0);
	[g, [
		(angle.cos * radius),
		(angle.sin * radius).linlin(-1, 1, 20, 5)
	]].flop.do { |pair| Out.kr(pair[0].bus, pair[1]) };
	Silent.ar(1)
}.play;

a.trace;
a.free;

g.do(_.watch);

g.do { |gc| gc.stopWatching.stopAuto };
a.free;

p = n.play(Pbind(
	\chan, m,
	\instrument, \bufGrainPanFiltDist,
	\pan, g[0].asMap,
	\distance, g[1].asMap,
	\bufnum, b,
	\time, Pwhite(0.8, 1.8, inf),
	\delta, Pkey(\time) * Pwhite(0.25, 0.55, inf),
	\start, Pswitch1([
		Pwhite(516826, (516826 + 97978) - (Pkey(\time) * 44100), inf),
		Pwhite(3276, (3276 + 488489) - (Pkey(\time) * 44100), inf),
	], Pwrand(#[0, 1], #[0.5, 0.5], inf)),
	\rate, Prand(#[-1, 1], inf),
	\start, Pif(Pkey(\rate) < 0, Pkey(\start) + (Pkey(\time) * 44100), Pkey(\start)),
	\time, Pkey(\time) - 0.25,
	\attack, 0.1, \decay, 0.15,
	\ffreq, 15000
), (protoEvent: ProtoEvent(\singleSynthPlayer).copy.proto_(~rvbEvent.proto)));

p.stop;

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;

TempoClock.default.clear;

(1379..1380).do(s.sendMsg(\n_free, _));

(
BP(\wet).free;
PR(\basicSynthChooser).chuck(BP(\wet), nil, (
	alwaysReset: true,
	event: (eventKey: \singleSynthPlayNotify).proto_(topEnvironment[\rvbEvent].proto),
	inChannels: 2,
	master: topEnvironment[\master],
	glrvbmc: topEnvironment[\glrvbmc],
	lcrvbmc: topEnvironment[\lcrvbmc],
	bufdir: topEnvironment[\sampleDir],
	bufpath: "head/slurpy.aiff",
	userprep: {
		#[glrvbmc, lcrvbmc].do { |key|
			key.envirGet.tryPerform(\receivesSignalFrom, ~chan);
		};
		~buf = Buffer.readAndQuery(s, ~bufdir +/+ ~bufpath);
		~panCtl = GenericGlobalControl(\pan, nil, 0, \bipolar);
		~distCtl = GenericGlobalControl(\distance, nil, 5, #[5, 20]);
		~xymaps = [~panCtl, ~distCtl].collect(_.asMap);
		~fastProbCtl = GenericGlobalControl(\fastProb, nil, 0);
	},
	useGui: { |vpi|
		[~panCtl, ~distCtl, ~fastProbCtl].do { |gc| gc => VP(vpi) };
	},
	userfree: {
		#[glrvbmc, lcrvbmc].do { |key|
			key.envirGet.tryPerform(\stopsReceivingFrom, ~chan);
		};
		[~buf, ~panCtl, ~distCtl, ~fastProbCtl].free;
	},
	preparePlay: {
		~stage = 0;
		~autoSynth ?? {
			~autoSynth = {
				var	angle = Phasor.kr(0, -2pi / 8 * ControlDur.ir, 0, 2pi),
					radius = SinOsc.kr(0.329843287).range(0.3, 1.0);
				Out.kr(~panCtl.bus, angle.cos * radius);
				Out.kr(~distCtl.bus, (angle.sin * radius).linlin(-1, 1, 20, 5));
				Silent.ar(1)
			}.play(~chan.fadergroup, addAction: \addToHead);
		};
	},
	stopCleanup: {
		~autoSynth !? {
			~autoSynth.free;
			~autoSynth = nil;
		}
	},
	lastTrig: {
		~stage = ~stage + 1;
	},
	recvEventNotify: {
		if(~stage > 0) { ~stage = ~stage + 1 };
	},
	objects: (
		bgpan: (
			def: \bufGrainPanFiltDist,
			args: [
				#[pan, distance], Plazy { Pn(~xymaps, inf) },
				\bufnum, Plazy { Pn(~buf, inf) },
				\time, Pwhite(0.8, 1.8, inf),
				\overlap, Pwhite(2.0, 5.0, inf),
				\delta, Pkey(\time) / Pkey(\overlap),
				\start, Plazy { Pif(
					Pwhite(0.0, 1.0, inf) < ~fastProbCtl,
					Pwhite(3276, (3276 + 488489) - (Pkey(\time) * ~buf.sampleRate), inf),
					Pwhite(516826, (516826 + 97978) - (Pkey(\time) * ~buf.sampleRate), inf)
				) },
				\rate, Prand(#[-1, 1], inf),
				\attack, 0.1, \decay, 0.15,
				\ffreq, 15000,
				\datafixes, Pfunc { |ev|
					switch(~stage)
					{ 0 } {
						if(ev[\rate] < 0) { ev[\start] = ev[\start] + (ev[\time] * ~buf.sampleRate) };
						ev[\time] = ev[\time] - ev[\attack] - ev[\decay];
						0
					}
					{ 1 } {
						ev.putAll((
							start: 516826, time: 165436 / ~buf.sampleRate - 0.25,
							rate: 1
						));
						0
					}
					{ nil };	// all other stages: stop now
				}
			]
		)
	),
	reset: Func(\resetBPStreams).v
));
0 => BP(\wet);
)

// Tongue comes out, open mouth: start vocalization

a = LPCAna("~/Documents/temp/questions1.aiff".standardizePath);
a.ana(50, 2000, 0.25);
a.saveToFiles(topEnvironment[\sampleDir] +/+ "head/questions1.lpc");

// use doscbloop above (w/ noise buffer == c)

b = Buffer.readAndQuery(s, topEnvironment[\sampleDir] +/+ "head/questions1.lpc.aif");

d = ~rvbEvent.proto.copy.put(\glrvbout, s.options.numOutputBusChannels).put(\lcrvbout, 8);
e = ().proto_(d).parent_(ProtoEvent(\polySynthBusLock).v.parent);

SynthDef(\oscbloop1, { |outbus, bufnum, freq1 = 50, freq2 = 900, fcurve = 0, time = 1, fHoldPct = 0,
	amp1 = 1, amp2 = 1, noiseBlend = 0.1, noiseFmul = 1, noisePreamp = 1, rq = 1.0,
	normAmp = 0.5, beats = 0.1|
	var	freq = EnvGen.kr(Env([freq1, freq1, freq2], [fHoldPct, 1 - fHoldPct], fcurve),
			timeScale: time),
		preAmp = Line.kr(amp1, amp2, time),
		sig = BPF.ar(COsc.ar(bufnum, freq, beats), freq, rq, noisePreamp),
		postAmp = normAmp / preAmp * (preAmp+1),
		env = NamedControl.kr(\env, (0 ! 20).overWrite(Env.linen(0.01, 0.98, 0.01).asArray)),
		eg = EnvGen.kr(env, timeScale: time, doneAction: 2);
	Out.ar(outbus, sig.distort * postAmp * eg);
}).add;

// ~lpcEv = (instrument: \simpleLPCfxPan, target: m.effectgroup, /*inbus: bus,*/ bus: m.inbus,
// 	lpcbuf: b, voxdur: c/44100, start: 0, end: c/44100, time: c/44100,
// 	hpf: 20, lpf: 6000);

// e = (instrument: \blip, freq: 60.midicps * [1, 5/4, 3/2], sustain: c/44100, chan: m, parent: ProtoEvent(\polySynthBusLock).v.parent, collIndex: \dummy, lpcEv: ~lpcEv.copy, amp: 20);

a = SoundFile.openRead(topEnvironment[\sampleDir] +/+ "head/questions1.aiff");
z = a.duration;
a.close;

~blip = Buffer.alloc(s, 2048, 1, { |buf| buf.sine1Msg(1 ! 30) });

var f = 60.midicps * [1, 9/8, 4/3, 3/2];
e.copy.putAll((
	chan: n, instrument: \oscbloop1, bufnum: c, freq1: f, freq2: f * 3, time: 10,
	normAmp: 20.dbamp, beats: 0.6,
	env: [Env.linen(0.25, 0.35, 0.4)],
	lpcEv: (
		instrument: \simpleLPCfxPan, target: n.effectgroup, bus: n.inbus,
		lpcbuf: b, voxdur: z, start: 117625/44100, end: 127959/44100, time: 10,
		hpf: 20, lpf: 15000
	)
)).play;

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| /*r.remove;*/ s.sendMsg(\n_trace, m[1]) }).add;

(
BP(\sw).free;
PR(\basicSynthChooser).chuck(BP(\sw), nil, (
	event: (eventKey: \polySynthBusLock).proto_(topEnvironment[\rvbEvent].proto),
	dir: topEnvironment[\sampleDir],
	path: "head/questions1.aiff",
	labelPath: { ~dir +/+ "head/questions1-labels.txt" },
	lpcPath: "head/questions1.lpc.aif",

	master: topEnvironment[\master],
	glrvbmc: topEnvironment[\glrvbmc],
	lcrvbmc: topEnvironment[\lcrvbmc],

	userprep: {
		var	sf;
		~lpcbuf = Buffer.readAndQuery(s, ~dir +/+ ~lpcPath);
		~readLabels.();
		sf = SoundFile.openRead(~dir +/+ ~path);
		if(sf.notNil) {
			~voxdur = sf.duration;
			sf.close;
		} {
			"Could not read duration from %.".format(~dir +/+ ~path).warn;
		};
		#[glrvbmc, lcrvbmc].do { |key|
			key.envirGet.tryPerform(\receivesSignalFrom, ~chan);
		};
		~noisebuf = Buffer.sendCollection(s, Signal.fill(1024, { 1.0.rand2 }).asWavetable, 1, 0.05);
		~pitchbufs = \makeWavetables.eval(8, s, 2048, 48, { |numh| 1 ! numh });
	},
	userfree: {
		[~lpcbuf, ~noisebuf, ~pitchbufs].free;
		#[glrvbmc, lcrvbmc].do { |key|
			key.envirGet.tryPerform(\stopsReceivingFrom, ~chan);
		};
	},

	delta: Pwhite(3.0, 6.0, inf),
	sustain: Pkey(\delta).linlin(3.0, 6.0, 4.0, 9.0),

	freq1: Pexprand(80.0, 250.0, inf),
	freq2: Pkey(\freq1),
	fcurve: 0,
	preamp: 9,
	amp: 10.dbamp,
	noiseenv: Env.linen(0.2, sustainTime: 0.45, releaseTime: 0.35),
	pfreq: (Paccumbounce(32, 46, Prand(#[-2, -1, 1, 2], inf), inf) +.x Pseries(0, Pwhite(1, 4, 3)))
		.clump(3)
		.collect { |deg| Mode(\g).cps(deg) },

	questionKeys: #["what", "where", "why", "who"],
	coords: Plazy {
		var	items = ~pts.select { |pt|
				~questionKeys.includesEqual(pt[\id])
			};
		items.do { |item| item.postln; };
		Prand(items, inf).collect { |item| [item[\start], item[\end]] }
	},
	lpchpf: 20,
	lpclpf: 15000,
	dist: Pwhite(5.0, 20.0, inf),
	pan: Pwhite(-1.0, 1.0, inf),
	lpcEv: Pbind(
		\instrument, \simpleLPCfxPanDist,
		\lpcbuf, Plazy { Pn(~lpcbuf, inf) },
		\voxdur, Plazy { Pn(~voxdur, inf) },
		#[start, end], BPStream(\coords),
		\hpf, BPStream(\lpchpf),
		\lpf, BPStream(\lpclpf),
		\distance, BPStream(\dist),
		\pan, BPStream(\pan)
	),

	objects: (
		noisy: (
			def: \oscbloop1,
			args: [
				bufnum: Plazy { Pn(~noisebuf, inf) },
				freq1: BPStream(\freq1),
				freq2: BPStream(\freq2),
				fcurve: BPStream(\fcurve),
				time: BPStream(\sustain),
				amp1: BPStream(\preamp),
				amp2: Pkey(\amp1),
				// omitted noise component
				noiseBlend: 0,
				normAmp: BPStream(\amp),
				env: Pfunc { ~noiseenv },
				lpcEv: BPStream(\lpcEv) <> Pfunc { |ev| ~sanitizeEvent.(ev) }
			]
		),
		pitched: (
			def: \oscbloop1,
			args: [
				freq1: BPStream(\pfreq),
				freq2: Pkey(\freq1),
				bufnum: Plazy { Pkey(\freq1).cpsmidi.linlin(48, 48+(12*7),
					~pitchbufs.first.bufnum, ~pitchbufs.first.bufnum + ~pitchbufs.size - 1
				) },
				fcurve: BPStream(\fcurve),
				time: BPStream(\sustain),
				amp1: BPStream(\preamp),
				amp2: Pkey(\amp1),
				// omitted noise component
				noiseBlend: 0,
				normAmp: BPStream(\amp),
				env: Pfunc { ~noiseenv },
				lpcEv: BPStream(\lpcEv) <> Pfunc { |ev| ~sanitizeEvent.(ev) }
			]
		)
	),
	sanitizeKeys: (time: \time),
	sanitizeEvent: { |ev, keys(~sanitizeKeys)|
		var	newEv = ().proto_(~event.proto);
		keys.keysValuesDo { |k, v|
			newEv[k] = ev[v];
		};
		newEv
	},

	readLabels: {
		~pt = TabFileReader.read(~labelPath.());
		~processLabels.();
	},
	processLabels: {
		var temp;
		~pts = ~pt.collect { |row|
			temp = (id: row[2], start: row[0].asFloat, end: row[1].asFloat);
			temp.put(\dur, temp[\end] - temp[\start])
		}
	}
));
0 => BP(\sw);
)

BP(\sw).triggerOneEvent(0);

p = BP(\sw);
p.sanitizeKeys.put(\debug, \debug);
p.event.debug = false;

p.delta = Pwhite(1.5, 3.0, inf);
p.sustain = Pkey(\delta).linlin(1.5, 3.0, 5.0, 11.0);

p.synth = Pwrand(#[noisy, pitched], #[0.1, 0.9], inf);
p.pitchedrq

p.noisyenv

// Smile and other emotions: vocal chatter
