
Dialog.getPaths { |paths| p = paths[0].postcs };
"/Users/dewdrop/SCServer/trax/kc.git/trunk/samples/arms/hands-1_data.txt"

d = thisProcess.nowExecutingPath.dirname.dirname +/+ "samples/arms";
p = d +/+ "hands-1_data.txt";

// read in pairs, choose whichever has non-zero for third value

f.close;

(
var f, sf;
protect {
	var	l, l2;
	var write = Routine { |row|
		var	databuf = FloatArray.newClear(3 * 2000), i = 0;
		loop {
			if(row == nil or: { i >= databuf.size }) {
				sf.writeData(databuf.extend(i));
				databuf = FloatArray.newClear(3 * 2000);
				i = 0;
			} {
				row.do { |data| databuf[i] = data; i = i + 1 };
			};
			row = true.yield;
		}
	};
	f = File(p, "r");
	if(f.isOpen) {
		sf = SoundFile(p.splitext[0] ++ ".wav").headerFormat_("WAV").numChannels_(3);
		if(sf.openWrite) {
			while { (l = f.getLine).notNil } {
				l = l.reject(_.isSpace).split($,).asFloat;
				l2 = f.getLine;
				if(l2.notNil) {
					l2 = l2.reject(_.isSpace).split($,).asFloat;
					l = if(l2[2] == 0) { l } { l2 };
				};
				write.(l);
			};
			write.(nil);  // force flush
		} { "Couldn't open output file".warn };
	} { "Couldn't open input file".warn };
} { f.close; sf.close };
)


// test: visualize
w = ResizeFlowWindow("test", Rect(900, 100, 300, 200));
z = MultiSliderView(w, Rect(0, 0, 100, 200))
.indexThumbSize_(100/3 - 4).gap_(4).value_(0 ! 3);
w.recursiveResize.front;

b = Buffer.readAndQuery(s, d +/+ "hands-1_data.wav");

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
		data = BufRd.kr(3, buf, ph, 0, interpolation: 1),
		prevData = Select.kr(Impulse.kr(0), [LocalIn.kr(5), data ++ #[0, 0]]),
		mvt = data[2],
//		peak = Peak.kr(data[2].abs),
		done = ph >= fr,
		sum, sumDly, writer, stupidBufFix;
	mvt = Select.kr(mvt >= 30, [mvt, prevData[2]]);

	writer = BufWr.kr(mvt, rotatingBuf, i, loop: 1);
//	stupidBufFix = rotatingBuf <! writer;  // force next 2 BufRd's to be later than writer
	stupidBufFix = i + writer - writer;  // force next 2 BufRd's to be later than writer

	#sum, sumDly = Select.kr(Impulse.kr(0), [prevData[3..], 0 ! 2]);
// 	sum = Latch.kr(sum + BufRd.kr(1, stupidBufFix, i, loop: 1), trig);
// 	sumDly = Latch.kr(sumDly + BufRd.kr(1, stupidBufFix, i+1, loop: 1), trig);
	sum = Latch.kr(sum + BufRd.kr(1, rotatingBuf, stupidBufFix, loop: 1), trig);
	sumDly = Latch.kr(sumDly + BufRd.kr(1, rotatingBuf, stupidBufFix+1, loop: 1), trig);
	// moving sum / count == moving average
	data[2] = (sum - sumDly) / i.clip(1, i_movingAvgSize);

	LocalOut.kr(data ++ [sum, sumDly]);
	SendReply.kr(trig, "/lorne", data / #[1, 1, 30]);
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