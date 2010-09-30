ChuckableBrowser.newWindow;

Dialog.getPaths { |paths| p = paths[0].postcs };
"/Users/dewdrop/SCServer/trax/kc.git/trunk/samples/arms/hands-1_data.txt"
"/home/dlm/share/SuperCollider/scd/kc.git/trunk/samples/arms/NACL_Arms.log"

"/home/dlm/share/SuperCollider/scd/kc.git/trunk/samples/arms/locomotor_arms_solo_Laura_9-8-10.txt"

d = thisProcess.nowExecutingPath.dirname.dirname +/+ "samples/arms";
p = d +/+ "NACL_Arms.log";
p = d +/+ "hands-1_data2.txt";
p = d +/+ "locomotor_arms_solo_Laura_9-8-10.txt";

~sampleDir = d.dirname;

File.exists(p);

// read in pairs, choose whichever has non-zero for third value

f.close;

FloatArray[0, 1, 2].extend(2)

(
var f, sf;
var	width = 5;
protect {
	var	l, l2;
	var write = Routine { |row|
		var	databuf = FloatArray.newClear(width * 2000), i = 0, c = 0;
		loop {
			if(row.isNil or: { i >= databuf.size }) {
				sf.writeData(databuf.extend(i));
				databuf = FloatArray.newClear(width * 2000);
				i = 0;
			};
			row !? {
				row.do { |data| databuf[i] = data; i = i + 1 };
			};
			row = true.yield;
		}
	};
	f = File(p, "r");
	if(f.isOpen) {
		sf = SoundFile(p.splitext[0] ++ ".wav").headerFormat_("WAV").numChannels_(width);
		if(sf.openWrite) {
			while { (l = f.getLine).notNil } {
				if(l.size > 0) {
					l = l.reject(_.isSpace).split($,).asFloat.extend(width, 0.0);
					write.(l);
				};
			};
			write.(nil);  // force flush
		} { "Couldn't open output file".warn };
	} { "Couldn't open input file".warn };
} { f.close; sf.close; "files closed".postln; };
)


// test: visualize
n = 5;
w = ResizeFlowWindow("test", Rect(900, 100, 300, 200));
z = MultiSliderView(w, Rect(0, 0, 100, 200))
.indexThumbSize_(100/n - 4).gap_(4).value_(0 ! n);
w.recursiveResize.front;

b.free;
b = Buffer.readAndQuery(s, d +/+ "hands-1_data2.wav");

b.numFrames/30

// mental note: there are some really f*king nasty bugs with <! here
// post to the list later
// (even so, my totally crap workaround i + writer - writer isn't helping...)

(
a = { |buf, i_movingAvgSize = 20|
	var	trig = Impulse.kr(30),
		i = PulseCount.kr(trig),
		rotatingBuf = LocalBuf(i_movingAvgSize + 1, 1).clear,
		fr = BufFrames.ir(buf),
		ph = Phasor.kr(0, 30 * ControlDur.ir, start: 0, end: fr + 10000),
		data = BufRd.kr(n, buf, ph, 0, interpolation: 1),
//		prevData = Select.kr(Impulse.kr(0), [LocalIn.kr(n+2), data ++ #[0, 0]]),
		mvt = data.last,
		done = ph >= fr,
		sum, sumDly, writer, stupidBufFix, avgSize;

/*
	writer = BufWr.kr(mvt, rotatingBuf, i, loop: 1);
//	stupidBufFix = rotatingBuf <! writer;  // force next 2 BufRd's to be later than writer
	stupidBufFix = i + writer - writer;  // force next 2 BufRd's to be later than writer

	#sum, sumDly = Select.kr(Impulse.kr(0), [prevData[n..], 0 ! 2]);
// 	sum = Latch.kr(sum + BufRd.kr(1, stupidBufFix, i, loop: 1), trig);
// 	sumDly = Latch.kr(sumDly + BufRd.kr(1, stupidBufFix, i+1, loop: 1), trig);
	sum = Latch.kr(sum + BufRd.kr(1, rotatingBuf, stupidBufFix, loop: 1), trig);
	sumDly = Latch.kr(sumDly + BufRd.kr(1, rotatingBuf, stupidBufFix+1, loop: 1), trig);
	// moving sum / count == moving average
	data[n-1] = (sum - sumDly) / i.clip(1, i_movingAvgSize);
*/
//	LocalOut.kr(data ++ [sum, sumDly]);

	avgSize = 0.1 * ControlRate.ir;
	data[n-1] = RunningSum.kr(data[n-1], avgSize) / avgSize;
	4.do { |i| data[i] = data[i].madd(0.5, 0.5) };

	SendReply.kr(trig, "/lorne", data / (1 ! n).put(n-1, 20));
	FreeSelf.kr(done);
	done.poll(done, "done");
	Silent.ar(1);
}.play(args: [buf: b]);

o.remove;
o = OSCresponderNode(s.addr, '/lorne', { |t, r, m|
	defer { z.value = m[3..] };
}).add;

//OSCpathResponder(s.addr, ['/n_end', a.nodeID], { |t, r, m| r.remove; o.remove; "responders removed".debug }).add;
)

a.free;

a.trace;

f = { |n = 5|
	SynthDef("data" ++ n, { |buf, outbus, frameRate = 30, loop = 0|
		var	//trig = Impulse.kr(30),
			fr = BufFrames.ir(buf),
			notLoop = loop <= 0,
			end = fr + (10000 * notLoop),
			ph = Phasor.kr(0, frameRate * ControlDur.ir, start: 0, end: end),
			data = BufRd.kr(n, buf, ph, 0, interpolation: 2);//,

// data.poll(Impulse.kr(0), "2");
//data.debug("data");
	
		Out.kr(outbus, data);
//		FreeSelf.kr(notLoop * (ph >= fr));
	}).add;

	SynthDef("datafixer" ++ n, { |bus, avgTime = 0.2|
		var	data = In.kr(bus, n),
			avgSize = (avgTime * ControlRate.ir).trunc;
	
		data[n-1] = RunningSum.kr(data[n-1], avgSize) / avgSize / 20;

		(n-1).do { |i| data[i] = data[i].madd(0.5, 0.5) };
		ReplaceOut.kr(bus, data);
	}).add;
};

f.();

k = Bus.control(s, 5);
KrBusWatcher.register(k);
KrBusWatcher.newFrom(s).updateFreq_(10);
u.remove;
u = Updater(k, { |obj, data|
	defer { z.value = data };
});

b.free;
b = Buffer.readAndQuery(s, d +/+ "hands-1_data2.wav");

a = Synth(\data5, [buf: b, loop: 1, outbus: k]);
c = Synth.after(a, \datafixer5, [bus: k]);
a.free;
c.free;

KrBusWatcher.unregister(k);

a = {
	var	sig = In.kr(k, 5);
	sig = sig.madd(0.5, 0.5);
	Silent.ar(1)
}.play;

a.free;


(
Proto {
	~event = (eventKey: \singleSynthPlayNotify);
	~numCh = 1;
	~iMadeBus = false;
	~prep = {
		~outCh ?? { ~outCh = ~numCh };
		~bus ?? {
			~bus = Bus.control(s, max(~numCh, ~outCh));
			~iMadeBus = true;
		};
		~userprep.();
	};
	~freeCleanup = {
		if(~iMadeBus) { ~bus.free };
		~userfree.();
	};
	
	~asPattern = {
		~userPat.() <> ~busyWaitPat.()
	};
	~userPat = Pfunc { |ev| ev };
	~busyWaitPat = {
		Pn((instrument: \rest, delta: 1), inf)
	};
} => PR(\dataIn);
)

topEnvironment[\sampleDir] = thisProcess.nowExecutingPath.dirname.dirname +/+ "samples";

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| t.debug("node started at") }).add;

(
BP(\di).free;
PR(\dataIn).chuck(BP(\di), nil, (
	alwaysReset: true,
	numCh: 5,
	outCh: 8,
	path: topEnvironment[\sampleDir] +/+ "arms/NACL_Arms.wav", // "arms/hands-1_data2.wav",
	userprep: {
		~buf = Buffer.readAndQuery(s, ~path);
		~maxVel = GenericGlobalControl(\maxVel, nil, 9, #[0, 20, lin]);
		~maxRatio = GenericGlobalControl(\maxRatio, nil, 5.1, #[0.05, 15, exp]);

		SynthDef("data" ++ ~numCh, { |buf, outbus, frameRate = 30, loop = 0|
			var	fr = BufFrames.ir(buf),
				dur = fr / frameRate,
				notLoop = loop <= 0,
				end = fr + (10000 * notLoop),
				stopper = Line.kr(0, 1, dur, doneAction: notLoop*2),
				ph = Phasor.kr(0, frameRate * ControlDur.ir, start: 0, end: end),
				data = BufRd.kr(~numCh, buf, ph, 0, interpolation: 1);
	
			Out.kr(outbus, data);
		}).add;

		SynthDef("datafixer" ++ ~numCh, { |bus, avgTime = 0.2, stop = 0, maxVel = 1, maxRatio = 10|
			var	data = In.kr(bus, ~numCh),
				avgSize = (avgTime * ControlRate.ir).trunc,
				peak;
		
			data[~numCh-1] = RunningSum.kr(data[~numCh-1], avgSize) / avgSize / maxVel;
			FreeSelf.kr(stop);

			(~numCh-1).do { |i| data[i] = data[i].madd(0.5, 0.5) };
			// w/o copy, 'data' has 3 more elements than In.kr created
			// this causes In.kr to create 8 OutputProxies where 5 would be correct
			data = data.copy.add(data[1] - data[0]).add(data[3] - data[2]);
			data = data.add(data[6] / max(data[5], 0.01) / maxRatio);
			// peak = Peak.kr(data.last);
			// peak.poll(stop, "peak was");
			
			ReplaceOut.kr(bus, data);
		}).add;

		~visualizer.();
	},
	visualizer: {
		defer(e {
			~win = ResizeFlowWindow("test", Rect(900, 100, 300, 200))
				.onClose_(e { ~closeWin.() });
			~ms = MultiSliderView(~win, Rect(0, 0, 100, 200))
				.indexThumbSize_(100/~outCh - 4).gap_(4).value_(0 ! ~outCh);
			~win.recursiveResize.front;
			
//			KrBusWatcher.register(~bus);
			KrBusWatcher.newFrom(s).updateFreq_(10);
			~upd = Updater(~bus, e { |obj, data|
				var ms = ~ms;
				defer { ms.value = data };
			});
		});
	},
	userfree: {
		[~buf, ~maxVel, ~maxRatio].free;
		~closeWin.();
	},
	preparePlay: {
		~bus.setn(0 ! ~outCh);
		KrBusWatcher.register(~bus)
	},
	stopCleanup: {
		KrBusWatcher.unregister(~bus);
		s.listSendBundle(nil, [
			[error: -1],
			// ~fixer.tryPerform(\freeMsg),
			~fixer.tryPerform(\setMsg, \stop, 1),
			~player.tryPerform(\freeMsg),
			[error: -2]
		].select(_.notNil));
		~fixer = nil;
		~player = nil;
		~bus.setn(0 ! ~outCh);
	},
	recvEventNotify: { |node, ev|
		if(ev[\instrument].asString.contains("fixer")) {
			~fixer = node;
		} {
			~player = node;
		};
	},
	userPat: {
		Pseq([
			(
				instrument: ("datafixer" ++ ~numCh).asSymbol,
				bus: ~bus, avgTime: ~avgTime ? 0.2,
				maxVel: ~maxVel.asMap, maxRatio: ~maxRatio.asMap,
				delta: 0.0005, collIndex: ~collIndex, addAction: \addToHead
			),
			Pfuncn {
				(
					instrument: ("data" ++ ~numCh).asSymbol,
					buf: ~buf, bus: ~bus, loop: 0,
					delta: ~buf.numFrames / 30,
					target: ~fixer, addAction: \addBefore, collIndex: ~collIndex
				).parent_(ProtoEvent(\singleSynthPlayNotify).parent)
			}
		], 1)
	},
	closeWin: {
		var	win = ~win;
		win !? {
			defer(e { win.onClose_(nil).close });
			KrBusWatcher.unregister(~bus);
			~upd.remove;
		};
	}
));
0 => BP(\di);
)


s.makeBundle(nil, {
	#[player, fixer].do { |key| BP(\di)[key].trace }
});

BP(\di).play;
BP(\di).stop;


// get raw max velocity (5th channel)
f = SoundFile.openRead(topEnvironment[\sampleDir] +/+ "arms/hands-1_data2.wav");
f.readData(z = FloatArray.newClear(f.numFrames * f.numChannels));
f.close;

z.clump(5).flop.last.maxItem
// 18.136728286743

BP(\di).maxVel.spec_(#[0, 20, lin]).value_(9);
BP(\di).maxVel.gui;