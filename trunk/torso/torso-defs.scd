
// just in case... (won't load twice if already loaded)
(thisProcess.nowExecutingPath.dirname.dirname +/+ "common/common-defs.scd").loadPath;


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

(keys: #[master, glrvbmc, lcrvbmc],
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
		chan.newPostSend(~glrvbmc, 0.21);
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
	out.mapGlobal(\clevel, nil, 1, \amp);
	out.mapGlobal(\density, nil, 0.8, #[0.5, 3.0]);
	out.mapGlobal(\freqmul, nil, 1, #[0.5, 2.0, exp], allowGUI: false);
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
