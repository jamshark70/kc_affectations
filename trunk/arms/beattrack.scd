// really isn't good enough...

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

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

k = Bus.control(s, 1);

w.tryPerform(\close);
w = Window(\test, Rect(Window.screenBounds.width - 150, 10, 145, 50));
Button(w, w.view.bounds.insetBy(2, 2))
	.states_([["click"]])
	.action_({ |view, modifiers|
		z.set(\t_trig, 1);
		if(modifiers & 1 > 0) { z.trace };
	});
w.front;

a = m.play({ |t_trig = 0|
	SinOsc.ar(TExpRand.kr(200, 800, t_trig)) * Decay2.kr(t_trig, 0.01, 0.08)
}, [t_trig: k.asMap]);

z = { |initTempo = 84, t_trig = 0, tolerance = 0.05, movingAvgSize = 8|
	var	//initTrig = Impulse.kr(0),
		i = PulseCount.kr(t_trig),
		isNotFirstTrig = i > 1,
		localIn = LocalIn.kr(3),
		fbAvg = Select.kr(isNotFirstTrig, [60 / initTempo, localIn[0]]),
		timer = Timer.kr(t_trig),
		// multiples are allowed (permits missed triggers)
		roundedDownTime = max(timer.trunc(fbAvg) - fbAvg, 0),
		reducedTime = timer - roundedDownTime,
		// moving avg
		rotatingBuf = LocalBuf(movingAvgSize + 1, 1).clear,
//		trigMinusInit = (t_trig > 0) - (isNotFirstTrig > 0),
		iWrap = i.wrap(0, movingAvgSize-1),
		writer = BufWr.kr(reducedTime, rotatingBuf, iWrap, loop: 1),
		sum, sumDly, movingsum,
		avg, toleranceAmt, goodTrig;

reducedTime.poll(t_trig, "\nwriting to buf");

	#sum, sumDly = Select.kr(Impulse.kr(0), [localIn[1..], 0 ! 2]);
sum.poll(t_trig, "previous sum");
sumDly.poll(t_trig, "previous sumDly");
	sum = Latch.kr(sum + BufRd.kr(1, rotatingBuf, i, loop: 1), t_trig);
	sumDly = Latch.kr(sumDly + BufRd.kr(1, rotatingBuf, i+1, loop: 1), t_trig);
	movingsum = sum - sumDly;
sum.poll(t_trig, "updated sum");
sumDly.poll(t_trig, "updated sumDly");

	avg = (movingsum) / min(i, movingAvgSize);
avg.poll(t_trig, "avg");
	// check trigger within tolerance since last trig
	toleranceAmt = tolerance * avg;
	goodTrig = InRange.kr(timer, timer - toleranceAmt, timer + toleranceAmt);

	LocalOut.kr([avg, sum, sumDly]);
	// movingsum.poll(t_trig);
	// output trigger at expected next beat	
	TDuty.kr(avg, 0, 1) * (i > 0)
}.play(outbus: k);

z.trace

a.free; z.free;


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
