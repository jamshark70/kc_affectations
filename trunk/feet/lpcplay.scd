// =====================================================================
// SuperCollider Workspace
// =====================================================================

Help.gui;
EmacsInterface

Object.browse

Dialog.getPaths { |path| p = path[0].postcs };
p

\makeEmptyMixer8.eval;
m = MixerChannel(\test, s, 1, 2);
m => MCG(0);

b = LPCFile("/Users/dewdrop/sounds/spoken/quantum-5sec.lpc").loadToBuffer;
s.bufferAllocator.debug
b.buffer
Buffer(s, 1, 1, b.buffer).free

o = OSCresponderNode(s.addr, '/b_info', { |t, r, m| m.postln; r.remove; }).add;
s.sendMsg(\b_query, 0);
s.sendMsg(\b_query, 1);
o.remove;
s.bufferAllocator.free(0);

c.free
c = Buffer.readAndQuery(s, "/Users/dewdrop/sounds/fx/water/L_7304__ingeos___stream_underwater_Ruisseau_de_Ponchale_Les_Peyroux_23_St_Goussaud_France.aiff");

a = m.play { |outbus|
	var cps, rmso, err, voc, noise, timepoint, sig;
	timepoint = LFSaw.ar(Line.kr(1, 0.5, 20)/b.sndDur, 1, 0.5, 0.5);
	# cps, rmso, err = LPCVals.kr(b.buffer, timepoint);
	// a periodic Blip to filter, amplitude is 1 - error
	noise = PinkNoise.ar(err * 0.05); // a noise source
//	voc = Saw.ar(Line.kr(440, 100, 20) * [1, 1.002]).sum * 0.25;
	voc = PlayBuf.ar(1, c, loop: 1);
	// the rms values tend to be high... scale them back quite a bit!
	sig = LPCSynth.ar(b.buffer, voc + noise, timepoint, mul: 1 /*rmso*/);
	Out.ar(outbus, Limiter.ar(sig * 20.dbamp));
};

a.trace;

a.free;

m.stopRecord;

s.queryAllNodes;
s.sendMsg(\n_free, 1006);

PeakMonitor(m)

b.free
LPCAna

b.free;
b = Buffer.readAndQuery(s, p, numFrames: 44100*5);
b.write(p.splitext[0] ++ "-5sec.aiff", sampleFormat: "int16");

"/Users/dewdrop/sounds/spoken/quantum-5sec.aiff"
x = LPCAna("/Users/dewdrop/sounds/spoken/quantum-5sec.aiff");
x.ana(nPoles: 64, frameSize: 256, hop: 0.5, minFreq: 70, maxFreq: 400, conditionSignal: 1, completion: { "done".debug });
x.saveToLPCFile(p.splitext[0] ++ "-5sec.lpc");
x.saveToFiles("/Users/dewdrop/sounds/spoken/lpc/kcfeet.lpc");
x = nil;

x.lperr; x.lppch; x.lprms;
x.resrms.plot
x.pchcps.plot

LPCAna.browse


// basic recording
// air - earth - fire - water - grass - trees - worms - eagles - mountains - waterfalls - glaciers - plains - oceans
PeakMonitor(m);
z = m.play { In.ar(8, 1) };
m.startRecord("~/sounds/spoken/kcfeet.aiff".standardizePath);
m.stopRecord;
z.free;
m.free;

fork { SoundFile.normalize(a = "~/sounds/spoken/kcfeet.aiff".standardizePath, a.splitext[0] ++ "-norm.aiff", newSampleFormat: "int16", threaded: true); };

x = LPCAna("~/sounds/spoken/kcfeet-mono.aiff".standardizePath);
x.ana(nPoles: 32, frameSize: 256, hop: 0.5, minFreq: 70, maxFreq: 300, conditionSignal: 1, completion: { "done".debug });


// use lpc
// path == TEMPORARY!
~dir = "~/sounds/spoken/lpc".standardizePath;

~lpcb.free;
~lpcb = Buffer.readAndQuery(s, ~dir +/+ "kcfeet.lpc.aif");
b = ~lpcb;

c = Buffer.readAndQuery(s, "/Users/dewdrop/sounds/fx/water/L_7304__ingeos___stream_underwater_Ruisseau_de_Ponchale_Les_Peyroux_23_St_Goussaud_France.aiff");

~pt = TabFileReader.read(~dir +/+ "kcfeet-labels.txt");
~pt = ~pt.do { |pt| 2.do { |i| pt[i] = pt[i].asFloat } };

f = SoundFile.openRead(~dir +/+ "kcfeet-mono.aiff"); f.close;

z = m.play { PlayBuf.ar(1, c, loop: 1) };

p = ~pt.choose;

SynthDef(\lpcfx, { |outbus, lpcbuf, sfdur, start, end, time = 1, amp = 8|
	var cps, rmso, err, voc, noise, timepoint, sig, wet;
	timepoint = Line.kr(start, end, time) / sfdur;
	# cps, rmso, err = LPCVals.kr(lpcbuf, timepoint);
	noise = PinkNoise.ar(err * 0.05);
	voc = In.ar(outbus, 1);
	sig = LPCSynth.ar(lpcbuf, voc + noise, timepoint, mul: rmso);
	wet = EnvGen.kr(Env.linen(0.2, time - 0.4, 0.2), doneAction: 2);
	XOut.ar(outbus, wet, sig * amp);
//	ReplaceOut.ar(outbus, Limiter.ar(sig * amp));
}).add;


q = Pbind(
	\instrument, \lpcfx,
	\group, m.effectgroup,
	\outbus, m.inbus,
	\lpcbuf, ~lpcb,
	\sfdur, f.duration,
	#[start, end], Prand(~pt.flop[0..1].flop, inf),
	\time, 5,
	\amp, 8
).asStream;

z = m.play { PlayBuf.ar(1, c, loop: 1) };

e = q.next(()).play;
{ s.sendMsg(\n_trace, e[\id][0]) }.defer(0.5);

z.free;


// analysis seems too volatile
LPCFile.browse
