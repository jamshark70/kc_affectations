// filtering: needs to change ffreq when syncopation is active
// other kinds of syncopation

ChuckableBrowser.newWindow;
SynthDescLib.global.browse;
Object.browse;
s.queryAllNodes;

BP.loadGui;

Help.gui;

(thisProcess.nowExecutingPath.dirname.dirname +/+ "common/common-defs.scd").loadPath;

// run the lines separately or only this one, but not both
(thisProcess.nowExecutingPath.dirname +/+ "feet-defs.scd").loadPath;

MIDIPort.init([3]);  // linux, 2 for mac
MT(1).gui;
MIDIPort.resetAll;

(
[m, n].free;
m = MixerChannel(\test1, s, 1, 2);
n = MixerChannel(\test2, s, 2, 2);
//MixingBoard(\test, nil, m, n);

b = MixingBoard.new;
8.do { |i|
	MixerChannelGUI.new(nil, b) => MCG.prNew(i);
	if(MIDIPort.initialized) {
		MixerMIDIControl(\omni, nil, MCG(i).v);
	};
	b.add(MCG(i).v);
};

m => MCG(0); n => MCG(1);
~master !? { ~master => MCG(7) };

{ MixingBoard.at(0).refresh }.defer(3.0);
)

MixingBoard.at(0).refresh;

// in case I forgot to init midi first
8.do { |i| MixerMIDIControl(\omni, nil, MCG(i).v); };




Dialog.getPaths({ |path| p = path });
p = p[0];

p = (if(thisProcess.platform.name == \osx) {
	"/Users/dewdrop/SCServer/trax/kcgit/trunk/samples/feet"
//	"/Users/dewdrop/sounds/fx/footsteps"
} {
//	"/media/DLM/trax/kc/samples/feet"
	thisProcess.nowExecutingPath.dirname.dirname +/+ "samples/feet"
}) +/+ "58454_sinatra314_footsteps_wooden_floor_loop.wav";

b = Buffer.readAndQuery(s, p);
b.numChannels

b = Buffer(s, nil, nil, 0);
b.updateInfo;

// wet should be fairly low, < -0.8
(
a = m.play(
	Instr("test1", { |bufnum, freq, decay = 0.1, wet = -1|
		var sig = PlayBuf.ar(1, bufnum, BufRateScale.ir(bufnum), loop: 1),
			kl = DynKlank.ar(`[
				({ ExpRand(1.0, 5.0) } ! 5) * freq,
				0.2 ! 5,
				decay ! 5
			], sig);
			//kl = Ringz.ar(sig, freq, decay);
		XFade2.ar(sig, Limiter.ar(kl), wet)
	}, [\mybuf, \freq, #[0.01, 5, \exp], \bipolar]),
	[b]
);
a.gui;
)

m.scope

c = Buffer.readAndQuery(s, "~/share/sc-svn/common/build/sounds/a11wlk01.wav".standardizePath);

// maybe...
a = m.play {
	var	s1 = PlayBuf.ar(1, b, BufRateScale.ir(b), loop: 1),
	s2 = PlayBuf.ar(1, c, BufRateScale.ir(c), loop: 1);
	Convolution.ar(s2, s1)
};

a.free;


// get tempo from beat track? nope, not accurate enough
a = m.play {
	var	sig = PlayBuf.ar(1, b, BufRateScale.ir(b), loop: 1),
	fft = FFT(LocalBuf(1024, 1), sig),
	trackb, trackh, trackq, tempo;
	#trackb, trackh, trackq, tempo = BeatTrack.kr(fft);
	tempo.poll(trackb, "tempo");
	(SinOsc.ar(220) * Decay2.kr(trackb, 0.01, 0.1)) + sig
};

a.free;


// read labels set in audacity
~pt = TabFileReader.read(b.path.dirname +/+ "58454_labels.txt");

~pt = TabFileReader.read(p.dirname +/+ "58454_labels.txt");
~pt = ~pt.flop[0].asFloat;
~ptd = ~pt.differentiate.drop(1);
~mean = ~ptd.mean;

~evenpts = Array.series(~ptd.size, ~pt[1], ~mean);
~error = ~evenpts - ~pt[1..];
~error.mean

// write exact points out to audacity label file
f = File(p.dirname +/+ "58454_labels2.txt", "w");
([
	{ |i| "t" ++ i } ! ~ptd.size,
	~pt[1..]
].flop ++ [
	{ |i| "e" ++ i } ! ~ptd.size,
	~evenpts
].flop)
.sort({ |a, b| a[1] < b[1] })
.do({ |row|
	f << ("%\t%\t%\n".format(row[1], row[1], row[0]))
});
f.close;

// peaks for ~pt -- need early peak AND on-the-spot peak
~pt = TabFileReader.read(BP(\op).sfpath.dirname +/+ "58454_labels4.txt");
~pt.do { |row|
	2.do { |i| row[i] = row[i].asFloat }
};

Pprotect(
	Pfset(
		{
			o = OSCresponderNode(s.addr, '/tr', { |t, r, m|
				i = m[2] % 100;
				j = 3 + (m[2] >= 100).binaryValue;
				~pt[i] = ~pt[i].extend(max(j+1, ~pt[i].size)).put(j, m[3]);
			}).add;
		},
		Pbind(
			\instrument, \returnPeak,
			\bufnum, BP(\st).buffers[0],
			\start, (Pstutter(2, Pseq(~pt.flop[0], 1)) - Pseq(#[0.15, 0], inf)) * 44100,
			\frames, 22050,
			\trigid, Pseries(0, 1, inf) +.x Pseq(#[0, 100], 1),
			\delta, 0.1
		),
		{
			{ o.remove; "done".postln }.defer(0.8)
		}
	),
	{ o.remove }
).play;

~pt.do(_.postln); ""
(BP(\op).sfpath.dirname +/+ "58454_lab*").pathMatch

(Pseries(0, 1, inf) +.x Pseq(#[0, 100], 1)).asStream.nextN(20)

f = File(BP(\op).sfpath.dirname +/+ "58454_labels5.txt", "w");
~pt.do { |row|
	row.do { |item, i|
		if(i > 0) { f << $\t };
		f << item;
	};
	f << Char.nl;
};
f.close;

f.path
(BP(\op).sfpath.dirname +/+ "58454_labels3.txt").openDocument;

OSCresponder.all.detect({ |o| o.cmdName == '/tr' }).nodes.copy.do(_.remove);

p = m.play(
	Pbind(
		\instrument, \bufGrain,
		\bufnum, b,
		\time, ~mean * 4,
		\delta, Pkey(\time),
		\amp, 1
	)
);

TempoClock.default.tempo = ~mean.reciprocal;
TempoClock.default.tempo = 110 / 60;
TempoClock.default.gui;

// is this right? playing the footsteps faster?
// seems like it makes more sense that way
p = m.play(
	Pbind(
		\instrument, \bufGrain,
		\bufnum, b,
		\delta, 1, // 0.69704989285714,  // 0.69... == ~ptd.mean
		\time, Pkey(\delta) / Ptempo(),
		\rate, Pseq(~ptd, inf) / ~mean, // * (110/86),
		\attack, 0.005,
// 		\start, (Pseq(~pt[1..], inf) - Pkey(\attack)) * b.sampleRate,
		\start, (Pseq(~pt[1..], inf) - (0.25 * Pkey(\rate))) * b.sampleRate,
		\amp, 4
	),
	(quant: #[1, -0.25])
);

SynthDef(\singrain, { |outbus, freq = 440, amp = 1, time = 1, pan = 0|
	Out.ar(outbus, Pan2.ar(SinOsc.ar(freq, 0, amp) * EnvGen.kr(Env.perc(0.01, time), doneAction: 2), pan));
}).add;

// happy with this
p = n.play(
	Ptpar([
		0, Pbind(
			\instrument, \bufGrainPan,
			\bufnum, b,
			\delta, 1/3, // 0.69704989285714,  // 0.69... == ~ptd.mean
			\time, Pkey(\delta) / Ptempo(),
			\rate, Pseq(~ptd, inf) / ~mean * 3, // * (110/86),
			\attack, 0.005,
			// 		\start, (Pseq(~pt[1..], inf) - Pkey(\attack)) * b.sampleRate,
			\start, (Pseq(~pt[1..], inf) - (0.18 / Ptempo() * Pkey(\rate))) * b.sampleRate,
			\amp, 1,
			\pan, -1
		),
		0.18, Pbind(
			\instrument, \singrain,
			\amp, 1,
			\time, 0.15,
			\freq, 880,
			\pan, 1
		)
	]),
	(quant: #[1, -0.18])
);

p.stop;

Pbindf(Ptpar([
	0, Pbind(
		\instrument, \bufGrainPan,
		\bufnum, b,
		\delta, 1, // 0.69704989285714,  // 0.69... == ~ptd.mean
		\time, Pkey(\delta) / Ptempo(),
		\rate, 1, // Pseq(~ptd, inf) / ~mean, // * (110/86),
		\attack, 0.005,
		// 		\start, (Pseq(~pt[1..], inf) - Pkey(\attack)) * b.sampleRate,
		\start, (Pseq(~pt[1..], inf) - (0.25 / Ptempo() * Pkey(\rate))) * b.sampleRate,
		\pan, -1,
		\amp, 1
	),
	0.25, Pbind(
		\instrument, \singrain,
		\amp, 1,
		\time, 0.15,
		\freq, 880,
		\pan, 1
	)
]), \outbus, Pkey(\out)).record(b.path.dirname +/+ "tempo-test3.aiff", dur: 20);

s.queryAllNodes;
s.sendMsg(\n_trace, 1221);

m.scope

p.isPlaying


p = n.play(
	Pbind(
		\instrument, \bufGrainPan,
		\bufnum, b,
		\delta, 1,
		\time, Pkey(\delta) / Ptempo(),
		// random indices, but a value must not repeat either of the previous 2
		\i, Penvir(
			(prev: nil ! 2, index: 0),
			Pwhite(0, ~ptd.size - 1, inf).reject { |x|
				var	test = ~prev.includes(x);
				~prev[~index] = x;
				~index = (~index + 1) % ~prev.size;
				test
			}
		).clump(3),
		\rate, Pindex(~ptd, Pkey(\i), inf) / ~mean, // Pseq(~ptd, inf) / ~mean, // * (110/86),
		\attack, 0.005,
// 		\start, (Pseq(~pt[1..], inf) - (0.25 / Ptempo() * Pkey(\rate))) * b.sampleRate,
		\start, (Pindex(~pt[1..], Pkey(\i), inf) - (0.25 / Ptempo() * Pkey(\rate))) * b.sampleRate,
		\amp, 1,
		\pan, #[-1, 0, 1],
		\lag, Pwhite(0.0, 0.03, inf).clump(3)
	)
);

p.stop;


// pr: manage rhythmic counterpoint
// user's responsibility to make sure leadTime = 0.5 * maxLag * tempo
(
SynthDef(\bufGrainPanFilt, { |start, time, bufnum, pan, rate = 1, amp = 1,
		attack = 0.001, decay = 0.02, outbus, ffreq = 2000|
	var sig;
	sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
		* EnvGen.kr(Env.linen(attack, time, decay), doneAction:2);
	sig = LPF.ar(sig, ffreq);
	Out.ar(outbus, Pan2.ar(sig, pan, amp));
}).add;

PR(\abstractProcess).clone {
	~event = (eventKey: \singleSynthPlayer);
	~quant = #[1, -0.25].asTimeSpec;
	~alwaysReset = true;	// supports changes in ~numWalkers while stopped
	~def = \bufGrainPanFilt;

	~prep = {
		~chan = MixerChannel(~collIndex, s, 2, 2);
		~path = (if(thisProcess.platform.name == \osx) {
			"/Users/dewdrop/SCServer/trax/kcgit/trunk/samples/feet"
//			"/Users/dewdrop/sounds/fx/footsteps"
		} {
			"/media/DLM/trax/kc/samples/feet"
		}) +/+ "58454_sinatra314_footsteps_wooden_floor_loop.wav";
		~buf = Buffer.readAndQuery(s, ~path);

		~pt = TabFileReader.read(~path.dirname +/+ "58454_labels.txt").flop[0].asFloat;
		~ptd = ~pt.differentiate.drop(1);
		~pt = ~pt.drop(1);
		~mean = ~ptd.mean;

		currentEnvironment
	};

	~freeCleanup = {
		[~chan, ~buf].free;
	};

	~lastEventTime = 0;
	~lastItems = IdentitySet.new;

	~numWalkers = 3;
	~numWalkers_ = { |numW|
		~numWalkers = numW;
		if(BP(~collIndex).isPlaying) {
			"BP(%): numWalkers changed, but won't take effect until after stopping."
				.format(~collIndex.asCompileString).warn;
		};
		currentEnvironment
	};

	~gestures = (
		one: { |i| Pbind(\delta, 1, \amp, ~amp.(i), \ffreq, ~loFilt) },
		halfSyncop: { |i, parms|
			Pbind(
				\delta, Pseq([Pn(1, parms[\preSyncop]), 1.5, Pn(1, inf)], 1),
				\amp, ~amp.(i),
				\ffreq, Pseq([Pn(~loFilt, parms[\preSyncop]), Pn(~hiFilt, inf)], 1)
			)
		},
		triplet4: { |i, parms|
			Pbind(
				\delta, Pseq([Pn(1, parms[\preSyncop]), Pn(2/3, inf)], 1),
				\amp, ~amp.(i),
				\ffreq, Pseq([Pn(~loFilt, parms[\preSyncop]), Pn(~hiFilt, inf)], 1)
			)
		}
	);

	~loFilt = 2400;
	~hiFilt = 18000;
	~index = Plazy { Pwhite(0, ~ptd.size - 1, inf) };
	~delta = { |key, parms|
		Plazy { ~deltas[key].(parms).asPattern }
	};
	~rate = 1.25;
	~eventLag = Pwhite(0.0, 0.03, inf);

	~pan = { |i|
		if(~numWalkers > 1) {
			i.linlin(0, ~numWalkers - 1, -1, 1)
		} {
			0
		}
	};

	~amp = 1;

	~oneWalkerPattern = { |gesture, i, parms|
		Pbind(
			\time, Pif(Pfunc { |ev| ev[\time].isNil },
				min(1, Pkey(\delta)) / Ptempo(),
				Pkey(\time)
			)
		)
		<>
		~gestures[gesture].value(i, parms)
		<>
		Pbind(
			\instrument, ~def,
			\bufnum, ~buf,
			// random indices, but a value must not repeat any chosen at the current timepoint
			\i, BPStream(\index).reject { |x|
				if(thisThread.clock.beats == ~lastEventTime) {
					if(~lastItems.includes(x)) {
						true
					} {
						~lastItems.add(x);
						false
					}
				} {
					~lastItems.clear.add(x);
					// this needs to be set only when the two are not equal
					// and that happens only in this false branch
					~lastEventTime = thisThread.clock.beats;
					false
				};
			}, // .collect { |x| x.debug(thisThread.clock.beats.asString); x },
			\rate, Pindex(~ptd, Pkey(\i), inf) / ~mean * BPStream(\rate),
			\attack, 0.005,
			// note, phase is expected to be -1..0 so '+' really subtracts
			\start, (Pindex(~pt, Pkey(\i), inf) + (BP(~collIndex).quant.phase / Ptempo() * Pkey(\rate))) * ~buf.sampleRate,
			\lag, BPStream(\eventLag),
			\chan, ~chan,

			\pan, ~pan.(i)
		)
	};

	~dur = Pwhite(18, 30, inf);
	~preSync = Pwhite(0.3, 0.6, inf);
	~whichSync = Pif(Pfunc { ~numWalkers > 1 },
		Pwhite(0, Pfunc { ~numWalkers - 1 }, inf), -999, -999);

	~asPattern = {
		~durStream ?? { ~makeStreamForKey.(\dur) };
		~preSyncStream ?? { ~makeStreamForKey.(\preSync) };
		~whichSyncStream ?? { ~makeStreamForKey.(\whichSync) };
		PnNilSafe(Plazy {
			var	dur = ~durStream.next,
				preSyncop = (dur * ~preSyncStream.next(dur)).roundUp(1),
				parms = (dur: dur, preSyncop: preSyncop),
				whichSyncop = ~whichSync.next(parms);
			parms.put(\whichSyncop, whichSyncop);
			Pfindur(dur, Ppar(
				{ |i|
					~oneWalkerPattern.(
						if(i == whichSyncop) { #[halfSyncop, triplet4].choose } { \one },
						i,
						parms
					)
				} ! ~numWalkers
			))
		}, inf)
	};
} => PR(\steps1);
)

BP(\st).free;
PR(\steps1) => BP(\st);
BP(\st) => MCG(2);
BP(\st).leadTime = 0.015 * (110/60);

#[1, -0.18].asTimeSpec.wrap_(true) => BP(\st);
BP(\st).quant.phase

BP(\st).play(doReset: true);
BP(\st).stop;

BP(\st).isPlaying
BP(\st).eventLag = 0;

PeakMonitor(BP(\st).chan)

// why does #1 sound late when it's syncopated?
BP(\st).delta = { |i|
	if(i == 1) { Pseq([Pn(1, { rrand(8, 16) }), 1.5], inf) }
	{ 1 }
};

BP(\st).amp = 1;

BP(\st).numWalkers = 1;
BP(\st).delta = Pseq([Pn(1, { rrand(8, 16) }), 1.5], inf);
BP(\st).normPan = BP(\st).v[\panForWalker];
BP(\st).panForWalker = -1;
BP(\st).eventLag = 0;

(
BP(\st).play;

z = n.play(
	Pbind(
		\instrument, \singrain,
		\freq, Pseq(#[440, 880], inf),
		\delta, 0.5,
		\time, 0.15,
		\amp, Pseq(#[1, 0.4], inf),
		\pan, 1
	),
	(quant: 1)
);
)

z.stop; BP(\st).stop;

(
t = TLSequenceIterator([
	bpCmd: (name: \st, dur: 45, prepareBP: { |bp|
		bp.numWalkers = 1;
	}),
	\sync,
	12,
	bpCmd: (name: \st, dur: 45, prepareBP: { |bp|
		bp.numWalkers = 2;
	}),
	\sync,
	12,
	bpCmd: (name: \st, dur: 45, prepareBP: { |bp|
		bp.numWalkers = 3;
	})
]).play
)

t.stop;

BP(\st).gestures.halfSyncop = { |i, parms|
			Pbind(
				\delta, Pseq([Pn(1, parms[\preSyncop]), 1.5, Pn(1, inf)], 1),
				\time, min(1, Pkey(\delta)) / Ptempo(),
				\amp, ~amp.(i),
				\ffreq, Pseq([Pn(~loFilt, parms[\preSyncop] + 1), Pn(~hiFilt, inf)], 1)
			)
		};
BP(\st).gestures.one = { |i| Pbind(\delta, 1, \time, min(1, Pkey(\delta)) / Ptempo(), \amp, ~amp.(i), \ffreq, ~loFilt) };

BP(\st).loFilt = 2000;

BP(\st).asPattern = {
		PnNilSafe(Plazy {
			var	dur = rrand(18, 32),
				preSyncop = (dur * rrand(0.3, 0.6)).roundUp(1),
				whichSyncop = if(~numWalkers > 1) { ~numWalkers.rand } { -999 },
				parms = (preSyncop: preSyncop, whichSyncop: whichSyncop);
			Pfindur(dur, Ppar(
				{ |i|
					~oneWalkerPattern.(
 						if(i == whichSyncop) { #[halfSyncop, triplet4].choose } { \one },
// 						if(i == whichSyncop) { \halfSyncop } { \one },
						i,
						parms
					)
				} ! ~numWalkers
			))
		}, inf)
	};
BP(\st).numWalkers = 3;

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;

n.play(\bufGrainPanFilt, [start: [430909, 0, 0, 0, 1.31545, 1, 0.005, 0.02, 20, 18000]]);
n.play(\bufGrainPanFilt, [start: [528490, 0, 0, 0, 1.31443, 1, 0.005, 0.02, 20, 1200]]);

SynthDescLib.at(\bufGrainPanFilt).msgFunc.postcs

BasicTimeSpec


PeakMonitor(n);

// not quite the right effect
a = n.play {
	var	initTrig = Impulse.kr(0),
		tdur = Select.kr(initTrig, [LocalIn.kr(1), Rand(0.04, 0.06)]),
		trig = Impulse.kr(tdur.reciprocal);
	tdur = TExpRand.kr(0.03, 0.07, trig);
	LocalOut.kr(tdur);
	TGrains.ar(2, trig, b, 110/60, Line.kr(0, b.duration, b.duration * 5), dur: tdur * 20, pan: TRand.kr(-1, 1, trig), amp: 0.8)
};

a.trace;

a.free;

// not bad
SynthDef(\bufGrainPanComb, { |start, time, bufnum, pan, rate = 1, amp = 1,
		attack = 0.001, decay = 0.02, outbus, ffreq = 2000, combdecay = 0.1|
	var sig;
	sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
		* EnvGen.kr(Env.linen(attack, time, decay));
	sig = Limiter.ar(CombL.ar(LeakDC.ar(sig), 0.06, ffreq.reciprocal, combdecay));
	DetectSilence.ar(sig, 0.001, doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, amp));
}).add;

a = n.play(\bufGrainPanComb, [time: 5, bufnum: b, ffreq: 300, combdecay: 0.2]);
a.trace;

// really want something to smear the attacks
// pv_bufrd?
// lores (frame=256) is wicked ugly! maybe nice transition to water sounds
// plus partial/noise synths, with narrow thresholds, get watery
b = BP(\st).buf;

c.free;
f = 256;
c = Buffer.alloc(s, b.duration.calcPVRecSize(f, 0.25));

a = {
	var	sig = PlayBuf.ar(1, b, BufRateScale.kr(b), 1, 0, 0),
		fft = FFT(LocalBuf(f, 1), sig, 0.25, 1),
		stop = Line.kr(0, 1, b.duration, doneAction: 2);
	PV_RecordBuf(fft, c, run: 1, hop: 0.25, wintype: 1);
	stop.poll(Done.kr(stop), "over");
	Silent.ar(1)
}.play;

a.trace;

// pv partial synth - strip transient bins - OK but too "bad pv"-ish
// magsmear makes it more "clicky"
~lo = 1; ~hi = 7; ~mid = 1.32432;
SynthDef(\test, { |thresh = 1, outbus|
 	var	//fft = PV_PlayBuf(LocalBuf(256, 1), c, loop: 1); //,
//		pos = Phasor.kr(0, SampleRate.ir * ControlDur.ir, 219163, 247803, 219163) / b.numFrames,
		pos = Phasor.kr(0, SampleRate.ir * ControlDur.ir, 0, b.numFrames, 0) / b.numFrames,
		fft = PV_BufRd(LocalBuf(f, 1), c, pos),
		fft2 = PV_Copy(fft, LocalBuf(f, 1)),
		// most of this crap will be calculated in the client first,
		// but I wrote it this way for testing and see no need to change it
		// it does basically the same thing as a CurveWarp
		// it's to map the exponential threshold range 0.01 .. 1.0
		// onto an amplitude compensation curve
		lo = ~lo, hi = ~hi, midval = ~mid,
		ga = midval - lo,
		gb = lo - hi,
		gc = hi - midval,
		sqrterm = sqrt(gb.squared - (4 * ga * gc)),
		qresult = (sqrterm - gb) / (2 * ga),
		grow = if(qresult.rate == \scalar) {
			if(qresult.abs == 1.0) {
				((gb.neg - sqrterm) / (2 * ga)).squared
			} {
				qresult.squared
			};
		} {
			Select.kr(BinaryOpUGen('==', qresult.abs, 1.0), [qresult.squared, ((gb.neg - sqrterm) / (2 * ga)).squared])
		},
		x = (thresh.log / 0.01.log),
		curveA = (hi-lo) / (1.0 - grow),
		curveB = lo + curveA,
		ampComp = curveB - (curveA * pow(grow, x)),
		threshScale = (SampleRate.ir * 0.5 / f);
// 		ampComp = 1; // ((thresh.reciprocal.log / 100.log) * 12).dbamp;
	fft = PV_PartialSynthF(fft, thresh * threshScale, numFrames: 2);
	fft2 = PV_PartialSynthF(fft2, thresh.linlin(0.01, 1, 0.005 * threshScale, 0), numFrames: 2);
	fft = PV_MagSubtract(fft, fft2);
	Out.ar(outbus, IFFT(fft, 1) * ampComp);
}, metadata: (specs: (thresh: #[0.01, 1, \exp], outbus: [0, 128, \lin, 1, m.inbus], midval: [~lo, ~lo+~hi*0.5, \lin, 0, (~hi-~lo)*0.25 + ~lo]))).add;

7.ampdb

SynthDescLib.at(\test).makeGui;

s.queryAllNodes;
s.sendMsg(\n_trace, 1006);

// turn it into an effect
// stereo ffts... urgh
~lo = 1; ~hi = 7; ~mid = 1.32432;
~numfr = 256;

{	|name = \waterfx, numCh = 2, numFr = 256, lo = 1, hi = 7, mid = 1.32432|
	SynthDef(name, { |thresh = 1, wet = 1, outbus|
	 	var	sig = In.ar(outbus, numCh), sig2,
			fft = FFT({ LocalBuf(numFr, 1) } ! numCh, sig, 0.25, 1),
			fft2 = PV_Copy(fft, { LocalBuf(numFr, 1) } ! numCh),
			// most of this crap will be calculated in the client first,
			// but I wrote it this way for testing and see no need to change it
			// it does basically the same thing as a CurveWarp
			// it's to map the exponential threshold range 0.01 .. 1.0
			// onto an amplitude compensation curve
			ga = mid - lo,
			gb = lo - hi,
			gc = hi - mid,
			sqrterm = sqrt(gb.squared - (4 * ga * gc)),
			qresult = (sqrterm - gb) / (2 * ga),
			grow = if(qresult.rate == \scalar) {
				if(qresult.abs == 1.0) {
					((gb.neg - sqrterm) / (2 * ga)).squared
				} {
					qresult.squared
				};
			} {
				Select.kr(BinaryOpUGen('==', qresult.abs, 1.0), [qresult.squared, ((gb.neg - sqrterm) / (2 * ga)).squared])
			},
			x = (thresh.log / 0.01.log),
			curveA = (hi-lo) / (1.0 - grow),
			curveB = lo + curveA,
			ampComp = curveB - (curveA * pow(grow, x)),
			threshScale = (SampleRate.ir * 0.5 / f);
	// 		ampComp = 1; // ((thresh.reciprocal.log / 100.log) * 12).dbamp;
		fft = PV_PartialSynthF(fft, thresh * threshScale, numFrames: 2);
		fft2 = PV_PartialSynthF(fft2, thresh.linlin(0.01, 1, 0.005 * threshScale, 0), numFrames: 2);
		fft = PV_MagSubtract(fft, fft2);
		sig2 = IFFT(fft, 1) * ampComp;
		ReplaceOut.ar(outbus, XFade2.ar(sig, sig2, wet.madd(2, -1)));
	}, metadata: (specs: (thresh: #[0.01, 1, \exp], wet: \bipolar)));
} => Func(\makeWateryFx);

\makeWateryFx.eval(\waterfx).add;
a = m.playfx(\waterfx);
a.trace;
a.free;


(10.log / 100.log * 12).dbamp
{ |x| (x * 12).dbamp }.((0, 0.01 .. 1.0)).plot;

// t = 1, -7.3 dB
// t = 0.1, -10.17 dB
// t = 0.01, -17 dB
#[-7.3, -10.17, -17].dbamp.reciprocal

[1, 10, 100].log / 100.log
[1, 0.1, 0.01].log / 0.01.log
\growForCurve.eval(*(#[0, -6, -12].dbamp.reciprocal))

f = { |thresh|
	var	a, b, grow = 26.095725092341,
		lo = 1, hi = 7.0794578438414;
	thresh = thresh.reciprocal.log / 100.log;
	a = (hi-lo) / (1.0 - grow);
	b = lo + a;
	b = b - (a * pow(grow, thresh));
};

f.(1)
f.(0.01)
f.(0.1)

{ |minval, midval, maxval|
	var a, b, c, sqrterm, qresult, sgn = sign(maxval - minval);
		// the formula is unstable just above the average of minval and maxval
		// so mirror the midval around the average
	(midval > ((maxval + minval) * 0.5)).if({
		midval = minval + maxval - midval;
		sgn = sgn.neg;
	});
	a = midval - minval;
	b = minval - maxval;
	c = maxval - midval;
	sqrterm = sqrt(b.squared - (4 * a * c));
	(((qresult = (sqrterm - b) / (2 * a))).abs != 1).if({
		// note, NOT taking the log here
		// because the mapsynth would just have to .exp it
//		log(qresult.squared).abs * sgn
		qresult.squared * sgn
	}, {
		((b.neg - sqrterm) / (2 * a)).squared * sgn
	});
} => Func(\growForCurve);


PeakMonitor(m);

s.sendMsg(\n_trace, 10116)

// steps almost become like muffled speech?
a = m.play {
	var	fft = PV_BufRd(LocalBuf(f, 1), c, Line.kr(0, 1, 60, doneAction: 2));
	IFFT(fft, 1)
};

LFNoise1.kr(0.8).range()

a = m.play {
	var	pos = SinOsc.kr(0.01, 0, 0.48, 0.5),
		fft = PV_BufRd(LocalBuf(f, 1), c, pos);
	IFFT(fft, 1)
};

a.trace;
a.free;

SynthDef(\test, { |outbus = 16, stretch = 1, shift = 0|
	var	fft = PV_BufRd(LocalBuf(f, 1), c, Line.kr(0, 1, 60, doneAction: 2));
	fft = PV_MagShift(fft, stretch, shift);
	Out.ar(outbus, IFFT(fft, 1));
}, metadata: (specs: (stretch: #[0.25, 4, \exp], shift: #[0, 512, \lin, 1]))).add;

SynthDescLib.at(\test).makeGui;

c.getn(0, 50, _.postln);

c.free;

[c, d].free;

// convolution
c = Buffer.alloc(s, 32768, 1);

a = {
	var	eg = EnvGen.kr(Env(#[0, 1, 0], #[0.7, 0.3] * 0.5, #[2, -2]), doneAction: 2),
		sig = WhiteNoise.ar * eg;
// 		timer = Line.kr(0, 1, 3, doneAction: 2);
	RecordBuf.ar(sig, c, loop: 0);
	eg.poll(Done.kr(eg));
	Silent.ar(1)
}.play;

c.plot2;
c.getn(0, 20, _.postln);

// filesize 188893
c = Buffer.alloc(s, 188893.roundUp(2048), 1);
c.read("~/Applications/sc-emacs/common/build/sounds/a11wlk01.wav".standardizePath);
// after that, buf should be zero-padded

d = Buffer.alloc(s, PartConv.calcBufSize(2048, c), 1);
d.preparePartConv(c, 2048);

// awright, this is cool but 60% cpu???!! (down to 20% with 2048 fft framesize)
a = m.play {
// 	var	sig = PlayBuf.ar(1, b, BufRateScale.kr(b), 1, ~pt[1] * 44100 - 8000, 0)
// 			* EnvGen.kr(Env.perc(0.001, 0.3));
 	var	sig = PlayBuf.ar(1, b, BufRateScale.kr(b), 1, 0, 0);
// 	sig = Convolution2.ar(sig, c, framesize: c.numFrames.nextPowerOfTwo);
	sig = PartConv.ar(sig, 2048, d);
	DetectSilence.ar(sig, doneAction: 2);
	Limiter.ar(sig);
};

OSCpathResponder(s.addr, ['/n_go', a.nodeID], { |time, resp| a.trace; resp.remove }).add;

a.free;

Env(#[0, 1, 0], #[1, 2], #[-1, -2]).plot2;
a = m.play(\bufGrain, [bufnum: c, time: c.duration, amp: 1]);
a.trace;


// stacked allpass - nice
a = m.play {
 	var	sig = PlayBuf.ar(1, b, BufRateScale.kr(b), 1, 0, 0),
		ap = sig;
	10.do {
		ap = AllpassN.ar(ap, 0.05, Rand(0.02, 0.05), 0.4);
	};
	ap
};

a.free;


// stacked allpass - some comb-y effect but not as obvious as Comb
a = m.play { |delay = 0.03|
 	var	sig = PlayBuf.ar(1, b, BufRateScale.kr(b), 1, 0, 0),
		ap = sig;
	10.do {
		ap = AllpassN.ar(ap, 0.05, delay, 1);
	};
	ap
};

a.free;


// pv partial synth - strip transient bins - OK but too "bad pv"-ish
// magsmear makes it more "clicky"
SynthDef(\test, { |thresh = 0.1, outbus = 0|
 	var	sig = PlayBuf.ar(1, b, BufRateScale.kr(b), 1, 0, 0),
		fft = FFT(LocalBuf(2048, 1), sig);
//	fft = PV_NoiseSynthF(fft, thresh * SampleRate.ir * 0.5 / 2048, numFrames: 2);
 	fft = PV_NoiseSynthP(fft, thresh * pi, numFrames: 2);
//	fft = PV_MagSmear(fft, thresh * 1024);
	Out.ar(outbus, IFFT(fft));
}, metadata: (specs: (thresh: \unipolar))).add;

SynthDescLib.at(\test).makeGui;

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| a = Synth.basicNew(\test, s, m[1]) }).add;

a.trace;

PeakMonitor(0)


// avoid even harmonics in buf.cheby!!
SynthDef(\bufGrainPanKlank, { |start, time, bufnum, pan, rate = 1, amp = 1,
		attack = 0.001, decay = 0.02, outbus, ffreq = 2000, filtAttack = 0.1, filtDecay = 1.0,
		shapebuf = -1, shapeXf = 1, chorusFreq = 0.05, chorusAmt = 0.02, chorusDelay = 0.03,
		lpfreq = 2000, lprq = 1|
	var
// 		harm = \harm.kr((1..5)),
// 		amps = \amps.kr((1..5).reciprocal),
// 		decays = \decays.kr(1 ! 5),
harm = #[1, 4, 7, 10, 13],
amps = #[1, 3, 5, 7, 9],
decays = 1 ! 5,
		sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
			* EnvGen.kr(Env.linen(attack, time, decay)),
		// Klank(decay) - Klank(attack) is like a bank of Formlets
		filt = Klank.ar(`[harm, amps, decays], sig, freqscale: ffreq, decayscale: filtDecay)
			- Klank.ar(`[harm, amps, decays], sig, freqscale: ffreq, decayscale: filtAttack),
		shaped, dly, cfreqRand = chorusFreq * 0.2;
	sig = Limiter.ar(sig + filt);
	shaped = Select.ar(shapebuf < 0, [Shaper.ar(shapebuf, sig), sig]);
	sig = XFade2.ar(sig, shaped, shapeXf);
	dly = sig;
	3.do {
		dly = DelayL.ar(dly, chorusDelay + chorusAmt,
			SinOsc.kr(
				chorusFreq + Rand(cfreqRand.neg, cfreqRand),
				Rand(0, 2pi),
				chorusAmt, chorusDelay
			));
		sig = sig + dly;
	};
// 	sig = LeakDC.ar(sig);
	sig = RLPF.ar(sig, lpfreq, lprq);
	DetectSilence.ar(sig, 0.001, doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, amp));
}, metadata: (specs: (
	pan: \bipolar, rate: #[0.1, 10, \exp],
	attack: #[0.001, 1, \exp], decay: #[0.001, 1, \exp],
	ffreq: \freq,
	filtAttack: #[0.001, 1, \exp], filtDecay: #[0.001, 1, \exp],
	shapeXf: \bipolar,
	chorusFreq: #[0.001, 1, \exp], chorusAmt: #[0.001, 1, \exp], chorusDelay: #[0.001, 1, \exp],
	lpfreq: \freq, lprq: \myrq
))).add;

a = n.play(\bufGrainPanKlank, [start: ~pt.choose * 44100, time: 5.0, bufnum: b, ffreq: 100, filtAttack: 0.5, filtDecay: 1.0, harm: #[1, 4, 7, 10, 13], amps: #[1, 3, 5, 7, 9].reciprocal, shapebuf: -1]);

a = n.play(\bufGrainPanKlank, [start: ~pt.choose * 44100, time: 1.0, bufnum: b, ffreq: 100, filtAttack: 0.5, filtDecay: 1.0, harm: #[1, 4, 7, 10, 13], amps: #[1, 3, 5, 7, 9].reciprocal, shapebuf: c]);
a.trace;

SynthDescLib.at(\bufGrainPanKlank).makeGui;
b.duration
c

c = Buffer.alloc(s, 2048, 1);
c.cheby(#[1, 0, 1, 0, 1, 0, 1]);
c.cheby(#[1, 0, 1]);
c.plotWavetable

c.sine3(#[1], #[1], #[pi]);
c.sine3((1..5), (1..5).reciprocal.neg, 0 ! 5);
c.sine3((1..5), 1 ! 5, 0 ! 5);

c.cheby(Array.squareAmps(9))

a.free;

[1, 2, 4, 8].differentiate
// footsteps (swamp)

PR(\steps1).chuck(BP(\stw), nil, (
	bufPath: "16771__dobroide__20060307-comp1.swamp.wav",
	processLabels: {
		~pt = ~pt.collect { |row|
			2.do { |i| row[i] = row[i].asFloat };
			(pre: row[0], step: row[1], name: row[2])
		};
		~pts = ~pt.collect(_.step);
		~ptw = ~pts.select { |num, i| ~pt[i].name.contains("wet") };
//		~ptd = ~pts.differentiate.drop(1);
	},
	ratefix: 1,
	index: Plazy { Pwhite(0, ~pts.size - 1, inf) },
	start: Plazy { (Pindex(~pts, Pkey(\i), inf) + (Pfunc { BP(~collIndex).quant.phase } / Ptempo() * Pkey(\rate))) * ~buf.sampleRate }
));

BP(\stw).use { ~ptw = ~pts.select { |num, i| ~pt[i].name.contains("wet") } };
BP(\stw).index = Plazy { Prand(~pt.collectIndices { |it| it.name.contains("wet") }, inf) };



p = BP(\stw);
p.gsel = \unison;
p.gesture = \onept5stretch;
p.preSync = Pfunc { |dur| max(1, dur - rrand(5, 12)).postln };

p.gesture = \stepsStretch;
p.dur = Pseq([14, Pseries(3, Pwhite(1, 3, 5))]);
p.preSync = Pseq([10, Pn(0, inf)]);



// stop and turn
z = BP(\st).buffers[0];
~pt = BP(\st).pt;

i = (~pt.size - 1).rand;
t = 0.2;
a = m.play(\bufGrain, [bufnum: z, start: (~pt[i] + t) * 44100, time: t, rate: -1, amp: BP(\st).peaks[0][i].reciprocal].debug);

BP(\st).peaks.size
a.trace

PeakMonitor(m);


i = Pshuf((0..~pt.size-1), 1).asStream.nextN(5);
r = rrand(1.2, 1.8);
t = 0.2;
m.play((instrument: \bufGrain, bufnum: z, start: (~pt[i] + (t*r)) * 44100, time: t, rate: r.neg, amp: BP(\st).peaks[0][i].reciprocal / i.size));

r = 2;

y = BP(\op).pvbuf;
m.play((instrument: \pvplayPanC, pvbuf: y, startFrame: (~pt[i] + (t*r)) / z.duration * BP(\op).numPvFrames, time: t, rate: r.neg, amp: BP(\st).peaks[1][i].reciprocal * 20.dbamp, cwidth: 0.4, crate: 12));

p = n.play(
	Pbind(
		\instrument, \pvplayPanC,
		\pvbuf, y,
		\n, 3,
		\i, Pn(Pshuf(~pt, 1), inf).clump(Pkey(\n)),
		\pan, Pn(Pseries(-1, 2 / (Pkey(\n)-1), Pkey(\n).asStream), inf).clump(Pkey(\n)),
		\time, 0.25,
		\eTopRatio, 0.8,
		#[attack, decay], Ptuple([Pkey(\eTopRatio), 1 - Pkey(\eTopRatio)], inf) * Pkey(\time),
		\playspeed, Pwhite(1.2, 1.9, inf),
		\startFrame, (Pindex(~pt, Pkey(\i), inf) + (Pkey(\time) * Pkey(\playspeed))) * (BP(\op).numPvFrames / z.duration),
		\rate, Pkey(\playspeed).neg,
		\amp, Pindex(BP(\st).peaks[1], Pkey(\i), inf).reciprocal / Pkey(\n) * 20.dbamp,
		\cwidth, Pgeom.fromEndpoints(1.0, 0.3, 3),
// 		\crate, Pwhite(0.1, 2.5, inf),
// 		\crate, 0,
		\crate, Pgeom.fromEndpoints(0.1, 15, 3),
		\cphase, Pwhite(0.0, 0.98, inf),
		\delta, 1.5
	)
	//.asStream.next(())
);


o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |time, resp, msg| s.sendMsg(\n_trace, msg[1]); }).add;

SynthDef(\pvplayPanC, { |outbus, pvbuf, startFrame, time = 1, rate = 1, amp = 1, ampMap = 1, pan,
	attack = 0.01, decay = 0.05, numTeeth = 20, cphase = 0, cwidth = 0.5, crate = 0|
	var	fft = PV_PlayBuf(LocalBuf(Index.kr(pvbuf, 0), 1), pvbuf, rate, startFrame, loop: 0),
		sig;
// 	fft = PV_BinShift(fft, 1, Line.kr(shiftS, shiftE, time));
	cphase = (Sweep.kr(rate: crate) + cphase).wrap(0.0, 1.0);
	fft = PV_RectComb(fft, numTeeth, cphase, cwidth);
	sig = IFFT(fft, 1)
		* EnvGen.kr(Env.linen(attack, time - attack - decay, decay, curve: #[4, 0, -4]), doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, amp * ampMap));
}).add;

Env.linen(0.2, 0.6, 0.2, curve: #[4, 0, -4]).plot


(
(keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		event: (eventKey: \polySynthPlayer),
		bufSource: \op,
		inChannels: 2,
		master: ~master,
		glrvbmc: ~glrvbmc,
		lcrvbmc: ~lcrvbmc,
		alwaysReset: true,
		userprep: {
			if(BP.exists(~bufSource) and: { BP(~bufSource).v[\pvbuf].notNil }) {
				~pvbuf = BP(~bufSource).pvbuf;
				~pt = BP(~bufSource).pt;
				~peaks = BP(~bufSource).peaks;
			} {
				"Couldn't load BP(%); BP(%) not ready".format(~collIndex.asCompileString, ~bufSource.asCompileString).warn;
			};
			~ampCtl = GenericGlobalControl(\amp, nil, 0.75, #[0, 1, \amp]);
			~event.putAll((distNear: 5, distFar: 20,
				glrvbout: ~glrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels },
				lcrvbout: ~lcrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels },
				pvbuf: ~pvbuf, ampMap: ~ampCtl.asMap
			));
		},
		userfree: { ~ampCtl.free },
		useGui: { |vpi| ~ampCtl => VP(vpi) },
		synth: \pvc,
		delta: 1.5,
		panWidth: 0.3,
		panCenter: Pn(Pseries.fromEndpoints(0, 0.9, 3), inf),
		objects: (
			pvc: (
				def: \addRvbOut.eval(\pvplayPanC, { |pvbuf, startFrame, time = 1, rate = 1,
						amp = 1, ampMap = 1, pan,
						attack = 0.01, decay = 0.05,
						numTeeth = 20, cphase = 0, cwidth = 0.5, crate = 0|
					var	fft = PV_PlayBuf(LocalBuf(Index.kr(pvbuf, 0), 1),
							pvbuf, rate, startFrame, loop: 0),
						sig;
					cphase = (Sweep.kr(rate: crate) + cphase).wrap(0.0, 1.0);
					fft = PV_RectComb(fft, numTeeth, cphase, cwidth);
					sig = IFFT(fft, 1)
						* EnvGen.kr(Env.linen(attack, time - attack - decay, decay, curve: #[4, 0, -4]),
							doneAction: 2);
					Pan2.ar(sig, pan, amp * ampMap);
				}),
				args: [
					\num, 3,
					\i, Plazy { Pn(Pshuf((0 .. ~pt.size-1), 1), inf) }.clump(Pkey(\num)),
					\spread, Pn(Pseries(-1, 2 / (Pkey(\num)-1), Pkey(\num).asStream), inf).clump(Pkey(\num)),
					\pan, (Pkey(\spread) * BPStream(\panWidth) + BPStream(\panCenter)).clip(-1.0, 1.0),
					\distance, Pseries.fromEndpoints(5, 20, 3),
					\time, 0.25,
					\eTopRatio, 0.8,
					#[attack, decay], Ptuple([Pkey(\eTopRatio), 1 - Pkey(\eTopRatio)], inf) * Pkey(\time),
					\playspeed, Pwhite(1.2, 1.9, inf),
					\startFrame, Plazy { (Pindex(~pt, Pkey(\i), inf) + (Pkey(\time) * Pkey(\playspeed))) }
						* (BP(\op).numPvFrames / z.duration),
					\rate, Pkey(\playspeed).neg,
					\amp, Plazy { Pindex(~peaks[1], Pkey(\i), inf) }.reciprocal / Pkey(\num) * 20.dbamp,
					\cwidth, Pgeom.fromEndpoints(1.0, 0.3, 3),
					\crate, Pgeom.fromEndpoints(0.1, 15, 3),
					\cphase, Pwhite(0.0, 0.98, inf)
				]
			)
		),
		reset: {
			var	str;
			currentEnvironment.env.keys.do { |key|
				if((str = key.asString).contains("Stream")) {
					~makeStreamForKey.(str[ .. str.size - 7].asSymbol);
				}
			}
		}
	));
	0 => BP(name);
}, type: \bp) => Fact(\stopturn);
)


BP(\stopturn).play(DelayTimeSpec(5));

PeakMonitor(~master)
BP(\stopturn).ampCtl.bus.get(_.postln)

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m|
	s.sendMsg(\s_getn, m[1], 0, SynthDescLib.at(\pvplayPanC).controls.size);
	OSCpathResponder(s.addr, ['/n_setn', m[1]], { |t, r, m|
		r.remove;
		[SynthDescLib.at(\pvplayPanC).controlNames, m[4..]].flop.do(_.postln); $\n.post
	}).add;
}).add;


BP(\stopturn).reset;
BP(\stopturn).triggerOneEvent(0);

BP(\stopturn).use {
	e = BP(\stopturn).eventStream.next(BP(\stopturn).event.copy);
};

s.dumpOSC(1);
BP(\stopturn).triggerOneEvent(0);
s.dumpOSC(0);



// freqshift? no - we only hear the background noise shifted

i = (~pt.size - 1).rand;
t = 0.2;
a = m.play(\bufGrain, [bufnum: b, start: (~pt[i] + t) * 44100, time: t, rate: -1, amp: 1 /*BP(\st).peaks[0][i].reciprocal*/].debug);

SynthDef(\bufGrainFS, { |start, time, bufnum, rate = 1, amp = 1, shift = 0,
		attack = 0.001, decay = 0.02, outbus|
	var sig;
	sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0);
	sig = FreqShift.ar(sig, shift);
	sig = sig * EnvGen.kr(Env.linen(attack, time, decay), doneAction:2);
	Out.ar(outbus, sig * amp);
}).perform(Library.at(\ddwGlobal, \storeMethod), \ddwSynths);


i = (~pt.size - 1).rand;
t = 0.2;
a = m.play(\bufGrainFS, [bufnum: b, start: (~pt[i] + t) * 44100, time: t, rate: -1, amp: 1 /*BP(\st).peaks[0][i].reciprocal*/, shift: 440]);


// simple stuff

();
r = 5;
a = m.play(\bufGrain, [bufnum: b, start: 0, time: b.duration / r, rate: r, amp: 1]);

a.free;

f = { |r = 1, atk = 0.3, dcy = 0.3|
	var	time = (1 - atk - dcy) * b.duration / r;
	atk = atk * b.duration / r;
	dcy = dcy * b.duration / r;
	m.play(\bufGrain, [bufnum: b, start: 0, time: time, attack: atk, decay: dcy, rate: r, amp: 1]);
};

a = f.(5);

p = n.play(
	Pbind(
		\instrument, \bufGrainPan,
		\bufnum, b,
		\bufdur, b.duration,
		// \rate, Pwhite(2.5, 5.0, 10),
		\rate, Pbeta(2.0, 5.0, 0.8, 0.8, inf),
		\factor, Pkey(\bufdur) / Pkey(\rate),
		\attack, 0.3 * Pkey(\factor),
		\decay, 0.3 * Pkey(\factor),
		\time, Pkey(\bufdur) - Pkey(\attack) - Pkey(\decay),
		\amp, 1,
		\pan, Pwhite(0.6, 1.0, inf) * Prand(#[-1, 1], inf),
		\delta, Pkey(\factor) * Pwhite(0.5, 0.7, inf)
	)
);

p.stop;

q = n.playfx(Instr("busfx.dist"), [0, 2]); q.gui;

Instr("busfx.onePhaser", { |bus, numCh = 1, maxDelay = 0.1, delay = 0.005, speed = 0.1, width = 0.003, decay = 0.01|
	var	sig = In.ar(bus, numCh);
	sig = (sig + AllpassL.ar(sig, maxDelay, max(0, SinOsc.kr(speed, 0, width, delay)), decay)) * 0.5;
	sig
}, [\audiobus, \numChannels, #[0.05, 2.0], #[0.005, 1.0, \exp], #[0.01, 10, \exp], #[0.001, 1.0, \exp], #[0.001, 10.0, \exp]]);

q = n.playfx(Instr("busfx.onePhaser"), [0, 2, 1.0]); q.gui;


// filtDecay low, not much effect; 0.2, buzzy; 0.9, really wobbly
SynthDef(\bufGrainPanPhaser, { |start, time, bufnum, pan, amp = 1, ampMap = 1,
		rate1 = 1, rate2 = 1, proportion = 0.5,
		attack = 0.001, decay = 0.02, outbus, rgate = 1,  // gate just for quick release
		filtDelay = 0.005, filtSpeed = 0.1, filtWidth = 0.003, filtDecay = 0.1, filtAmp = 1|
	var sig, ffreq,
		rate = EnvGen.kr(Env([rate1, rate2, rate1], [proportion, 1-proportion], \lin),
			timeScale: time);
	sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0);
	sig = Limiter.ar(sig * amp, 0.99) * EnvGen.kr(Env.linen(attack, time, decay), rgate);
	ffreq = SinOsc.kr(filtSpeed, 0, filtWidth, filtDelay);
	// 0.06 ~= 16 Hz, likely as low a freq as you'll need
	sig = sig + AllpassL.ar(LeakDC.ar(sig), 0.06, ffreq, filtDecay, filtAmp);
	DetectSilence.ar(sig, 0.001, 0.3, doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, ampMap));
}).add;

\addRvbOut.eval(\bufGrainPanPhaserDist, SynthDescLib.at(\bufGrainPanPhaser).def.func).add;

p = n.play(
	Pbind(
		\instrument, \bufGrainPanPhaser,
		\bufnum, b,
		\bufdur, b.duration,
		// \rate, Pwhite(2.5, 5.0, 10),
		\rate, Pbeta(2.0, 5.0, 0.8, 0.8, inf),
		\factor, Pkey(\bufdur) / Pkey(\rate),
		\attack, 0.3 * Pkey(\factor),
		\decay, 0.3 * Pkey(\factor),
		\time, Pkey(\bufdur) - Pkey(\attack) - Pkey(\decay),
		\amp, 1,
		\pan, Pwhite(0.6, 1.0, inf) * Prand(#[-1, 1], inf),
		\filtDelay, Pwhite(0.005, 0.02, inf),
		\filtSpeed, Pwhite(3.0, 10.0, inf),
		\filtWidth, Pkey(\filtDelay) * Pwhite(0.7, 0.95, inf),
		\filtDecay, Pwhite(0.1, 0.9, inf),
		\delta, Pkey(\factor) * Pwhite(0.5, 0.7, inf)
	)
);

p.stop;

(0.01, 0.02 .. 1.0).reciprocal.plot


// spatialize!
// more parm groups
// need formula for 0, 1, 2 --> weights array

(
(
keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		event: (eventKey: \singleSynthPlayNotify),
		inChannels: 2,
		master: ~master,
		glrvbmc: ~glrvbmc,
		lcrvbmc: ~lcrvbmc,
		trajectoryKey: \traj,
		alwaysReset: true,

		userprep: {
			[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\receivesSignalFrom, ~chan));
			if(BP.exists(\st) and: { BP(\st)[\buffers].tryPerform(\at, 0).notNil }) {
				~buf = BP(\st)[\buffers][0]
			} {
				~buf = Buffer.readAndQuery(s, topEnvironment[\sampleDir] +/+ "feet/58454_sinatra314_footsteps_wooden_floor_loop.wav");
				~iLoadedBuf = true;
			};
			~decayCtl = GenericGlobalControl(\decayIndex, nil, 0, #[0, 2, \lin]);
			~ampCtl = GenericGlobalControl(\amp, nil, 1, \amp);
			~deltaDistribCtl = GenericGlobalControl(\deltaD, nil, 6, #[1.2, 6, \exp]);
			~maxSynthsCtl = GenericGlobalControl(\maxSynths, nil, 1, #[1, 12, \lin, 1]);
			~synths = IdentitySet.new;
			~xymaps = Pseq(BP(~trajectoryKey).xymaps, inf);
			~event.proto = topEnvironment[\rvbEvent].proto;
			~commonArgs = ~commonArgs.value;
		},
		useGui: { |vpi|
			[~decayCtl, ~ampCtl, ~deltaDistribCtl, ~maxSynthsCtl].do { |gc| gc => VP(vpi) };
		},
		userfree: {
			if(~iLoadedBuf == true) { ~buf.free };
			BP(~trajectoryKey).notUsedBy(~collIndex);
			[~decayCtl, ~ampCtl, ~deltaDistribCtl, ~maxSynthsCtl].free;
		},

		preparePlay: { BP(~trajectoryKey).isUsedBy(~collIndex) },

		recvEventNotify: { |synth|
			if(synth.notNil) {
				~synths = ~synths.add(synth);
				OSCpathResponder(s.addr, ['/n_end', synth.nodeID], e { |time, resp, msg|
					resp.remove;
					~synths.remove(synth);
					if(~synths.size <= 0 and: { ~isPlaying.not }) {
						BP(~trajectoryKey).notUsedBy(~collIndex);
					}
				}).add;
			};
		},
		stopCleanup: {
			if(~synths.size <= 0) { BP(~trajectoryKey).notUsedBy(~collIndex) };
		},
		// do NOT fold this into stopCleanup because maybe I don't want it automatically
		stopNodes: { |releaseTime = 0.5|
			releaseTime = -1 - releaseTime;
			~synths.do(_.set(\rgate, releaseTime));
		},

		cosEnv: Env(#[0, 1, 0], #[1, 1], \sin),
		synth: Pif(
			Pfunc({ ~synths.size < ~maxSynthsCtl.value }),
			Pwrand(#[lessPh, midPh, morePh],
				Pfunc({
					((#[0, 1, 2] - ~decayCtl.value) * 0.6 + 1)
					.collect { |i| ~cosEnv.at(i.clip(0, 2)) }
					.normalizeSum
				}),
				inf
			),
			\rest
		),

		// delta: (1.5+3.4) - Pexprand(1.5, 3.4, inf), // Pwhite(0.8, 1.6, inf),
		delta: Plazy({ Pbeta(1, 4.8, ~deltaDistribCtl, 1, inf) }),

		// Beta distrib. with a & b < 1.0 is u-shaped, tends toward extremes
		rate1: Pbeta(2.0, 5.0, 0.8, 0.8, inf),
		rate2: Pbeta(2.0, 5.0, 0.8, 0.8, inf),
		proportion: Pwhite(0.02, 0.98, inf),
		// derived algebraically from
		// factor * rate1 + (1/2 * factor * (r2-r1)) = bufdur
		factor: Pkey(\bufdur) * 2 / (Pkey(\rate1) + Pkey(\rate2)),
		// factor: Pkey(\bufdur) / Pkey(\rate),
		attack: 0.3,
		decay: 0.3,
		time: Pkey(\factor) - Pkey(\attack) - Pkey(\decay),
		amp: 2,
		pan: Pwhite(0.6, 1.0, inf) * Prand(#[-1, 1], inf),

		commonArgs: { [
			#[pan, distance], BPStream(\xymaps),
			\bufnum, ~buf,
			\bufdur, Pfunc({ ~buf.duration }),
			\rate1, BPStream(\rate1),
			\rate2, BPStream(\rate2),
			\factor, BPStream(\factor),
			\proportion, BPStream(\proportion),
			\amp, BPStream(\amp),
			\ampMap, ~ampCtl.asMap,
			\attack, BPStream(\attack) * Pkey(\factor),
			\decay, BPStream(\decay) * Pkey(\factor),
			\time, BPStream(\time)
		] },

		// filtDecay low, not much effect; 0.2, buzzy; 0.9, really wobbly
		objects: { (
			lessPh: (
				def: \bufGrainPanPhaserDist,
				args: ~commonArgs ++ [
					\filtDelay, Pwhite(0.005, 0.02, inf),
					\filtSpeed, Pwhite(3.0, 10.0, inf),
					\filtWidth, Pkey(\filtDelay) * Pwhite(0.7, 0.95, inf),
					\filtDecay, Pwhite(0.02, 0.09, inf)
				]
			),
			midPh: (
				def: \bufGrainPanPhaserDist,
				args: ~commonArgs ++ [
					\filtDelay, Pwhite(0.005, 0.02, inf) + 0.01,
					\filtSpeed, Pwhite(3.0, 10.0, inf),
					\filtWidth, Pkey(\filtDelay) * Pwhite(0.7, 0.95, inf),
					\filtDecay, Pwhite(0.18, 0.3, inf)
				]
			),
			morePh: (
				def: \bufGrainPanPhaserDist,
				args: ~commonArgs ++ [
					\filtDelay, Pwhite(0.005, 0.02, inf) + 0.02,
					\filtSpeed, Pwhite(3.0, 10.0, inf),
					\filtWidth, Pkey(\filtDelay) * Pwhite(0.7, 0.95, inf),
					\filtDecay, Pwhite(0.7, 0.95, inf)
				]
			)			
		) }
	));
}, type: \bp) => Fact(\ilanaSteps);
)

BP(\traj).free; PR(\trajectories) => BP(\traj);

BP(\is).free;
Fact(\ilanaSteps) => BP(\is);
0 => BP(\is);

BP(\is).synth = BP(\is).synth.trace;
BP(\is).synth = BP(\is).synth.pattern;

BP(\is).listVars;

BP(\is).delta = Pwhite(1.5, 3.4, inf);
BP(\is).delta = (1.5+3.4) - Pexprand(1.5, 3.4, inf);

// Pbeta(0.0, 1.0, 0.7, 0.7, 10000).asStream.all.histo.plot;
// ((1.5+3.4) - Pexprand(1.5, 3.4, 100000)).asStream.all.histo(100, 1.5, 3.4).plot;
// Pbeta(1.5, 3.4, 5.5, 1, 100000).asStream.all.histo(100, 1.5, 3.4).plot;

BP(\is).decayCtl.spec = #[0, 2];
BP(\is).decayCtl.gui;

BP(\is).decayCtl => VP(1);

// already in the Fact()!
();
BP(\is).use {
	~cosEnv = Env(#[0, 1, 0], #[1, 1], \sin);
	~synth = Pif(
		Pfunc({ ~synths.size < ~maxSynthsCtl.value }),
		Pwrand(#[lessPh, midPh, morePh],
			Pfunc({
				((#[0, 1, 2] - ~decayCtl.value) * 0.6 + 1)
				.collect { |i| ~cosEnv.at(i.clip(0, 2)) }
				.normalizeSum
			}),
			inf
		),
		\rest
	);
};

BP(\is).amp = 2;

BP(\is).midPhfiltDelay = Pwhite(0.005, 0.02, inf) + 0.01;
BP(\is).morePhfiltDelay = Pwhite(0.005, 0.02, inf) + 0.02;

BP(\is).morePhfiltDecay = Pwhite(0.9, 1.4, inf);

BP(\is).saveSynth = BP(\is).synth;
BP(\is).synth = \morePh;

BP(\is).synth = BP(\is).saveSynth;


BP(\is).eventStreamPlayer.event.debug = true;
BP(\is).eventStreamPlayer.event.debug = false;

BP(\is).event.debug = false;

BP(\is).srate1 = BP(\is).rate1;
BP(\is).srate2 = BP(\is).rate2;

BP(\is).rate1 = 2; BP(\is).rate2 = 5;

BP(\is).rate1 = BP(\is).srate1;
BP(\is).rate2 = BP(\is).srate2;

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m|
	{ s.sendMsg(\n_trace, m[1])  }.defer(1)
}).add;

BP(\is).triggerOneEvent(0);

// 1.2 mixed
// 1.4, mostly 3s and 4s, but 1s and 2s not rare
// 4, 2s are rare
// 6, nearly all 4s
BP(\is).delta = Pbeta(1, 4.8, 6, 1, inf).trace;

BP(\is).rate1 = 1;
BP(\is).rate2 = 1;

BP(\is).rate1 = Pwhite(0.87, 1.2, inf);
BP(\is).rate2 = Pkey(\rate1) * Pwhite(1.6, 2.5, inf);
BP(\is).proportion = Pwhite(0.3, 0.7, inf);

BP(\is).synths

BP(\is).stopNodes;
BP(\is).synths.do(_.set(\rgate, -1.5));

// Laura: flurry of pitch, then settle down

// klankmachine api
parms[\chorusAmps]
parms[\chorusAmt]
parms[\chorusDelay]
parms[\excTime]
parms[\freq]
parms[\harm]
parms[\kAmp]
parms[\mainAmp]
parms[\newDelta]
parms[\prob]
parms[\rate]
parms[\start]
parms[\timeMul]


\chuckIf.eval(PR(\trajectories), BP, \traj);
\chuckIf.eval(Fact(\opening), BP, \op, nil, Library.at(\rvbs));
\chuckIf.eval(Fact(\openingSteps), BP, \st, nil, Library.at(\rvbs));
BP(\st).autoRun = false;

BP(\st).gestures.keys


// interesting but quick flurry is a bad idea

fork {
	3.do { |i|
		BP(\st).runGesture((
			gest: \klankMachine,
			newDelta: Pseg(Pseq(#[0.08, 0.36], 1), 12, \exp),
			excTime: 0.15,
			timeMul: Env(#[0.3, 0.01, 0.3], #[3, 9], \exp).asStream / Pkey(\delta),
			// filtAttackRatio: Env(#[1, 0.1, 1, 1, 0.95], #[2, 4, 2, 4], #[5, 5, 0, 2]),
			filtAttackRatio: Env(#[0.1, 1, 0.6], #[6, 6], #[-2, 4]),
			// filtAttackRatio: 0.01 / Pkey(\filtDecay), // <-- hampered by bad design
			freq: (Pvbrown(32, 44, Pwhite(-4, 4, inf).reject(_ == 0), inf, 38)
				+ ((i-2) * 7)
			).collect { |degree| Mode(\g).cps(degree) },
			mainAmp: Env(#[1, 0.1, 1], #[2.5, 9.5], \exp),
			// default xyPat uses \numEv, but we don't know how long newDelta pat will run
			xyPat: Ptuple([
				Pseg(
					Pwhite(0.6, 1.0, inf) * Prand(#[-1, 1], inf),
					Pexprand(0.5, 2.0, inf)
				),
				Pseg(
					Pwhite(5.0, 20.0, inf),
					Pexprand(0.5, 2.0, inf)
				)
			], 1)
		));
		rrand(1.1, 1.9).wait;
	};
};

(38-7).unmapMode(\g)


// too slow, pitch needs to be subtler
BP(\st).runGesture((
	gest: \klankMachine,
	// newDelta: Pexprand(1.5.reciprocal, 1.5, inf) * Pseg(Pseq(#[0.4, 0.15, 0.4], 1), 6, \exp),
	newDelta: Pseq([
		Pexprand(0.24, 0.48, { rrand(2, 6) }),
		Pwhite(0.75, 1.2, 1)
	], 1),
	excTime: 0.15,
	// timeMul: 0.3 / Pkey(\delta),
	timeMul: Env(#[0.01, 0.3], #[20], 4.5).asStream / Pkey(\delta),
	filtAttackRatio: 0.01 / Pkey(\filtDecay), // <-- hampered by bad design
	freq: Pvbrown(32, 44, Pwhite(-4, 4, inf).reject(_ == 0))
		.collect { |degree| Mode(\g).cps(degree) },
//	mainAmp: Env(#[1, 0.1, 1], #[2.5, 9.5], \exp),
	// default xyPat uses \numEv, but we don't know how long newDelta pat will run
	xyPat: Ptuple([
		Pseg(
			Pwhite(0.6, 1.0, inf) * Prand(#[-1, 1], inf),
			Pexprand(0.5, 2.0, inf)
		),
		Pseg(
			Pwhite(5.0, 20.0, inf),
			Pexprand(0.5, 2.0, inf)
		)
	], 1)
));


BP(\st).use {
	var notes = Mode(\g).cps(#[22, 28, 31, 33, 34, 37, 39, 40, 43, 46]);
	5.do { |i|
		// ("laurawp" ++ i).asSymbol.envirPut(Pvbrown(32, 44, Pwhite(-4, 4, inf).select(_ != 0))
		// 	.collect { |degree| Mode(\g).cps(degree) });
		("laurawp" ++ i).asSymbol.envirPut(Pser(notes, { rrand(3, 6) }) ++ Pn(Pshuf(notes, 1), inf));
	};
	~lauraWpPitchPool = Pn(Pseries(0, 1, 5), inf);
	~runLauraWp = { |parms( () )|
		BP(\st).runGesture((
			instr: parms[\instr],
			gest: parms[\gest] ? \klankMachine,
			newDelta: parms[\newDelta] ?? {
				Pexprand(0.24, 0.48, { parms[\numEv] ?? { rrand(3, 7) } })
			},
			excTime: 0.15,
			timeMul: parms[\timeMul] ?? { Env(#[0.01, 0.3], #[20], 4.5).asStream / Pkey(\delta) },
			filtAttackRatio: parms[\filtAttackRatio] ?? { 0.01 / Pkey(\filtDecay) },
			freq: parms[\freq] ?? {
				BPStream(("laurawp" ++ ~lauraWpPitchPoolStream.next).asSymbol)
			},
			mainAmp: parms[\mainAmp] ?? { Env(#[1, 0.1, 1], #[2.5, 9.5], \exp) },
			kAmp: parms[\kAmp] ? 1,
			harm: parms[\harm],  // if nil, remains nil in the parms dict passed thru
			// default xyPat uses \numEv, but we don't know how long newDelta pat will run
			xyPat: Ptuple([
				Pseg(
					Pwhite(0.6, 1.0, inf) * Prand(#[-1, 1], inf),
					Pexprand(0.5, 2.0, inf)
				),
				Pseg(
					Pwhite(5.0, 20.0, inf),
					Pexprand(0.5, 2.0, inf)
				)
			], 1)
		));
	};
};

// needs shape... what shape?
fork {
	var	numEv;
	while { BP(\st).isPlaying } {
		numEv = rrand(4, 11);
		BP(\st).runLauraWp((
			numEv: numEv,
			timeMul: Pgeom.fromEndpoints(rrand(0.05, 0.3), 0.01, numEv),
			chorusAmps: #[0, 0, 0],
			mainAmp: Pgeom.fromEndpoints(*(#[1.0, 0.1].rotate(2.rand) ++ numEv))
		));
		rrand(1.2, 2.2).wait;
	}
};


// maybe
(
var //numEv = rrand(4, 11),
	notes = Mode(\g).cps(#[22, 28, 31, 33, 34, 37, 39, 40, 43, 46]);
BP(\st).runLauraWp((
	numEv: inf, //numEv,
	newDelta: Env(#[0.6, 0.15], #[15], -4.5).asStream * Pexprand(0.75, 1.333, inf),
	timeMul: Env(#[0.35, 0.01], #[25], \exp).asStream / Pkey(\delta),
	chorusAmps: #[0, 0, 0],
	freq: Pser(notes, { rrand(3, 6) }) ++ Pn(Pshuf(notes, 1), inf),
	mainAmp: 1,
	kAmp: 2,
	harm: Pstutter(Pwhite(6, 15, inf), Pseq(#[
		[[1, 2, 3, 4, 5]],
		[[1, 3, 5, 7, 9]]
	], inf))
));
)



// maybe - fits choreography better; blur pitches
// getting there...

SynthDef(\bufGrainPanKlRing, { |start, time, bufnum, pan, rate = 1, amp = 1, ampMap = 1,
		attack = 0.001, decay = 0.02, outbus, filtFreq = 2000, filtAttack = 0.1, filtDecay = 1.0,
		filtAmp = 1,
		fShiftWidth = 0.05, mixProb = 0.5, movingProb = 0.22,
		ffreq = 2000, lprq = 1|
	var harm = \harm.kr((1..5)),
		amps = \amps.kr((1..5).reciprocal),
		decays = \decays.kr(1 ! 5),
		sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
			* EnvGen.kr(Env.linen(attack, time, decay)),
		// Klank(decay) - Klank(attack) is like a bank of Formlets
		filt = Klank.ar(`[harm, amps, decays], sig, freqscale: filtFreq, decayscale: filtDecay)
			- Klank.ar(`[harm, amps, decays], sig, freqscale: filtFreq, decayscale: filtAttack);
	sig = sig + (Limiter.ar(filt) * filtAmp);
	sig = (sig * (Rand(0, 1) < mixProb)) + FreqShift.ar(sig,
		Select.ar(Rand(0, 1) < movingProb, [
			Line.ar(*([({ Rand(-0.2, 0.2) } ! 2) * filtFreq] ++ filtDecay)),
			TExpRand.ar(-0.2, 0.2, 1) * filtFreq
		])
	);
	sig = RLPF.ar(sig, ffreq, lprq);
	DetectSilence.ar(sig, 0.001, doneAction: 2);
	Out.ar(outbus, Pan2.ar(sig, pan, amp * ampMap));
}).add;

\addRvbOut.eval(\bufGrainPanKlRingDist, SynthDescLib.at(\bufGrainPanKlRing).def.func).add;

// good test

(
var //numEv = rrand(4, 11),
	notes = Mode(\g).cps(#[22, 28, 31, 33, 34, 37, 39, 40, 43, 46]);
BP(\st).runLauraWp((
	instr: Pwrand(#[bufGrainPanKlankDist, bufGrainPanKlRingDist], #[0.4, 0.6], inf),
	numEv: inf, //numEv,
	// newDelta: Env(#[0.6, 0.15], #[15], -4.5).asStream * Pexprand(0.75, 1.333, inf),
	newDelta: Pseq([
		Pseg(
			Pser([Pwhite(0.4, 0.7, 1), Pwhite(0.12, 0.18, 1)], 3),
			Pwhite(2.5, 4.5, inf),
			\exp
		),
		Pwhite(0.8, 1.8, 1)
	], inf),
	timeMul: Pif(0.15.asPattern.coin, Pwhite(0.15, 0.35, inf), 0.01) / Pkey(\delta),
	// oh, it gets uglier!
	filtAttackRatio: Pif(
		(Pkey(\filtDecay) * Pkey(\delta)) > 0.011,
		Pwhite(0.9, 0.98, inf),
		1
	),
	chorusAmps: #[0, 0, 0],
	freq: Pser(notes, { rrand(3, 6) }) ++ Pn(Pshuf(notes, 1), inf),
	mainAmp: 1,
	kAmp: 2,
	harm: Pstutter(Pwhite(6, 15, inf), Pseq([
		Pexprand(0.98, 0.98.reciprocal, inf).clump(5) * [1, 2, 3, 4, 5],
		Pexprand(0.98, 0.98.reciprocal, inf).clump(5) * [1, 3, 5, 7, 9]
	], inf).collect([_]))  // polySynthPlayer: wrap array arg in another array
));
)


BP(\st).v.env.keys.select { |key| key.asString.containsi("Ctl") }

BP(\st).pitchProbCtl = GenericGlobalControl(\pitchProb, nil, 0.15);
BP(\st)[\free] = BP(\st)[\free].addFunc({ ~pitchProbCtl.free });

BP(\st)[\free].inspect

BP(\st) => VP(0);
BP(\st).pitchProbCtl => VP(0);

BP(\st).event.printStoppedStream = true;
BP(\st).event.printAllStreamsOnStop = false;

BP(\st).event.printStoppedStream = false;

// oh FUCKING hell - i need freq to depend on decay and it's backward in klankMachine
BP(\st).gestures.klankMachineLWp = { |parms|
	var	pat = ~gestures[\klankMachine].value(parms),
		ppairs = pat.patternpairs,
		filtFreqI = ppairs.indexOf(\filtFreq),
		filtDecayI = ppairs.indexOf(\filtDecay);
	if(filtFreqI.notNil and: { filtDecayI.notNil }) {
		#[0, 1].do { |i|
			ppairs.swap(filtFreqI + i, filtDecayI + i);
		};
		Pbind(*ppairs) // .pairsDo { |key, val| (key -> val).postcs }
	} { nil };
};


(
f = {
	BP(\st).runLauraWp((
		gest: \klankMachineLWp,
		instr: Pwrand(#[bufGrainPanKlankDist, bufGrainPanKlRingDist], #[0.4, 0.6], inf),
		numEv: inf, //numEv,
		newDelta: Pseg(
			Pser([Pwhite(0.4, 0.7, 1), Pwhite(0.12, 0.18, 1)], 3,
				#[0, 1].wchoose(#[0.7, 0.3])),
			Pwhite(2.5, 4.5, inf),
			\exp
		),
		timeMul: Pif(
			(Pseries.fromEndpoints(1, BP(\st).pitchProbCtl.value, rrand(4, 7)) ++ BP(\st).pitchProbCtl.asPattern).coin,
			Pwhite(0.15, 0.35, inf),
			0.01
		) / Pkey(\delta),
		// oh, it gets uglier!
		filtAttackRatio: Pif(
			(Pkey(\filtDecay) * Pkey(\delta)) >= 0.011,
			Pwhite(0.9, 0.98, inf),
			1
		),
		chorusAmps: #[[0, 0, 0]],
		// pull pitch only if you'll hear it
		freq: Pif(
			(Pkey(\filtDecay) * Pkey(\delta)) >= 0.011,
			BPStream(("laurawp" ++ BP(\st).lauraWpPitchPoolStream.next).asSymbol, envir: BP(\st).v),
			Pwhite(28, 42, inf).collect { |degree| Mode(\g).cps(degree) }
		),
		mainAmp: 1,
		kAmp: 2,
		harm: Pstutter(Pwhite(6, 15, inf), Pseq([
			Pexprand(0.98, 0.98.reciprocal, inf).clump(5) * [1, 2, 3, 4, 5],
			Pexprand(0.98, 0.98.reciprocal, inf).clump(5) * [1, 3, 5, 7, 9]
		], inf).collect([_]))  // polySynthPlayer: wrap array arg in another array
	));
};
)

BP(\st).setLauraWps(Mode(\g).cps(#[22, 28, 31, 33, 34, 37, 39, 40, 43, 46]));

fork {
	while { BP(\st).isPlaying } {
		f.();
		rrand(5.0, 9.0).wait;
	}
};

BP(\st).v.env.keys.select { |key| key.asString.containsi("autorun") }
BP(\st).removeAutoRun;



// new walking sequence demo

\chuckIf.eval(PR(\trajectories), BP, \traj);
\chuckIf.eval(Fact(\opening), BP, \op, nil, Library.at(\rvbs));
\chuckIf.eval(Fact(\openingSteps), BP, \st, nil, Library.at(\rvbs));
// BP(\st).autoRun = false;
\chuckIf.eval(Fact(\ilanaSteps), BP, \is, nil, Library.at(\rvbs));

BP(\is).rate1 = Pwhite(1.3, 1.9, inf);
BP(\is).rate2 = Pkey(\rate1) * Pwhite(2.0, 3.2, inf);

BP(\is).delta = Plazy({ Pbeta(0.6, 2.0, ~deltaDistribCtl, 1, inf) });
BP(\is).ampCtl.value = 2;

(
var	lwpLoopParms,
	recording = false;
if(t.isPlaying) { t.stop; "stop sequencer before replaying!".warn } {
	t = TLSequenceIterator([
		{
			if(recording) {
				~master.startRecord("newfeet.aiff");
				1
			} { 0 }
		},
		{ thisThread.clock.beats.debug("1. Stephen"); 0 },
		bpCmd: (name: \op, dur: 35, /* shouldSync: false, */ prepareBP: { |bp|
			bp.ampCtl.value = 0.68;
			// if(d.class == DDWTimer) { d.reset };
		}),
		12,
		gcAutoSynthCmd: (gc: BP(\op).ampCtl, name: \ctlPoint, outName: \outbus,
			value: 0, time: 22, curve: -2, shouldSync: false),
		bpCmd: (name: \st, /* shouldSync: false, */ prepareBP: { |bp|
			bp.ampCtl.value = 0;
			bp.gest = Pseq([Pn(\slowSteps, { rrand(2, 4) }), \slowStepStretch], inf);
			bp.numEv = Pwhite(4, 7, inf);
			bp.gDelta = Pwhite(2.5, 4.0, inf);
			bp.slowRate = Pwhite(0.5, 0.8, inf);
			bp.defaultParms = nil;
			bp.kdecay = Pexprand(0.014, 0.017, inf);
			bp.makeStreamForKey(\kfreq);	// reset this one
			bp.autoRun = true;
			
			bp.gestures.oneKlankStepsCallback = { |parms|
				CleanupStream(~gestures[\oneKlankSteps].(parms).asStream, parms[\callback])
			};
		}),
		gcAutoSynthCmd: (gc: BP(\st).ampCtl, name: \ctlPoint, outName: \outbus,
			/* shouldSync: false, */
			value: 0.7, time: 14, curve: 2),
		\cmdSync,
		20,

		{ BP(\st).stop; 2 },

		{ thisThread.clock.beats.debug("2. Ilana"); 0 },
		bpCmd: (name: \is, dur: 40, prepareBP: { |bp|
			bp.maxSynthsCtl.value = 2;
			bp.decayCtl.value = 2;
			bp.delta = Plazy({ Pbeta(1, 4.8, ~deltaDistribCtl, 1, inf) });
		}, clearDoneSignal: { BP(\is).stopNodes(-1) }),

		20,
		{	BP(\is).delta = Plazy({ Pbeta(0.6, 2.0, ~deltaDistribCtl, 1, inf) });
			BP(\is).maxSynthsCtl.value = 3;
			25
		},
		
		{ thisThread.clock.beats.debug("3. Laura"); 0 },
		bpCmd: (name: \st, prepareBP: { |bp|
			bp.autoRun = false;
			bp.pitchProbCtl.value = 0.08;
			bp.setLauraWps(Mode(\g).cps(#[22, 28, 31, 33, 34, 37, 39, 40, 43, 46]));
		}),
		0.01,  // a RACE condition? Ya gotta be kidding me!
		TLSequenceIterator([
			15,
			gcAutoSynthCmd: (gc: BP(\st).pitchProbCtl, name: \ctlPoint, outName: \outbus,
				value: 0.27, time: 33, curve: 5.4)
		]).shouldSync_(false),
		loopCmd: lwpLoopParms = (
			dur: 35,
			// fine print: ~doneSignal is non-nil by default, preventing 'dur' from being used
			setDoneSignal: { ~doneSignal = nil },
			lwpParms: (
				gest: \klankMachineLWp,
				instr: Pwrand(#[bufGrainPanKlankDist, bufGrainPanKlRingDist], #[0.4, 0.6], inf),
				numEv: inf, //numEv,
				newDelta: Pseg(
					Pser([Pwhite(0.4, 0.7, 1), Pwhite(0.12, 0.18, 1)], 3,
						#[0, 1].wchoose(#[0.7, 0.3])),
					Pwhite(2.5, 4.5, inf),
					\exp
				),
				timeMul: Pif(
					(Plazy({ Pseries.fromEndpoints(1, BP(\st).pitchProbCtl.value, rrand(4, 7)) }) ++ BP(\st).pitchProbCtl.asPattern).coin,
					Pwhite(0.15, 0.35, inf),
					0.01
				) / Pkey(\delta),
				// oh, it gets uglier!
				filtAttackRatio: Pif(
					(Pkey(\filtDecay) * Pkey(\delta)) >= 0.011,
					Pwhite(0.9, 0.98, inf),
					1
				),
				chorusAmps: #[[0, 0, 0]],
				// pull pitch only if you'll hear it
				freq: Pif(
					(Pkey(\filtDecay) * Pkey(\delta)) >= 0.011,
					BPStream(("laurawp" ++ BP(\st).lauraWpPitchPoolStream.next).asSymbol, envir: BP(\st).v),
					Pwhite(28, 42, inf).collect { |degree| Mode(\g).cps(degree) }
				),
				mainAmp: 1,
				kAmp: 2,
				harm: Pstutter(Pwhite(6, 15, inf), Pseq([
					Pexprand(0.98, 0.98.reciprocal, inf).clump(5) * [1, 2, 3, 4, 5],
					Pexprand(0.98, 0.98.reciprocal, inf).clump(5) * [1, 3, 5, 7, 9]
				], inf).collect([_]))  // polySynthPlayer: wrap array arg in another array
			),
			cmds: [
				{
					BP(\st).runLauraWp(~lwpParms, true);
					rrand(5.0, 9.0)
				}
			]
		),
		\cmdSync,
		1,

		// 3 poses
		// kdecay is not used in klankMachine
		{	BP(\st).stopSavedStreams;
			BP(\st).override(\kdecay, Pwhite(0.15, 0.3, 3));
			0
		},
		loopCmd: (repeats: 3,
			cmds: [
				{	BP(\st).runGesture((gest: \oneKlank, numEv: 2));
					// if(~repeats > 1) {
						rrand(2.0, 3.0)
					// } { 0 }
				}
			]
		),
		\cmdSync,
		loopCmd: lwpLoopParms.copy.dur_(15),
		\cmdSync,

		2,
		{ thisThread.clock.beats.debug("4. Stephen"); 0 },
		// 'changeSteps' in 01-feet-sequence.scd
		{	var	bp = BP(\st);
			bp.chordN = 0;
			bp.kdecay = (Pwhite(0.1, 0.3, inf) * Env(#[0.1, 0.25], #[86], 7));
			bp.gest = Pswitch1([
				Pseq([
					Pwrand(#[clatter, oneKlankSteps, clatterDecay, klankDecay, slowSteps],
						#[4, 2, 3, 1, 1].normalizeSum, { rrand(3, 6) }),
					\slowStepStretch
				], inf),
				Prand(#[oneKlankSteps, klankDecay, klankHarmonize, klankHrmSteps], inf)
			], (Pwhite(0.0, 1.0, inf) < Env(#[0.0, 0.5], #[120])).collect(_.binaryValue));
			bp.gDelta = Pwhite(1.5, 3.0, inf) * Env(#[1, 0.36], #[90]);
			bp.numEv = Pwhite(6, 14, inf);
			bp.addAutoRun;
			0
		},
		30,

		{ thisThread.clock.beats.debug("5. Ilana"); 0 },
		{ BP(\st).stop; 0.8 },
		bpCmd: (name: \is, dur: 20, prepareBP: { |bp|
			bp.maxSynthsCtl.value = 8;
			bp.decayCtl.value = 2;
			bp.delta = Plazy({ Pbeta(0.6, 2.0, ~deltaDistribCtl, 1, inf) });
		} /*, clearDoneSignal: { BP(\is).stopNodes(-1) }*/),
		\cmdSync,

		{ thisThread.clock.beats.debug("6. Laura"); 0 },
		bpCmd: (name: \st, prepareBP: { |bp|
			bp.autoRun = false;
			bp.pitchProbCtl.value = 0.36;
			// bp.setLauraWps(Mode(\g).cps(#[22, 28, 31, 33, 34, 37, 39, 40, 43, 46]));
		}),
		0.01,
		gcAutoSynthCmd: (gc: BP(\st).pitchProbCtl, name: \ctlEnv, outName: \outbus,
			env: Env(#[0.36, 0.6], #[1], 4), time: 18, connect: 0),
		loopCmd: lwpLoopParms.copy.dur_(30),
		\cmdSync,

		{	// BP(\st).removeAutoRun;  // really?
			BP(\st).autoRunMultiSpeed;
			30
		},

		{	BP(\st).autoRunMultiSpeed(false);  // stop that
			BP(\st).stopSavedStreams;
			1
		},

		{
			thisThread.clock.beats.debug("7. Together");
			BP(\traj).isUsedBy(\is);  // NOT PURELY DEBUG
			0
		},
		bpCmd: (name: \op, dur: 35, /* shouldSync: false, */ prepareBP: { |bp|
			bp.ampCtl.value = 0.68;
			// if(d.class == DDWTimer) { d.reset };
		}),

		loopCmd: (
			dur: 45,
			setDoneSignal: { ~doneSignal = nil },
			actions: [
				{ BP(\st).runGesture },
				{ BP(\is).triggerOneEvent(0) },
				{ BP(\st).runLauraWp(lwpLoopParms[\lwpParms], true); }
			],
			cmds: [
				{
					~actions.choose.value;
					exprand(0.6, 2.6)
				}
			]
		),
		\cmdSync,

		{
			BP.all.stop;
			if(recording) {
				{ ~master.stopRecord }.defer(8);
			};
			0
		}
	]).play;
	u = Updater(t, { |obj, what|
		if(what == \done) { "TLSeq stopped".postln; u.remove };
	});
};
)

t.stop;



BP(\st).gestures[\klankMachineLWp]

t.activeCmds.do(_.listVars)

t.dependants


BP(\op).prepareForPlay;
BP(\op).reset;
BP(\traj).isUsedBy(\op);

e = BP(\op).eventStream.next(BP(\op).event.copy);

fork {
	e.play;
	1.0.wait;
	Server.killAll;
};

t = TLSequenceIterator([
	bpCmd: (name: \op, dur: 35, /* shouldSync: false, */ prepareBP: { |bp|
		bp.ampCtl.value = 0.68;
		// if(d.class == DDWTimer) { d.reset };
	})
]).play;
