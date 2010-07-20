

Library.put(\chucklib, \midiSearches, #["remote"]); BP.loadGui;
s.waitForBoot(e { (Document.current.path.dirname +/+ "feet-defs.scd").debug("loading").loadPath });

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


// use chaotic attractor as x/y?
// Rossler gives 3 coordinates but just spirals around, not so exciting

~xy = SharedBus.newFrom(Bus.control(s, 2), \me);

RosslerL.findRespondingMethodFor(\signalRange)

WrapInstr("chaostest", { |freq = 2, a = 0.2, b = 0.2, c = 5.7, h = 0.05, mul = 0.25|
	var	theta, r, x, y;
//	#x, y = A2K.kr(RosslerL.ar(freq, a, b, c, h));
// 	x = x.range(-1, 1);
// 	y =  y.range(5, 14);
	theta = DemandEnvGen.kr(
		Dswitch1([
			Dwhite(-pi, 0, inf),
			Dwhite(-2pi, -pi, inf),
			Dwhite(0, pi, inf)
		], Drand(#[0, 0, 0, 0, 0, 0, 0, 0, 1, 2], inf)),
		Dwhite(0.1, 0.4, inf),
		Env.shapeNumber(\sine)
	);
	r = DemandEnvGen.kr(
		Dwhite(0.1, 1.0, inf),
		Dwhite(0.0, 1.0, inf).linexp(0, 1, 0.6, 2.0),
		Env.shapeNumber(\sine)
	);
// 	theta = Sweep.kr(1, 5 / 2pi);
// 	r = 1;
	x = theta.cos * r;
	y = theta.sin * r;
	x = x * mul;
	y = (y * mul).linlin(-1, 1, 5, 45);
	SendReply.kr(Impulse.kr(10), "/xy", [x, y]);
	[x, y]
}, [#[0.1, 120, exp], #[-10, 10], #[-10, 10], #[0, 10], #[0.001, 0.1, exp], #[0.01, 1.0, \exp]]);

p = WrapPatch("chaostest", [`60, `0.432, `2, `4, nil, 1]).play(bus: ~xy); //p.gui;
p.free;

~xy.getn(2, _.postln)

w = Window("where", Rect(800, 50, 400, 400));
t = StaticText(w, Rect(0, 0, 10, 10)).background_(Color.blue);
w.front;

o.remove;
o = OSCresponderNode(s.addr, '/xy', { |time, r, m|
	defer {
		t.bounds = t.bounds.moveTo(
			m[3].linlin(-1, 1, 0, 390),
			m[4].linlin(5, 45, 390, 0)
		)
	}
}).add;

p.gui;
p.synth.trace

p.run(false);
p.run(true);

Balance2.ar( left, right, pos: 0, level: 1 )

// plug chaostest into pvplay
SynthDescLib.at(\pvplayStereoDist).controls.do(_.postln); ""

c.getn(0, 3, _.postln);

PeakMonitor(n);

a = n.play(\pvplayStereoDist, [
	distance: ("c" + (~xy.index + 1)), pan: ("c" ++ ~xy.index),
	glrvbout: ~glrvbmc.inbus, lcrvbout: ~lcrvbmc.inbus,
	glrvbamt: 0.2,
	amp: 6.dbamp,
	pvbuf: c, startFrame: ~pt[6] / b.duration * (c.numFrames - 3) / 512, time: 20, rate: 0.02
]);

\addRvbOut.eval(\test, { |pan, amp = 1|
	var	trig = Impulse.kr(8);
	Pan2.ar(
		SinOsc.ar(TExpRand.kr(200, 800, trig), 0,
			Decay2.kr(trig, 0.01, 0.08, amp)),
		pan
	)
}).add;

SynthDescLib.at(\test).controls.do(_.postln); ""

a = n.play(\test, [distance: ("c" ++ (~xy.index + 1)), pan: ("c" ++ ~xy.index), glrvbout: ~glrvbmc.inbus, lcrvbout: ~lcrvbmc.inbus,	glrvbamt: 0.2, amp: 0.2, distFar: 45].postln);

a.free

a.trace;

~xy.getn(2, _.postln);