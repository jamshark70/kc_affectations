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



// exploratory

MIDIPort.init(#[3]);

BP.loadGui;

MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

// (Document.current.path.dirname.dirname +/+ "common/common-defs.scd").loadPath;
(Document.current.path.dirname +/+ "arms-defs1.scd").loadPath;


~master => MCG(7);
~glrvbmc => MCG(5);
~lcrvbmc => MCG(6);

[~glrvb, ~lcrvb].do(_.run(false)); [~glrvbmc, ~lcrvbmc].do(_.mute(true));
[~glrvb, ~lcrvb].do(_.run(true)); [~glrvbmc, ~lcrvbmc].do(_.mute(false));


BP(\di).free;
Fact(\dataIn).chuck(BP(\di), nil, (playTestFile: true, readFrame: 138));

BP(\di).setStartTime(14, 57);  // L's solo
BP(\di).setStartTime(15, 23);  // rise up
BP(\di).setStartTime(15, 07);  // just before

BP(\di).play;
Server.killAll;

BP(\di).fixer.trace;

BP(\di).stop;


// move data to lang
(
PR(\abstractProcess).clone {
	~alwaysReset = true;
	~autoPlay = true;
	~event = (eventKey: \singleSynthPlayNotify);
	~dk = \di;
	~prep = {
		if(BP.exists(~dk).not) {
			"Load BP(%) first.".format(~dk.asCompileString).warn
		} {
			#[bus, trigbus, recvBus, numCh, outCh].do { |key| key.envirPut(BP(~dk)[key]) };
		};

		~def = ~makeDef.();
		~userprep.();

		BP(~dk).addDependant(currentEnvironment);
	};
	~freeCleanup = {
		BP(~dk).removeDependant(currentEnvironment);
		~userfree.();
	};
	~update = { |obj, what, more|
		case
		{ obj.tryPerform(\collIndex) == ~dk } {
			case { ~autoPlay and: { what == \play } } { BP(~collIndex).play }
				{ more == \stopped } { BP(~collIndex).stop }
		}
	};

	~makeDef = {
		SynthDef(("datafetcher" ++ ~outCh).asSymbol, { |bus, useTrigBus, recvBus, trigbus,
			replyID|
			var	sig = In.kr(bus, ~outCh),
				trig = Select.kr(useTrigBus, [
					InTrig.kr(recvBus, 1),
					In.kr(trigbus, 1)
				]) > 0;  // force trig to be exactly 0 or 1
			SendReply.kr(trig, '/datafetch', sig, replyID);
		}).add
	};
	~makeResponder = { |node|
		var	self = currentEnvironment;
		OSCpathResponder(s.addr, ['/datafetch', (node ?? { ~node }).nodeID], { |time, resp, msg|
			self[\latest] = msg[3..];
			BP(self[\collIndex]).changed(\data, self[\latest]);
		}).add;
	};

	// ~preparePlay = {
	// };
	~stopCleanup = {
		~node !? { ~node.free; ~node = nil };
		~resp.do(_.remove); ~resp = nil;
	};
	~recvEventNotify = { |node|
		~node = node;
		~resp = ~makeResponder.(node);
	};
	~asPattern = {
		Pseq([
			(instrument: ~def.name,
				bus: ~bus, useTrigBus: BP(~dk).playTestFile.binaryValue, recvBus: ~recvBus,
				trigbus: ~trigbus, replyID: ~replyID ? 0, addAction: \addToTail,
				delta: 2
			).putAll(~synthEventParms.()),
			Pn((instrument: \rest, delta: 2), inf)
		])
	};
	~synthEventParms = ();
} => PR(\dataReader);
)

BP(\dr).free;
PR(\dataReader) => BP(\dr);
0 => BP(\dr);

u.remove;
u = Updater(BP(\dr), { |obj, what, data|
	data.postln;
});


n = 15;
n = 7;  // c 1/4 sec

(
w = ResizeFlowWindow(\velsum, Rect(5, 50, 300, 100));
z = EZSlider(w, 290@20, "vel sign", #[-1, 1] /*[n.neg, n]*/, initVal: 0);
w.recursiveResize.front;
)

p = Pbind(
	// \type, \setProperties,
	\time, Ptime(),
	\delayed, Pdelay(Pkey(\vel), n),
	\subtract, Pif(Pseries(0, 1, inf) < n, 0, Pkey(\delayed)),
	\value, Paccum(-inf, inf, Pkey(\vel) - Pkey(\subtract), inf, 0).drop(1)
	// \args, #[value],
	// \defer, true,
	// \receiver, z
).asStream;

n = 11;
p = Pbind(
	\time, Ptime(),
	\delayed, Pdelay(Pkey(\vel), 3),
	\subtract, Pif(Pseries(0, 1, inf) < 3, 0, Pkey(\delayed)),
	\diff, Pkey(\vel) - Pkey(\subtract),
	\sign, (Pkey(\diff)).sign,
	\signDly, Pdelay(Pkey(\sign), n),
	\sub2, Pif(Pseries(0, 1, inf) < n, 0, Pkey(\signDly)),
	\value, (Paccum(-inf, inf, Pkey(\sign) - Pkey(\sub2), inf, 0).drop(1) / n),
//	* (Pkey(\vel) / 1.5),
	// \value, Pkey(\diff),
	\colors, [Color.new255(255, 180, 180), Color.new255(180, 255, 180)],
	\play, {
		var ev = currentEnvironment;
		defer {
			z.value = ev[\value]; // * ev[\vel] / 1.5;
			w.view.background = ev[\colors][0].blend(ev[\colors][1], ev[\value]*0.5 + 0.5);
		};
	}
).asStream;

z.sliderView.background = Color.clear;
w.refresh;

w.view.background = Color.clear;

BP(\di).setStartTime(15, 7);  // just before

BP(\di).buf.get(BP(\di).startFrame * BP(\di).buf.numChannels, _.postln);

// p.next((vel: 1)).play;
// p.next((vel: -1)).play;

// problem here is, increasing velocity from near-zero reads the same as big velocity

p.reset;
t = nil;
d = nil;

u.remove;
u = Updater(BP(\dr), { |obj, what, data|
	p.next((vel: data[9 /*23*/])).play;
	// var e = p.next((vel: data[23].sign));  // 23 == 9+14
	// if(t.isNil) { t = e[\time] };
	// if(e[\value].abs > 10 and: { d.isNil or: { d[\value].abs <= 10 } }) {
	// 	[e[\time] - t, data[23].sign, e[\value]].postln;
	// 	t = e[\time];
	// };
	// d = e;
});

f = { |y0, y1, y2, y3, mu|
   var a0,a1,a2,a3,mu2;

   mu2 = mu*mu;
   a0 = y3 - y2 - y0 + y1;
   a1 = y0 - y1 - a0;
   a2 = y2 - y0;
   a3 = y1;

   (a0*mu*mu2)+(a1*mu2)+(a2*mu)+a3;
};

f.(0, 1, 2, 3, (0, 0.1 .. 2.0));

BP(\di).play;
BP(\di).player.trace;
BP(\di).fixer.trace;
BP(\di).stop;

SynthDef(\acceldecel, { |bus, useTrigBus, recvBus, trigbus, upThresh = 0.8, downThresh = 0.15, delaySamps = 3, meanSamps = 11|
	var	sig = In.kr(bus + 9, 1),  // +9 = vavg
		bufsecs = In.kr(bus, 1),
		trigIn = Select.kr(useTrigBus, [
			InTrig.kr(recvBus, 1),
			In.kr(trigbus, 1)
		]) > 0,  // force trig to be exactly 0 or 1
		trig = Trig1.kr(trigIn, ControlDur.ir),
		// demand-rate delay AGAIN
		dbuf = LocalBuf(delaySamps),
		dphase = Demand.kr(trig, 0, Dseq([Dseries(0, 1, delaySamps)], inf)),
		prev = Demand.kr(trig, 0, Dbufrd(dbuf, dphase)),
		diff = sig - prev,
		writer = Demand.kr(trig <! prev, 0, Dbufwr(sig, dbuf, dphase)),
		signmean = MeanTriggered.kr(diff.sign, trig, meanSamps),
		threshDetect = Schmidt.kr(signmean.abs, downThresh, upThresh),
		threshTrig = HPZ1.kr(threshDetect).abs,
		oldTime = Latch.kr(bufsecs, Delay1.kr(threshTrig));
	SendReply.kr(HPZ1.kr(threshTrig).abs, '/acceldecel', [signmean, threshDetect, bufsecs - oldTime, (bufsecs / 60).trunc, (bufsecs % 60).round(0.01)]);
	SendReply.kr(trig, '/accelraw', signmean);
}).add;

q.remove; BP(\di).uv.background_(Color.clear);
q = OSCresponderNode(s.addr, '/acceldecel', { |t, r, m|
	// ~incr = (m[4].abs > 0).binaryValue * m[3].sign;
	// ~prevIncr = ~incr;
	~incr = m[4] * m[3].sign;
	m.postln;
	defer {
		BP(\di).uv.background_(
			switch(~incr.asInteger)
			{ -1 } { Color.gray(0.6) }
			{ 0 } { Color.clear }
			{ 1 } { Color.white }
		)
	};
}).add;

(
var colors = [Color.new255(255, 180, 180), Color.new255(180, 255, 180)];
o.remove;
o = OSCresponderNode(s.addr, '/accelraw', { |t, r, m|
	defer {
		z.value = m[3];
		w.view.background = colors[0].blend(colors[1], m[3]*0.5 + 0.5);
	};
}).add;
)

u.remove;
u = Updater(BP(\di), { |obj, what, more|
	case { more == \stopped } { a.free; a = nil }
		{ what == \play } {
			a = Synth(\acceldecel, [bus: BP(\di).bus, useTrigBus: 1, recvBus: BP(\di).recvBus,
				trigbus: BP(\di).trigbus, upThresh: 0.5, downThresh: 0.1], addAction: \addToTail);
		};
});

a.free;
a = Synth(\acceldecel, [bus: BP(\di).bus, useTrigBus: 1, recvBus: BP(\di).recvBus, trigbus: BP(\di).trigbus, downThresh: 0.1], addAction: \addToTail);

BP(\di).play;

BP(\di).setStartTime(15, 18);

a.trace;
a.free;

SynthDef(\singrain, { |freq = 440, amp = 0.1, sustain = 0.1, out|
	Out.ar(out, (SinOsc.ar(freq, 0, amp)
		* EnvGen.kr(Env.perc(0.05, 0.95), timeScale: sustain, doneAction: 2)) ! 2);
}).add;

~incr = 0;
p = ~master.play(Penvir((prevIncr: 0, sideEffect: { |value| value }), Pbind(
	\instrument, \singrain,
	\dur, Pswitch([
		Plazy({ Env([rrand(0.07, 0.09), rrand(0.4, 0.45)], [rrand(0.4, 0.75)], \exp).asPseg }),
		Plimitsum({ rrand(0.4, 0.75) }, Pswitch([
			Pwhite(0.35, 0.45, inf),
			Pwhite(0.07, 0.1, inf)
		], Pfunc({ (~prevIncr > 0).binaryValue }))),
		Plazy({ Env([rrand(0.4, 0.45), rrand(0.07, 0.09)], [rrand(0.4, 0.75)], \exp).asPseg })
	], Pfunc({
		~sideEffect.(topEnvironment[\incr] + 1, ~prevIncr = topEnvironment[\incr])
	})),
	\fmul, Pgbrown(3/4, 4/3, 0.1, inf),
	\freq, 440 * pow(Pkey(\dur).linlin(0.07, 0.45, Pkey(\fmul), 1), Prand(#[-1, 1], inf)),
	\legato, 0.7
)));

p.stop;

(
(
make: { |name|
	BP(name).free;
	PR(\dataReader).chuck(BP(name), nil, (
		rbufProto: (val: 0, sign: 0, dur: 0),
		rbufSize: 10,
		userprep: {
			~rbuf = { ~rbufProto.copy } ! ~rbufSize;
			~rbufIndex = 0;
		},
		// increasing 'i' goes backward in time
		dataAt: { |i = 0| ~rbuf.wrapAt(~rbufIndex - i) },
		makeDef: {
			SynthDef(\acceldecel, { |bus, useTrigBus, recvBus, trigbus, upThresh = 0.8, downThresh = 0.15, delaySamps = 3, meanSamps = 11|
				var	sig = In.kr(bus + 9, 1),  // +9 = vavg
				bufsecs = In.kr(bus, 1),
				trigIn = Select.kr(useTrigBus, [
					InTrig.kr(recvBus, 1),
					In.kr(trigbus, 1)
				]) > 0,  // force trig to be exactly 0 or 1
				trig = Trig1.kr(trigIn, ControlDur.ir),
				// demand-rate delay AGAIN
				dbuf = LocalBuf(delaySamps),
				dphase = Demand.kr(trig, 0, Dseq([Dseries(0, 1, delaySamps)], inf)),
				prev = Demand.kr(trig, 0, Dbufrd(dbuf, dphase)),
				diff = sig - prev,
				writer = Demand.kr(trig <! prev, 0, Dbufwr(sig, dbuf, dphase)),
				signmean = MeanTriggered.kr(diff.sign, trig, meanSamps),
				threshDetect = Schmidt.kr(signmean.abs, downThresh, upThresh),
				threshTrig = HPZ1.kr(threshDetect).abs,
				oldTime = Latch.kr(bufsecs, Delay1.kr(threshTrig));
				SendReply.kr(HPZ1.kr(threshTrig).abs, '/acceldecel', [signmean, threshDetect, bufsecs - oldTime, bufsecs]);
				SendReply.kr(trig, '/accelraw', signmean);
			}).add;
		},
		makeResponder: { |node|
			var	self = currentEnvironment;
			[
				OSCpathResponder(s.addr, ['/acceldecel', node.nodeID], e { |t, r, m|
					~rbufIndex = (~rbufIndex + 1) % ~rbuf.size;
					~rbuf[~rbufIndex].put(\sign, m[4] * m[3].sign)
						.put(\value, m[3])
						.put(\dur, m[5])
						.put(\time, m[6]);
					NotificationCenter.notify(~collIndex, \accel, ~rbuf[~rbufIndex]);
				}).add,
				OSCpathResponder(s.addr, ['/accelraw', node.nodeID], { |t, r, m|
					self[\mean] = m[3];
					NotificationCenter.notify(~collIndex, \accelraw, m[3]);
				}).add
			]
		},
		upThresh: 0.5,
		downThresh: 0.1,
		delaySamps: 3,
		meanSamps: 11,
		synthEventParms: { (
			upThresh: ~upThresh,
			downThresh: ~downThresh,
			delaySamps: ~delaySamps,
			meanSamps: ~meanSamps
		) }
	));
	0 => BP(name);
}, type: \bp) => Fact(\acceltrig);
)

// change to NotificationCenter
// u.remove;
// u = Updater(BP(\actrk), { |obj, what, data|
// 	if(what == \accel) { data.postln };
// });


NotificationCenter.register(\actrk, \accel, 0, { |data|
	if(data[\sign] > 0) {
		data.postln
	};
});

NotificationCenter.unregister(\actrk, \accel, 0);


BP(\actrk).dataAt([0, 1]).postln; "\n"


BP(\actrk).dataAt(0).sign;


// check height
#[yspan, xspan].collect { |key| BP(\di).dataNames.indexOf(key) };

~yx = Array(600);
u.remove;
u = Updater(BP(\dr), e { |obj, what, data|
	var	yx = data[13] / max(data[12], 0.01) * (data[13] + data[12]);
	~yx.add(yx);
	if(~yx.size == 600) { u.remove; "done".postln };
});

~yx.plot

(
w = ResizeFlowWindow(\velsum, Rect(5, 50, 300, 100));
z = EZSlider(w, 290@20, "yx", #[0, 100], initVal: 0);
w.recursiveResize.front;
)

u.remove;
u = Updater(BP(\dr), e { |obj, what, data|
	var	yx = data[13] / max(data[12], 0.01) * (data[13] + data[12]);
	defer { z.value = yx };
});

(
w = Window(\velsum, Rect(5, 50, 620, 400));
w.drawHook = {
	if(~yx.size > 0) {
		Pen.moveTo(Point(0, 399 - (~yx[0] * 12)));
		~yx.doAdjacentPairs { |y0, y1, x|
			Pen.lineTo(Point(x+1, 399 - (y1 * 12)));
		};
	};
	Pen.stroke;
};
w.front;
)

w.close;

~yx = Array(600);
NotificationCenter.register(\lsyx, \yxraw, 0, { |median|
	if(~yx.size == 600) {
		~yx = ~yx.rotate(-1).put(599, median);
	} {
		~yx.add(median);
	};
	defer { w.refresh };
});

NotificationCenter.unregister(\lsyx, \yxraw, 0);


(
BP(\yxtrk).free;
PR(\dataReader).chuck(BP(\yxtrk), nil, (
	rbufProto: 0,
	rbufSize: 11,
	userprep: {
		~rbuf = { ~rbufProto.copy } ! ~rbufSize;
		~rbufIndex = 0;
	},
	// increasing 'i' goes backward in time
	dataAt: { |i = 0| ~rbuf.wrapAt(~rbufIndex - i) },
	makeDef: {
		SynthDef(\yx, { |bus, useTrigBus, recvBus, trigbus, meanSamps = 11|
			var	sig = In.kr(bus + 12, 2),  // +12 = xspan
			yx = sig[1] / max(sig[0], 0.01) * sig.sum,
			bufsecs = In.kr(bus, 1),
			trigIn = Select.kr(useTrigBus, [
				InTrig.kr(recvBus, 1),
				In.kr(trigbus, 1)
			]) > 0,  // force trig to be exactly 0 or 1
			trig = Trig1.kr(trigIn, ControlDur.ir),
			// demand-rate delay AGAIN
			// dbuf = LocalBuf(delaySamps),
			// dphase = Demand.kr(trig, 0, Dseq([Dseries(0, 1, delaySamps)], inf)),
			// prev = Demand.kr(trig, 0, Dbufrd(dbuf, dphase)),
			// diff = sig - prev,
			// writer = Demand.kr(trig <! prev, 0, Dbufwr(sig, dbuf, dphase)),
			median = MedianTriggered.kr(yx, trig, meanSamps); //,
			// threshDetect = Schmidt.kr(signmean.abs, downThresh, upThresh),
			// threshTrig = HPZ1.kr(threshDetect).abs,
			// oldTime = Latch.kr(bufsecs, Delay1.kr(threshTrig));
			// SendReply.kr(HPZ1.kr(threshTrig).abs, '/acceldecel', [signmean, threshDetect, bufsecs - oldTime, bufsecs]);
			SendReply.kr(trig, '/yxraw', median);
		}).add;
	},
	makeResponder: { |node|
		var	self = currentEnvironment;
		[
			// OSCpathResponder(s.addr, ['/acceldecel', node.nodeID], e { |t, r, m|
			// 	~rbufIndex = (~rbufIndex + 1) % ~rbuf.size;
			// 	~rbuf[~rbufIndex].put(\sign, m[4] * m[3].sign)
			// 		.put(\value, m[3])
			// 		.put(\dur, m[5])
			// 		.put(\time, m[6]);
			// 	BP(~collIndex).changed(\accel, ~rbuf[~rbufIndex]);
			// }).add,
			OSCpathResponder(s.addr, ['/yxraw', node.nodeID], e { |t, r, m|
				self[\median] = m[3];
			 	~rbufIndex = (~rbufIndex + 1) % ~rbuf.size;
			 	~rbuf[~rbufIndex] = m[3];
				BP(~collIndex).changed(\yxraw, m[3]);
			}).add
		]
	},
	// upThresh: 0.5,
	// downThresh: 0.1,
	// delaySamps: 3,
	meanSamps: 11,
	synthEventParms: { (
		// upThresh: ~upThresh,
		// downThresh: ~downThresh,
		// delaySamps: ~delaySamps,
		meanSamps: ~meanSamps
	) }
));
0 => BP(\yxtrk);
)

~yx = Array(600);
NotificationCenter.register(\lsyx, \yxraw, 0, { |median|
	if(~yx.size == 600) {
		~yx = ~yx.rotate(-1).put(599, median);
	} {
		~yx.add(median);
	};
	defer { w.refresh };
});

NotificationCenter.unregister(\lsyx, \yxraw, 0);


BP(\yxtrk).meanSamps = 11;

BP(\yxtrk).rbuf

y = BP(\yxtrk).dataAt((0..10));
y.differentiate.sum.abs / (y[0..9] absdif: y[1..10]).sum


(
(
make: { |name|
	BP(name).free;
	PR(\dataReader).chuck(BP(name), nil, (
		rbufSize: 11,
		makeDef: {
			SynthDef(\yx, { |bus, useTrigBus, recvBus, trigbus, thresh = 4, timeThresh = 0.12,
				countThresh = 4, meanSamps = 11|
				var	sig = In.kr(bus + 12, 2),  // +12 = xspan
				yx = sig[1] / max(sig[0], 0.01) * sig.sum,
				bufsecs = In.kr(bus, 1),
				trigIn = Select.kr(useTrigBus, [
					InTrig.kr(recvBus, 1),
					In.kr(trigbus, 1)
				]) > 0,  // force trig to be exactly 0 or 1
				trig = Trig1.kr(trigIn, ControlDur.ir),
				median = MedianTriggered.kr(yx, trig, meanSamps),
				// dbuf = LocalBuf(~rbufSize),
				// dphase = Demand.kr(trig, 0, Dseq([Dseries(0, 1, ~rbufSize)], inf)),
				// writer = Demand.kr(trig, 0, Dbufwr(median, dbuf, dphase)),
				// all = Demand.kr(trig <! writer, 0, Dbufrd(dbuf, (0 .. ~rbufSize-1))),
				// count = (all > thresh).sum,
				// no MovingSumTriggered...
				count = MeanTriggered.kr(median > thresh, trig, meanSamps) * meanSamps,
				lastTrigTime = Select.kr(Impulse.kr(0), [LocalIn.kr(1), 0]),
				timer = Sweep.kr(1),
				timeSince = timer - lastTrigTime,
				realTrig = trig * (median > thresh) * (count < countThresh) * (timeSince > timeThresh);
				LocalOut.kr(Latch.kr(timer, realTrig));
				SendReply.kr(realTrig, '/xytrig', [yx, timeSince, timer]);
			}).add;
		},
		makeResponder: { |node|
			var	self = currentEnvironment;
			OSCpathResponder(s.addr, ['/xytrig', node.nodeID], { |time, resp, msg|
				msg = msg[3..];
				BP(self[\collIndex]).changed(\xytrig, msg[3..]);
				self.doTrig(msg);
			}).add;
		},
		thresh: 4.0,
		timeThresh: 0.12,
		countThresh: 4,
		meanSamps: 11,
		synthEventParms: { (
			thresh: ~thresh,
			timeThresh: ~timeThresh,
			countThresh: ~countThresh,
			meanSamps: ~meanSamps
		) }
	));
	0 => BP(name);
}, type: \bp) => Fact(\lsoloTrig);
)

BP(\lsyx).free;
Fact(\lsoloTrig) => BP(\lsyx);

();
BP(\lsyx).doTrig = { |data|
	"%: %\n".postf(if(data[0] > 4) { "high" } { " low" }, data);
	if(data[0] < 4) { BP(\lsyx).node.trace };
};

BP(\di).setStartTime(14, 50);

BP(\lsyx).node.trace

p = BP(\lsyx);
p.lowThresh = 1.8;
p.lowSamps = 6;

p.node.trace;