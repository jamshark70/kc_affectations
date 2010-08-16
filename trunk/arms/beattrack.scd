// really isn't good enough...

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

m.free;
m = MixerChannel(\test, s, 1, 2);
m => MCG(0);

b = Bus.audio(s, 1);
k = Bus.control(s, 1);

w = Window(\test, Rect(Window.screenBounds.width - 150, 10, 145, 50));
Button(w, w.view.bounds.insetBy(2, 2))
	.states_([["click"]])
	.action_({ z.set(\t_trig, 1) });
w.front;

a = {
	var	sig = In.ar(b, 1),
		fft = FFT(LocalBuf(1024, 1), sig),
		beat, half, qrt, tempo;
	#beat, half, qrt, tempo = BeatTrack.kr(fft);
	tempo.poll(beat);
	beat
}.play(outbus: k);

z = { |t_trig = 0|
	SinOsc.ar(220) * Decay2.kr(t_trig, 0.01, 0.08)
}.play(outbus: b);


a.free; z.free;


// simplify!
// tolerance as proportion of beat duration

PeakMonitor(m, 10);

k = Bus.control(s, 1);

w.tryPerform(\close);
w = Window(\test, Rect(Window.screenBounds.width - 150, 10, 145, 50));
b = Button(w, w.view.bounds.insetBy(2, 2))
	.states_([["click"]])
	.action_({ |view, modifiers|
		if(z.isNil) { z = f.() } {
			z.set(\t_trig, 1);
			if(modifiers & 1 > 0) { z.trace };
		};
	});
w.onClose_({
	a.free; z.free;
	r.stop;
	w = nil;
}).front;

(
a = m.play({ |t_trig = 0|
	SinOsc.ar(TExpRand.kr(200, 800, t_trig)) * Decay2.kr(t_trig, 0.01, 0.08)
}, [t_trig: k.asMap]);

f = {
	var synth = { |initTempo = 84, t_trig = 0, tolerance = 0.05, movingAvgSize = 8, thresh = 0.05|
		var	//initTrig = Impulse.kr(0),
			sTime = Sweep.kr(1, 1),
			filtTimer = Timer.kr(t_trig),
			filtTrig = t_trig * (filtTimer > thresh),
			i = PulseCount.kr(filtTrig),
			isNotFirstTrig = i > 1,
			localIn = LocalIn.kr(3),
			fbAvg = Select.kr(isNotFirstTrig, [60 / initTempo, localIn[0]]),
			timer = Timer.kr(filtTrig),
			// multiples are allowed (permits missed triggers)
			roundedDownTime = max(timer.trunc(fbAvg) - fbAvg, 0),
			reducedTime = timer - roundedDownTime,
			// moving avg
			rotatingBuf = LocalBuf(movingAvgSize + 1, 1).clear,
	//		trigMinusInit = (filtTrig > 0) - (isNotFirstTrig > 0),
			iWrap = i, //.wrap(0, movingAvgSize),
			writer = BufWr.kr(reducedTime, rotatingBuf, iWrap, loop: 1),
			sum, sumDly, movingsum,
			avg, toleranceAmt, goodTrig, trigout;
	
//reducedTime.poll(filtTrig, "\nwriting to buf");
	
		#sum, sumDly = Select.kr(Impulse.kr(0), [localIn[1..], 0 ! 2]);
// sum.poll(filtTrig, "previous sum");
// sumDly.poll(filtTrig, "previous sumDly");
		sum = Latch.kr(sum + BufRd.kr(1, rotatingBuf, i, loop: 1), filtTrig);
		sumDly = Latch.kr(sumDly + BufRd.kr(1, rotatingBuf, i+1, loop: 1), filtTrig);
		movingsum = sum - sumDly;
// sum.poll(filtTrig, "updated sum");
// sumDly.poll(filtTrig, "updated sumDly");
	
		avg = (movingsum) / i.clip(1, movingAvgSize);
// avg.poll(filtTrig, "-----> avg");
		// check trigger within tolerance since last trig
		toleranceAmt = tolerance * avg;
		goodTrig = InRange.kr(timer, timer - toleranceAmt, timer + toleranceAmt);
	
		LocalOut.kr([avg, sum, sumDly]);
		// movingsum.poll(filtTrig);
		// output trigger at expected next beat	
	//	trigout = TDuty.kr(avg, 0, 1) * (i > 0);
		trigout = Impulse.kr(max(avg, 0.02).reciprocal) * isNotFirstTrig;
		sTime.poll(filtTrig, "trigger", 0);
		sTime.poll(trigout, "***** BANG *****", 1);
		trigout
	}.play(outbus: k, args: [t_trig: 1]);

	o = OSCpathResponder(s.addr, ['/n_end', synth.nodeID], { |t, r, m|
		"z(%) ended".format(m[1]).debug;
		z = nil;
		p.remove;
		r.remove;
	}).add;
	t = List.new;
	u = List.new;
	p = OSCresponderNode(s.addr, '/tr', { |time, r, m|
		[t, u][m[2]].add(m[3]);
	}).add;
	synth
};
)

r = fork {
	loop {
		rrand(0.23, 0.28).wait;
		if(0.9.coin) { z.set(\t_trig, 1) };
	}
};

z.trace

a.free; z.free;
r.stop;


// so this is fine: kr unit for demand-rate input
a = {
	var time = LFNoise1.kr(1.0).range(0.1, 0.4),
		trig = TDuty.kr(time, 0, 1);
	time.poll(trig);
	Silent.ar(1)
}.play;

a.free;


m.synth.trace
s.sendMsg(\n_trace, 1015)

// ok, here's the problem:
// Dseries (like Pseries) adds the 'step' calculated in the last cycle, not the new value written in the buffer
// I need a true accumulator (LocalIn/Out)

(
o = OSCresponderNode(s.addr, '/vals', { |t, r, m| m[3..].postln }).add;

a = {
	var	movingAvgSize = 4,
		t_trig = Impulse.kr(1),
		i = PulseCount.kr(t_trig),
		rotatingBuf = LocalBuf(movingAvgSize, 1).clear,
		trigMinusInit = t_trig,
		writer = Demand.kr(trigMinusInit, 0, Dbufwr(i, rotatingBuf, i, loop: 1)),
		sum, sumDly, movingsum;
	#sum, sumDly = Select.kr(Impulse.kr(0), [LocalIn.kr(2), [0, 0]]);
	sum = Latch.kr(sum/*.poll(t_trig, "sum")*/ + Demand.kr(t_trig <! writer, 0, Dbufrd(rotatingBuf, i, loop: 1)).poll(t_trig, "demand"), t_trig);
	sumDly = Latch.kr(sumDly + Demand.kr(t_trig <! writer, 0, Dbufrd(rotatingBuf, i+1, loop: 1)), t_trig);
	movingsum = sum - sumDly;
	SendReply.kr(t_trig, '/vals', [i, sum, sumDly, movingsum]);
	LocalOut.kr([sum, sumDly]);
	Silent.ar(1)
}.play;

OSCpathResponder(s.addr, ['/n_end', a.nodeID], { |t, r, m| r.remove; o.remove }).add;
)

o.remove;
a.free;

a.trace;

1	1	0
2	3	0
3	6	1
4	10	3
5	15	6


(
o = OSCresponderNode(s.addr, '/vals', { |t, r, m| m[3..].postln }).add;

a = {
	var	movingAvgSize = 4,
		t_trig = Impulse.kr(1),
		i = PulseCount.kr(t_trig),
		rotatingBuf = LocalBuf(movingAvgSize+1, 1).clear,
		trigMinusInit = t_trig,
		writer = BufWr.kr(i, rotatingBuf, i, loop: 1),
		sum, sumDly, movingsum;
	#sum, sumDly = Select.kr(Impulse.kr(0), [LocalIn.kr(2), 0 ! 2]);
	sum = Latch.kr(sum + BufRd.kr(1, rotatingBuf, i, loop: 1), t_trig);
	sumDly = Latch.kr(sumDly + BufRd.kr(1, rotatingBuf, i+1, loop: 1), t_trig);
	movingsum = sum - sumDly;
	SendReply.kr(t_trig, '/vals', [i+1, sum, sumDly, movingsum]);
	LocalOut.kr([sum, sumDly]);
	Silent.ar(1)
}.play;

OSCpathResponder(s.addr, ['/n_end', a.nodeID], { |t, r, m| r.remove; o.remove }).add;
)

o.remove;
a.free;

a.trace;


t = t.drop(1);
t = t.differentiate;
u = u.differentiate;

[t.mean, u.mean]
[t.size, u.size]

t = t.drop(1);
u = u.drop(1);

[t, u, abs(t-u)].lace(t.size * 3).plot(numChannels: 3, minval: 0.0, maxval: 1.0);