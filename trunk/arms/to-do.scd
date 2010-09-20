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
k.noteOnArgsPat = (mod_lev: 3);

VC(\ac).v.trace;
k.free;


/**** TODO Sunrise ****/

{ |array, balanceTest({ |item| item < 0 })|
	var	toBalance = Array(array.size),
		result = Array(array.size),
		copy = array.copy,
		numBalance, useBalanceItem;
	array.do { |item|
		if(balanceTest.(item)) {
			toBalance.add(item);
			copy.take(item);
		};
	};
	numBalance = toBalance.size div: 2;
	// result 1st half, only use half of balance items
	(array.size div: 2).do { |i|
		if(numBalance > 0 and: { (toBalance.size / copy.size).coin }) {
			result.add(toBalance.takeAt(toBalance.size.rand))
		} {
			result.add(copy.takeAt(copy.size.rand))
		};
	};
	(copy ++ toBalance).scramble.do { |item| result.add(item) };
	result
} => Func(\shufBalanceSome);

\shufBalanceSome.eval(#[-1, 1, 2, 3].weight(#[6, 9, 11, 4]))

p = Pbind(
	\voicer, VC(\ac).v,
	\pan, 0,
	\distance, 5,
	\dur, Pseg(
		Pseq(#[0.5, 0.1, 0.5], 1),
		3, \exp
	),
	\diff, Pdiff(Pkey(\dur)),
	// \freq, Pseries(30,
	// 	Pwrand(#[-1, 1, 2, 3], #[1, 1, 2, 0.9].normalizeSum, inf)
	// 		* Pif(Pkey(\diff) > 0, -1, 1),
	// 	inf
	// ),
	\freq, Pseries(26,
		// Pshuf(#[-1, 1, 2, 3].weight(#[6, 9, 11, 4]), 1)
		Pseq(\shufBalanceSome.eval(#[-1, 1, 2, 3].weight(#[6, 9, 11, 4])), 1)
			* Pif(Pkey(\diff) > 0, -1, 1),
		inf
	),
	\mode, \g,
	\gate, 0.5,
	\mod_lev, 2.5,
	\length, Pwhite(2.0, 3.5, inf),
	\attackTimeScale, 1,
	\decayTimeScale, 1
	// \count, Pseries(1, 1, inf)
)/*.trace(\count)*/.play(protoEvent: ProtoEvent(\voicerNote).copy);




/**** TODO Hand stacking ****/
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
