// really isn't good enough...

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
	SinOsc.ar(TExpRand(200, 800, t_trig) * Decay2.kr(t_trig, 0.01, 0.08)
}, [t_trig: k.asMap]);

z = { |initTempo = 84, t_trig = 0, tolerance = 0.05, movingAvgSize = 8|
	var	//initTrig = Impulse.kr(0),
		i = PulseCount.kr(t_trig),
		isNotFirstTrig = i > 1,
		fbAvg = Select.kr(isNotFirstTrig, [60 / initTempo, LocalIn.kr(1)]),
		timer = Timer.kr(t_trig),
		// multiples are allowed (permits missed triggers)
		roundedDownTime = max(timer.trunc(fbAvg) - fbAvg, 0),
		reducedTime = timer - roundedDownTime,
		// moving avg
		rotatingBuf = LocalBuf(movingAvgSize, 1).clear,
		trigMinusInit = (t_trig > 0) - (isNotFirstTrig > 0),
		iWrap = i.wrap(0, movingAvgSize-1),
		writer = Demand.kr(trigMinusInit, 0, Dbufwr(reducedTime, rotatingBuf, iWrap, loop: 1)),
		sum = Demand.kr(trigMinusInit, 0, Dseries(0, Dbufrd(rotatingBuf, iWrap, loop: 1), inf)),
		sumDly = Demand.kr(trigMinusInit, 0, Dseries(0, Dbufrd(rotatingBuf, iWrap-1, loop: 1), inf)),
		movingsum = sum - sumDly,
		avg = (movingsum) / movingAvgSize,
		// check trigger within tolerance since last trig
		toleranceAmt = tolerance * avg,
		goodTrig = InRange.kr(timer, timer - toleranceAmt, timer + toleranceAmt);
	LocalOut.kr(avg);
movingsum.poll(t_trig);
	// output trigger at expected next beat	
	TDuty.kr(avg, 0, 1) * (i > 0)
}.play(outbus: k);

z.trace

a.free; z.free;


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
		writer = Demand.kr(trigMinusInit, 0, Dbufwr(i+1, rotatingBuf, i, loop: 1)),
		sum = Demand.kr(trigMinusInit, 0, Dseries(i+1, Dbufrd(rotatingBuf, i, loop: 1), inf)),
		sumDly = Demand.kr(trigMinusInit, 0, Dseries(0, Dbufrd(rotatingBuf, i+1, loop: 1), inf)),
		movingsum = sum - sumDly;
	SendReply.kr(t_trig, '/vals', [i+1, sum, sumDly, movingsum]);
	Silent.ar(1)
}.play;
)

o.remove;
a.free;

1	1	0
2	3	0
3	6	1
4	10	3
5	15	6