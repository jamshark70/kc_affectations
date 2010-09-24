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



/**** check ac sound ****/

Fact(\armsChordVC) => VC(\ac);

k = VoicerMIDISocket(0, VP(2).v);
k.noteOnArgsPat = Pbind(\mod_lev, Pkey(\velocity).linlin(0, 127, 0.5, 6.0), \finalAmp, -15.dbamp);

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
make: { |name|
	var	tempAmps = { |i| Array.triangleAmps((20000 / ((4+i) * 12).midicps).asInteger) } ! ~numRows,
		out;

	~target = MixerChannel(name, s, 2, 2, level: -23.dbamp, outbus: ~master, completionFunc: { |chan|
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
	\addRvbOut.eval(~defname, { |pan, finalAmp = 1, freq = 440, gate = 1, ffreq = 14000, rq = 1, vsens = 0.8, fenvsens = 1, attackTimeScale = 1, decayTimeScale = 1|
		var	sig = WrapInstr("osc2.vosc3matrix").valueArray([
			freq, gate,
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

{ |array, weights|
	var	bag = IdentityWeighBag.with(array, weights),
		balCounts = bag.counts div: 2,
		indices = balCounts.collectIndices(_ > 0),
		i,
		result = Array(weights.sum);
	// first half, use half of each
	while { indices.size > 0 }
	{
		result.add(bag.at(i = indices.choose));
		bag.remove(result.last);
		balCounts[i] = balCounts[i] - 1;
		if(balCounts[i] == 0) { indices.take(i) };
	};
	while { bag.size > 0 } {
		result.add(bag.choose);
		bag.remove(result.last);
	};
	result
} => Func(\shufBalance);

\shufBalance.eval([-1, 1, 2, 3], #[6, 9, 11, 4])

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
	~asPattern = { Prout { |inval| ~embedInStream.debug.(inval) } };
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

(
p = PR(\psetp2).copy.prep(
	Pbind(
		\root, Pstutter(Pwhite(1, 3, inf), Pseq([
			Pwhile1({ |inval, next| next < 40 },
				Pseries(26, Pwrand(#[1, 2, 3], #[1, 4, 3].normalizeSum, inf), inf)
			),
			Pwhile1({ |inval, next| next > 26 },
				Pseries(40, Pwrand(#[-1, -2, -3], #[1, 4, 3].normalizeSum, inf), inf)
			)
		])),
		\num, Pwhite(3, 6, inf)
	),
	Pseq([
		Pbind(
			\voicer, VC(\ac).v,
			\finalAmp, -18.dbamp,
			\pan, 0,
			\distance, 8,
			// \distance, Pseq([
			// 	Pseries.fromEndpoints(18, 5, 42),
			// 	Pseries.fromEndpoints(5, 18, 42)
			// ]),
			\dur, Plazy({ |ev|
				Pgeom.fromEndpoints(0.4, 0.15, ev[\num]) * Pexprand(0.5, 2.0, inf)
			}),
			\freq, Pkey(\root) + Pseries(0, 
				Pwrand(#[1, 2, 3, 4], #[1, 4, 3, 2].normalizeSum, inf), Pkey(\num).asStream),
			\mode, \g,
			\gate, 0.5, // Pkey(\dur).linlin(0.1, 0.5, 0.6, 0.2),
			\mod_lev, 2.5,
			\length, Pkey(\dur) * 4.5, // Pwhite(2.0, 3.5, inf),
			\attackTimeScale, 0.1,
			\decayTimeScale, 1
		),
		Pbind(
			\freq, #[],
			\dur, Pwhite(0.3, 0.9, 1),
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
/***** TODO What else? ****/
/**** TODO Axial variations [0/2] ****/
/***** TODO Shiva ****/
/***** TODO Three levels ****/
/**** TODO Duet partnering (S & I) ****/
/**** TODO Manipulating Laura ****/
/**** TODO Stephen solo ****/
/**** TODO Cradling - drawing bow ****/
/**** TODO Laura solo ****/
