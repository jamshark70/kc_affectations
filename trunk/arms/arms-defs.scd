// some general definitions


#[c, db, d, eb, e, f, gb, g, ab, a, bb, b].do { |key, i|
	Mode(\default).v.copy.root_(i) => Mode(key);
	Mode(key).v.transposeRoot(0) => Mode((key ++ "0").asSymbol);
};


{ |minval, midval, maxval|
	var a, b, c, sqrterm, qresult, sgn = sign(maxval - minval);
		// the formula is unstable just above the average of minval and maxval
		// so mirror the midval around the average
	(midval > ((maxval + minval) * 0.5)).if({
		midval = minval + maxval - midval;
		sgn = sgn.neg;
	});
	a = midval - minval;
	b = minval - maxval;
	c = maxval - midval;
	sqrterm = sqrt(b.squared - (4 * a * c));
	(((qresult = (sqrterm - b) / (2 * a))).abs != 1).if({
		// note, NOT taking the log here
		// because the mapsynth would just have to .exp it
//		log(qresult.squared).abs * sgn
		qresult.squared * sgn
	}, {
		((b.neg - sqrterm) / (2 * a)).squared * sgn
	});
} => Func(\growForCurve);


SynthDef(\mapParm, { |bus, lo = 0, hi = 1, grow = 1|
	var	a, b;
	grow = Select.kr(InRange.kr(grow, 0.999, 1.001), [grow, 1.001]);
	a = (hi-lo) / (1.0 - grow);
	b = lo + a;
	b = b - (a * pow(grow, In.kr(bus, 1).madd(0.5, 0.5)));
	ReplaceOut.kr(bus, b);
}).perform(Library.at(\ddwGlobal, \storeMethod));

SynthDef(\snapback, { |inpos = 0, threshold = 0.5, center = 0,
		startFreq = 18, endFreq = 2, decayTime = 1,
		threshScale = 1, inLag = 0.1,
		outbus, replyID|
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
		wobble = Ringz.kr(pulse4filter, freq, decayTime).clip(thresh4clip.neg, thresh4clip),
		sig = Select.kr(state, [wobble, inScaled.clip(thresh4clip.neg, thresh4clip)]),
		stateChanging = (trig0to1 + trig1to0 /* + trig2to0 */ > 0);
	LocalOut.kr([
			// float wrapping!!
		(state + stateChanging).wrap(0, 2),
		wobble
	]);
	SendReply.kr(stateChanging, "/snapbackState", trig0to1, replyID); 
	ReplaceOut.kr(outbus, sig);
}).perform(Library.at(\ddwGlobal, \storeMethod));

SynthDef(\xyactivity, { |busnum, avgCycles = 100 /*, lag = 0.06 */|
	var	// in = Lag.kr(In.kr(busnum, 2), lag),
		in = In.kr(busnum, 2),
		oldTheta = Select.kr(Impulse.kr(0), [LocalIn.kr(1), 0]),
		x = in[0], y = in[1],
		xdiff = HPZ1.kr(x),
		ydiff = HPZ1.kr(y),
		xmean = RunningSum.kr(xdiff, avgCycles) / avgCycles,
		ymean = RunningSum.kr(ydiff, avgCycles) / avgCycles,
		theta = atan2(ymean.neg, xmean),
		xact = RunningSum.kr(xdiff.abs, avgCycles) / avgCycles,
		yact = RunningSum.kr(ydiff.abs, avgCycles) / avgCycles,
		radius = (xact.squared + yact.squared).sqrt;
	// if input is not moving, theta will be 0;
	// but really I want it to return the previous theta

var tIndex = BinaryOpUGen('==', xmean, 0) * BinaryOpUGen('==', ymean, 0);
// [theta, oldTheta].poll(tIndex, "theta, old");
	theta = Select.kr(tIndex, [theta, oldTheta]);
	// thanks to Wouter for this trick to "unwrap" the atan result
	// but it depends on a bugfix that Lorne won't have
	theta = Wrap.kr(theta, oldTheta - pi, oldTheta + pi);
// theta.poll(Impulse.kr(2), "theta");
	LocalOut.kr(theta);
	ReplaceOut.kr(busnum+2, [xmean, ymean, xact, yact, theta, radius]);
}).perform(Library.at(\ddwGlobal, \storeMethod));


// track when derivative changes from positive to negative or vice versa
// assumes smoothing is already done by xyactivity
// this could be either x or y!
// zeroTimeThresh: At top of curve, direction may be 0 very briefly
// if that time < threshold, allow it for a hit
// otherwise, suppress it
// that should strip out false triggers if it's stationary, then starts moving

/*
SynthDef(\trigReverseDirection, { |busnum, thetabus, replyID, zeroTimeLo = 0.03, zeroTimeHi = 0.1, dirThresh = 0.01|
	var	deriv1 = In.kr(busnum, 1),  // first derivative
		direction = deriv1.sign,  // remove subtle changes
		directionChange = HPZ1.kr(direction).abs,
		time = Timer.kr(directionChange),
	//		hitFromZero = (directionChange >= 0) * (time < zeroTimeThresh),
		hitFromZero = (directionChange >= 0) * InRange.kr(time, zeroTimeLo, zeroTimeHi),
		hitPassZero = directionChange >= 1,
		allowHit = deriv1.abs >= dirThresh,
		hit = (hitPassZero + hitFromZero) * allowHit;
	// HPZ1 is (x[i] - x[i-1]) * 0.5; if abs >= 1, it means -1 --> 1 or 1 --> -1
	// deriv1.poll(hitPassZero + hitFromZero, "direction");
	//directionChange.poll(hitPassZero + hitFromZero, "direction");
	//time.poll(hitFromZero, "time");
	SendReply.kr(hit, '/dirChanged', direction, replyID);
}).perform(Library.at(\ddwGlobal, \storeMethod));
*/

SynthDef(\trigReverseDirection, { |busnum, replyID, crossTheta = 0.5pi, timeBetween = 0.1|
	var	initTrig = Impulse.kr(0),
		theta = In.kr(busnum, 1),
		prevTheta = Select.kr(initTrig, [LocalIn.kr(1), theta]),
		crossMapped = crossTheta.wrap(theta - 0.5pi, theta + 0.5pi),
		trig = InRange.kr(crossMapped, min(prevTheta, theta), max(prevTheta, theta)),
	time = Timer.kr(trig);
	trig = trig * (time >= timeBetween);
	// <! is necessary to force LocalOut to be later in the chain than LocalIn
	LocalOut.kr(theta <! trig);
	SendReply.kr(trig, '/dirChanged', theta, replyID);
}).perform(Library.at(\ddwGlobal, \storeMethod));

// track continuous angle changes > x radians?



// dispatcher
(
PR(\abstractProcess).clone {
	// for busy-wait, just to maintain playing status
	~event = (eventKey: \dummy);
	~alwaysReset = true;

	// default: you should override for multiple instances
	~busIndex = s.options.numControlBusChannels - 100;

	~busParms = #[mousex, mousey, xmeanDelta, ymeanDelta, xactivity, yactivity, theta, radius];

	~prep = {
		if(s.controlBusAllocator.reserve(~busIndex, ~busParms.size, warn: false).notNil) {
			~bus = Bus(\control, ~busIndex, ~busParms.size, s);
		} {
			BP(~collIndex).free;
			Error("Couldn't allocate % channels at given index %.".format(~busParms.size, ~busIndex)).throw;
		};

		~trackDefs = ~trackers.();

		~trackGroup = Group(s.asTarget, \addBefore);

		~resetBusParms.();
// 		s.makeBundle(nil, {
// 		});
	};

	~avgCycles = 50;
	~mainTrackSynth = {
		Synth(\xyactivity, ~trackSynthArgs.(), ~trackGroup, \addToHead);
	};
	~trackSynthArgs = {
		[busnum: ~bus, avgCycles: ~avgCycles, lag: 0.06]
	};

	~trackers = { (
		yReverseDir: (
			def: \trigReverseDirection,
			respPath: '/dirChanged',
			busParm: \theta,
			args: [crossTheta: 0],
			action: { |msg| BP(\vertNotes).triggerOneEvent(0) },
			active: false,
			activateOnPlay: true
		)
	) };

	~activate = { |key|
		var	def = ~trackDefs[key];
		if(def.notNil and: { def.active.not }) {
			~startOneTracker.(def);
		}
	};

	~deactivate = { |key|
		var	def = ~trackDefs[key];
		if(def.notNil and: { def.active }) {
			~stopOneTracker.(def);
		}
	};

	~toggle = { |key|
		var	def = ~trackDefs[key];
		if(def.notNil) {
			if(def.active) {
				~stopOneTracker.(def);
			} {
				~startOneTracker.(def);
			};
		}
	};

	~startTrackers = {
		~trackSynth = ~mainTrackSynth.();
		~trackDefs.do { |def|
			if(def.activateOnPlay ? true) {
				~startOneTracker.(def);
			};
		};
	};

	~startOneTracker = { |def|
		def.node = Synth(def.def, ~baseArgs.(def) ++ def.args(def), ~trackGroup, \addToTail);
		def.resp = OSCpathResponder(s.addr, [def.respPath, def.node.nodeID], e { |time, resp, msg|
			def[\action].(msg)
		}).add;
		def.active = true;
	};

	~stopOneTracker = { |def|
		def.node.free;
		def.resp.remove;
		def.node = nil;
		def.resp = nil;
		def.active = false;
	};

	~baseArgs = { |def|
		var	i = ~indexForParm.(def.busParm);
		if(i.isNil) {
			"%'s bus parameter % is not defined. Defaulting to %."
				.format(~trackDefs.findKeyForValue(def), def.busParm, ~busParms[0])
				.warn;
			i = 0;
		};
		[busnum: ~bus.index + i]
	};

	~indexForParm = { |key| ~busParms.indexOf(key) };
	~busnumForParm = { |key| ~indexForParm.(key) + ~bus.index };

	~stopCleanup = {
		~trackSynth.free;
		~trackSynth = nil;
		~trackDefs.do { |def|
			~stopOneTracker.(def);
		};
	};

	~freeCleanup = {
		~trackGroup.free;
		~bus.free;
	};

	~resetBusParms = { |val = 0|
		~busParms.do { |key|
			key.envirPut(val);
		};
		~bus.setn(val ! ~busParms.size);
	};

	~asPattern = {
		Pseq([
			Pfuncn {
				~startTrackers.();
				0
			},
//			Pbind(\delta, 2)
			Prout {
				loop {
					~bus.getn(~bus.numChannels, e { |val|
						~busParms.do { |key, i|
							// if there's no movement, theta is NaN;
							// keep the old value in the Proto var
							if(val[i].isNaN.not) { key.envirPut(val[i]) };
						};
						currentEnvironment.changed(\busValues);
					});
					0.1.yield;
				}
			}
		], 1)
	};
} => PR(\xyDispatch);


Proto({
	~mouseColor = Color.red;
	~mouseColor2 = Color.red(alpha: 0.2);
	~winSize = min(800, Window.screenBounds.height - 50);

	// you should set this at chuck time
	~model = \xy;
	~useMouse = false;

	~prep = {
		if(BP.exists(~model)) {
			~initViz.();
			BP(~model).v.addDependant(currentEnvironment);
		} {
			BP(~collIndex).free;
			Error("Model % for this GUI doesn't exist.".format(~model)).throw;
		};
	};

	~freeCleanup = {
		~busrefresh.stop;
		~window.onClose_(nil).close;
		BP(~model).v.removeDependant(currentEnvironment);
	};

	~update = { |obj, what|
		if(what == \busValues) {
			defer(e { ~trackView.refresh });
		};
	};

	~initViz = {
		~halfSize = ~winSize * 0.5;
		~vizspec = \bipolar.asSpec;
		~window = Window(~model, Rect.aboutPoint(Window.screenBounds.center, ~halfSize, ~halfSize))
			.acceptsMouseOver_(true)
			.onClose_(e {
				BP(~collIndex).free;
			});
		~trackView = UserView(~window, Rect(0, 0, ~winSize, ~winSize))
			.background_(Color.new255(255, 255, 180, 255 * 0.5))
			.drawFunc_(e { |view|
				var	x, dx, y, radius, theta;
				x = ~vizspec.unmap(~getParm.(\mousex)) * ~winSize;
				y = ~vizspec.unmap(~getParm.(\mousey)) * ~winSize;
				radius = ((~getParm.(\radius) + 0.25).log + 1.388) * ~winSize * ~diffScale;
				dx = radius * 0.5;
				theta = ~getParm.(\theta);
				Pen	.fillColor_(~mouseColor2)
					.fillOval(Rect(x - dx, y - dx, radius, radius))
					.strokeColor_(~mouseColor)
					.moveTo(x @ y)
					.lineTo(Point(x + (dx * cos(theta)), y - (dx * sin(theta))))
					.moveTo(Point(~getParm.(\xmeanDelta) * ~winSize * 100 + ~halfSize, 0))
					.lineTo(Point(~getParm.(\xmeanDelta) * ~winSize * 100 + ~halfSize, 15))
					.moveTo(Point(0, ~halfSize - (~getParm.(\ymeanDelta) * 100 * ~winSize)))
					.lineTo(Point(15, ~halfSize - (~getParm.(\ymeanDelta) * 100 * ~winSize)))
					.stroke;
			})
			.clearOnRefresh_(true)
			.mouseOverAction_(
				if(~useMouse) {
					e { |view, x, y|
						~getParm.(\bus).setn([(x / ~winSize) * 2 - 1, (y / ~winSize) * 2 - 1]);
					}
				}
			);
		~window.front.refresh;
	};

	~getParm = { |key|
		BP(~model).v[key]
	};
}) => PR(\trackviz);
);


WrapInstr("osc2.fm2carX", { arg freq, gate, car_env, mod_env, mod_lev, mod_ratio, detune, car_detune,
		car_buf, mod_buf, car_vs, mod_vs, basefreq, keyscale, attackTimeScale = 1, decayTimeScale = 1;
	var sig, mod, car_amp, mod_amp, timeScale, car_eg, hit1;

	car_eg = Select.kr(Impulse.kr(0), [LocalIn.kr(1), 0]);
		// once envelope starts going down, attack phase is over
	hit1 = PulseCount.kr(HPZ1.kr(car_eg) < 0) > 0;
	timeScale = Select.kr(hit1, [attackTimeScale, decayTimeScale]);
	car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
	mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
		* EnvGen.kr(mod_env, gate, timeScale: timeScale);
	mod_lev = mod_lev * basefreq / ((keyscale * freq) + (basefreq * (1 - keyscale)));
	mod = Osc.ar(mod_buf, freq.madd(mod_ratio * [1, car_detune], detune * [1, -1]), 0, mod_amp * mod_lev);
	freq = freq * [1, car_detune];
	car_eg = EnvGen.kr(car_env, gate, timeScale: timeScale, doneAction:2);
	LocalOut.kr(car_eg);
	sig = Mix(Osc.ar(car_buf, freq + (mod * freq), 0, car_amp))
		* car_eg;
}, [\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0.01, 300, \exponential], [1, 12, \linear, 0, 1], [-5, 5, \linear, 0, 0], \mydetune, \mybuf, \mybuf, nil, nil, \freq, [0.001, 1.0, \exp], #[0.1, 10, \exp, 0, 1]]);

WrapInstr("osc2.fm2car_stereo", { |physicalPan = 0|
	var	sig = WrapInstr.wrap("osc2.fm2carX");
	Pan2.ar(sig, physicalPan);
}, [\bipolar]);

WrapInstr("osc2.fm2car_pan_lfo", { |freq, freqlag, ampLow = 0.4, ampTimeRatio = 0.3, pan = 0, mod_lev = 1, modLfoSpeed = 0, modLfoAmp = 0, modLfoDecay = 1, modLfoRange = 1, detune = 0, detuneLfoSpeed = 0, detuneLfoAmp = 0|
	var	lfo = Ringz.kr(Impulse.kr(0) * modLfoAmp, modLfoSpeed, modLfoDecay)
			.linexp(-1, 1, modLfoRange.reciprocal, modLfoRange),
		dtlfo = SinOsc.kr(detuneLfoSpeed, mul: detuneLfoAmp),
		sig,
		slideTrig = HPZ1.kr(freq).abs, slideEnv;

	freq = EnvGen.kr(Env(freq ! 2, [freqlag], \sin), gate: slideTrig);
	slideEnv = EnvGen.kr(Env([1, ampLow, 1], [ampTimeRatio, 1 - ampTimeRatio], #[-3, 3]),
		gate: slideTrig, timeScale: freqlag);
	sig = WrapInstr.wrap("osc2.fm2carX", [freq, nil, nil, nil, mod_lev * lfo, nil,
		// detune + dtlfo so that dtlfo = 0 doesn't force detune to be 0
		detune + dtlfo]);
	Pan2.ar(sig * slideEnv, pan);
}, [NoLagControlSpec.newFrom(\freq.asSpec), NoLagControlSpec(0, 10), nil, nil, \bipolar, #[0.01, 300, exponential], #[0.1, 10, exp], nil, #[0.1, 10, exp], #[1, 5], #[-5, 5], #[0.01, 10, exp], #[0, 10]]);

// modLfo will be mapped to a kr bus
// but it's more flexible to make it a direct arg - allows nested patching etc.
// modLfo range expected to be 0-1
WrapInstr("osc2.fm2car_bass_tlfo", { |freq, freqlag, ampLow = 0.4, ampTimeRatio = 0.3, mod_lev = 1, modLfo, modUpRange = 1, detune = 0, detuneLfoSpeed = 0, detuneLfoAmp = 0|
	var dtlfo = SinOsc.kr(detuneLfoSpeed, mul: detuneLfoAmp),
		slideTrig = HPZ1.kr(freq).abs, slideEnv;

	freq = EnvGen.kr(Env(freq ! 2, [freqlag], \sin), gate: slideTrig);
	slideEnv = EnvGen.kr(Env([1, ampLow, 1], [ampTimeRatio, 1 - ampTimeRatio], #[-3, 3]),
		gate: slideTrig, timeScale: freqlag);

	modLfo = modLfo.linexp(-1, 1, modUpRange.reciprocal, modUpRange);
	WrapInstr.wrap("osc2.fm2carX", [freq, nil, nil, nil, mod_lev * modLfo, nil,
		// detune + dtlfo so that dtlfo = 0 doesn't force detune to be 0
		detune + dtlfo]);
}, [NoLagControlSpec.newFrom(\freq.asSpec), NoLagControlSpec(0, 10), nil, nil, #[0.01, 300, exponential], #[0, 1], #[0.1, 10, exp], #[-5, 5], #[0.01, 10, exp], #[0, 10]]);

SynthDef(\repeatingRhythmBus, { |out, numRhythmSlots = 1, rhythmRepeats = 1e10, dropTime = 0.05|
	var	rhythm = \rhythm.kr(0.5 ! 20),
		lev = Dseq(#[0, 1], inf),
		time = Dswitch1([
				// if I use rhythm-dropTime here, it would be 20 binops
				// vs 1 binop this way
			Dseq([Dser(rhythm, numRhythmSlots)], rhythmRepeats) - dropTime,
			dropTime
		], Dseq(#[0, 1], inf));
// 		time = Dseq([Dser(rhythm, numRhythmSlots)], rhythmRepeats),
	Out.kr(out, DemandEnvGen.kr(lev, time, 5, 2.1 /*, timeScale? */));
}).perform(Library.at(\ddwGlobal, \storeMethod));

// t_trig is also the rhythmic value
SynthDef(\trigRhythmBus, { |out, t_trig = 1, top = 1, dropTime = 0.05|
	var	curve = EnvGen.kr(Env([0, top, 0], [t_trig - dropTime, dropTime], 2.1), t_trig);
	Out.kr(out, curve);
}).perform(Library.at(\ddwGlobal, \storeMethod));


/*
	var	modUp = EnvGen.kr(Env(#[0, 1, 0], #[0.92, 0.08], 2.1), modUpTrig,
			levelScale: modUpRange, timeScale: modUpTime),
*/


ProtoEvent(\voicerNote).copy.put(
	\play, #{
		var	lag = ~lag ? 0,  // ~timingOffset !? { ~timingOffset / ~clock.tempo };
			timingOffset = ~timingOffset ? 0,
			clock = ~clock,
			voicer = ~voicer,
			bundle, releaseGate,
			thisEvent = currentEnvironment;
		(~debug == true).if({
			"\n".debug;
			["voicerNote event", ~clock.beats, ~clock.tempo].debug;
			currentEnvironment.collect({ |value| value.isFunction.not.if(value, nil) }).postcs;
		});
		~prepNote.value;
		~finish.value;	// user-definable
		releaseGate = (~releaseGate ? 0).asArray;
		~nodes.do({ |node, i|
			var	freq = ~newFreq.wrapAt(i), length = ~length.wrapAt(i);
			Func(\schedEventBundleArray).doAction(lag, ~timingOffset, node.server,
				node.server.makeBundle(false, {
					node.trigger(freq, ~gate.wrapAt(i), ~args.wrapAt(i), node.server.latency);
				}));
			(length.notNil and: { length != inf }).if({
					// can't use schedEventBundle
					// because you must not release the VoicerNode
					// until the proper time comes
				thisThread.clock.sched(length + timingOffset, {
					if(thisEvent[\postponeReleaseTo].isNil) {
					voicer.releaseNode(node, freq, releaseGate.wrapAt(i),
						lag + (node.server.latency ? 0));
					} {
						thisThread.clock.schedAbs(thisEvent[\postponeReleaseTo], {
							voicer.releaseNode(node, freq, releaseGate.wrapAt(i),
								lag + (node.server.latency ? 0));
						});
					};
				});
			});
		});
	}
) => ProtoEvent(\voicerNotePostponeRelease);


// rhythms for bass notes

PR(\abstractProcess).clone {
	~event = (eventKey: \default);
	~alwaysReset = true;
	~num = 2;
	~bpsKeys = #[top, delta];

	~driver = \cchs;

	~prep = {
		~bus = Bus.control(s, ~num);
//		~amountCtl = GenericGlobalControl(\modAmt, nil, 0);
		~modUpCtl = GenericGlobalControl(\modUpRange, nil, 1, #[0.1, 10, \exp]);

		// populate multiple streams where only one is given at init time
		~bpsKeys.do { |key| ~putAction.(key, key.envirGet) };
		~makeStreamForKey.(\pitch);

		BP(~driver).v.addDependant(currentEnvironment);

		~lastMidiNote = 36;  // if c4 = midC, this is c2
	};

	~freeCleanup = {
		[~bus, /*~amountCtl,*/ ~modUpCtl].free;
		BP(~driver).v.removeDependant(currentEnvironment);
	};

	~busIndex = { |i| ~bus.index + i };

	~top = Pwhite(0.2, 1.0, inf);
	~delta = Pseq([
		Pwhite(2, 6, 1),
		Pwrand(#[0.25, 0.5, 0.75], #[1, 6, 7].normalizeSum, { rrand(7, 19) })
	], inf);

	~pitch = Pfunc {
		var	chEvent = BP(~driver).lastEvent,
			mnote = 14.unmapMode(chEvent[\mode]).asInteger,
			pclass = mnote % 12;

		// adjust octave for smaller interval
		case { pclass < 4 } {
				if(~lastMidiNote >= 45) { mnote = mnote + 12 }
			}
			{ pclass > 8 } {
				if(~lastMidiNote <= 39) { mnote = mnote - 12 }
			};

		~lastMidiNote = mnote;
	};

	~initNotes = {
		var	freq;
		~nodes ?? {
			freq = ~pitchStream.next.midicps;
			// use event[\voicer] per BP => VC syntax
			~nodes = ~event[\voicer].trigger([freq, freq*2], #[1, 0.6], [
// 				modLfo: ~busIndex.((0 .. ~bus.numChannels - 1)),
				modLfo: { |i| ("c" ++ ~busIndex.(i)).asSymbol } ! ~bus.numChannels,
				modUpRange: ~modUpCtl.asMap,
				detuneLfoSpeed: exprand(0.3, 1.7), detuneLfoAmp: 0.2,
				mod_lev: #[3.4, 2.5],
				attackTimeScale: 1, decayTimeScale: 1
			].flop, ~event[\voicer].target.server.latency)
		};
	};

	~stopCleanup = {
		~nodes.do({ |node| node.release(latency: ~event[\voicer].target.server.latency) });
		~nodes = nil;
	};

	~update = { |obj, what, event|
		if(what == \chord) {
			~slideNotes.(event);
		};
	};
	
	~slideNotes = { |ev|
		var	freq = ~pitchStream.next.midicps * #[1, 2];
		~nodes.do { |node, i|
			node.set([freq: freq[i], freqlag: ev[\slideTime]]);
		};
	};

	~asPattern = {
		Pseq([
			Pfuncn {
				~initNotes.();
				Event.silent(0)
			},
			Ppar(
				{ |i|
					Pmono(\trigRhythmBus,
						\out, ~busIndex.(i),
						\top, BPStream(("top" ++ i).asSymbol), // * ~amountCtl,
						\delta, BPStream(("delta" ++ i).asSymbol),
						\trig, Pkey(\delta) / Ptempo()
					)
				} ! ~bus.numChannels
			)
		], 1)
	};

	// putAction is overridden below
	~superPutAction = ~putAction;
} => PR(\rhythmBusPool);

	// BPStream patterns should have separate streams for each parallel Pmono
PR(\rhythmBusPool).v[\putAction] = { |key, value|
	var	streamKey;
	if(value.isPattern
		or: {	streamKey = (key ++ "0Stream").asSymbol;
				streamKey.envirGet.notNil
		}
	) {
		if(~bpsKeys.includes(key)) {
			~num.do { |i|
//				(key ++ i ++ "Stream").asSymbol.envirPut(value.asStream);
				~superPutAction.((key ++ i).asSymbol, value);
			};
		} {
			~superPutAction.(key, value);
		};
	};
};


PR(\abstractProcess).clone {
	~event = (eventKey: \chordChooser);

// 	~chords = Mode.keys
// 		.reject(#[cmin, default].includes(_))
// 		.reject({ |key| key.asString.last == $0 })
// 		.asArray.scramble[..5]
// 		.collect { |key|
// 			(mode: key,
// 				notes: #[21, 25, 28, 30, 31.5, 33, 34, 36, 39, 41, 42.5, 44, 45.5, 47, 50, 51, 53.5])
// 		};

	~prep = {
		~intervals ?? {
			~intervals = Pxrand(~intervalSets, inf);
		};

		// dependent processes need to have some event to use
		// before this process starts playing
		BP(~collIndex).prepareForPlay;
		~eventStream.next(~event.copy);
	};

	~freeCleanup = {
		currentEnvironment.releaseDependants;
	};

	~intervalSets = [
		[-3, -1, -2, -2, -1, -3, -2, -4]
	];

	// assumes root = 0; will be transposed
	~top = Paccumbounce(46, 58, Pwrand(#[-2, -1, 1, 2], #[1, 2, 2, 1].normalizeSum, inf), inf);
	~mode = Pxrand(Mode.keys.select { |key|
		key = key.asString;
		key.size <= 2 and: { key.first.inclusivelyBetween($a, $g) and: { key.last != $0 } }
	}.asArray, inf);
	~slideTime = Pexprand(1.8, 4.4, inf);

	~asPattern = {
		Pbind(
			\top0, BPStream(\top),
			\mode, BPStream(\mode),
			\mode0, Pfunc { |ev| ~getZeroMode.(ev) },
			\top, Pfunc { |ev| ev[\top0].unmapMode(ev[\mode0]).mapMode(ev[\mode]) },
			\intervals, BPStream(\intervals),
// 			\chord, Pxrand(~chords, inf),
			\chord, Pfunc { |ev| ~makeChord.(ev) },
			\delta, Pwhite(3, 6, inf) * 5,
			\slideTime, BPStream(\slideTime)
		).collect({ |ev| ~lastEvent = ev; ev })
	};

// 	~makeChord = { |ev|
// 		var	chs = List.new, stats;
// 		\traverseIntervalTree.eval([ev[\top]], ev[\intervals], chs);
// 		stats = chs.collect { |ch, i|
// 			[\chPitchFit.eval(ch, ev[\top], 0, ev[\mode], Library.at(\fitFactors)), i]
// 		};
// 		stats = stats.sort({ |a, b| a[0] > b[0] });
// 		chs[stats.oneOfTop(3)[1]]
// 	};

	// above "homogenizes" the chords too much (and is SLOW!), so...
	// throw out the fitness calculation and just choose a random order of intervals
	~makeChord = { |ev|
		var	chord = Array(ev[\intervals].size + 1).add(ev[\top]);
		ev[\intervals].scramble.do { |int|
			chord.add(chord.last + int);
		};
		chord
	};

	~getZeroMode = { |ev|
		var	mode = ev[\mode].asString;
		if(mode.last != $0) { mode.add($0).asSymbol } { ev[\mode] };
	};
} => PR(\chordChooser);

(play: {
	// many processes could be listening to me
	BP(~collIndex).v.changed(\chord, currentEnvironment);
}) => ProtoEvent(\chordChooser);


// chord notes factory
(make: { |name|
	BP(name).free;
	PR(\patternTop).chuck(BP(name), nil, (
		driver: \cchs,
		event: (eventKey: \voicerNotePostponeRelease,
			// user hook: to allow sliding to next chord
			finish: {
				BP(~collIndex).recvEventNotify(currentEnvironment);
			}
		),
	
		modeChooser: \default,
		mode: \default,
		ampLow: 0.5,
		ampTimeRatio: 0.4,
	
		dispatcher: \xy,
		prep: {
			var	ev;
			~activeNodes = IdentitySet.new;
			~activeEvents = IdentitySet.new;
			if(~modeChooser.notNil) {
				~makeStreamForKey.(\modeChooser);
				~mode = ~modeChooserStream.next;
			};
	
			BP(~driver).v.addDependant(currentEnvironment);
			ev = BP(~driver).lastEvent;
			~setChord.(ev[\chord], ev[\mode], ev);
		},
		freeCleanup: {
			BP(~driver).v.removeDependant(currentEnvironment);
		},
		deg: Pfunc { ~chord[BP(~dispatcher).mousey.linlin(1, -1, 0, ~chord.size-0.001, \none).trunc] },
		delta: 1,
		length: Pwhite(1.5, 6.0, inf),
		dtSpeed: Pexprand(0.3, 1.7, inf),
			// note, 'freq' is actually scale degree here
			// lower register is less tolerant of modulating detune
		dtAmp: Pkey(\freq).linexp(16, 56, 0.2, 4, clip: \none),
		envScaleSpec: #[0.1, 10, \exp].asSpec,
		envScale: Pfunc {
			~envScaleSpec.map(BP(~dispatcher).radius
				.linlin(0.0001, 0.002, 0, 1, \minmax)).reciprocal
		},
		mod_levelSpec: #[0.8, 2.3].asSpec,
		mod_level: Pfunc {
			~mod_levelSpec.map(BP(~dispatcher).radius
				.linlin(0.0001, 0.002, 0, 1, \minmax))
		},
		modLfoDecaySpec: #[0.1, 7.0, \exp].asSpec,
		modLfoRangeSpec: #[1, 2.5, \exp].asSpec,
		modLfoSpeed: Pexprand(3.0, 8.0, inf),
		modLfoAmp: 1,
		modLfoDecay: Pfunc {
			~modLfoDecaySpec.map(BP(~dispatcher).radius
				.linlin(0.0001, 0.002, 0, 1, \minmax))
		},
			// -0.5 for lower bound means slower movement won't trigger lfo
		modLfoRange: Pfunc {
			~modLfoRangeSpec.map(BP(~dispatcher).radius
				.linlin(0.0001, 0.002, -0.5, 1, \minmax))
		},
		basePattern: PR(\patternTop).v[\asPattern],
	
		recvEventNotify: { |ev|
			ev[\countReleased] = 0;
			~activeEvents.add(ev);
			~activeNodes.addAll(ev[\nodes]);
			// trickery (or work around design flaw):
			// the VoicerNodes don't have the Synth nodes yet,
			// but if I wait until the thread yields, they will
			// oh... and, I know which event the node belongs to b/c of lexical scope!
			defer(e {
				ev[\nodes].do { |node|
					var	upd = Updater(node.synth, e { |obj, what|
						if(what == \n_end) {
							~activeNodes.remove(node);
							ev[\countReleased] = ev[\countReleased] + 1;
							if(ev[\countReleased] == ev[\nodes].size) {
								~activeEvents.remove(ev);
							};
							upd.remove;
						}
					});
				};
			});
		},
	
		update: { |obj, what, event|
			if(obj.collIndex == ~driver and: { what == \chord }) {
				~setChord.(event[\chord], event[\mode], event);
			};
		},
	
		setChord: { |notes, mode(\default), event|
			~chord = notes.sort;
			~mode = mode;
			~slideNotes.(event);
		},
	
		slideNotes: { |ev|
			// need to control slide distance
			// so, map from event's 'freq' + newModeRoot - oldModeRoot
			// to chord notes within a range around it
			var	//pitches = Pshuf(~chord, inf).asStream.nextN(~activeNodes.size),
				slideTime = ev[\slideTime],
				releaseAbsTime = thisThread.clock.beats + slideTime + 2.5,
				event, nodeI, center,
				pool = ~chord.copy, newPitch;
			~activeNodes.do { |node, i|
				event = ~activeEvents.detect { |ev| ev[\nodes].includes(node) };
				// don't slide if the event can't be found
				if(event.notNil) {
					nodeI = event[\nodes].indexOf(node);
					center = event[\freq].asArray[nodeI] - ~mode.asMode.root + event[\mode].asMode.root;
					newPitch = pool.select { |p| p.inclusivelyBetween(center - 8, center + 8) }
						.choose;
					if(newPitch.notNil) {
						pool.remove(newPitch);
						node.set([freq: Mode(~mode).cps(newPitch), freqlag: slideTime]);
						event[\postponeReleaseTo] = releaseAbsTime;
					} {
						// couldn't slide, so release instead
						node.release(freq: event[\newFreq][nodeI]);
					};
				};
			};
		},
	
		asPattern: {
			Pbind(
				\ampLow, BPStream(\ampLow),
				\ampTimeRatio, BPStream(\ampTimeRatio),
				\mod_level, BPStream(\mod_level),
				\detuneLfoSpeed, BPStream(\dtSpeed),
				\detuneLfoAmp, BPStream(\dtAmp),
				\modLfoSpeed, BPStream(\modLfoSpeed),
				\modLfoAmp, BPStream(\modLfoAmp),
				\modLfoDecay, BPStream(\modLfoDecay),
				\modLfoRange, BPStream(\modLfoRange),
				\attackTimeScale, BPStream(\envScale),
				\decayTimeScale, Pkey(\attackTimeScale)
			)
			<>
			~basePattern.()
		}
	));
}, type: \bp) => Fact(\vertNotes);


// couple of Voicer factories
(keys: #[master],
make: { |name|
	~target = MixerChannel(name, s, 2, 2, level: -17.dbamp, outbus: ~master);
	~cb = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg(#[1, 2, 3].reciprocal) });
	~mb = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg(#[1]) });

	Voicer(20, WrapInstr("osc2.fm2car_pan_lfo"), [
		basefreq: `440, keyScale: `0.28621534453893,
		car_buf: ~cb, mod_buf: ~mb,
 		car_env: Env.adsr(0.5, 0.8, 0.75, 1.0),
		mod_ratio: `1, detune: `0, car_detune: `0.99798261661993,
		car_vs: `0.66141732283465, mod_vs: `0
	], target: ~target);
},
free: { [~cb, ~mb, ~target].free }, type: \voicer) => Fact(\fmping);

(keys: #[master],
make: { |name|
	~target = MixerChannel(name, s, 1, 2, level: -17.dbamp, outbus: ~master);
	~cb = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg(#[1, 2, 3].reciprocal) });
	~mb = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg(#[1]) });

	Voicer(20, WrapInstr("osc2.fm2car_bass_tlfo"), [
		basefreq: `440, keyScale: `0.28621534453893,
		car_buf: ~cb, mod_buf: ~mb,
 		car_env: Env.adsr(0.5, 0.8, 0.75, 1.0),
		mod_ratio: `1, detune: 0, car_detune: `0.99798261661993,
		car_vs: 0.66141732283465, mod_vs: `0
	], target: ~target);
},
free: { [~cb, ~mb, ~target].free }, type: \voicer) => Fact(\armsBass);
