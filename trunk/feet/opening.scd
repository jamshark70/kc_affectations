// todo:
// try multiple xy buses, cycle thru in pattern

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


// start: fast + stretched steps
SynthDescLib.at(\pvplayStereoDist).controls.do(_.postln); ""

Pdefn(\pan, Pwhite(-1.0, 1.0, inf));
Pdefn(\distance, Pwhite(5.0, 20.0, inf));
//Pdefn(\rate, Pexprand(0.05, 1.0, inf));
Pdefn(\rate, Pswitch1([Pexprand(0.05, 0.2, inf), Pexprand(0.6, 1.2, inf)], Pwrand(#[0, 1], #[0.3, 0.7], inf)));
Pdefn(\time, 0.25 / Pkey(\rate));
Pdefn(\decay, Pkey(\time) * 0.14);
Pdefn(\amp, 5.dbamp); // Pwhite(0, 5, inf).dbamp
Pdefn(\delta, Pkey(\time) * Ptempo() * Pwhite(0.3, 0.6, inf));

Pdefn(\delta, Ptempo() * max(Pwhite(0.3, 0.6, inf) * Pseq([
	Pn(1, { rrand(2, 5) }),
	Pexprand(0.05, 0.2, { rrand(8, 14) })
], inf), Pkey(\time) * 0.1));

Pseg(
	Pexprand(0.04, 0.4, inf),
	Pwhite(2.0, 6.0, inf),
	\exp
).trace

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
		*[[
			\pan,
			\distance,
			\rate,
			\time,
			\decay,
			\amp,
			\delta
		], [
			Pdefn(\pan),
			Pdefn(\distance),
			Pdefn(\rate),
			Pdefn(\time),
			Pdefn(\decay),
			Pdefn(\amp),
			Pdefn(\delta),
		]].flop.flat
	)
]));

a.stop;

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