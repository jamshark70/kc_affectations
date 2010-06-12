// provided for troubleshooting only, please don't steal!
// H. James Harkins

// run these 2 lines before the () bit
// you can do this once at the start of the session
// no need to repeat for every run

s.boot;
s.controlBusAllocator.reserve(0, 1);
~bus = Bus(\control, 0, 1, s);

~useMouse = false;	// change this to true to debug with mouse

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
	
	~mod_ratio = 2;
	~detune = 1.4;
	~degree = Pwhite(-7, 7, inf) + 35;
	~delta = Pexprand(1.0, 4.0, inf);
	~legato = Pwhite(4.0, 10.0, inf);
	~pan = Pwhite(-0.8, 0.8, inf);

	~trackInstr = \snapback;
	~startFreq = Pwhite(4.0, 9.0, inf);
	~decayTime = Pwhite(2.5, 10.0, inf);
	~ornamentProb = 0.06;
	
	~replyName = '/snapbackState';

	// lo/hi/mid/center may be functions, passed the event being processed
	~mapSpecs = (
		mod_lev: (
			lo: 0.2,
			hi: { rrand(15.0, 30.0) },
			mid: 1.0,
			center: { |ev| ev[\synthEvent][\pan] },
			threshold: 0.2,
			threshScale: 4.9,
			prob: 0.75,
			ornament: \arpeg, // can be pattern also
			ornaments: (
				arpeg: { |nodeEvent| Pbind(
					\instrument, ~def.name.asSymbol,
					// nodeEvent[\degree]: 35 = mid c; -21 = start 8va higher
					\degree, Paccumbounce(-7, 14, Pwrand(#[-1, 1, 2], #[0.1, 0.45, 0.45], inf), rrand(6, 11), nodeEvent[\degree] - 35),
					\dur, rrand(0.1, 0.2),
					\mod_lev, Pexprand(1.0, 5.0, inf),
					\sustain, 2.5,
					\gate, 0.5, \amp, 1
				) }
			)
		),
		freq: (
			lo: { |ev| ev[\synthEvent][\freq] * rrand(0.7, 0.94) },
			hi: { |ev| ev[\synthEvent][\freq] * rrand(1.07, 1.7) },
			mid: { |ev| ev[\synthEvent][\freq] },
			center: { |ev| ev[\synthEvent][\pan] },
			threshold: { rrand(0.08, 0.16) },
			threshScale: { |ev| ev[\threshold].reciprocal },
			prob: 0.36
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
		});

		~synthdefs.();

		~replyID = UniqueID.next;
		
		~replyResp = OSCresponderNode(s.addr, ~replyName, e { |time, resp, msg|
			if(msg[2] == ~replyID) { ~trackStateChanged.(msg) };
		}).add;

		~fmbuf = Buffer.alloc(s, 1024, 1, completionMessage: { |buf|
			buf.sine1Msg(#[1])
		});

		WrapInstr("osc2.fm1stereo", { |pan = 0/*, freq, gate, car_env, mod_env, mod_lev, mod_ratio, detune, car_buf, mod_buf, car_vs, mod_vs*/|
			var	sig = WrapInstr.wrap("osc2.fm1");
			Pan2.ar(sig, pan);
		}, [\bipolar]);
		~def = WrapPatch("osc2.fm1stereo", [nil, nil, nil, Env.adsr(0.8, 0.1, 0.7, 1.4), nil, nil, nil, nil, ~fmbuf, ~fmbuf]).asSynthDef.perform(Library.at(\ddwGlobal, \storeMethod));
		SynthDescLib.at(~def.name.asSymbol).msgFuncKeepGate = true;
		
		~initViz.();

		~mousebus = Bus.control(s, 1);
		
		~trackGen = ~trackGen.();
		~mapGen = ~mapGen.();
		~makeStreamForKey.(\trackGen);
		~makeStreamForKey.(\mapGen);

//// debug
//~traceResp = OSCresponderNode(s.addr, '/traceme', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;

		currentEnvironment
	};

	~freeCleanup = {
		[~chan, ~mousebus, ~fmbuf].free;
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
			defer(e {
				if(~window.isClosed.not) {
					~trackView.refresh;
				};
			});
		};
	};
	
	~nodeEndedNotify = { |node, event|
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
				trackEvent = ~trackGenStream.next(inevent).put(\lag, 0.0125).play;
				event[\parmSynths][name] = Synth.basicNew(trackEvent[\instrument], event[\server], trackEvent[\id][0]);
				mapEvent = ~mapGenStream.next(inevent)
					.put(\lag, 0.025)
					.put(\addAction, \addAfter)
					.put(\group, event[\parmSynths][name])
					.play;
				event[\parmSynths][(name ++ "_map").asSymbol] = Synth.basicNew(mapEvent[\instrument], event[\server], mapEvent[\id][0]);
				
//				trackEvent[\synthEvent] = nil;
//				mapEvent[\synthEvent] = nil;
//				trackEvent.debug("\ntrackEvent");
//				mapEvent.debug("\nmapEvent");
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

	~asPattern = {
//		Pfin(1,
		Pbind(
			\protoEvent, \singleSynthAutoMap,
			\instrument, ~def.name.asSymbol,
			\chan, ~chan,
			\gate, 1,
			\mod_ratio, BPStream(\mod_ratio),
			\mod_lev, 1,
			\detune, BPStream(\detune),
			\degree, BPStream(\degree),
			\freq, Pkey(\degree).degreeToKey(#[0, 2, 4, 5, 7, 9, 11],
				12).midicps * Pexprand(1.004.reciprocal, 1.004, inf),
			\delta, BPStream(\delta),
			\sustain, Pkey(\delta) * BPStream(\legato),
			\pan, BPStream(\pan)
		)
//		).collect { |ev| ev.put(\sustain, nil).put(\delta, 1000) };
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
//b.poll(Impulse.kr(5), "mapped");
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
				var	x, dx;
					// 0.1 = half threshold
				dx = 0.1 * ~winsize;
				Pen	.fillColor_(~stripeColor)
					.strokeColor_(~lineColor);
				~nodes.do { |ev|
					x = ~vizspec.unmap(ev.pan) * ~winsize;
					Pen	.fillRect(Rect(x - dx, 0, dx*2, ~winsize))
						.moveTo(x @ 0)
						.lineTo(x @ ~winsize)
						.stroke;
				};
				x = ~vizspec.unmap(~mousex) * ~winsize;
				Pen	.strokeColor_(~mouseColor)
					.moveTo(x @ 0)
					.lineTo(x @ ~winsize);
				Pen.stroke;
			})
			.clearOnRefresh_(true)
			.mouseOverAction_(e { |view, x, y|
				~mousebus.set((x / ~winsize) * 2 - 1);
			});
		~window.front.refresh;
	};
} => PR(\perturbTest);

PR(\perturbTest) => BP(\pt);
BP(\pt).quant = DelayTimeSpec(2);

BP(\pt).play;
)

MixingBoard(mixers: BP(\pt).chan);
TempoClock.default.queue.size

s.freeAll;



BP(\pt).chan.play(Pbind(
	\instrument, BP(\pt).def.name.asSymbol,
	\degree, Paccumbounce(-7, 21, Pwrand(#[-1, 1, 2], #[0.2, 0.5, 0.3], inf), { rrand(6, 11) }).postcs,
	\dur, rrand(0.1, 0.2),
	\sustain, 1,
	\gate, 1, \amp, 1
).trace)

s.queryAllNodes;
s.sendMsg(\n_free, 1131)
(1226..1231).do(s.sendMsg(\n_free, _));

( 'instrument': \Cczyy, 'degree': 1, 'dur': 0.12176060676575, 'gate': 1, 'sustain': 1, 'amp': 1 ).play

s.sendMsg(\n_trace, 1132)
s.sendMsg(\n_free, 1132)

SynthDescLib.at(\Cczyy).hasGate
SynthDescLib.at(\Cczyy).msgFuncKeepGate = true;
SynthDescLib.at(\Cczyy).msgFunc.postcs

( 'instrument': \Cczyy, 'degree': 1, 'dur': 0.12176060676575, 'gate': 1, 'sustain': 4, 'amp': 1 ).asOSC

MixingBoard(\x, nil, BP(\pt).chan);

BP(\pt).mapSpecs[\freq].prob = 0.1;

WrapInstr("osc2.fm1").openFile