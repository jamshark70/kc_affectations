// todo:
// Ptpar is going in the right direction
// start dense, thin out, transition from stretching to normal rate
// then do running across the floor

Library.put(\chucklib, \midiSearches, #["remote"]); BP.loadGui;
#[glrvbmc, glrvb, lcrvbmc, lcrvb, master].do({ |obj| obj.envirGet.free; obj.envirPut(nil) });
s.waitForBoot(e { (Document.current.path.dirname +/+ "feet-defs.scd").debug("loading").loadPath });

(
~glrvbmc => MCG(5);
~lcrvbmc => MCG(6);
~master => MCG(7);

m = MixerChannel(\test1, s, 1, 2, outbus: ~master);
n = MixerChannel(\test2, s, 2, 2, outbus: ~master);
m => MCG(0); n => MCG(1);

[m, n].do { |ch|
	ch.sendsSignalTo(~glrvbmc);
	ch.sendsSignalTo(~lcrvbmc);
};
)


[~glrvb, ~lcrvb].do(_.run(false));
[~glrvb, ~lcrvb].do(_.run(true));

PeakMonitor(~master)

b.free;
b = Buffer.readAndQuery(s, topEnvironment[\feetdir].dirname +/+ "samples/feet/58454_sinatra314_footsteps_wooden_floor_loop.wav");

~pt = TabFileReader.read(b.path.dirname +/+ "58454_labels.txt");
~pt = ~pt.flop[0].asFloat;
~ptd = ~pt.differentiate.drop(1);
~mean = ~ptd.mean;

c.free;
c = Buffer.readAndQuery(s, b.path.splitext[0] ++ "-pv512.aiff");
f = 512;
c = Buffer.alloc(s, b.duration.calcPVRecSize(f, 0.25));

a = {
	var	sig = PlayBuf.ar(1, b, BufRateScale.kr(b), 1, 0, 0),
		fft = FFT(LocalBuf(f, 1), sig, 0.25, 1),
		stop = Line.kr(0, 1, b.duration, doneAction: 2);
	PV_RecordBuf(fft, c, run: 1, hop: 0.25, wintype: 1);
	stop.poll(Done.kr(stop), "over");
	Silent.ar(1)
}.play;

c.write(b.path.splitext[0] ++ "-pv512.aiff", sampleFormat: "float");


~xys = { Bus.control(s, 2) } ! 10;
~xys = ~xys.collect(SharedBus.newFrom(_, \me));

WrapInstr("xy", { |distNear = 5, distFar = 20, mul = 0.25, send = 0|
	var	theta, r, x, y;
	theta = DemandEnvGen.kr(
		Dwhite(-2pi, 2pi, inf),
		Dwhite(0.25, 0.9, inf),
		Env.shapeNumber(\sine)
	);
	r = DemandEnvGen.kr(
		Dwhite(0.1, 1.0, inf),
		Dwhite(0.0, 1.0, inf).linexp(0, 1, 0.6, 2.0),
		Env.shapeNumber(\sine)
	);
	x = theta.cos * r;
	y = theta.sin * r;
	x = x * mul;
	y = (y * mul).linlin(-1, 1, distNear, distFar);
	SendReply.kr(send * Impulse.kr(10), "/xy", [x, y]);
	[x, y]
}, [#[1, 50], #[1, 50], #[0.01, 1.0, \exp]]);


~xysynths = ~xys.collect { |xybus|
	WrapPatch("xy", [5, 20, 1, `0]).play(bus: xybus)
};

~xymaps = ~xys.collect({ |bus| [bus.asMap, ("c" ++ (bus.index+1)).asSymbol] });



// start: fast + stretched steps
SynthDescLib.at(\pvplayStereoDist).controls.do(_.postln); ""

Pdefn(\pan, Pwhite(-1.0, 1.0, inf));
Pdefn(\distance, Pwhite(5.0, 20.0, inf));
Pdefn(\rate, Pexprand(0.05, 1.0, inf));
//Pdefn(\rate, Pswitch1([Pexprand(0.05, 0.2, inf), Pexprand(0.6, 1.2, inf)], Pwrand(#[0, 1], #[0.3, 0.7], inf)));
Pdefn(\time, 0.25 / Pkey(\rate));
Pdefn(\decay, Pkey(\time) * 0.14);
Pdefn(\amp, 15.dbamp); // Pwhite(0, 5, inf).dbamp
Pdefn(\delta, Pkey(\time) * Ptempo() * Pwhite(0.3, 0.6, inf));

Pdefn(\delta, Ptempo() * max(Pwhite(0.3, 0.6, inf) * Pseq([
	Pn(1, { rrand(2, 5) }),
	Pexprand(0.05, 0.2, { rrand(8, 14) })
], inf), Pkey(\time) * 0.1));

Pdefn(\shiftS, Pwhite(8, 30, inf));
Pdefn(\shiftE, Pkey(\shiftS) * Pwhite(0.1, 0.4, inf));


z = 5;
a = n.play(Ptpar([
	0, Pbind(
		\instrument, \pvplayStereoDist,
		\pvbuf, c,
		\rate, Pgeom.fromEndpoints(1, 0.02, z),
		\time, 0.25 * Pkey(\rate).reciprocal,
		\decay, Pkey(\time) * 0.14,
		\amp, 5.dbamp,
		//	\n, 3,
		\pt, Pn(Pshuf(~pt, 1), inf),
		\startFrame, Pkey(\pt) * (((c.numFrames - 3) / 512) / b.duration),
		\pan, Pstutter(2, Pseries.fromEndpoints(-1.0, 0, (z * 0.5).roundUp.asInteger))
			* Pseq(#[1, -1], inf, { 2.rand }),
		\distance, Pseries.fromEndpoints(15, 5, z),
		\glrvbout, ~glrvbmc.inbus, \glrvbamt, 0.3,
		\lcrvbout, ~lcrvbmc.inbus,
		\delta, 0 // Pkey(\time) * Ptempo() * Pwhite(0.75, 0.9, inf)
	),
	{ rrand(0.5, 2.0) }, Pbind(
		\instrument, \pvplayStereoDist,
		\distNear, 5, \distFar, 20,
		\glrvbout, ~glrvbmc.inbus,
		\lcrvbout, ~lcrvbmc.inbus,
		\pvbuf, c,
		\pt, Pn(Pshuf(~pt, 1), inf),
		\startFrame, Pkey(\pt) * (((c.numFrames - 3) / 512) / b.duration),
		#[pan, distance], Pseq(~xymaps, inf),
		\shiftS, Pdefn(\shiftS),
		\shiftE, Pdefn(\shiftE),
		\rate, Pdefn(\rate),
		\time, Pdefn(\time),
		\decay, Pdefn(\decay),
		\amp, Pdefn(\amp),
		\delta, Pdefn(\delta)
	)//.trace(prefix: $\n)
]));

a.stop;



(
BP(\op).free;
PR(\basicSynthChooser).chuck(BP(\op), nil, (
	inChannels: 2,
	master: ~master,
	glrvbmc: ~glrvbmc,
	lcrvbmc: ~lcrvbmc,
	userprep: {
		[~glrvbmc, ~lcrvbmc].do(~chan.sendsSignalTo(_));
		~xys = { SharedBus.newFrom(Bus.control(s, 2), ~collIndex) } ! 10;
		~xysynths = ~xys.collect { |xybus|
			var patch;
			patch = WrapPatch("xy", [5, 20, 1, `0]).play(bus: xybus, callback: e {
				patch.synth.debug("moving").moveToHead(~chan.fadergroup);
			});
		};
		~xymaps = ~xys.collect({ |bus| [bus.asMap, ("c" ++ (bus.index+1)).asSymbol] });
	},
	userfree: {
		[~glrvbmc, ~lcrvbmc].do(~chan.stopsSendingTo(_));
		~xysynths.free;
		~xys.do(_.releaseBus(~collIndex));
	},
	synth: \pvplayStereoDist,
	objects: (
		pv: (
			def: \pvplayStereoDist,
			args: [
				distNear: 5, distFar: 20,
				glrvbout: ~glrvbmc.inbus,
				lcrvbout: ~lcrvbmc.inbus,
				pvbuf: Plazy { ~pvbuf.asPattern },
				pt: Pn(Pshuf(~pt, 1), inf),
				startFrame: Pkey(\pt) * (((c.numFrames - 3) / 512) / b.duration),
				#[pan, distance]: Pseq(~xymaps, inf),
				shiftS: Pwhite(8, 30, inf),
				shiftE: Pkey(\shiftS) * Pwhite(0.1, 0.4, inf),
				rate: Pexprand(0.05, 1.0, inf),
				time: 0.25 / Pkey(\rate),
				decay: Pkey(\time) * 0.14,
				amp: 6.dbamp,
				delta: Ptempo() * max(Pwhite(0.3, 0.6, inf) * Pseq([
					Pn(1, { rrand(2, 5) }),
					Pexprand(0.05, 0.2, { rrand(8, 14) })
				], inf), Pkey(\time) * 0.1)
			]
		)
	)
));
)


o = OSCresponderNode(s.addr, '/n_go', { |t, r, m|
	r.remove;
	Synth.basicNew(\dummy, s, m[1]).trace
}).add;

Pdefn(\speed, Pexprand(0.1, 1.2, inf));
Pdefn(\numev, Pfunc { |speed| (speed.linlin(0.1, 1.2, 12, 4) * rrand(0.7, 1.4)).round.asInteger });

Pdefn(\pan, Pn(
	Plazy { |ev|
		Pseries.fromEndpoints(rrand(-1.0, -0.2), rrand(0.2, 1.0), ev[\numev]) * #[-1, 1].choose
	},
	inf
));
Pdefn(\distance, Pn(
	Plazy { |ev|
		Pseries.fromEndpoints(0, 1, ev[\numev]).linlin(0, 1, rrand(5.0, 20.0), rrand(5.0, 20.0))
	},
	inf
));
Pdefn(\rate, Plazy { |ev|
	Pn(ev[\speed].linexp(0.1, 1.2, 1, 0.04), inf)
});
Pdefn(\delta, Plazy { |ev|
	Pexprand(0.7, 1.5, inf) * ev[\speed] * 0.25
});

a = n.play(
	Ppar([
		Pbind(
			\instrument, \pvplayStereoDist,
			\pvbuf, c,
			\rate, Pgeom.fromEndpoints(1, 0.02, z),
			\time, 0.25 * Pkey(\rate).reciprocal,
			\decay, Pkey(\time) * 0.14,
			\amp, 5.dbamp,
			\pt, Pn(Pshuf(~pt, 1), inf),
			\startFrame, Pkey(\pt) * (((c.numFrames - 3) / 512) / b.duration),
			\pan, Pstutter(2, Pseries.fromEndpoints(-1.0, 0, (z * 0.5).roundUp.asInteger))
				* Pseq(#[1, -1], inf, { 2.rand }),
			\distance, Pseries.fromEndpoints(15, 5, z),
			\glrvbout, ~glrvbmc.inbus, \glrvbamt, 0.4,
			\lcrvbout, ~lcrvbmc.inbus,
			\delta, 0 // Pkey(\time) * Ptempo() * Pwhite(0.75, 0.9, inf)
		),
		Pspawner({ |sp|
			var	speed, numev,
				speedStrm = Pdefn(\speed).asStream, numevStrm = Pdefn(\numev).asStream;
			loop {
				sp.wait(exprand(0.3, 1.2));
				speed = speedStrm.next;
				numev = numevStrm.next(speed);
				sp.seq(Pbind(
					\instrument, \pvplayStereoDist,
					\distNear, 5, \distFar, 20,
					\speed, speed, \numev, numev,
					\glrvbout, ~glrvbmc.inbus,
					\lcrvbout, ~lcrvbmc.inbus,
					\pvbuf, c,
					\pt, Pfin(numev, Pn(Pshuf(~pt, 1), inf)),
					\startFrame, Pkey(\pt) * (((c.numFrames - 3) / 512) / b.duration),
					*[[
						\pan,
						\distance,
						\rate,
						\time,
						\decay,
						\amp,
						\delta
					], [
						Pdefn(\pan).source,
						Pdefn(\distance).source,
						Pdefn(\rate).source,
						Pdefn(\time).source,
						Pdefn(\decay).source,
						Pdefn(\amp).source,
						Pdefn(\delta).source
					]].flop.flat)
				);
			};
		})
	])
);

a.stop;