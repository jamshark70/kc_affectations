// =====================================================================
// SuperCollider Workspace
// =====================================================================

b.free;
b = Bus.control(s, 1);

[/c_setn, 0, 1, x]

KrBusWatcher.register(b);
KrBusWatcher.newFrom(s).updateFreq = 6;

KrBusWatcher.newFrom(s).nodes

w = ResizeFlowWindow("test", Rect(5, 50, 600, 100));
z = EZSlider(w, Rect(0, 0, 500, 20), "x", \bipolar);
//u = Updater(b, { |val| defer { z.value = b[0] } });
w.recursiveResize.front;

r = {
	loop {
		b.get({ |val| defer { z.value = val } });
		0.1.wait;
	}
}.fork(AppClock);

r.stop;

b.set(0.0);
s.sendMsg(\c_setn, b.index, 1, 1.0.rand2);


thisProcess.recvOSCfunc = { |time, addr, msg|
	if(#['/info', 'status.reply', '/status.reply'].includes(msg[0]).not) { msg.postln };
};

thisProcess.recvOSCfunc = nil;

NetAddr.localAddr.sendMsg(\hello, 123);

n = NetAddr("199.165.243.203", 9000);
n.sendMsg('/c_setn', 0, 1, 10.rand);
n.sendMsg('/c_setn', 0.0, 1.0, 3.14159);

["hi there"].asRawOSC
Object.browse

b.get(_.postln)

a = { SinOsc.ar(In.kr(0, 1) * 100) ! 2 }.play;

a = {
	var	freq = Lag.kr(TExpRand.kr(200, 800, Impulse.kr(6)), 0.1),
		cutoff = In.kr(0, 1).linexp(-1, 1, 700, 3000),
		sig = Saw.ar(freq * [1, 1.004], 0.5).sum;
	RLPF.ar(sig, cutoff, 0.1) ! 2
}.play;

a.free;


