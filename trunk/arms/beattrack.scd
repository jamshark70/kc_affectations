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

Pgeom.fromEndpoints(1, 0.01, 25).postcs

// Nick's agent-based approach
(
Proto {
	~score = 0;
	~ioi = 1;	// inter-onset interval
	~phase = 0;
	~lastWinTime = 0;
	~downScoreFactor = 2.5;
	~scoreDamping = 0.8254;  // reduces score by a factor of 100 over 25 iterations
	~prep = { |phase = 0, ioi = 1|
		~phase = phase;
		~ioi = ioi;
		currentEnvironment
	};
	~rescore = { |now, inputIoi|
		case
			// { now absdif: (~phase + (now - ~phase).round(~ioi * 2)) < 0.03 }
			// 	{ ~score = ~score - 1 }
			// now is within 30ms of prediction
			{ (now absdif: (~phase + (now - ~phase).round(~ioi))) < 0.03
				// and my ioi is not too much bigger than input
				and: { ~ioi < (inputIoi * 1.2) } }
				{ ~score = ~score + ~scoreAdd.(now) }
			{ now absdif: (~phase + (now - ~phase).round(~ioi * 0.5)) < 0.03 }
				{ ~score = ~score + (0.1 * ~scoreAdd.(now)) }
			{ ~score = ~score - ((now - ~phase) * ~downScoreFactor) };
		~score = ~score * ~scoreDamping;
	};
	~scoreAdd = { |now|
		// if interval vs now is a (near)multiple of ioi, reduce influence on score
		~ioi / (now - ~phase)
	};
	~shouldBeRemoved = { |now|
		~score < -3 and: { now - ~lastWinTime > 4 }
	};
} => PR(\tempoAgent);

Proto {
	~agents = LinkedList.new;
	~activeTimes = LinkedList.new.add(0);
	~agentProto = \tempoAgent;
	~nextID = 0;

	~rejectThresh = 0.08;
	~newAgentThresh = 0.25;
	~cullActiveTimeAfter = { (~bestInterval ? 0.5) * 2 };
	~clock = { TempoClock.default };

	~recvTrig = { |now|
		var	ioi, bestAgent = ~agents.first, culltime;
		if(~clock.isFunction) { ~clock = ~clock.value };
		now ?? { now = ~clock.beats };
		ioi = now - ~lastTrig;

		// Nick: 1-3
		if(ioi >= ~rejectThresh) {
			// Nick: 4-8
			~agents.copy.do { |agent|
				agent.rescore(now, ioi);
//agent.score.debug("new score (%)".format(agent.id));
				case
					{ agent.shouldBeRemoved(now)/*.debug("remove")*/ } { ~agents.remove(agent) }
					{ agent.score > (bestAgent.tryPerform(\score) ? 0) } {
						bestAgent = agent;
					};
			};
			if(bestAgent.notNil) {
				bestAgent.lastWinTime = now;
//"\nbest".debug; bestAgent.listVars;
			};
			// Nick: 9
			culltime = now - ~cullActiveTimeAfter.(now, ioi);
			~activeTimes = ~activeTimes.reject { |time| time < culltime };
			// Nick: 10-15
			~activeTimes.do { |then|
				var	ioi = now - then;
				if(ioi >= ~newAgentThresh) {
					~agents.add(PR(~agentProto).copy.prep(now, ioi).put(\id, ~nextID));
					~nextID = ~nextID + 1;
				};
			};
			~activeTimes.add(now);
			~lastTrig = now;
			bestAgent !? { ~bestInterval = bestAgent.ioi };
		};
		~bestInterval
	};

	~lastTrig = 0;
} => PR(\estimateTempo);
)

();
e = Env(#[0.3, 0.3, 1.2, 1.2, 0.5], #[5, 5, 3, 3] * 3, \exp);

p = PR(\estimateTempo).copy;
r = fork {
	var	curve = e.asStream;
	loop {
		p.recvTrig(thisThread.beats).debug("best interval");
		(curve.next * exprand(0.95, 1.05)).debug("\nyield").yield;
	}
};

r.stop;

p.listVars;

p.agents.do { |ag| "".postln; ag.listVars };


0.585648771929 / 0.29968354995071


// problem:
// sometimes near-multiple of yield is chosen -- why?
//		Could be more than one agent with very close ioi's but different phases?


(
a = m.play({ |t_trig = 0|
	SinOsc.ar(TExpRand.kr(200, 800, t_trig)) * Decay2.kr(t_trig, 0.01, 0.08)
}, [t_trig: k.asMap]);

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
)