// harmonic series processes

Library.put(\chucklib, \midiSearches, #["remote"]); BP.loadGui;
#[glrvbmc, glrvb, lcrvbmc, lcrvb, master].do({ |obj| obj.envirGet.free; obj.envirPut(nil) });
s.waitForBoot(e { (Document.current.path.dirname +/+ "head-defs.scd").debug("loading").loadPath });


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

		~chan = MixerChannel(~collIndex, s, 2, 2, outbus: ~master, completionFunc: { |chan|
			// adding harmonics increases volume a lot
			// this reduces the amp variation from about 20dB to about 6
			chan.playfx(Instr("busfx.companderd"), [0, 2, 0.03, 1.0, 0.10660504994928, 0.0022888750750465, 0.1821720077621, 7.2629183877784, 0.005]);
		});
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
					[	amp: ~makeAmpPattern.(numEv),
						panCtr: rrand(ratio / ~high - 0.4, ratio / ~high) * #[-1, 1].choose,
						panWidth: (1 - Pkey(\panCtr).abs) * (ratio / ~high)
					]),
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
	~alwaysReset = true;
	~minTop = 2;
	~maxTop = 32;
	~procInit = {
		~lowhCtl = GenericGlobalControl(\lowh, nil, ~minTop, [~minTop, ~maxTop, \lin, 1]);
		~tophCtl = GenericGlobalControl(\numh, nil, ~minTop, [~minTop, ~maxTop, \lin, 1]);

		// see pattern for sync with master clock
		~quant = NilTimeSpec.new;
	};
	~procFree = { [~lowhCtl, ~tophCtl].free };
	~useGui = { |vpi| ~lowhCtl => VP(vpi); ~tophCtl => VP(vpi) };
	~makeGResponder = 0;
	~removeGResponder = 0;

	~panGen = Pif(Pfunc { |num| num > 1 }, Prand(#[lr, rl, ctrout, scatter], inf), \zero);
	~lr = Plazy { |num| Pseries.fromEndpoints(-1.0, 1.0, num) };
	~rl = Plazy { |num| Pseries.fromEndpoints(1.0, -1.0, num) };
	~ctrout = Plazy { |num| Pseries.fromEndpoints(0.0, 1.0, num) * Pseq(#[-1, 1], inf, { 2.rand }) };
	~scatter = Pwhite(-1.0, 1.0, inf);
	~zero = 0;

	~asPattern = {
		~makeStreamForKey.(\panGen);
		Pspawner { |sp|
			var	num, panGen;
			if((num = thisThread.beats - BP(~cl).goTime) > 0) {
				sp.wait((num.trunc - num + 1));
				loop {
					num = ~tophCtl.value.asInteger - ~lowhCtl.value.asInteger + 1;
					panGen = ~panGenStream.next(num).envirGet.asStream;
					sp.par(
						Ptpar((~lowhCtl.value.asInteger .. ~tophCtl.value.asInteger).collect({ |i|
							[	(1 - i.reciprocal),
								Pbind(
									\chan, ~chan,
									\instrument, Pn(\partial1bgated, 2),
									\numHold, 1, //if(i == 0, 1, max(num / 4, 1)),
									\ratio, i,
									\freq, ~fund * Pkey(\ratio),
									\egRate, ~tempoCtl.asMap,
									\egRateMul, i,
									\egBuf, ~egbuf,
									// empirically, unity gain is about 4dB too loud
									\amp, -4.dbamp,
									\delta, Pkey(\egRateMul).reciprocal * Pkey(\numHold),
									\sustain, Pkey(\delta) * (1 - (0.5 / Pkey(\numHold))),
									\panCtr, panGen.next(num),
									\panWidth, 0
								)
							]
						}).flat, 1
					));
					sp.wait(2);
				}
			}; // else, do nothing and spawner ends
		};
	};
} => PR(\hsSweep);

();
PR(\hs1).clone {
	~minTop = 2;
	~maxTop = 40;
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

	// this can be called by any gesture-trigger responder
	~addAStream = { |ratio = 2|
		var	stream, sync;
		if(~hStreams[ratio].isNil) {
			sync = ((0.1 * ~clock.tempo) + ~clock.beats - BP(~cl).goTime).roundUp(ratio.reciprocal)
				+ BP(~cl).goTime - ~clock.beats;
			stream = ~spawner.par(~oneStream.(ratio, nil, 
				[	timingOffset: (1 - (ratio+1).reciprocal) * ~offsetCtl.asPattern,
					panCtr: 0,
					panWidth: ratio / ~tophCtl.value
				]),
				sync
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

BP(\fmt).free;
PR(\basicSynthChooser).chuck(BP(\fmt), nil, (
	chan: BP(\mstClock).chan,
	isFx: true,
	alwaysReset: true,
	event: (eventKey: \monoSupport),
	userprep: {
		~fmtKeys = FormantTable.keys.select { |k| k.asString.contains("tenor") }.asArray;
	},
	delta: Pexprand(0.1, 0.9, inf), // Pexprand(1.0, 4.0, inf),
	formant: Plazy { Pxrand(~fmtKeys, inf) },
	fadeIn: 8,
	fadeOut: 4,
	objects: (
		fmt: (
			def: SynthDef(\formantfx2, { |inbus, outbus, t_trig = 0, slideTime = 1, gate = 1, amp = 1,
					fadeIn = 5, fadeOut = 5|
				var	ffreqs = NamedControl.kr(\ffreqs, Array.series(5, 400, 400)),
					amps = NamedControl.kr(\amps, 1 ! 5),
					qs = NamedControl.kr(\qs, 0.1 ! 5),
					sig = In.ar(inbus, 2), sig2,
					wet = Linen.kr(gate, fadeIn, 1, fadeOut, doneAction: 2);
				ffreqs = ffreqs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
				amps = amps.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
				qs = qs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
				sig2 = BBandPass.ar(sig, ffreqs, qs, amps).sum * amp;
				sig = XFade2.ar(sig, sig2, wet.madd(2, -1));
				ReplaceOut.ar(outbus, sig);
			}),
			args: [
				protoEvent: Pseq([\singleSynthPlayNotify, Pn(\singleSynthTrigger, inf)]),
				#[ffreqs, amps, qs], Pnsym(BPStream(\formant), FormantTable),
				ffreqs: Pkey(\ffreqs) * Pexprand(0.95, 0.95.reciprocal, inf).clump(5),
				trig: 1,
				slideTime: Pkey(\delta) * Pwhite(0.4, 0.8, inf),
				inbus: Plazy { Pn(~chan.inbus, inf) },
				node: Pfunc { ~node ? 0 },
				sustain: inf,
				amp: 12.5.dbamp,
				fadeIn: BPStream(\fadeIn),
				fadeOut: BPStream(\fadeOut)
			]
		)
	),
	recvEventNotify: { |node, event|
		~node = node;
	},
 	stopCleanup: { ~node.release; ~node = nil; ~makeStreamForKey.(\fmtprotoEvent) }
));
)

BP(\mstClock).chan.startRecord(thisProcess.platform.recordingsDir +/+ "harmonics-demo.aiff");


// general init

(
BP.all.free;
Fact(\mstClock) => BP(\mstClock);

PR(\hs1) => BP(\hs);
Fact(\hstrig) => BP(\hstrig);

PR(\hsSweep) => BP(\hswp);

PR(\hsDrone).chuck(BP(\hsd), nil, (maxTop: 40));
Fact(\formantfx1) => BP(\fmt);

BP(\cpt).free;
PR(\counterpoint).chuck(BP(\cpt), nil, (master: ~master));
0 => BP(\cpt);

BP(\cd).free;
PR(\cadences).chuck(BP(\cd), nil, (parentBP: \cpt));
0 => BP(\cd);

Fact(\int) => BP(\int);
// what clock should int use?
~clock60 ?? { ~clock60 = TempoClock(tempo: 1, queueSize: 1024) };
~clock60 => BP(\int);

BP(#[cd, cpt, fmt, hs, hsd, hstrig, hswp, int, mstClock]).do { |bp| bp.printStopMsg = false };

(1..3).do { |i| Fact(("drum" ++ i).asSymbol).chuck(BP(("drum" ++ i).asSymbol), nil, (source: \drum1)) };

NotificationCenter.registerOneShot(\drum3, \ready, \bploader, e {
	Fact(\drum4).chuck(BP(\drum4), nil, (pan: -1));
	// 5 and 6 are basically copies - switch between them to change phase vs. drum4
	Fact(\drum4).chuck(BP(\drum5), nil, (pan: 1, chan: BP(\drum4).chan));
	Fact(\drum4).chuck(BP(\drum6), nil, (pan: 1, chan: BP(\drum4).chan));

	Fact(\drum7) => BP(\drum7);
	Fact(\drum7).chuck(BP(\drum8), nil, (ctlSource: \drum7, quant: #[-1, 1.25]));
});

PR(\bpCmd).clone {
	~setDoneSignal = {
		~playing = if(BP(\drum5).isPlaying) { \drum5 } { \drum6 };
		~name = if(~playing == \drum5) { \drum6 } { \drum5 };
		BP(~playing).stop(~quant);
	};
	~prepareBP = { |bp| ~extraPrep.(bp); bp.reset };
} => PR(\swap56cmd);
)

i = 0;
BP.keys.asArray.sort.do { |key|
	BP(key) => MT(1);
// 	if(BP(key)[\chan].notNil and: { BP(key)[\chan].mcgui.isNil }) {
// 		BP(key) => MCG(i);
// 		i = i + 1;
// 	}
};

d = DDWTimer.new;

(
var	drumLevel = -7.dbamp,
	waitForNotesCmd = PR(\funcCmd).copy.putAll((
		setDoneSignal: {
			~doneSignal = NotificationCenter.register(\notes, \go, \drumproc, e { |args|
				args.debug("got go signal");
				~doneSignal.remove;  // this is a NotificationRegistration
				~stop.();
			});
		},
		clearDoneSignal: { ~doneSignal = nil }
	)),
	t2 = TLSequenceIterator([
		{	var	bp = BP(\drum1);
			bp.bar = 3;
			bp.wetCtl.value = 0.98;
			bp.fdecCtl.value = 0.25;
			bp.ffLowCtl.value = 2;
			bp.ffRangeCtl.value = 0;
			BP.all.do { |bp|
				if(bp.collIndex.asString.contains("drum")) {
					bp[\chan].tryPerform(\level_, drumLevel);
				};
			};
			// if(d.class == DDWTimer) { d.reset };
			0
		},
	/*
		loopCmd: (
			setDoneSignal: {
				~doneSignal = true;
				defer(e {
					~window = ResizeFlowWindow("trigger",
						Rect(Window.screenBounds.width - 200, 50, 200, 100));
					Button(~window, 90@20)
						.states_([["go"]])
						.action_(e {
							if(BP(\drum1).isPlaying.not) { ~cmd.stop };
						});
					Button(~window, 90@20)
						.states_([["move on"]])
						.action_(e {
							currentEnvironment.stop;
						});
					~window.recursiveResize.front;
				})
			},
			clearDoneSignal: { defer(e { ~window.close }) },
			cmds: [
				{	PR(\funcCmd).copy.putAll((
						looper: currentEnvironment,
						func: { ~looper.cmd = currentEnvironment },
						doneSignal: true
					))
				},
				\cmdSync,
				{	if(~doneSignal == true) {
						PR(\bpCmd).copy.putAll((
							name: \drum1,
							quant: 1,
							dur: 2.9
						))
					}
				},
				\cmdSync
			]
		),
		\sync,
	*/

		waitForNotesCmd, \cmdSync,
		Quant(3, -0.5),
	
	
		bpCmd: (name: \drum1, quant: `nil, prepareBP: { |bp|
			bp.bar = Pseq(#[3, 0], inf);
		}),
		12,
		gcAutoSynthCmd: (gc: BP(\drum1).wetCtl, name: \ctlPoint, outName: \outbus, 
			value: 0.078, time: 30, curve: 0),
		bpCmd: (name: \drum2, quant: `nil, prepareBP: { |bp|
			bp.bar = Pseq(#[0, 2], inf);
		}),
		12,

		[	{	BP(\drum1).bar = Pseq([3, Prand(BP(\drum1).indices[1], 1)], inf);
				12
			},
			{	BP(\drum2).bar = Prand(BP(\drum2).indices[1], inf);
				12
			},
		
			{	BP(\drum2).bar = Prand(#[1, 2, 3], inf);
				12
			},
			gcAutoSynthCmd: (gc: BP(\drum1).ffRangeCtl, name: \ctlEnv, outName: \outbus, 
				env: Env(#[0, 14, 0], #[0.6, 0.4], #[6, -2]), time: 30, connect: 0),
		],

		waitForNotesCmd, \cmdSync,
		Quant(3, -0.5),
	
		bpCmd: (name: \drum3, quant: `nil, prepareBP: { |bp|
			bp.bar = Prand(#[8, 2], inf);
			bp.ffreqCtl.value = 60;
		}),
		mixerAutoSynthCmd: (mixer: BP(\drum3).chan, name: \ctlEnv, outName: \outbus,
			connect: 0, env: Env([0, drumLevel], #[18], 2.4)),
		gcAutoSynthCmd: (gc: BP(\drum3).ffreqCtl, name: \ctlPoint, outName: \outbus, 
			value: 18000, time: 30, curve: 5),
		
		{	BP(\drum3).bar = Prand([8, 2], inf) + Prand(#[0, 1, 4], inf);
			BP(\drum2).bar = 3;
			12
		},
	
		{	BP(\drum3).bar = Prand(BP(\drum3).indices[2], inf);
			12
		},
	
		{	BP(\drum3).bar = Prand(BP(\drum3).indices[[2, 3]].flat, inf);
			BP(\drum1).bar = 3;
			24
		},
	
		{	BP(\drum3).bar = 15;
			6
		},
	
		waitForNotesCmd, \cmdSync,
		Quant(3, -0.5),

		{ BP(#[drum1, drum2, drum3]).stop; 0 },
	
		bpCmd: (name: #[drum4, drum5], quant: `nil, prepareBP: { |bp|
			var	panEnd = -1;
			bp.reset;
			if(bp.collIndex == \drum5) {
				bp.quant = #[-1, 0.02];
				panEnd = 1;
				bp.amp = Pseq(#[1, 1 /* finger-amp */], inf) * Env(#[0, 1], #[12], 2.4)
			};
			bp.pan = Env([0, panEnd], #[30]);
			bp.wetCtl.value = 0.078;
		}),
	
		18,
		swap56cmd: (quant: #[-1, 0.25], extraPrep: { |bp| bp.amp = Pseq(#[1, 1 /* finger-amp */], inf) }),
		gcAutoSynthCmd: (gc: BP(\drum4).ffRangeCtl, name: \ctlPoint, outName: \outbus, 
			value: 18, time: 36),
	
		24,
		swap56cmd: (quant: #[-1, 1.25], extraPrep: { |bp| bp.amp = Pseq(#[1, 1 /* finger-amp */], inf) }),
		24,
		swap56cmd: (quant: #[-1, 0.75]),
		24,
	
		waitForNotesCmd, \cmdSync,
		Quant(3, -0.5),

		{	BP(#[drum4, drum5, drum6]).stop;
			BP(\drum7).pan = -1;
			BP(\drum8).pan = 1;
			BP(\drum7).quant = -1;
			BP(\drum8).quant = #[-1, 0.75];
			0
		},
	
		bpCmd: (name: #[drum7, drum8], quant: -1, prepareBP: { |bp|
			bp.ostFiltCtl.value = 1;
			bp.fmltDcyCtl.value = 0.25;
			bp.fmltWetCtl.value = 0.1;
		}),
		funcCmd: (doneSignal: true,
			num3: rrand(2, 7),
			func: {
				var	thisCmd = currentEnvironment;
				BP(#[drum7, drum8]).do { |bp|
					~num3 = ~num3 + 5;
					bp.gest = Pseq([
						CleanupStream(
							Pseq([\threePl1, Pn(\threeAcc, ~num3), \ostFilt2Quant]).asStream,
							{ thisCmd.stop }
						),
						Pn(\ostFilt2, inf)
					]);
					bp.accFreq = 52 * Pwhite(2, Pseries.fromEndpoints(16, 5, ~num3) ++ Pn(5, inf), inf);
					bp.accFreq2 = (Pkey(\ffreq) * Pwhite(2, 4, inf)).wrap(52, 52 * (Pseries.fromEndpoints(16, 5, ~num3) ++ Pn(5, inf)));
				};
			}
		),
		\cmdSync,
		{ "synced".debug; 6 },
	
		36,
		loopCmd: (repeats: 2,
			qphase: Pseq(#[1.25, 0.75], inf).asStream,
			acc: Pseq([\threeAcc, Prand(#[fiveAcc, sevenAcc], inf)]).asStream,
			cmds: [
				{	var	numAcc = rrand(3, 6), acc = ~acc.next,
						pat = Pseq([\ostFilt2Sync, Pn(acc, numAcc), \ostFilt2Quant], 1);
					BP(#[drum7, drum8]).do { |bp|
						bp.override(\gest, pat);
					};
					BP(\drum8).quant = [-1, ~qphase.next];
					24
				}
			]
		),
		\cmdSync,
	
		{	BP(\drum8).gest = Pfsm([
				#[4, 5],
				Pwrand(#[five, fiveRest], #[0.5, 0.5], { rrand(2, 4) }), #[0, 1, 2, 3],
				Pwrand(#[seven, sevenRest], #[0.5, 0.5], { rrand(2, 4) }), #[0, 1, 2, 3],
				\fiveAcc, #[2, 4, 5],
				\sevenAcc, #[3, 4, 5],
				\five1Acc, #[0, 2],
				\seven1Acc, #[1, 3],
			], inf);
			6
		},
		{	BP(\drum7).gest = BP(\drum8).gest;
			6 //24
		},
	
		loopCmd: (repeats: 3,
			acc: Prand(#[threeAcc, fiveAcc, sevenAcc], inf),
			cmds: [
				{	var	// both 7+8 use the same random seed
						pat = Pseed(Pn(Date.seed, 1), Pseq([
							Pif(Ptime() < rrand(8, 15), Pseq([\randsync, ~acc], 1)),
							\randquant
						], 1));
					BP(#[drum7, drum8]).do { |bp|
						bp.keepGoing = false;
						bp.override(\gest, pat);
					};
					BP(\drum8).quant = -1;
					rrand(3, 6) * 6
				}
			]
		),
		\cmdSync,
	
		gcAutoSynthCmd: (gc: BP(\drum7).fmltWetCtl, name: \ctlPoint, outName: \outbus,
			value: 0.736, time: 20, curve: 2),
		loopCmd: (repeats: 4,
			cmds: [
				funcCmd: (
					doneSignal: true,
					func: {
						var	seed = Date.seed, num = rrand(7, 15),
							thisCmd = currentEnvironment,
							n = Pxrand((2..8), num).asStream.all.debug("n"),
							factor = { rrand(1, 2) } ! num,
							rest = #[1, 2].wchoose(#[0.8, 0.2]);
						BP(#[drum7, drum8]).do { |bp|
							var	once = true, saven, saveFactor;
							bp.keepGoing = false;
							bp.override(\restBeats, Pn(rest, 1));
							bp.override(\gest, Pseq([
								\randsync,
								\oneAcc,
								Pseed(Pn(seed, 1),
									Pwrand(#[nhigh, nhighAcc], #[0.4, 0.6], num)
								).collect { |gest|
									if(once) {
										bp.override(\n, Pseq(n, 1));
										bp.override(\factor, Pseq(factor, 1));
										once = false;
									};
									gest
								}
							], 1), false, { thisCmd.stop });
						};
					}
				),
				\sync,
				{ if(~repeats > 1) { rrand(18, 48) } { 0 } }
			]
		),
		\cmdSync,
		{ "synced".debug; 0 },
	
		{	BP(\drum7).gest = Pseq([
				\randsync,
				Pwrand(#[ngap, ngapAcc, nhigh, nhighAcc], #[0.2, 0.2, 0.3, 0.3], { rrand(7, 15) }),
				Pfin((Pwhite(4, 8, inf) * Pseries.fromEndpoints(5, 0.3, 5)).trunc.trace(prefix: "7-num57: ").asStream, BP(\drum7).gest)
			], inf);
			12
		},
	
		{	BP(\drum8).gest = Pseq([
				\randsync,
				Pwrand(#[ngap, ngapAcc, nhigh, nhighAcc], #[0.2, 0.2, 0.3, 0.3], { rrand(7, 15) }),
				Pfin((Pwhite(4, 8, inf) * Pseries.fromEndpoints(5, 0.3, 5)).trunc.trace(prefix: "8-num57: ").asStream, BP(\drum8).gest)
			], inf);
			36
		},
	
	// 	36,
	//	funcCmd: (func: { ~iterator.stop })
	//	{ BP.all.stop; 8 },
	//	{ ~master.stopRecord; 0 }
	]);

if(t.tryPerform(\isRunning) ? false) { t.stop; "Wait for t to stop first".die };

c = BP(\mstClock).clock;
t = TLSequenceIterator([
	{	BP(\hs).low_(2).high_(24);
		#[chan, chan2].do { |key| BP(\mstClock)[key].level = -15.dbamp };
		if(d.class == DDWTimer) { d.reset };
		0
	},
	bpCmd: (name: \mstClock/*, prepareBP: { |bp|
		bp.tempoCtl.value = 0.1;
	}*/),
	gcAutoSynthCmd: (
		gc: BP(\mstClock).tempoCtl, name: \ctlEnv, outName: \outbus,
		connect: 0, env: Env(#[0.1, 0.1, 0.245], #[25, 60]), time: 1
	),
	6,
	bpCmd: (name: \hs, prepareBP: { |bp|
		bp.debug.use {
			~lastRise = 1;
			~rat = Pswitch1([
				Pwhile1({ |in, item| ~lastRise = item; item <= ~high }, Pseries(~low, 1, inf)),
				(Pexprand(Pfunc { ~low }, Pfunc { ~high }, inf)
					.round(1).reject { |x| ~activeRatios.includes(x) });
			], Pfunc {
				(~lastRise.linexp(~low, ~high, 0.005, 1)/*.debug("coin")*/.coin
				or: { ~activeRatios.includes(~lastRise+1.0)/*.debug("already playing %".format(~lastRise+1))*/ })
				.binaryValue
			});
		};
	}),
	0.1,
	bpCmd: (name: \hstrig, doReset: true, setDoneSignal: { |bp|
		~upd = Updater(BP(\hs), e { |obj, what|
			if(what == \allChildrenStopped) {
				~upd.remove;
				BP(\hs).stop;
			}
		});
	}),

	45,
	bpCmd: (name: \hswp, prepareBP: { |bp|
		bp.debug.lowhCtl.value = 2;
		bp.tophCtl.value = 2;
	}),
	gcAutoSynthCmd: (
		gc: BP(\hswp).tophCtl, name: \ctlPoint, outName: \outbus,
		value: 32, time: 40, curve: 1.6,
		setDoneSignal: {
			~upd = Updater(~gc, e { |obj, msg|
				var	val;
				if(msg[\what] == \value and: { (val = ~gc.value.asInteger) > BP(\hs).low }) {
					if(val < BP(\hs).high) {
						BP(\hs).low = val+1;
					} {
						BP(#[hstrig]).stop;
					}
				};
			});
		},
		clearDoneSignal: { ~upd.remove }
	),

	25,
// 	#[30] ++ #[chan, chan2].collect { |key|
// 		PR(\mixerAutoSynthCmd).copy.putAll((
// 			mixer: BP(\mstClock)[key], name: \ctlPoint, outName: \outbus,
// 			value: -15.dbamp, time: 30, curve: -2.1
// 		))
// 	},
	bpCmd: (name: \hsd, prepareBP: { |bp|
		bp.debug.tophCtl.value = 2;
	}),
	gcAutoSynthCmd: (
		gc: BP(\hsd).tophCtl, name: \ctlPoint, outName: \outbus,
		value: 32, time: 45, curve: 1.6,
		setDoneSignal: {
			~upd = Updater(~gc, e { |obj, msg|
				var	val;
				if(msg[\what] == \value and: { (val = ~gc.value.asInteger) > BP(\hswp).low }) {
					if(val < BP(\hswp).tophCtl.value) {
						BP(\hswp).lowhCtl.value = val+1;
					} {
						BP(\hswp).stop;
					}
				};
			});
		},
		clearDoneSignal: { ~upd.remove; BP(\hswp).stop }
	),
//	\cmdSync,
	20,
	bpCmd: (name: \fmt, prepareBP: { |bp|
		bp.debug.fadeIn = 22;
		bp.fadeOut = 12;
	}),

// start choral section (which was always after formants)

	25, //{ rrand(10.0, 18.0) },

	// DRUM SUB-ITERATOR
	funcCmd: (
		subIter: t2,
		setDoneSignal: {
			~doneSignal = Updater(~subIter, e { |obj, what|
				if(what.debug("t2 notification") == \done) {
					~doneSignal.remove;
					~stop.()
				};
			});
		},
		clock108: ~clock108,
		func: {
			~subIter.play(argClock: ~clock108 ? TempoClock.default);
		},
		done: {
			~subIter.stop;
		},
		clearDoneSignal: {
			~doneSignal = nil;
		}
	),

	bpCmd: (name: \cd, prepareBP: { |p|
		p.debug("choral").tempoPat = 1;
		p.chan.level = -1.dbamp;
		p.dur = Pwhite(0.9, 1.25, inf) *.x Pwhite(12.0, 16.0, { |num| num });
		p.p5_(0).sharp_(false).shortFirst_(false).oneNote_(true);
		p.reset;	// maybe voodoo, but it seems sometimes \cd reuses a freed bus object??
	}),
	\cmdSync,

	{ rrand(10.0, 16.0) },

	[	{ rrand(5.0, 8.0) },
		{	NotificationCenter.notify(\notes, \go, 0);  // tell drum process to move ahead
			0
		}
	],
	bpCmd: (name: \cd, prepareBP: { |p|
		p.oneNote_(false);
	}),
	\cmdSync,
	7, //{ rrand(6.0, 14.0) },

	bpCmd: (name: \cpt, prepareBP: { |p|
		p.filterNotePat = nil;
		p.useLpf = false;
		p.seqKeys = #[t2];
		p.tempoPat = (42/60) * Pexprand(0.75, 0.5.reciprocal, inf);
		p.att_(0.7).rel_(0.9).dec_(1.2);
		p.reset;
	}),
	\cmdSync,
	2, //{ rrand(6.0, 9.0) },

	[	{ rrand(5.0, 8.0) },
		{	NotificationCenter.notify(\notes, \go, 1);
			0
		}
	],
	bpCmd: (name: \cd, prepareBP: { |p|
		p.dur = Pwhite(0.5, 0.8, inf) *.x Pwhite(12.0, 16.0, { |num| num });
		p.p5_(1).shortFirst_(true);
	}),
	\cmdSync,
	{ rrand(8.0, 12.0) },

	bpCmd: (name: \cpt, prepareBP: { |p|
		p.seqKeys = #[t2, a2b];
	}),
	\cmdSync,
	2, //{ rrand(6.0, 9.0) },

	bpCmd: (name: \cd, prepareBP: { |p|
		p.sharp_(true);
	}),
	\cmdSync,
	{ rrand(8.0, 12.0) },

	[	{ rrand(5.0, 8.0) },
		{	NotificationCenter.notify(\notes, \go, 2);
			0
		}
	],
	bpCmd: (name: \cpt, prepareBP: { |p|
		p.tempoPat = (42/60) * Pexprand(0.75, 0.5.reciprocal, inf);
		p.seqKeys = #[t3, a31, a32];
	}),
	\cmdSync,
	2,

	bpCmd: (name: \cd, prepareBP: { |p|
		p.p5_(2);
	}),
	\cmdSync,
	{ rrand(8.0, 12.0) },

	[	{ rrand(4.0, 8.0) },
		loopCmd: (
			repeats: 3,
			setDoneSignal: {  // init
				~count = 0;
				~doneSignal = \ifIDontPutSomethingInHereItWillStopImmediately;
			},
			cmds: [
				{ rrand(3.0, 9.0) },
				{	~bpDur = rrand(7.0, 11.0);
					PR(\bpCmd).copy.putAll((name: \int, dur: ~bpDur))
				},
				{	var	up = rrand(0.1, 0.3);
					PR(\mixerAutoSynthCmd).copy.putAll((
						mixer: BP(\int).chan, name: \ctlEnv, outName: \outbus,
						connect: 0, time: ~bpDur, env: Env(#[-24, -8.5, -24].dbamp, [up, 1-up], \exp)
					))
				},
				{	(if((~count = ~count + 1) < ~repeats) { ~bpDur }
					{ ~doneSignal = nil })
				}
			]
		),
		\cmdSync,
		bpCmd: (name: \int),
		mixerAutoSynthCmd: (
			mixer: BP(\int).chan, name: \ctlPoint, outName: \outbus,
			value: -8.5.dbamp, time: 3.5, curve: 2.1
		)
	],

	bpCmd: (name: \cpt, prepareBP: { |p|
		p.seqKeys = #[t2, a2d1, a2d2];
	}),
	\cmdSync,
	2,

	bpCmd: (name: \cpt, prepareBP: { |p|
		p.filterNotePat = { |pat|
			Pfin(pat.estimateLength - 1, pat)
		};
		p.seqKeys = #[t4, a41, a42];
		p.tempoPat = 1;
		p.useLpf = true;
	}),
	\cmdSync,
	{ rrand(1.0, 2.5) },

	bpCmd: (name: \cpt, prepareBP: { |p|
		p.tempoPat = 2.5;
		p.filterNotePat = { |pat|
			Pfin(pat.estimateLength - 1, pat).drop(1)
		};
	}),
	\cmdSync,
	{ rrand(1.0, 2.5) },

	[	{ rrand(1.0, 3.0) },
		{	NotificationCenter.notify(\notes, \go, 3);
			0
		}
	],
	bpCmd: (name: \cpt, prepareBP: { |p|
		p.tempoPat = 1.2;
		p.filterNotePat = { |pat|
			pat.drop(pat.estimateLength - 1)
		};
	}),
	\cmdSync,

// 	{ rrand(6.0, 9.0) },
// 	funcCmd: (func: { ~iterator.stop })
]).play(argClock: SystemClock)
)

t.stop;

BP.all.stop
BP.all.free


BP(\cd).clock === TempoClock.default.tempo

~master.stopRecord;


/* scrap
	{ rrand(3.0, 6.0) },

	bpCmd: (name: \cpt, prepareBP: { |p|
		p.chan.level = -7.dbamp;
		p.seqKeys = #[a41, a42, t4, b4];
	}),
	\cmdSync,
	{ rrand(1.0, 4.0) },

	bpCmd: (name: \cpt, prepareBP: { |p|
		p.tempoPat = { 1.1 * (Env(#[1, 1, 0.56], #[6, 6], 3).asStream) };
		p.seqKeys = #[a51, a52, t5, b5];
	}),
	\cmdSync,
*/


t = TLSequenceIterator([
	bpCmd: (name: \cd, prepareBP: { |p|
		p.tempoPat = 1;
		p.chan.level = -3.8.dbamp;
		p.dur = Pwhite(0.9, 1.25, inf) *.x Pwhite(12.0, 16.0, { |num| num });
		p.p5_(false).sharp_(false).shortFirst_(false).oneNote_(true);
	})
]).play;

t.stop

BP(\cd).p5_(2).sharp_(true).shortFirst_(true).oneNote_(false);

BP(\int).clock.gui;


// scrap?
t.stop
BP(\mstClock).chan.stopRecord;

t.isPlaying

BP(\hstrig).delta = Pexprand(0.04, 0.2, inf) * Plazy { Env(#[32, 1], #[120], \exp).asStream };

BP(\mstClock).fund * 32
FormantTable.keys.select { |k| k.asString.contains("tenor") }.do { |k| FormantTable.at(k).postln }; ""

BP(\fmt).delta = Pexprand(0.1, 0.9, inf);
BP(\fmt).fmtslideTime = Pkey(\delta) * Pwhite(0.4, 0.8, inf);


~master.startRecord(thisProcess.platform.recordingsDir +/+ "drone-chorus.aiff");

BP.all.do { |bp| bp.printStopMsg = false };

~clock60 = TempoClock(tempo: 1, queueSize: 1024);
~clock60 => BP(\int);

p = BP(\cpt);
