

Library.put(\chucklib, \midiSearches, #["remote"]); BP.loadGui;
s.waitForBoot(e { (Document.current.path.dirname +/+ "feet-defs.scd").debug("loading").loadPath });


b.free;
b = Buffer.readAndQuery(s, topEnvironment[\feetdir].dirname +/+ "samples/feet/58454_sinatra314_footsteps_wooden_floor_loop.wav");

~pt = TabFileReader.read(b.path.dirname +/+ "58454_labels.txt");
~pt = ~pt.flop[0].asFloat;
~ptd = ~pt.differentiate.drop(1);
~mean = ~ptd.mean;

c.free;
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
	#theta, r = ({
		DemandEnvGen.kr(
			Dwhite(-1.0, 1.0, inf),
			Dwhite(0.1, 0.8, inf),
			Env.shapeNumber(\sine)
		)
	} ! 2);
	x = theta.cos * r;
	y = theta.sin * r;
	x = x * mul;
	y = (y * mul).linlin(-1, 1, 5, 14);
	SendReply.kr(Impulse.kr(10), "/xy", [x, y]);
	[x, y]
}, [#[0.1, 120, exp], #[-10, 10], #[-10, 10], #[0, 10], #[0.001, 0.1, exp], #[0.01, 1.0, \exp]]);

p = WrapPatch("chaostest", [`60, `0.432, `2, `4, nil, 1]).play(bus: ~xy); p.gui;
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
			m[4].linlin(5, 14, 390, 0)
		)
	}
}).add;

p.gui;
p.synth.trace

