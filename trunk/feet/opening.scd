

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

~xy = Bus.control(s, 2);

Instr("chaostest", { |freq = 2, a = 0.2, b = 0.2, c = 5.7, h = 0.05|
	var	x, y;
	#x, y = A2K.kr(RosslerL.ar(freq, a, b, c, h));
	x = x.range(-1, 1);
	y =  y.range(5, 14);
	SendReply.kr(Impulse.kr(10), "/xy", [x, y]);
	[x, y]
}, [#[0.1, 20, exp], nil, nil, #[0, 10], #[0.001, 0.1, exp]]);

p = Patch("chaostest").play(bus: ~xy);

