
Dialog.getPaths { |paths| p = paths[0].postcs };
"/Users/dewdrop/SCServer/trax/kc.git/trunk/samples/arms/hands-1_data.txt"

d = thisProcess.nowExecutingPath.dirname.dirname +/+ "samples/arms";
p = d +/+ "hands-1_data2.txt";

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
// 				[(c = c+1), i].debug("written");
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
				l = l.reject(_.isSpace).split($,).asFloat.extend(width, 0.0);
// 				l2 = f.getLine;
// 				if(l2.notNil) {
// 					l2 = l2.reject(_.isSpace).split($,).asFloat;
// 					l = if(l2[2] == 0) { l } { l2 };
// 				};
				write.(l);
			};
			write.(nil);  // force flush
		} { "Couldn't open output file".warn };
	} { "Couldn't open input file".warn };
} { f.close; sf.close };
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
	SynthDef("data" ++ n, { |buf, outbus, frameRate = 30, avgTime = 0.2, loop = 0|
		var	trig = Impulse.kr(30),
			fr = BufFrames.ir(buf),
			end = fr + (10000 * (loop <= 0)),
			ph = Phasor.kr(0, frameRate * ControlDur.ir, start: 0, end: end),
			data = BufRd.kr(n, buf, ph, 0, interpolation: 1),
			avgSize = (avgTime * ControlRate.ir).trunc;
	
		data[n-1] = RunningSum.kr(data[n-1], avgSize) / avgSize;
		4.do { |i| data[i] = data[i].madd(0.5, 0.5) };
	
		Out.ar(outbus, data);
	}).add;
};

