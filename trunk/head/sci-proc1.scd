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

k = VoicerMIDISocket(0, VP(0).v);

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
		~chan = MixerChannel(~collIndex, s, 2, 2);

		~egbuf = Buffer.alloc(s, 1024, 1, { |buf|
			buf.setnMsg(0, Env(#[0, 1, 0], #[0.5, 0.5], \sine).discretize(1024))
		});

		~clock = BP(~cl).tc;
		~tempoCtl = BP(~cl).tempoCtl;

		~activeRatios = IdentitySet.new;
	};

	~freeCleanup = {
		[~chan, ~egbuf].free;
		if(~window.notNil and: { ~window.isClosed.not }) { ~window.close };
	};

/*
	~recvEventNotify = { |node, ev|
		var	ratio = ev[\ratio];
		if(ev[\instrument] != \rest) {
			~activeRatios.add(ratio);
			OSCpathResponder(~chan.server.addr, ['/n_end', node.nodeID], e { |time, resp, msg|
				resp.remove;
				~activeRatios.remove(ratio);
			}).add;
		};
	};
*/

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
			sp.par(~onePattern.(1, inf));
		});
	};

	~onePattern = { |ratio = 1, repeats = 1, pbindf|
		var	self = currentEnvironment,
			result = Pfset(
				{ self.activeRatios.add(ratio).debug(">> activeRatios") },
				Pfin(repeats, Pbind(
				\instrument, \partial1bgated,
				\ratio, ratio,
				\freq, BPStream(\fund) * ratio,
				\egRate, ~tempoCtl.asMap,
				\egRateMul, ratio,
				\delta, ratio.reciprocal,
				\sustain, Pkey(\delta) * 0.5,
				\egBuf, ~egbuf,
				\chan, ~chan
				)),
				{ self.activeRatios.remove(ratio); self.activeRatios.debug("<< activeRatios") }
			);
		if(pbindf.notNil) {
			Pbindf(result, *pbindf)
		} {
			result
		};
	};
} => PR(\hs1);
);

BP(\hs).free;
PR(\hs1) => BP(\hs);
0 => BP(\hs);

p = BP(\hs);

// Pwxrand((2..20), (2..20).reciprocal.normalizeSum, inf);
p.rat = \patRejectLastN.eval(Pexprand(2, Pseries(2, 1, 20) ++ Pn(20, inf), inf).round(1), 1);
p.rat = Pexprand(2, Pclutch(Pseries(2, 1, 20), Pdiff(Ptime()) > 0) ++ Pn(20, inf), inf).round(1).reject { |x|
	~activeRatios.includes(x)
};

p.fullSet = (1..20).as(IdentitySet);

p.makeGui = {
	~window = ResizeFlowWindow(~collIndex, Rect.aboutPoint(Window.screenBounds.center, 75, 25));
	~btn = Button(~window, Rect(0, 0, 140, 40))
		.states_([["GO"]])
		.font_(Font.default.copy.size_(28))
		.action_(e {
			var	ratio;
			if((~fullSet - ~activeRatios).size > 0) {
				ratio = ~ratStream.next;
				~spawner.par(~onePattern.(ratio, (rrand(1.5, 4) * ratio).asInteger),
					0.1)
			};
		});
	~window.recursiveResize.front;
};

p.makeGui;

p.activeRatios;



(1..20).as(IdentitySet) - #[5, 18, 16, 8, 6, 10, 4, 14, 11, 1, 13, 12, 3, 7, 20, 9, 15, 2, 19, 17].as(IdentitySet)