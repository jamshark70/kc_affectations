
// todo:
// track multiple points, all synths can respond
// other parms (y? orientation?)

// false = drive the control bus from vvvv
// change this to true to debug with mouse
// you don't have to run this: if you don't set the var, it assumes 'false'
~useMouse = true;

// double-click just inside the opening paren here and ctrl-return to run

BP(\pt).listVars
BP(\pt).mode = BP(\pt).mode.trace(prefix: "mode: ");

BP(\pt).vAddr = NetAddr("127.0.0.1", 57120);

(
ProtoEvent(\singleSynthPlayNotify).copy.putAll((
	setArgs: {
		var	/*argbus, args,*/ lib, desc;
		if((lib = SynthDescLib.all[~lib ? \global]).notNil
		and: { (desc = lib[~instrument.asSymbol]).notNil }) {
			~hasGate = desc.hasGate;
			~controlNames = desc.controlNames.collect(_.asSymbol);
			~argbus = Bus.control(~server, ~controlNames.size);			
			~argValues = desc.controls.collect { |cn|
				cn.name.asSymbol.envirGet ?? { cn.defaultValue }
			};
			~argbus.setn(~argValues);
			~args = [~controlNames, (..~controlNames.size-1).collect({ |i| ("c" ++ (i+~argbus.index)).asSymbol })].flop.flat;
		} {
			currentEnvironment.keysValuesDo { |key, val| [key, val].postln };
			Error("singleSynthAutoMap event requires a SynthDesc, but couldn't find it.").throw;
		}
	},
	notifyDependents: {
			// once the synth is dead, don't need the control bus anymore
		OSCpathResponder(~server.addr, ['/n_end', ~node.asNodeID], e { |time, resp, msg|
			protect { BP(~collIndex).v.nodeEndedNotify(~node, currentEnvironment) } {
				resp.remove;
				~argbus.free;
			};
		}).add;
		BP(~collIndex).v.recvEventNotify(~node, currentEnvironment);
	}
)) => ProtoEvent(\singleSynthAutoMap);

ProtoEvent.composite(#[singleSynthPlayer, singleSynthTrigger, singleSynthAutoMap]) => ProtoEvent(\perturb);


PR(\abstractProcess).clone {
	~event = (eventKey: \perturb);
	~parmRejectKeys = #[out, outbus, i_out, gate];
	~busKeys = #[mousex, mousey, xmeanDelta, ymeanDelta, xactivity, yactivity, theta, radius];
	~avgCycles = 50;
	~diffScale = 10;
	
	~mod_ratio = 2;
	~detune = 1.4;
//	~degree = Pwhite(-7, 7, inf) + 35;
	~degree = Pfin({ rrand(5, 9) }, Pshuf((-7..7), 1)) + 35;
	~mode = \default;
	~delta = Pexprand(0.5, 1.8, inf);
	~legato = Pwhite(7.0, 12.0, inf);
	~pan = Pwhite(-0.8, 0.8, inf);
	~restDelta = Pwhite(8.0, 14.0, inf);

	~panXferEnv = Env(#[-1, 0, 1], 0.5 ! 2, #[1.8, -1.8]);
	~panXfer = { |ev| ~panXferEnv.at(ev[\pan] * 0.625 + 0.5) };

	~trackInstr = \snapback;
	~startFreq = Pwhite(4.0, 9.0, inf);
	~decayTime = Pwhite(2.5, 10.0, inf);
	~ornamentProb = 0.06;
	
	~replyName = '/snapbackState';

	// lo/hi/mid/center may be functions, passed the event being processed
	~mapSpecs = (
		mod_lev: (
			lo: 0.2,
			hi: { rrand(7.0, 12.0) },
			mid: { rrand(0.9, 1.25) },
			center: { |ev| ev[\synthEvent][\pan] },
			threshold: 0.2,
			threshScale: 4.9,
			prob: 0.84,
			ornament: \arpeg, // can be pattern also
			ornaments: (
				arpeg: { |nodeEvent| 
					var	mode = nodeEvent[\mode].asMode,
						numEvents = rrand(6, 11),
						panDir = #[-1, 1].choose;
					Pbind(
						\instrument, ~def.name.asSymbol,
						// nodeEvent[\degree]: 35 = mid c; -21 = start 8va higher
						\degree, Paccumbounce(-7, 28, Pwrand(#[-1, 1, 2], #[0.1, 0.45, 0.45], inf), numEvents, nodeEvent[\degree] - 28),
						\scale, mode.scale + mode.root,
						\dur, rrand(0.1, 0.2),
						\mod_lev, Pexprand(1.0, 5.0, inf),
						\sustain, 2.5,
						\gate, 0.5, \amp, 1,
						\physicalPan, Pseries.fromEndpoints(panDir.neg, panDir,
							numEvents) * rrand(0.7, 0.9)
					)
				}
			)
		),
		freq: (
			lo: { |ev| ev[\synthEvent][\freq] * rrand(0.95, 0.97) },
				// so that mid is smack in the middle of a real exponential range
			hi: { |ev| ev[\synthEvent][\freq].squared / ev[\lo]  },
			mid: { |ev| ev[\synthEvent][\freq] },
			center: { |ev| ev[\synthEvent][\pan] },
			threshold: { rrand(0.08, 0.16) },
			threshScale: { |ev| ev[\threshold].reciprocal },
			prob: 0.08
			// no ornaments for freq
		)
	);

	// this should be .next'ed explicitly -- put main synth event into event proto
	// caller knows what the outbus is, should pre-populate
	// control name in event too
	~trackGen = { Pbind(
		\instrument, BPStream(\trackInstr),
		\inpos, ~mousebus.asMap,
		\center, Pfunc { |ev| ~mapSpecs[ev[\controlName]][\center].value(ev) },
		\startFreq, BPStream(\startFreq),
		\decayTime, BPStream(\decayTime),
		\threshold, Pfunc { |ev| ~mapSpecs[ev[\controlName]][\threshold].value(ev) },
		\threshScale, Pfunc { |ev| ~mapSpecs[ev[\controlName]][\threshScale].value(ev) },
		\replyID, Pfunc { ~replyID }
	) };
	
	// populate outbus and control name here too
	~mapGen = { Pbind(
		\instrument, \mapParm,
		\bus, Pkey(\outbus),
		\lo, Pfunc { |ev| ~mapSpecs[ev[\controlName]][\lo].value(ev) },
		\mid, Pfunc { |ev| ~mapSpecs[ev[\controlName]][\mid].value(ev) },
		\hi, Pfunc { |ev| ~mapSpecs[ev[\controlName]][\hi].value(ev) },
		\grow, Pfunc { |ev| ~growForCurve.(ev[\lo], ev[\mid], ev[\hi]) }
	) };

	~prep = {
		~nodes = IdentitySet.new;
		~chan = MixerChannel(~collIndex, s, 2, 2, level: -24.dbamp, completionFunc: { |chan|
//			~mousesyn = { MouseY.kr(-1, 1) }.play(outbus: ~mousebus,
//				target: chan.fadergroup, addAction: \addToHead);

			// 300 cycles is not quite 1/2 second
			~activitySynth = Synth(\xyactivity, [busnum: ~mousebus, avgCycles: ~avgCycles, diffScale: ~diffScale], target: chan.fadergroup);
		});

		~synthdefs.();

		~replyID = UniqueID.next;
		
		~replyResp = OSCresponderNode(s.addr, ~replyName, e { |time, resp, msg|
			if(msg[2] == ~replyID) { ~trackStateChanged.(msg) };
		}).add;

		~carbuf = Buffer.alloc(s, 1024, 1, completionMessage: { |buf|
			buf.sine1Msg(Array.squareAmps(3))
		});
		~modbuf = Buffer.alloc(s, 1024, 1, completionMessage: { |buf|
			buf.sine1Msg(#[1, 0.5, 0.1]);
		});
		
		WrapInstr("osc2.fm2car", { arg freq, gate, car_env, mod_env, mod_lev, mod_ratio, detune, car_detune,
				car_buf, mod_buf, car_vs, mod_vs, basefreq, keyscale;
			var sig, mod, car_amp, mod_amp;
			car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
			mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
				* EnvGen.kr(mod_env, gate);
			mod_lev = mod_lev * basefreq / ((keyscale * freq) + (basefreq * (1 - keyscale)));
			mod = Osc.ar(mod_buf, freq.madd(mod_ratio * [1, car_detune], detune * [1, -1]), 0, mod_amp * mod_lev);
			freq = freq * [1, car_detune];
			sig = Mix(Osc.ar(car_buf, freq + (mod * freq), 0, car_amp))
				* EnvGen.kr(car_env, gate, doneAction:2)
		}, [\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0.01, 300, \exponential], [1, 12, \linear, 0, 1], [-5, 5, \linear, 0, 0], \mydetune, \mybuf, \mybuf, nil, nil, \freq, [0.001, 1.0, \exp]]);

		WrapInstr("osc2.fm2car_stereo", { |physicalPan = 0|
			var	sig = WrapInstr.wrap("osc2.fm2car");
			Pan2.ar(sig, physicalPan);
		}, [\bipolar]);

		~def = WrapPatch("osc2.fm2car_stereo", [nil, nil, nil, Env.adsr(0.8, 0.1, 0.7, 1.4), nil, nil, `3, `0.59, `1.0052, ~carbuf, ~modbuf, 0.6, 0, 272.2, 1]).asSynthDef.perform(Library.at(\ddwGlobal, \storeMethod));
		SynthDescLib.at(~def.name.asSymbol).msgFuncKeepGate = true;
		
		~initViz.();

		~mousebus ?? { ~mousebus = Bus.control(s, ~busKeys.size) };
		if(~mousebus.numChannels != ~busKeys.size) {
			~freeCleanup.();
			Error("Couldn't initialize BP(%). Supplied control bus % is the wrong size (should be %)."
				.format(~collIndex.asCompileString, ~mousebus, ~busKeys.size)).throw;
		};

		~busKeys.do { |key| key.envirPut(0) };
		~mousebus.setn(0 ! ~busKeys.size);
		
		~trackGen = ~trackGen.();
		~mapGen = ~mapGen.();
		~makeStreamForKey.(\trackGen);
		~makeStreamForKey.(\mapGen);

//// debug
//~traceResp = OSCresponderNode(s.addr, '/traceme', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;

		currentEnvironment
	};

	~freeCleanup = {
		[~chan, /*~mousebus,*/ ~fmbuf].free;
		~busrefresh.stop;
		~window.close;
		~replyResp.remove;
//~traceResp.remove;
	};
	
	~recvEventNotify = { |node, event|
			// some events/nodes might be received here that don't need to be tracked
		if(event[\argbus].notNil) {
			~nodes.add(event);
			event[\parmSynths] = ();
			~makeParmSynths.(event);
			~sendEventParms.(event, '/noteOn');
			defer(e {
				if(~window.isClosed.not) {
					~trackView.refresh;
				};
			});
		};
	};
	
	~nodeEndedNotify = { |node, event|
		~sendEventParms.(event, '/noteOff');
		event[\parmSynths].do(_.free);
		~nodes.remove(event);
		defer(e {
			if(~window.isClosed.not) {
				~trackView.refresh;
			};
		});
	};

	~makeParmSynths = { |event|
		var	trackEvent, mapEvent, inevent;
		event[\controlNames].do { |name, i|
			if((~mapSpecs[name].tryPerform(\at, \prob) ? 0).coin) {
				inevent = (
					type: \on,
					outbus: event[\argbus].index + i,
					controlName: name,
					group: event[\node],
					addAction: \addBefore,
					synthEvent: event
				);
				trackEvent = ~trackGenStream.next(inevent).put(\lag, 0.002).play;
				event[\parmSynths][name] = Synth.basicNew(trackEvent[\instrument], event[\server], trackEvent[\id][0]);
				mapEvent = ~mapGenStream.next(inevent)
					.put(\lag, 0.004)
					.put(\addAction, \addAfter)
					.put(\group, event[\parmSynths][name])
					.play;
				event[\parmSynths][(name ++ "_map").asSymbol] = Synth.basicNew(mapEvent[\instrument], event[\server], mapEvent[\id][0]);
				// if I don't clear these, I'll have an infinitely-recursive data structure, bad
				trackEvent[\synthEvent] = nil;
				mapEvent[\synthEvent] = nil;
				// used for notifications to vvvv
				event[\trackEvent] = trackEvent;
				event[\mapEvent] = mapEvent;
			};
		};
	};

	~trackStateChanged = { |msg|
		var	nodeEvent, psynth, cname, pat;
			// msg[3] == 0: state 0 means wobble was triggered
		if(msg[3] == 0 and: { ~ornamentProb.coin }) {
			nodeEvent = ~nodes.detect { |ev|
				ev[\parmSynths].detect({ |ps| (psynth = ps).asNodeID == msg[1] }).notNil
			};
//nodeEvent.debug("\n\nfound node for id");
			if(nodeEvent.notNil) {
				cname = nodeEvent[\parmSynths].findKeyForValue(psynth);
				~mapSpecs[cname][\ornamentStream] ?? { ~mapSpecs[cname][\ornamentStream] = ~mapSpecs[cname][\ornament].asStream };
				if((pat = ~mapSpecs[cname][\ornamentStream].next(nodeEvent)).notNil) {
					pat = ~mapSpecs[cname][\ornaments][pat].value(nodeEvent);
				} /*{
					pat = nil;
				}*/;
				pat !? { ~chan.play(pat, (clock: BP(~collIndex).clock)) };
			}
		}
	};

	~sendEventParms = { |event, cmdPath, argFunc(~sendParmArgs)|
		~vAddr !? {
			~vAddr.sendBundle(nil, [cmdPath] ++ argFunc.(event));
		};
	};

	// you may override this
	// return an array with info to send to vvvv
	~sendParmArgs = { |event|
		[event[\node].nodeID, ~collIndex, center: event[\pan]]
	};

	~asPattern = {
		~modeStream ?? { ~makeStreamForKey.(\mode) };
		Pseq([
			Plazy { |inEvent|
				Pbind(
					\protoEvent, \singleSynthAutoMap,
					\instrument, ~def.name.asSymbol,
					\chan, ~chan,
					\gate, 1,
					\mod_ratio, BPStream(\mod_ratio),
					\mod_lev, 1,
					\detune, BPStream(\detune),
					\degree, BPStream(\degree, resetSource: true),
//					\mode, BPStream(\mode),
					\mode, ~modeStream.next(inEvent),
					\freq, Pfunc { |ev| ev[\mode].asMode.cps(ev[\degree]) },
					\delta, BPStream(\delta),
					\sustain, Pkey(\delta) * BPStream(\legato),
					\pan, BPStream(\pan),
					\physicalPan, Pfunc { |ev| ~panXfer.(ev) }
				)
			},
				// rest
			Pbind(\protoEvent, \dummy, \delta, Pfin(1, BPStream(\restDelta)))
		], inf)
	};
	
	~stopCleanup = {
		var	desc;
			// not ideal but ok for testing
		~nodes.copy.do { |ev|
			if((desc = SynthDescLib.global.at(ev[\instrument].asSymbol)).notNil
			and: { desc.hasGate }) {
				ev.node.release;
			} {
				ev.node.free
			};
		};
	};
	
	~synthdefs = {
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

		SynthDef(\xyactivity, { |busnum, avgCycles = 100|
			var	in = In.kr(busnum, 2),
				x = in[0], y = in[1],
				xdiff = HPZ1.kr(x),
				ydiff = HPZ1.kr(y),
				xmean = RunningSum.kr(xdiff, avgCycles),
				ymean = RunningSum.kr(ydiff, avgCycles),
				arctan = (ymean.neg / xmean).atan,
				piplus = pi + arctan,
				theta = Select.kr(xmean < 0, [arctan, piplus]),
				xact = RunningSum.kr(xdiff.abs, avgCycles) / avgCycles,
				yact = RunningSum.kr(ydiff.abs, avgCycles) / avgCycles,
				radius = (xact.squared + yact.squared).sqrt;
			ReplaceOut.kr(busnum+2, [xact, yact, theta, radius]);
		}).perform(Library.at(\ddwGlobal, \storeMethod));
	};

	~growForCurve = { |minval, midval, maxval|
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
	//		log(qresult.squared).abs * sgn
			qresult.squared * sgn
		}, {
			((b.neg - sqrterm) / (2 * a)).squared * sgn
		});
	};

	~initViz = {
		~vizspec = \bipolar.asSpec;
		~lineColor = Color.blue;
		~stripeColor = Color.blue(alpha: 0.05);
		~mouseColor = Color.red;
		~mouseColor2 = Color.red(alpha: 0.2);
		~winsize = min(800, Window.screenBounds.height - 50);
		~window = Window("mouse", Rect.aboutPoint(Window.screenBounds.center, ~winsize/2, ~winsize/2))
			.acceptsMouseOver_(true)
			.onClose_(e {
				fork {
					BP(~collIndex).stopNow;
					while { ~nodes.isEmpty.not } { 1.0.wait };
					BP(~collIndex).free;
				}
			});
		~trackView = UserView(~window, Rect(0, 0, ~winsize, ~winsize))
			.background_(Color.new255(255, 255, 180, 255 * 0.5))
			.drawFunc_(e { |view|
				var	x, dx, y, radius;
					// 0.1 = half threshold
				dx = 0.1 * ~winsize;
				Pen	.fillColor_(~stripeColor)
					.strokeColor_(~lineColor);
				~nodes.do { |ev|
					x = ~vizspec.unmap(ev.pan) * ~winsize;
					Pen	.fillRect(Rect(x - dx, 0, dx*2, ~winsize))
						.moveTo((x @ 0))
						.lineTo((x @ ~winsize))
						.stroke;
				};
				x = ~vizspec.unmap(~mousex) * ~winsize;
				y = ~vizspec.unmap(~mousey) * ~winsize;
				radius = ((~radius + 0.25).log + 1.388) * ~winsize * ~diffScale;
				dx = radius * 0.5;
				Pen	.fillColor_(~mouseColor2)
					.fillOval(Rect(x - dx, y - dx, radius, radius))
					.strokeColor_(~mouseColor)
					.moveTo(x @ y)
					.lineTo(Point(x + (dx * cos(~theta)), y - (dx * sin(~theta))))
					.stroke;
			})
			.clearOnRefresh_(true)
			.mouseOverAction_(
				if(topEnvironment[\useMouse] ? false) {
					e { |view, x, y|
						~mousebus.setn([(x / ~winsize) * 2 - 1, (y / ~winsize) * 2 - 1]);
					}
				}
			);
		~window.front.refresh;
		~busrefresh = Routine {
			loop {
				~mousebus.getn(~mousebus.numChannels, e { |val|
					~busKeys.do { |key, i|
						// if there's no movement, theta is NaN;
						// keep the old value in the Proto var
						if(val[i].isNaN.not) { key.envirPut(val[i]) };
					};
					defer(e { if(~trackView.notClosed) { ~trackView.refresh } });
				});
				0.1.wait;
			}
		}.play(AppClock);
	};
} => PR(\perturbTest);

s.waitForBoot {
	if(~bus.notNil and: { ~bus.numChannels != PR(\perturbTest).busKeys.size }) {
		~bus.free;
		~bus = nil;
	};

	if(~bus.isNil) {
		if(s.controlBusAllocator.reserve(0, PR(\perturbTest).busKeys.size, warn: false).notNil) {
			~bus = Bus(\control, 0, PR(\perturbTest).busKeys.size, s);
		} {
			"Couldn't allocate data bus at index 0. Please quit and reboot the server.".die;
		};
	};

	if(Mode.exists(\Eb).not) {
		#[eb, 3, f, 5, g, 7, bb, 10].pairsDo { |key, root|
			Mode(\default).v.copy.root_(root).transposeRoot(0) => Mode(key);
		};
	};

	BP(\pt).free;
	PR(\perturbTest).chuck(BP(\pt), nil, (
		mousebus: ~bus,
		diffScale: 10,
		mode: Pindex(
			Pfunc { ~modes },
			Pwhite(0, Pfunc { ~modes.size - 1 }, inf).reject { |i|
				var	sameAsLast = (~modes.size > 1) and: { i == ~lastModeIndex };
				~lastModeIndex = i;
				sameAsLast
			}
		),
		modes: #[default, eb, f, g, bb]
	));
	BP(\pt).quant = DelayTimeSpec(2);
	
	BP(\pt).play;
};
)
