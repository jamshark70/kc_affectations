// defs for the actual arms section, not the silly prototype


// just in case... (won't load twice if already loaded)
(thisProcess.nowExecutingPath.dirname.dirname +/+ "common/common-defs.scd").loadPath;


// melody (axial)

(keys: #[master, glrvbmc],
make: { |name|
	var	out;
	~wt = \makeWavetables.eval(8, s, 2048, 48, { |numharm|
		var	array = Array.triangleAmps(numharm),
			tweak = ((numharm div: 5) + 1 .. (numharm-1)), i;
		min(10, numharm div: 5).do {
			i = tweak.takeAt(tweak.size.rand);
			if(i.notNil) {
				array[i] = array[i] * exprand(2.5, 6.0) * (i+1);
			};
		};
		array
	});
	~target = MixerChannel(name, s, 2, 2, completionFunc: { |chan|
		// eq?
		~chorus = chan.playfx(WrapInstr("busfx.chorus2"), [0, 2, 2, 3, 0.01285261232269, 0.077426358822457, 0.00860870962377, 0.87266466760906, 0.15647481535888]);
	});
	WrapInstr("osc2.vosc3mapfporta", { |freq, freqlag = 0.1, ffreq = 2000, rq = 1, pan|
		var	sig = WrapInstr.wrap("osc2.vosc3map", [Lag.kr(freq, freqlag)]);
		Pan2.ar(RLPF.ar(sig, ffreq, rq), pan)
	}, [NoLagControlSpec(20, 20000, \exp, 0, 440), #[0, 1, 4], \freq, \myrq]);
	out = MonoPortaVoicer(1, WrapInstr("osc2.vosc3mapfporta"), [bufbase: `(~wt.first.bufnum), numbufs: `(~wt.size), basefreq: `(48.midicps), topfreq: `(132.midicps), env: Env.adsr(0.4, 0, 1, 1.2), ffreq: 2423.054873855, rq: 1, vsens: 0.84722220897675, detune: 1.003], target: ~target);
	// no global maps - this is mostly to generate the synthdef
	SynthDescLib.at(out.nodes[0].defname.asSymbol).msgFuncKeepGate = true;
	out
},
free: { ~target.free },
maps: { |self| self[\value].globalControls.collectAs({ |gc| if(gc.name != \detune) { [gc.name, gc.asMap] } }, Array).select(_.notNil).flat },
type: \voicer) => Fact(\armsmelVC);


// now this really is a bit of silliness, but Pmono[Artic] patterns don't work
// when grabbing events on-demand (it's fine until you need the EventStreamCleanup to fire)
// so, I have to do it myself. grr....

PR(\abstractProcess).clone {
	~event = (eventKey: \monoSupport, immediateOSC: true);
	~vcKey = \am;
	~prep = {
		if(VC.exists(~vcKey).not) {
			"VC(%) doesn't exist. Please create it before using BP(%)."
				.format(~vcKey.asCompileString, ~collIndex.asCompileString).warn;
		};
		~makeStreamForKey.(\level);
		currentEnvironment
	};
	~alwaysReset = true;
	~pan = 0;

	~rewriteProb = 0.3;
	~phrases = [
		#[2, 5, 4],
		#[2, 7, 6, 4, 8],
		#[2, 5, 6, 4],
		#[9, 8, 3],
		#[8, 11, 10, 5, 2, 3, 4],
		#[-2, -5, 0, 1, 0, 4]
	];
	~degree = Plazy {
		var	self = currentEnvironment;
		Pswitch(
			~phrases.collect { |row|
				PR(\rewriter).copy.prep(Pseq(row, 1), Pfuncn(e { ~levelStream.next }, 1), [
					(_.notNil) -> { |item, level, inval|
						if(self[\rewriteProb].coin) {
							item + [0, rrand(1, 3) * #[-1, 1].choose].rotate(2.rand)
						} { [item] }
					}
				])
			},
			\patRejectLastN.eval(Pseq([0, 1, 2, Prand((0 .. (a.size-1)), inf)]), 1)
		)
	};

	~dur = Pwrand(#[1, 2], #[0.9, 0.1], inf);
// 	~legato = Pwrand(#[1.01, 0.9, 0.4], #[0.7, 0.2, 0.1], inf); // 1.01;
	~gate = 0.8;
	~freqlag = 0.3;
	~detune = 1.003;
	~gate = 0.8;
	~level = (Pn(0, 3) ++ Pexprand(0.01, 2.99, inf).collect(_.asInteger));
	~recvEventNotify = { |node| ~node = node };
	~stopCleanup = { if(~node.notNil) { ~node.release }; ~node = nil };
	~asPattern = {
		Pbind(
			\instrument, VC(~vcKey).v.nodes[0].defname.asSymbol,
//			\level, BPStream(\level),
			\node, Pfunc { ~node ?? { 0 } },
			\protoEvent, Pif(Pfunc { ~node.isNil }, \singleSynthPlayNotify, \singleSynthTrigger),
			\node, Pfunc { ~node ?? { 0 } },
			\root, 7,
			\freq, (BPStream(\degree).degreeToKey(#[0, 2, 4, 5, 7, 9, 11]) + 67).midicps,
			\delta, BPStream(\dur),
// 			\legato, BPStream(\legato),
			\gate, BPStream(\gate),
			\freqlag, BPStream(\freqlag),
			\detune, BPStream(\detune),
			\gate, BPStream(\gate),
			\pan, BPStream(\pan),
			\chan, VC(\am).env.target
		)
		// now this is a problem - you don't know when the next trigger is,
		// so you don't know when to release
		// removing for now
// 		.collect { |ev|
// 			if(~node.notNil and: { ev[\legato] < 1 }) {
// 				\schedEventBundleArray.eval(ev[\lag] ? 0, ev[\timingOffset] ? 0,
// 					ev[\server] ?? { Server.default },
// 					[~node.releaseMsg], nil, true
// 				);
// 				~node = nil;
// 			};
// 			ev
// 		};
	};
	~reset = Func(\resetBPStreams).v;
} => PR(\melody);

