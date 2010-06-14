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
//~dir = "~/sounds/spoken/lpc".standardizePath;
~dir = Document.current.path.dirname.dirname +/+ "samples/feet";

~lpcb.free;
~lpcb = Buffer.readAndQuery(s, ~dir +/+ "words-lpf3-lpc.aiff");
b = ~lpcb;

c.free;
c = Buffer.readAndQuery(s, ~dir +/+ "L_7304__ingeos___stream_underwater_Ruisseau_de_Ponchale_Les_Peyroux_23_St_Goussaud_France.aiff");

~pt = TabFileReader.read(~dir +/+ "words-labels.txt");
~pt = ~pt.do { |pt| 2.do { |i| pt[i] = pt[i].asFloat } };

f = SoundFile.openRead(~dir +/+ "words-mono.aiff"); f.close;

z = m.play { PlayBuf.ar(1, c, loop: 1) };

p = ~pt.choose;

SynthDef(\lpcfx, { |outbus, lpcbuf, sfdur, start, end, time = 1, amp = 8|
	var cps, rmso, err, voc, noise, timepoint, sig, wet, peak;
	timepoint = Line.kr(start, end, time) / sfdur;
	# cps, rmso, err = LPCVals.kr(lpcbuf, timepoint);
	noise = PinkNoise.ar(err * 0.05);
	voc = In.ar(outbus, 1);
	sig = LPCSynth.ar(lpcbuf, voc + noise, timepoint, mul: rmso) * amp;
	peak = Peak.kr(sig);
//peak.poll(Impulse.ar(5));
	wet = EnvGen.kr(Env.linen(0.2, time - 0.4, 0.2), doneAction: 2);
Poll.kr(Done.kr(wet), peak, "peak", 1);
	XOut.ar(outbus, wet, sig);
//	ReplaceOut.ar(outbus, Limiter.ar(sig * amp));
}).add;


q = Pbind(
	\instrument, \lpcfx,
	\group, m.effectgroup,
	\outbus, m.inbus,
	\lpcbuf, ~lpcb,
	\sfdur, f.duration,
	\pt, Pseq(~pt, 1).trace,
	#[start, end], Pkey(\pt).collect { |pt| pt[0..1] },
	\time, 5,
	\amp, 2
).asStream;

z = m.play { PlayBuf.ar(1, c, loop: 1) };

e = q.next(()).put(\amp, 4).play;
{ s.sendMsg(\n_trace, e[\id][0]) }.defer(0.5);

l = List.new;
o.remove;
o = OSCresponderNode(s.addr, '/tr', { |t, r, m| l.add(m[3]) }).add;

1.4006985425949, 1.2204302549362, 1.6174520254135, 0.52945500612259, 0.77074950933456, 0.6013805270195, 0.36621832847595, 0.57746821641922, 1.219409942627, 0.96967452764511, 0.33334475755692, 0.50978434085846, 0.62868392467499

z.free;


// analysis seems too volatile
LPCFile.browse
x = LPCFile(~dir +/+ "words.lpc");

3.do { x.pchcps = x.pchcps.lowpass };
3.do { x.origrms = x.origrms.lowpass };
3.do { x.resrms = x.resrms.lowpass };
3.do { x.nrmerr = x.nrmerr.lowpass };

x.saveToFile(~dir +/+ "words-lpf3.aiff");
x.saveLPCFile(~dir +/+ "words-lpf3.lpc");


// fail

( 'instrument': lpcfx, 'time': 5, 'amp': 8, 'start': 19.727046, 
  'sustain': 0.8, 'server': localhost, 'isPlaying': true, 'hasGate': false, 'outbus': SharedBus(audio, 4, 2, localhost), 
  'id': [ 1011 ], 'group': Group(4), 'msgFunc': a Function, 'sfdur': 20.489841269841, 'lpcbuf': Buffer(0, 262144, 1, 164130416, /home/ddw1970/share/SuperCollider/scd/kc/trunk/samples/feet/words-lpf3-lpc.aiff), 
  'end': 20.32408, 'freq': 261.6255653006 )
Channel 0 maximum clip: 1.1445959338419e+18
Channel 1 maximum clip: 1.1445959338419e+18

~pt.detect { |pt| pt[0] == 19.727046 }