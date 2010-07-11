// head rhythms

// make random pitch range part of the variation
// drum3: bufGrainRLPF

Library.put(\chucklib, \midiSearches, #["remote"]); BP.loadGui;


SynthDescLib.global.browse;
Object.browse;
s.queryAllNodes;

MIDIPort.init([2]);
MIDIPort.autoFreeSockets = false;

MT(1).free;
MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

(Document.current.path.dirname +/+ "head-defs.scd").loadPath;
topEnvironment[\dir] = Document.current.path.dirname.dirname +/+ "samples/feet";

m = MixerChannel(\test1, s, 1, 2);
n = MixerChannel(\test2, s, 2, 2);
m => MCG(0); n => MCG(1);

#[master, rvbmc, rvb].do(_.envirPut(nil));

VoicerProxy.new => VP.prNew(0);
8.do { VP(0).v.addControlProxy(nil, true) };
VP(0).v.gui;

//k = VoicerMIDISocket(0, VP(0).v);

{	var cc;
	8.do {
		cc = VoicerMIDIController(\omni, \knob);
		cc => CC.prNew(cc.ccnum.shortName.asSymbol);
	};
}.value;

8.do { |i| CC(("k" ++ i).asSymbol) => VP(0) };

~master ?? { ~master = MixerChannel(\master, s, 2, 2, level: 1) };

~rvbmc => MCG(6);
~master => MCG(7);
MixingBoard.at(0).refresh;

~rvb.run(false); ~rvbmc.mute;
~rvb.run(true); ~rvbmc.mute;



PR(\bufPerc).v[\beatsPerBar].postcs

(
BP(\fours).free;
PR(\bufPerc).chuck(BP(\fours), nil, (
	bufPaths: "~/sounds/drums/Udu/*FING*".pathMatch,
	
	ampbase: #[0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0],
	removeMask: #[4, 7],
	amps: 0,
	pbindPreAction: {
		~amps = ~ampbase.copy;
		~removeMask.do { |i| ~amps[i] = 0 };
		~bufs = { ~buffers.size.rand } ! ~amps.count(_ > 0);
	}
));
)

(
BP(\threes).free;
PR(\bufPerc).chuck(BP(\threes), nil, (
	bufPaths: ["~/sounds/drums/Udu/uduSLAP1.wav".standardizePath],
	
	ampbase: #[1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0],
	removeMask: #[2, 6],
	amps: 0,
	pbindPreAction: {
		~amps = ~ampbase.copy;
		~removeMask.do { |i| ~amps[i] = 0 };
	}
));
)

BP(\threes).pbindPreAction = {
		~amps = ~ampbase.copy;
		~removeMask.do { |i| ~amps[i] = 0 };
// 		~bufs = { ~buffers.size.rand } ! ~amps.count(_ > 0);
	};
BP(\threes).bufs = #[0];

BP.all.do { |bp| bp.removeMask = bp.removeMask.copy; bp.removeMask.removeAt(0) };
BP(\fours).removeMask = nil;
BP(\threes).removeMask = nil;

BP(\threes).ampbase = BP(\threes).ampbase.copy.putEach(#[5, 11], #[0.4, 0.4]);


(
(keys: #[master, rvbmc],
copyKeys: #[buffers, chan, postMCCreation, calcBar, bar, amps],  // you can override this
sourceFreesMe: true,
bp: \t1,
make: { |name|
	var	parms = ~parms ?? { () }, upd;
	BP(name).free;
	~keys.do { |key| parms[key] ?? { parms.put(key, key.envirGet) } };
	~copyKeys.do { |key| parms[key] ?? { parms.put(key, BP(~bp)[key]) } };
	PR(\bufPerc).chuck(BP(name), nil, parms);
	// copies have to go away because they depend on the source's buffers, mixer etc.
	if(~sourceFreesMe ? true) {
		upd = Updater(BP(~bp), { |obj, what|
			if(what == \free) {
				upd.remove;
				BP(name).free;
			}
		});
	};
	BP(name)
}, type: \bp) => Fact(\copyBufPerc);
)



TempoClock.default.gui;
TempoClock.tempo = 108/60;

TempoClock.schedAbs(TempoClock.nextBar, { TempoClock.beatsPerBar = 3 });

(
BP(\t1).free;
PR(\bufPerc).chuck(BP(\t1), nil, (
	bufPaths: ["~/sounds/drums/Udu/uduSLAP1.wav".standardizePath],
	baseIndices: #[0, 8],
	baseAmp: 1,
	postMCCreation: {
		var	zero = 0 ! 12, temp;
		~pbindPreAction = Routine(~calcBar);
		~bases = { |i|
			temp = zero.copy;
r			~baseIndices.size.do { |j|
				if((i bitAnd: (1 << j)) > 0) {
					temp.put(~baseIndices[j], ~baseAmp)
				};
			};
			temp
		} ! (1 << ~baseIndices.size);
		~indices = { |num|
			~bases.collectIndices({ |array| array.count(_ > 0) == num });
		} ! (~baseIndices.size + 1)		
	},
	postBufferLoad: {
		~chan.newPostSend(~rvbmc, 0.391);
		~fdecCtl = GenericGlobalControl(\fdec, nil, 0.5,  #[0.01, 1.0, exp]);
		~ffLowCtl = GenericGlobalControl(\fLow, nil, 2, #[1, 32, \lin, 1]);
		~ffRangeCtl = GenericGlobalControl(\fRange, nil, 8, #[0, 32, \lin, 1]);
		~wetCtl = GenericGlobalControl(\wet, nil, 1);

		~ffreq = 52 * Pwhite(~ffLowCtl, ~ffLowCtl.asPattern + ~ffRangeCtl + 0.99).trunc;
		~argPairs = [
			ffreq: BPStream(\ffreq),
			fdec: ~fdecCtl, 
			wet: ~wetCtl.asMap
		];
		// sibling processes may not init until I'm done
		NotificationCenter.notify(\t1, \ready);
	},
	useGui: { |vpi| #[fdecCtl, ffLowCtl, ffRangeCtl, wetCtl].do { |key| key.envirGet => VP(vpi) } },
	free: { [~fdecCtl, ~ffLowCtl, ~ffRangeCtl, ~wetCtl].free },
	amps: 0,
	bar: Pseq(#[0, 1], inf),
	calcBar: {
		var	bar = BPStream(\bar, resetSource: true).asStream,
			count = Pseries(0, 1, inf).asStream;
// 		"reset".debug(~collIndex);
		loop {
			~amps = ~bases[bar.next];
			~barHook.(count.next);
			0.yield;
		}
	},
	barHook: {
		~rates = #[0.5, 0.6];
		if (~amps[0] == 0) { ~rates.rotate(-1) }
		{ ~rates };
	},

	def: \bufGrainPanFmlet
));

NotificationCenter.registerOneShot(\t1, \ready, \ctor, {
	var	parms;

	Fact(\copyBufPerc).chuck(BP(\t2), nil, (
		copyKeys: Fact(\copyBufPerc).copyKeys ++ #[fdecCtl, ffLowCtl, ffRangeCtl, wetCtl, def],
		parms: (
			baseIndices: #[2, 6],
			baseAmp: 1,
			rates: #[1.25],
			postBufferLoad: {
				~ffreq = 52 * Pwhite(~ffLowCtl, ~ffLowCtl.asPattern + ~ffRangeCtl + 0.99).trunc;
				~argPairs = [
					ffreq: BPStream(\ffreq),
					fdec: ~fdecCtl,
					wet: ~wetCtl.asMap
				];
			}	
		)
	));

	parms = (
		bufPaths: "~/sounds/drums/Udu/*FING*".pathMatch,
		amps: 0,
		barHook: {
			~bufs = { ~buffers.size.rand } ! ~amps.count(_ > 0);
		},
		baseIndices: #[1, 4, 7, 10],
		baseAmp: 3.7
	);
	#[postMCCreation, calcBar].do { |key| parms.put(key, BP(\t1)[key]) };
	
	BP(\f1).free;
	PR(\bufPerc).chuck(BP(\f1), nil, parms);

	~num = BP.keys.size;
	BP.keys.asArray.sort.do { |key, i|
		BP(key).chuck(MT(1), 73 - ~num + i);
	};

	BP.all.do(_.alwaysReset = true);
	BP.all.do({ |bp| bp[\reset] = { /*"reset func".debug(~collIndex);*/ ~pbindPreAction.reset } });
});
)

BP(\t2).rates = #[1.25];

BP(\t1).bar = Pseq(#[3, 0], inf);
BP(\t2).bar = Pseq(#[0, 2], inf);

BP.all.do(_.alwaysReset = true)
BP.all.do({ |bp| bp[\reset] = { "reset func".debug(~collIndex); ~pbindPreAction.reset } });

BP.all.do(_.reset);

BP(\t2).bar = Prand(BP(\t2).indices[1], inf);
BP(\t1).bar = Pseq([3, Prand(BP(\t1).indices[1], 1)], inf);

BP(#[t1, t2]).do { |bp| bp.bar = Pseq(#[0, 2], inf) };

BP(\t1).bar = 0; BP(\t2).bar = 2;



BP(\f1).bar = Prand(#[8, 2], inf);
BP(\f1).bar = Prand([8, 2], inf) + Prand(#[0, 1, 4], inf);
BP(\f1).bar = Prand(BP(\f1).indices[1], inf);
BP(\f1).bar = Prand(BP(\f1).indices[2], inf);
BP(\f1).bar = Prand(BP(\f1).indices[3], inf);

BP(\f1).bases[[8, 2]]

BP(\t2).bar = Prand(BP(\t2).indices[1], inf);
BP(\t1).bar = Pseq([3, Prand(BP(\t1).indices[1], 1)], inf);

BP(\t1).bar = 3;
BP(\t2).bar = 3;
BP(\f1).bar = 15;


(
//~master.startRecord(thisProcess.platform.recordingsDir +/+ "rhythm1.aiff");
t = TLSequenceIterator([
	{	var	bp = BP(\drum1);
		bp.bar = 3;
		bp.wetCtl.value = 0.98;
		bp.fdecCtl.value = 0.25;
		bp.ffLowCtl.value = 2;
		bp.ffRangeCtl.value = 0;
		0
	},
	loopCmd: (
		setDoneSignal: {
			~doneSignal = true;
			defer(e {
				~window = ResizeFlowWindow("trigger",
					Rect(Window.screenBounds.width - 200, 50, 200, 100));
				Button(~window, 90@20)
					.states_([["go"]])
					.action_(e {
						if(BP(\drum1).isPlaying.not) { ~cmd.stop };
					});
				Button(~window, 90@20)
					.states_([["move on"]])
					.action_(e {
						currentEnvironment.stop;
					});
				~window.recursiveResize.front;
			})
		},
		clearDoneSignal: { defer(e { ~window.close }) },
		cmds: [
			{	PR(\funcCmd).copy.putAll((
					looper: currentEnvironment,
					func: { ~looper.cmd = currentEnvironment },
					doneSignal: true
				))
			},
			\cmdSync,
			{	if (~doneSignal == true) {
					PR(\bpCmd).copy.putAll((
						name: \drum1,
						quant: 1,
						dur: 2.9
					))
				}
			},
			\cmdSync
		]
	),
	\sync,
	Quant(3, -0.5),
	bpCmd: (name: \drum1, quant: `nil, prepareBP: { |bp|
		bp.bar = Pseq(#[3, 0], inf);
// 		bp.wetCtl.value = 0.98;
// 		bp.fdecCtl.value = 0.25;
// 		bp.ffLowCtl.value = 2;
// 		bp.ffRangeCtl.value = 0;
	}),
	12,
	gcAutoSynthCmd: (gc: BP(\drum1).wetCtl, name: \ctlPoint, outName: \outbus, 
		value: 0.078, time: 30, curve: 0),
	bpCmd: (name: \drum2, quant: `nil, prepareBP: { |bp|
		bp.bar = Pseq(#[0, 2], inf);
	}),
	12,

	bpCmd: (name: \drum3, quant: `nil, prepareBP: { |bp|
		bp.bar = Prand(#[8, 2], inf);
		bp.ffreqCtl.value = 60;
	}),
	mixerAutoSynthCmd: (mixer: BP(\drum3).chan, name: \ctlEnv, outName: \outbus,
		connect: 0, env: Env(#[0, 0.75], #[18], 2.4)),
	gcAutoSynthCmd: (gc: BP(\drum3).ffreqCtl, name: \ctlPoint, outName: \outbus, 
		value: 18000, time: 30, curve: 5),

	{	BP(\drum1).bar = Pseq([3, Prand(BP(\drum1).indices[1], 1)], inf);
		12
	},
	{	BP(\drum2).bar = Prand(BP(\drum2).indices[1], inf);
		12
	},

	{	BP(\drum2).bar = Prand(#[1, 2, 3], inf);
		12
	},

	{	BP(\drum3).bar = Prand([8, 2], inf) + Prand(#[0, 1, 4], inf);
		BP(\drum2).bar = 3;
		12
	},

	{	BP(\drum3).bar = Prand(BP(\drum3).indices[2], inf);
		12
	},

	{	BP(\drum3).bar = Prand(BP(\drum3).indices[[2, 3]].flat, inf);
		BP(\drum1).bar = 3;
		24
	},

	{	BP(\drum3).bar = 15;
		48
	},

 	funcCmd: (func: { ~iterator.stop })
//	{ BP.all.stop; 8 },
//	{ ~master.stopRecord; 0 }
]).play(argClock: ~clock108 ? TempoClock.default);
)

t.stop;

u = Updater(BP(\t1), { |... args| args.debug("t1 update"); });
u.remove;


	SynthDef(\returnPeak, { |bufnum, start, frames|
		var	term = Line.ar(0, 1, frames / BufSampleRate.ir(bufnum)),
			sig = PlayBuf.ar(1, bufnum, rate: BufRateScale.ir(bufnum), startPos: start),
			peak = Peak.ar(sig),
			done = Done.kr(term) + Done.kr(sig);
		SendTrig.kr(done, 0, peak);
		FreeSelf.kr(done);
	}).add;

o.remove;
o = OSCresponderNode(s.addr, '/tr', { |t, r, m| m.postln }).add;

Synth(\returnPeak, [bufnum: BP(\t1).buffers[0], frames: BP(\t1).buffers[0].numFrames]);

fork {
	BP(\f1).buffers.do { |buf|
		Synth(\returnPeak, [bufnum: buf, frames: buf.numFrames]);
		0.1.wait;
	};
};

BP(\f1).bases.do { |row|
	row.do { |item, i| if(item > 0) { row[i] = 3.7 } };
};


s.queryAllNodes;

[bufnum: BP(\t1).buffers[0], frames: BP(\t1).buffers[0].numFrames].asOSCArgArray
BP.all.free


// if using "clay pot" folder samples:
MultiEQ.new(2, \hipass, 120.682, 0.dbamp, 1)

BP(\t1).buffers[0]
BP(\f1).buffers[0]

m.scope

(
var	x;
n.play((
	instrument: \bufGrainPan, bufnum: BP(\t1).buffers[0], time: BP(\t1).buffers[0].duration, amp: 1,
	collIndex: \dummy,
	lpcEv: (
		instrument: \formantXfer2, lpfreq: 18000,
		ffreqs: (x = FormantTable.rand)[0], amps: x[1], qs: x[2],
		amp: 5
	)
).parent_(ProtoEvent(\polySynthBusLock).v.parent));
)

TempoClock.tempo = 1;

SynthDef(\timedFormantXfer2, { |inbus, outbus, t_trig = 0\bufGrainPanFmlet, slideTime = 1, amp = 1, lpfreq = 2000,
	time = 1|
	var	ffreqs = NamedControl.kr(\ffreqs, Array.series(5, 400, 400)),
		amps = NamedControl.kr(\amps, 1 ! 5),
		qs = NamedControl.kr(\qs, 0.1 ! 5),
		sig = In.ar(inbus, 1); //,
//		noise = PinkNoise.ar(noiseAmp * Amplitude.kr(sig));
	ffreqs = ffreqs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
	amps = amps.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
	qs = qs.collect { |x| EnvGen.kr(Env([x, x], [slideTime], \exp), t_trig) };
	sig = LPF.ar(sig, lpfreq);
	sig = BBandPass.ar(sig /*+ noise*/, ffreqs, qs, amps).sum;
	Out.ar(outbus, (sig * amp) ! 2);
	Line.kr(0, 1, time, doneAction: 2);
}).add;

Pdefn(\ftk, Prand(FormantTable.keys.asArray, inf));

(
p = n.play(Pbind(*[
	instrument: \bufGrainPan,
	bufnum: BP(\t1).buffers[0],
	time: BP(\t1).buffers[0].duration,
	amp: 1,
	collIndex: \dummy,
	delta: Pwhite(1, 4, inf) * 0.125,
	lpcEv: Pbind(*[
		instrument: \timedFormantXfer2, lpfreq: 18000,
		#[ffreqs, amps, qs], Pnsym(Pdefn(\ftk), FormantTable),
		amp: 5
	]) <> Pfunc { |ev| (time: ev[\time] + 0.1) }
]), (protoEvent: ProtoEvent(/*\singleSynthPlayer*/ \polySynthBusLock).copy));
)

p.stop;

Pdefn(\ftk, Prand(FormantTable.keys.asArray.select { |key| key.asString.contains("bass") }, inf));
Pdefn(\ftk, Prand(FormantTable.keys.asArray.select { |key| key.asString.contains("tenor") }, inf));
Pdefn(\ftk, Prand(FormantTable.keys.asArray.select { |key| key.asString.contains("alto") }, inf));
Pdefn(\ftk, Prand(FormantTable.keys.asArray.select { |key| key.asString.contains("soprano") }, inf));


(x = FormantTable.rand)[0], 

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;

n.free

BP(\t1).rates = [0.5, 0.6];

Instr.at(\busfx).keys
MultiEQ.new(2, \hipass, 91, 0.dbamp, 1).edit(BP(\t1).chan)

Instr("busfx.formlet", { |bus, numCh, ffreq = 2000, atk = 0.1, dec = 0.2|
	var sig = In.ar(bus, numCh);
	sig = Formlet.ar(sig, ffreq, atk, dec);
	Limiter.ar(sig);
}, [\mybus, StaticSpec(1, 8), \freq, #[0.01, 1.0, exp], #[0.01, 1.0, exp]]);

a = BP(\t1).chan.playfx(Instr("busfx.formlet"), [0, 1]);
a.gui

FxPatch(
	[ 'busfx', 'formlet' ], [ 24, 1, 104.0, 0.01, 0.26101569768623 ]
)


32.midicps

SynthDef(\bufGrainPanFmlet, { |start, time, bufnum, pan, rate = 1, amp = 1,
		attack = 0.001, decay = 0.02, outbus,
		ffreq = 2000, fatk = 0.01, fdec = 0.1, wet = 1|
	var sig, sig2, eg;
	sig = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum), 1, start, 0);
	eg = EnvGen.kr(Env.linen(attack, time, decay), doneAction:2);
	sig2 = Limiter.ar(Formlet.ar(sig, ffreq, fatk, fdec));
	sig = LPF.ar(sig, wet.linexp(0, 1, 18000, ffreq));
	sig = XFade2.ar(sig, sig2, wet.madd(2, -1));
	Out.ar(outbus, Pan2.ar(sig, pan, amp * eg));
}).perform(Library.at(\ddwGlobal, \storeMethod), \ddwSynths);

BP(\t1).def = \bufGrainPanFmlet;
BP(\t2).def = \bufGrainPanFmlet;

BP(\t1).argPairs = [ffreq: 52 * Pwhite(2, 32), fdec: 0.5];

BP(\t1).use {
	~fdecCtl = GenericGlobalControl(\fdec, nil, 0.5,  #[0.01, 1.0, exp]);
	~ffLowCtl = GenericGlobalControl(\fLow, nil, 2, #[1, 32, \lin, 1]);
	~ffRangeCtl = GenericGlobalControl(\fRange, nil, 8, #[1, 32, \lin, 1]);
	~useGui = { |vpi| #[fdecCtl, ffLowCtl, ffRangeCtl].do { |key| key.envirGet => VP(vpi) } };
	~free = { [~fdecCtl, ~ffLowCtl, ~ffRangeCtl].free };
};

BP(\t1).use {
	~argPairs = [
		ffreq: 52 * Pwhite(~ffLowCtl, ~ffLowCtl.asPattern + ~ffRangeCtl + 0.99).trunc, 
		fdec: ~fdecCtl
	];
};

BP(\t1).barHook = {
	~rates = #[0.5, 0.6];
	if (~amps[0] == 0) { ~rates.rotate(-1) }
	{ ~rates };
};

(1..3).do { |i| Fact(("drum" ++ i).asSymbol).chuck(BP(("drum" ++ i).asSymbol), nil, (source: \drum1)) };
Fact(\drum2).chuck(BP(\drum2), nil, (source: \drum1));

BP(\drum3).bar = 15;
BP(\drum3).def = \bufGrainRLPFPan;

(
(keys: #[master, rvbmc, clock108],
source: #[drum1, drum3],
make: { |name|
	BP(name).free;
	if(~source.asArray.every { |src| BP.exists(src) }) {
		if (BP(~source.last)[\argPairs].notNil) {
			~makeBP.(name);
		} {
			NotificationCenter.registerOneShot(~source.last, \ready, name, e {
				~makeBP.(name);
			});
			BP(name)
		}
	} {
		"% not loaded, cannot load %".format(~source, name).warn;
	}
},
makeBP: { |name|
	BP(name).free;
	PR(\basicBufferPlayer).chuck(BP(name), nil, (
		bufPaths: nil,
		buffers: ~source.asArray.collect { |bp| BP(bp).buffers }.flat,
		def: \bufGrainRLPFPan,
		inChannels: 2,
		delta: Pseq(#[0.25, 0.25, 0.5, 0.5], inf),
		bufIndex: Ppatlace([0, Pxrand((1..4), inf)], inf),
		time: Pfunc { |ev| ~buffers[ev[\bufIndex]].duration },
		timeConversion: { |time| time * thisThread.clock.tempo },
		amp: Pseq(#[1, 3.7], inf),
		rate: Place(#[[0.5, 0.6, 0.6, 0.5], 1], inf),
		start: 0,
		pan: ~pan ? 0,
		argPairs: [pan: BPStream(\pan)],
		reset: {
			var	str;
			currentEnvironment.keys.do { |key|
				if((str = key.asString).contains("Stream")) {
					~makeStreamForKey.(str[ .. str.size - 7].asSymbol);
				}
			}
		}
	));
	~clock108 => BP(name);
}, type: \bp) => Fact(\drum4);
)

BP(#[drum4, drum5]).free;
Fact(\drum4).chuck(BP(\drum4), nil, (pan: -1));
Fact(\drum4).chuck(BP(\drum5), nil, (pan: 1));

BP(#[drum4, drum5]).do { |bp| ~clock108 => bp };
BP(#[drum4, drum5]).do { |bp| bp.start = 0; };
BP(#[drum4, drum5]).do { |bp| bp.rate = Place(#[[0.5, 0.6, 0.6, 0.5], 1], inf); };

BP(\drum4).play(-1);
BP(\drum5).play(#[-1, 1.5]);

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;
