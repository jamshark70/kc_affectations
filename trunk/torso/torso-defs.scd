
// just in case... (won't load twice if already loaded)
// (thisProcess.nowExecutingPath.dirname.dirname +/+ "common/common-defs.scd").loadPath;

// using armsChordVC for a different sound
// this loads common-defs, so above is deprecated
(thisProcess.nowExecutingPath.dirname.dirname +/+ "arms/arms-defs1.scd").loadPath;

s.doWhenBooted {
	if(~cRvbMc.tryPerform(\fadergroup).isNil) {
		~cRvbMc = MixerChannel(\rvbC, s, 2, 2, level: 1, outbus: ~master);
	};
	if(~cavernousRvb.isPlaying.not) {
		~cRvbMc.doWhenReady {
			~cavernousRvb = ~cRvbMc.playfx(Instr("busfx.freeverb2"), [0, 1/*0.69354838132858*/, 0.90322577953339, 0.5, 1.0])
		}
	};
};

(
keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		event: (eventKey: \singleSynthPlayer),
		master: ~master, glrvbmc: ~glrvbmc, lcrvbmc: ~lcrvbmc,
		userprep: {
			#[glrvbmc, lcrvbmc].do { |key|
				key.envirGet.tryPerform(\receivesSignalFrom, ~chan);
			};
			~event.proto = topEnvironment[\rvbEvent].proto;
			~event.put(\glrvbamt, 0.395).put(\lcrvbamt, 0.232);
		},
		userfree: {
			#[glrvbmc, lcrvbmc].do { |key|
				key.envirGet.tryPerform(\stopsReceivingFrom, ~chan);
			};
		},
		sustain: Pwhite(9.0, 18.0, inf),
		delta: Pif(Pwhite(0.0, 1.0, inf) < 0.2, Pwhite(1.5, 4.0, inf), Pwhite(10.0, 16.0, inf)),
		delta: Pseq([
			Plazy({
				var	last = rrand(0.9, 1.2);
				Pgeom.fromEndpoints(rrand(1.8, 2.6), last, rrand(4, 9)) ++ Pn(last*0.5, 1)
			}),
			Pwhite(10.0, 16.0, 1)
		], inf),
		objects: { (
			lowbell: (
				def: \addRvbOut.eval(\dbell10, { |outbus, atten = 0.02, time = 9, //pan = 0,
					fLow = 80, fHigh = 240, dLow = 0.45, dHigh = 1.0,
					beaterFilt = 2500, beaterDec = 0.1,
					chfreq = 0.6, chamt = 0.002, chdly = 0.008,
					pan = 0, panWidth = 1, panFreq = 1|
					var	n = 10,
						exc = LPF.ar(PinkNoise.ar, beaterFilt)
							* Decay2.kr(Impulse.kr(0), 0.01, beaterDec),
						fpoints = (0..n).linlin(0, n, fLow, fHigh),
						freqs = ({ |i| ExpRand(*fpoints[[i, i+1]]) } ! n).clump(2).flop,
						sig = freqs.collect { |farray|
							Klank.ar(`[
								farray,
								atten ! n,
								farray.linlin(fLow, fHigh, dLow, dHigh, \none)
							], exc, decayscale: time)
						}; //,
						// panFreq = Rand(0.4, 1.2);
					sig = sig.collect { |chan, i|
						Pan2.ar(chan, SinOsc.kr(panFreq, pi * i, panWidth, pan).clip(-1, 1))
					}.sum;
					sig = 0.5 * (sig
						+ DelayL.ar(sig, chamt + chdly + 0.05, SinOsc.kr(chfreq, 0, chamt, chdly)));
					DetectSilence.ar(sig, amp: 0.001, doneAction: 2);
					sig = Limiter.ar(sig);
					Out.ar(outbus, sig);
				}),
				args: [
					time: BPStream(\sustain),
					// delta: Pkey(\time) * Pexprand(0.8, 1.1, inf), // + Pwhite(0.2, 1.0, inf),
					fLow: Pif(Pkey(\delta) < 5, Pexprand(120, 300, inf), Pexprand(40, 70, inf)),
					fHigh: Pkey(\fLow) * Pwhite(4.0, 11.0, inf),
					beaterFilt: Pexprand(1500, 5000, inf),
					atten: 0.025,
					distance: Pwhite(5.0, 20.0, inf),
					pan: Pif(Pkey(\fLow) >= 120, Pwhite(-1.0, 1.0, inf), 0),
					panWidth: 1,
					chfreq: Pwhite(0.3, 0.8, inf)
				]
			)
		) }
	));
	0 => BP(name);
}, type: \bp) => Fact(\bells);


// washes (moved over from feet)

(keys: #[master, glrvbmc, lcrvbmc, cRvbMc],
make: { |name|
	var out;

	WrapInstr([\osc2, \vosc3map2], { |freq, bufbase, numbufs, basefreq, topfreq, gate, freqmul = 1|
		var	baselog = log2(basefreq),
			newfreq = freq * freqmul,
			freqmap = ((log2(newfreq) - baselog) / (log2(topfreq) - baselog)
				* (numbufs - 1)).clip(0, numbufs - 1.001);
		WrapInstr.wrap([\osc2, \vosc3], [newfreq, gate, bufbase, freqmap]);
	}, [\freq, [0, 1000, \linear, 1, 0], [0, 20, \lin, 1, 0], \freq, \freq, NoLagControlSpec(0, 1), #[0.5, 2, \exp, 0, 1]]);
	
	WrapInstr("osc2.vosc3mapfiltenv", { |gate = 1, ffreq, rq, fenv, fenv_sens, fenv_vsens, fenv_tscale = 1, pan = 0|
		var	sig = WrapInstr.wrap("osc2.vosc3map2", (nil ! 5) ++ [gate]),
			glatch = Latch.kr(gate, gate),
			feg = EnvGen.kr(fenv, gate, timeScale: fenv_tscale);
		feg = (feg - 1) * Sensitivity.kr(1, glatch, fenv_vsens) * fenv_sens + 1;
		sig = RLPF.ar(sig, (ffreq * feg).clip(20, 18000), rq);
		Pan2.ar(sig, pan)
	}, [#[0, 1], \freq, \myrq, EnvSpec(Env.one), #[0, 1], #[0, 1], #[0.1, 10, \exp]]);

	~target = MixerChannel(name, s, 2, 2, level: -27.dbamp, outbus: ~master, completionFunc: { |chan|
//		~mono2Stereo = chan.playfx('1to2');
		StaticEQ(1, \eq, 589.41, -6.457.dbamp, 1, \hishelf, 6947.785, 2.047.dbamp, 1).play(chan);
		~ch = chan.playfx(Instr("busfx.chorus2"), #[0, 2, 2, 3, 0.0040240867741694, 0.11364637357074, 0.0036090192987437, 1.1344639929904, 0.72629173909809]);
		~ch.doWhenPlaying { ~ch.synth.moveToTail(chan.effectgroup) };
		// spatialization strategy isn't compatible with channel fx
		chan.newPostSend(~cRvbMc, 0.405);
		chan.newPostSend(~lcrvbmc, 0.98);  // rather soupy but sounds ok
	});

	~wt = #[squareAmps, sawtoothAmps].collect { |selector|
		\makeWavetables.eval(8, s, 2048, nil, { |nh|
			var	a = Array.perform(selector, nh), i = (0, 2 .. a.size-1).scramble;
			i.keep((i.size * rrand(0.1, 0.2)).asInteger).do { |ind| a[ind] = 0 };
			a
		});
	};
	out = Voicer(16, WrapInstr("osc2.vosc3mapfiltenv"), [bufbase: ~wt.first.first.bufnum, numbufs: `(~wt.first.size), basefreq: `(48.midicps), topfreq: `(127.midicps), env: Env.adsr(1.6, 0.8, 0.6, 2.5), fenv: Env(#[1, 40, 1], #[3.5, 4.0].normalizeSum, \sin), fenv_tscale: (3.5+4.0), detune: 1.003, /* ffreq: 900,*/ fenv_sens: 0.8, fenv_vsens: 1, vsens: 0.2], target: ~target);
// 	out.mapGlobal(\ffreq, nil, 400, \freq);
// 	out.mapGlobal(\rq, nil, 1, \myrq);
	// out.mapGlobal(\clevel, nil, 1, \amp);
	// out.mapGlobal(\density, nil, 0.8, #[0.5, 3.0]);
	out.mapGlobal(\freqmul, nil, 1, #[0.5, 2.0, exp], allowGUI: false);
	// SynthDescLib.at(out.nodes[0].defname.asSymbol).msgFuncKeepGate = true;
	out
},
free: {
	[~target, ~wt].free
},
type: \vc) => Fact(\wtpadnofx);


MIDIRecBuf(\waterch, [
	#[40, 47, 57, 62, 78, 61, 71,
		33, 45, 54, 55, 60, 71, 86,
		31, 43, 52, 57, 62, 71, 78, 88],
	#[7, 7, 8].collect { |n| (1 ! (n-1)) ++ #[2] }.flat,
	1, 0.5
].asNotes, (type: \ch, mode: \g)) => MBM(0);

PR(\arpeg1).clone {
	~superAsPattern = ~asPattern;
	~asPattern = { |inEvent|
 		~preInsertStream !? {
 			inEvent = ~preInsertStream.next(inEvent);
 		};
		~lastEv !? {
			~lastEv.use { ~releaseNote.() };
			~lastEv = nil;
		};
		~superAsPattern.(inEvent).collect { |ev|
			var	synths, count;
			if(ev[\length] == inf) {
				~lastEv = ev.put(\immediateOSC, true);
				thisThread.clock.sched(0, e {
					var	synths = ev[\nodes].collect(_.synth),
						count = synths.size,
						ufunc = { |obj, what|
							if(what == \n_end) {
								obj.removeDependant(ufunc);
								// ~lastEv might have changed since synths started
								if((count = count - 1) == 0 and: { ~lastEv === ev }) {
									~lastEv = nil;
								};
							}
						};
					synths.do { |node| node.addDependant(ufunc) };
				});
			};
			ev
		};
	};
} => PR(\arpeg1PreInsert);

{ |notes, inEvent| 
	if(notes.isArray) {
		Pn(notes.keep(min(notes.size, inEvent[\numNotes])), 1)
	} {
		Pn(notes.asArray.asNotes.keep(min(notes.size, inEvent[\numNotes])), 1)
	}
} => ArpegPat(\blockNum);

//{ |notes, parentEv| [parentEv[\delta], parentEv[\delta] - 4, 0.4] } => MicRh(\waterch);
{ |notes, parentEv| [parentEv[\delta], parentEv[\delta] - 4, ~gatePatStream.next] } => MicRh(\waterch);

(make: { |name|
	BP(name).free;
	\newCh.eval(name, \arpeg1PreInsert, \macroRh, MBM(0)[\waterch], nil, Pwhite(16, 22, inf), \waterch, \blockNum, nil, \g);
	BP(name).child.makeChordPattern = { Pclutch(Pseq(~chords, inf), Pdelay(Pkey(\numNotes) >= 7)) };
	// MicRh accesses this
	BP(name).child.gatePat = Pn(Pgeom(0.1, (10 ** (1/9)).reciprocal, { rrand(5, 10) }));
	BP(name).child.argPairs = [fenv_tscale: Pexprand(0.8, 1.8, inf)];
	BP(name).child[\reset] = BP(name).child[\reset] <> {
		~preInsert = Pbind(
			\numNotes, Pseq([
				Pwhile1({ |ev, next| next <= 7 },
					Pseries(Pseq([4, Pwhite(4, 7, inf)]).asStream, 1, inf)),
				Pn(8, 2)
			], inf)
		)
	};
	BP(name).value.reset;
	BP(name)
}, type: \bp) => Fact(\waterch);


(//keys: #[master, glrvbmc, lcrvbmc],
vcKey: \wp,
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		chan: VC(~vcKey).env.target,
		isFx: true,
		userprep: {
			~overlap = GenericGlobalControl(\overlap, nil, 0.7, #[0.7, 6.0, \exp]);
			~event = ~event.copy.put(\addAction, \addToHead);
		},
		useGui: { |vp| ~overlap => VP(vp) },
		userfree: { ~overlap.free },
		delta: Pwhite(3.0, 8.0, inf),
		sustain: Plazy { Pkey(\delta) * ~overlap },
		objects: { (
			shift: (
				def: (
					Instr("busfx.fshift", { |bus, numCh, freq1, freq2, wet1, wet2, wetProp = 0.5, time = 1|
						var	sig = In.ar(bus, numCh),
							freq = XLine.kr(freq1, freq2, time),
							fx = FreqShift.ar(sig, freq),
							weteg = EnvGen.kr(Env([wet1, wet2, wet1], [wetProp, 1-wetProp], \sin),
								timeScale: time, doneAction: 2);
						XFade2.ar(sig, fx, weteg.madd(2, -1))
					}, [\audioBus, \numChannels, #[0, 900], #[0, 900], nil, nil, nil, #[0.1, 50]]);
					Patch("busfx.fshift", [nil, 1], ReplaceOut)
				),
				args: [
					time: Pkey(\sustain),
					freq1: Pwhite(0.0, 900.0, inf),
					freq2: Pwhite(0.0, 900.0, inf),
					wet1: 0, wet2: 1,
					wetProp: Pwhite(0.2, 0.8, inf)
				]
			)
		) }
	));
	0 => BP(name);
}, type: \bp) => Fact(\watershift);


// melody synth
// Func, not Fact, b/c Fact-calling-a-Fact will mess up the environments
{ |name|
	VC(name).free;
	topEnvironment.use {
		Fact(\armsChordVC).chuck(VC(name), nil, (
			defaultCarDetune: 1.0066,
			defaultDetune: 2.234,
			car_amps: Array.squareAmps(5),
			mod_amps: Array.sawtoothAmps(5), //#[1],
			car_env: Env.adsr(0.5, 0.8, 0.75, 1.0),            
			mod_env: Env.adsr(0.01, 2.5, 0.75, 1, curve: -2.5),
			keyScale: 0.3669,
			defaultCarVs: 0.145,
			defaultModVs: 0.145,
			isMono: true,
			cRvbMc: topEnvironment[\cRvbMc],
			// called within the VC's new environment
			customize: { |v|
				~target.newPostSend(~cRvbMc, 1.2);
				v.mapGlobal(\mod_ratio, nil, 3, #[1, 10, \exp]);
				v.mapGlobal(\mod_lev, nil, 1.6, #[0.01, 15, \exp]);
				// v.mapGlobal(\distance, nil, 10, #[5, 20]);
				// v.mapGlobal(\pan, nil, 0, \bipolar);
			}
		));
	};
} => Func(\makeTmelVC);



PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);
	~continuous = false;
	~alwaysReset = false;
	~continuous_ = { |bool = false|
		~continuous = ~alwaysReset = bool;
		currentEnvironment
	};		

	~prep = {
		~event.proto_(topEnvironment[\rvbEvent].proto.copy.putAll((distNear: 5, distFar: 50)));
		~reset.();
	};

	~rewriteProb = 0.3;
	~rewriteLevel = Pwhite(1, 3, inf); // Pseq([1, 2, Pwhite(1, 3, inf)], 1);
	~phraseIndex = Pfunc { ~phrases.size.rand };
	~phrases = [
		#[7, 8],
		#[7, 4, 5, 7, 8],
		#[7, 5, 7, 6],
		#[7, 4, 2, 5, 6]
	];
	~octOffset = 35;
	~mode = \d;
	~dur = Pseq([
		Pwhite(1.9, 3.2, 1),
		Pswitch1([
			Pwhite(1.9, 2.6, inf),
			Pexprand(0.4, 0.7, inf),
			Pexprand(0.9, 1.4, inf)
		], Pwrand(#[0, 1, 2], #[1, 3, 5].normalizeSum, { |ev| ev[\noteCount] - 2 })),
		Pwhite(1.9, 3.2, 1)
	], inf); //Pexprand(1.2, 3.0, inf);
	~amp = 0.15;
	~frlagProp = Pwhite(0.5, 0.8, inf);
	~freqlag = Plazy({ Pfunc({ |ev| ev[\note].length }) * BPStream(\frlagProp) });
	~gate = 0.2;
	~rest = 3;

	~asPattern = {
		var	phr;
		~makeStreams.();
		Pseq([
			Plazy({ |ev|
				if((phr = ~makePhrase.(ev)).notNil) { phr }
					{ BP(~collIndex).stop(0); nil }  // force stop
			}),
			Plazy({ |ev|
				if(~continuous) {
					// currentEnvironment.listVars;
					Pn((note: SequenceNote(#[], ~restStream.next(ev), 1, 1)), 1)
					// (freq: #[], delta: ~restStream.next(ev))
					// Event.silent(~restStream.next(ev))
				} {
					BP(~collIndex).stop(0); nil
				}
			})
		], inf)/*.collect { |ev|
			ev.tryPerform(\at, \note).postcs;
			ev
		}*/
	};

	~makePhrase = { |ev|
		// one buslock per phrase; need to know total dur in advance
		var	phrI = ~phraseIndexStream.next,
			notes, durs, lock,
			once = true;
		if(phrI.notNil) {
			lock = PR(\busLock).copy.prep((numCh: 2, rate: \control));
			notes = \patRejectLastN.eval(~rewriters[phrI].asStream, 1).all;
			ev[\noteCount] = notes.size;
			durs = ~durStream.nextN(ev[\noteCount], ev);
			notes = [notes, durs, durs + 0.01, ~gateStream.next(ev)].asNotes;
			Pfunc({ |ev|
				var xyEv;
				if(once) {
					xyEv = ~xyPatStream.next(ev);
					xyEv !? {  // DON'T YIELD NIL!!!
						xyEv.put(\delta, 0)
						.put(\chan, nil)
						.put(\bus, lock/*.listVars*/.bus)
						.put(\parent, ProtoEvent(\singleSynthPlayer).v.parent)
						.yield
					};
					xyEv = ~envPatStream.next(ev);
					xyEv !? {  // DON'T YIELD NIL!!!
						xyEv.put(\delta, 0)
						.put(\chan, nil)
						.put(\bus, ev[\voicer].globalControls[\mod_ratio].bus)
						.put(\parent, ProtoEvent(\singleSynthPlayer).v.parent)
						.yield
					};
					// why? event must .play before ev[\id] is available
					thisThread.clock.sched(0.01, {
						lock.addNode(ev[\voicer].latest.synth);
						nil
					});
					once = false;
				};
				ev
			})
			<>
			Pbind(
				\note, Pseq(notes, 1) + BPStream(\octOffset),
				\mode, BPStream(\mode),
				\totalDur, durs.sum,
				\freqlag, BPStream(\freqlag),
				#[pan, distance], (lock.bus.index + #[0, 1]).collect { |i| ("c" ++ i).asSymbol },
				\finalAmp, BPStream(\amp)
			)
		};  // else returns nil, stopping the process
	};

	~pan1 = Pwhite(0.6, 1.0, inf) * Prand(#[-1, 1], inf);
	~pan2 = Pkey(\x1).neg;
	~yNear = 22;
	~yFar = 50;
	~xyProportion = Pwhite(0.6, 0.9, inf);
	~xyDef = \xylin;

	~xyPat = Plazy({ Pbind(
		\instrument, BPStream(\xyDef),
		// CHANGE ME!
		\sustain, Pkey(\totalDur) * BPStream(\xyProportion),
		\x1, BPStream(\pan1),
		\x2, BPStream(\pan2),
		\y1, BPStream(\yNear),
		\y2, BPStream(\yFar)
	) });

	~envDef = \ctlEnv;
	~randModStart = Pwhite(2.0, 4.0, inf);
	~modREnv = Pfunc { |ev| Env([~randModStartStream.next(ev), 3], #[1], \sin) };
	~envProportion = Pwhite(0.4, 0.7, inf);
	~envPat = Plazy({ Pbind(
		\instrument, BPStream(\envDef),
		\time, Pkey(\totalDur) * BPStream(\envProportion),
		\connect, 0,
		\env, BPStream(\modREnv)
	) });

	~streamKeys = #[xyPat, envPat, rewriteLevel, rest, phraseIndex, dur, randModStart, gate];
	~makeStreams = { |forceReset = false|
		~streamKeys.do { |key|
			if(forceReset or: { (key ++ "Stream").asSymbol.envirGet.isNil }) {
				~makeStreamForKey.(key)
			};
		}
	};

	~makeRewriters = {
		var	self = currentEnvironment, rew;
		~rewriters = ~phrases.collect { |row|
			rew = PR(\rewriter).copy.prep(Pseq(row, 1), Pfuncn(e { ~rewriteLevelStream.next }, 1), [
				(_.notNil) -> { |item, level, inval|
					// self: this runs inside the rewriter Proto object
					if(self[\rewriteProb].coin) {
						item + [0, rrand(1, 3) * #[-1, 1].choose].rotate(2.rand)
					} { [item] }
				}
			]).keepLowerLevels_(true);
		};
	};

	~reset = {
		~makeStreams.(true);
		~makeRewriters.();
	};
		
} => PR(\torsoMel);


(
vcKey: \tmel,
make: { |name|
	BP(name).free;
	PR(\torsoMel) => BP(name);
	if(VC.exists(~vcKey)) {
		BP(name) => VC(~vcKey);
	} {
		"VC(%) not found; set voicer manually".format(~vcKey.asCompileString).warn;
	};
	0 => BP(name);
}, type: \bp) => Fact(\tmelBP);


(
//keys: #[master, glrvbmc, lcrvbmc],
parentChan: nil,
longDelayMax: 8,
longDelayTime: 8,
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		event: (eventKey: \singleSynthPlayer),
		alwaysReset: true,
		chan: ~parentChan,
		longDelayMax: ~longDelayMax,
		longDelayTime: ~longDelayTime,
		isFx: true,
		// master: ~master, glrvbmc: ~glrvbmc, lcrvbmc: ~lcrvbmc,
		userprep: {
			if(~chan.isNil) {
				Error("Could not instantiate Fact(\\bellfx) -- parent mixerchannel not supplied")
				.throw;
			};
			~longDelayBuf = Buffer.allocConsecutive(~chan.outChannels, s, (~longDelayMax * s.sampleRate).nextPowerOfTwo, 1);
			~delayBus = Bus.audio(s, ~chan.outChannels);
			~attenCtl = GenericGlobalControl(\atten, nil, 0.15, #[0.01, 0.35, \exp]);
			~event.put(\chan, nil).put(\atten, ~attenCtl.asMap);
			// #[glrvbmc, lcrvbmc].do { |key|
			// 	key.envirGet.tryPerform(\receivesSignalFrom, ~chan);
			// };
			// ~event.proto = topEnvironment[\rvbEvent].proto;
			// ~event.put(\glrvbamt, 0.395).put(\lcrvbamt, 0.232);
		},
		userfree: {
			[~longDelayBuf, ~delayBus, ~attenCtl].free;
			// 	#[glrvbmc, lcrvbmc].do { |key|
			// 		key.envirGet.tryPerform(\stopsReceivingFrom, ~chan);
			// 	};
		},
		delta: Pexprand(0.12, 0.6, inf),
		sustain: Pwhite(3.0, 7.0, inf),
		preparePlay: {
			~dlySynth ?? {
				~dlySynth = SynthDef(\bufdelay2, { |inbus, outbus, buf, delaytime|
					Out.ar(outbus,
						BufDelayL.ar(buf + #[0, 1], In.ar(inbus, 2), delaytime: delaytime)
					)
				}).play(~chan.effectgroup, [
					inbus: ~chan.inbus, outbus: ~delayBus,
					buf: ~longDelayBuf, delaytime: ~longDelayTime
				], \addToHead);
			}
		},
		stopCleanup: {
			~dlySynth !? { ~dlySynth.free; ~dlySynth = nil; }
		},
		objects: { (
			lowbell: (
				def: SynthDef(\bellfx10, { |inbus, outbus, atten = 0.02, time = 9, //pan = 0,
					fLow = 80, fHigh = 240, dLow = 0.45, dHigh = 1.0,
					beaterFilt = 18000, beaterDec = 0.1,
					// chfreq = 0.6, chamt = 0.002, chdly = 0.008,
					pan = 0, panWidth = 1, panFreq = 1,
					wet = 0.8|
					var	n = 10,
						in = In.ar(inbus, 2),
						initTrig = Impulse.kr(0),
						exc = LPF.ar(in, beaterFilt)
							* Decay2.kr(initTrig, 0.01, beaterDec),
						fpoints = (0..n).linlin(0, n, fLow, fHigh),
						freqs = ({ |i| ExpRand(*fpoints[[i, i+1]]) } ! n).clump(2).flop,
						sig = freqs.collect { |farray, i|
							Klank.ar(`[
								farray,
								atten ! n,
								farray.linlin(fLow, fHigh, dLow, dHigh, \none)
							], exc[i], decayscale: time)
						}; //,
						// panFreq = Rand(0.4, 1.2);
					sig = sig.collect { |chan, i|
						Pan2.ar(chan, SinOsc.kr(panFreq, pi * i, panWidth, pan).clip(-1, 1))
					}.sum;
					// sig = 0.5 * (sig
					// 	+ DelayL.ar(sig, chamt + chdly + 0.05, SinOsc.kr(chfreq, 0, chamt, chdly)));
					// DetectSilence.ar(sig, amp: 0.001, doneAction: 2);
					sig = Limiter.ar(sig);
					Line.kr(0, 1, time, doneAction: 2);
					Out.ar(outbus, sig);  // use atten to control level
					// wet = EnvGen.kr(Env([0.001, wet, 0.001], [0.01, time], \exp),
					// 	doneAction: 2).madd(2, -1);
					// ReplaceOut.ar(outbus, XFade2.ar(in, sig, wet));
				}),
				args: [
					inbus: Pn(~delayBus, inf),
					target: Pfunc { ~dlySynth },
					bus: ~chan.inbus,
					addAction: \addAfter,
					time: BPStream(\sustain),
					// delta: Pkey(\time) * Pexprand(0.8, 1.1, inf), // + Pwhite(0.2, 1.0, inf),
					fLow: Pexprand(1600, 2400, inf),
					fHigh: Pkey(\fLow) * Pwhite(5.0, 8.0),
// 					atten: 0.1,
					beaterFilt: Pexprand(1500, 5000, inf),
					pan: 0,
					panWidth: 1
				]
			)
		) }
	));
	0 => BP(name);
}, type: \bp) => Fact(\bellfx);