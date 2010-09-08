
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


