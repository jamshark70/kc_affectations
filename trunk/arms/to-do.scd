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
// note pattern is wrong, hard to get panning and distance to come across

var notes = Pseries(26, Pseq(\shufBalance.eval([-1, 1, 2, 3], [6, 8, 10, 5]), 1)
			* Pif(Pseries(0, 1, inf) >= 14, -1, 1), inf).asStream.all;
p = Pbind(
	\voicer, VC(\ac).v,
	\finalAmp, -6.dbamp,
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
	\freq, Pscratch(Pseq(notes, 1), Pseq([1, Pseq(#[1, 1, -1], inf)], 1)),
	\mode, \g,
	\gate, Pkey(\dur).linlin(0.1, 0.5, 0.6, 0.2),
	\mod_lev, 2.5,
	\count, Pseries(1, 1, inf),
	\durMul, Pseq(#[0.4, 0.4, 1], inf),
	\dur, Pkey(\dur) * Pkey(\durMul),
	// \length, Pif(Pkey(\count) < 18, Pwhite(2.0, 3.5, inf),
	// 	(Pwhite(3.6, 4.8, inf) - Pseries(0, Pkey(\dur), inf))), //.trace,
	\length, Pkey(\dur) * 2.5, // Pwhite(2.0, 3.5, inf),
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
