// filtering: needs to change ffreq when syncopation is active
// other kinds of syncopation

ChuckableBrowser.newWindow;
SynthDescLib.global.browse;
Object.browse;
s.queryAllNodes;

Help.gui;

MIDIPort.init([2]);
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
//~master => MCG(7);

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
	"/media/DLM/trax/kc/samples/feet"
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