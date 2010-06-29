// harmonic series processes


SynthDescLib.global.browse;
Object.browse;
s.queryAllNodes;

MIDIPort.init([2]);
MIDIPort.autoFreeSockets = false;

MT(1).free;
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
8.do { VP(0).v.addControlProxy(nil, true) };
VP(0).v.gui;

//k = VoicerMIDISocket(0, VP(0).v);

{	var cc;
	8.do {
		cc = VoicerMIDIController(\omni, \knob);
		cc => CC.prNew(cc.ccnum.shortName.asSymbol);
	};
}.value;

8.do { |i| CC(("k" ++ i).asSymbol) => VP(0) };

~master ?? { ~master = MixerChannel(\master, s, 2, 2, level: 1) };

~rvbmc => MCG(6);
~master => MCG(7);
MixingBoard.at(0).refresh;

~rvb.run(false); ~rvbmc.mute;
~rvb.run(true); ~rvbmc.mute;


(
// egRate == 1 corresponds to 1 sec dur; 0.25 = 4 sec
SynthDef(\partial1a, { |outbus, freq = 440, amp = 1, egRate = 1, egRateMul = 1, egBuf|
	var	sig = FSinOsc.ar(freq, 0, amp),
		egpos = Sweep.kr(1, egRate * egRateMul),
		eg = BufRd.kr(1, egBuf, egpos * BufFrames.ir(egBuf), loop: 0, interpolation: 2);
	FreeSelf.kr(egpos >= 1.0);
	OffsetOut.ar(outbus, sig * eg);
}).add;

SynthDef(\partial1b, { |outbus, freq = 440, amp = 1, egRate = 1, egRateMul = 1, egBuf,
	panWidth = 0, panCtr = 0|
	var	sig = FSinOsc.ar(freq, 0, amp),
		swRate = egRate * egRateMul,
		egpos = Sweep.kr(1, swRate),
		eg = BufRd.kr(1, egBuf, egpos * BufFrames.ir(egBuf), loop: 0, interpolation: 2),
		pan = LFNoise1.kr(swRate, panWidth, panCtr).clip(-1.0, 1.0);
	FreeSelf.kr(egpos >= 1.0);
	OffsetOut.ar(outbus, Pan2.ar(sig * eg, pan));
}).add;


SynthDef(\partial1bgated, { |outbus, freq = 440, amp = 1,
	egRate = 1, egRateMul = 1, egSusPt = 0.5, egBuf,
	panWidth = 0, panCtr = 0, gate = 1|
	var	sig = FSinOsc.ar(freq, 0, amp),
		swRate = egRate * egRateMul,
		posTest = Select.kr(Impulse.kr(0), [LocalIn.kr(1), 0]),
		notReachedSusPt = BinaryOpUGen('==', sign(egSusPt - posTest), swRate.sign),
		egpos = Sweep.kr(1, swRate * (((gate <= 0) + notReachedSusPt) > 0)),
// 		egpos = Sweep.kr(1, swRate * (((gate <= 0) + (posTest < egSusPt)) > 0)),
		eg = BufRd.kr(1, egBuf, egpos * BufFrames.ir(egBuf), loop: 0, interpolation: 2),
		pan = LFNoise1.kr(swRate, panWidth, panCtr).clip(-1.0, 1.0);
	LocalOut.kr(egpos);
	FreeSelf.kr(egpos >= 1.0);
	OffsetOut.ar(outbus, Pan2.ar(sig * eg, pan));
}).add;
);

(
Proto {
	~fund = 32.midicps;
	~event = (eventKey: \singleSynthPlayNotify);
	~quant = NilTimeSpec.new;
	~initTempo = 0.1;
	~tempoSpec = #[0.01, 10, \exp].asSpec;
	~alwaysReset = true;

	~prep = {
		~clock = TempoClock(~initTempo, queueSize: 2048).permanent_(true);
		~tempoCtl = GenericGlobalControl(\tempo, nil, ~initTempo, ~tempoSpec);
		~upd = Updater(~tempoCtl, e { |obj, msg|
			if(msg[\what] == \value) {
				~clock.tempo = obj.value
			};
		});

		// how much of a note's duration to hold in the middle
		~holdPctCtl = GenericGlobalControl(\holdPct, nil, 0);

		~chan = MixerChannel(~collIndex, s, 2, 2, outbus: ~master);
		~egbuf = Buffer.alloc(s, 1024, 1, { |buf|
			buf.setnMsg(0, Env(#[0, 1, 0], #[0.5, 0.5], \sine).discretize(1024))
		});
	};

	~asPattern = {
		Pseq([
			Pfuncn {
				~goTime = thisThread.beats;
				0
			},
			Pbind(
				\instrument, \partial1bgated,
				\freq, ~fund,
				\egRate, ~tempoCtl.asMap,
				\egRateMul, (1 - ~holdPctCtl.asPattern).max(0.001).reciprocal,
				\delta, 1,
				\sustain, ((~holdPctCtl.asPattern - 1) * 0.5 + 1) * Pkey(\delta),
				\amp, 1,
				\egBuf, ~egbuf,
				\chan, ~chan
			)
		])
	};

	~useGui = { |vpi| ~tempoCtl => VP(vpi); ~holdPctCtl => VP(vpi) };

	~freeCleanup = {
		~upd.remove;
		~clock.stop;
		[~tempoCtl, ~holdPctCtl, ~chan, ~egbuf].free;
	}
} => BP(\mstClock);
);

(
PR(\abstractProcess).clone {
	~event = (eventKey: \singleSynthPlayNotify);
	~cl = \mstClock;
	~alwaysReset = true;

	~low = 2;
	~high = 32;
	~rat = Pwhile1({ |in, item| item <= ~high }, Pseries(~low, 1, inf))
		++ (Pexprand(Pfunc { ~low }, Pfunc { ~high }, inf)
			.round(1).reject { |x| ~activeRatios.includes(x) });
	~numEv = Pfunc { |ratio| ratio } * Pwhite(1.5, 4) * Pseries(1, 0.02, inf);

	~prep = {
// 		~master ?? { ~master = topEnvironment[\master] };
// 		~chan = MixerChannel(~collIndex, s, 2, 2, outbus: ~master);

		~clImport.();
		~procInit.();

		~makeGResponder.();
		currentEnvironment
	};

	~procInit = {
		~activeRatios = Set.new;
		~fullSet = (~low .. ~high).asFloat.as(Set);
	};

	~clImportKeys = #[clock, tempoCtl, fund, chan, egbuf, holdPctCtl];
	~clImport = {
		~clImportKeys.do { |key|
			key.envirPut(BP(~cl)[key])
		}
	};

	~freeCleanup = {
//		[~chan, ~egbuf].free;
		~removeGResponder.();
		~procFree.();
	};

	~stopCleanup = {
		~activeRatios = Set.new;
	};

	~low_ = { |newLow = 2|
		var	minI = ~fullSet.minItem;
		if(newLow < minI) {	// extending low range lower
			(newLow .. minI - 1).do { |i| ~fullSet.add(i.asFloat) }
		} {
			if(newLow > minI) {
				(minI .. newLow - 1).do { |i| ~fullSet.remove(i.asFloat) }
			}
		};
		~low = newLow;
		currentEnvironment
	};

	~high_ = { |newHigh = 2|
		var	maxI = ~fullSet.maxItem;
		if(newHigh < maxI) {
			(newHigh + 1 .. maxI).do { |i| ~fullSet.remove(i.asFloat) }
		} {
			if(newHigh > maxI) {
				(maxI + 1 .. newHigh).do { |i| ~fullSet.add(i.asFloat) }
			}
		};
		~high = newHigh;
		currentEnvironment
	};

	~asPattern = {
		~makeStreamForKey.(\rat);
		~makeStreamForKey.(\numEv);
		Pspawner({ |sp|
			~spawner = sp;
			~spawnerStarted = thisThread.beats;	// for scheduling
			
			// busywait to reduce scheduling latency for new streams
			sp.par(Pbind(
				\instrument, \rest,
				\delta, 0.1 * Ptempo()
			));
			~initStreams.(sp);
		});
	};

	~oneStream = { |ratio = 1, repeats = 1, pbindf|
		var	self = currentEnvironment,
			result = Pbind(
				\instrument, \partial1bgated,
				\ratio, ratio,
				\freq, BPStream(\fund) * ratio,
				\egRate, ~tempoCtl.asMap,
				\egRateMul, ratio,
				\delta, ratio.reciprocal,
				\sustain, Pkey(\delta) * 0.5,
				\egBuf, ~egbuf,
				\chan, ~chan
			);
		if(pbindf.notNil) {
			result = Pbindf(result, *pbindf)
		};
		if(repeats.notNil) { result = Pfin(repeats, result) };
		// note, this doesn't call endhook if the process is stopped manually
		// (you should supply stopCleanup to handle it for that case)
		result = CleanupStream(result.asStream, e {
			~streamEndHook.(result, ratio);
		});
	};

	// this can be called by any gesture-trigger responder
	~addAStream = {
		var	ratio, numEv, test, stream;
		// 'any' test is slightly slower than != but !='s size check is not safe
		if(~isPlaying and: { ~fullSet.any { |item| ~activeRatios.includes(item).not } }) {
			ratio = ~ratStream.next;
			stream = ~spawner.par(
				~oneStream.(ratio, numEv = ~numEvStream.next(ratio).asInteger,
					[amp: ~makeAmpPattern.(numEv)]),
				0.1);
			~streamHook.(stream, ratio);
		};
	};

	~makeAmpPattern = { |numEv| Pgeom.fromEndpoints(1, rrand(0.02, 0.18), numEv) };

	~streamHook = { |stream, ratio|
		~activeRatios.add(ratio);
	};
	~streamEndHook = { |stream, ratio|
		~activeRatios.remove(ratio);
	};

	~makeGResponder = {
		~window = ResizeFlowWindow(~collIndex, Rect.aboutPoint(Window.screenBounds.center, 75, 25));
		~btn = Button(~window, Rect(0, 0, 140, 40))
			.states_([["GO"], ["full", Color.black, Color.new255(255, 200, 200)]])
			.font_(Font.default.copy.size_(28))
			.action_(e { |view|
				if(~addAStream.().isNil) {
					(e { view.value = 0 }).defer(0.5);
				} {
					view.value = 0;
				};
			});
		~window.recursiveResize.front;
	};

	~removeGResponder = { 
		if(~window.notNil and: { ~window.isClosed.not }) { ~window.close };
	};
} => PR(\hs1);

PR(\hs1).clone {
	~procInit = {
		~tophCtl = GenericGlobalControl(\numh, nil, 2, #[2, 60, \lin, 1]);

		// see pattern for sync with master clock
		~quant = NilTimeSpec.new;
	};
	~procFree = { ~tophCtl.free };
	~useGui = { |vpi| ~tophCtl => VP(vpi) };
	~makeGResponder = 0;
	~removeGResponder = 0;

	~asPattern = {
		Pspawner { |sp|
			var	num;
			if((num = thisThread.beats - BP(~cl).goTime) > 0) {
				sp.wait((num.trunc - num + 1));
				loop {
					num = ~tophCtl.value.asInteger - 1;
					sp.par(
						Ptpar([
							({ |i| i = i + 2; (1 - i.reciprocal) } ! num),
							{ |i|
								i = i + 2;
								Pbind(
									\chan, ~chan,
									\instrument, Pn(\partial1bgated, 2),
									\numHold, 1, //if(i == 0, 1, max(num / 4, 1)),
									\ratio, i,
									\freq, ~fund * Pkey(\ratio),
									\egRate, ~tempoCtl.asMap,
									\egRateMul, i,
									\egBuf, ~egbuf,
									\amp, 1,
									\delta, Pkey(\egRateMul).reciprocal * Pkey(\numHold),
									\sustain, Pkey(\delta) * (1 - (0.5 / Pkey(\numHold))),
									\panWidth, 0 //, // i/(num-1),
								)
							} ! num
						].lace(num*2), 1)
					);
					sp.wait(2);
				}
			}; // else, do nothing and spawner ends
		};
	};
} => PR(\hsSweep);

();
PR(\hs1).clone {
	~minTop = 2;
	~maxTop = 60;
	~procInit = {
		~tophCtl = GenericGlobalControl(\numh, nil, ~minTop, [~minTop, ~maxTop, \lin, 1]);
		~tophCtl.addDependant(currentEnvironment);
		// 0 is a dummy value
		~hStreams = Array.newClear(~maxTop + 1).overWrite(0 ! ~minTop);

		~offsetCtl = GenericGlobalControl(\offset, nil, 0.5, #[0, 0.5]);

		// see pattern for sync with master clock
		~quant = NilTimeSpec.new;
	};
	~procFree = { [~tophCtl, ~offsetCtl].free };
	~useGui = { |vpi| ~tophCtl => VP(vpi); ~offsetCtl => VP(vpi) };
	~makeGResponder = 0;
	~removeGResponder = 0;

	~stopCleanup = {
		(~minTop .. ~maxTop).do { |i| ~hStreams[i] = nil };
	};

	// inherit asPattern from hs1:
	// this process uses the same technique of adding harmonics dynamically
/*
	~oneStream = { |ratio = 1, repeats = 1, pbindf|
		var	self = currentEnvironment,
			result = Pfin(repeats, Pbind(
				\instrument, \partial1bgated,
				\ratio, ratio,
				\freq, BPStream(\fund) * ratio,
				\egRate, ~tempoCtl.asMap,
				\egRateMul, ratio,
				\delta, ratio.reciprocal,
				\sustain, Pkey(\delta) * 0.5,
				\egBuf, ~egbuf,
				\chan, ~chan
			));
		if(pbindf.notNil) {
			result = Pbindf(result, *pbindf)
		} {
			result
		};
		// note, this doesn't empty activeRatios if the process is stopped manually
		// (but stopCleanup does)
		result = CleanupStream(result.asStream, e {
			~streamEndHook.(result, ratio);
		});
	};
*/

	// this can be called by any gesture-trigger responder
	~addAStream = { |ratio = 2|
		var	stream, sync;
		if(~hStreams[ratio].isNil) {
			sync = ((0.1 * ~clock.tempo) + ~clock.beats - BP(~cl).goTime).roundUp(ratio.reciprocal)
				+ BP(~cl).goTime - ~clock.beats;
			stream = ~spawner.par(~oneStream.(ratio, nil), sync,
				[timingOffset: (1 - (ratio+1).reciprocal) * ~offsetCtl.asPattern]
			);
			~streamHook.(stream, ratio);
		};
	};

	~initStreams = {
		(~minTop .. ~tophCtl.value.asInteger).do { |i|
			~addAStream.(i)
		};
	};

//	~makeAmpPattern = { |numEv| Pgeom.fromEndpoints(1, rrand(0.02, 0.18), numEv) };

	~streamHook = { |stream, ratio|
		~hStreams[ratio] = stream;
	};
	~streamEndHook = { |stream, ratio|
		~hStreams[ratio] = nil;
	};

	// changing tophCtl value calls back here:
	~update = { |obj, msg|
		var	i;
		if(~isPlaying and: { obj === ~tophCtl and: { msg[\what] == \value } }) {
			if((i = ~hStreams.indexOf(nil)).isNil) {
				i = ~maxTop + 1;
			};
			if(i <= obj.value) {
				// add streams
				(i .. obj.value.asInteger).do { |ratio|
					~addAStream.(ratio)
				};
			} {
				if(i > (obj.value + 1)) {
					// remove streams
					(obj.value.asInteger + 1 .. i - 1).do { |ratio|
						~spawner.suspend(~hStreams[ratio]);
						~hStreams[ratio] = nil;
					};
				};
			};
		};
	};
} => PR(\hsDrone);
);

BP(\hs).free;
PR(\hs1) => BP(\hs);
0 => BP(\hs);

p = BP(\hs);

BP(\hswp).free;
PR(\hsSweep) => BP(\hswp);

BP(\hsd).free;
PR(\hsDrone).chuck(BP(\hsd), nil, (maxTop: 40));


// Pwxrand((2..20), (2..20).reciprocal.normalizeSum, inf);
//p.rat = \patRejectLastN.eval(Pexprand(2, Pseries(2, 1, 20) ++ Pn(20, inf), inf).round(1), 1);
//p.rat = Pexprand(2, Pclutch(Pseries(2, 1, { ~fullSet.size - 1 }), Pdiff(Ptime()) > 0) ++ Pn(20, inf), inf).round(1).reject { |x| ~activeRatios.includes(x) };

p.rat = Pseries(2.0, 1.0, { ~fullSet.size - 1 }) ++ (Pexprand(2, Plazy { Pn(~fullSet.maxItem, inf) }, inf).round(1).reject { |x| ~activeRatios.includes(x) });
p.numEv = Pfunc { |ratio| ratio } * Pwhite(1.5, 4) * Pseries(1, 0.02, inf);

p.fullSet = (1..50).asFloat.as(Set);

p.makeGui = {
	~window = ResizeFlowWindow(~collIndex, Rect.aboutPoint(Window.screenBounds.center, 75, 25));
	~btn = Button(~window, Rect(0, 0, 140, 40))
		.states_([["GO"]])
		.font_(Font.default.copy.size_(28))
		.action_(e {
			var	ratio, numEv, test;
			// took way too long to figure this out but...
			// this test is OK if both are Sets (not IdentitySets) and fullSet starts at 1.0
			// this is faster b/c == fails if the collection sizes are different
			if(not(~fullSet == ~activeRatios)) {
				ratio = ~ratStream.next;
				~spawner.par(
					~onePattern.(ratio, numEv = ~numEvStream.next(ratio).asInteger,
						[amp: Pgeom.fromEndpoints(1, 0.1, numEv)]),
					0.1)
			};
		});
	~window.recursiveResize.front;
};

p.makeGui;

p.activeRatios;
p.activeRatios.includes(1.0);



// sequence it!
(
BP(\hstrig).free;
Proto {
	~quant = 0;
	~delta = Pexprand(0.04, 0.2, inf) * Plazy { Env(#[20, 1], #[120], \exp).asStream };
	~event = (play: {
		BP(\hs).addAStream;
	});
	~asPattern = {
		Pbind(\delta, BPStream(\delta, resetSource: true))
	};
} => BP(\hstrig);
)

(
c = BP(\mstClock).clock;
t = TLSequenceIterator([
	{	BP(\hs).low_(2).high_(24);
		0
	},
	bpCmd: (name: \mstClock),
	12,
	bpCmd: (name: \hs),
	0.1,
	bpCmd: (name: \hstrig, dur: 120, doReset: true),

	// start hswp
	// automate tophCtl with dependency to raise BP(\hs).low

	\cmdSync,
	funcCmd: (func: { ~iterator.stop })
]).play(argClock: SystemClock);
)

t.stop


BP(\hstrig).delta = Pexprand(0.04, 0.2, inf) * Plazy { Env(#[32, 1], #[120], \exp).asStream };