// to do for showing:
// refine arms melody
	// spatialize - introduce further back in the space - done
	// change ffreq, rq patterns
	// L/R/Mid patterns lagging at separate times, pretty nice, what is context for it?
// make sure character of chords comes through
// rework feet opening for responsiveness
// (if Lorne will be putting up graphics with each step, I can sync sound to that too)

s.options.preferredDeviceFunc_(nil).device_("Aggregate Device");
BP.loadGui;

ChuckableBrowser.newWindow;
SynthDescLib.global.browse;
Object.browse;
s.queryAllNodes;

MIDIPort.init([1]);
MIDIPort.resetAll;

s.waitForBoot {
	(thisProcess.nowExecutingPath.dirname.dirname +/+ "feet/feet-defs.scd").loadPath;
	0.1.wait;	// seems to be necessary to prevent duplicate reverbs
	(thisProcess.nowExecutingPath.dirname +/+ "arms-defs1.scd").loadPath;
};

(
\makeEmptyMixer8.eval;

[m, n].free;
m = MixerChannel(\test1, s, 1, 2);
n = MixerChannel(\test2, s, 2, 2);
//MixingBoard(\test, nil, m, n);

m => MCG(0); n => MCG(1);
//~master => MCG(7);
)

MixingBoard.at(0).refresh;

// in case I forgot to init midi first
8.do { |i| MixerMIDIControl(\omni, nil, MCG(i).v); };


[~glrvb, ~lcrvb].do { |patch| patch.run(false) };
[~glrvb, ~lcrvb].do { |patch| patch.run(true) };

[~glrvbmc, ~lcrvbmc, ~master].do { |mc, i| mc => MCG(i+5) };


// sound for vertical curve trigger
~cb = Buffer.alloc(s, 1024, 1);
~mb = Buffer.alloc(s, 1024, 1);

~cb.sine1((1..3).reciprocal);
~mb.sine1([1]);

WrapInstr("osc2.fm2car", { arg freq, gate, car_env, mod_env, mod_lev, mod_ratio, detune, car_detune,
		car_buf, mod_buf, car_vs, mod_vs, basefreq, keyscale;
	var sig, mod, car_amp, mod_amp;
	car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
	mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
		* EnvGen.kr(mod_env, gate);
	mod_lev = mod_lev * basefreq / ((keyscale * freq) + (basefreq * (1 - keyscale)));
	mod = Osc.ar(mod_buf, freq.madd(mod_ratio * [1, car_detune], detune * [1, -1]), 0, mod_amp * mod_lev);
	freq = freq * [1, car_detune];
	sig = Mix(Osc.ar(car_buf, freq + (mod * freq), 0, car_amp))
		* EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0.01, 300, \exponential], [1, 12, \linear, 0, 1], [-5, 5, \linear, 0, 0], \mydetune, \mybuf, \mybuf, nil, nil, \freq, [0.001, 1.0, \exp]]);

WrapInstr("osc2.fm2car_stereo", { |physicalPan = 0|
	var	sig = WrapInstr.wrap("osc2.fm2car");
	Pan2.ar(sig, physicalPan);
}, [\bipolar]);

WrapInstr("osc2.fm2car_pan_lfo", { |pan = 0, mod_lev = 1, modLfoSpeed = 0, modLfoAmp = 0, modLfoDecay = 1, modLfoRange = 1, detune = 0, detuneLfoSpeed = 0, detuneLfoAmp = 0|
	var	lfo = Ringz.kr(Impulse.kr(0) * modLfoAmp, modLfoSpeed, modLfoDecay)
			.linexp(-1, 1, modLfoRange.reciprocal, modLfoRange),
		dtlfo = SinOsc.kr(detuneLfoSpeed, mul: detuneLfoAmp),
		sig = WrapInstr.wrap("osc2.fm2car", [nil, nil, nil, nil, mod_lev * lfo, nil,
			// detune + dtlfo so that dtlfo = 0 doesn't force detune to be 0
			detune + dtlfo]);
	Pan2.ar(sig, pan);
}, [\bipolar, #[0.01, 300, exponential], #[0.1, 10, exp], nil, #[0.1, 10, exp], #[1, 5], #[-5, 5], #[0.01, 10, exp], #[0, 10]]);

WrapInstr("osc2.fm2car").listArgs

// might also lfo 'detune' - higher pitches are more tolerant - adds nice dimension
v = WrapInstr("osc2.fm2car_pan_lfo").miditest(0, [car_buf: ~cb, mod_buf: ~mb, \mod_lev, 4.7777362156971, \mod_ratio, `1, \detune, 0 /*.2755905511811*/, \car_detune, `0.99798261661993, \car_vs, `0.66141732283465, \mod_vs, `0, \basefreq, `440, \keyscale, `0.28621534453893], n);

v.unmapGlobal(\detuneLfoAmp);
#[detuneLfoAmp, modLfoSpeed, modLfoAmp, modLfoDecay, modLfoRange, envTimeScale].do { |key|
	v.unmapGlobal(key);
};
k = MIDIPort.search(v);

k.noteOnArgsPat = Pbind(
	\detuneLfoAmp, Pkey(\midinote).linexp(28, 96, 0.2, 4, clip: \none),
	\modLfoSpeed, Pkey(\velocity).linlin(0, 127, 1.4, 6.0),
	\modLfoAmp, Pkey(\velocity).linlin(0, 127, 0, 1),
	\modLfoDecay, Pkey(\velocity).linlin(0, 127, 1, 8),
	\modLfoRange, Pkey(\midinote).linexp(36, 84, 1.6, 4)
);

k.noteOnArgsPat.inspect;

\mod_lev, 4.7777362156971, \mod_ratio, 1, \detune, 0.2755905511811, \car_detune, 0.99798261661993, \car_vs, `0.66141732283465, \mod_vs, `0, \basefreq, `440, \keyscale, `0.28621534453893


~cb.plotWavetable

v.trace
28.midicps = 41.2034 // 0.2 max detune
96.midicps = 2093    // 4 max detune



\pan, 0, 
\mod_lev, 4.0617792969413, 
\modLfoSpeed, 4.3430544633167, 
\modLfoAmp, 0, 
\modLfoDecay, 3.6228897509243, 
\modLfoRange, 2.4173228346457, 
\mod_ratio, 1, 
\detune, 0.11811023622047, 
\car_detune, 1.0057155293159, 


(
"dummy";

(
level: -20.dbamp,
make: { |name|
// 	var	out;
	~target = MixerChannel(name, s, 2, 2, level: ~level);
	~cb = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg(#[1, 2, 3].reciprocal) });
	~mb = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg(#[1]) });

	Voicer(20, WrapInstr("osc2.fm2car_pan_lfo"), [
		basefreq: `440, keyScale: `0.28621534453893,
		car_buf: ~cb, mod_buf: ~mb,
 		car_env: Env.adsr(0.5, 0.8, 0.75, 1.0),
// 		mod_env: ,
		mod_ratio: `1, detune: `0, car_detune: `0.99798261661993,
		car_vs: `0.66141732283465, mod_vs: `0
	], target: ~target);
},
free: { [~cb, ~mb, ~target].free }, type: \voicer) => Fact(\fmping);

"dummy";
)

VC(\fmp).free;
Fact(\fmping) => VC(\fmp);
VC(\fmp) => MCG(2);

WrapInstr("osc2.fm2car_pan_lfo").listArgs

k = VoicerMIDISocket(0, VC(\fmp).v);
k.addControl(nil, \envTimeScale, 1, #[0.1, 10, \exp]);
VC(\fmp).v.gui;

k.removeControl(\envTimeScale);

VC(\fmp).v.nodes[0].defname;


{ Decay2.kr(Impulse.kr(0), 0.98, 0.02) }.plot(1)
{ Lag.kr(EnvGen.kr(Env(#[0, 1, 0], #[0.98, 0.02], 2.1)), 0.01) }.plot(1)
{ EnvGen.kr(Env(#[1, 2, 1], #[0.98, 0.02], \exp)) - 1 }.plot(1)

WrapInstr("osc2.fm2car_bass_tlfo").listArgs;

v = Voicer(20, WrapInstr("osc2.fm2car_bass_tlfo"), [car_buf: ~cb, mod_buf: ~mb, \mod_lev, 4.7777362156971, \mod_ratio, `1, \detune, 0, \car_detune, `0.99798261661993, \car_vs, 0.66141732283465, \mod_vs, `0, \basefreq, `440, \keyscale, `0.28621534453893, car_env: Env.adsr(0.5, 0.8, 0.75, 1.0)], target: m);

if(VP.exists(0).not) { VoicerProxy.new => VP.prNew(0) };
v => VP(0);
VP(0).v.gui;

();

k = VoicerMIDISocket(0, v);
k.addControl(nil, \car_vs, 0);
k.addControl(nil, \modUpRange, 1, #[0.1, 10, \exp]);
VoicerSusPedal(0, 64, v);

k.noteOnArgsPat = Pbind(
	\detuneLfoSpeed, Pexprand(0.3, 1.7, inf),
	\detuneLfoAmp, Pkey(\midinote).linexp(28, 96, 0.2, 4, clip: \none),
	\modLfo, 0,
// 	\modLfo, (BP(\rhy).bus.index + Pwhite(0, BP(\rhy).num - 1, inf))
// 		.collect { |index| ("c" ++ index).asSymbol },
//	\modUpRange, Pkey(\midinote).linexp(36, 84, 1.6, 4),
	\mod_lev, Pkey(\velocity).linlin(0, 127, 1.2, 3.4),
	\attackTimeScale, Pkey(\velocity).linexp(0, 127, 10.0, 0.1),
	\decayTimeScale, Pkey(\velocity).linexp(0, 127, 10.0, 3.5)
);


// make a pool of rhythm synths
~rhybus = Bus.control(s, 5);

(
~rhythms = Ppar(
	{ |i|
		Pmono(\trigRhythmBus,
			\out, ~rhybus.index + i,
			\top, Pwhite(0.2, 1.0, inf),
			\delta, Pseq([
				Pwhite(2, 6, 1),
				Pwrand(#[0.25, 0.5, 0.75], #[1, 6, 7].normalizeSum, { rrand(7, 19) })
			], inf),
			\trig, Pkey(\delta) / Ptempo()
		)
	} ! ~rhybus.numChannels
).play;
)

~rhythms.stop;

PR(\abstractProcess).v[\makeStreamForKey].postcs
PR(\abstractProcess).v[\putAction].postcs
PR(\abstractProcess).v.listMethods

(
PR(\abstractProcess).clone {
	~event = (eventKey: \default);
	~num = 5;
	~bpsKeys = #[top, delta];

	~prep = {
		~bus = Bus.control(s, ~num);

		// populate multiple streams where only one is given at init time
		~bpsKeys.do { |key| ~putAction.(key, key.envirGet) };
	};

	~freeCleanup = {
		~bus.free;
	};

	~busIndex = { |i| ~bus.index + i };

	~top = Pwhite(0.2, 1.0, inf);
	~delta = Pseq([
		Pwhite(2, 6, 1),
		Pwrand(#[0.25, 0.5, 0.75], #[1, 6, 7].normalizeSum, { rrand(7, 19) })
	], inf);

	~asPattern = {
		Ppar(
			{ |i|
				Pmono(\trigRhythmBus,
					\out, ~busIndex.(i),
					\top, BPStream("top" ++ i),
					\delta, BPStream("delta" ++ i),
					\trig, Pkey(\delta) / Ptempo()
				)
			} ! ~bus.numChannels
		)
	};
} => PR(\rhythmBusPool);

	// BPStream patterns should have separate streams for each parallel Pmono
PR(\rhythmBusPool).v[\putAction] = { |key, value|
	var	streamKey;
	if(value.isPattern
		or: {	streamKey = (key ++ "0Stream").asSymbol;
				streamKey.envirGet.notNil
		}
	) {
		~num.do { |i|
			(key ++ i ++ "Stream").asSymbol.envirPut(value.asStream);
		};
	};
};
)

BP(\rhy).free;
PR(\rhythmBusPool) => BP(\rhy);
1 => BP(\rhy);

BP(\rhy).play;
BP(\rhy).stop;


BP(\rhy).listVars;
BP(\rhy).v[\putAction].postcs
PR(\rhythmBusPool).v[\putAction].postcs



// ~rhySynths.do { |sy| s.sendMsg(\n_free, sy[0][2]) };

s.sendMsg(\n_trace, 1054);

k.ccs.reverseDo(_.free);
v.free;


// chords
v = VC(\fmp).v;
k = VoicerMIDISocket(0, v);
VoicerSusPedal(0, 64, v);

v.gate(Mode(\c).cps(#[21, 25, 28, 30, 32, 33, 36, 38.5, 39, 42, 43, 46, 48]), 6, 0.5);

v.gate(Mode(\eb).cps(#[21, 25, 29, 30, 33, 34, 36, 39, 40, 43, 45.5]), 6, 0.5);



#[21, 25, 28, 30, 31.5, 34, ].unmapMode(\c).asInteger.collect(_.asMIDINote)
#[21, 25, 28, 30, 32, 33, 36, 38.5, 39, 42, 43, 46, 48].unmapMode(\c).asInteger.collect(_.asMIDINote)

#[21, 25, 29, 30, 33, 34, 36, 39, 40, 43, 45.5].unmapMode(\eb).asInteger.collect(_.asMIDINote)

#[14, 21, ].unmapMode(\ab).asInteger.collect(_.asMIDINote)

BP(\cchs).free;
PR(\chordChooser) => BP(\cchs);
BP(\cchs).prepareForPlay;

{ x = BP(\cchs).eventStream.next(()).postln; x.chord.unmapMode(x.mode).asInteger.collect(_.asMIDINote).postln }.bench;

x.chord.unmapMode(x.mode).asInteger.collect(_.asMIDINote)



// bass process
BP(\ab).free;
PR(\rhythmBusPool) => BP(\ab);
BP(\ab) => VC(\fmb);
0 => BP(\ab);

BP(\ab).amountCtl.gui
BP(\ab).modUpCtl.gui


PR(\rhythmBusPool).v[\driver]

VC(\fmp).v.panic;
VC(\fmb).v.trace;




// ok, REAL sounds now

~wt.free;
~wt = \makeWavetables.eval(8, s, 2048, 48, { |numharm|
	var	array = Array.triangleAmps(numharm),
		tweak = ((numharm div: 5) + 1 .. (numharm-1)), i;
	min(10, numharm div: 5).do {
		i = tweak.takeAt(tweak.size.rand);
		if(i.notNil) {
			array[i] = array[i] * exprand(2.5, 6.0) * (i+1);
		};
	};
	array
});

~wt[0].plotWavetable

Library.at(WrapInstr, \osc2).keys.asArray.sort;
WrapInstr("osc2.vosc3mapfilt").listArgs;
WrapInstr("osc2.vosc3mapfilt").openFile;

MIDIPort.autoFreeSockets = true;

WrapInstr("osc2.vosc3mapfporta").listArgs;
WrapInstr("osc2.vosc3map").listArgs;

WrapInstr("osc2.vosc3mapfporta", { |freq, freqlag = 0.1, ffreq = 2000, rq = 1|
	// I should have been able to do this, but it duplicated the freq control...???
	// debug later
// 	WrapInstr.wrap("osc2.vosc3mapfilt", [nil, nil, Lag.kr(freq, freqlag)])
	RLPF.ar(WrapInstr.wrap("osc2.vosc3map", [Lag.kr(freq, freqlag)]), ffreq, rq)
}, [NoLagControlSpec(20, 20000, \exp, 0, 440), #[0, 1, 4], \freq, \myrq]);

v = WrapInstr("osc2.vosc3mapfilt").miditest(0, [bufbase: `(~wt.first.bufnum), numbufs: `(~wt.size), basefreq: `(48.midicps), topfreq: `(132.midicps), env: Env.adsr(0.4, 0, 1, 1.2), \ffreq, 2423.054873855, \rq, 1, \vsens, 0.84722220897675, \detune, 1.003], target: n);

// no lag arg built in
// I like the general direction of this, needs to be smoother
v = WrapInstr("osc2.vosc3mapfporta").miditestMono(0, [bufbase: `(~wt.first.bufnum), numbufs: `(~wt.size), basefreq: `(48.midicps), topfreq: `(132.midicps), env: Env.adsr(0.4, 0, 1, 1.2), \ffreq, 2423.054873855, \rq, 1, \vsens, 0.84722220897675, \detune, 1.003], target: n);
v.portaTime = 0.6;
v.unmapGlobal(\freqlag);

SynthDescLib.at(v.nodes[0].defname.asSymbol).controls.do(_.postln); ""

p = Pbind(
	\type, \voicerNote,
	\voicer, v,
	\root, 7,
	\degree, Pseq(#[2, 5, 4, 2, 7, 6, 4, 8, 2, 5, 6, 4], inf),
	\dur, Pwrand(#[1, 2], #[0.9, 0.1], inf),
	\legato, 1.01,
	\gate, 0.8
).play;

p.stop;

v.trace;

z = n.playfx(WrapInstr("busfx.chorus2"), [0, 1, 2, 3, KrNumberEditor(0.01285261232269, ControlSpec(0.0001, 0.2, 'exp', 0, 0.001, "")), KrNumberEditor(0.077426358822457, ControlSpec(0.001, 10, 'exp', 0.0, 0.001, "")), KrNumberEditor(0.00860870962377, ControlSpec(0.0001, 0.25, 'exp', 0.0, 0.0001, "")), KrNumberEditor(0.87266466760906, ControlSpec(0, 6.2831853071796, 'linear', 0.0, 0, "")), KrNumberEditor(0.15647481535888, ControlSpec(0.1, 10, 'exp', 0, 1, ""))]); z.gui;

\ffreq, 2423.054873855, \rq, 1, \vsens, 0.84722220897675, \detune, 1.003


~maps = v.globalControls.collectAs({ |gc| if(gc.name != \detune) { [gc.name, gc.asMap] } }, Array).select(_.notNil).flat;

SynthDescLib.at(v.nodes[0].defname.asSymbol).msgFuncKeepGate = true;
SynthDescLib.at(VC(\am).v.nodes[0].defname.asSymbol).msgFuncKeepGate = true;

// promising - is this really easier than MonoPortaVoicer?
p = n.play(Ptpar([
	(0..2),
	{ |i|
		PmonoArtic(VC(\am).v.nodes[0].defname.asSymbol,
			\root, 7,
			\degree, Pseq(#[2, 5, 4, 2, 7, 6, 4, 8, 2, 5, 6, 4], inf),
			\dur, Pwrand(#[1, 2], #[0.9, 0.1], inf),
			\legato, 1.01,
			\gate, 0.8,
			\freqlag, 0.3,
			\detune, 1.003,
			\gate, 0.8,
			\pan, i.wrap(-1, 1)
		)
	} ! 3
].flop.flat), (protoEvent: Event.default.proto_((detunedFreq: { ~freq.value }))));

p.stop;

(1044..1046).do(s.sendMsg(\n_free, _))

PeakMonitor(n);

s.sendMsg(\n_trace, 1022);

(
(keys: #[master, glrvbmc],
make: { |name|
	var	out;
	~wt = \makeWavetables.eval(8, s, 2048, 48, { |numharm|
		var	array = Array.triangleAmps(numharm),
			tweak = ((numharm div: 5) + 1 .. (numharm-1)), i;
		min(10, numharm div: 5).do {
			i = tweak.takeAt(tweak.size.rand);
			if(i.notNil) {
				array[i] = array[i] * exprand(2.5, 6.0) * (i+1);
			};
		};
		array
	});
	~target = MixerChannel(name, s, 2, 2, completionFunc: { |chan|
		// eq?
		~chorus = chan.playfx(WrapInstr("busfx.chorus2"), [0, 2, 2, 3, 0.01285261232269, 0.077426358822457, 0.00860870962377, 0.87266466760906, 0.15647481535888]);
	});
	WrapInstr("osc2.vosc3mapfporta", { |freq, freqlag = 0.1, ffreq = 2000, rq = 1, pan|
		var	sig = WrapInstr.wrap("osc2.vosc3map", [Lag.kr(freq, freqlag)]);
		Pan2.ar(RLPF.ar(sig, ffreq, rq), pan)
	}, [NoLagControlSpec(20, 20000, \exp, 0, 440), #[0, 1, 4], \freq, \myrq]);
	out = MonoPortaVoicer(1, WrapInstr("osc2.vosc3mapfporta"), [bufbase: `(~wt.first.bufnum), numbufs: `(~wt.size), basefreq: `(48.midicps), topfreq: `(132.midicps), env: Env.adsr(0.4, 0, 1, 1.2), ffreq: 2423.054873855, rq: 1, vsens: 0.84722220897675, detune: 1.003], target: ~target);
	// no global maps - this is mostly to generate the synthdef
	SynthDescLib.at(out.nodes[0].defname.asSymbol).msgFuncKeepGate = true;
	out
},
free: { ~target.free },
maps: { |self| self[\value].globalControls.collectAs({ |gc| if(gc.name != \detune) { [gc.name, gc.asMap] } }, Array).select(_.notNil).flat },
type: \voicer) => Fact(\armsmelVC);
)

Fact(\armsmelVC) => VC(\am);
//VC(\am).v.gui;

();
d = Pseq(#[2, 5, 4, 2, 7, 6, 4, 8, 2, 5, 6, 4], inf);

p = { |i|
	Pn(Event.silent(1), i) ++
	PmonoArtic(VC(\am).v.nodes[0].defname.asSymbol,
		\root, 7,
		\degree, d,
		\dur, Pwrand(#[1, 2], #[0.9, 0.1], inf),
		\legato, 1.01,
		\gate, 0.8,
		\freqlag, 0.3,
		\detune, 1.003,
		\gate, 0.8,
		\pan, i.wrap(-1, 1)
	)
};

~ev = Event.default.proto_((detunedFreq: { ~freq.value }, group: n.synthgroup, bus: n.inbus.index));

~streams = { |i| p.(i).asEventStreamPlayer(~ev) } ! 3;
~streams.do { |strm, i|
	var	upd;
	upd = Updater(strm, { |obj, what|
		[i, what].debug("notify");
		if(what == \stopped) { upd.remove };
	});
};

w.tryPerform(\close);
w = Window(\test, Rect(Window.screenBounds.width - 150, 10, 145, 50));
Button(w, w.view.bounds.insetBy(2, 2))
	.states_([["click", Color.new255(255, 200, 200), Color.black]])
	.action_({ ~streams.do { |strm| strm.next(TempoClock.beats) } });
w.front;

~streams.do { |strm| strm.removedFromScheduler };

// ok, f*ck - why is it so hard to trigger events by hand?
(
PR(\abstractProcess).clone {
	~event = (eventKey: \monoSupport, immediateOSC: true);
	~vcKey = \am;
	~prep = {
		if(VC.exists(~vcKey).not) {
			"VC(%) doesn't exist. Please create it before using BP(%)."
				.format(~vcKey.asCompileString, ~collIndex.asCompileString).warn;
		};
		~makeStreamForKey.(\level);
		currentEnvironment
	};
	~alwaysReset = true;
	~pan = 0;

	~rewriteProb = 0.3;
	~phrases = [
		#[2, 5, 4],
		#[2, 7, 6, 4, 8],
		#[2, 5, 6, 4],
		#[9, 8, 3],
		#[8, 11, 10, 5, 2, 3, 4],
		#[-2, -5, 0, 1, 0, 4]
	];
	~degree = Plazy {
		var	self = currentEnvironment;
		Pswitch(
			~phrases.collect { |row|
				PR(\rewriter).copy.prep(Pseq(row, 1), Pfuncn(e { ~levelStream.next }, 1), [
					(_.notNil) -> { |item, level, inval|
						if(self[\rewriteProb].coin) {
							item + [0, rrand(1, 3) * #[-1, 1].choose].rotate(2.rand)
						} { [item] }
					}
				])
			},
			\patRejectLastN.eval(Pseq([0, 1, 2, Prand((0 .. (a.size-1)), inf)]), 1)
		)
	};

	~dur = Pwrand(#[1, 2], #[0.9, 0.1], inf);
// 	~legato = Pwrand(#[1.01, 0.9, 0.4], #[0.7, 0.2, 0.1], inf); // 1.01;
	~gate = 0.8;
	~freqlag = 0.3;
	~detune = 1.003;
	~gate = 0.8;
	~level = (Pn(0, 3) ++ Pexprand(0.01, 2.99, inf).collect(_.asInteger)).trace(prefix: "level: ");
	~recvEventNotify = { |node| ~node = node };
	~stopCleanup = { if(~node.notNil) { ~node.release }; ~node = nil };
	~asPattern = {
		Pbind(
			\instrument, VC(~vcKey).v.nodes[0].defname.asSymbol,
//			\level, BPStream(\level),
			\node, Pfunc { ~node ?? { 0 } },
			\protoEvent, Pif(Pfunc { ~node.isNil }, \singleSynthPlayNotify, \singleSynthTrigger),
			\node, Pfunc { ~node ?? { 0 } },
			\root, 7,
			\freq, (BPStream(\degree).degreeToKey(#[0, 2, 4, 5, 7, 9, 11]) + 67).midicps,
			\delta, BPStream(\dur),
// 			\legato, BPStream(\legato),
			\gate, BPStream(\gate),
			\freqlag, BPStream(\freqlag),
			\detune, BPStream(\detune),
			\gate, BPStream(\gate),
			\pan, BPStream(\pan),
			\chan, VC(\am).env.target
		)
		// now this is a problem - you don't know when the next trigger is,
		// so you don't know when to release
		// removing for now
// 		.collect { |ev|
// 			if(~node.notNil and: { ev[\legato] < 1 }) {
// 				\schedEventBundleArray.eval(ev[\lag] ? 0, ev[\timingOffset] ? 0,
// 					ev[\server] ?? { Server.default },
// 					[~node.releaseMsg], nil, true
// 				);
// 				~node = nil;
// 			};
// 			ev
// 		};
	};
	~reset = Func(\resetBPStreams).v;
} => PR(\melody);
)

Pexprand(0.15, 2.99, inf).collect(_.asInteger).asStream.nextN(1000).histo(3, 0, 2);

3.do { |i|
	var name = ("ml" ++ i).asSymbol;
	BP(name).free;
	PR(\melody).chuck(BP(name), nil, (pan: i-1));
	0 => BP(name)
};

s.sendMsg(\n_free, 1049);
BP(\ml1).node

BP.all.do { |bp|
	bp.reset = {
		var	str;
		~collIndex.debug("reset");
		currentEnvironment.env.keys.do { |key|
			if(key != \eventStream and: { (str = key.asString).contains("Stream") }) {
				~makeStreamForKey.(str[ .. str.size - 7].asSymbol);
			}
		}
	};
};


w.tryPerform(\close);
w = Window(\test, Rect(Window.screenBounds.width - 150, 10, 145, 50));
Button(w, w.view.bounds.insetBy(2, 2))
	.states_([["click"]])
	.action_({
		BP(\ml1).triggerOneEvent(0);
	});
w.front;

BP(\ml1).node.trace;
BP(#[ml0, ml1, ml2]).do { |bp| bp.freqlag = 0.8 };

BP.all.reset;
BP.all.do({ |bp| bp.v.reset });  // WHY WHY WHY WHY?????!!!
~ct = 0;

w.tryPerform(\close);
w = Window(\test, Rect(Window.screenBounds.width - 150, 10, 145, 50));
Button(w, w.view.bounds.insetBy(2, 2))
	.states_([["click"]])
	.action_({
		3.do { |i|
			var name = ("ml" ++ i).asSymbol;
			if(i <= ~ct and: { 0.92.coin }) { BP(name).triggerOneEvent(0) };
		};
		~ct = ~ct + 1;
	});
w.front;

w.tryPerform(\close);
w = Window(\test, Rect(Window.screenBounds.width - 150, 10, 145, 50));
Button(w, w.view.bounds.insetBy(2, 2))
	.states_([["click"]])
	.action_({
		fork {
			(0..2).scramble.do { |i|
				var name = ("ml" ++ i).asSymbol;
				BP(name).triggerOneEvent(0);
				rrand(0.2, 0.6).wait;
			};
		};
	});
w.front;

BP.all.stop;

BP(\ml0).triggerOneEvent(0);
e = BP(\ml0).eventStream.next(BP(\ml0).event.copy);

BP(\ml0)[\eventStream]
BP.all.do({ |bp| bp.event.immediateOSC = true });


a = [
	#[2, 5, 4],
	#[2, 7, 6, 4, 8],
	#[2, 5, 6, 4],
	#[9, 8, 3],
	#[8, 11, 10, 5, 2, 3, 4],
	#[-2, -5, 0, 1, 0, 4]
];
p = Pswitch(
	a.collect { |row|
		PR(\rewriter).copy.prep(Pseq(row, 1), Pfin(1, Pkey(\level)), [
			(_.notNil) -> { |item, level, inval|
				if(0.3.coin) { item + [0, rrand(1, 3) * #[-1, 1].choose] } { [item] }
			}
		])
	},
	\patRejectLastN.eval(Pseq([0, 1, 2, Prand((0 .. (a.size-1)), inf)]), 1)
);

p.inspect

BP.all.do { |bp|
	bp.degree = p;
	bp.level = Pn(0, 3) ++ Pexprand(0.01, 2.99, inf).collect(_.asInteger)
};

BP(\ml1).use { ~eventStream.next(~ev.copy) };

Pdefn(\level, 1);

q = Pswitch(
	a.collect { |row|
		PR(\rewriter).copy.prep(Pseq(row, 1), Pfin(1, Pdefn(\level)), [
			(_.notNil) -> { |item, level, inval|
				if(0.3.coin) { item + [0, rrand(1, 3) * #[-1, 1].choose] } { [item] }
			}
		]) //.keepLowerLevels_(true)
	},
	\patRejectLastN.eval(Pseq([0, Prand((0 .. (a.size-1)), inf)]), 1)
).asStream;

q.nextN(20);

p.list[0].listVars



// swirling, spatialized chords

Fact(\armsChordVC) => VC(\ac);

// quicky spatial test

w.tryPerform(\close);
w = Window("test", Rect(Window.screenBounds.width - 405, 5, 400, 400));
d = Slider2D(w, w.view.bounds.insetBy(2, 2));
w.front;


(
p = Pchain(
	Ppar([
		Pbind(
			\type, \setProperties,
			\receiver, d,
			\args, #[x, y],
			\x, Pkey(\pan).linlin(-1, 1, 0, 1),
			\y, Pkey(\distance).linlin(Pkey(\distNear), Pkey(\distFar), 0, 1)
		),
		Pbind(
			\type, \voicerNote,
			\voicer, VC(\ac).v,
			\degree, Pseq([9, 6, 4, 2, -1, -3], inf),
			\legato, 0.7,
			\gate, 0.2,
			\mod_lev, Pkey(\distance).linlin(Pkey(\distNear), Pkey(\distFar), 2.5, 1)
		)
	]),
	Pstutter(2, Pbind(
		\distNear, 5,
		\distFar, 20,
		\angle, (Ptime() * 2pi / 2).wrap(0, 2pi),
		\radius, sin(Ptime() * 2pi / 6.3746263543) * 0.45 + 0.55,
		\pan, Pkey(\angle).cos * Pkey(\radius),
		\distance, (Pkey(\angle).sin * Pkey(\radius)).linlin(-1, 1, Pkey(\distNear), Pkey(\distFar)),
		\glrvbout, ~glrvbmc.inbus,
		\lcrvbout, ~lcrvbmc.inbus,
		\dur, 0.1
	))
).play;
)

p.stop;

VC(\ac).v.trace;


MBM(0)[\waterch].midiNotes.collect { |n| n.asInteger.asMIDINote };

a = [48, 55, 57, 64, 66, 74, 81, 83];
b = (a +.x #[-12, 0, 12]).removeDups.sort;	// for ordering
c = (#[-12, 0, 12] +.t a);	// for hierarchy
e = c.collect { |row, i|
	row.collect { |item| [item, i] }
}.flatten(1).sort { |a, b| a[0] < b[0] or: { a[0] == b[0] and: { a[1] < b[1] } } };

c.do { |row|
	var	lastI = 0, i;
	row.do { |item|
		i = b.indexOf(item);
		Post << (i - lastI).reptChar($\t) << item.asMIDINote;
		lastI = i;
	};
	Post << Char.nl;
};

// maybe choose the row based on height?
// no, octave xposition will be too obvious
C2	G2	A2		E3	F#3				D4				A4	B4
			C3			G3	A3			E4	F#4				D5			A5	B5
								C4				G4	A4			E5	F#5			D6	A6	B6


~angle = GenericGlobalControl(\angle, 3997.asBus(server: Server.default), 0, [0, 2pi]);
~rotSpeed = GenericGlobalControl(\rotSpeed, 4000.asBus(server: Server.default), 0, [0, 2]);

~angle.dependants

~win = ResizeFlowWindow("", Rect(10, 10, 200, 100));
~angle.gui(~win);
~win.startRow;
~rotSpeed.gui(~win);
~win.recursiveResize.front;

[~angle, ~rotSpeed].do(_.watch);
KrBusWatcher.newFrom(s).updateFreq = 8;

s.makeBundle(nil, {
	~angle.automate { Sweep.kr(1, LFNoise1.kr(0.25).exprange(0.1, 1.8)).wrap(0.0, 1.0) * 2pi };
	~rotSpeed.automate {
		var a = ~angle.kr,
			last = Select.kr(Impulse.kr(0), [LocalIn.kr(1), a]);
		a = a.wrap(last - pi, last + pi);
		LocalOut.kr(a);
		Slope.kr(a) / 2pi
	};
	~rotSpeed.autoSynth.moveAfter(~angle.autoSynth);
});

[~angle, ~rotSpeed].do { |gc| gc.stopAuto.stopWatching };


~guiUpdate = { |ev|
	defer {
		d.setXY(ev[\pan].linlin(-1, 1, 0, 1), ev[\distance].linlin(ev[\distNear], ev[\distFar], 0, 1))
	};
	ev
};

(
p = Pfset(e {
		[~angle, ~rotSpeed].do(_.watch);
		KrBusWatcher.newFrom(s).updateFreq = 8;
		s.makeBundle(nil, {
			~angle.automate { Sweep.kr(1, LFNoise1.kr(0.25).exprange(0.1, 1.8)).wrap(0.0, 1.0) * 2pi };
			~rotSpeed.automate({
				var a = ~angle.kr,
					last = Select.kr(Impulse.kr(0), [LocalIn.kr(1), a]);
				a = a.wrap(last - pi, last + pi);
				LocalOut.kr(a);
				Slope.kr(a) / 2pi
			}, ~angle.autoSynth, \addAfter);
		});
	},
	Pbind(
		\type, \voicerNote,
		\voicer, VC(\ac).v,
		\angle, ~angle, // (Ptime() * 2pi / 8).wrap(0, 2pi) + (Pkey(\row) * (2pi/3)),
		\rotSpeed, ~rotSpeed.asPattern * 0.5,
		\radius, sin(Ptime() * 2pi / 11.3247623) * 0.2 + (0.8 * Pkey(\rotSpeed)),
		\row, Pwhite(0, Pkey(\rotSpeed) * 2.99, inf).collect(_.asInteger),
// 		#[midinote, row], Pxrand(e, inf),
		\midinote, Pnsym1(Pkey(\row).collect(_.asSymbol),
			c.collectAs({ |row, i| i.asSymbol -> Pxrand(row, inf) }, IdentityDictionary)
		),
		\gate, 0.2,
		\distNear, 5,
		\distFar, 20,
		\pan, Pkey(\angle).cos * Pkey(\radius),
		\distance, (Pkey(\angle).sin * Pkey(\radius)).linlin(-1, 1, Pkey(\distNear), Pkey(\distFar)),
		\mod_lev, Pkey(\distance).linlin(Pkey(\distNear), Pkey(\distFar), 2.5, 1),
		\glrvbout, ~glrvbmc.inbus,
		\lcrvbout, ~lcrvbmc.inbus,
		\dur, Pkey(\rotSpeed).reciprocal / 40,
		\sustain, Pkey(\dur) * (3 - Pkey(\row))  // hmm... not quite
	).collect(~guiUpdate), //.trace(#[row, midinote]),
	e { [~angle, ~rotSpeed].do { |gc| gc.stopAuto.stopWatching } }
).play;
)

p.stop;

p.isPlaying;

PeakMonitor(~master)
PeakMonitor(0)

TempoClock.clear

(1003..1004).do(s.sendMsg(\n_free, _))
~angle.autoSynth

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;

(
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote, distNear: 5, distFar: 20, midi: false);
	~alwaysReset = true;

	~chords = (
		// each is mode name (symbol), then midinotes
		c_ish: #[g, 48, 55, 57, 64, 66, 74, 81, 83]
	);

	~row = Pwhite(0, Pkey(\rotSpeed) * 2.99, inf).collect(_.asInteger);
	~chord = Plazy { Pn(Pshuf(~fullCh.keys.asArray, 1), inf) }; // Pstutter(Pwhite(20, 60, inf), Pfunc { ~fullCh.keys.choose });
	~chordItem = Pfunc { |ev|
		if(ev[\chord] != ~lastChord) {
			~lastChord = ev[\chord];
			// force reset - this makes Plazy reevaluate and grab other chord item
			~makeStreamForKey.(\midinote);
		};
		~fullCh[~lastChord]
	};
	~midinote = \patRejectLastN.eval(Plazy { |ev|
		var	arpeg = ~arpegStream.next(ev);
		Pswitch1(ev[\chordItem][\hierarchy].collect { |row|
			ArpegPat(arpeg).asPattern(row)
		}, Pkey(\row))
	}, 1);
	~arpeg = \armsCh;
	~gate = Pexprand(0.05, 0.2, inf) * Pkey(\rotSpeed).linlin(0.1, Pfunc { ~maxRotSpeed }, 0.6, 4);
// 	~gate = 0.2;

	~mod_lev = Pkey(\distance).linlin(Pkey(\distNear), Pkey(\distFar), 2.5, 1);
	~radius = sin(Ptime() * 2pi / 11.3247623) * 0.5 + (0.5 * Pkey(\rotSpeed) / Pfunc { ~maxRotSpeed });
// 	~radius = sin(Ptime() * 2pi / 11.3247623) * 0.2 + (0.8 * Pkey(\rotSpeed));

	~dur = Pwrand(#[1, 2], #[0.9, 0.1], inf) * Pkey(\rotSpeed).linexp(0.1, Pfunc { ~maxRotSpeed }, 0.4, 0.08);
	~sustain = Pwhite(1.2, 2.0, inf) * 4 / (Pkey(\row) + 4);
// 	~dur = max(0.1, Pkey(\rotSpeed)).reciprocal / 40;
// 	~sustain = Pkey(\dur) * (3 - Pkey(\row));  // hmm... not quite
	~attScale = Pkey(\rotSpeed).linexp(0.1, Pfunc { ~maxRotSpeed }, 0.5, 1);
// 	~attScale = max(0.1, Pkey(\rotSpeed)).reciprocal * 0.2;
	~decScale = Pkey(\attackTimeScale);

	~maxRotSpeed = 2;
	~maxRotSpeed_ = { |speed = 1|
		if(speed != ~maxRotSpeed) {
			~maxRotSpeed = speed;
			~rotSpeed.spec = [0, speed];  // asSpec is automatic
		};
		currentEnvironment
	};
	~speedThresh = 0.15;
	~angleBus = 3997;
	~rotSpeedBus = 4000;

	~prep = {
		~angle = GenericGlobalControl(\angle, ~angleBus.asBus(\control), 0, [0, 2pi]);
		~rotSpeed = GenericGlobalControl(\rotSpeed, ~rotSpeedBus.asBus(\control), 0, [0, ~maxRotSpeed]);
		KrBusWatcher.newFrom(s).updateFreq = 8;
		~initChords.();
	};

	~copyProc = { |name ((~collIndex ++ UniqueID.next).asSymbol)|
		var	self = currentEnvironment, parms;
		BP(name).free;
		parms = (
			angleBus: Bus.control(s, 1 /*, name + "angle"*/),
			rotSpeedBus: Bus.control(s, 1 /*, name + "rotSpeed"*/),
			shouldFreeGCs: true,
			initChords: {
				~fullCh = self[\fullCh];
			},
			chord: (~chordStream ?? { ~makeStreamForKey.(\chord) }).next
		);
		// this is so I can change patterns in the dispatcher
		// and they get spawned thru to the children
		~bpsKeys.do { |key| parms[key] = key.envirGet };
		PR(\armsChord).chuck(BP(name), nil, parms);
		~event[\voicer] => BP(name)	// should return BP
	};

	~spawnChild = { |quant = 0|
		var bp = ~copyProc.(),
			lastSpawned = ~lastSpawned,
			upd = Updater(bp, e { |obj, what, more|
				if(more == \stopped) {
					upd.remove;
					if(~lastSpawned == bp.collIndex) { ~lastSpawned = nil };
					if(BP.exists(bp.collIndex)) {
						bp.free;
					};
				}
			});
		// this is a moderately obscene hack
		if(lastSpawned.notNil) {
			// ctlPoint uses replaceOut, will overwrite "real" autoSynth
			Synth(\ctlPoint, [outbus: BP(lastSpawned).rotSpeed.bus, value: 0, time: ~killOldProcTime],
				BP(lastSpawned).rotSpeed.autoSynth, \addAfter);
			thisThread.clock.sched(~killOldProcTime - 0.01, {
				BP(lastSpawned).rotSpeed.stopAuto; nil
			});
		};
		~lastSpawned = bp.collIndex;
		bp.play(quant);
	};
	~killOldProcTime = 1.4;

	~bpsKeys = #[radius, /*chord,*/ chordItem, row, midinote, gate, mod_lev, dur, sustain, attScale, decScale, arpeg, maxRotSpeed];

	// dispatcher will override this to pull prepared fullCh dictionary,
	// rather than rebuilding every time
	~initChords = {
		~fullCh = IdentityDictionary.new;
		~chords.tryPerform(\keysValuesDo, { |key, value|
			~addChord.(key, value)
		});
	};

	~addChord = { |key, value|
		~fullCh.put(key, ~expandChord.(value))
	};

	~expandChord = { |array, adds = #[-7, 0, 7]|
		var	mapped = array[1..].mapMode(array[0]),
			result = (mode: array[0], orig: mapped, allSort: (mapped +.x adds).removeDups.sort,
			hierarchy: adds +.t mapped);
		result.put(\hierarchyDict,
			result[\hierarchy].collectAs({ |row, i| i.asSymbol -> row },
				IdentityDictionary)
		)
		.put(\sortWithLevels, result[\hierarchy].collect { |row, i|
			row.collect { |item| [item, i] }
		}.flatten(1).sort { |a, b| a[0] < b[0] or: { a[0] == b[0] and: { a[1] < b[1] } } });
	};

// 	~startAuto = { |ev, envir, angle(~angle), rotSpeed(~rotSpeed)|
// 		s.makeBundle(nil, {
// 			angle.automate {
// 				Sweep.kr(1, LFNoise1.kr(0.25).range(0.1, 1.8)).wrap(0.0, 1.0) * 2pi
// 			};
// 			rotSpeed.automate({ |maxRotSpeed = 1|
// 				var a = ~angle.kr,
// 					last = Select.kr(Impulse.kr(0), [LocalIn.kr(1), a]);
// 				a = a.wrap(last - pi, last + pi);
// 				LocalOut.kr(a);
// 				Slope.kr(a) / (2pi * maxRotSpeed)
// 			}, target: angle.autoSynth, addAction: \addAfter);
// 		});
// 	};

	~startAuto = {
		var	proportion = rrand(0.2, 0.7);
		s.makeBundle(nil, {
			~rotSpeed.automate({ |outbus|
				// eventually:
// 				Line.kr(0, 1, rrand(3.5, 8.0))
// 				In.kr(~rotSpeedInBus ? outbus)
// 					* LFDNoise1.kr(LFNoise1.kr(1.2).range(0.4, 2.5)).exprange(0.8, 1.25)
				EnvGen.kr(Env(#[0.1, 1.9, 0.14], [proportion, 1 - proportion], \sin),
					timeScale: rrand(3.5, 8.0), doneAction: 2)
			}, nil, ~chan.tryPerform(\fadergroup), \addToHead);
			~angle.automate({
				// leaky integrator is not leaky if coef == 1
				Integrator.kr(~rotSpeed.kr * ControlDur.ir, 1).wrap(0, 2pi);
			}, nil, ~rotSpeed.autoSynth, \addAfter);
		});
		OSCpathResponder(s.addr, ['/n_end', ~rotSpeed.autoSynth.nodeID], e { |time, resp, msg|
			resp.remove;
			if(BP.exists(~collIndex)) {
				BP(~collIndex).stop(0);
			};
		}).add;
	};

	~stopCleanup = {
		s.makeBundle(0.1, {
			[~angle, ~rotSpeed].do { |gc| gc.stopAuto.stopWatching }
		});
	};

	~freeCleanup = {
		if(~shouldFreeGCs ? true) {
			[~angle, ~rotSpeed].free;
		};
	};

	~useGui = { |vpi|
		[~angle, ~rotSpeed].do { |gc| gc => VP(vpi) };
	};


	~asPattern = {
		~arpegStream ?? { ~makeStreamForKey.(\arpeg) };
		Pseq([
			// workaround scel indent bug
			'Pfuncn'.asClass.new { |ev|
				[~angle, ~rotSpeed].do(_.watch);
				~startAuto.();
				Event.silent(0)
			},
			Pbind(
				\angle, ~angle,
				\rotSpeed, ~rotSpeed,
				\radius, BPStream(\radius),
				\pan, Pkey(\angle).cos * Pkey(\radius),
				\distance, (Pkey(\angle).sin * Pkey(\radius)).linlin(-1, 1, Pkey(\distNear), Pkey(\distFar)),
				\chord, if(~chord.isSymbol) { ~chord } { BPStream(\chord) },
				\chordItem, BPStream(\chordItem),
				\row, BPStream(\row),
				\freq, BPStream(\midinote),
				\mode, Pfunc { |ev| ev[\chordItem][\mode] },
				\gate, BPStream(\gate),
				\mod_lev, BPStream(\mod_lev),
				\dur, BPStream(\dur),
				\length, BPStream(\sustain),
				\attackTimeScale, BPStream(\attScale),
				\decayTimeScale, BPStream(\decScale)
			) //.trace
		])
	};
} => PR(\armsChord);
)

BP(\ac).free;
PR(\armsChord) => BP(\ac);
BP(\ac) => VC(\ac);
0 => BP(\ac);
p = BP(\ac);

BP(\ac) =>.72 MT(1);


p.dur = Pwrand(#[1, 2], #[0.9, 0.1], inf) * Pkey(\rotSpeed).linexp(0.1, Pfunc { ~maxRotSpeed }, 0.22, 0.08);
// p.sustain = (Pkey(\dur) * (12 / (Pkey(\row) + 1)));  // hmm... not quite
// p.sustain = Pkey(\dur) * Pswitch1([Pwhite(1.8, 3.5, inf), Pwhite(3.0, 6.0, inf), Pwhite(6.0, 14.0, inf)], Pkey(\row));
p.sustain = Pwhite(1.2, 2.0, inf) * 4 / (Pkey(\row) + 4);

p.attScale = Pkey(\rotSpeed).linexp(0.1, Pfunc { ~maxRotSpeed }, 0.5, 1);

p.gate = Pexprand(0.05, 0.2, inf) * Pkey(\rotSpeed).linlin(0.1, Pfunc { ~maxRotSpeed }, 1, 4);

p.radius = sin(Ptime() * 2pi / 11.3247623) * 0.5 + (0.5 * Pkey(\rotSpeed) / Pfunc { ~maxRotSpeed });

p.arpeg = \armsCh;

{ |notes| 
	Penvir((),
		Pwalk(notes, Pwrand([
			Pseq([Pn(1, { ~n = rrand(2, 4) }), Pfuncn { 1 - ~n }], 1),  // 1-n == (n-1).neg
			Pseq([Pn(-1, { ~n = rrand(2, 4) }), Pfuncn { ~n - 1 }], 1),
// 			Pn(-1, { rrand(2, 4) }),
			-2, 2,
		], #[0.4, 0.1, 0.1, 0.4], inf), Pseq(#[1, -1], inf), 0)
	)
} => ArpegPat(\armsCh);

p.midinote = \patRejectLastN.eval(Plazy { |ev|
	var	arpeg = ~arpegStream.next(ev).debug("arpeg");
	Pswitch1(ev[\chordItem][\hierarchy].collect { |row|
		ArpegPat(arpeg).asPattern(row)
	}, Pkey(\row))
}, 1);


// triggerable by rotSpeed threshold

p.makeOneArpeg = {
	// envir is to isolate BPStreams
	var	self = currentEnvironment, envir = (), pat, upd;
	~arpegStream ?? { ~makeStreamForKey.(\arpeg) };
	~patKeys.do { |key| envir[key] = key.envirGet };
	envir.angle = GenericGlobalControl(\angle, nil, 0, [0, 2pi]);
	envir.rotSpeed = GenericGlobalControl(\rotSpeed, nil, 0, [0, ~maxRotSpeed]);
	pat = Penvir(envir,
		// force pattern to be made in context of the local envir
		'Plazy'.asClass.new {
			self.asPattern(envir, ~angle, ~rotSpeed);
		}
	).asEventStreamPlayer(BP(~collIndex).prepareEvent);
	// for some stupid reason, Pfset's cleanup func did not fire
	// so I have to use a notification to remove the global controls created locally
	upd = Updater(pat, { |obj, what|
		if(what == \stopped) {
			upd.remove;
			#[angle, rotSpeed].do { |key| envir[key].debug("freeing").free }
		};
	});
	pat
};

p.patKeys = #[radius, chord, chordItem, row, midinote, gate, mod_lev, dur, sustain, attScale, decScale, maxRotSpeed, fullCh, arpeg, arpegStream];

();
PR(\armsChord).startAuto = {
	var	proportion = rrand(0.2, 0.7);
	s.makeBundle(nil, {
		~rotSpeed.automate({
			In.kr(BP(\di).bus.index+4, 1).linlin(0, 1, 0.1, 1.0)
		}, nil, ~chan.tryPerform(\fadergroup), \addToHead);
		~angle.automate({
			// leaky integrator is not leaky if coef == 1
			Integrator.kr(~rotSpeed.kr * ControlDur.ir, 1).wrap(0, 2pi);
		}, nil, ~rotSpeed.autoSynth, \addAfter);
	});
	OSCpathResponder(s.addr, ['/n_end', ~rotSpeed.autoSynth.nodeID], e { |time, resp, msg|
		resp.remove;
		if(BP.exists(~collIndex)) {
			BP(~collIndex).stop(0);
		};
	}).add;
};


Fact(\armsChordVC) => VC(\ac);

BP(\acDisp).free;
PR(\armsChord) => BP(\acDisp);
BP(\acDisp) => VC(\ac);
0 => BP(\acDisp);
p = BP(\acDisp);

BP(\acDisp) =>.72 MT(1);


BP(\acDisp).dur = PR(\armsChord).dur;
BP(\acDisp).dur = BP(\acDisp).dur + 0.2;
BP(\acDisp).dur = BP(\acDisp).dur.trace(prefix: "dur: ");

p.maxRotSpeed = 1;

p.dur.postcs

p.dur = Pwrand(#[1, 2], #[0.9, 0.1], inf) * Pkey(\rotSpeed).linexp(0.1, Pfunc { ~maxRotSpeed }, 0.7, 0.06);
p.dur = Pwrand(#[1, 2], #[0.9, 0.1], inf) * (Pkey(\rotSpeed).collect { |rs|
	var	rs2 = rs.linexp(0.1, ~maxRotSpeed, 0.7, 0.06);
	if(rs > (~maxRotSpeed * 0.42)) { rs2 * 0.5 } { rs2 }
});

BP(\di).play;
u = Updater(BP(\di), { |obj, what, more|
	if(more == \stopped) {
		u.remove;
		BP(BP(\acDisp).lastSpawned).stop;
	};
});
BP(\acDisp).spawnChild => VP(1);
//BP(BP(\acDisp).lastSpawned) => MT(1);


BP(BP(\acDisp).lastSpawned).rotSpeed.value

BP(\di).stop;

(
Proto {
	~quant = NilTimeSpec.new;
	~doAction = {
		var i = VP.collection.detectIndex { |vp|
			vp.v.controlProxies.every { |gcp| gcp.gc.isNil }
		};
		if(i.isNil) {
			BP(\acDisp).spawnChild
		} {
			BP(\acDisp).spawnChild => VP(i)
		};
	};
} => BP(\test);
)

p.row = Pwhite(0, Pkey(\rotSpeed) * 2.99, inf).collect(_.asInteger);
p.gate = Pexprand(0.05, 0.2, inf) * Pkey(\rotSpeed).linexp(0.1, Pfunc { ~maxRotSpeed }, 0.2, 4);
p.dur = Pwrand(#[1, 2], #[0.9, 0.1], inf) * Pkey(\rotSpeed).linexp(0.1, Pfunc { ~maxRotSpeed }, 0.4, 0.08);

p.fullCh.keys

p.chords[\c_ish][1..].collect(_.asMIDINote)
p.addChord(\em, #[g, 52, 59, 60, 67, 69, 74, 78, 79, 83, 93]);
p.addChord(\am, #[g, 45, 54, 55, 62, 64, 72, 76, 83]);
p.addChord(\g, #[g, 43, 52, 57, 59, 66, 67, 74, 76, 84]);

p.chord = Pn(Pshuf(p.fullCh.keys.asArray, 1), inf).trace(prefix: "chord: ");
p.copyProc = { |name ((~collIndex ++ UniqueID.next).asSymbol)|
		var	self = currentEnvironment, parms;
		BP(name).free;
		parms = (
			angleBus: Bus.control(s, 1 /*, name + "angle"*/),
			rotSpeedBus: Bus.control(s, 1 /*, name + "rotSpeed"*/),
			shouldFreeGCs: true,
			initChords: {
				~fullCh = self[\fullCh];
			},
			chord: (~chordStream ?? { ~makeStreamForKey.(\chord) }).next
		);
		// this is so I can change patterns in the dispatcher
		// and they get spawned thru to the children
		~bpsKeys.do { |key| parms[key] = key.envirGet };
		PR(\armsChord).chuck(BP(name), nil, parms);
		~event[\voicer] => BP(name)	// should return BP
	};
p.bpsKeys = #[radius, /*chord,*/ chordItem, row, midinote, gate, mod_lev, dur, sustain, attScale, decScale, arpeg];

#[43, 52, 57, 59, 66, 67, 74, 76, 84].collect(_.asMIDINote)

s.sendMsg(\n_trace, 1177);
s.sendMsg(\n_free, 1005);

fork {
	5.do { |i|
		BP(\acDisp).spawnChild => VP(i);
		rrand(1.5, 3.5).wait;
	}
};

();
z = Pbind(
	\type, \voicerNote,
	\voicer, VC(\ac).v,
	\degree, Pwhite(0, 7, inf),
	\dur, 0.5,
	\gate, Pif(Ptime() < 8, Env(#[0.1, 1, 0.1], #[0.5, 0.5] * 8, \sin))
).play;

z.stop;