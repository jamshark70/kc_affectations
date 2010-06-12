// run these 2 lines before the () bit
// you can do this once at the start of the session
// no need to repeat for every run

s.boot;
s.controlBusAllocator.reserve(0, 1);
~bus = Bus(\control, 0, 1, s);

(
BP(\pt).free;

WrapInstr([\osc2, \fm1], { arg freq, gate, car_env, mod_env, mod_lev, mod_ratio, detune,
        car_buf, mod_buf, car_vs, mod_vs;
    var sig, mod, car_amp, mod_amp;
    car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
    mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
        * EnvGen.kr(mod_env, gate);
    mod = Osc.ar(mod_buf, freq * mod_ratio + detune, 0, mod_amp * mod_lev);
    sig = Osc.ar(car_buf, freq + (mod * freq), 0, car_amp)
        * EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0.01, 300, \exponential], [0.25, 20, \linear, 0.1, 1], [-5, 5, \linear, 0, 0], \mybuf, \mybuf, nil, nil]);

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
	
	~prep = {
		~nodes = IdentitySet.new;
		~chan = MixerChannel(~collIndex, s, 2, 2, level: -24.dbamp, completionFunc: { |chan|
//			~mousebus = Bus.control(s, 1);
			~mousebus = topEnvironment[\bus];
//			~mousesyn = { MouseY.kr(-1, 1) }.play(outbus: ~mousebus,
//				target: chan.fadergroup, addAction: \addToHead);
		});

		~synthdefs.();

		~fmbuf = Buffer.alloc(s, 1024, 1, completionMessage: { |buf|
			buf.sine1Msg(#[1])
		});

		WrapInstr("osc2.fm1stereo", { |pan = 0/*, freq, gate, car_env, mod_env, mod_lev, mod_ratio, detune, car_buf, mod_buf, car_vs, mod_vs*/|
			var	sig = WrapInstr.wrap("osc2.fm1");
			Pan2.ar(sig, pan);
		}, [\bipolar]);
		~def = WrapPatch("osc2.fm1stereo", [nil, nil, nil, Env.adsr(0.8, 0.1, 0.7, 1.4), nil, nil, nil, nil, ~fmbuf, ~fmbuf]).asSynthDef.perform(Library.at(\ddwGlobal, \storeMethod));
		
		~initViz.();
	};

	~initViz = {
		~mousex = 0;
		~vizspec = \bipolar.asSpec;
		~lineColor = Color.blue;
		~stripeColor = Color.blue(alpha: 0.05);
		~mouseColor = Color.red;
		~winsize = min(800, Window.screenBounds.height - 50);
		~window = Window("mouse", Rect.aboutPoint(Window.screenBounds.center, ~winsize/2, ~winsize/2))
			.acceptsMouseOver_(true)
			.onClose_(e {
				fork {
					~busrefresh.stop;
					BP(~collIndex).stopNow;
					2.0.wait;
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
 			})
		;
		~window.front.refresh;
		~busrefresh = Routine {
			loop {
				~mousebus.get(e { |val|
					~mousex = val;
					defer(e { if(~trackView.notClosed) { ~trackView.refresh } });
				});
				0.1.wait;
			}
		}.play(AppClock);
	};

	~freeCleanup = {
		[~chan, /*~mousebus,*/ ~fmbuf].free;
		~busrefresh.stop;
		~window.close;
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
		var	hi;
		event.controlNames.do { |name, i|
//			if(~parmRejectKeys.includes(name).not) {
//				// busnum is event.argbus.index + i
//			};
			if(name.asSymbol == \mod_lev) {
				event[\parmSynths][\mod_lev] = Synth(\snapback, [
					inpos: ~mousebus.asMap, outbus: event.argbus.index + i,
					center: event[\pan], // rrand(-0.8, 0.8),
					startFreq: rrand(4.0, 6.0), endFreq: 1,
					decayTime: rrand(1.5, 3.5),
					threshold: 0.2, threshScale: 5
				]);
				event[\parmSynths][\mod_lev_map] = Synth(\mapParm, [
					bus: event.argbus.index + i,
					lo: 0.2,
					hi: hi = rrand(15.0, 30.0),
					grow: ~growForCurve.(0.2, 1.0, hi)
				], target: event[\parmSynths][\mod_lev], addAction: \addAfter);
//				{ event[\parmSynths][\mod_lev].trace }.defer(0.1);
			};
		};
	};

	~asPattern = {
//		Pseq([
//			Pfin(1,
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
						12).midicps,
					\delta, BPStream(\delta),
					\sustain, Pkey(\delta) * BPStream(\legato),
					\pan, BPStream(\pan)
				)
//			),
//			Event.silent(30)
//		], 1)

/*		Pseq([
				// init main synth and its parms
			Pfuncn {
				var	event;
					// this should call back with an argbus-bearing event
				~event.copy.putAll(
					(protoEvent: \singleSynthAutoMap, instrument: \default,
						freq: 440, amp: 0.6, delta: 0, sustain: nil,
						collIndex: ~collIndex, chan: ~chan)
				).yield;
				// make parm synths
				event = ~nodes.detect(true);	// only one, get it
				~makeParmSynths.(event);
				0
			},
			// singleSynthTriggers to disturb parms randomly
			Pbind(
				\protoEvent, \singleSynthTrigger,
				\node, Pfunc { ~nodes.detect(true).parmSynths[\freq] },
				\trig, Pexprand(0.4, 1.8, inf),
				\delta, Pwhite(1, 6, inf) * 0.25
			)
		], 1)
*/
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
} => PR(\perturbTest);

PR(\perturbTest) => BP(\pt);
BP(\pt).quant = DelayTimeSpec(2);

BP(\pt).play;
)

s.makeGui;

BP(\pt).mousex

Help.gui

BP(\pt).mouseColor