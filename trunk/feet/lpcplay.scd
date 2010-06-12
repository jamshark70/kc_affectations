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
x.saveToFiles("/Users/dewdrop/sounds/spoken/quantum-5sec-2.lpc");
x = nil;

x.lperr; x.lppch; x.lprms;
x.resrms.plot
x.pchcps.plot

LPCAna.browse
