ChuckableBrowser.newWindow;
SynthDescLib.global.browse;
Object.browse;
s.queryAllNodes;

MIDIPort.init([1]);
MIDIPort.resetAll;

(
[m, n].free;
m = MixerChannel(\test1, s, 1, 2);
n = MixerChannel(\test2, s, 2, 2);
//MixingBoard(\test, nil, m, n);

b = MixingBoard.new;
8.do { |i|
	MixerChannelGUI.new(nil, b) => MCG.prNew(i);
	if(MIDIPort.initialized) {
		MixerMIDIControl(\omni, nil, MCG(i).v);
	};
	b.add(MCG(i).v);
};

m => MCG(0); n => MCG(1);
//~master => MCG(7);
)

MixingBoard.at(0).refresh;

// in case I forgot to init midi first
8.do { |i| MixerMIDIControl(\omni, nil, MCG(i).v); };

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

MIDIPort.autoFreeSockets = true;

v = WrapInstr("osc2.vosc3mapfilt").miditest(0, [bufbase: `(~wt.first.bufnum), numbufs: `(~wt.size), basefreq: `(48.midicps), topfreq: `(132.midicps), env: Env.adsr(0.4, 0, 1, 1.2), \ffreq, 2423.054873855, \rq, 1, \vsens, 0.84722220897675, \detune, 1.003], target: n);

// no lag arg built in
// I like the general direction of this, needs to be smoother
v = WrapInstr("osc2.vosc3mapfilt").miditestMono(0, [bufbase: `(~wt.first.bufnum), numbufs: `(~wt.size), basefreq: `(48.midicps), topfreq: `(132.midicps), env: Env.adsr(0.4, 0, 1, 1.2), \ffreq, 2423.054873855, \rq, 1, \vsens, 0.84722220897675, \detune, 1.003], target: n);
v.portaTime = 1.1;

FxPatch(
	[ 'busfx', 'chorus2' ], [ 18, 1, 2, 3, KrNumberEditor(0.01285261232269, ControlSpec(0.0001, 0.2, 'exp', 0, 0.001, "")), KrNumberEditor(0.077426358822457, ControlSpec(0.001, 10, 'exp', 0.0, 0.001, "")), KrNumberEditor(0.00860870962377, ControlSpec(0.0001, 0.25, 'exp', 0.0, 0.0001, "")), KrNumberEditor(0.87266466760906, ControlSpec(0, 6.2831853071796, 'linear', 0.0, 0, "")), KrNumberEditor(0.15647481535888, ControlSpec(0.1, 10, 'exp', 0, 1, "")) ]
)


p = Pbind(
	\type, \voicerNote,
	\voicer, v,
	\root, 7,
	\degree, Pseq(#[2, 5, 4, 2, 7, 6, 4, 8, 2, 5, 6, 4], inf),
	\dur, Pwrand(#[1, 1.5], #[0.9, 0.1], inf),
	\legato, 1.01,
	\gate, 0.8
).play;

z = n.playfx(WrapInstr("busfx.chorus2"), [0, 1, 2, 3]); z.gui;

p.stop;

\ffreq, 2423.054873855, \rq, 1, \vsens, 0.84722220897675, \detune, 1.003
