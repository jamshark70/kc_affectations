// sounds for torso


MIDIPort.init([2]);
MIDIPort.autoFreeSockets = false;

s.options.preferredDeviceFunc_(nil).device_("Aggregate Device");

BP.loadGui;

MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

(Document.current.path.dirname.dirname +/+ "common/common-defs.scd").loadPath;

//(Document.current.path.dirname +/+ "head-defs.scd").loadPath;
~master.doWhenReady { PeakMonitor(~master) };


m = MixerChannel(\test1, s, 1, 2/*, level: 0.1*/);
n = MixerChannel(\test2, s, 2, 2/*, level: 0.1*/);
m => MCG(0); n => MCG(1);

[m, n].do { |mx|
	mx.outbus = ~master;
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


[~glrvb, ~lcrvb].do(_.run(false));
[~glrvb, ~lcrvb].do(_.run(true));


VoicerProxy.new => VP.prNew(0);
4.do { VP(0).v.addControlProxy(VoicerGCProxy(nil, VP(0).v), addAlways: true) };
VP(0).v.gui;



// bells
a = m.play {
	var	n = 10,
		exc = LPF.ar(PinkNoise.ar, 2500)
			* Decay2.kr(Impulse.kr(0), 0.01, 0.1),
		fspec = #[80, 240, \exp].asSpec,
		freqs = { |i| ExpRand(*fspec.map([i, i+1] / n)) } ! n,
		sig = Klank.ar(`[
			freqs,
			1 ! n,
			freqs.linlin(80, 240, 4.0, 9.0, \none)
		], exc) / 50;
	Peak.ar(sig).poll(TDelay.ar(Impulse.ar(0), 0.05));
	DetectSilence.ar(sig, amp: 0.001, doneAction: 2);
	Limiter.ar(sig)
};

a.free;

f = { |n = 10|
	SynthDef(("bell" ++ n).asSymbol, { |outbus, atten = 0.02, time = 9, pan = 0,
		fLow = 80, fHigh = 240, dLow = 0.45, dHigh = 1.0,
		beaterFilt = 2500, beaterDec = 0.1,
		chfreq = 0.6, chamt = 0.002, chdly = 0.008|
		var	//n = 10,
			exc = LPF.ar(PinkNoise.ar, beaterFilt)
				* Decay2.kr(Impulse.kr(0), 0.01, beaterDec),
			fpoints = (0..n).linlin(0, n, fLow, fHigh),
			freqs = ({ |i| ExpRand(*fpoints[[i, i+1]]) } ! n).clump(2).flop,
			sig = freqs.collect { |farray|
				Klank.ar(`[
					farray,
					atten ! n,
					farray.linlin(fLow, fHigh, dLow, dHigh, \none)
				], exc, decayscale: time)
			},
			panFreq = Rand(0.4, 1.2);
//		Peak.ar(sig).poll(TDelay.ar(Impulse.ar(0), 0.05));
		sig = sig.collect { |chan, i|
			Pan2.ar(chan, SinOsc.kr(panFreq, pi * i))
		}.sum;
		sig = 0.5 * (sig
			+ DelayL.ar(sig, chamt + chdly + 0.05, SinOsc.kr(chfreq, 0, chamt, chdly)));
		DetectSilence.ar(sig, amp: 0.001, doneAction: 2);
		sig = Limiter.ar(sig);
//		sig = Pan2.ar(sig, pan);
		Out.ar(outbus, sig);
	}).add
};

f.(10);

SynthDescLib.at(\bell10).controls.do(_.postln); ""

\addRvbOut.eval(\dbell10, SynthDescLib.at(\bell10).def.func).add;

a = m.play(\bell10, [time: 15]);

g = { |i|
	GenericGlobalControl(i.asSymbol, nil, #[0.075, 0.035][i], #[0.001, 0.75, exp]);
} ! 2;

w = ResizeFlowWindow("test", Rect(900, 100, 400, 400));
["glrvb", "lcrvb"].do { |str, i|
	StaticText(w, 100@20).string_(str).align_(\right);
	g[i].gui(w);
	w.startRow;
};
w.recursiveResize.front;


p = n.play(Pbind(
	\instrument, \dbell10,
	\time, Pwhite(9.0, 18.0, inf),
	\delta, Pkey(\time) * Pexprand(0.8, 1.1, inf), // + Pwhite(0.2, 1.0, inf),
	\fLow, Pexprand(40, 70, inf), //Pwhite(40, 75).midicps,
	\fHigh, Pkey(\fLow) * Pwhite(4.0, 11.0, inf),
	\beaterFilt, Pexprand(1500, 5000, inf),
	\atten, 0.025,
	\distance, Pwhite(5.0, 20.0, inf).trace(prefix: "dist: "),
	\chfreq, Pwhite(0.3, 0.8, inf),
	#[glrvbamt, lcrvbamt], #[0.395, 0.232] //,
	// #[glrvbamt, lcrvbamt], g.collect(_.asMap)
), (protoEvent: ().proto_(~rvbEvent.proto)));

p.stop;

p.event = (p.event.copy[\atten] = 0.1);


o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;

o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;

a = m.play { SinOsc.ar(XLine.kr(200, 40, 12), 0, 0.2) };
a.free;

(
BP(\b).free;
PR(\basicSynthChooser).chuck(BP(\b), nil, (
	event: (eventKey: \singleSynthPlayer),
	master: ~master, glrvbmc: ~glrvbmc, lcrvbmc: ~lcrvbmc,
	userprep: {
		#[glrvbmc, lcrvbmc].do { |key|
			key.envirGet.tryPerform(\receivesSignalFrom, ~chan);
		};
		~event.proto = topEnvironment[\rvbEvent].proto;
		~event.put(\glrvbamt, 0.395).put(\lcrvbamt, 0.232);
	},
	userfree: {
		#[glrvbmc, lcrvbmc].do { |key|
			key.envirGet.tryPerform(\stopsReceivingFrom, ~chan);
		};
	},
	sustain: Pwhite(9.0, 18.0, inf),
	delta: Pif(Pwhite(0.0, 1.0, inf) < 0.2, Pwhite(1.5, 4.0, inf), Pwhite(10.0, 16.0, inf)),
	objects: { (
		lowbell: (
			def: \addRvbOut.eval(\dbell10, { |outbus, atten = 0.02, time = 9, //pan = 0,
				fLow = 80, fHigh = 240, dLow = 0.45, dHigh = 1.0,
				beaterFilt = 2500, beaterDec = 0.1,
				chfreq = 0.6, chamt = 0.002, chdly = 0.008,
				pan = 0, panWidth = 1, panFreq = 1|
				var	n = 10,
					exc = LPF.ar(PinkNoise.ar, beaterFilt)
						* Decay2.kr(Impulse.kr(0), 0.01, beaterDec),
					fpoints = (0..n).linlin(0, n, fLow, fHigh),
					freqs = ({ |i| ExpRand(*fpoints[[i, i+1]]) } ! n).clump(2).flop,
					sig = freqs.collect { |farray|
						Klank.ar(`[
							farray,
							atten ! n,
							farray.linlin(fLow, fHigh, dLow, dHigh, \none)
						], exc, decayscale: time)
					}; //,
					// panFreq = Rand(0.4, 1.2);
				sig = sig.collect { |chan, i|
					Pan2.ar(chan, SinOsc.kr(panFreq, pi * i, panWidth, pan).clip(-1, 1))
				}.sum;
				sig = 0.5 * (sig
					+ DelayL.ar(sig, chamt + chdly + 0.05, SinOsc.kr(chfreq, 0, chamt, chdly)));
				DetectSilence.ar(sig, amp: 0.001, doneAction: 2);
				sig = Limiter.ar(sig);
				Out.ar(outbus, sig);
			}),
			args: [
				time: BPStream(\sustain),
				// delta: Pkey(\time) * Pexprand(0.8, 1.1, inf), // + Pwhite(0.2, 1.0, inf),
				fLow: Pexprand(40, 70, inf), //Pwhite(40, 75).midicps,
				fHigh: Pkey(\fLow) * Pwhite(4.0, 11.0, inf),
				beaterFilt: Pexprand(1500, 5000, inf),
				atten: 0.025,
				distance: Pwhite(5.0, 20.0, inf),
				pan: Pif(Pkey(\fLow) >= 120, Pwhite(-1.0, 1.0, inf), 0),
				panWidth: 1,
				chfreq: Pwhite(0.3, 0.8, inf)
			]
		)
	) }
));
0 => BP(\b);
)

p = BP(\b);
p.lowbellfLow = Pif(Pkey(\delta) < 5, Pexprand(120, 300, inf), Pexprand(40, 70, inf));

p.delta = Pif(Pwhite(0.0, 1.0, inf) < 0.5, Pwhite(1.5, 4.0, inf), Pwhite(10.0, 16.0, inf));

p.delta = Pseq([Pwhite(1.2, 2.5, { rrand(3, 8) }), Pwhite(10.0, 16.0, { rrand(1, 3) })], inf);

p.delta = Pseq([
	Plazy({
		var	last = rrand(0.9, 1.2);
		Pgeom.fromEndpoints(rrand(1.8, 2.6), last, rrand(4, 9)) ++ Pn(last*0.5, 1)
	}),
	Pwhite(10.0, 16.0, 1)
], inf);


// washes - feet pad didn't make the cut there, try to reuse here
// pad is reusable, maybe change wavetables and rethink fx


Fact(\waterpad) => VC(\wp);
VC(\wp) => VP(0);

SynthDescLib.at(VC(\wp).v.nodes[0].defname.asSymbol).msgFuncKeepGate = true;
SynthDescLib.at(VC(\wp).v.nodes[0].defname.asSymbol).msgFunc.postcs

p = Pbind(
	\type, \voicerNote,
	\voicer, VC(\wp).v,
	\degree, Pwhite(0, 7, inf),
	\octave, 5 + Pwrand(#[-1, 0, 1, 2], #[1, 3, 3, 2].normalizeSum, inf),
	\delta, Pexprand(0.5, 1.2, inf),
	\legato, Pwhite(3.0, 6.0, inf),
	\gate, Pwhite(0.2, 0.5, inf)
).play;

p.stop;
VC(\wp).env.stopfx;


VC(\wp).env.playfx;
VC(\wp).env.fx.trace

u = VC(\wp).env.levelSync;
u.remove;