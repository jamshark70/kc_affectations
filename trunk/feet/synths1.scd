
ChuckableBrowser.newWindow;
SynthDescLib.global.browse;
Object.browse;
s.queryAllNodes;

MIDIPort.init([2]); //([1]);
MIDIPort.resetAll;

\makeEmptyMixer8.eval;

TempoClock.tempo = 110/60;

x = VoicerMIDIController(\omni, \knob);
x.dump
x.ccnum.shortName.dump
CControl.browse
x.free;

var cc;
8.do {
	cc = VoicerMIDIController(\omni, \knob);
	cc => CC.prNew(cc.ccnum.shortName.asSymbol);
};

MIDIPort.at(\omni).ccResponders.collectIndices(_.notNil)

(
var b;
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

{ MixingBoard.at(0).refresh }.defer(3.0);
)

MixingBoard.at(0).refresh;

// in case I forgot to init midi first
8.do { |i| MixerMIDIControl(\omni, nil, MCG(i).v); };



// wavetable synth with slide (introduce pitches into feet section)
// decent prototype
~wt.free;

// ~wt = \makeWavetables.eval(8, s, 2048, nil, { |numHarm|
// 	Array.sawtoothAmps(numHarm)
// });

(
var	nh = (s.sampleRate * 0.5 / 79.midicps).trunc,
	normalSpectrum = (1..nh).reciprocal,
	rwidth = 4,  // number above and below center to randomize
	// actually i/(rwidth*2) * 2pi but /2 *2 cancel out
	template = { |i| (i/rwidth * pi).cos.neg * 0.5 + 0.5 } ! (rwidth*2 + 1);
~wt.free;
~wt = Buffer.allocConsecutive(8, s, 2048, 1, { |buf, i|
	var	low = i.linlin(0, 7, 0, nh - (rwidth*2) - 1),
		spectrum = normalSpectrum.copy;
	template.do { |randAmt, i|
		spectrum[low + i] = spectrum[low + i] + randAmt.rand;
	};
	buf.sine1Msg(spectrum)

// 	var	center = i.linlin(0, 7, rwidth, nh - rwidth - 1),
// 		pool = (rwidth.neg .. rwidth).scramble,
// 		spectrum = normalSpectrum.copy;
// 	rrand(2, 5).do { |i|
// 		spectrum[(center + pool[i])] = rrand(0.5, 1.0);
// 	};
// 	buf.sine1Msg(spectrum)
});
)

~wt[7].plotWavetable

WrapInstr("osc2.vosc3map").openFile
WrapInstr("osc2.vosc3map").listArgs

WrapInstr("osc2.vosc3panslide", { |freq, startFreq, slideTime = 0, slideTrig = 1|
	freq = EnvGen.kr(Env([startFreq, freq], [slideTime], \sin), slideTrig);
	WrapInstr.wrap("osc2.vosc3panfilt", [freq]);
}, [NoLagControlSpec.newFrom(\freq.asSpec), NoLagControlSpec.newFrom(\freq.asSpec), NoLagControlSpec(0, 2), TrigSpec.new]);

WrapInstr("osc2.vosc3panslide").listArgs

v.free;

// basefreq: `(48.midicps), topfreq: `(127.midicps), 
v = WrapInstr("osc2.vosc3panslide").miditest(0, [bufbase: `(~wt.first.bufnum), numbufs: `(~wt.size), bufmod: KrNumberEditor(0, [0, ~wt.size-1.001]), env: Env.adsr(0.5, 0.1, 0.8, 0.6), detune: 1.003, slideTime: 0.7, ffreq: 18000], target: n);
v.unmapGlobal(\startFreq);
v.unmapGlobal(\slideTime);

k = MIDIPort.search(v);

// very basic
k.noteOnArgsPat = Pbind(
	\startFreq, Pkey(\midinote).midicps,
	\slideTrig, 1
);

// good
k.noteOnArgsPat = Penvir((), Pbind(
	\mfreq, Pkey(\midinote).midicps,
	\startFreq, Pif(
		Pfunc { v.nodes.any { |node| node.isPlaying and: { node.isReleasing.not } } },
		Pfunc { ~lastFreq },
		Pkey(\mfreq)
	),
	\saveFreq, Pfunc { |ev| ~lastFreq = ev[\mfreq] },
	\slideTrig, 1,
	\maxfreq, max(Pkey(\mfreq), Pkey(\startFreq)),
	\minfreq, min(Pkey(\mfreq), Pkey(\startFreq)),
	// lower bound is 1.0 b/c we will never divide a smaller by a larger number
	\slideTime, (Pkey(\maxfreq) / Pkey(\minfreq)).explin(1.0, 2.0, 0.7, 1.6, \none)
));

v.trace;


n = v.trigger(440, 0.5, [startFreq: 440]);
n.release;

// not bad
var	nh = (s.sampleRate * 0.5 / 79.midicps).trunc,
	normalSpectrum = (1..nh).reciprocal,
	rwidth = 4,  // number above and below center to randomize
	// actually i/(rwidth*2) * 2pi but /2 *2 cancel out
	template = { |i| (i/rwidth * pi).cos.neg * 0.5 + 0.5 } ! (rwidth*2 + 1);
~wt.do { |buf, i|
	var	low = i.linlin(0, 7, 0, nh - (rwidth*2) - 1),
		spectrum = normalSpectrum.copy;
	template.do { |randAmt, i|
		spectrum[low + i] = spectrum[low + i] + randAmt.rand;
	};
	buf.sine1(spectrum)
};

(r { ~wt.do { |buf| buf.plotWavetable; 0.5.wait } }).play(AppClock);

//7034375353

// good poc; actually higher bufnums don't sound so good here
// (well, they do when I'm not wearing earplugs)

p = Penvir((), Pbind(
	\type, \voicerNote,
	\voicer, v,
	\degree, Pvbrown(0, 11, Pwrand(#[-3, -2, -1, 1, 2, 3], #[1, 2, 3, 3, 2, 1].normalizeSum, inf)),
	\freq, Pfunc { |ev| ev.use { ~freq.value } },
	\startFreq, Pfunc { |ev| if(~lastFreq.isNil) { ev[\freq] } { ~lastFreq } },
	\saveFreq, Pfunc { |ev| ~lastFreq = ev[\freq] },
	\dur, 2,
	\legato, Pwhite(3.0, 6.0, inf)
)).play;

p.stop;


\default.asMode.v.copy.root_(7) => Mode(\g);

if(MBM.exists(0).not) { MIDIBufManager(chan: nil) => MBM.prNew(0) };

MIDIRecBuf(\ch1, [
	#[74, 76,  74, 79, 78],
	#[1, 2,  1, 1, 2],
	1, 0.5
].asNotes, (mode: \g, type: \ch, useOwnMode: true)) => MBM(0);

{ |notes|
	var	numEv = notes.estimateLength,
		totaldur = numEv * 2.0 + 6.0;
	Ptuple([2.0, Pseries(totaldur, -2, numEv), 0.5], 1)
} => MicRh(\slideArpeg);

{ |notes| Pseq(notes, 1) } => ArpegPat(\asis1);


BP(\slch).free;
\newCh.eval(\slch, \arpeg1, \macroRh, MBM(0)[\ch1], nil, 200, \slideArpeg, \asis1);
v => BP(\slch);

BP(\slch).child.argPairs = [
	startFreq: Pfunc { |ev| ev[\mode].asMode.cps(ev[\note].asFloat) }
];

// this exploits the fact that argPairs resets for each chord
BP(\slch).child.argPairs = [
	mnote: Pkey(\note).asFloat,
	startNote: Penvir((), 
		Pseq([
			Pfin(1, Pkey(\mnote)).collect { |note| ~startNote = note },
			Pfunc { |ev|
				~startNote <!! (~startNote = ev[\note].asFloat)
			}
		], 1)
	),
	#[mfreq, startFreq], Pfunc { |ev| ev[\mode].asMode.cps([ev[\mnote], ev[\startNote]]) },
	slideTrig: 1,
	maxfreq: max(Pkey(\mfreq), Pkey(\startFreq)),
	minfreq: min(Pkey(\mfreq), Pkey(\startFreq)),
	// lower bound is 1.0 b/c we will never divide a smaller by a larger number
	slideTime: (Pkey(\maxfreq) / Pkey(\minfreq)).explin(1.0, 2.0, 0.7, 1.6, \none)
];

MBM(0)[\ch1] => BP(\slch);

BP(\slch).reset;
BP(\slch).triggerOneEvent(0);

BP(\slch).child.chords[0].listVars

\g.asMode.cps(39)


(
WrapInstr("osc2.vosc3panslide", { |freq, startFreq, slideTime = 0, slideTrig = 1|
	freq = EnvGen.kr(Env([startFreq, freq], [slideTime], \sin), slideTrig);
	WrapInstr.wrap("osc2.vosc3panfilt", [freq]);
}, [NoLagControlSpec.newFrom(\freq.asSpec), NoLagControlSpec.newFrom(\freq.asSpec), NoLagControlSpec(0, 2), TrigSpec.new]);

(keys: #[master, rvbmc],
make: { |name|
	var	nh = (s.sampleRate * 0.5 / 79.midicps).trunc,
		normalSpectrum = (1..nh).reciprocal,
		rwidth = 4,  // number above and below center to randomize
		// actually i/(rwidth*2) * 2pi but /2 *2 cancel out
		template = { |i| (i/rwidth * pi).cos.neg * 0.5 + 0.5 } ! (rwidth*2 + 1),
		out;

	~wt = Buffer.allocConsecutive(8, s, 2048, 1, { |buf, i|
		var	low = i.linlin(0, 7, 0, nh - (rwidth*2) - 1),
		spectrum = normalSpectrum.copy;
		template.do { |randAmt, i|
			spectrum[low + i] = spectrum[low + i] + randAmt.rand;
		};
		buf.sine1Msg(spectrum)
	});

	~target = MixerChannel(name, s, 2, 2 /*, completionFunc */);
	out = Voicer(15, WrapInstr("osc2.vosc3panslide"), [bufbase: `(~wt.first.bufnum), numbufs: `(~wt.size)/*, bufmod: KrNumberEditor(0, [0, ~wt.size-1.001])*/, env: Env.adsr(0.8, 0.1, 0.8, 1.8), detune: 1.003, slideTime: 0.7, ffreq: 3000, vsens: `0.6], target: ~target);
	out.mapGlobal(\bufmod, nil, 0, [0, ~wt.size-1.001]);

	out
}, free: { [~target, ~wt].free }, type: \voicer) => Fact(\slidePad);
)

Fact(\slidePad) => VC(\sp);
VC(\sp) => MCG(2);
VC(\sp).v.gui;


// bass notes
// first try low notes on VC(\sp) -- too homogeneous
v = VC(\sp).v;
n = v.trigger(55, 1, args: [startFreq: 110]);
n.do(_.release);

WrapInstr("osc2.fm1").openFile
WrapInstr("osc2.vosc3filt").listArgs

(
	var	nh = (s.sampleRate * 0.5 / 55.midicps).trunc,
		normalSpectrum = (1..nh).reciprocal,
		rwidth = 4,  // number above and below center to randomize
		// actually i/(rwidth*2) * 2pi but /2 *2 cancel out
		template = { |i| (i/rwidth * pi).cos.neg * 0.5 + 0.5 } ! (rwidth*2 + 1),
		out;

	~wt.free;
	~wt = Buffer.allocConsecutive(8, s, 2048, 1, { |buf, i|
		var	low = i.linlin(0, 7, 0, nh - (rwidth*2) - 1),
		spectrum = normalSpectrum.copy;
		template.do { |randAmt, i|
			spectrum[low + i] = spectrum[low + i] + randAmt.rand;
		};
		buf.sine1Msg(spectrum)
	});
)

WrapInstr("osc2.vosc3filt").openFile

// Env isn't working??? stays 0???
KrNumberEditor.defaultLag = 0.1;

WrapInstr("osc2.vosc3filtBufAtk", { |gate = 1, bufmod = 0, numbufs = 2, fsens = 0, bufmAttack = 0.01, bufmDecay = 0.07|
	var	envRange = (numbufs - 1.001) - bufmod,
		envtop = envRange * Sensitivity.kr(1, Latch.kr(gate, gate), fsens);
	WrapInstr.wrap("osc2.vosc3filt", [nil, gate, nil, bufmod, nil, Env([0, envtop, 0.001], [bufmAttack, bufmDecay], -4)])
}, [NoLagControlSpec(0, 1), NoLagControlSpec(0, 6.999), NoLagControlSpec.newFrom(\mybuf.asSpec), NoLagControlSpec.newFrom(\unipolar.asSpec), NoLagControlSpec(0.002, 1, \exp), NoLagControlSpec(0.002, 1, \exp)]);

WrapInstr("osc2.vosc3filtBufAtk").listArgs

WrapInstr("osc2.vosc3fbassBufAtk", { |freq, freqlag, gate, bufbase, numbufs = 2, bufmod, env, vsens, detune, ffreq, rq, msens = 0, bufmAttack = 0.01, bufmDecay = 0.07, lfbuf, t_gate = 1|
	var	maxBufAdd = numbufs - 1.001,
		envRange = maxBufAdd - bufmod,
		envtop = envRange * Sensitivity.kr(1, Latch.kr(t_gate, t_gate), msens);
	var sig, amp, buf;
	amp = Sensitivity.kr(1, Latch.kr(gate, gate), vsens);
		// the bufenv should know how many buffers it's covering
		// but, bufmod might be rising making the range invalid
	buf = bufbase + bufmod
		+ (envtop * EnvGen.kr(Env([0, 1, 0.001], [bufmAttack, bufmDecay], -4), t_gate));
	freq = Lag.kr(freq, freqlag);
	// SinOsc is to reinforce fundamental when higher bufnums deemphasize it
	sig = VOsc3.ar(buf, freq/detune, freq, freq*detune) + Osc.ar(lfbuf, freq);
	RLPF.ar(sig * amp * EnvGen.kr(env, gate, doneAction:2), ffreq, rq)
}, [\freq, nil, \amp, #[0, 1000, \linear, 1, 0], #[0, 1000, \linear, 1, 0], #[0, 20], EnvSpec(Env.adsr), [0, 1], \mydetune, \freq, \myrq, \unipolar, #[0.002, 1, \exp], #[0.002, 1, \exp], \mybuf, TrigSpec()]);

WrapInstr("osc2.vosc3fbassBufAtk").listArgs;

VoicerProxy.new => VP.prNew(0);

~bufs = VC(\sp).env.wt;
~lfbuf = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg((1..5).reciprocal) });
//~bufs = ~wt; // VC(\sp).env.wt;  actually better with wt from VC(\sp)
v.free;

VC(\bs).free;
v = MonoPortaVoicer(1, WrapInstr("osc2.vosc3fbassBufAtk"), [numbufs: `(~bufs.size), vsens: 1, bufbase: `(~bufs.first.bufnum), env: Env.adsr(0.01, 0.2, 0.6, 0.1), lfbuf: ~lfbuf], target: m);
v => VC(\bs);
VC(\bs) => VP(0);

v.mapGlobal(\ffreq, nil, 1200, \freq);	// around 220 is nice and mellow
v.mapGlobal(\bufmod, nil, 0, #[0, 6.998]);

v.portaTime = 0.7;

p = Pbind(
	\type, \voicerNote, \voicer, VC(\bs).v,
	\midinote, Pseq(#[33, 26], inf),
	\dur, Pseq(#[1, 3], inf),
	\legato, Pseq(#[1.1, 0.9], inf),
	\gate, Pseq(#[1, 0.001], inf),
	\vsens, 0,
	\msens, 1,
	\ffreq, 1200,
	\bufmAttack, 0.1,
	\bufmDecay, 0.8,
	\detune, 1.003
).play;

p.stop;

v.trace;

n = v.trigger(55, 1, args: [detune: 1.003, bufmAttack: 0.5, bufmDecay: 1.5 /*, ffreq: 15000 */]);
{ n.trace }.defer(0.1);

n.do(_.release);

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;


(keys: #[master, rvbmc],
make: { |name|
	var	out;
	~target = MixerChannel(name, s, 1, 2, level: -12.dbamp);
	if(VC.exists(\sp).not) {
		"Fact(%) requires buffers from VC('sp') - creating now.\n".postf(~collIndex.asCompileString);
		Fact(\slidePad) => VC(\sp);
	};
	~bufs = VC(\sp).env.wt;
	~lfbuf = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg((1..5).reciprocal) });
	out = MonoPortaVoicer(1, WrapInstr("osc2.vosc3fbassBufAtk"), [numbufs: `(~bufs.size), vsens: 1, bufbase: `(~bufs.first.bufnum), env: Env.adsr(0.01, 0.2, 0.6, 0.5), lfbuf: ~lfbuf, vsens: 0, msens: 1, bufmAttack: 0.1, bufmDecay: 0.8, detune: 1.003], target: ~target);
	out.mapGlobal(\ffreq, nil, 1200, \freq);	// around 220 is nice and mellow
	out.mapGlobal(\bufmod, nil, 0, #[0, 6.998]);
out
},
free: { [~target, ~lfbuf].free },
type: \vc) => Fact(\feetbass);

VC(\bs).free;
Fact(\feetbass) => VC(\bs);
VC(\bs) => MCG(3);
VC(\bs).portaTime = 1.2;

VC(\bs) => BP(\sb);

(
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);
	~bassID = \currentBassNote;

	~rootRange = NumericRange(11, 23);
	~root = Pvbrown(11, 23, Pwhite(1, 3, inf), inf, 14);
	~interval = Pwhite(1, 5, inf);
	~upOrDown = Prand(#[-1, 1], inf);
	~upOrDownFix = Pif(
		Pfunc { |ev|
			~rootRange.inrange(ev[\target] + (ev[\interval] * ev[\upOrDown]))
		},
		Pkey(\upOrDown),
		Pkey(\upOrDown).neg
	);

	~shortDur = Pwhite(2, 3, inf);
	~longDur = Pwhite(16, 30, inf);
	~longHold = Pwhite(0.4, 0.6, inf);
	~gate = Pseq(#[1, 0.001], inf);

	~asPattern = {
		Pbind(
			\bassID, BPStream(\bassID),
			\target, Pstutter(2, BPStream(\root)),
			\interval, Ppatlace([BPStream(\interval), 0], inf),
			\upOrDown, BPStream(\upOrDown),
			\freq, BPStream(\upOrDownFix),
			\freq, Pkey(\target) + (Pkey(\interval) * Pkey(\upOrDown)),
			\dur, Ppatlace([BPStream(\shortDur), BPStream(\longDur)], inf),
			\legato, Ppatlace([1.01, BPStream(\longHold)], inf),
			\length, Pkey(\dur) * Pkey(\legato),
			\gate, BPStream(\gate),
			\mode, \g,
			\midi, false
		)		
	};
} => PR(\slideBass);
)

BP(\sb).free;
PR(\slideBass) => BP(\sb);
VC(\bs) => BP(\sb);
1 => BP(\sb);

BP(\sb).preRest = BP(\sb).preRest.trace(prefix: "rest: ");

Library.at(BP(\sb).bassID)

VC(\sp).globalControls[\bufmod].automate({
	SinOsc.kr(SinOsc.kr(0.012847362, -0.5pi).exprange(0.01, 0.12), -0.5pi).range(0.0, 6.999);
}, target: VC(\sp).env.target.fadergroup, addAction: \addToHead);
VC(\sp).v.globalControls[\bufmod].watch;

VC(\bs).v.globalControls[\bufmod].autoSynth.trace

VC(\sp).v.globalControls[\bufmod].stopAuto.stopWatching;

BP(\sb).shortDur = Pwhite(2, 3, inf).trace(prefix: "short: ");
BP(\sb).shortDur = 3;

BP(\sb).rootRange = NumericRange(11, 23);
BP(\sb).upOrDown = Pfunc { |ev|
	var	dir = #[-1, 1].choose;
	if(~rootRange.inrange(ev[\target] + (ev[\interval] * dir))) { dir } { dir.neg };
};
BP(\sb).root = Pvbrown(11, 23, Pwhite(1, 3, inf), inf, 14);

25.unmapMode(\g)

p = Pbind(
	\type, \voicerNote, \voicer, VC(\bs).v,
	\degree, Pseries(28, -1, 22),
	\octave, 0,
	\root, \g.asMode.root,
	\dur, 1,
	\length, 0.9,
	\gate, 1,
	\vsens, 0,
	\msens, 1
).trace(\degree).play;

p.stop;


// chords for water section
~wt.free;
~wt = \makeWavetables.eval(8, s, 2048, nil, { |nh|
	Array.squareAmps(nh);
});

~wt[0].plotWavetable

Library.at(WrapInstr, \osc2).keys

WrapInstr("osc2.vosc3mapfilt").openFile
WrapInstr("osc2.vosc3map").listArgs

// well crap, why don't I rewrite my whole instr library while I'm at it? Sheesh.
WrapInstr([\osc2, \vosc3map], { |freq, bufbase, numbufs, basefreq, topfreq, gate|
	var	baselog = log2(basefreq),
		freqmap = ((log2(freq) - baselog) / (log2(topfreq) - baselog)
			* (numbufs - 1)).clip(0, numbufs - 1.001);
	WrapInstr.wrap([\osc2, \vosc3], [freq, gate, bufbase, freqmap]);
}, [\freq, [0, 1000, \linear, 1, 0], [0, 20, \lin, 1, 0], \freq, \freq, #[0, 1]]);

WrapInstr("osc2.vosc3mapfiltenv", { |gate = 1, ffreq, rq, fenv, fenv_sens, fenv_vsens, vtimespec|
	var	sig = WrapInstr.wrap("osc2.vosc3map", (nil ! 5) ++ [gate]),
		glatch = Latch.kr(gate, gate),
		feg = EnvGen.kr(fenv, gate, timeScale: vtimespec.map(glatch));
	feg = (feg - 1) * Sensitivity.kr(1, glatch, fenv_vsens) * fenv_sens + 1;
	RLPF.ar(sig, (ffreq * feg).clip(20, 20000), rq)
}, [#[0, 1], \freq, \myrq, EnvSpec(Env.one), #[0, 1], #[0, 1], ObjectSpec(#[1, 1].asSpec)]);

WrapInstr("osc2.vosc3mapfiltenv").listArgs

v.free;
v = Voicer(15, WrapInstr("osc2.vosc3mapfilt"), [bufbase: `(~wt.first.bufnum), numbufs: `(~wt.size), basefreq: `(48.midicps), topfreq: `(127.midicps), env: Env.adsr(1.2, 0.8, 0.6, 1.6)], target: m);

v = WrapInstr("osc2.vosc3mapfiltenv").miditest(initArgs: [bufbase: `(~wt.first.bufnum), numbufs: `(~wt.size), basefreq: `(48.midicps), topfreq: `(127.midicps), env: Env.adsr(1.2, 0.8, 0.6, 1.6), fenv: Env(#[1, 6, 1], #[0.1, 0.9], \sin), vtimespec: #[2, 0.5, exp].asSpec, detune: 1.003, vsens: 0.7, ffreq: 900], target: m);

v.trace;

SynthDescLib.at(v.nodes[0].patch.synthDef.name.asSymbol)

(type: \voicerNote, voicer: v, dur: 2, midinote: #[40, 47, 54, 55, 60, 62, 69], gate: 0.4).play;
(type: \voicerNote, voicer: v, dur: 2, midinote: #[28, 40, 47, 54, 55, 62, 69], gate: 0.8).play;

(type: \voicerNote, voicer: v, dur: 2, midinote: #[36, 48, 54, 55, 62, 69], gate: 0.8).play;


(type: \voicerNote, voicer: v, dur: 2, midinote: #[40, 47, 57, 71], gate: 0.4).play;
(type: \voicerNote, voicer: v, dur: 2, midinote: #[40, 47, 57, 62, 71], gate: 0.4).play;
(type: \voicerNote, voicer: v, dur: 2, midinote: #[40, 47, 57, 62, 78, 71], gate: 0.4).play;
(type: \voicerNote, voicer: v, dur: 2, midinote: #[40, 47, 57, 62, 78, 61, 71], gate: 0.4).play;

(type: \voicerNote, voicer: v, dur: 2, midinote: #[33, 45, 54, 55, 60, 71, 86], gate: 0.4).play;

(type: \voicerNote, voicer: v, dur: 2, midinote: #[31, 43, 52, 57, 62, 71, 78, 88], gate: 0.4).play;

p = Pbind(
	\type, \voicerNote, \voicer, v ?? { VC(\wp).v },
	\dur, 8,
	\sustain, 5.5,
	\n, Pseries(4, 1, inf),
	\midinote, Pseq([
		Pn(Pfin(Pkey(\n).asStream, Pseq(#[40, 47, 57, 62, 61, 71, 78])), 4).clump(Pkey(\n)),
		#[33, 45, 54, 55, 60, 71, 86],
		#[31, 43, 52, 57, 62, 71, 78, 88]
	]),
	\gate, 0.4
).play;

p.stop;

b = Buffer.allocConsecutive(10, s, (44100 * 67.midicps.reciprocal).roundUp);
c = Buffer.alloc(s, 44100, 1);

a = m.playfx { |outbus, clevel = 0.3|
	var	sig = In.ar(outbus, 1),
		extendsig = BufCombN.ar(c, sig, 1, 20),
		n = 10,
//		freqs = { ExpRand(800, 2000).reciprocal } ! n,
		freqs = Array.series(n, 67.midicps, 67.midicps/4).reciprocal,
		pulses = { Dust.kr(2) } ! n,
		decays = Decay2.kr(pulses, 0.1, 0.4),
		combs = BufCombL.ar(b, (sig + extendsig) * decays, freqs, 2);
	(combs.sum * clevel) + sig
};

a.trace;
a.set(\clevel, 0.4);
a.free;

s.sendMsg(\n_free, 2205);

(
(
keys: #[master, rvbmc],
numCombs: 10,
cFundamental: 67.midicps,
cStep: 67.midicps / 4,	// i.e., 67.midicps is 4th partial, next comb will be 5th
make: { |name|
	var out;

//currentEnvironment.debug;

	WrapInstr([\osc2, \vosc3map2], { |freq, bufbase, numbufs, basefreq, topfreq, gate|
		var	baselog = log2(basefreq),
			freqmap = ((log2(freq) - baselog) / (log2(topfreq) - baselog)
				* (numbufs - 1)).clip(0, numbufs - 1.001);
		WrapInstr.wrap([\osc2, \vosc3], [freq, gate, bufbase, freqmap]);
	}, [\freq, [0, 1000, \linear, 1, 0], [0, 20, \lin, 1, 0], \freq, \freq, #[0, 1]]);
	
	WrapInstr("osc2.vosc3mapfiltenv", { |gate = 1, ffreq, rq, fenv, fenv_sens, fenv_vsens, vtimespec|
		var	sig = WrapInstr.wrap("osc2.vosc3map2", (nil ! 5) ++ [gate]),
			glatch = Latch.kr(gate, gate),
			feg = EnvGen.kr(fenv, gate, timeScale: vtimespec.map(glatch));
		feg = (feg - 1) * Sensitivity.kr(1, glatch, fenv_vsens) * fenv_sens + 1;
		RLPF.ar(sig, (ffreq * feg).clip(20, 20000), rq)
	}, [#[0, 1], \freq, \myrq, EnvSpec(Env.one), #[0, 1], #[0, 1], ObjectSpec(#[1, 1].asSpec)]);

	// note, this is a mono -> stereo effect
	~combsdef = SynthDef(("combsfx" ++ name).asSymbol, { |outbus, density = 2, clevel = 0.3,
		attack = 0.1, decay = 0.4, combDecay = 2, bigDelay = 1, bigDecay = 20, gate = 1,
		i_littleDelayB0, i_bigDelayB|
		var	sig = In.ar(outbus, 1),
			extendsig = BufCombN.ar(i_bigDelayB, sig, bigDelay, bigDecay),
			shuf = Dshuf((0 .. ~numCombs - 1), 1),
			initPulse = Impulse.kr(0),
			order = { Demand.kr(initPulse, 0, shuf) } ! ~numCombs,
			freqs = Select.kr(order, Array.series(~numCombs, ~cFundamental, ~cStep).reciprocal),
			pulses = { Dust.kr(density) } ! ~numCombs,
			decays = Decay2.kr(pulses, attack, decay),
			combs = BufCombL.ar(i_littleDelayB0 + (0 .. ~numCombs - 1),
				(sig + extendsig) * decays, freqs, combDecay),
			weteg = EnvGen.kr(Env.asr(0.1, 1, 0.5), gate, doneAction: 2);
		combs = Splay.ar(combs, levelComp: false);
		ReplaceOut.ar(outbus, Limiter.ar(combs * clevel * weteg) + sig)
	}).add;
	SynthDef('1to2', { |outbus| ReplaceOut.ar(outbus, In.ar(outbus, 1) ! 2) }).add;

	~target = MixerChannel(name, s, 2, 2, level: -27.dbamp, outbus: ~master, completionFunc: { |chan|
		~mono2Stereo = chan.playfx('1to2');
	});
	~wt = \makeWavetables.eval(8, s, 2048, nil, { |nh| Array.squareAmps(nh) });
	~bigdelay = Buffer.alloc(s, 44100, 1);
	~littledelays = Buffer.allocConsecutive(~numCombs, s, (s.sampleRate / ~cFundamental).roundUp);
	out = Voicer(16, WrapInstr("osc2.vosc3mapfiltenv"), [bufbase: `(~wt.first.bufnum), numbufs: `(~wt.size), basefreq: `(48.midicps), topfreq: `(127.midicps), env: Env.adsr(1.2, 0.8, 0.6, 1.6), fenv: Env(#[1, 6, 1], #[0.1, 0.9], \sin), vtimespec: #[2, 0.5, exp].asSpec, detune: 1.003, vsens: 0.7/*, ffreq: 900, fenv_sens: 0.8, fenv_vsens: 0.6*/], target: ~target);
	out.mapGlobal(\ffreq, nil, 900, \freq);
//	out.mapGlobal(\rq, nil, 1, \myrq);
	out.mapGlobal(\fenv_sens, nil, 0.8);
	out.mapGlobal(\fenv_vsens, nil, 0.6);
	out.mapGlobal(\clevel, nil, 0.6, \amp);
	out
},
free: { [~target, ~wt, ~bigdelay, ~littledelays].free },
playfx: { |self| self.use {
	~fx ?? {
		~fx = ~target.playfx(~combsdef.name, [
			clevel: ~value.globalControls[\clevel],  // automagically asMap's
			i_littleDelayB0: ~littledelays.first, i_bigDelayB: ~bigdelay
		])
	};
} },
stopfx: { |self| self.use {
	~fx !? { ~fx.release; ~fx = nil }
} },
type: \vc) => Fact(\waterpad);
)

VC(\wp).free;
Fact(\waterpad) => VC(\wp);

k = VoicerMIDISocket(0, VC(\wp).v);

VC(\wp).env.playfx;
VC(\wp).env.stopfx;
VC(\wp).env.fx.trace;

MIDIRecBuf(\waterch, [
	#[40, 47, 57, 62, 78, 61, 71,
		33, 45, 54, 55, 60, 71, 86,
		31, 43, 52, 57, 62, 71, 78, 88],
	#[7, 7, 8].collect { |n| (1 ! (n-1)) ++ #[2] }.flat,
	1, 0.5
].asNotes, (type: \ch, mode: \g)) => MBM(0);

();
PR(\arpeg1).clone {
	~superAsPattern = ~asPattern;
	~asPattern = { |inEvent|
		~preInsertStream !? {
			inEvent = ~preInsertStream.next(inEvent);
		};
		~superAsPattern.(inEvent);
	};
} => PR(\arpeg1PreInsert);

BP(\wch).free;
\newCh.eval(\wch, \arpeg1PreInsert, \macroRh, MBM(0)[\waterch], nil, 12, \blockFollow, \block, nil, \g);
BP(\wch).child.preInsert = Pbind(\numNotes, Pseries(4, 1, inf));

{ |notes, inEvent| 
	if(notes.isArray) {
		Pn(notes.keep(min(notes.size, inEvent[\numNotes])), 1)
	} {
		Pn(notes.asArray.asNotes.keep(min(notes.size, inEvent[\numNotes])), 1)
	}
} => ArpegPat(\blockNum);

~gStream = Pn(Pseries(0.1, 0.1, 10)).asStream;
BP(\wch).child.gatePat = Pn(Pseries(0.1, 0.1, 10));
//{ |notes, parentEv| [parentEv[\delta], parentEv[\delta] - 4, rrand(0.1, 0.5).debug("gate")] } => MicRh(\waterch);
{ |notes, parentEv| [parentEv[\delta], parentEv[\delta] - 4, ~gatePatStream.next] } => MicRh(\waterch);

\blockNum =>.arpeg BP(\wch);
\waterch =>.micro BP(\wch);

BP(\wch).child[\reset].postcs
BP(\wch).child.makeChordPattern = { Pstutter(Pseq([4, Pn(1, inf)]), Pseq(~chords, inf)) };
BP(\wch).child.preInsertStream.reset;

VC(\wp).env.playfx;
VC(\wp).env.stopfx;

SynthDef(\wpffreq, { |outbus|
	var	ff = SinOsc.kr(
			SinOsc.kr(0.003).exprange(0.01, 0.06),
			-0.5pi
		).exprange(300, 9000);
	ReplaceOut.kr(outbus, ff);
}).add;

VC(\wp).globalControls[\ffreq].automate(\wpffreq);
VC(\wp).globalControls[\ffreq].watch
VC(\wp).globalControls[\ffreq].stopAuto.stopWatching;

(
t = TLSequenceIterator([
	bpCmd: (name: \wch, prepareBP: { |bp|
		bp.child.preInsert = Pbind(
			\numNotes, Pseq([
				Pwhile1({ |ev, next| next <= 7 },
					Pseries(Pseq([4, Pwhite(4, 7, inf)]).asStream, 1, inf)),
				Pn(8, 2)
			], inf).trace(prefix: "numNotes: ")
		);
//		bp.child.makeChordPattern = { Pstutter(Pseq([4, Pn(1, inf)]), Pseq(~chords, inf)) };
		bp.child.makeChordPattern = { Pclutch(Pseq(~chords, inf).trace(prefix: "got chord: "), Pdelay(Pkey(\numNotes) >= 7)) };
	}),
	gcAutoSynthCmd: (gc: VC(\wp).globalControls[\clevel], name: \ctlEnv, outName: \outbus,
		time: 40, connect: 0, env: Env(#[0.07, 1], #[1], \exp)
	),
	gcAutoSynthCmd: (gc: VC(\wp).globalControls[\ffreq], name: \wpffreq, outName: \outbus)
]).play;
)

t.stop

Array.series(10, 67.midicps, 67.midicps/4).cpsmidi

z = StaticEQ.new(1, \eq, 589.41, -6.457.dbamp, 1, \hishelf, 6947.785, 2.047.dbamp, 1).play(VC(\wp).env.target, addAction: \addToHead);

// test procs in defs
VC(\wp).free;
Fact(\waterpad).chuck(VC(\wp), nil, (numCombs: 10));
Fact(\waterch) => BP(\wch);
0 => BP(\wch);
BP(\wch) => VC(\wp);
BP(\wch) => VP(0);

BP(\wch).macro = 18;
BP(\wch).child[\reset].inspect
BP(\wch).child.preInsert

BP(\wch).reset
BP(\wch).child.reset

BP(\wch).value.reset

BP(\wch).child.gatePat = Pn(Pseries(0.1, 0.1, { rrand(6, 10) }));

s.queryAllNodes
VC(\wp).env.fx.set(\density, 0.8)

MultiEQ(2).edit(VC(\wp).env.target)

BP(\wch).child.argPairs = [fenv_vsens: 1, vsens: 0.2, fenv_tscale: Pexprand(0.8, 1.8, inf).trace(prefix: "tscale: ")];

~ch = VC(\wp).env.target.playfx(Instr("busfx.chorus2"), [0, 1, 2, 3]); ~ch.gui;

~ch.run(false);
~ch.run(true);

(-25.5.dbamp / -27.dbamp)

u.remove;
u = Updater(VC(\wp).env.target.controls[\level], { |obj, parms|
	if(parms[\what] == \value) { VC(\wp).env.combsMC.level = obj.value * 1.1885 }
});

// this does NOT work -- need separate mixerauto commands
a = VC(\wp).env.target.levelAuto(\ctlEnv, [env: Env(#[-27, -15, -27].dbamp, #[5, 5])]).postln;
VC(\wp).env.target.watch(\level);

VC(\wp).env.target.stopWatching;



// improving waterpad sound
// assumes feet-defs loaded

v = VC(\waterpad).v;
v.trace;

k = VoicerMIDISocket(0, VP(0).v);

k.noteOnArgsPat = Pbind(
	\fenv_sens, 0.8,
	\fenv_vsens, 0,
	\fenv_tscale, Pkey(\velocity).linexp(0, 127, 15.0, 2.0),
	\advance, Pdiff(Ptime()) >= 1.2,
//	\ffreq, Pclutch(Pexprand(80, 600, inf).trace(prefix: "ffreq: "), Pkey(\advance)),
	\pan, Pseq(#[-1, 1], inf),
	\bufbase, Pclutch(Prand(VC(\waterpad).env.wt.collect(_.first), inf).trace(prefix: "ffreq: "), Pkey(\advance))
);

// decouple ffreq?
v.unmapGlobal(\ffreq);
v.unmapGlobal(\rq);

PeakMonitor(VC(\waterpad).env.target);
PeakMonitor(~master);
VC(\waterpad).env.ch.synth.trace;

z = VC(\waterpad).env.target.newPostSend(~glrvbmc, -10.dbamp);
g = GenericGlobalControl(\l, nil, z.level, \amp); g.gui;
u.remove;
u = Updater(g, { |obj, what|
	if(what.isKindOf(Dictionary) and: { what[\what] == \value }) {
		z.level = obj.value
	}
});

g.releaseDependants; g.free;

z.level