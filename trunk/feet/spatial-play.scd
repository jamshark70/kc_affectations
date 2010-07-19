// rudimentary, kind of dumb spatialization tests

Library.put(\chucklib, \midiSearches, #["remote"]); BP.loadGui;
//s.waitForBoot(e { (Document.current.path.dirname +/+ "head-defs.scd").debug("loading").loadPath });

(
~master ?? { ~master = MixerChannel(\master, s, 2, 2, level: 1) };
//~rvbmc => MCG(6);
~master => MCG(7);
MixingBoard.at(0).refresh;
)

~glrvb.free;

FxPatch(
	[ 'busfx', 'freeverb2' ], [ 18, KrNumberEditor(1.0, ControlSpec(0, 1, 'linear', 0, 0.5, "")), KrNumberEditor(0.54166668653488, ControlSpec(0.0, 1.0, 'linear', 0.0, 0.0, "")), KrNumberEditor(0.5, ControlSpec(0.0, 1.0, 'linear', 0.0, 0.0, "")), KrNumberEditor(1.0, ControlSpec(0, 1, 'amp', 0, 0, "")) ]
)
FxPatch(
	[ 'busfx', 'rvb_allpass2' ], [ 20, 2, KrNumberEditor(0.25, ControlSpec(0.25, 2, 'linear', 0.0, 0.25, "")), KrNumberEditor(0.014025612063518, ControlSpec(0.001, 1.5, 'exp', 0, 0.05, "")), KrNumberEditor(0.17782792880092, ControlSpec(0.01, 10, 'exp', 0, 0.25, "")), 4, KrNumberEditor(0.019573417367152, NoLagControlSpec(0.001, 1, 'exp', 0, 0.03, "")) ]
)

#[glrvbmc, glrvb, lcrvbmc, lcrvb].do(_.envirPut(nil));

(
if(Window.screenBounds.height > 600) {
	// global reverb
	~glrvbmc ?? {
		~glrvbmc = MixerChannel(\rvb, s, 2, 2, level: 1, outbus: ~master);
	};

	~glrvbmc.doWhenReady {
		if(~glrvb.isNil or: { ~glrvb.isPlaying.not }) {
			~glrvb = ~glrvbmc.playfx(Instr("busfx.freeverb2"), #[0] ++
				[#[1.0, 0.75, 0.5, 1.0], Instr("busfx.freeverb2").specs[1..]].flop
				.collect { |val_spec| KrNumberEditor(*val_spec) }
			);
		};
	};

	// local reverb should be more stereo-separated
	~lcrvbmc ?? {
		~lcrvbmc = MixerChannel(\rvb, s, 2, 2, level: 1, outbus: ~master);
	};

	~lcrvbmc.doWhenReady {
		if(~lcrvb.isNil or: { ~lcrvb.isPlaying.not }) {
			~lcrvb = ~lcrvbmc.playfx(Instr("busfx.rvb_allpass2"), [0, 2, nil, nil, nil, 4, nil]);
		};
	};
};
)

~glrvbmc => MCG(5);
~lcrvbmc => MCG(6);

m = MixerChannel(\test1, s, 1, 2, outbus: ~master);
n = MixerChannel(\test2, s, 2, 2, outbus: ~master);
m => MCG(0); n => MCG(1);

[m, n].do { |ch|
	ch.sendsSignalTo(~glrvbmc);
	ch.sendsSignalTo(~lcrvbmc);
};


Instr("busfx.rvb_allpass2").listArgs

(
topEnvironment[\feetdir] ?? {
	topEnvironment[\feetdir] = thisProcess.nowExecutingPath
		?? { Document.current.tryPerform(\path) };
	if(topEnvironment[\feetdir].notNil) {
		topEnvironment[\feetdir] = topEnvironment[\feetdir].dirname;
	} {
		switch(thisProcess.platform.name)
			{ \osx } {
				topEnvironment[\feetdir] = "~/SCServer/trax/kc.git/trunk/feet".standardizePath;
			}
			{ \linux } {
				topEnvironment[\feetdir] = "~/share/SuperCollider/scd/kc.git/trunk/feet".standardizePath;
			};
	};
};
)

b.free;
b = Buffer.readAndQuery(s, topEnvironment[\feetdir].dirname +/+ "samples/feet/58454_sinatra314_footsteps_wooden_floor_loop.wav");

~pt = TabFileReader.read(b.path.dirname +/+ "58454_labels.txt");
~pt = ~pt.flop[0].asFloat;
~ptd = ~pt.differentiate.drop(1);
~mean = ~ptd.mean;


// s.queryAllBuffers(action: (_.postln));
// s.bufferAllocator.free(0)


SynthDef(\bufGrainPanRvb, { |start, time, bufnum, pan, rate = 1, amp = 1,
		attack = 0.001, decay = 0.02, outbus,
		attfreq = 15000, attdb = 0, attrs = 1,
		glrvbout = 0, glrvbamt = 0,
		lcrvbout = 0, lcrvbamt = 0|
	var sig;
	sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
		* EnvGen.kr(Env.linen(attack, time, decay), doneAction:2);
	sig = Pan2.ar(sig, pan, amp);
	Out.ar(outbus, sig);
	sig = BHiShelf.ar(sig, attfreq, attrs, attdb.neg);
	Out.ar(glrvbout, sig * glrvbamt);
	Out.ar(lcrvbout, sig * lcrvbamt);
}).add;


f = { |i = 0, dist = 1, amp = 4, rvbamp = 1|
	n.play(\bufGrainPanRvb, [start: (~pt[i] - 0.1) * 44100, time: 0.25, decay: 0.3, pan: ~pan ? 0,
		amp: amp / dist,
		glrvbout: ~glrvbmc.inbus, glrvbamt: amp * rvbamp / dist.sqrt,
		lcrvbout: ~lcrvbmc.inbus, lcrvbamt: amp * rvbamp * (1 - dist.sqrt.reciprocal),
		attfreq: ~attfreq ? 15000, attdb: ~attdb ? 0, attrs: ~attrs ? 1
	]);
};

f.(6, 1, 10, 0.05);
f.(6, 3, 10, 0.05);

w = Window("where", Rect(800, 50, 400, 400));
t = StaticText(w, Rect(0, 0, 10, 10)).background_(Color.blue);
w.front;

Pdefn(\amp, 30);
Pdefn(\rvbamp, 0.042);
Pdefn(\dnear, 5);
Pdefn(\dfar, 14);
Pdefn(\i, 6);
Pdefn(\attfreq, 4000);
Pdefn(\attdb, Pkey(\dist).linexp(Pkey(\near), Pkey(\far), 18, 32));
Pdefn(\attrs, Pkey(\dist).linlin(Pkey(\near), Pkey(\far), 1, 3));

SynthDescLib.at(\bufGrainPanRvb)

(
p = Pbind(
	\near, Pdefn(\dnear),
	\far, Pdefn(\dfar),
	\dist, (Ptime() * (2pi/11) - 0.5pi).sin.linlin(-1, 1, Pkey(\near), Pkey(\far)),
	\pt, ~pt,
	\glrvbmc, ~glrvbmc,
	\lcrvbmc, ~lcrvbmc,
	\amp, Pdefn(\amp),
	\rvbamp, Pdefn(\rvbamp),
	\i, Pdefn(\i),
	\attfreq, Pdefn(\attfreq),
	\attdb, Pdefn(\attdb),
	\attrs, Pdefn(\attrs),
	\play, {
		s.makeBundle(s.latency, { f.(~i, ~dist, ~amp, ~rvbamp) });
		defer(e {
			t.bounds_(t.bounds.moveTo(~pan.linlin(-1, 1, 0, 390), ~dist.linlin(~near, ~far, 390, 0)));
		}, s.latency)
	},
	\pan, (Ptime() * 2pi/18).sin,
	\delta, Pexprand(0.2, 0.3, inf)
).play;
)

p.stop;

FxPatch(
	[ 'busfx', 'rvb_allpass2' ], [ 20, 2, 0.25, 0.015525093419474, 0.82540422302882, 4, 0.04 ]
)

~glrvb.gui;
~lcrvb.gui;

~lcrvb.synth.trace;

PeakMonitor(~glrvbmc);
PeakMonitor(~lcrvbmc);

PeakMonitor(~master);

o.remove;
z = SynthDescLib.at(\bufGrainPanRvb).controlNames;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m|
	r.remove;
	Post << Char.nl;
	Synth.basicNew(\dummy, s, m[1]).getn(0, z.size, { |val| [z, val].flop.do(_.postln) });
}).add;

o = OSCresponderNode(s.addr, '/n_go', { |t, r, m|
	r.remove;
	Synth.basicNew(\dummy, s, m[1]).trace
}).add;


Instr("busfx.freeverb2").listArgs

// front
[ start, 192175.28125 ]
[ time, 0.25 ]
[ bufnum, 0 ]
[ pan, -0.65357011556625 ]
[ rate, 1 ]
[ amp, 5.9985508918762 ]
[ attack, 0.0010000000474975 ]
[ decay, 0.019999999552965 ]
[ outbus, 24 ]
[ glrvbout, 18 ]
[ glrvbamt, 0.67073935270309 ]
[ lcrvbout, 20 ]
[ lcrvbamt, 0.82926064729691 ]


// back
[ start, 192175.28125 ]
[ time, 0.25 ]
[ bufnum, 0 ]
[ pan, -0.12453178316355 ]
[ rate, 1 ]
[ amp, 2.145133972168 ]
[ attack, 0.0010000000474975 ]
[ decay, 0.019999999552965 ]
[ outbus, 24 ]
[ glrvbout, 18 ]
[ glrvbamt, 0.40110477805138 ]
[ lcrvbout, 20 ]
[ lcrvbamt, 1.0988951921463 ]



~fn = { |start, time, bufnum, pan, rate = 1, amp = 1,
		attack = 0.001, decay = 0.02, outbus|
	var sig;
	sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0)
		* EnvGen.kr(Env.linen(attack, time, decay), doneAction:2);
	sig = Pan2.ar(sig, pan, amp);
//	Out.ar(outbus, sig);
};

#[\Out, \XOut].any { |cl| unit.isKindOf(cl.asClass) }

SynthDef(\not, {
	var result = SynthDef.wrap(~fn), pan;
	pan = block { |break|
		UGen.buildSynthDef.children.do { |unit|
			if(unit.isKindOf(Control)) {
				unit.channels.do { |out|
					if(out.name == \pan) { break.(out) }
				}
			}
		}
	};
	pan.dump
/*	if(result.rate != \audio) {
		UGen.buildSynthDef.children
		.select { |unit| unit.writesToBus }
		.postln.do { |unit|
			var uinsize = unit.inputs.size;
			unit.inputs[uinsize - unit.numAudioChannels..].debug("% signal".format(unit.class.name));
		};
	} {
		result.debug("signal");
	};
*/
});

SynthDescLib.at(\bufGrainPan).def.inspect
.func.postcs

(
{ |name, ugenFunc, metadata, rates|
	var	findCtl = { |cname|
		block { |break|
			UGen.buildSynthDef.children.do { |unit|
				if(unit.isKindOf(Control)) {
					unit.channels.do { |out|
						if(out.name == cname) { break.(out) }
					}
				}
			}
		}
	};
	SynthDef(name, { |dist = 5, near = 5, far = 14,
		glrvbout, lcrvbout, glrvbamt = 0.045, lcrvbamt = -1,
		attfreq = 15000, attdb = 0, attrs = 1|
		var result = SynthDef.wrap(ugenFunc), out, pan, outctl;
		// don't add a new \pan control if the function already made one
		if((pan = findCtl.(\pan)).isNil) {
			"make pan namedcontrol".debug;
			pan = NamedControl(\pan, 0);
		};
		if((outctl = findCtl.(\outbus)).debug("find outbus").isNil and: { (outctl = findCtl.(\out)).debug("find out").isNil }) {
			"make out namedcontrol".debug;
			outctl = NamedControl(\out, 0);
		};
		if(result.rate.debug("result rate") != \audio) {
			// not audio rate, look for Out unit
			// (Out.ar returns 0.0, which is scalar)
			out = UGen.buildSynthDef.children.detect(_.writesToBus);
			if(out.notNil) {
				"found Out.ar".debug;
				result = out.inputs[out.inputs.size - out.numAudioChannels .. ];
				UGen.buildSynthDef.children.remove(out);
			} {
				Error("Result of UGen func is not audio rate and has no Out unit").throw;
			};
		};

		dist = dist.clip(near, far);
		result = result * near;
		Out.ar(outctl, result / dist);

		lcrvbamt = Select.kr(lcrvbamt < 0, [lcrvbamt, glrvbamt]);
		result = BHiShelf.ar(result, attfreq, attrs, attdb.neg);
		Out.ar(glrvbout, result * glrvbamt / dist.sqrt);
		Out.ar(lcrvbout, result * lcrvbamt * (1 - dist.sqrt.reciprocal));
	}, rates, metadata: metadata);
} => Func(\addRvbOut);
)

Func(\addRvbOut).listArgs
d = \addRvbOut.eval(\test, SynthDescLib.at(\bufGrainPan).def.func);
d.inspect

d.add;
d.allControlNames.do(_.postln); ""


Pdefn(\amp, 5);
Pdefn(\rvbamp, 0.042);
Pdefn(\dnear, 5);
Pdefn(\dfar, 30);
Pdefn(\i, 6);
Pdefn(\attfreq, 4000);
Pdefn(\attdb, Pkey(\dist).linexp(Pkey(\near), Pkey(\far), 18, 32));
Pdefn(\attrs, Pkey(\dist).linlin(Pkey(\near), Pkey(\far), 1, 3));

(
p = n.play(Pbind(
	\instrument, \test,
	\near, Pdefn(\dnear),
	\far, Pdefn(\dfar),
	\dist, (Ptime() * (2pi/11) - 0.5pi).sin.linlin(-1, 1, Pkey(\near), Pkey(\far)),
	\i, Pdefn(\i),
// 	\pt, ~pt,
	\start, Pindex(~pt, Pkey(\i), inf) * 44100 - 0.15,
	\time, 0.25,
	\decay, 0.5,
	\attack, 0.05,
	\bufnum, b,
	\glrvbout, ~glrvbmc.inbus,
	\lcrvbout, ~lcrvbmc.inbus,
	\amp, Pdefn(\amp),
	\glrvbamt, Pdefn(\rvbamp),
	\attfreq, Pdefn(\attfreq),
	\attdb, Pdefn(\attdb),
	\attrs, Pdefn(\attrs),
	\pan, (Ptime() * 2pi/18).sin,
	\delta, Pexprand(0.2, 0.3, inf)
).collect { |ev|
	defer({
		t.bounds_(t.bounds.moveTo(~pan.linlin(-1, 1, 0, 390), ~dist.linlin(~near, ~far, 390, 0)));
	}.inEnvir(ev), s.latency);
	ev
});
)

p.stop;




MixerChannel(test1, localhost, 1, 2)
 Synthgroup: Group(15)
Effectgroup: Group(16)
Fader synth: Synth("mixers/Mxb1x2" : 17)
Destination: MixerChannel(master, localhost, 2, 2)
          level: 0.75 (-2.499 dB)
            pan: 0


MixerChannel(test2, localhost, 2, 2)
 Synthgroup: Group(19)
Effectgroup: Group(20)
Fader synth: Synth("mixers/Mxb2x2" : 21)
Destination: MixerChannel(master, localhost, 2, 2)
          level: 0.75 (-2.499 dB)
            pan: 0


MixerChannel(rvb, localhost, 2, 2)
 Synthgroup: Group(7)
Effectgroup: Group(8)
Fader synth: Synth("mixers/Mxb2x2" : 9)
Destination: MixerChannel(master, localhost, 2, 2)
          level: 0.632 (-3.979 dB)
            pan: 0


MixerChannel(rvb, localhost, 2, 2)
 Synthgroup: Group(11)
Effectgroup: Group(12)
Fader synth: Synth("mixers/Mxb2x2" : 13)
Destination: MixerChannel(master, localhost, 2, 2)
          level: 0.34 (-9.383 dB)
            pan: 0


MixerChannel(master, localhost, 2, 2)
 Synthgroup: Group(3)
Effectgroup: Group(4)
Fader synth: Synth("mixers/Mxb2x2" : 5)
Destination: Output 0 -> Bus(audio, 0, 2, localhost)
          level: 1 (0 dB)
            pan: 0

