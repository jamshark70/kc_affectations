MIDIPort.init([2]);
MIDIPort.autoFreeSockets = false;

s.options.preferredDeviceFunc_(nil).device_("Aggregate Device");

BP.loadGui;

MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

(Document.current.path.dirname.dirname +/+ "common/common-defs.scd").loadPath;
(Document.current.path.dirname +/+ "arms-defs1.scd").loadPath;

~master.doWhenReady { PeakMonitor(~master) };


m = MixerChannel(\test1, s, 1, 2/*, level: 0.1*/, outbus: ~master);
n = MixerChannel(\test2, s, 2, 2/*, level: 0.1*/, outbus: ~master);
m => MCG(0); n => MCG(1);

[m, n].do { |mx|
	// mx.outbus = ~master;
	mx.sendsSignalTo(~glrvbmc);
	mx.sendsSignalTo(~lcrvbmc);
};

~master => MCG(7);
~glrvbmc => MCG(5);
~lcrvbmc => MCG(6);

PeakMonitor(m);
PeakMonitor(n);
PeakMonitor(~master);
PeakMonitor(~glrvbmc);
PeakMonitor(~lcrvbmc);


[~glrvb, ~lcrvb].do(_.run(false)); [~glrvbmc, ~lcrvbmc].do(_.mute(true));
[~glrvb, ~lcrvb].do(_.run(true)); [~glrvbmc, ~lcrvbmc].do(_.mute(false));

~glrvb.synth.trace;

VoicerProxy.new => VP.prNew(0);
4.do { VP(0).v.addControlProxy(VoicerGCProxy(nil, VP(0).v), addAlways: true) };
VP(0).v.gui;


o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;

o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;



/**** check ac sound ****/

Fact(\armsChordVC) => VC(\ac);

k = VoicerMIDISocket(0, VP(2).v);
k.noteOnArgsPat = Pbind(\mod_lev, Pkey(\velocity).linlin(0, 127, 0.5, 6.0), \finalAmp, -15.dbamp).trace;

q = VC(\ac).env.target.playfx(Instr("busfx.chorus")/*.listArgs*/, [0, 2]); q.gui;

q.run(false);
q.run(true);

q = MultiEQ(2, \hishelf, 3654.349, 4.274.dbamp, 1, \eq, 301.329, -5.641.dbamp, 1.286).edit(VC(\ac).env.target);

VC(\ac).v.trace;
k.free;


/**** need a couple of other voicers ****/

Library.at(WrapInstr, \osc2).keys.asArray.sort;

(
// from violin piece - modified
(keys: #[master, glrvbmc, lcrvbmc],
numRows: 8,
numCols: 8,
env: Env.adsr(1, 0.4, 0.8, 1.2, curve: -2),
fenv: Env.one,
graphInsert: nil,
make: { |name|
	var	tempAmps = { |i| Array.triangleAmps((20000 / ((4+i) * 12).midicps).asInteger) } ! ~numRows,
		out;

	~target = MixerChannel(name, s, 2, 2, outbus: ~master, completionFunc: { |chan|
		var	patch = chan.playfx(Instr("busfx.chorus2"), [0, 1, 2, 3, 0.006957213735427, 0.1708276390401, 0.0034747717625074, 1.1689647098094, 0.3]);
		patch.doWhenPlaying({
			patch.synth.moveToTail(chan.effectgroup);
		});
		// EQ?
	});
	[~glrvbmc, ~lcrvbmc].do { |mc|
		mc.tryPerform(\receivesSignalFrom, ~target);
	};

		// generate a matrix of buffers
		// if numCols is 8, 0-7 have the most partials, 8-15 have fewer, etc.
		// each column is randomized differently for more animation in higher partials
	~bufs = Buffer.allocConsecutive(~numRows * ~numCols, s, 2048, 1);
	fork {
		~bufs.do({ |buf, i|
			var	amps = tempAmps[i div: ~numCols];
0.06.wait;
			buf.sine1(amps + ({ 0.12.rand2 } ! amps.size))
		});
"done generating buffers".debug;
	};

	WrapInstr([\osc2, \vosc3matrix], { arg freq, gate, bufbase, bufmod, env, vsens, detune,
		ffreq, rq, fenv, fenvsens = 1,
		numrows, numcols, basefreq, topfreq,
		attackTimeScale, decayTimeScale;
		var	sig1, sig2, amp, buf;
		var	baselog = log2(basefreq),
			freqmap = ((log2(freq) - baselog) * (numrows / (log2(topfreq) - baselog)))
				.clip(0, numrows - 2.001),
			fmapfloor = freqmap.floor,
			fmapfrac = freqmap - fmapfloor,
			detunedown = freq/detune,
			detuneup = freq*detune,
			// env timescale handling: [0] is filter eg, [1] is amp
			envs = LocalIn.kr(2),
			eg_test = envs.collect { |eg| Select.kr(Impulse.kr(0), [eg, 0]) },
			// once envelope starts going down, attack phase is over
			hit1 = PulseCount.kr(HPZ1.kr(eg_test) < 0) > 0,
			timeScales = Select.kr(hit1, [attackTimeScale, decayTimeScale]);
		amp = Latch.kr(Sensitivity.kr(1, gate, vsens), gate);
		buf = bufbase + (fmapfloor * numcols) + bufmod;
		#sig1, sig2 = VOsc3.ar([buf, buf+numcols], detunedown, freq, detuneup);
		eg_test = [fenv, env].collect { |e, i|
			EnvGen.kr(e, gate, timeScale: timeScales[i], doneAction: 2 * i);
		};
		LocalOut.kr(eg_test);
		ffreq = (ffreq * Sensitivity.kr(1, eg_test[0], fenvsens)).clip(20, 20000);
		RLPF.ar(XFade2.ar(sig1, sig2, fmapfrac.madd(2, -1), amp),
			ffreq, rq, mul: eg_test[1]);
	}, [\freq, \amp, #[0, 1000, \linear, 1, 0], #[0, 20], EnvSpec(Env.adsr), #[0, 1], #[0.9, 1.1, \linear, 0, 1], \freq, #[1, 0.001], EnvSpec(Env.one), nil, #[0, 20, \lin, 1, 0], #[0, 20, \lin, 1, 0], \freq, \freq, #[0.01, 10, \exp, 0, 1], #[0.01, 10, \exp, 0, 1]]);

	~defname = (name ++ "def").asSymbol;
	\addRvbOut.eval(~defname, { |pan, finalAmp = 1, freq = 440, freqlag = 0, gate = 1, ffreq = 14000, rq = 1, vsens = 0.8, fenvsens = 1, attackTimeScale = 1, decayTimeScale = 1|
		var	sig = WrapInstr("osc2.vosc3matrix").valueArray([
			Lag.kr(freq, freqlag), gate,
			~bufs[0].bufnum,  // bufbase
			{	var	rate = Rand(0.7, 1.4),
					dur = rate.reciprocal,
					pulse = Impulse.kr(rate),
					buf = Demand.kr(pulse, 0, Dseq([
						Dwhite(0.0, ~numCols * 0.25, 1),
						Dwhite(~numCols * 0.7, ~numCols-1.001, 1)
					], inf));
				EnvGen.kr(Env([Rand(~numCols * 0.7, ~numCols-1.001), buf], [dur]), pulse)
			},
			~env,
			vsens, /*detune:*/ 1.003,
			ffreq, rq, ~fenv, fenvsens,
			~numRows, ~numCols,
			/*basefreq:*/ 48.midicps, /*topfreq:*/ (11*12).midicps,
			attackTimeScale, decayTimeScale
		]);
		~graphInsert !? { sig = ~graphInsert.(sig) };
		Pan2.ar(sig, pan, finalAmp)
	}).add;

	out = Voicer(25, ~defname, target: ~target);
	
	out.mapGlobal(\ffreq, nil, 14000, \freq);
	out.mapGlobal(\rq, nil, 1.0, \myrq);
	// out.mapGlobal(\fenvsens, nil, 1.0, #[0.1, 15, \exp]);
	
	// ~target.doWhenReady({ |chan|
	// 	chan.playfx({ |outbus|
	// 		RLPF.ar(In.ar(outbus, 1),
	// 			out.globalControls[\ffreq].kr, 
	// 			out.globalControls[\rq].kr
	// 		)
	// 	})
	// });
	
	out
}, free: { [~target, ~bufs].free }, type: \voicer) => Fact(\shimmerpad);
)

();
VC(\sp).free;
// Fact(\shimmerpad) => VC(\sp);

Fact(\shimmerpad).chuck(VC(\sp), nil, (
	env: Env.adsr(0.5, 0.4, 0.8, 1.8, curve: -2),
	fenv: Env.adsr(0.5, 0.5, 0.1, 3, peakLevel: 1, bias: 1) //.postcs
));

VC(\sp) => VP(1);

VC(\sp).v.unmapGlobal(\ffreq);
VC(\sp).v.unmapGlobal(\fenvsens);
VC(\sp).v.mapGlobal(\vsens, nil, 0.8);

k = VoicerMIDISocket(0, VP(1).v);

k.noteOnArgsPat = Pbind(
	\attackTimeScale, Pkey(\velocity).linlin(0, 127, 1, 0.1),
	\decayTimeScale, Pkey(\attackTimeScale),
	\angle, Ptime() * 2pi / 12 - 0.5pi,
	// \distance, sin(Pkey(\angle)).linlin(-1, 1, 5, 50),
	// \pan, cos(Pkey(\angle)),
	// \distance, Pkey(\velocity).linlin(0, 127, 50, 5),
	// \pan, Pwhite(-1.0, 1.0, inf),
	\ffreq, Pkey(\midinote).midicps * 4,
	\fenvsens, Pkey(\velocity).linlin(0, 127, 0, 7),
	\distFar, 50,
	\glrvbout, ~glrvbmc.inbus.index,
	\lcrvbout, ~lcrvbmc.inbus.index,
	\glrvbamt, 0.2,
	\lcrvbamt, 0.1,
	\finalAmp, -15.dbamp
);

MIDIPort.at(0).sockets.copy.do(_.free);

VC(\sp).v.nodes[0].inspect;
VC(\sp).v.trace;

/**** TODO Sunrise ****/

// { |array, balanceTest({ |item| item < 0 })|
// 	var	toBalance = Array(array.size),
// 		result = Array(array.size),
// 		copy = array.copy,
// 		numBalance, useBalanceItem;
// 	array.do { |item|
// 		if(balanceTest.(item)) {
// 			toBalance.add(item);
// 			copy.take(item);
// 		};
// 	};
// 	numBalance = toBalance.size div: 2;
// copy.debug("copy");
// toBalance.debug("toBalance");
// numBalance.debug("numBalance");
// 	// result 1st half, only use half of balance items
// 	(array.size.debug("array size") div: 2).debug("first half").do { |i|
// 		if(numBalance > 0 and: { (toBalance.size / copy.size).coin }) {
// 			result.add(toBalance.takeAt(toBalance.size.rand));
// 			numBalance = numBalance - 1;
// 		} {
// 			result.add(copy.takeAt(copy.size.rand))
// 		};
// 	};
// 	(copy ++ toBalance).scramble.do { |item| result.add(item) };
// 	result
// } => Func(\shufBalanceSome);

IdentityWeighBag.with(#[1, 2, 3])
.inspect

// cuz WeighBag sux
Proto {
	~prep = { |array, counts|
		~array = array;
		~counts = counts;
		~weights = counts.normalizeSum;
		~numItems = counts.sum;
		currentEnvironment
	};
	~add = { |item, num = 1|
		var	i = ~array.indexOf(item);
		if(i.notNil) {
			~counts[i] = ~counts[i] + num;
			~numItems = ~numItems + num;
		} {
			~array = ~array.add(item);
			~counts = ~counts.add(num);
		};
		~weigh.();
	};
	~get = { |i| ~array[i] };
	~remove = { |item|
		var	i = ~array.indexOf(item);
		if(i.notNil) {
			if(~counts[i] > 1) {
				~counts[i] = ~counts[i] - 1
			} {
				~array.removeAt(i);
				~counts.removeAt(i);
			};
			~weigh.();
		};
	};
	~choose = { ~array.wchoose(~weights) };

	~weigh = {
		~numItems = ~counts.sum;
		~weights = ~counts / ~numItems;
	};
} => PR(\fixedWeighBag);



{ |array, weights|
	var	bag = PR(\fixedWeighBag).prep(array, weights),
		balCounts = bag.counts div: 2,
		bcsum = balCounts.sum,
		indices = balCounts.collectIndices(_ > 0),
		i,
		result = Array(weights.sum);
	// first half, use half of each
"first while".debug;
	while { bcsum > 0 }
	{
		result.add(bag.get(i = indices.wchoose(balCounts.normalizeSum)));
		bag.remove(result.last);
		balCounts[i] = balCounts[i] - 1;
		bcsum = bcsum - 1;
	};
"second while".debug;
	while { bag.size > 0 } {
		result.add(bag.choose);
		bag.remove(result.last);
	};
	result
} => Func(\shufBalance);

\shufBalance.eval([-1, 1, 2, 3], [6, 9, 11, 4])


Error.debug = true;
Error.debug = false;

p = Pbind(
	\voicer, VC(\ac).v,
	\finalAmp, -18.dbamp,
	\pan, 0,
	\distance, 5,
	\dur, Pseg(
		Pseq(#[0.5, 0.1, 0.5], 1),
		3, \exp
	),
	\diff, Pdiff(Pkey(\dur)),
	\freq, Pseries(26,
		Pseq(\shufBalance.eval([-1, 1, 2, 3], [6, 9, 11, 4]).postln, 1)
			* Pif(Pkey(\diff) > 0, -1, 1),
		inf
	),
	\mode, \g,
	\gate, Pkey(\dur).linlin(0.1, 0.5, 0.6, 0.2),
	\mod_lev, 2.5,
	\count, Pseries(1, 1, inf),
	\length, Pif(Pkey(\count) < 18, Pwhite(2.0, 3.5, inf),
		(Pwhite(3.6, 4.8, inf) - Pseries(0, Pkey(\dur), inf))), //.trace,
	\attackTimeScale, 1,
	\decayTimeScale, 1
)/*.trace(\count)*/.play(protoEvent: ProtoEvent(\voicerNote).copy);

o.remove;
o = OSCresponderNode(s.addr, '/n_end', { |t, r, m| /*r.remove;*/ [t, m].postln }).add;

Pbind(
	\type, \rest,
	\delta, Pseg(
		Pseq(#[0.5, 0.1, 0.5], 1),
		3, \exp
	),
	\count, Pseries(1, 1, inf)
).trace(\count).play;




/**** TODO Hand stacking ****/

p = Pbind(
	\voicer, VC(\ac).v,
	\finalAmp, -18.dbamp,
	\pan, 0,
	\distance, Pseq([
		Pseries.fromEndpoints(18, 5, 42),
		Pseries.fromEndpoints(5, 18, 42)
	]),
	\dur, Pseg(
		Pseq(#[0.5, 0.1, 0.5], 1),
		5, \exp
	),
	\diff, Pdiff(Pkey(\dur)),
	\freq, Pscratch(
		Pseries(26, Pseq(\shufBalance.eval([-1, 1, 2, 3], [6, 8, 10, 5]), 1)
			* Pif(Pseries(0, 1, inf) >= 14, -1, 1), inf),
		Pseq([1, Pseq(#[1, 1, -1], inf)], 1)
	),
	\mode, \g,
	\gate, Pkey(\dur).linlin(0.1, 0.5, 0.6, 0.2),
	\mod_lev, 2.5,
	\count, Pseries(1, 1, inf),
	\durMul, Pseq(#[0.4, 0.4, 1], inf),
	\dur, Pkey(\dur) * Pkey(\durMul),
	\length, Pif(Pkey(\count) < 72, Pwhite(1.2, 2.5, inf),
		(Pwhite(3.6, 4.8, inf) - Pseries(0, Pkey(\dur), inf))), //.trace,
	// \length, Pkey(\dur) * 4.5, // Pwhite(2.0, 3.5, inf),
	\attackTimeScale, 0.1,
	\decayTimeScale, 1,
	\pan, Pclutch(Pseq(#[-1, 1], inf, { 2.rand }), Pdelay(Pkey(\durMul), 1) >= 1)
)/*.trace(\count)*/.play(protoEvent: ProtoEvent(\voicerNote).copy.proto_(~rvbEvent.proto.copy.putAll((glrvbamt: 0.7, lcrvbamt: 0.16))));

VC(\ac).v.playingNodes[0].trace;

p.stop;

Pbind(
	\type, \rest,
	\delta, Pseg(
		Pseq(#[0.5, 0.1, 0.5], 1),
		5, \exp
	) * Pseq(#[0.4, 0.4, 1], inf),
	\count, Pseries(1, 1, inf)
).trace(\count).play;

[6, 9, 11, 4] / 30 * 84


// revision for slower version
// need Psetp but for multiple values
(
Proto {
	~canEmbed = true;
	~prep = { |outerPat, innerPat|
		~outerPat = outerPat;
		~innerPat = innerPat;
		currentEnvironment
	};
	~embedInStream = { |inval|
		var outerStream = ~outerPat.asStream,
			innerStream,
			outerEvent, innerEvent;
		while { (outerEvent = outerStream.next(inval)).notNil } {
			innerStream = ~innerPat.asStream;
			while { (innerEvent = innerStream.next(inval.copy.putAll(outerEvent))).notNil } {
				innerEvent.putAll(outerEvent);
				inval = innerEvent.yield;
			};
		};
		inval
	};
	~asStream = { Routine { |inval| ~embedInStream.(inval) } };
	~asPattern = { Prout { |inval| ~embedInStream.(inval) } };
	~play = { |clock, protoEvent, quant|
		~asPattern.().play(clock, protoEvent, quant)
	};
} => PR(\psetp2);
)

();
// test case, good
p = PR(\psetp2).copy.prep(
	Pbind(\a, Pseries(0, 1, 2), \b, Pkey(\a) * 2),
	Pbind(\c, Pgeom(2, 2, 4))
);

q = p.asStream;
q.next(());


// ok shape - work on note overlaps, pan/distance
// control top pitch
// can lorne give height? --> root pitch?

~lastPoint = 200@200;

w = Window("test", Rect(800, 100, 400, 400));
u = UserView(w, w.view.bounds.insetBy(2, 2))
.drawFunc_({ |view|
	Pen.fillOval(Rect.aboutPoint(~lastPoint, 3, 3))
});
w.front;

PeakMonitor(VC(\ac).env.target)

(
p = PR(\psetp2).copy.prep(
	Pbind(
		\root, Pstutter(Pwrand(#[1, 2], #[0.8, 0.2], inf), Pseq([
			Pwhile1({ |inval, next| next < 40 },
				Pseries(26, Pwrand(#[1, 2, 3], #[1, 4, 3].normalizeSum, inf), inf)
			),
			Pwhile1({ |inval, next| next >= 21 },
				Pseries(40, Pwrand(#[-1, -2, -3], #[1, 4, 3].normalizeSum, inf), inf)
			)
		])), //.trace(prefix: "root: "),
		\num, Pexprand(2.5, 6.499, inf).round //Pwhite(3, 6, inf)
	), //.trace,
	Pseq([
		Pbind(
			\voicer, VC(\ac).v,
			\finalAmp, -18.dbamp,
			\angle, Pseries(
				{ 2pi.rand },
				Pwhite(0.1, 0.4, inf) * Pstutter(inf, Prand(#[-1, 1], 1)),
				inf
			).asStream,  // asStream retains continuity between Pbinds
			\radius, Paccumbounce(0.2, 1, Pexprand(0.04, 0.1, inf)).asStream,
			\pan, cos(Pkey(\angle)) * Pkey(\radius),
			\distance, (sin(Pkey(\angle)) * Pkey(\radius)).linlin(-1, 1, 5, 20),
			\dur, Plazy({ |ev|
				Pgeom.fromEndpoints(rrand(0.2, 0.32), rrand(0.09, 0.14), ev[\num])
					* Pexprand(0.75, 1.333, inf)
			}),
			\freq, Pwhile1({ |ev, next| next <= 54 },
				Pkey(\root) + Pseries(0, 
					Pwrand(#[1, 2, 3, 4], #[1, 4, 3, 2].normalizeSum, inf), Pkey(\num).asStream)
			),
			\mode, \g,
			\gate, 0.5, // Pkey(\dur).linlin(0.1, 0.5, 0.6, 0.2),
			\mod_lev, 2.5,
			// \length, 0.15,
			// \length, Pkey(\dur) * 4.5,
			// \length, Pwhite(2.0, 3.5, inf),
			// earlier notes in 1 chord will hold longer -- all cut off w/in 1.5 sec of each other
			\length, Pwhite(3.0, 4.5, inf) - Pseries(0, Pkey(\dur), inf),
			\attackTimeScale, 0.25,
			\decayTimeScale, 1
		)/*.collect { |ev|
			defer {
				topEnvironment[\lastPoint] = Point(
					ev[\pan].linlin(-1, 1, 0, 396),
					ev[\distance].linlin(5, 20, 396, 0)
				);
				u.refresh;
			};
			ev
		}*/,
		Pbind(
			\freq, #[],
			\dur, Pwhite(0.15, 0.35, 1),
			\length, 0.2,
			\gate, 0.1
		)
	], 1)
).play(nil, ProtoEvent(\voicerNote).copy.proto_(~rvbEvent.proto.copy.putAll((glrvbamt: 0.7, lcrvbamt: 0.16))));
)

p.stop;

p.isPlaying;


/**** TODO 9:28 sequence [0/2] ****/
/***** TODO Apply inversions note sequences to another sound ****/

~slideNotes = (
	lauraslide: Pseries(
		{ rrand(-7, 0) },
		Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
		Pkey(\numEv).asStream
	),
	inversion1: Pseries(
		{ rrand(-3, 4) },
		Pstutter(
			Pseq([Pfuncn({ |ev| (ev[\numEv] * 0.6).round }), 100], 1),
			Pseq([1, -1], 1)
		) * Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
		Pkey(\numEv).asStream
	),
	inversion2: Pseries(
		{ rrand(0, 8) },
		Pstutter(
			Pseries(1, 1, inf),
			Pseq([1, -1], inf, 0 /*, { 2.rand }*/)
		) * Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
		Pkey(\numEv).asStream
	)
);

(
var	timer = Ptime().asStream;
p = PR(\psetp2).copy.prep(
	Pbind(
		\gest, Pseq(#[inversion1, inversion2, lauraslide], 1),
		\numEv, Pwhite(12, 19, inf),
		\totalDur, Pwhite(2.5, 4.0, inf),
		\timeIsNow, timer
	),
	Pseq([
		Pbind(
			// \voicer, VC(\ac).v,
			\voicer, VC(\sp).v,
			\finalAmp, -18.dbamp,
			\pan, Plazy({ |ev|
				Pseries.fromEndpoints(rrand(-1.0, -0.5), rrand(0.5, 1.0), ev[\numEv])
				* #[-1, 1].choose
			}),
			\distance, Plazy({ |ev|
				Pseries.fromEndpoints(rrand(15.0, 18.0), rrand(5.0, 7.0), ev[\numEv])
			}),
			\dur, Plazy({ |ev|
				Pgeom.fromEndpoints(rrand(0.12, 0.22), rrand(0.06, 0.09), ev[\numEv])
					* Pexprand(0.75, 1.333, inf)
			}),
			\freq, Pwhile1({ |ev, next| next <= 54 },
				Pnsym(Pfin(1, Pkey(\gest)), ~slideNotes) + 28
			),
			\mode, \g,
			\ffreq, Pfunc { |ev| Mode(ev[\mode]).cps(ev[\freq]) * 4 },
			\gate, Pkey(\freq).linlin(14, 54, 0.1, 0.8),
			\mod_lev, 2.5,
			// \length, 0.15,
			// \length, Pkey(\dur) * 4.5,
			// \length, Pwhite(2.0, 3.5, inf),
			// earlier notes in 1 chord will hold longer -- all cut off w/in 1.5 sec of each other
			\length, (Pwhite(0.8, 1.2, inf) * Pkey(\totalDur)) - Pseries(0, Pkey(\dur), inf),
			\attackTimeScale, Pkey(\gate).linlin(0.1, 0.8, 1.4, 0.15),
			\decayTimeScale, 1
		)/*.collect { |ev|
			defer {
				topEnvironment[\lastPoint] = Point(
					ev[\pan].linlin(-1, 1, 0, 396),
					ev[\distance].linlin(5, 20, 396, 0)
				);
				u.refresh;
			};
			ev
		}*/,
		Pbind(
			\freq, #[],
			\dur, Pfuncn { timer.next } - Pkey(\timeIsNow) + Pwhite(0.25, 0.65, 1),
			\length, 0.2,
			\gate, 0.1
		)
	], 1)
).play(nil, ProtoEvent(\voicerNote).copy.proto_(~rvbEvent.proto.copy.putAll((glrvbamt: 0.7, lcrvbamt: 0.16))));
)

p.stop;

p.isPlaying

/***** TODO What else? ****/


/**** TODO Axial variations [0/2] ****/
/***** TODO Shiva ****/

Fact(\armsmelVC) => VC(\am);
VC(\am) => VP(0);

k.free;
k = VoicerMIDISocket(0, VP(0).v);

BP(\am).free;
PR(\melody) => BP(\am);

p = BP(\am);
p.prepareForPlay;

p.triggerOneEvent(0);

p.stop(0);

p.do(_.free);
p = 3.collect { |i|
	var	bp = PR(\melody) => BP(("am" ++ i).asSymbol);
	bp.pan = #[0, -0.8, 0.8][i];
	0 => bp;
};

p.do { |bp, i|
	bp.event.distFar_(50).lcrvbamt_(0.035).ampMul_(nil);
	// bp.distance = sin(Pseries(-0.5pi + 0.4.rand2, rrand(0.1, 0.18), inf)).linlin(-1, 1, 42, 12);
	// bp.gate = Pswitch1(
	// 	[	Pexprand(0.1, 0.4, inf),
	// 		Pwhite(0.45, 0.75, inf)
	// 	], Pwrand(#[0, 1], #[0.9, 0.1], inf)
	// );
	bp.gate = Pseg(
		Pstutter(2, Pseq([
			Pexprand(0.1, 0.22, 1),
			Pwhite(0.6, 0.9, 1)
		], inf)),
		// hold, then slide
		Ppatlace([
			Pwhite(3.0, 8.0, inf),
			Pwhite(1.1, 2.2, inf)
		], inf)
	);
	// /*if(i == 0) {*/ bp.gate = bp.gate.trace(prefix: "%: ".format(i)) /*}*/;
	bp.distance = Pkey(\gate).linlin(0.1, 0.75, 45, 8);
};


p = BP(#[am0, am1, am2]);

p.do(_.prepareForPlay);
p.do(_.asEventStreamPlayer);
p.do(_.triggerOneEvent(0));

BP(\am0).eventStreamPlayer.event
BP(\am0).event

p.stop;

p.do { |bp| bp.reset };
i = 1;

k.free;
k = BasicMIDISocket(1, { |num|
	if(num == 60) {
		min(3, i).do { |j|
			BP(("am" ++ j).asSymbol).triggerOneEvent(0);
		};
		if(0.5.coin) { BP(\tc).triggerOneEvent(0.1) };
		i = i + 1;
	};
});

BP.all.stop;


// quieter, supporting chords

VC(\btp).free;
// Fact(\shimmerpad) => VC(\sp);

Fact(\shimmerpad).chuck(VC(\btp), nil, (
	env: Env.adsr(0.5, 0.4, 0.8, 1.8, curve: -2),
	fenv: Env.adsr(0.5, 0.5, 0.1, 3, peakLevel: 1, bias: 1), //.postcs
	// need some EQ pre-reverb
	graphInsert: { |sig|
		var	hishelf = EQSpec1.newSpec(\hishelf, freq: 8705, k: -6.667.dbamp, rq: 1, sr: 44100);
		sig = HPF.ar(sig, 668);
		sig = StaticEQ.eqFuncs[\hishelf].(sig, hishelf.k, hishelf.a0);
	}
));

VC(\btp) => VP(1);


p = Pbind(
	\voicer, VC(\btp).v,
	\mode, \g,
	\freq, (Pwhite(35, 46, inf) -.x Pseries(0, Pwrand(#[1, 2, 3], #[1, 3, 2].normalizeSum, 3)))
		.clump(3),
	\dur, 4,
	\length, 4,
	\gate, 0.1,
	\attackTimeScale, 2.5,
	\decayTimeScale, 2.5,
	\finalAmp, -6.dbamp,
	\distance, Pwhite(12.0, 18.0, inf),
	\pan, Pwhite(-0.7, 0.7, inf),
	\fenvsens, 0
).play(nil, ProtoEvent(\voicerNote).copy.proto_(~rvbEvent.proto.copy/*.putAll((glrvbamt: 0.7, lcrvbamt: 0.16))*/));

p.stop;

VC(\btp).v.globalControls[\ffreq].watch.automate({
	SinOsc.kr(LFNoise1.kr(0.2).exprange(0.05, 0.12)).exprange(6100, 16500)
}, target: VC(\btp).env.target.fadergroup, addAction: \addToHead);

VC(\btp).v.globalControls[\ffreq].stopWatching.stopAuto;

// MultiEQ(2).edit(VC(\sp).env.target);

VC(\btp).v.playingNodes.choose.synth.trace;


(
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);
	~bpFilter = { |key|
		key = key.asString;
		key[..1] == "am" and: { key[2..].every(_.isDecDigit) }
	};
	~prep = {
		~setBPs.();
		~event.proto = topEnvironment[\rvbEvent].proto;
	};
	~setBPs = { |bpFilter(~bpFilter)|
		~bps = BP.all.select { |bp| bpFilter.(bp.collIndex) };
	};

	~stopCleanup = {
		~event[\voicer].tryPerform(\releaseAll);
	};

	~mode = \g;
	~freq = Pfunc { |ev|
		var	result = Array.new(~bps.size), midi;
		~bps.do { |bp|
			if(bp[\node].notNil and: { (midi = bp[\lastEvent].tryPerform(\at, \midi)).notNil }) {
				result.add(midi.mapMode(ev[\mode]));
			};
		};
		result
	};
	~dur = 4;
	~length = inf;
	~gate = 0.1;
	~attackTimeScale = 2.5;
	~decayTimeScale = 2.5;
	~finalAmp = -6.dbamp;
	~distance = Pwhite(12.0, 18.0, inf);
	~pan = Pwhite(-0.7, 0.7, inf);
	~fenvsens = 0;

	~asPattern = {
		Pbind(
			\mode, BPStream(\mode),
			\freq, BPStream(\freq),
			\dur, BPStream(\dur),
			\length, BPStream(\length),
			\gate, BPStream(\gate),
			\attackTimeScale, BPStream(\attackTimeScale),
			\decayTimeScale, BPStream(\decayTimeScale),
			\finalAmp, BPStream(\finalAmp),
			\distance, BPStream(\distance),
			\pan, BPStream(\pan),
			\fenvsens, BPStream(\fenvsens)
		).collect { |ev|
			~lastEvent !? {
				~lastEvent[\nodes].do { |node, i|
					// releases only if node hasn't been stolen
					node.release(0, (~lastEvent[\lag] ? 0) + (node.server.latency ? 0),
						~lastEvent[\newFreq].wrapAt(i))
				};
			};
			~lastEvent = ev;
			ev
		}
	};
} => PR(\thinChords);
)

BP(\tc).free;
PR(\thinChords) => BP(\tc);
BP(\tc) => VC(\btp);

BP(\tc).prepareForPlay;



/***** TODO Three levels ****/

BP(\sm).free;
PR(\armsSkidMel).chuck(BP(\sm), nil, (
	master: ~master,
	glrvbmc: ~glrvbmc,
	lcrvbmc: ~lcrvbmc
));

BP(\sm).amp = 0.9;

BP(\sm).reset;

2.do { BP(\sm).triggerOneEvent(0) };

BP(\sm).loTime = Pexprand(0.4, 0.6, inf);

BP(\sm).def = \combskid;
BP(\sm).rdecay = 2;
BP(\sm).listVars;
BP(\sm).hiffreq = Pfunc { |ev| Mode(ev[\mode]).cps(ev[\degree] + 28) };

BP(\sm).lpffreq = Plazy({ Pn(~lpffreqCtl.asMap, inf) });
BP(\sm).lpffreq = Pexprand(1200, 7000, inf);

p.free;
p = 3.collect { |i|
	PR(\armsSkidMel).chuck(BP((\sm ++ i).asSymbol), nil, (
		master: ~master,
		glrvbmc: ~glrvbmc,
		lcrvbmc: ~lcrvbmc,
		amp: 0.9
	));
};

p.do { |bp|
	// bp.rewriteLevel = Pn(0, 1) ++ Pseq([1, 2, Pwhite(1, 3, inf)], 1);
	bp.rewriteLevel = Pseq([0, 1, 2, Pwhite(1, 3, inf)], 1);
	bp.loTime = Pwhite(0.22, 0.45, inf);
	bp.hiTime = Pkey(\loTime) * Pexprand(1.0, 1.25, inf);
};

p.do { |bp| bp.reset };
i = Pwhite(0.0, Pgeom(2.0, 0.95, inf), inf).asStream;

k.free;
k = BasicMIDISocket(1, { |num|
	if(num == 60) {
		fork {
			p.scramble.do { |bp|
				2.do { bp.triggerOneEvent(0) };
				i.next.wait;
			};
		};
	};
});

s.controlBusAllocator.debug
BusDict


/**** TODO Duet partnering (S & I) ****/

// let this run for a bit, then hold a chord about the time they pick up Laura

~nodes = nil;
p = Pbind(
	// \protoEvent, Pseq([\polySynthPlayNotify, Pn(\polySynthTrigger, inf)], 1),
	\instrument, VC(\sp).v.nodes[0].defname,
	\node, Pfunc { ~nodes ? 0 },
	\chan, VC(\sp).env.target,
	\mode, \g,
	\high, Pseq([0, 1, Pseq([Pn(0, { rrand(1, 5) }), Pn(1, { rrand(1, 2) })], inf)], 1),
	\prevHigh, Pdelay(Pkey(\high)),
	\top, Pswitch1([
		Paccumbounce(30, 40, Pwrand(#[-1, 1, 2, 3], #[3, 3, 2, 1].normalizeSum, inf)),
		Paccumbounce(38, 47, Pwrand(#[-1, 1, 2, 3], #[3, 3, 2, 1].normalizeSum, inf))
	], Pkey(\high)),
	\degree, (Pkey(\top) -.x Pseries(0, Pwrand(#[1, 2, 3], #[1, 3, 2].normalizeSum, 3)))
		.clump(3),
	\freq, Pfunc { |ev| Mode(ev[\mode]).cps(ev[\degree].scramble) },
	\delta, Pwhite(1, 4, inf),
	\freqlag, Pkey(\delta) * 0.6,
	\finalAmp, -12.dbamp,
	\protoEvent, Pseq([
		\polySynthPlayNotify,
		Pif(Pkey(\prevHigh) > 0, \polySynthPlayNotify, \polySynthTrigger)
	], 1),
	\sustain, Pif(Pkey(\high) > 0, Pkey(\delta) - 0.6, inf),
	\lag, Pif(Pbinop('==', Pkey(\protoEvent), \polySynthPlayNotify), 0,
		Pn(Pseries(0, Pwhite(0.12, 0.25, inf), 3).clump(3), inf)),
	\notifyDependents, { topEnvironment[\nodes] = ~node },
	\collIndex, \fuckingDummyCuzIPutInADumbCondition
).collect { |ev|
	var	sustain;
	if((sustain = ev[\sustain]).notNil and: { ev[\sustain] != inf }) {
		thisThread.clock.sched(sustain, {
			Func(\schedEventBundleArray).doAction(s.latency, 0, s,
				[\n_set, ~nodes.asArray.asOSCArgArray, \gate, 0].flop, true);
			nil
		});
	};
	ev
}.play(nil, ProtoEvent(\monoSupport).copy.proto_(~rvbEvent.proto.copy/*.putAll((glrvbamt: 0.7, lcrvbamt: 0.16))*/));

p.stop; ~nodes.do(_.release);

[\n_set, #[0, 1, 2], \gate, 0].flop
~nodes

(1391..1393).do(s.sendMsg(\n_free, _))

/**** TODO Manipulating Laura ****/

BP(\sm).free;
PR(\armsSkidMel).chuck(BP(\sm), nil, (
	master: ~master,
	glrvbmc: ~glrvbmc,
	lcrvbmc: ~lcrvbmc
));

BP(\sm).amp = 0.4;

BP(\sm).reset;

2.do { BP(\sm).triggerOneEvent(0) };

BP(\sm).loTime = Pexprand(0.4, 0.6, inf);

// THIS STUFF HERE!!
BP(\sm).def = \combskid;
BP(\sm).rdecay = 2;
BP(\sm).listVars;
BP(\sm).hiffreq = Pfunc { |ev| Mode(ev[\mode]).cps(ev[\degree] + 28) };

BP(\sm).lpffreq = Plazy({ Pn(~lpffreqCtl.asMap, inf) });
BP(\sm).lpffreq = Pexprand(1200, 7000, inf);


/**** TODO Stephen solo ****/
// AVOID DEGREES THAT ARE TOO LOW

BP(\sm).event.eventKey = \polySynthPlayer;
BP(\sm).def = \airskid;

BP(\sm).hiffreq = Pfunc { |ev|
	var deg = ev[\degree];
	deg = deg + (#[0] ++ ({ #[-1, -2, -3].wchoose(#[0.1, 0.5, 0.4]) } ! 2).integrate);
	Mode(ev[\mode]).cps(deg + 42)
};

BP(\sm).loTime.postcs

BP(\sm).delta = Pwhite(1.5, 4.0, inf);
BP(\sm).sustain = Pkey(\delta) * Pwhite(1.8, 2.5, inf);


/**** TODO Cradling - drawing bow ****/
// rocking

~nodes = nil;
p = Prout({ |inval|
	[
		#[35, 40],
		#[35, 41],
		#[37, 42, 43, 38, 33]
	].do { |degrees|
		inval = Pbind(
			\instrument, VC(\sp).v.nodes[0].defname,
			\node, Pfunc { ~nodes ? 0 },
			\chan, VC(\sp).env.target,
			\mode, \g,
			\last, Pseq([Pn(false, degrees.size-1), true], 1),
			\top, Pseq(degrees, 1),
			\degree, (Pkey(\top) -.x Pseries(0, Pwrand(#[1, 2, 3], #[1, 3, 2].normalizeSum, 3)))
			.clump(3),
			\freq, Pfunc { |ev| Mode(ev[\mode]).cps(ev[\degree].scramble) },
			\delta, Pif(Pkey(\last), 2, 1),
			\freqlag, 0.2,
			\finalAmp, -12.dbamp,
			\protoEvent, Pseq([
				\polySynthPlayNotify,
				Pn(\polySynthTrigger, inf)
			], 1),
			\sustain, Pif(Pkey(\last), Pkey(\delta) - 0.6, inf),
			// \lag, Pif(Pbinop('==', Pkey(\protoEvent), \polySynthPlayNotify), 0,
			// 	Pn(Pseries(0, Pwhite(0.12, 0.25, inf), 3).clump(3), inf)),
			\notifyDependents, { topEnvironment[\nodes] = ~node },
			\collIndex, \fuckingDummyCuzIPutInADumbCondition
		).collect({ |ev|
			var	sustain;
			if((sustain = ev[\sustain]).notNil and: { ev[\sustain] != inf }) {
				thisThread.clock.sched(sustain, {
					Func(\schedEventBundleArray).doAction(s.latency, 0, s,
						[\n_set, ~nodes.asArray.asOSCArgArray, \gate, 0].flop, true);
					nil
				});
			};
			ev
		}).embedInStream(inval);
	}
}).play(nil, ProtoEvent(\monoSupport).copy.proto_(~rvbEvent.proto.copy/*.putAll((glrvbamt: 0.7, lcrvbamt: 0.16))*/));

p.stop; ~nodes.do(_.release);


(
PR(\abstractProcess).clone {
	~event = (eventKey: \monoSupport);
	~autoRun = false;
	~alwaysReset = true;

	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;
		~distCtl = GenericGlobalControl(\distance, nil, 5, #[5, 20]);
	};
	~useGui = { |vpi| ~distCtl => VP(vpi) };
	~freeCleanup = { ~distCtl.free };

	~topArrays = Pseq([
		#[35, 40],
		#[35, 41],
		#[37, 42, 43, 38, 33],
		Pfunc({
			Pseq([
				Paccumbounce(31, 38,
					Pwrand(#[-1, 1, 2, 3], #[3, 3, 2, 1].normalizeSum, inf) * #[-1, 1].choose,
					rrand(1, 5)
				),
				Pwhite(40, 47, 1)
			], 1)
		})
	], 1);
	~rest = 1;
	~mode = \g;
	~chordAdd = Pseries(0, Pwxrand(#[1, 2, 3, 4], #[2, 3, 2, 0.5].normalizeSum, 3)).clump(3);
	~freq = Pfunc { |ev| Mode(ev[\mode]).cps(ev[\degree].scramble) };
	~deltaBase = 1.2;
	~delta = Plazy({ Pif(Pkey(\last), 2, 1) * BPStream(\deltaBase) });
	~freqlag = 0.2;
	~finalAmp = -12.dbamp;
	~sustain = Pif(Pkey(\last), Pkey(\delta) - 0.6, inf);
	~distance = Plazy({ Pn(~distCtl.asMap, inf) });
	~pan = Pwhite(0.5, 0.9, inf) * Pfunc { #[-1, 0, 1].scramble };

	~runGesture = {
		if(~spawner.notNil) {
			~spawner.seq(~makePhrase.());
		} {
			"BP(%): Not playing; can't run phrase.".format(~collIndex.asCompileString).warn;
		};
	};

	~makePhrase = { |degrees|
		var	num;
		degrees ?? { degrees = ~topArraysStream.next };
		if(degrees.notNil) {
			degrees = degrees.dereference;
			if(degrees.isArray) { degrees = Pseq(degrees, 1) };
			num = degrees.estimateLength;
			Pbind(
				\instrument, ~event[\voicer].nodes[0].defname,
				\node, Pfunc { ~nodes ? 0 },
				\chan, ~event[\voicer].bus.asMixer,
				\last, Pseq([Pn(false, num-1), true], 1),
				\protoEvent, Pseq([
					\polySynthPlayNotify,
					Pn(\polySynthTrigger, inf)
				], 1),
				\mode, BPStream(\mode),
				\top, degrees,
				\degree, Pkey(\top) -.x ~chordAdd,
				\freq, BPStream(\freq),
				\delta, BPStream(\delta),
				\freqlag, BPStream(\freqlag),
				\finalAmp, BPStream(\finalAmp),
				\sustain, BPStream(\sustain),
				\pan, ~panStream.next,
				\distance, ~distanceStream.next
			).collect({ |ev|
				var	sustain;
				if((sustain = ev[\sustain]).notNil and: { ev[\sustain] != inf }) {
					thisThread.clock.sched(sustain, e {
						Func(\schedEventBundleArray).doAction(s.latency, 0, s,
							[\n_set, ~nodes.asArray.asOSCArgArray, \gate, 0].flop, true);
						~nodes = nil;
					});
				};
				ev
			})
		}
	};

	~recvEventNotify = { |nodes, event|
		~nodes = nodes;
	};
	~stopCleanup = {
		~nodes !? {
			~nodes[0].server.listSendBundle(~nodes[0].server.latency,
				~nodes.collect { |node| node.releaseMsg })
		};
		~nodes = nil;
	};

	~asPattern = {
		~topArraysStream ?? { ~makeStreamForKey.(\topArrays) };
		~restStream ?? { ~makeStreamForKey.(\rest) };
		~panStream ?? { ~makeStreamForKey.(\pan) };
		~distanceStream ?? { ~makeStreamForKey.(\distance) };
		Pspawner({ |sp|
			~spawner = sp;
			if(~autoRun) {
				"BP(%): autoRun enabled\n".postf(~collIndex.asCompileString);
				loop {
					sp.seq(~makePhrase.());
					sp.wait(~restStream.next());
				}
			} {
				loop {
					sp.wait(0.1);
				}
			}
		})
	};

	~reset = { ~makeStreamForKey.(\topArrays) };
} => PR(\rockingChords);
)

BP(\rc).free;
PR(\rockingChords) => BP(\rc);
VC(\sp) => BP(\rc);
0 => BP(\rc);
BP(\rc) => MT(1);

BP(\rc).autoRun = true;
BP(\rc).mode = \g;

BP(\rc).chordAdd = Pseries(0, Pwxrand(#[1, 2, 3, 4], #[2, 3, 2, 0.1].normalizeSum, 3)).clump(3);

Paccumbounce.findRespondingMethodFor(\estimateLength);

BP(\rc).reset = { ~makeStreamForKey.(\topArrays) };
BP(\rc).v.reset;
BP(\rc).v[\reset].postcs

BP(\rc).alwaysReset = true;

BP(\rc).topArrays = Pseq([
		#[35, 40],
		#[35, 41],
		#[37, 42, 43, 38, 33],
		Pfunc({
			Pseq([
				Paccumbounce(31, 38,
					Pwrand(#[-1, 1, 2, 3], #[3, 3, 2, 1].normalizeSum, inf) * #[-1, 1].choose,
					rrand(1, 5)
				),
				Pwhite(36, 47, 1)
				// don't work: Pbinop's estimateLength is wrong
				// Pexprand(35.9, 47.4, 1).round
			], 1)
		})
	], 1);

x = BP(\rc).topArraysStream.next;

x.dereference.estimateLength

Pexprand.findRespondingMethodFor(\estimateLength)

BP(\rc).nodes

(1114..1116).do(s.sendMsg(\n_free, _))

/**** TODO Laura solo ****/
