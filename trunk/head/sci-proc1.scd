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
4.do { VP(0).v.addControlProxy(nil, true) };
VP(0).v.gui;

//k = VoicerMIDISocket(0, VP(0).v);

{	var cc;
	8.do {
		cc = VoicerMIDIController(\omni, \knob);
		cc => CC.prNew(cc.ccnum.shortName.asSymbol);
	};
}.value;

4.do { |i| CC(("k" ++ i).asSymbol) => VP(0) };

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
	~prep = {
		~tc = TempoClock(0.1, queueSize: 2048).permanent_(true);
		~tempoCtl = GenericGlobalControl(\tempo, nil, 0.1, #[0.01, 10, \exp]);
		~upd = Updater(~tempoCtl, e { |obj, msg|
			if(msg[\what] == \value) {
				~tc.tempo = obj.value
			};
		});
	};

	~useGui = { |vpi| ~tempoCtl => VP(vpi) };

	~freeCleanup = {
		~upd.remove;
		~tc.stop;
		~tempoCtl.free;
	}
} => BP(\mstClock);
);

(
PR(\abstractProcess).clone {
	~event = (eventKey: \singleSynthPlayNotify);
	~cl = \mstClock;
	~alwaysReset = true;

	~fund = 32.midicps;

	~prep = {
		~master ?? { ~master = topEnvironment[\master] };
		~chan = MixerChannel(~collIndex, s, 2, 2, outbus: ~master);

		~egbuf = Buffer.alloc(s, 1024, 1, { |buf|
			buf.setnMsg(0, Env(#[0, 1, 0], #[0.5, 0.5], \sine).discretize(1024))
		});

		~clock = BP(~cl).tc;
		~tempoCtl = BP(~cl).tempoCtl;

		~activeRatios = Set.new;

		~makeGResponder.();
		currentEnvironment
	};

	~freeCleanup = {
		[~chan, ~egbuf].free;
		~removeGResponder.();
	};

	~stopCleanup = {
		~activeRatios = Set.new;
	};

	~asPattern = {
		Pspawner({ |sp|
			~spawner = sp;
			~spawnerStarted = thisThread.beats;	// for scheduling
			
			// busywait to reduce scheduling latency for new streams
			sp.par(Pbind(
				\instrument, \rest,
				\delta, 0.1 * Ptempo()
			));

			// fundamental pulse
			sp.par(~oneStream.(1, inf));
		});
	};

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
		~activeRatios.add(ratio);
		// note, this doesn't empty activeRatios if the process is stopped manually
		// (but stopCleanup does)
		CleanupStream(result.asStream, { self.activeRatios.remove(ratio) });
	};

	// this can be called by any gesture-trigger responder
	~addAStream = {
		var	ratio, numEv, test;
		// took way too long to figure this out but...
		// this test is OK if both are Sets (not IdentitySets) and fullSet starts at 1.0
		// this is faster b/c == fails if the collection sizes are different
		if(~isPlaying and: { not(~fullSet == ~activeRatios) }) {
			ratio = ~ratStream.next;
			~spawner.par(
				~oneStream.(ratio, numEv = ~numEvStream.next(ratio).asInteger,
					[amp: ~makeAmpPattern.(numEv)]),
				0.1)
		};
	};

	~makeAmpPattern = { |numEv| Pgeom.fromEndpoints(1, rrand(0.02, 0.18), numEv) };

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


);

BP(\hs).free;
PR(\hs1) => BP(\hs);
0 => BP(\hs);

p = BP(\hs);

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


