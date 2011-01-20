ChuckableBrowser.newWindow;

// Run this first and choose the text file
Dialog.getPaths { |paths| p = paths[0].postcs };

// then cursor on open-paren and ctrl-alt-x
(
var f, sf;
var	width = 12;
protect {
	var	l; //, l2;
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
//				if(l.any(_.isDecDigit)) {
				l = l.reject(_.isSpace).split($,).asFloat.extend(width, 0.0);
				// if(l[1] == 0) { l[2..] = 0.0 };
				write.(l);
//					l2 = l;
//				} {
//					write.(l2/*.debug("wrote l2")*/)
//				};
			};
			write.(nil);  // force flush
		} { "Couldn't open output file".warn };
	} { "Couldn't open input file".warn };
} { f.close; sf.close; "files closed".postln; };
)



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

ChuckableBrowser.newWindow;

(
BP(\di).free;
PR(\dataIn).chuck(BP(\di), nil, (
	alwaysReset: true,
	numCh: 10,
	outCh: 10,
	startFrame: 0,
	vizRate: 5,
	vizRate_: { |newRate = 10|
		KrBusWatcher.updateFreq = newRate;
		currentEnvironment.put(\vizRate, newRate);
		if(~fixer.notNil) { ~fixer.set(\avgTime, newRate.reciprocal) };
	},
	dataSpecs: [
		[0, 60*60],  // 1 hr
		[0, 50],
		#[-1, 1],
		#[-1, 1],
		#[-1, 1],
		#[-1, 1],
		#[-1, 1],
		#[-1, 1],
		#[0, 8],
		#[0, 2]		
	].collect(_.asSpec),
	// path: topEnvironment[\sampleDir] +/+ "arms/NACL_Arms.wav", // "arms/hands-1_data2.wav",
	// path: topEnvironment[\sampleDir] +/+ "arms/hand_stack-100930.wav",
	path: topEnvironment[\sampleDir] +/+ "vizdata/Affectations_KC1_Data.wav",
	bus: 0,  // trick PR(\dataIn) into NOT creating the output bus
	userprep: {
		~buf = Buffer.readAndQuery(s, ~path);
		~rawBus = Bus.control(s, ~numCh);
		~bus = Bus.control(s, ~outCh);
		~maxVel = GenericGlobalControl(\maxVel, nil, 9, #[0, 20, lin]);
		~maxRatio = GenericGlobalControl(\maxRatio, nil, 5.1, #[0.05, 15, exp]);

		SynthDef("data" ++ ~numCh, { |buf, outbus, frameRate = 30, loop = 0, startFrame = 0|
			var	fr = BufFrames.ir(buf),
				dur = fr / frameRate,
				notLoop = loop <= 0,
				end = fr + (10000 * notLoop),
				stopper = Line.kr(0, 1, dur, doneAction: notLoop*2),
				ph = Phasor.kr(0, frameRate * ControlDur.ir, start: startFrame, end: end),
				data = BufRd.kr(~numCh, buf, ph, 0, interpolation: 1);
	
			Out.kr(outbus, data);
		}).add;

		SynthDef("datafixer" ++ ~numCh, { |rawBus, bus, avgTime = 0.2, stop = 0, maxVel = 1, maxRatio = 10, bufnum|
			var	sig = In.kr(rawBus, ~numCh),
				maxSamps = roundUp(avgTime * SampleRate.ir),
				startTime = Index.kr(bufnum, 0);
			sig[0] = sig[0] - startTime;
			(sig.size-2 .. sig.size-1).do { |i|
				sig[i] = Max.kr(K2A.ar(sig[i]), maxSamps);
			};
			FreeSelf.kr(stop);
			ReplaceOut.kr(bus, sig[#[0, 1, 2, 4, 3, 5, 7, 6, 8, 9]]);
		}).add;

		// SynthDef("datafixer" ++ ~numCh, { |bus, avgTime = 0.2, stop = 0, maxVel = 1, maxRatio = 10|
		// 	var	data = In.kr(bus, ~numCh),
		// 		avgSize = (avgTime * ControlRate.ir).trunc,
		// 		peak;
		
		// 	data[~numCh-1] = RunningSum.kr(data[~numCh-1], avgSize) / avgSize / maxVel;
		// 	FreeSelf.kr(stop);

		// 	(~numCh-1).do { |i| data[i] = data[i].madd(0.5, 0.5) };
		// 	// w/o copy, 'data' has 3 more elements than In.kr created
		// 	// this causes In.kr to create 8 OutputProxies where 5 would be correct
		// 	data = data.copy.add(data[1] - data[0]).add(data[3] - data[2]);
		// 	data = data.add(data[6] / max(data[5], 0.01) / maxRatio);
		// 	// peak = Peak.kr(data.last);
		// 	// peak.poll(stop, "peak was");
			
		// 	ReplaceOut.kr(bus, data);
		// }).add;

		~visualizer.();
	},
	visualizer: {
		~boundsColor = ~boundsColor ?? { Color.red(alpha: 0.15) };
		~velColor = ~velColor ?? { Color.blue(alpha: 0.3) };
		defer(e {
			~win = ResizeFlowWindow("test", Rect(900, 100, 300, 300))
				.onClose_(e { ~closeWin.() });
			~uv = UserView(~win, 200@200)
				.drawFunc_(e { |view|
					var	data = ~latestData.copy,
						velSize = data[8] * 2 + 3;  // max approx = 18
					(5..7).do { |i| data[i] = data[i].neg };
					Pen.color_(~boundsColor)
						.fillRect(Rect.newSides(*(data[#[2, 7, 4, 5]] * 100 + 100)))
						.color_(~velColor)
						.fillOval(Rect.aboutPoint(Point(*(data[#[3, 6]] * 100 + 100)),
							velSize, velSize));
				});
			~win.startRow;
			~tv = StaticText(~win, 200@30)
				.font_(Font.default.copy.size_(14))
				.align_(\right)
				.background_(Color.white);
			~win.startRow;
			~vs = EZSlider(~win, 200@30, "velocity", ~dataSpecs[8]);
			~win.recursiveResize.front;
			
			KrBusWatcher.newFrom(s).updateFreq_(~vizRate ? 10);
			~upd = Updater(~bus, e { |obj, data|
				var tv = ~tv, uv = ~uv, vs = ~vs, ds = ~dataSpecs, mins, secs;
				~latestData = data;
				defer {
					vs.value = data[8];
					uv.refresh;
					mins = data[0] div: 60;
					secs = (data[0] % 60).round;
					tv.string = "%%:%%".format(
						if(mins < 10) { $0 } { "" },
						mins,
						if(secs < 10) { $0 } { "" },
						secs
					);
				};
			});
		});
	},
	userfree: {
		[~buf, ~maxVel, ~maxRatio, ~rawBus, ~bus].free;
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
				rawBus: ~rawBus, bus: ~bus, avgTime: ~avgTime ? 0.2,
				maxVel: ~maxVel.asMap, maxRatio: ~maxRatio.asMap,
				bufnum: ~buf,
				delta: 0.0005, collIndex: ~collIndex, addAction: \addToHead
			),
			Pfuncn {
				(
					instrument: ("data" ++ ~numCh).asSymbol,
					buf: ~buf, bus: ~rawBus, loop: 0,
					delta: ~buf.numFrames / 30,
					startFrame: ~startFrame,
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


BP(\di).startFrame = (10 * 60 + 10) * 30;
BP(\di).startFrame = (9 * 60 + 30) * 30;
BP(\di).startFrame = 10 * 60 * 30;

BP(\di).player.trace;
BP(\di).fixer.trace;

(5006.81 - 4962.45) / 60

BP(\di).buf.getn(0, 10, _.postln);

4962.45 + (10.5 * 60)

(1000, 1002 .. 1012).do(s.sendMsg(\n_free, _))


s.makeBundle(nil, {
	#[player, fixer].do { |key| BP(\di)[key].trace }
});

BP(\di).play;
BP(\di).stop;

q = BP(\di);
q.buf



// get raw max velocity (5th channel)
f = SoundFile.openRead(topEnvironment[\sampleDir] +/+ "arms/hands-1_data2.wav");
f.readData(z = FloatArray.newClear(f.numFrames * f.numChannels));
f.close;

z.clump(5).flop.last.maxItem
// 18.136728286743

BP(\di).maxVel.spec_(#[0, 20, lin]).value_(9);
BP(\di).maxVel.gui;


// checking hand-stacking y data
f = SoundFile.openRead(BP(\di).buf.path);
f.readData(z = FloatArray.newClear(f.numFrames * f.numChannels));
f.close;

z = z.clump(5).flop;
a = z[2];
b = z[3];

[a.minItem, a.maxItem]
[b.minItem, b.maxItem]

PR('stacking') => BP(\stk);
Fact('armsChordVC') => VC(\ac);
VC(\ac) => BP(\stk);

BP(#[di, stk]).play(0);
u = Updater(BP(\di), { |obj, what, more|
	var	saveRoot,
		stopFunc = { |obj, what, more|
			if(more == \stopped) {
				BP(\stk).removeDependant(stopFunc);
				BP(\stk).root = saveRoot.debug("reset root");
			}
		};
	if(more == \stopped) {
		u.remove;
		saveRoot = BP(\stk).root.debug("saved root");
		BP(\stk).root = nil;
		BP(\stk).addDependant(stopFunc);
	};
});

BP.all.stop;
u.remove;

[-0.7, -0.3] * 0.5 + 0.5
BP(\stk).root = Plazy({ ~ymaxCtl.asPattern.linlin(0.15, 0.35, 23.5, 39.49).round });

BP(\stk).ymaxCtl.bus
BP(\di).bus

KrBusWatcher.newFrom(s).nodes


// exploring new data file
~sampleDir = thisProcess.nowExecutingPath.dirname.dirname +/+ "samples";

b = Buffer.readAndQuery(s, ~sampleDir +/+ "vizdata/Affectations_KC1_Data.wav");

SynthDef(\maxesmins, { |bufnum|
	var i = Phasor.ar(0, 1, start: 0, end: b.numFrames + 100),
		sig = BufRd.ar(b.numChannels, bufnum, i, loop: 0, interpolation: 1),  // no interp
		min = RunningMin.ar(sig),
		max = RunningMax.ar(sig),
		sum = Integrator.ar(sig, coef: 1),  // 1 == no leak
		done = i >= b.numFrames,
		chanI = (0 .. (b.numChannels - 1));
	Poll.ar(done, min, ["min ", chanI].flop.collect(_.join));
	Poll.ar(done, max, ["max ", chanI].flop.collect(_.join));
	Poll.ar(done, sum / b.numFrames, ["avg ", chanI].flop.collect(_.join));
	FreeSelf.kr(done);
}).add;

a = Synth(\maxesmins, [bufnum: b]);

var	chanI = (0 .. (b.numChannels - 1));
["min ", chanI].flop.collect(_.join);

"[min, max, avg]".postln;
[0, 0, -0.995833, -0.995076, -0.995076, -0.994444, -0.988294, -0.989363, 0, 0, 7866.01, 34, 0.990799, 0.992708, 0.990799, 0, 0.966588, 0.176113, 7.64443, 1.65159, 6414.72, 12.3625, -0.209681, 0.304227, 0.0481094, -0.905037, 0.129889, -0.436496, 0.193188, 0.0412316].clump(10).flop.do(_.postln); ""

// (time in sec.), (# markers), (XMin), (XMax), (XAvg), (YMin), (YMax), (YAvg), (VMax), (VAvg)
[min, max, avg]
[ 0, 7866.01, 6414.72 ]
[ 0, 34, 12.3625 ]
[ -0.995833, 0.990799, -0.209681 ]
[ -0.995076, 0.992708, 0.304227 ]
[ -0.995076, 0.990799, 0.0481094 ]
[ -0.994444, 0, -0.905037 ]
[ -0.988294, 0.966588, 0.129889 ]
[ -0.989363, 0.176113, -0.436496 ]
[ 0, 7.64443, 0.193188 ]
[ 0, 1.65159, 0.0412316 ]

b.free;