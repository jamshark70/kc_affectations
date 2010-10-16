
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
		// delta: Pif(Pwhite(0.0, 1.0, inf) < 0.2, Pwhite(1.5, 4.0, inf), Pwhite(10.0, 16.0, inf)),
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

(// keys: #[master, glrvbmc, lcrvbmc],
defaultCarDetune: 1.005716,
defaultDetune: 1.25,
car_amps: #[1, 2, 3].reciprocal,
mod_amps: #[1],
car_env: Env.adsr(0.5, 0.8, 0.75, 1.0),
mod_env: Env.adsr(0.01, 2.5, 0.05, 1, curve: -2.5),
keyScale: 0.28621534453893,
defaultCarVs: 0.833,
defaultModVs: 0.819,
isMono: false,
customize: nil,
make: { |name|
	var	args, out;
	~sideBus = Bus.audio(s, 2);
	~target = MixerChannel(name, s, 2, 2/*, level: -17.dbamp*/, outbus: ~master,
		completionFunc: { |chan|
			SynthDef(name ++ "Chorus", { |inbus, outbus|
				var	sig = Instr("busfx.chorus").valueArray([inbus, 2, 0.011924888841111, 0.15615231995716, 0.0044072173729238, 1.1, 0.5]);
				ReplaceOut.ar(outbus, sig);
			}).add;
			s.sync;
			~chorus = Synth(name ++ "Chorus", [#[inbus, outbus], ~sideBus].flop.flat, chan.effectgroup);
			StaticEQ(2, \hishelf, 3654.349, 4.274.dbamp, 1, \eq, 301.329, -5.641.dbamp, 1.286)
				.play(chan.effectgroup, ~sideBus, addAction: \addToTail);
			~modfx = ~target.playfx(\innermod1, [distance: [10, 5, 20, ~glrvbmc.inbus.index, ~lcrvbmc.inbus.index, 0.1, 0.1], inbus: [~sideBus, 300, 25, 0.04, 0.25]]);
			// ~chorus.doWhenPlaying { ~chorus.synth.moveToHead(chan.effectgroup) };
		});
	[~glrvbmc, ~lcrvbmc].do { |mc|
		mc.tryPerform(\receivesSignalFrom, ~target);
	};
	~cb = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg(~car_amps) });
	~mb = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg(~mod_amps) });

	~def = SynthDef((name ++ "def").asSymbol, { |pan, freq = 440, freqlag = 0, gate = 1,
			mod_lev = 0.01, mod_ratio = 1, detune = 0, car_detune = 0.99798261661993,
			car_vs = 0, mod_vs = 0,
			attackTimeScale = 1, decayTimeScale = 1, finalAmp = 1, outbus|
		Out.ar(outbus, WrapInstr("osc2.fm2car_stereo").valueArray([
			pan, freq, freqlag, gate,
			~car_env,
			~mod_env,
			mod_lev, mod_ratio,
			detune, car_detune,
			~cb.bufnum, ~mb.bufnum, car_vs, mod_vs, // 0.66141732283465 /* car_vs */, 0 /* mod_vs */,
			440, ~keyScale, /* basefreq, keyScale */
			attackTimeScale, decayTimeScale, finalAmp
		]))
	}).add;
	SynthDescLib.at(~def.name.asSymbol).msgFuncKeepGate = true;

	// default args for voicer: supply reverb targets automatically
// 	if(~glrvbmc.isKindOf(MixerChannel)) {
// 		args = [glrvbout: ~glrvbmc.inbus, lcrvbout: ~lcrvbmc.inbus];
// 	} {
// 		"VC(%): Spatialization reverbs not found.".format(name.asCompileString).warn;
// 	};
	if(~isMono ? false) {
		out = MonoPortaVoicer(1, ~def.name, args, bus: ~sideBus, target: ~target.synthgroup);
	} {
		out = Voicer(45, ~def.name, args, bus: ~sideBus, target: ~target.synthgroup);
	};
	out.mapGlobal(\detune, nil, ~defaultDetune, #[-5, 5], false);
	out.mapGlobal(\car_detune, nil, ~defaultCarDetune, \mydetune);
	out.mapGlobal(\car_vs, nil, ~defaultCarVs, nil, false);
	out.mapGlobal(\mod_vs, nil, ~defaultModVs, nil, false);
	out.mapGlobal(\finalAmp, nil, 0.16, #[0.001, 0.5, \exp]);
	~customize.(out);
	out
},
free: {
	[~glrvbmc, ~lcrvbmc].do { |mc|
		mc.tryPerform(\stopsReceivingFrom, ~target);
	};
	[~cb, ~mb, ~target, ~sideBus].free
}, type: \voicer) => Fact(\torsoVC);


{ |name|
	VC(name).free;
	topEnvironment.use {
		Fact(\torsoVC).chuck(VC(name), nil, (
			defaultCarDetune: 1.0066,
			defaultDetune: 2.234,
			car_amps: Array.squareAmps(5),
			mod_amps: Array.sawtoothAmps(5), //#[1],
			car_env: Env.adsr(0.5, 0.8, 0.75, 1.0),            
			mod_env: Env.adsr(0.01, 2.5, 0.75, 1, curve: -2.5),
			keyScale: 0.3669,
			defaultCarVs: 0.145,
			defaultModVs: 0.145,
			isMono: false,
			glrvbmc: topEnvironment[\cRvbMc],
			lcrvbmc: topEnvironment[\lcrvbmc],
			// called within the VC's new environment
			customize: { |v|
				// ~target.newPostSend(~cRvbMc, 1.2);
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
		event: (eventKey: \singleSynthPlayer, addAction: \addToHead),
		alwaysReset: true,
		chan: ~parentChan,
		longDelayMax: ~longDelayMax,
		longDelayTime: ~longDelayTime,
		delayInbus: ~delayInbus,
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
					inbus: ~delayInbus ?? { ~chan.inbus }, outbus: ~delayBus,
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
					var	n = 6,
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



// shimmerpad, but not spatialized - leave that to innermod fx

(keys: #[master, glrvbmc, lcrvbmc],
numRows: 8,
numCols: 8,
env: Env.adsr(1, 0.4, 0.8, 1.2, curve: -2),
fenv: Env.one,
graphInsert: nil,
makeTempAmps: {
	{ |i| Array.squareAmps((20000 / ((4+i) * 12).midicps).asInteger) } ! ~numRows
},
randomizeAmps: { |amps|
	var	indices = (0 .. amps.size-1).scramble.keep(max(1, amps.size div: 3));
	amps = amps.copy;
	indices.do { |i| amps[i] = amps[i] + 0.12.rand2 };
	amps
},
bufModFunc: { Lag.kr(NamedControl.kr(\bufmod, 0), 0.08) },
make: { |name|
	var	tempAmps = ~makeTempAmps.(),
		out;

	~target = MixerChannel(name, s, 2, 2, outbus: ~master/*, completionFunc: { |chan|
		var	patch = chan.playfx(Instr("busfx.chorus2"), [0, 1, 2, 3, 0.006957213735427, 0.1708276390401, 0.0034747717625074, 1.1689647098094, 0.3]);
		patch.doWhenPlaying({
			patch.synth.moveToTail(chan.effectgroup);
		});
		// EQ?
	}*/);
	[~glrvbmc, ~lcrvbmc].do { |mc|
		mc.tryPerform(\receivesSignalFrom, ~target);
	};

		// generate a matrix of buffers
		// if numCols is 8, 0-7 have the most partials, 8-15 have fewer, etc.
		// each column is randomized differently for more animation in higher partials
	~bufs = Buffer.allocConsecutive(~numRows * ~numCols, s, 2048, 1);
	fork {
		~bufs.do({ |buf, i|
			var	amps = tempAmps[i div: ~numCols];
0.06.wait;
			buf.sine1(~randomizeAmps.(amps, i))
		});
"done generating buffers".debug;
	};

	WrapInstr([\osc2, \vosc3matrix], { arg freq, gate, bufbase, bufmod, env, vsens, detune,
		ffreq, rq, fenv, fenvsens = 1,
		numrows, numcols, basefreq, topfreq,
		attackTimeScale, decayTimeScale;
		var	sig1, sig2, amp, buf;
		var	baselog = log2(basefreq),
			freqmap = ((log2(freq) - baselog) * (numrows / (log2(topfreq) - baselog)))
				.clip(0, numrows - 2.001),
			fmapfloor = freqmap.floor,
			fmapfrac = freqmap - fmapfloor,
			detunedown = freq/detune,
			detuneup = freq*detune,
			// env timescale handling: [0] is filter eg, [1] is amp
			envs = LocalIn.kr(2),
			eg_test = envs.collect { |eg| Select.kr(Impulse.kr(0), [eg, 0]) },
			// once envelope starts going down, attack phase is over
			hit1 = PulseCount.kr(HPZ1.kr(eg_test) < 0) > 0,
			timeScales = Select.kr(hit1, [attackTimeScale, decayTimeScale]);
		amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
		buf = bufbase + (fmapfloor * numcols) + bufmod;
		#sig1, sig2 = VOsc3.ar([buf, buf+numcols], detunedown, freq, detuneup);
		eg_test = [fenv, env].collect { |e, i|
			EnvGen.kr(e, gate, timeScale: timeScales[i], doneAction: 2 * i);
		};
		LocalOut.kr(eg_test);
		ffreq = (ffreq * Sensitivity.kr(1, eg_test[0], fenvsens)).clip(20, 20000);
		RLPF.ar(XFade2.ar(sig1, sig2, fmapfrac.madd(2, -1), amp),
			ffreq, rq, mul: eg_test[1]);
	}, [\freq, \amp, #[0, 1000, \linear, 1, 0], #[0, 20], EnvSpec(Env.adsr), #[0, 1], #[0.9, 1.1, \linear, 0, 1], \freq, #[1, 0.001], EnvSpec(Env.one), nil, #[0, 20, \lin, 1, 0], #[0, 20, \lin, 1, 0], \freq, \freq, #[0.01, 10, \exp, 0, 1], #[0.01, 10, \exp, 0, 1]]);

	~defname = (name ++ "def").asSymbol;
	SynthDef(~defname, { |pan, finalAmp = 1, freq = 440, freqlag = 0, gate = 1, ffreq = 14000, rq = 1, vsens = 0.8, fenvsens = 1, attackTimeScale = 1, decayTimeScale = 1, out|
		var	sig = WrapInstr("osc2.vosc3matrix").valueArray([
			Lag.kr(freq, freqlag), gate,
			~bufs[0].bufnum,  // bufbase
			~bufModFunc,
			~env,
			vsens, /*detune:*/ 1.003,
			ffreq, rq, ~fenv, fenvsens,
			~numRows, ~numCols,
			/*basefreq:*/ 48.midicps, /*topfreq:*/ (11*12).midicps,
			attackTimeScale, decayTimeScale
		]);
		~graphInsert !? { sig = ~graphInsert.(sig) };
		Out.ar(out, Pan2.ar(sig, pan, finalAmp))
	}).add;

	out = Voicer(25, ~defname, target: ~target);
	
	out.mapGlobal(\ffreq, nil, 14000, \freq);
	out.mapGlobal(\rq, nil, 1.0, \myrq);
	// out.mapGlobal(\fenvsens, nil, 1.0, #[0.1, 15, \exp]);
	
	out
}, free: { [~target, ~bufs].free }, type: \voicer) => Fact(\modpad);



SynthDef(\nrgxch, { |outbus, bufnum, center = 60, width = 10, speed = 4, // ffreq = 1000, rq = 0.2,
	chorCtr = 0.005, chorWidth = 0.003, chorSpeed = 0.02, chorDecay = 0.1,
	amp = 1, moveTime = 1|
	var	freq = LFDNoise1.kr(speed, width, center),
	sig = COsc.ar(bufnum, freq, 1),
	fenv = NamedControl.kr(\fenv, (0!24).overWrite(Env(#[2000, 2000], #[1]).asArray)),
	ffreq = EnvGen.kr(fenv, timeScale: moveTime),
	rqenv = NamedControl.kr(\rqenv, (0!24).overWrite(Env(#[0.35, 0.35], #[1]).asArray)),
	rq = EnvGen.kr(rqenv, timeScale: moveTime),
	ampenv = NamedControl.kr(\ampenv, (0!24).overWrite(Env.one.asArray)),
	ampeg = EnvGen.kr(ampenv, timeScale: moveTime, doneAction: 2);
	sig = BPF.ar(sig, ffreq, rq);
	3.do {
		sig = sig + AllpassL.ar(sig, chorCtr + chorWidth, max(0.0001, LFDNoise1.kr(chorSpeed, chorWidth, chorCtr)), chorDecay);
	};
	Out.ar(outbus, (sig * amp * ampeg) ! 2)
}).add;

SynthDef(\nrgxch2, { |outbus, bufnum, /*center = 60,*/ width = 10, speed = 4, // ffreq = 1000, rq = 0.2,
	chorCtr = 0.005, chorWidth = 0.003, chorSpeed = 0.02, chorDecay = 0.1,
	amp = 1, moveTime = 1|
	var	ctrenv = NamedControl.kr(\ctrenv, (0!24).overWrite(Env(100 ! 2, #[1]).asArray)),
		center = EnvGen.kr(ctrenv, timeScale: moveTime),
		freq = LFDNoise1.kr(speed, width, center),
		sig = COsc.ar(bufnum, freq, 1),
		fenv = NamedControl.kr(\fenv, (0!24).overWrite(Env(#[2000, 2000], #[1]).asArray)),
		ffreq = EnvGen.kr(fenv, timeScale: moveTime),
		rqenv = NamedControl.kr(\rqenv, (0!24).overWrite(Env(#[0.35, 0.35], #[1]).asArray)),
		rq = EnvGen.kr(rqenv, timeScale: moveTime),
		ampenv = NamedControl.kr(\ampenv, (0!24).overWrite(Env.one.asArray)),
		ampeg = EnvGen.kr(ampenv, timeScale: moveTime, doneAction: 2);
	sig = BPF.ar(sig, ffreq, rq);
	3.do {
		sig = sig + AllpassL.ar(sig, chorCtr + chorWidth, max(0.0001, LFDNoise1.kr(chorSpeed, chorWidth, chorCtr)), chorDecay);
	};
	Out.ar(outbus, (Limiter.ar(sig * amp) * ampeg) ! 2)
}).add;

// didn't wanna do this but...
{ |name, ugenFunc, metadata, rates|
	var	findCtl = { |cname|
		block { |break|
			UGen.buildSynthDef.children.do { |unit|
				if(unit.isKindOf(Control)) {
					unit.channels.do { |out|
						if(out.name == cname) { break.(out) }
					}
				}
			};
			nil
		}
	};
	SynthDef(name, { |distance1 = 5, distance2 = 5, distNear = 5, distFar = 14,
		glrvbout, lcrvbout, glrvbamt = 0.075, lcrvbamt = 0.035,
		attNearFreq = 9000, attFarFreq = 3000,
		attNearDb = -5, attFarDb = -18,
		attNearRs = 2, attFarRs = 2,
		moveTime = 1|
		var result = SynthDef.wrap(ugenFunc, rates, [moveTime]), out, pan, outctl, distance;
		// don't add a new \pan control if the function already made one
		if((pan = findCtl.(\pan)).isNil) {
			pan = NamedControl(\pan, 0);
		};
		if((outctl = findCtl.(\outbus)).isNil and: { (outctl = findCtl.(\out)).isNil }) {
			//			"make out namedcontrol".debug;
			outctl = NamedControl(\out, 0);
		};
		if(result.rate != \audio) {
			// not audio rate, look for Out unit
			// (Out.ar returns 0.0, which is scalar)
			out = UGen.buildSynthDef.children.detect(_.writesToBus);
			if(out.notNil) {
				result = out.inputs[out.inputs.size - out.numAudioChannels .. ];
				UGen.buildSynthDef.children.remove(out);
			} {
				Error("Result of UGen func is not audio rate and has no Out unit").throw;
			};
		};

		distance = Line.kr(distance1, distance2, moveTime).clip(distNear, distFar);
		result = result * distNear;
		Out.ar(outctl, result / distance);

		//		lcrvbamt = Select.kr(lcrvbamt < 0, [lcrvbamt, glrvbamt]);
		result = BHiShelf.ar(result,
			distance.linexp(distNear, distFar, attNearFreq, attFarFreq),
			distance.linlin(distNear, distFar, attNearRs, attFarRs),
			distance.linlin(distNear, distFar, attNearDb, attFarDb)
		);
		distance = distance.sqrt;
		Out.ar(glrvbout, result * glrvbamt / distance);
		Out.ar(lcrvbout, result * lcrvbamt * (1 - distance.reciprocal));
	}, /*#[0.1],*/ metadata: metadata);  // 0.1 == lag on 'distance'
} => Func(\addMovingRvbOut);

Instr("busfx.innermod1", { | /*bus,*/ inbus, numChan = 1,
	numbands = 10, freq = 261, centerMul = 25, rq = 0.04, speedMul = 1,
	fshift = 0, modMix = 1, remainderMix = 0.5|
	var	sig = In.ar(inbus, numChan).asArray,
		lfnoises = LFDNoise3.kr(({ Rand(0.2, 12) } ! numbands) * speedMul),
		bpfreqs = lfnoises.exprange(freq, freq*centerMul.clip(20, 20000)),
		modsig = sig.collect { |chan| BPF.ar(chan, bpfreqs, rq) },
		modsigsum = modsig.flop.sum,
		remainder = sig - modsigsum,
		fshifts = lfnoises.scramble * fshift,
		modded = modsig.collect { |chan| FreqShift.ar(chan, fshifts).sum };
		modsig = XFade2.ar(modsigsum, modded, modMix.madd(2, -1));
	(remainder * remainderMix) + modsig
}, [/*\audiobus,*/ \audiobus, StaticSpec(1, 8, \lin, 1), StaticSpec(1, 20, \lin, 1), \freq, #[1, 50, \exp], #[2.0, 0.01, \exp], #[0.001, 2, \exp], #[-150, 150], nil, nil]);


// non-moving
\addRvbOut.eval(\innermod1, { |inbus, freq = 261, centerMul = 25, rq = 0.04, speedMul = 1, fshift = 0, modMix = 1, remainderMix = 0.5, pan = 0|
	var	sig = Instr("busfx.innermod1").valueArray([inbus, 2, 4, freq, centerMul, rq, speedMul, fshift, modMix, remainderMix]);
	Balance2.ar(sig[0], sig[1], pan) // Pan2.ar(sig, pan)
}).add;


// moving: first graph-func arg must be moveTime
\addMovingRvbOut.eval(\innermod1Mv, { |moveTime = 1, inbus, freq = 261, centerMul = 25, rq = 0.04, speedMul = 1, fshift = 0, modMix = 1, remainderMix = 0.5, pan = 0, pan2 = 0|
	var	sig = Instr("busfx.innermod1").valueArray([inbus, 2, 4, freq, centerMul, rq, speedMul, fshift, modMix, remainderMix]);
	pan = Line.kr(pan, pan2, moveTime);
	Balance2.ar(sig[0], sig[1], pan) // Pan2.ar(sig, pan)
}).add;



(
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		// event: (eventKey: \singleSynthPlayer),
		event: (eventKey: \polySynthBusLock,
			notifyDependents: ProtoEvent(\polySynthPlayNotify).v[\notifyDependents]
		),
		master: topEnvironment[\master],
		glrvbmc: topEnvironment[\cRvbMc],
		lcrvbmc: topEnvironment[\lcrvbmc],
		xferfunc: atan((-4.0, -3.98 .. 4.0)).normalize,
		trajectoryKey: \droneTraj,
		trajectoryParms: [
			lowDur: 1.5, hiDur: 4.5, lowRDur: 2.0, hiRDur: 5.0
		],
		userprep: {
			~noisebuf = Buffer.sendCollection(s, Signal.fill(1024, { 1.0.rand2 }).asWavetable, wait: -1);
			[~glrvbmc, ~lcrvbmc].do { |mc|
				mc.tryPerform(\receivesSignalFrom, ~chan);
			};
			~event.proto = topEnvironment[\rvbEvent].proto;
			~activeSynths = IdentitySet.new;

			if(BP.exists(~trajectoryKey).not) {
				PR(\trajectories) => BP(~trajectoryKey);
			};
			BP(~trajectoryKey).synthArgs = ~trajectoryParms;
			// ~krPool = { Bus.control(s, 2) } ! 10;
		},
		userfree: {
			~noisebuf.free;
			// ~krPool.free;
		},
		// xferfunc pulls the deltas toward the edges of the range
		delta: Pwhite(0.0, 0.999, inf).collect { |d| ~xferfunc.blendAt(d * ~xferfunc.size).linlin(0, 1, 5, 20) }, // Pwhite(12.0, 20.0, inf),
		sustain: Pkey(\delta) + Pwhite(5.0, 8.5, inf),
		rq: 0.11,
		speedMul: Pwhite(0.4, 0.9, inf), // Pwhite(6.0, 10.0, inf),
		fshift: Pexprand(4.0, 12.0, inf),
		remainderMix: 0.9,
		objects: { (
			drone: (
				def: \nrgxch, // \addRvbOut.eval(\nrgxdrone, SynthDescLib.at(\nrgxch).def.func),
				args: [
					bufnum: ~noisebuf,
					center: Pexprand(60, 110, inf),
					speed: Pwhite(2.0, 9.0, inf),
					chorDecay: 0.0001,
					moveTime: Pkey(\sustain),
					amp: 4.dbamp,
					fenv: Pfunc({ Env({ exprand(220, 360) } ! 6, 5.reciprocal ! 5) }),
					rqenv: `Env(#[0.2, 0.2], #[1]),
					ampenv: `Env(#[0, 1, 1, 0], #[0.25, 0.5, 0.25], #[3, 0, -3]),
					distance: Pwhite(10.0, 20.0, inf),
					lpcEv: Pbind(
						\instrument, \innermod1,
						\glrvbout, ~glrvbmc.inbus.index,
						\lcrvbout, ~lcrvbmc.inbus.index,
						\glrvbamt, 0.1,
						\lcrvbamt, 0.1,
						\rq, BPStream(\rq),
						\speedMul, BPStream(\speedMul),
						\fshift, BPStream(\fshift),
						\remainderMix, BPStream(\remainderMix),
						#[pan, distance], Plazy { Pseq(BP(~trajectoryKey).xymaps, inf) },
						\killNode, true
					)
				]
			)
		) },
		preparePlay: {
			if(BP.exists(~trajectoryKey)
				and: { BP(~trajectoryKey).clients.includes(~collIndex).not }
			) {
				BP(~trajectoryKey).isUsedBy(~collIndex);
			};
		},
		stopCleanup: {
			// must check: trajectories could have been .free'd
			if(BP.exists(~trajectoryKey) and: { ~activeSynths.isEmpty }) {
				BP(~trajectoryKey).notUsedBy(~collIndex);
			};
		},
		recvEventNotify: { |node|
			var	self, ufunc;
			if(node.isKindOf(Synth)) {
				self = currentEnvironment;
				ufunc = { |obj, what|
					if(what == \n_end) {
						obj.removeDependant(ufunc);
						self[\activeSynths].remove(obj);
						if(self[\isPlaying].not and: { self[\activeSynths].isEmpty
								and: { BP.exists(self[\trajectoryKey]) } }) {
							BP(self[\trajectoryKey]).notUsedBy(self.collIndex);
						};
					}
				};
				~activeSynths.add(node);
				NodeWatcher.register(node);
				node.addDependant(ufunc);
			};
		}
	));
	0 => BP(name);
}, type: \bp) => Fact(\torsoDrone);


(
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		event: (eventKey: \polySynthBusLock),
		master: topEnvironment[\master],
		glrvbmc: topEnvironment[\cRvbMc],
		lcrvbmc: topEnvironment[\lcrvbmc],
		fxrq: 0.2,
		fxspeedMul: 0.71,
		fxfshift: 34.8,
		delta: Pswitch1([
			Pwhite(1.5, 3.0, inf),
			Pexprand(0.2, 0.9, inf)
		], Pwrand([0, Pn(1, Prand(#[1, 2, 3, 4], inf).asStream)], #[0.7, 0.3], inf)), //Pwhite(1.8, 4.0, inf),
		sustain: Pexprand(0.7, 2.8, inf), //Pwhite(1.0, 5.5, inf),
		amp: 1,
		userprep: {
			~noisebuf = Buffer.sendCollection(s, Signal.fill(1024, { 1.0.rand2 }).asWavetable, wait: -1);
			[~glrvbmc, ~lcrvbmc].do { |mc|
				mc.tryPerform(\receivesSignalFrom, ~chan);
			};
			~event.proto = topEnvironment[\rvbEvent].proto;
		},
		userfree: {
			~noisebuf.free;
		},
		objects: { (
			throw: (
				def: \nrgxch,
				args: [
					bufnum: ~noisebuf,
					center: 30, speed: 8, chorDecay: 0.0001, amp: 10.dbamp,
					moveTime: Pkey(\sustain),
					fLow: Pwhite(200, 400, inf),
					fHi: Pwhite(1000, 3000, inf),
					fenv: Pfunc({ |ev|
						[Env(#[0, 0.5, 1, 0.5, 0].linexp(0, 1, ev[\fLow], ev[\fHi]),
							#[0.3, 0.1, 0.1, 0.5], #[5, -3, 3, -2.5])]
					}),
					// rqenv: ,
					ampenv: `[Env(#[0, 0.1, 1, 0.1, 0] * 0.4, #[0.3, 0.1, 0.1, 0.5], \sin)],
					amp: BPStream(\amp),
					lpcEv: Pbind(
						\instrument, \innermod1Mv,
						\distance1, Pwhite(15.0, 20.0, inf),
						\distance2, Pkey(\distance1) / Pwhite(2.0, 3.0, inf),
						\pan, Pwhite(0.5, 1.0, inf) * Prand(#[-1, 1], inf),
						\pan2, Pwhite(0.5, 1.0, inf) * Pkey(\pan).sign.neg,
						\distFar, 20,
						// \glrvbout, ~glrvbmc.inbus.index,
						// \lcrvbout, ~lcrvbmc.inbus.index,
						\rq, BPStream(\fxrq),
						\speedMul, BPStream(\fxspeedMul),
						\fshift, BPStream(\fxfshift),
						\killNode, true
					)
				]
			)
		) }
	));
	0 => BP(name);
}, type: \bp) => Fact(\nrgThrows);



// stephen solo

(
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		event: (eventKey: \singleSynthPlayNotify),
		master: topEnvironment[\master],
		glrvbmc: topEnvironment[\cRvbMc],
		lcrvbmc: topEnvironment[\lcrvbmc],
		alwaysReset: true,
		noiseDef: \mappedDrone,
		timeScale: 5,
		gcSpecs: ~gcSpecs ?? { (
			distance: #[5, 20],
			center: \freq.asSpec.copy.default_(60),
			width: #[0, 80, \lin, 0, 10],
			speed: #[0.05, 20, \exp, 0, 8],
			ffreq: \freq.asSpec.copy.default_(rrand(100.0, 180.0)),
			rq: \myrq.asSpec.copy.default_(0.2),
			amp: [0, 10.dbamp, \lin, 0, 1],
			pan: \bipolar
		) },
		userprep: {
			~noisebuf = Buffer.sendCollection(s, Signal.fill(1024, { 1.0.rand2 }).asWavetable, wait: -1);
			[~glrvbmc, ~lcrvbmc].do { |mc|
				mc.tryPerform(\receivesSignalFrom, ~chan);
			};
			~event.proto = topEnvironment[\rvbEvent].proto;
			~event.put(\chan, nil);  // these are kr synths, shouldn't use MixerCh's bus
			~event.put(\target, ~chan.synthgroup);  // ignored for sound-synth event (w/ ~chan)
	
			~gcs = ~gcSpecs.collect { |spec, name|
				spec = spec.asSpec;
				GenericGlobalControl(name, nil, spec.default, spec);
			};
			~gcMaps = ~gcs.collect { |gc| gc.asMap };
			~gcBuses = ~gcs.collect { |gc| gc.index };

			\addRvbOut.eval(\mappedDrone, { |outbus, bufnum, center = 60, width = 10, speed = 4, ffreq = 1000, rq = 0.2,
				chorCtr = 0.005, chorWidth = 0.003, chorSpeed = 0.02, chorDecay = 0.1,
				pan = 0, amp = 1, timeScale = 1, gate = 1|
				var	freq = LFDNoise1.kr(speed, width, center),
					sig = COsc.ar(bufnum, freq, 1),
					ampenv = Env.asr(1, 1, 1),
					ampeg = EnvGen.kr(ampenv, gate, timeScale: timeScale, doneAction: 2);
				sig = BPF.ar(sig, ffreq, rq);
				3.do {
					sig = sig + AllpassL.ar(sig, chorCtr + chorWidth, max(0.0001, LFDNoise1.kr(chorSpeed, chorWidth, chorCtr)), chorDecay);
				};
				Out.ar(outbus, Pan2.ar(sig, pan, amp * ampeg))
			}).add;
		},
		userfree: {
			~noisebuf.free;
			~gcs.free;
		},
		delta: Pwhite(1.5, 3.0, inf),
		sustain: Pnsym1(Pkey(\synthKey), (
			distance: Pwhite(1.5, 6.0, inf),
			center: Pwhite(1.5, 6.0, inf),
			width: Pwhite(1.5, 6.0, inf),
			speed: Pwhite(1.5, 6.0, inf),
			rq: Pwhite(1.5, 6.0, inf),
			amp: Pwhite(1.5, 6.0, inf),
			ffreq: Pexprand(5.5, 10.0, inf),
			pan: Pexprand(5.5, 10.0, inf)
		)),
		synth: Pwxrand(#[distance, pan, center, ffreq, speed, amp],
			#[4, 1, 2, 1, 3, 2].normalizeSum, inf),
		objects: { (
			distance: (
				def: \ctlEnv,
				args: [
					gc: Pfunc({ |ev| ~gcs[ev[\synthKey]] }),
					bus: Pfunc({ |ev| ev[\gc].index }),
					time: Pkey(\sustain),
					// note: it doesn't matter what the first level is! It's never used.
					// 'connect' is 1 by default, ignoring that level
					levels: Ptuple([18, Pwhite(5.0, 11.0, inf), Pwhite(17.5, 20.0, inf)], inf),
					times: Pwhite(0.2, 0.7, inf).collect { |num| [num, 1-num] },
					curve: \lin,
					env: Pfunc({ |ev| Env(ev[\levels], ev[\times], ev[\curve]) })
				]
			),
			center: (
				def: \ctlEnv,
				args: [
					gc: Pfunc({ |ev| ~gcs[ev[\synthKey]] }),
					bus: Pfunc({ |ev| ev[\gc].index }),
					time: Pkey(\sustain),
					levels: Ptuple([30, Pexprand(200.0, 1200.0, inf), Pexprand(40.0, 70.0, inf)], inf),
					times: Pwhite(0.2, 0.7, inf).collect { |num| [num, 1-num] },
					curve: \exp,
					env: Pfunc({ |ev| Env(ev[\levels], ev[\times], ev[\curve]) })
				]
			),
			// width: (
			// 	def: \ctlEnv,
			// 	args: [
			// 		gc: Pfunc({ |ev| ~gcs[ev[\synthKey]] }),
			// 		bus: Pfunc({ |ev| ev[\gc].index }),
			// 		time: Pkey(\sustain),
			// 		levels: Ptuple([], inf),
			// 		times: Pwhite(0.2, 0.7, inf).collect { |num| [num, 1-num] },
			// 		curve: \exp,
			// 		env: Pfunc({ |ev| Env(ev[\levels], ev[\times], ev[\curve]) })
			// 	]
			// ),
			speed: (
				def: \ctlEnv,
				args: [
					gc: Pfunc({ |ev| ~gcs[ev[\synthKey]] }),
					bus: Pfunc({ |ev| ev[\gc].index }),
					time: Pkey(\sustain),
					levels: Ptuple([8, Pwhite(0.5, 1.2, inf), Pwhite(12.0, 18.0, inf), Pwhite(7.0, 9.0, inf)], inf),
					times: Pwhite(0.1, 0.4, inf).collect { |num| [num, 1.0-(num*2), num] },
					curve: \exp,
					env: Pfunc({ |ev| Env(ev[\levels], ev[\times], ev[\curve]) })
				]
			),
			ffreq: (
				def: \ctlEnv,
				args: [
					gc: Pfunc({ |ev| ~gcs[ev[\synthKey]] }),
					bus: Pfunc({ |ev| ev[\gc].index }),
					time: Pkey(\sustain),
					levels: Pfunc({
						var	n = rrand(3, 5);
						[{ exprand(100.0, 180.0) } ! n, { exprand(340.0, 800.0) } ! n]
							.lace(n*2).drop(#[-1, 0].choose)
					}),
					times: Pfunc({ |ev|
						Array.geom(ev[\levels].size - 1, 0.01, rrand(1.2, 1.6)).normalizeSum
					}),
					curve: \exp,
					env: Pfunc({ |ev| Env(ev[\levels], ev[\times], ev[\curve]) })
				]
			),
			// rq: (
			// 	def: \ctlEnv,
			// 	args: [
			// 		gc: Pfunc({ |ev| ~gcs[ev[\synthKey]] }),
			// 		bus: Pfunc({ |ev| ev[\gc].index }),
			// 		time: Pkey(\sustain),
			// 		levels: Ptuple([], inf),
			// 		times: Pwhite(0.2, 0.7, inf).collect { |num| [num, 1-num] },
			// 		curve: \exp,
			// 		env: Pfunc({ |ev| Env(ev[\levels], ev[\times], ev[\curve]) })
			// 	]
			// ),
			amp: (
				def: \ctlEnv,
				args: [
					gc: Pfunc({ |ev| ~gcs[ev[\synthKey]] }),
					bus: Pfunc({ |ev| ev[\gc].index }),
					time: Pkey(\sustain),
					levels: Ptuple([1, Pwhite(3.dbamp, 8.dbamp, inf), Pwhite(0.8, 1.0, inf)], inf),
					times: Pwhite(0.2, 0.7, inf).collect { |num| [num, 1-num] },
					curve: \exp,
					env: Pfunc({ |ev| Env(ev[\levels], ev[\times], ev[\curve]) })
				]
			),
			pan: (
				def: \ctlEnv,
				args: [
					gc: Pfunc({ |ev| ~gcs[ev[\synthKey]] }),
					bus: Pfunc({ |ev| ev[\gc].index }),
					time: Pkey(\sustain),
					levels: Pfunc({
						var	n = rrand(3, 5);
						[{ rrand(-1.0, -0.75) } ! n, { rrand(0.75, 1.0) } ! n]
							.lace(n*2).drop(#[-1, -2].choose).add(0.2.rand2)
							* #[-1, 1].choose
					}),
					times: Pfunc({ |ev|
						Array.geom(ev[\levels].size - 1, 0.01, rrand(1.2, 1.6)).normalizeSum
					}),
					curve: \lin,
					env: Pfunc({ |ev| Env(ev[\levels], ev[\times], ev[\curve]) })
				]
			)
		) },
		recvEventNotify: { |node, ev|
			if(ev[\instrument] == ~noiseDef) {
				~freeNoise.();	// release the old one, jes' in case
				~noiseSynth = node;
			}
		},
		freeNoise: {
			~noiseSynth !? {
				(type: \off, hasGate: true, id: ~noiseSynth.nodeID).play;
				~noiseSynth = nil;
			};
		},
		preparePlay: {
			~gcs.do { |gc| gc.value = gc.spec.default }
		},
		stopCleanup: {
			// maybe I need other cleanups
			~freeNoise.();
		},
		superPattern: PR(\basicSynthChooser).v[\asPattern],
		asPattern: {
			Pseq([
				(	instrument: ~noiseDef,
					bufnum: ~noisebuf,
					chorDecay: 0.0001,
					sustain: inf,
					chan: ~chan,
					// not really but I want this to go in fx group anyway
					isFx: true,
					timeScale: ~timeScale,
					delta: rrand(2.0, 5.0)
				).putAll(~gcMaps),
				~superPattern.()
			], 1)
		}
	));
	0 => BP(name);
}, type: \bp) => Fact(\torsoSolo);



// IMPORTANT: pass in [~glrvbmc, ~lcrvbmc] as chuck parms
PR(\abstractProcess).clone {
	~event = (eventKey: \polySynthPlayNotify);
	~alwaysReset = true;  // for fx

	~gate = Pexprand(0.08, 0.2, inf);
	~attackTimeScale = Pkey(\gate).linlin(0.01, 1.0, 5, 0.5);
	~decayTimeScale = Pkey(\attackTimeScale);
	~mode = Pstutter(
		Pwhite(5, 12, inf),
		Ppatlace([\ab0, Pxrand(Mode.keys.asArray.select { |key| key.asString.last == $0 }, inf)],
			inf)
	);
	~degree = Pvbrown(21, 33, Pwrand(#[1, 2, 3, 4], #[3, 4, 3, 1].normalizeSum, inf), inf)
	/*+ #[0, 7]*/ + Prand(#[-7, 0], inf);
	~chordDegree = Pvbrown(35, 49, Pwrand(#[1, 2, 3, 4], #[3, 4, 3, 1].normalizeSum, inf), inf, { rrand(42, 49) })
	- Pxrand(#[
		[0],
		[0, -1],
		[0, 1, 6],
		[0, 2],
		[0, 2, 3],
		[0, 4, 5]
	], inf);
	~delta = Pwhite(15.0, 25.0, inf);
	~sustain = Pkey(\delta) * Pwhite(0.6, 0.8, inf);

	~prep = {
		~chan = MixerChannel(~collIndex, s, 2, 2, outbus: topEnvironment[\master]);
		[~glrvbmc, ~lcrvbmc].do { |mc|
			mc.tryPerform(\receivesSignalFrom, ~chan);
		};
		~sideBus = Bus.audio(s, 2);
		~event.put(\chan, nil).put(\target, ~chan.synthgroup).put(\bus, ~sideBus.index);
		~rq = GenericGlobalControl(\rq, nil, 0.04, #[2, 0.01, \exp]);
		~speedMul = GenericGlobalControl(\speedMul, nil, 0.1, #[0.01, 2, \exp]);
		~fshift = GenericGlobalControl(\fshift, nil, 0, #[-120, 120]);
		// guarantee consecutive buses for distance and pan
		~gcbuspair = Bus.control(s, 2);
		~distance = GenericGlobalControl(\distance, ~gcbuspair.index.asBus(\control, 1, s), 17, #[5, 20]);
		~pan = GenericGlobalControl(\pan, (~gcbuspair.index + 1).asBus(\control, 1, s), 0, \bipolar);
		~nodes = IdentitySet.new;
	};

	~useGui = { |vpi|
		#[rq, speedMul, fshift, distance].do { |key|
			key.envirGet => VP(vpi);
		}
	};

	~freeCleanup = {
		[~chan, ~sideBus, ~rq, ~speedMul, ~fshift, ~distance, ~pan].free;
	};

	~preparePlay = {
		~fxSynth ?? {
			~fxSynth = ~chan.playfx(\innermod1, [
				distance: ~distance,
				pan: ~pan,
				distFar: 20,
				glrvbout: ~glrvbmc.inbus.index,
				lcrvbout: ~lcrvbmc.inbus.index,
				glrvbamt: 0.1,
				lcrvbamt: 0.1,
				inbus: ~sideBus,
				rq: ~rq,
				speedMul: ~speedMul,
				fshift: ~fshift
			]);
			~event[\voicer].globalControls[\bufmod]
				.watch
				.automate { LFDNoise1.kr(3.5).range(0, 6.999) };
			~pan.automate {
				var	radius = LFDNoise1.kr(Rand(0.1, 0.4)).range(0.5, 1.0),
					angle = Integrator.kr(LFDNoise1.kr(Rand(0.5, 1.1)).range(0.1, 0.6) * ControlDur.ir);
				cos(angle) * radius
			};
		}
	};

	~recvEventNotify = { |node, event|
		var	self = currentEnvironment,
			endFunc = { |obj, what|
				if(what == \n_end) {
					self.use {
						obj.removeDependant(endFunc);
						~nodes.remove(obj);
						if(~nodes.isEmpty and: { ~isPlaying.not and: { ~fxSynth.notNil } }) {
							~fxSynth.free;
							~fxSynth = nil;
							~event[\voicer].globalControls[\bufmod].stopWatching.stopAuto;
							~distance.stopAuto;
						};
					};
				};
			};
		node.do { |node|
			~nodes.add(node);
			node.addDependant(endFunc);
			NodeWatcher.register(node);
			~distance.automate(\ctlEnv, [
				time: event[\sustain] * rrand(0.85, 0.95),
				env: Env([17, rrand(5.0, 9.5), 17], #[0.4, 0.6], \sine)
			], ~chan.synthgroup, \addBefore);
		};
	};

	~asPattern = {
		Pbind(
			\instrument, ~event[\voicer].nodes[0].defname,
			\gate, BPStream(\gate),
			\attackTimeScale, BPStream(\attackTimeScale),
			\decayTimeScale, BPStream(\decayTimeScale),
			\mode, BPStream(\mode),
			\degree, BPStream(\degree),
			\freq, Pfunc { |ev| ev[\mode].asMode.cps(ev[\degree]) },
			\ffreq, ~event[\voicer].globalControls[\ffreq].asMap,
			\rq, ~event[\voicer].globalControls[\rq].asMap,
			\finalAmp, ~event[\voicer].globalControls[\finalAmp].asMap,
			\bufmod, ~event[\voicer].globalControls[\bufmod].asMap,
			\delta, BPStream(\delta),
			\sustain, BPStream(\sustain)
		)
	};

	~bindVoicer = { |vc|
		SynthDescLib.at(vc.nodes[0].defname.asSymbol).msgFuncKeepGate = true;
		~vcKey = VC.keys.detect { |key| VC(key).value === vc };
	};
} => PR(\torsoTones);


(
vcKey: \tton,
make: { |name|
	BP(name).free;
	PR(\torsoTones).chuck(BP(name), nil, (
		glrvbmc: topEnvironment[\cRvbMc],
		lcrvbmc: topEnvironment[\lcrvbmc]
	));
	if(VC.exists(~vcKey)) {
		BP(name) => VC(~vcKey);
	} {
		"VC(%) not found; set voicer manually".format(~vcKey.asCompileString).warn;
	};
	0 => BP(name);
}, type: \bp) => Fact(\ttonesBP);


{ |name|
	Fact(\shimmerpad).chuck(VC(name), nil, (
		makeTempAmps: {
			{ |i| Array.squareAmps((20000 / ((4+i) * 12).midicps).asInteger) } ! ~numRows
		},
		randomizeAmps: { |amps|
			var	indices = (0 .. amps.size-1).scramble.keep(max(1, amps.size div: 3));
			amps = amps.copy;
			indices.do { |i| amps[i] = amps[i] + 0.12.rand2 };
			amps
		},
		bufModFunc: { Lag.kr(NamedControl.kr(\bufmod, 0), 0.08) },
		spatialize: false
	));
	VC(name).v.mapGlobal(\bufmod, nil, 0, #[0, 6.999]);
	VC(name).v.mapGlobal(\finalAmp, nil, 1, \amp);
	VC(name).v.globalControls[\ffreq].value = 3000;
} => Func(\makettoneVC);



// poses on chair

PR(\abstractProcess).clone {
	~event = (eventKey: \monoSupport, protoEvent: \polySynthPlayNotify);
	~alwaysReset = true;
	~requiredKeys = #[vcKey];
	~resetAllSources = false;
	~repeats = inf;
	~controlsVCPos = true;
	~useModGCs = true;
	~prep = {
		~ctlBus = Bus.control(s, 3).setn(#[0, 10, 0]);
	};
	~freeCleanup = {
		if(~controlsVCPos and: { VC.exists(~vcKey) and: { VC(~vcKey).env[\modfx].notNil } }) {
			VC(~vcKey).env[\modfx].map(\distance, -1, \pan, -1, \fshift, -1)
		};
		~ctlBus.free
	};

	~freq = \patRejectLastN.eval(Pvbrown(28, 46, Pwrand(#[1, 2, 3], #[0.2, 0.4, 0.4], inf), inf, 36), 2);
	~freq2 = Pseq([Mode(\a).cps(19), Pkey(\freqdelay)], 1);
	~freqlag = Pseq([8, Pwhite(1.5, 3.2, inf)], 1);
	~changingDelta = Prout({ |inval|
		inval = Pseq([12, Pwhite(1.0, 3.0, { rrand(2, 5) }), Pwhite(6.0, 10.0, 1)], 1)
			.embedInStream(inval);
		~delta = Pseq([Pwhite(1.0, 3.0, { rrand(3, 6) }), Pwhite(6.0, 10.0, 1)], 1);
		~deltaStream.next(inval).yield  // this routine gets gc'ed after this
	});
	~sustain = Pif(
		Pbinop('and', Pkey(\delta) >= 6, Pdiff(Pkey(\delta)) > 1),
		Pwhite(5.0, 8.0, inf),
		Pkey(\delta) + Pwhite(4.0, 7.0, inf)
	);
	~gate = 0.05;
	~mode = \a;
	~attackTimeScale = Pkey(\gate).linlin(0, 1, 6, 0.5);
	~decayTimeScale = max(Pkey(\attackTimeScale), 2.5);
	~finalAmp = 0.16;

	~preparePlay = {
		if(~controlsVCPos and: { ~rotSynth.isNil }) {
			~rotSynth = {
				var	radius = LFDNoise1.kr(Rand(0.1, 0.4)).range(0.5, 1.0),
				angle = Integrator.kr(LFDNoise1.kr(Rand(0.5, 1.1)).range(0.1, 0.6) * ControlDur.ir);
				[	cos(angle) * radius,
					(sin(angle) * radius).linlin(-1.0, 1.0, 5.0, 20.0),
					LFDNoise1.kr(0.07).exprange(0.001, 8)
				]
			}.play(VC(~vcKey).env.target.fadergroup, ~ctlBus, addAction: \addToHead);
		};
	};
	~stopCleanup = {
		(~clock ?? { TempoClock.default }).sched(10, e {
			if(~isPlaying.not and: { ~rotSynth.notNil }) {
				~rotSynth.free;
				~rotSynth = nil;
			};
			nil
		});
	};
	~userPattern = {
		var	pbind = Pbind(
			\mode, BPStream(\mode, ~resetAllSources),
			\freq, BPStream(\freq, ~resetAllSources).collect { |deg, ev| ev[\mode].asMode.cps(deg) },
			\freqdelay, Pdelay(Pkey(\freq), 1),
			\freq2, BPStream(\freq2, ~resetAllSources),
			\freqlag, BPStream(\freqlag, ~resetAllSources),
			\delta, BPStream(\delta, resetSource: true),
			\sustain, BPStream(\sustain, ~resetAllSources),
			\gate, BPStream(\gate, ~resetAllSources),
			\attackTimeScale, BPStream(\attackTimeScale, ~resetAllSources),
			\decayTimeScale, BPStream(\decayTimeScale, ~resetAllSources)
		);
		if(~useModGCs.not) {
			pbind = Pbindf(pbind,
				\mod_ratio, BPStream(\mod_ratio, ~resetAllSources),
				\mod_lev, BPStream(\mod_lev, ~resetAllSources),
				\finalAmp, BPStream(\finalAmp)
			);
		};
		PnNilSafe(pbind, ~repeats)
	};
	~asPattern = {
		Pchain(
			Pfunc({ |ev|
				var ev2;
				if(ev[\freq] != ev[\freq2]) {
					ev2 = ev.copy
						.put(\freq, ev[\freq2])
						.put(\delta, 0.01);
					ev2.yield;
					(protoEvent: \polySynthTrigger,
						node: ev2[\node],
						freq: ev[\freq], delta: ev[\delta] - 0.01)
					.parent_(~event.parent)
				} { ev }
			}),
			~userPattern.(),
			().putPairs(~event[\voicer].nodes[0].mapArgs)
		)
	};

	~bindVoicer = { |vc|
		if(~controlsVCPos and: { VC.exists(~vcKey) and: { VC(~vcKey).env[\modfx].notNil } }) {
			// unmap position in old voicer
			VC(~vcKey).env[\modfx].map(\distance, -1, \pan, -1, \fshift, -1)
		};
		~vcKey = VC.keys.detect { |key| VC(key).value === vc };
		~event.putAll((
			target: VC(~vcKey).env.target.synthgroup,
			bus: VC(~vcKey).env[\sideBus] ?? { VC(~vcKey).env.target.inbus },
			instrument: VC(~vcKey).v.nodes[0].defname
		));
		if(~controlsVCPos and: { VC(~vcKey).env[\modfx].notNil }) {
			// unmap position in old voicer
			VC(~vcKey).env[\modfx].map(*(
				[#[pan, distance, fshift], ~ctlBus.index + #[0, 1, 2]].flop.flat
			))
		};		
	};

	~reset = {
		~delta = ~changingDelta;
		#[delta, freq, freq2, freqlag, sustain].do { |key|
			~makeStreamForKey.(key)
		};
	};
} => PR(\tposes);



(make: { |name|
PR(\tposes).chuck(BP(name), nil, (
	// controlsVCPos: false,  // REENABLE FOR SEQUENCE
	mode: Pseq([
		Pn(\a0, { rrand(25, 65) }),
		Pstutter(Pwhite(6, 10, { rrand(1, 3) }),
			Pxrand(Mode.keys.select { |key| key != \a0 and: { key.asString.last == $0 } }.asArray, inf)
		)
	], inf).collect { |mode| ~lastMode = mode },
	num: Pwrand(#[1, 2, 3], #[0.7, 0.2, 0.1], inf),
	freq: Pvbrown(28, 47, Pwhite(3, 6, inf), inf) - Pfunc({ |ev|
		var	n;
		~numStream ?? { ~makeStreamForKey.(\num) };
		n = ~numStream.next(ev);
		(#[0] ++ ({ #[1, 2, 3].wchoose(#[0.2, 0.45, 0.35]) } ! (n-1))).integrate
	}),
	freq2: Pkey(\freq) * Pif(0.02.asPattern.coin, Pwhite(0.6, 0.8, inf), 1),
	freqlag: Pif(Pbinop('==', Pkey(\freq), Pkey(\freq2)), 0, Pwhite(0.2, 0.8, inf)),
	changingDelta: Prand([
		Pstutter(inf, Pexprand(0.08, 0.14, 1)) * Pseq([Pn(1, { rrand(3, 7) }), 3], 1),
		Pexprand(0.08, 0.2, { rrand(8, 17) }),
		Plazy({
			var	curve = Env([rrand(0.06, 0.09), rrand(0.18, 0.35)], #[1], 5).asArray;
			Pseries.fromEndpoints(0.0, 1.0, rrand(8, 14)).collect { |x| curve.envAt(x) }
		})
	], inf),
	sustain: max(0.08, Pkey(\delta) * Pwhite(0.25, 0.6, inf)),
	attackTimeScale: 0.1,
	decayTimeScale: Pif(Pbinop('==', Pkey(\freq), Pkey(\freq2)), 0.4,
		(Pkey(\freqlag) - Pkey(\sustain) + Pwhite(0.4, 0.8, inf))
	)
));
0 => BP(name);
}, type: \bp) => Fact(\fastnotesBP);
