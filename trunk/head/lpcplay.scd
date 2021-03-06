// vox synthesis for head section, initial experiments

// notched blippy wavetables
// overlapping phonemes
// pitch material (incl. chords) as input - one lpc seg/chord, or more?
//		- split exciter from lpcsynth - buspool from r-u-listening


SynthDescLib.global.browse;
Object.browse;
s.queryAllNodes;

MIDIPort.init([2]);
MIDIPort.autoFreeSockets = false;

MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

(Document.current.path.dirname +/+ "head-defs.scd").loadPath;
topEnvironment[\dir] = Document.current.path.dirname.dirname +/+ "samples/feet";

m = MixerChannel(\test1, s, 1, 2);
n = MixerChannel(\test2, s, 2, 2);
m => MCG(0); n => MCG(1);

#[master, rvbmc, rvb].do(_.envirPut(nil));

VoicerProxy.new => VP.prNew(0);
4.do { VP(0).v.addControlProxy(nil, true) };
VP(0).v.gui;

k = VoicerMIDISocket(0, VP(0).v);

(
var cc;
8.do {
	cc = VoicerMIDIController(\omni, \knob);
	cc => CC.prNew(cc.ccnum.shortName.asSymbol);
};
);

4.do { |i| CC(("k" ++ i).asSymbol) => VP(0) };

(Document.current.path.dirname +/+ "feet-defs.scd").loadPath;
TempoClock.tempo = 110/60;

~rvbmc => MCG(6);
~master => MCG(7);
MixingBoard.at(0).refresh;

~rvb.run(false); ~rvbmc.mute;
~rvb.run(true); ~rvbmc.mute;


// lpc support files
~lpcb.free;

~dir = Document.current.path.dirname.dirname +/+ "samples/feet";
//~lpcb = Buffer.readAndQuery(s, ~dir +/+ "words-lpf3-lpc.aiff");
~lpcb = Buffer.readAndQuery(s, ~dir +/+ "words-ana3.lpc.aif");
~pt = TabFileReader.read(~dir +/+ "words-labels.txt");
~pt = ~pt.do { |pt| #[0, 1, 3, 4].do { |i| pt[i] = pt[i].asFloat } };
SoundFile.use(~dir +/+ "words-mono.aiff", { |file| ~voxdur = file.duration });


// default LPCAna parms SUCK
x = LPCAna(~dir +/+ "words-mono.aiff");
x.ana(nPoles: 35, frameSize: 1000, hop: 0.5, minFreq: 70, maxFreq: 300, conditionSignal: 0);

x.saveToFiles(~dir +/+ "words-ana4.lpc");

y = LPCFile(~dir +/+ "words-ana3.lpc");
[y.nrmerr.minItem, y.nrmerr.maxItem]

~lpcb.getn(0, 3, _.postln)

SynthDef(\lpc1, { |outbus, lpcbuf, voxdur = 1, start, end = 1, time = 1, amp = 1, freq = 440, noiseMul = 1, hpf = 400, ampFactor = 0.01, xfscale = 0.25, lpf = 5000|
	var	pos = Line.kr(start, end, time) / voxdur,
 		lpcv = LPCVals.ar(lpcbuf, pos),
		src = Blip.ar(freq * [1, 1.003], 15000.0 / freq).sum,
 		noise = HPF.ar(WhiteNoise.ar(noiseMul), hpf),
//		noise = WhiteNoise.ar(noiseMul),
		sig = LPCSynth.ar(lpcbuf, XFade2.ar(src, noise, (xfscale * lpcv[2]).madd(2, -1)), pos, amp * lpcv[1]),
		eg = EnvGen.kr(Env.linen(0.05, time - 0.1, 0.05), doneAction: 2);
	sig = LPF.ar(sig, lpf);
	Out.ar(outbus, Limiter.ar(sig * eg * ampFactor));
}).add;

SynthDescLib.at(\lpc1).def.children.do(_.postln)

p = ~pt.choose;
a = m.play(\lpc1, [lpcbuf: ~lpcb, start: (p[0] - 0.1) / ~voxdur, end: (p[1] + 0.1) / ~voxdur, time: p[1] - p[0] * 3, amp: 1, freq: 200, noiseMul: 1, ampFactor: 1, xfscale: 0.23, lpf: 12000, hpf: 1646]);
a.free;

PeakMonitor(m);

h = GenericGlobalControl(\hpf, nil, 200, #[20, 8000, \exp]); h.gui;
g = GenericGlobalControl(\xfmul, nil, 0.25); g.gui;
i = GenericGlobalControl(\lpf, nil, 5000, \freq); i.gui;

p = m.play(
	Pbind(
		\instrument, \lpc1,
		\pt, Prand(~pt, inf),
		#[start, end], Pkey(\pt),	// ignores extra vals
		\time, 0.95, // Pkey(\end) - Pkey(\start),
		\amp, 1,
		\voxdur, ~voxdur,
		\delta, Pkey(\time).roundUp(0.25),
		\freq, Pexprand(200.0, 600.0, inf),
		\noiseMul, 1,
		\hpf, h.asMap,
		\ampFactor, 1, //0.01
		\xfscale, g.asMap,
		\lpf, i.asMap
	)
);

p.stop;


o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m|
	s.sendMsg(\n_trace, m[1]); r.remove;
}).add;


p = m.play(
	Pbind(
		\instrument, \lpc1,
		\pt, Prand(~pt, inf),
		#[ptstart, ptend], Pindex(Pkey(\pt), Pn(#[0, 1], 1), inf),
		\start, Pwhite(Pkey(\ptstart), Pkey(\ptend) - 0.1, inf),
		\end, Pkey(\start) + 0.1,
		\time, 0.3,
		\amp, 1,
		\voxdur, ~voxdur,
		\delta, 0.125,
		\freq, Pexprand(200.0, 600.0, inf),
		\noiseMul, 1,
		\hpf, 3000,
		\ampFactor, 1, //0.01
		\xfscale, 0.236,
		\lpf, 18000
	)
);

p.stop;


// bus lock object - release bus when all the locking objects are gone
(
Proto {
	~prep = { |args|
		if(args.respondsTo(\keysValuesDo)) {
			currentEnvironment.putAll(args);
		};
		~locks = IdentitySet.new;
		// this way, makeStuff can have whatever args it needs
		// and it will pull them from the environment (after being put there by putAll)
		currentEnvironment.env.use { ~makeStuff.valueEnvir };
		currentEnvironment
	};

	~numCh = 1;
	~rate = \audio;
	~server = { Server.default };

	// user overrides
	~makeStuff = { |numCh, rate, server|
		~server = server.value;
		if((~bus = Bus.perform(rate, ~server, numCh)).isNil) {
			Error("couldn't get % bus".format(rate)).throw;
		};
		~bus //.debug("made");
	};

	~freeStuff = {
		~bus/*.debug("freed")*/.free;
		~killNodes.do(_.free);
	};

	~addNode = { |node|
		var	endFunc = e { |obj, what|
			if(what == \n_end) {
				node.removeDependant(endFunc);
				~removeLock.(node);
			};
		};
		~locks.add(node);
		NodeWatcher.register(node);
		node.addDependant(endFunc);
	};

	~removeLock = { |obj|
		~locks.remove(obj);
		if(~locks.isEmpty) {
			~freeStuff.();
		};
	};
} => PR(\busLock);
)


SynthDef(\simpleLPCfxPan, { |inbus, outbus, lpcbuf, voxdur = 1, start, end = 1, time = 1, amp = 1, freq = 440, noiseMul = 1, hpf = 1600, xfscale = 0.25, lpf = 15000, pan = 0|
	var	src = In.ar(inbus, 1),
		pos = Line.kr(start, end, time) / voxdur,
 		lpcv = LPCVals.ar(lpcbuf, pos),
 		noise = HPF.ar(WhiteNoise.ar(noiseMul), hpf),
		sig = LPCSynth.ar(lpcbuf, XFade2.ar(src, noise, (xfscale * lpcv[2]).madd(2, -1)), pos, amp * lpcv[1]),
		eg = EnvGen.kr(Env.linen(0.05, time - 0.1, 0.05), doneAction: 2);
	sig = LPF.ar(sig, lpf);
	Out.ar(outbus, Pan2.ar(Limiter.ar(sig * eg), pan));
}).add;

SynthDef(\stupidBlip, { |outbus, freq = 440, amp = 1, detune = 1.003, time = 1|
	var	sig = Blip.ar(freq * [1, detune], 15000 / freq, amp),
		eg = EnvGen.kr(Env.perc(0.05, 0.95), timeScale: time, doneAction: 2);
	Out.ar(outbus, sig * eg);
}).add;


// other synthdef
WrapInstr("osc2.vosc3").openFile;  // wanted vosc3matrix - mei you

~wt.free;
~wt = Buffer.allocConsecutive(8, s, 2048, 1, { |buf, i|
	var	amps = 1 ! 18,	// c. 800 Hz top freq, just for test
		indices = (0..17).scramble.keep((i*1.5).round.asInteger);
//	(i*1.5).round.do { indices.takeAt(indices.size.rand) };
	indices.do { |i| amps[i] = rrand(0.0, 0.1) };
	buf.sine1Msg(amps)
});

~wt[7].plotWavetable;

WrapInstr("osc2.vosc3").listArgs;
d = WrapPatch("osc2.vosc3", [nil, `1, ~wt.first.bufnum, nil, Env.adsr(0.01, 0.2, 0.6, 0.1), nil, nil, `1.003]).asSynthDef.add;
SynthDescLib.at(d.name.asSymbol).msgFuncKeepGate = true;

e = m.play((instrument: d.name.asSymbol, vsens: 1, gate: 0.2));

p = m.play(Pbind(
	\instrument, d.name.asSymbol,
	\vsens, 1,
	\gate, 0.2,
	\degree, Pwhite(0, 7, inf),
	\dur, 0.25,
	\bufmod, Pwhite(0, ~wt.size - 1.001, inf)
));

p.stop;

();
(
var	lock = PR(\busLock).copy.prep,
	bus = lock.bus,
	freqs = #[60, 64, 67].midicps,
	srcEv;

~lock = lock;
~srcEv = (instrument: \stupidBlip, freq: freqs, amp: 1, time: 1, target: m.synthgroup, bus: bus,
	parent: ProtoEvent(\polySynthPlayer).parent).play;
~srcEv.node.do(lock.addNode(_));

~onept = ~pt.choose;
~lpcEv = (instrument: \simpleLPCfx, target: m.effectgroup, inbus: bus, bus: m.inbus,
	lpcbuf: ~lpcb, voxdur: ~voxdur, start: ~onept[0], end: ~onept[1], time: 1, amp: 1,
	parent: ProtoEvent(\singleSynthPlayer).parent).play;
~lock.addNode(~lpcEv.node);
)

(
(parent: ProtoEvent(\polySynthPlayer).v.parent.copy.putAll((
	superPlay: ProtoEvent(\polySynthPlayer).v[\play],
	play: {
		var	chan = ~chan;
		~numCh ?? { ~numCh = ~chan.inChannels };
		~lock = PR(\busLock).copy.prep((
			numCh: ~numCh, server: ~chan.server
		));
		~bus = ~lock.bus;
		~target = ~chan.synthgroup;
		~chan = nil;
		~superPlay.();

		if(~lpcEv.size > 0) {
			~lpcEv.putAll((
				bus: chan.inbus,
				target: chan.effectgroup,
				chan: nil,
				inbus: ~lock.bus,
					// effectgroup might have post-lpc effect nodes (chorus etc.)
					// so put lpc's up front
				addAction: ~lpcEv[\addAction] ?? { \addToHead }
			))
			// cuz parent: don't work in putAll #@$*$&*$&@#312
			.parent_(ProtoEvent(~lpcProto ?? { \singleSynthPlayer }).v.parent)
			.play;
			~lpcEv[\node].do { |node| ~lock.addNode(node) };
		} {
			~sendNode = Synth("mixers/Send" ++ ~numCh,
				[busin: ~lock.bus, busout: chan.inbus, level: 1],
				chan.effectgroup
			);
			~lock.killNodes = ~sendNode;
		};
	},
	notifyDependents: {
		~node.do { |node| ~lock.addNode(node) };
	}
))) => ProtoEvent(\polySynthBusLock);
)

~lpcEv = (instrument: \simpleLPCfx, target: m.effectgroup, inbus: bus, bus: m.inbus,
	lpcbuf: ~lpcb, voxdur: ~voxdur, start: ~onept[0], end: ~onept[1], time: 1, amp: 1,


~onept = ~pt.choose;
e = (instrument: d.name.asSymbol, freq: 60.midicps * [1, 5/4, 3/2], vsens: 1, gate: 1, sustain: 5, chan: m, parent: ProtoEvent(\polySynthBusLock).v.parent, collIndex: \dummy, lpcEv: (instrument: \simpleLPCfx, lpcbuf: ~lpcb, voxdur: ~voxdur, start: ~onept[0], end: ~onept[1], time: 5, amp: 1));
e.play;
e.node[0].trace;
e.sendNode.trace;
e.node[0].dependants

e = { |i| (instrument: d.name.asSymbol, freq: (60.midicps * [1, 5/4, 3/2])[i], vsens: 1, gate: 1, sustain: 5, chan: m, parent: ProtoEvent(\polySynthBusLock).v.parent, collIndex: \dummy, lpcEv: (instrument: \simpleLPCfx, lpcbuf: ~lpcb, voxdur: ~voxdur, start: (~onept = ~pt.choose)[0], end: ~onept[1], time: 5, amp: 1)) } ! 3;

fork {
	e.do { |ev| ev.play; 0.5.wait }
};



s.queryAllNodes;

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m|
	s.sendMsg(\n_trace, m[1]); // r.remove;
}).add;


e.lock.listVars

s.audioBusAllocator.debug
s.audioBusAllocator.free(11)

~onept = ~pt.choose;
e = (instrument: d.name.asSymbol, freq: 60.midicps * [1, 5/4, 3/2], vsens: 1, gate: 1, sustain: 5, chan: n, numCh: 1, parent: ProtoEvent(\polySynthBusLock).v.parent, collIndex: \dummy, lpcEv: (instrument: \simpleLPCfxPan, lpcbuf: ~lpcb, voxdur: ~voxdur, start: ~onept[0], end: ~onept[1], time: 5, amp: 1, pan: 1));
e.play;

s.bufferAllocator.debug;

(
BP(\vx).free;
PR(\basicSynthChooser).chuck(BP(\vx), nil, (
	dir: topEnvironment[\dir] ?? { Document.current.path.dirname.dirname +/+ "samples/feet" },
	lpcPath: "words-ana3.lpc.aif",
	labelPath: "words-labels.txt",
	audioPath: "words-mono.aiff",
	event: (eventKey: \polySynthBusLock),
	userprep: {
		~wt = Buffer.allocConsecutive(8, s, 2048, 1, { |buf, i|
			var	amps = 1 ! 18,	// c. 800 Hz top freq, just for test
				indices = (1..17).scramble.keep(rrand(9, 12));
			indices.do { |i| amps[i] = rrand(0.0, 0.1) };
			buf.sine1Msg(amps)
		});

		~lpcb = Buffer.readAndQuery(s, ~dir +/+ ~lpcPath);
		~pt = TabFileReader.read(~dir +/+ ~labelPath);
		~pt = ~pt.do { |pt| #[0, 1, 3, 4].do { |i| pt[i] = pt[i].asFloat } };
		SoundFile.use(~dir +/+ ~audioPath, { |file| ~voxdur = file.duration });

		~noisewt = Buffer.allocConsecutive(10, s, 4096, 1);

		// generate noise exciter buffers, with individual resonant filter characteristics
		fork {
			var	n;
			
			SynthDef(\writeNoise, { |bufnum|
				var	noise = WhiteNoise.ar, numfilt = 50,
				filtered = Klank.ar(`[  // f, a, r
					Pseries(20, 15000, numfilt).asStream.all * ({ ExpRand(0.95, 0.95.reciprocal) } ! numfilt),
					1 ! numfilt,
					{ ExpRand(0.01, 0.2) } ! numfilt
				], noise),
				recorder = RecordBuf.ar(filtered, bufnum, loop: 0, doneAction: 2),
				peak = Peak.ar(filtered);
				SendReply.ar(K2A.ar(Done.kr(recorder)), "/noisePeak", peak, bufnum);
			}).add;
			
			// exciter buffer must be normalized - Klank result above is REALLY LOUD
			SynthDef(\scaleBuf, { |bufnum, amp = 1|
				RecordBuf.ar(
					BufRd.ar(1, bufnum, Phasor.ar(end: BufFrames.ir(bufnum) + 10000), loop: 0, interpolation: 1)
						* amp,
					bufnum, loop: 0, doneAction: 2
				)
			}).add;

			s.sync;
			
			n = ~noisewt.size;
			~peakResp = OSCresponderNode(s.addr, '/noisePeak', e { |t, r, m|
				var	buf;
				// SendReply returns the bufnum as the reply ID m[2]
				if((buf = ~noisewt.detect { |b| b.bufnum == m[2] }).notNil) {
					n = n - 1;
					if(n == 0) { r.remove; "BP(%) noise buffers done\n".postf(~collIndex.asCompileString) };
					Synth(\scaleBuf, [bufnum: m[2], amp: 0.98 / m[3]]);
				};
			}).add;
			
			Pbind(
				\instrument, \writeNoise,
				\bufnum, Pseq(~noisewt, 1),
				\delta, 0.05
			).play;
		};
	},
	userfree: {
		[~wt, ~noisewt, ~lpcb].free;
	},

	degree: Pwhite(36, 44, inf) -.x Pseries(0, Pwhite(1, 3, { rrand(1, 5) }), inf).clump(10),
	mode: \default,
	bufmod: Pwhite(0, Pfunc { ~wt.size - 1.001 }, inf),
	amp: Pexprand(0.5, 1, inf),

	objects: { (
		wtblip: (
			def: WrapPatch("osc2.vosc3", [nil, KrNumberEditor(1, #[0, 1]).lag_(nil), ~wt.first.bufnum, nil, Env.adsr(0.01, 0.2, 0.6, 0.1), nil, nil, `1.003]),
			args: [
				degree: BPStream(\degree),
				mode: BPStream(\mode),
				freq: Pfunc { |ev| ev[\mode].asMode.cps(ev[\degree]) },
				bufmod: BPStream(\bufmod),
				vsens: 1,
				gate: BPStream(\amp),
				lpcEv: BPStream(\lpcEv) <> Pfunc { |ev| ~sanitizeEvent4lpc.(ev) }
			]
		),
		// unfiltered WhiteNoise -> CombL
		comb1: (
			def: SynthDef(\comb1, { |outbus, gate = 1, amp = 1, freq = 440, excTime = 0.08,
					cdecay = 20, detune = 1.003|
				var	exc = WhiteNoise.ar(amp) * Decay2.ar(Impulse.ar(0), 0.01, excTime),
					sig = exc + CombL.ar(exc, 0.05, (freq * [1, detune]).reciprocal, cdecay).sum,
					eg = EnvGen.kr(Env.asr(0.05, 1, 0.15), gate, doneAction: 2);
				Out.ar(outbus, sig * eg);
			}), //.add,
			args: [
				degree: BPStream(\degree),
				mode: BPStream(\mode),
				freq: Pfunc { |ev| ev[\mode].asMode.cps(ev[\degree]) },
				amp: 1,
				lpcEv: BPStream(\lpcEv) <> Pfunc { |ev| ~sanitizeEvent4lpc.(ev) },
			]
		),
		// buffers with filtered WhiteNoise -> CombL
		comb2: (
			def: SynthDef(\comb2, { |bufnum, freq = 440, amp = 1, cdecay = 2, gate = 1,
					detune = 1.003, outbus|
				var	excbuf = BufRd.ar(1, bufnum, Sweep.ar(1, BufSampleRate.ir(bufnum)), loop: 0) * amp,
					excTime = BufDur.ir(bufnum),
					excdecay = Decay2.kr(Impulse.kr(0), 0.01, excTime),
					exc = excbuf * excdecay,
					sig = exc + CombL.ar(exc, 0.05, (freq * [1, detune]).reciprocal, cdecay).sum,
					eg = EnvGen.kr(Env.asr(0.01, 1, 0.15), gate, doneAction: 2);
				Out.ar(outbus, sig * eg)
			}), //.add,
			args: [
				degree: BPStream(\degree),
				mode: BPStream(\mode),
				freq: Pfunc { |ev| ev[\mode].asMode.cps(ev[\degree]) },
				bufnum: Pxrand(~noisewt, inf).clump(Pfunc { |ev| ev[\degree].size }),
				xfade: Pwhite(-1.0, 1.0, inf),
				amp: 5,
				lpcEv: BPStream(\lpcEv) <> Pfunc { |ev| ~sanitizeEvent4lpc.(ev) }
			]
		)
	) },

	preparePlay: {
		if(~needToFixSynthDescsOnce ? true) {
			~objects.do { |obj|
				SynthDescLib.at(obj.name.asSymbol).msgFuncKeepGate = true;
			};
			~needToFixSynthDescsOnce = false;
		};
	},

	lpcInstr: \simpleLPCfxPan,
	lpcStart: Pwhite(Pkey(\ptstart), Pkey(\ptend) - Pkey(\time), inf),
	lpcEnd: Pkey(\start) + Pkey(\time),
	lpcPan: Pwhite(-1.0, 1.0, inf),
	lpcAtt: 0.05,
	lpcDec: 0.05,
	lpcEv: Plazy { Pbind(
		\instrument, BPStream(\lpcInstr),
		\lpcbuf, ~lpcb,
		\voxdur, ~voxdur,
		\pt, Pxrand(~pt, inf),
		#[ptstart, ptend], Pkey(\pt),
		\start, BPStream(\lpcStart),
		\end, BPStream(\lpcEnd),
//		\time, // should be populated by sanitizeEvent
		\amp, 1,
		\pan, BPStream(\lpcPan),
		\attack, BPStream(\lpcAtt),
		\decay, BPStream(\lpcDec)
	) },
// 	lpcEv: 0,  // 0.size == 0, so event will use a dummy Send synth
	sanitizeEvent4lpc: { |ev, keys((time: \sustain))|
		var	newEv = ();
		keys.keysValuesDo { |k, v|
			newEv[k] = ev[v];
		};
		newEv
	}
));
)

p = BP(\vx);
p.delta = Pwhite(1, 3, inf) * 0.5;
p.sustain = Pkey(\delta) * 0.9;

p.degree = Pwhite(36, 44, inf) -.x Pseries(0, Pwhite(1, 3, { rrand(1, 5) }), inf).clump(10);
p.amp = 1;

p.lpcStart = Pwhite(Pkey(\ptstart), max(Pkey(\ptstart), Pkey(\ptend) - 0.15), inf);
p.lpcEnd = Pkey(\start) + Pwhite(0.1, 0.15, inf);

p.lpcStart = Pwhite(Pkey(\ptstart), max(Pkey(\ptstart), Pkey(\ptend) - Pfunc { ~lpcDur = rrand(0.1, 0.15) }), inf);
p.lpcEnd = (Pkey(\start) + Pfunc { ~lpcDur });

p.lpcEvStream.reset;

p.lpcStartStream.next((ptstart: 0.1, ptend: 0.25));

p.lpcStart = Pkey(\ptstart);
p.lpcEnd = Pkey(\ptend);

p.lpcStart = Pwhite(Pkey(\ptstart), Pkey(\ptend) - 0.05, inf);
p.lpcEnd = Pkey(\start) + 0.05;

p.bufmod = Pwhite(0, 6.998, inf);
p.bufmod = 0;

// rapid overlapping
p.delta = Pwrand([Pn(1, 2), 2, 3, 4, 5, 6], #[0.5, 4, 4, 2, 1, 0.5].normalizeSum, inf) * 0.125;
p.sustain = (Pkey(\delta) * Pwhite(1.0, 3.0, inf)).clip(0.1, 1.2);
p.lpcDec = Pkey(\time) * 0.4;
p.lpcAtt = Pkey(\time) * 0.25;

p.mode = Prand(Mode.keys.select { |key| key.asString.last == $0 }.asArray, inf);

p.synth = p.synth.trace;
p.synth = \comb1;
p.synth = \comb2;
p.comb2amp = 5;

z = p.comb2bufnum;
p.comb2bufnum = p.comb2bufnum.trace;
p.comb2bufnum = z;

p.synth = Pfunc { ~objects.keys.choose };

p.savelpc = p.lpcEv;
p.lpcEv = Pfunc { 0 };
p.lpcEv = p.savelpc;



g = GenericGlobalControl(\bufmod, nil, 0, #[0, 6.998]); g.gui;
p.bufmod = g.asMap;

FxPatch(
	[ 'busfx', 'chorus2' ], [ 20, 2, 2, 3, 0.011564949675432, 0.052749969028213, 0.0095969140264937, 2.094395164811, 0.52749969028213 ]
)


p.objects.collect(_.name);

q = m.play(Pbind(
	\instrument, \comb1,
	\amp, 1,
	\degree, Pwhite(-7, 7, inf),
	\dur, 0.5
));

q.stop;

q = m.play(Pbind(
	\instrument, \comb1,
	#[bufnum1, bufnum2], Pxrand(p.noisewt, inf).clump(2),
	\xfade, Pwhite(-1.0, 1.0, inf),
	\amp, 1,
	\degree, Pwhite(-7, 7, inf),
	\dur, 0.125
));

q.stop;


p.lpcEv = Plazy { Pbind(
		\instrument, BPStream(\lpcInstr),
		\lpcbuf, ~lpcb,
		\voxdur, ~voxdur,
		\pt, Pxrand(~pt, inf),
		#[ptstart, ptend], Pkey(\pt),
		\start, BPStream(\lpcStart),
		\end, BPStream(\lpcEnd),
//		\time, // should be populated by sanitizeEvent
		\amp, 1,
		\pan, BPStream(\lpcPan)
).trace(prefix: "\n") };

Task {
	p.noisewt.do { |buf|
		buf.getToFloatArray(action: { |data|
			[buf.bufnum, data.minItem, data.maxItem, data.squared.mean.sqrt].postln
		});
		0.2.wait;
	};
}.play(AppClock);


~savebufmod = p.bufmod;
p.bufmod = p.bufmod.trace;
p.bufmod = ~savebufmod;


// with hpf on noise, ok whispering sound
SynthDef(\lpc1, { |outbus, lpcbuf, voxdur = 1, start, end = 1, time = 1, amp = 1, freq = 440, noiseMul = 1, hpf = 400, ampFactor = 0.01, xfscale = 0.25, lpf = 5000|
	var	pos = Line.kr(start, end, time) / voxdur,
 		lpcv = LPCVals.ar(lpcbuf, pos),
// 		src = Blip.ar(freq * [1, 1.003], 15000.0 / freq).sum,
 		noise = HPF.ar(WhiteNoise.ar(noiseMul), hpf),
		sig = LPCSynth.ar(lpcbuf, noise, pos, amp * lpcv[1]),
		eg = EnvGen.kr(Env.linen(0.05, time - 0.1, 0.05), doneAction: 2);
	sig = LPF.ar(sig, lpf);
	Out.ar(outbus, Limiter.ar(sig * eg * ampFactor));
}).add;

// comb is nice
SynthDef(\lpc1, { |outbus, lpcbuf, voxdur = 1, start, end = 1, time = 1, amp = 1, freq = 440, noiseMul = 1, hpf = 400, ampFactor = 0.01, xfscale = 0.25, lpf = 5000|
	var	pos = Line.kr(start, end, time) / voxdur,
 		lpcv = LPCVals.ar(lpcbuf, pos),
		exc = WhiteNoise.ar(amp) * Decay2.ar(Impulse.ar(0), 0.01, 0.08),
		src = CombL.ar(exc, 0.05, (freq * #[1, 1.003]).reciprocal, 20).sum,
 		noise = HPF.ar(WhiteNoise.ar(noiseMul), hpf),
//		noise = WhiteNoise.ar(noiseMul),
		sig = LPCSynth.ar(lpcbuf, XFade2.ar(src, noise, (xfscale * lpcv[2]).madd(2, -1)), pos, amp * lpcv[1]),
		eg = EnvGen.kr(Env.linen(0.05, time - 0.1, 0.05), doneAction: 2);
	sig = LPF.ar(sig, lpf);
	Out.ar(outbus, Limiter.ar(sig * eg * ampFactor));
}).add;



p = ~pt.choose;
a = m.play(\lpc1, [lpcbuf: ~lpcb, start: (p[0] - 0.1) / ~voxdur, end: (p[1] + 0.1) / ~voxdur, time: p[1] - p[0] * 3, amp: 1, freq: 200, noiseMul: 1, ampFactor: 1, xfscale: 0.25, lpf: 12000, hpf: 1600]);

q = BP(\vx).chan.playfx(Instr("busfx.chorus2"), [0, 2, 2, 3]); q.gui;

		p.wt.do { |buf, i|
			var	amps = 1 ! 18,	// c. 800 Hz top freq, just for test
				indices = (1..17).scramble.keep(rrand(9, 12));
			indices.do { |i| amps[i] = rrand(0.0, 0.1) };
			buf.sine1(amps.debug(i))
		};
""

SynthDescLib.at(p.objects[\wtblip].name.asSymbol)

r = m.play(Pbind(
	\instrument, p.objects[\wtblip].name,
	\bufmod, PnNilSafe(Pseries(0, 1, p.wt.size), inf).min(6.999),
	\detune, g.asMap,
	\delta, 1,
	\sustain, 0.9
), (protoEvent: ProtoEvent(\singleSynthPlayer).copy));

r.stop;

g = GenericGlobalControl(\detune, nil, 1.003, \mydetune); g.gui;
m.free;


// comb with shaped noise
~noisewt = Buffer.allocConsecutive(10, s, 4096, 1);

SynthDef(\writeNoise, { |bufnum|
	var	noise = WhiteNoise.ar, numfilt = 50,
	filtered = Klank.ar(`[  // f, a, r
		Pseries(20, 15000, numfilt).asStream.all * ({ ExpRand(0.95, 0.95.reciprocal) } ! numfilt),
		1 ! numfilt,
		{ ExpRand(0.01, 0.2) } ! numfilt
	], noise),
	recorder = RecordBuf.ar(filtered, bufnum, loop: 0, doneAction: 2),
	peak = Peak.ar(filtered);
	SendReply.ar(K2A.ar(Done.kr(recorder)), "/peak", peak, bufnum);
}).add;

SynthDef(\scaleBuf, { |bufnum, amp = 1|
	RecordBuf.ar(
		BufRd.ar(1, bufnum, Phasor.ar(end: BufFrames.ir(bufnum) + 10000), loop: 0, interpolation: 1)
			* amp,
		bufnum, loop: 0, doneAction: 2
	)
}).add;

(
o.remove;
~n = ~noisewt.size;
o = OSCresponderNode(s.addr, '/peak', { |t, r, m|
	var	buf;
	if((buf = ~noisewt.detect { |b| b.bufnum == m[2] }).notNil) {
		~n = ~n - 1;
		if(~n == 0) { r.remove; "done".postln };
		Synth(\scaleBuf, [bufnum: m[2], amp: 0.98 / m[3]]);
	};
}).add;

q = Pbind(
	\instrument, \writeNoise,
	\bufnum, Pseq(~noisewt, 1),
	\delta, 0.01
).play;
)

// assumes 2 bufs have same sample rate - exciter will be as long as the shorter buffer
SynthDef(\comb1, { |bufnum1, bufnum2, xfade = 0, freq = 440, amp = 1, cdecay = 2, outbus|
	var	exc2 = BufRd.ar(1, [bufnum1, bufnum2], Sweep.ar(1, BufSampleRate.ir(bufnum1)), loop: 0),
		exc = XFade2.ar(exc2[0], exc2[1], xfade),
		excTime = BufDur.ir([bufnum1, bufnum2]).reduce(\min),
		excdecay = Decay2.kr(Impulse.kr(0), 0.01, excTime),
		comb = CombL.ar(exc * excdecay, 0.05, freq.reciprocal, cdecay, amp);
	DetectSilence.ar(comb, 0.001, doneAction: 2);
	Out.ar(outbus, comb)
}).add;


// assumes 2 bufs have same sample rate - exciter will be as long as the shorter buffer
SynthDef(\comb2, { |bufnum1, bufnum2, xfade = 0, freq = 440, amp = 1, cdecay = 2, gate = 1, outbus|
	var	exc2 = BufRd.ar(1, [bufnum1, bufnum2], Sweep.ar(1, BufSampleRate.ir(bufnum1)), loop: 0),
		exc = XFade2.ar(exc2[0], exc2[1], xfade),
		excTime = BufDur.ir([bufnum1, bufnum2]).reduce(\min),
		excdecay = Decay2.kr(Impulse.kr(0), 0.01, excTime),
		comb = CombL.ar(exc * excdecay, 0.05, freq.reciprocal, cdecay, amp),
		eg = EnvGen.kr(Env.asr(0.01, 1, 0.15), gate, doneAction: 2);
	Out.ar(outbus, comb * eg)
}).add;

p.use {
q = n.play(Pbind(
	\instrument, \comb2,
	#[bufnum1, bufnum2], Pxrand(~noisewt, inf).clump(2),
	\xfade, Pwhite(-1.0, 1.0, inf),
	\freq, Pwhite(28, 42, inf).collect { |x| Mode(\default).cps(x) },
	\delta, 1,
	\sustain, Pkey(\delta) * 1.4,
	\cdecay, 25,
	\amp, 1,
	\numCh, 1,
//	\chan, n,
	\lpcEv, Pbind(
		\instrument, \simpleLPCfxPan,
		\lpcbuf, ~lpcb,
		\voxdur, ~voxdur,
		#[start, end], Prand(~pt, inf),
		\amp, 1
	) <> Pfunc { |ev| (time: ev.use { ~sustain.() }) }
), (protoEvent: ProtoEvent(\polySynthBusLock).copy));
};

q.stop;

n.free;



// not really lpc but related: amp response of formant filters?
(
f = { |center, freq, bw|
	var w0, sin_w0, alpha, a0, b0rz, b1, b2, sr, a1, a2, cos_w0, w, sin_w, cos_w, out;
	sr  = 44100;
	w0 = pi * 2 * center / 44100;
	sin_w0 = w0.sin;
	cos_w0 = w0.cos;
	alpha = sin_w0 * sinh(0.34657359027997 * bw * w0 / sin_w0);
	b0rz = (1 + alpha).reciprocal;
	a0 = alpha * b0rz;
	b1 = cos_w0 * 2 * b0rz;
	b2 = (1 - alpha) * b0rz.neg;

	a1 = 0.0;
	a2 = a0.neg;
	b1 = b1.neg;
	b2 = b2.neg;

	out = freq.asArray.collect { |freq|
		w = 2pi * freq / 44100;
		sin_w = w.sin;
		cos_w = w.cos;
	
		sqrt(
			squared(
				(a0 * squared(cos_w))
				- (a0 * squared(sin_w))
				+ (a1 * cos_w) 
				+ a2
			)
			+ squared(
				(2 * a0 * cos_w * sin_w)
				+ (a1 * (sin_w))
			)
		)
		/ 
		sqrt(
			squared(
				squared(cos_w)
				- squared(sin_w)
				+ (b1 * cos_w)
				+ b2
			)
			+ squared(
				(2 * cos_w * sin_w)
				+ (b1 * sin_w)
			)
		)
	};
	if(freq.size == 0) { out[0] } { out }
};
)

f.(500, 500, 0.1)

(56 * (1..50)).collect { |test| f.(500, test, 0.1) }.plot

f.(500, (56 * (1..50)), 0.1).plot

FormantTable.keys.select { |key| key.asString.contains("tenor") };

x = FormantTable.at(\tenorO);

z = Pseries.fromEndpoints(100, 5000, 100).asStream.all;

y = x.flop.collect { |filt|
	f.(filt[0], z, filt[2]) * filt[1]
};

y[0].plot;
y.sum.plot;


