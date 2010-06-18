// vox synthesis for head section, initial experiments

SynthDescLib.global.browse;
Object.browse;
s.queryAllNodes;

MIDIPort.init([2]);
MIDIPort.autoFreeSockets = false;

MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

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

~dir = Document.current.path.dirname.dirname +/+ "samples/feet";
~lpcb = Buffer.readAndQuery(s, ~dir +/+ "words-lpf3-lpc.aiff");
~pt = TabFileReader.read(~dir +/+ "words-labels.txt");
~pt = ~pt.do { |pt| #[0, 1, 3, 4].do { |i| pt[i] = pt[i].asFloat } };
SoundFile.use(~dir +/+ "words-mono.aiff", { |file| ~voxdur = file.duration });

SynthDef(\lpc1, { |outbus, lpcbuf, voxdur = 1, start, end = 1, time = 1, amp = 1, freq = 440|
	var	pos = Line.kr(start, end, time) / voxdur,
	lpcv = LPCVals.ar(lpcbuf, pos),
	src = Saw.ar(freq * [1, 1.003]).sum,
	noise = PinkNoise.ar(lpcv[2] * 8),
	sig = LPCSynth.ar(lpcbuf, src+noise, pos, amp * lpcv[1]),
	eg = EnvGen.kr(Env.linen(0.01, time - 0.05, 0.04), doneAction: 2);
	Out.ar(outbus, sig * eg);
}).add;

p = ~pt.choose;
a = m.play(\lpc1, [lpcbuf: ~lpcb, start: p[0] / ~voxdur, end: p[1] / ~voxdur, time: p[1] - p[0], amp: 1]);
a.free;

TempoClock.tempo

p = m.play(
	Pbind(
		\instrument, \lpc1,
		\pt, Prand(~pt, inf),
		#[start, end], Pkey(\pt),	// ignores extra vals
		\time, Pkey(\end) - Pkey(\start),
		\amp, 1,
		\voxdur, ~voxdur,
		\delta, Pkey(\time).roundUp(0.25),
		\freq, Pexprand(200.0, 600.0, inf)
	)
);

p.stop;


o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m|
	s.sendMsg(\n_trace, m[1]); r.remove;
}).add;
