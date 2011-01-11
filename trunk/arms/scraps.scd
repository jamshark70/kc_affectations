		SynthDef(\snapback, { |inpos = 0, threshold = 0.5, center = 0,
				startFreq = 18, endFreq = 2, decayTime = 1,
				threshScale = 1, inLag = 0.1,
				outbus|
			var	initTrig = Impulse.kr(0),
				localIn = LocalIn.kr(2),
				state = Select.kr(initTrig, [localIn[0], 0]),
				oldWobble = Select.kr(initTrig, [localIn[1], 0]),
				inCtr0 = Lag.kr(inpos, inLag) - center,
				inDly1 = Delay1.kr(inCtr0),
				inScaled = inCtr0 * threshScale,
				thresh4clip = abs(threshold * threshScale),
				trig0to1 = BinaryOpUGen('==', state, 0) *
					// that is, if 0 is between previous and current values of inCtr0...
					InRange.kr(oldWobble, min(inDly1, inCtr0), max(inDly1, inCtr0)),
				isState1 = BinaryOpUGen('==', state, 1),
				trig1to0 = isState1 * (inCtr0.abs > threshold),
				freq = EnvGen.kr(Env([startFreq, startFreq, endFreq], [0.01, decayTime], \exp), trig1to0),
				pulse4filter = (trig1to0 * (inScaled - oldWobble)),
				wobble = Ringz.kr(pulse4filter, freq, decayTime)/*.clip(thresh4clip.neg, thresh4clip)*/,
				sig = Select.kr(state, [wobble, inScaled/*, wobble*/]);
state.poll(HPZ1.kr(state).abs, "state");
inCtr0.poll(trig0to1 + trig1to0, "inCtr0");
			LocalOut.kr([
					// float wrapping!!
				(state + (trig0to1 + trig1to0 /* + trig2to0 */ > 0)).wrap(0, 2),
				wobble
			]);
//SendReply.kr(trig0to1 + trig1to0, '/traceme', 0, 1);
pulse4filter.poll(pulse4filter.abs > 0, "pulse4filter");
SendReply.kr(pulse4filter.abs > 2, '/traceme', 0, 1);
			ReplaceOut.kr(outbus, sig);
		}).perform(Library.at(\ddwGlobal, \storeMethod));


/*
		SynthDef(\snapback, { |inpos = 0, threshold = 0.5, center = 0,
				startFreq = 18, endFreq = 2, decayTime = 1,
				threshScale = 1,
				outbus|
			var	initTrig = Impulse.kr(0),
				state = Select.kr(initTrig, [LocalIn.kr(1), 0]),
				inCtr0 = inpos - center,
				inDly1 = Delay1.kr(inCtr0),
				inScaled = inCtr0 * threshScale,
				trig0to1 = BinaryOpUGen('==', state, 0)
					// that is, if 0 is between previous and current values of inCtr0...
					* InRange.kr(0, min(inDly1, inCtr0), max(inDly1, inCtr0)),
				isState1 = BinaryOpUGen('==', state, 1),
				trig1to2 = isState1 * (inCtr0.abs > threshold),
				freq = EnvGen.kr(Env([startFreq, startFreq, endFreq], [0.01, decayTime], \exp), trig1to2),
				trig2to0 = BinaryOpUGen('==', state, 2) * Done.kr(freq),
				pulse4filter = trig1to2 * inScaled,
				wobble = Ringz.kr(pulse4filter, freq, decayTime),
				sig = Select.kr(state, [wobble, inScaled, wobble]);
			// float wrapping!!
//state.poll(HPZ1.kr(state).abs, "state");
			LocalOut.kr((state + (trig0to1 + trig1to2 + trig2to0 > 0)).wrap(0, 3));
			ReplaceOut.kr(outbus, sig);
		}).perform(Library.at(\ddwGlobal, \storeMethod));
*/



if(v.active) { v.free };
v = Voicer(20, WrapInstr("osc2.fm2car_pan_lfo"), [car_buf: ~cb, mod_buf: ~mb, \mod_lev, 4.7777362156971, \mod_ratio, `1, \detune, 0, \car_detune, `0.99798261661993, \car_vs, 0.66141732283465, \mod_vs, `0, \basefreq, `440, \keyscale, `0.28621534453893, car_env: Env.adsr(0.5, 0.8, 0.75, 1.0)], target: n);

WrapInstr("osc2.fm2car_bass_tlfo").listArgs

if(VP.exists(0).not) { VoicerProxy.new => VP.prNew(0) };
v => VP(0);
VP(0).v.gui;

SynthDescLib.at(v.nodes[0].defname.asSymbol).controlNames;

();

k = VoicerMIDISocket(0, v);
k.addControl(nil, \car_vs, 0);
VoicerSusPedal(0, 64, v);

k.noteOnArgsPat = Pbind(
	\detuneLfoSpeed, Pexprand(0.3, 1.7, inf),
	\detuneLfoAmp, Pkey(\midinote).linexp(28, 96, 0.2, 4, clip: \none),
	\modLfoSpeed, Pkey(\velocity).linlin(0, 127, 1.4, 6.0),
	\modLfoAmp, Pkey(\velocity).linlin(0, 127, 0, 1),
	\modLfoDecay, Pkey(\velocity).linlin(0, 127, 1, 8),
	\modLfoRange, Pkey(\midinote).linexp(36, 84, 1.6, 4),
//	\envTimeScale, Pkey(\velocity).linexp(0, 127, 10.0, 0.1),
	\mod_lev, Pkey(\velocity).linlin(0, 127, 1.2, 3.4),
	\attackTimeScale, Pkey(\velocity).linexp(0, 127, 10.0, 0.1),
	\decayTimeScale, Pkey(\velocity).linexp(0, 127, 10.0, 3.5)
);

63.5.linexp(0, 127, 10.0, 0.1)

v.trace;

k.ccs.reverseDo(_.free);
k.free;
v.free;
k.inspect


k.noteOnArgsPat = Pbind(
	\detuneLfoSpeed, Pexprand(0.3, 1.7, inf),
	\detuneLfoAmp, Pkey(\midinote).linexp(28, 96, 0.2, 4, clip: \none),
	\rhythm, Pclump(Pwhite(8, 20), Pwrand(#[0.25, 0.5, 0.75], #[0.4, 0.35, 0.25], inf))
		.collect([_]).trace,
//	\rhythm, [ [#[1.0, 0.25, 0.25] - 0.05, 0.05].flop.flat ],
	\numRhythmSlots, Pfunc { |ev| ev[\rhythm][0].size },
//	\rhythmRepeats, inf,
	\modUpRange, Pkey(\midinote).linexp(36, 84, 1.6, 4),
//	\envTimeScale, Pkey(\velocity).linexp(0, 127, 10.0, 0.1),
	\mod_lev, Pkey(\velocity).linlin(0, 127, 1.2, 3.4),
	\attackTimeScale, Pkey(\velocity).linexp(0, 127, 10.0, 0.1),
	\decayTimeScale, Pkey(\velocity).linexp(0, 127, 10.0, 3.5)
);


// make 1 rhythm synth
~rhy = Bus.control(s, 1);
~rh = Synth(\repeatingRhythmBus, [out: ~rhy, numRhythmSlots: 20, rhythm: Pwrand(#[0.25, 0.5, 0.75], #[0.4, 0.35, 0.25], inf).asStream.nextN(20)]);

[~rh, ~rhy].free;

SynthDescLib.at(\repeatingRhythmBus)


(
~rhySynths = { |i|
	var	return, n = (i+1) * 4;
	s.makeBundle(0.2, {
		return = Synth(\repeatingRhythmBus, [out: ~rhybus.index + i, numRhythmSlots: n,
			rhythm: [rrand(2, 6)] ++ Pwrand(#[0.25, 0.5, 0.75], #[0.4, 0.35, 0.25], inf)
				.asStream.nextN(n-1)]);
	});
	return
} ! ~rhybus.numChannels;
)



p.midinote = /*\patRejectLastN.eval(*/Plazy { |ev|
	var	arpeg = (~arpegStream ?? { ~makeStreamForKey.(\arpeg); ~arpegStream }).next(ev),
		debugpats;
	Pnsym1(Pkey(\row).collect(_.asSymbol), debugpats = ev[\chordItem][\hierarchyDict].collect { |row|
		ArpegPat(arpeg).asPattern(row)
	}.postcs).collect { |n| if(Mode(\g).cps(n) < 30) {
		[n, ev[\row].asCompileString, ev[\row].asSymbol.asCompileString, debugpats[ev[\row].asSymbol]].debug("oh shit");
		debugpats.keysDo { |k| [k, ev[\row].asSymbol, k === ev[\row].asSymbol, k.asSymbol, ev[\row].asSymbol, k.asSymbol === ev[\row].asSymbol].asCompileString.debug("test") };
	}; n }
}/*, 2)*/;




// keeping for posterity, but the 'makeOnePlayer' approach has failed utterly
(
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote, distNear: 5, distFar: 20, midi: false);
	~alwaysReset = true;

	~chords = (
		// each is mode name (symbol), then midinotes
		c_ish: #[g, 48, 55, 57, 64, 66, 74, 81, 83]
	);

	~row = Pwhite(0, Pkey(\rotSpeed) * 2.99, inf).collect(_.asInteger);
	~chord = Pstutter(Pwhite(20, 60, inf), Pfunc { ~fullCh.keys.choose });
	~chordItem = Pfunc { |ev|
		if(ev[\chord] != ~lastChord) {
			~lastChord = ev[\chord];
			// force reset - this makes Plazy reevaluate and grab other chord item
			~makeStreamForKey.(\midinote);
		};
		~fullCh[~lastChord]
	};
	~midinote = \patRejectLastN.eval(Plazy { |ev|
		var	arpeg = ~arpegStream.next(ev);
		Pswitch1(ev[\chordItem][\hierarchy].collect { |row|
			ArpegPat(arpeg).asPattern(row)
		}, Pkey(\row))
	}, 1);
	~arpeg = \armsCh;
	~gate = Pexprand(0.05, 0.2, inf) * Pkey(\rotSpeed).linlin(0.1, Pfunc { ~maxRotSpeed }, 1, 4);
// 	~gate = 0.2;

	~mod_lev = Pkey(\distance).linlin(Pkey(\distNear), Pkey(\distFar), 2.5, 1);
	~radius = sin(Ptime() * 2pi / 11.3247623) * 0.5 + (0.5 * Pkey(\rotSpeed) / Pfunc { ~maxRotSpeed });
// 	~radius = sin(Ptime() * 2pi / 11.3247623) * 0.2 + (0.8 * Pkey(\rotSpeed));

	~dur = Pwrand(#[1, 2], #[0.9, 0.1], inf) * Pkey(\rotSpeed).linexp(0.1, Pfunc { ~maxRotSpeed }, 0.22, 0.08);
	~sustain = Pwhite(1.2, 2.0, inf) * 4 / (Pkey(\row) + 4);
// 	~dur = max(0.1, Pkey(\rotSpeed)).reciprocal / 40;
// 	~sustain = Pkey(\dur) * (3 - Pkey(\row));  // hmm... not quite
	~attScale = Pkey(\rotSpeed).linexp(0.1, Pfunc { ~maxRotSpeed }, 0.5, 1);
// 	~attScale = max(0.1, Pkey(\rotSpeed)).reciprocal * 0.2;
	~decScale = Pkey(\attackTimeScale);

	~maxRotSpeed = 2;
	~maxRotSpeed_ = { |speed = 1|
		if(speed != ~maxRotSpeed) {
			~maxRotSpeed = speed;
			~rotSpeed.spec = [0, speed];  // asSpec is automatic
		};
		currentEnvironment
	};

	~prep = {
		~angle = GenericGlobalControl(\angle, 3997.asBus, 0, [0, 2pi]);
		~rotSpeed = GenericGlobalControl(\rotSpeed, 4000.asBus, 0, [0, ~maxRotSpeed]);
		KrBusWatcher.newFrom(s).updateFreq = 8;
		~fullCh = IdentityDictionary.new;
		~chords.tryPerform(\keysValuesDo, { |key, value|
			~addChord.(key, value)
		});
	};

	~addChord = { |key, value|
		~fullCh.put(key, ~expandChord.(value))
	};

	~expandChord = { |array, adds = #[-7, 0, 7]|
		var	mapped = array[1..].mapMode(array[0]),
			result = (mode: array[0], orig: mapped, allSort: (mapped +.x adds).removeDups.sort,
			hierarchy: adds +.t mapped);
		result.put(\hierarchyDict,
			result[\hierarchy].collectAs({ |row, i| i.asSymbol -> row },
				IdentityDictionary)
		)
		.put(\sortWithLevels, result[\hierarchy].collect { |row, i|
			row.collect { |item| [item, i] }
		}.flatten(1).sort { |a, b| a[0] < b[0] or: { a[0] == b[0] and: { a[1] < b[1] } } });
	};

	~startAuto = { |ev, envir, angle(~angle), rotSpeed(~rotSpeed)|
		s.makeBundle(nil, {
			angle.automate {
				Sweep.kr(1, LFNoise1.kr(0.25).range(0.1, 1.8)).wrap(0.0, 1.0) * 2pi
			};
			rotSpeed.automate({ |maxRotSpeed = 1|
				var a = ~angle.kr,
					last = Select.kr(Impulse.kr(0), [LocalIn.kr(1), a]);
				a = a.wrap(last - pi, last + pi);
				LocalOut.kr(a);
				Slope.kr(a) / (2pi * maxRotSpeed)
			}, target: angle.autoSynth, addAction: \addAfter);
		});
	};

	~stopCleanup = {
		[~angle, ~rotSpeed].do { |gc| gc.stopAuto.stopWatching }
	};

	~freeCleanup = {
		[~angle, ~rotSpeed].free;
	};

	~useGui = { |vpi|
		[~angle, ~rotSpeed].do { |gc| gc => VP(vpi) };
	};


	~asPattern = { |envir, angle, rotSpeed|
		Pseq([
			// workaround scel indent bug
			'Pfuncn'.asClass.new { |ev|
				[angle ? ~angle, rotSpeed ? ~rotSpeed].do(_.watch);
				// this is a bit of a hack, but so is the rest of it!
				BP(envir[\collIndex]).startAuto.(ev, envir, angle, rotSpeed);
				Event.silent(0)
			},
			Pbind(
				\angle, angle ? ~angle,
				\rotSpeed, rotSpeed ? ~rotSpeed,
				\radius, BPStream(\radius, envir: envir),
				\pan, Pkey(\angle).cos * Pkey(\radius),
				\distance, (Pkey(\angle).sin * Pkey(\radius)).linlin(-1, 1, Pkey(\distNear), Pkey(\distFar)),
				\chord, BPStream(\chord, envir: envir),
				\chordItem, BPStream(\chordItem, envir: envir),
				\row, BPStream(\row, envir: envir),
				\freq, BPStream(\midinote, envir: envir),
				\mode, Pfunc { |ev| ev[\chordItem][\mode] },
				\gate, BPStream(\gate, envir: envir),
				\mod_lev, BPStream(\mod_lev, envir: envir),
				\dur, BPStream(\dur, envir: envir),
				\length, BPStream(\sustain, envir: envir),
				\attackTimeScale, BPStream(\attScale, envir: envir),
				\decayTimeScale, BPStream(\decScale, envir: envir)
			) //.trace
		])
	};

	~speedThresh = 0.15;
	~patKeys = #[radius, chord, chordItem, row, midinote, gate, mod_lev, dur, sustain, attScale, decScale, maxRotSpeed, fullCh, arpeg, arpegStream, collIndex];

	~makeOneArpeg = { |envir, angle, rotSpeed|
		var	speedRising = true, thresh = ~speedThresh;
		Pwhile1(
			{	|inevent, next|
				(speedRising or: { (next[\rotSpeed] ? 0) >= thresh })
			},
			~asPattern.(envir, angle, rotSpeed).collect { |ev|
				if((ev[\rotSpeed] ? 0) >= thresh)
					{ speedRising = false };
				ev
			}
		)
	};

	~makeOnePlayer = {
		// envir is to isolate BPStreams
		var	self = currentEnvironment, envir = (), pat, upd;
		~arpegStream ?? { ~makeStreamForKey.(\arpeg) };
		~patKeys.do { |key| envir[key] = key.envirGet };
		envir.angle = GenericGlobalControl(\angle, nil, 0, [0, 2pi]);
		envir.rotSpeed = GenericGlobalControl(\rotSpeed, nil, 0, [0, ~maxRotSpeed]);
		pat = Penvir(envir,
			// force pattern to be made in context of the local envir
			Plazy { self.makeOneArpeg(envir, ~angle, ~rotSpeed) }
		).asEventStreamPlayer(BP(~collIndex).prepareEvent);
		// for some stupid reason, Pfset's cleanup func did not fire
		// so I have to use a notification to remove the global controls created locally
		upd = Updater(pat, { |obj, what|
			if(what == \stopped) {
				upd.remove;
				#[angle, rotSpeed].do { |key| envir[key].debug("freeing").free }
			};
		});
		pat
	};

} => PR(\armsChord);
)


			// gets reset every arpeg; this should choose one or the other
			// BP(\stack).lengthChoices = [
			// 	Pwhite(3.0, 4.5, inf) - Pseries(0, Pkey(\dur), inf),
			// 	//Pexprand(0.1, 0.22, inf)
			// 	Pkey(\dur) * Pwhite(0.45, 0.8, inf)
			// ];
			// BP(\stack).lengthChooser = Pseq([0, Pwrand(#[0, 1], #[0.6, 0.4], inf)], 1);
			// BP(\stack).length = Plazy({ |ev|
			// 	~lengthChoices[~lengthChooserStream.next(ev)]
			// 	//~lengthChoices[0] * rrand(0.2, 1.0)
			// });
			// BP(\stack).attackTimeScale = Pif(Pkey(\length) <= 0.22, 0.1, 1);
			// BP(\stack).decayTimeScale = Pif(Pkey(\length) <= 0.22, 0.7, 1);
			// BP(\stack).mod_lev = Pif(Pkey(\length) <= 0.22, Pwhite(7.0, 12.0, inf), 2.5);



/*
	PR(\tlsAff).copy.putAll((
		name: "A590-locomotive(short)",
		segID: 590,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: Library.at(\diparms),
					loopCmd: (
						id: \lc2,
						autoSync: false,
						cmds: [
							{ BP(\acDisp).spawnChild(0); 0 },
							funcCmd: topEnvironment[\trigParms],
							\cmdSync
						]
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 600,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),
*/


	PR(\tlsAff).copy.putAll((
		name: "A620-Stephen solo",
		segID: 620,
		initProcesses: {
			\chuckIf.eval(PR(\armsSkidMel), BP, \ssol, nil, (
				master: topEnvironment[\master],
				glrvbmc: topEnvironment[\glrvbmc],
				lcrvbmc: topEnvironment[\lcrvbmc],
				event: (eventKey: \polySynthPlayer),
				def: \airskid,
				hiffreq: Pfunc({ |ev|
					var deg = ev[\degree];
					deg = deg + (#[0] ++ ({ #[-1, -2, -3].wchoose(#[0.1, 0.5, 0.4]) } ! 2).integrate);
					Mode(ev[\mode]).cps(deg + 42)
				}),
				delta: Pwhite(1.5, 4.0, inf),
				sustain: Pkey(\delta) * Pwhite(1.8, 2.5, inf),
				amp: 0.45
			));
		},
		unloadProcesses: { BP(\ssol).free },
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: Library.at(\diparms),
					loopCmd: (
						id: \stsolo,
						autoSync: false,
						cmds: [
							{ 2.do { BP(\ssol).triggerOneEvent(0) }; 0 },
							funcCmd: topEnvironment[\trigParms],
							\cmdSync
						],
						clearDoneSignal: { BP(\ssol).stop }
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 630,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

