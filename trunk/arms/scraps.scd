		SynthDef(\snapback, { |inpos = 0, threshold = 0.5, center = 0,
				startFreq = 18, endFreq = 2, decayTime = 1,
				threshScale = 1, inLag = 0.1,
				outbus|
			var	initTrig = Impulse.kr(0),
				localIn = LocalIn.kr(2),
				state = Select.kr(initTrig, [localIn[0], 0]),
				oldWobble = Select.kr(initTrig, [localIn[1], 0]),
				inCtr0 = Lag.kr(inpos, inLag) - center,
				inDly1 = Delay1.kr(inCtr0),
				inScaled = inCtr0 * threshScale,
				thresh4clip = abs(threshold * threshScale),
				trig0to1 = BinaryOpUGen('==', state, 0) *
					// that is, if 0 is between previous and current values of inCtr0...
					InRange.kr(oldWobble, min(inDly1, inCtr0), max(inDly1, inCtr0)),
				isState1 = BinaryOpUGen('==', state, 1),
				trig1to0 = isState1 * (inCtr0.abs > threshold),
				freq = EnvGen.kr(Env([startFreq, startFreq, endFreq], [0.01, decayTime], \exp), trig1to0),
				pulse4filter = (trig1to0 * (inScaled - oldWobble)),
				wobble = Ringz.kr(pulse4filter, freq, decayTime)/*.clip(thresh4clip.neg, thresh4clip)*/,
				sig = Select.kr(state, [wobble, inScaled/*, wobble*/]);
state.poll(HPZ1.kr(state).abs, "state");
inCtr0.poll(trig0to1 + trig1to0, "inCtr0");
			LocalOut.kr([
					// float wrapping!!
				(state + (trig0to1 + trig1to0 /* + trig2to0 */ > 0)).wrap(0, 2),
				wobble
			]);
//SendReply.kr(trig0to1 + trig1to0, '/traceme', 0, 1);
pulse4filter.poll(pulse4filter.abs > 0, "pulse4filter");
SendReply.kr(pulse4filter.abs > 2, '/traceme', 0, 1);
			ReplaceOut.kr(outbus, sig);
		}).perform(Library.at(\ddwGlobal, \storeMethod));


/*
		SynthDef(\snapback, { |inpos = 0, threshold = 0.5, center = 0,
				startFreq = 18, endFreq = 2, decayTime = 1,
				threshScale = 1,
				outbus|
			var	initTrig = Impulse.kr(0),
				state = Select.kr(initTrig, [LocalIn.kr(1), 0]),
				inCtr0 = inpos - center,
				inDly1 = Delay1.kr(inCtr0),
				inScaled = inCtr0 * threshScale,
				trig0to1 = BinaryOpUGen('==', state, 0)
					// that is, if 0 is between previous and current values of inCtr0...
					* InRange.kr(0, min(inDly1, inCtr0), max(inDly1, inCtr0)),
				isState1 = BinaryOpUGen('==', state, 1),
				trig1to2 = isState1 * (inCtr0.abs > threshold),
				freq = EnvGen.kr(Env([startFreq, startFreq, endFreq], [0.01, decayTime], \exp), trig1to2),
				trig2to0 = BinaryOpUGen('==', state, 2) * Done.kr(freq),
				pulse4filter = trig1to2 * inScaled,
				wobble = Ringz.kr(pulse4filter, freq, decayTime),
				sig = Select.kr(state, [wobble, inScaled, wobble]);
			// float wrapping!!
//state.poll(HPZ1.kr(state).abs, "state");
			LocalOut.kr((state + (trig0to1 + trig1to2 + trig2to0 > 0)).wrap(0, 3));
			ReplaceOut.kr(outbus, sig);
		}).perform(Library.at(\ddwGlobal, \storeMethod));
*/



if(v.active) { v.free };
v = Voicer(20, WrapInstr("osc2.fm2car_pan_lfo"), [car_buf: ~cb, mod_buf: ~mb, \mod_lev, 4.7777362156971, \mod_ratio, `1, \detune, 0, \car_detune, `0.99798261661993, \car_vs, 0.66141732283465, \mod_vs, `0, \basefreq, `440, \keyscale, `0.28621534453893, car_env: Env.adsr(0.5, 0.8, 0.75, 1.0)], target: n);

WrapInstr("osc2.fm2car_bass_tlfo").listArgs

if(VP.exists(0).not) { VoicerProxy.new => VP.prNew(0) };
v => VP(0);
VP(0).v.gui;

SynthDescLib.at(v.nodes[0].defname.asSymbol).controlNames;

();

k = VoicerMIDISocket(0, v);
k.addControl(nil, \car_vs, 0);
VoicerSusPedal(0, 64, v);

k.noteOnArgsPat = Pbind(
	\detuneLfoSpeed, Pexprand(0.3, 1.7, inf),
	\detuneLfoAmp, Pkey(\midinote).linexp(28, 96, 0.2, 4, clip: \none),
	\modLfoSpeed, Pkey(\velocity).linlin(0, 127, 1.4, 6.0),
	\modLfoAmp, Pkey(\velocity).linlin(0, 127, 0, 1),
	\modLfoDecay, Pkey(\velocity).linlin(0, 127, 1, 8),
	\modLfoRange, Pkey(\midinote).linexp(36, 84, 1.6, 4),
//	\envTimeScale, Pkey(\velocity).linexp(0, 127, 10.0, 0.1),
	\mod_lev, Pkey(\velocity).linlin(0, 127, 1.2, 3.4),
	\attackTimeScale, Pkey(\velocity).linexp(0, 127, 10.0, 0.1),
	\decayTimeScale, Pkey(\velocity).linexp(0, 127, 10.0, 3.5)
);

63.5.linexp(0, 127, 10.0, 0.1)

v.trace;

k.ccs.reverseDo(_.free);
k.free;
v.free;
k.inspect


k.noteOnArgsPat = Pbind(
	\detuneLfoSpeed, Pexprand(0.3, 1.7, inf),
	\detuneLfoAmp, Pkey(\midinote).linexp(28, 96, 0.2, 4, clip: \none),
	\rhythm, Pclump(Pwhite(8, 20), Pwrand(#[0.25, 0.5, 0.75], #[0.4, 0.35, 0.25], inf))
		.collect([_]).trace,
//	\rhythm, [ [#[1.0, 0.25, 0.25] - 0.05, 0.05].flop.flat ],
	\numRhythmSlots, Pfunc { |ev| ev[\rhythm][0].size },
//	\rhythmRepeats, inf,
	\modUpRange, Pkey(\midinote).linexp(36, 84, 1.6, 4),
//	\envTimeScale, Pkey(\velocity).linexp(0, 127, 10.0, 0.1),
	\mod_lev, Pkey(\velocity).linlin(0, 127, 1.2, 3.4),
	\attackTimeScale, Pkey(\velocity).linexp(0, 127, 10.0, 0.1),
	\decayTimeScale, Pkey(\velocity).linexp(0, 127, 10.0, 3.5)
);


// make 1 rhythm synth
~rhy = Bus.control(s, 1);
~rh = Synth(\repeatingRhythmBus, [out: ~rhy, numRhythmSlots: 20, rhythm: Pwrand(#[0.25, 0.5, 0.75], #[0.4, 0.35, 0.25], inf).asStream.nextN(20)]);

[~rh, ~rhy].free;

SynthDescLib.at(\repeatingRhythmBus)


(
~rhySynths = { |i|
	var	return, n = (i+1) * 4;
	s.makeBundle(0.2, {
		return = Synth(\repeatingRhythmBus, [out: ~rhybus.index + i, numRhythmSlots: n,
			rhythm: [rrand(2, 6)] ++ Pwrand(#[0.25, 0.5, 0.75], #[0.4, 0.35, 0.25], inf)
				.asStream.nextN(n-1)]);
	});
	return
} ! ~rhybus.numChannels;
)



p.midinote = /*\patRejectLastN.eval(*/Plazy { |ev|
	var	arpeg = (~arpegStream ?? { ~makeStreamForKey.(\arpeg); ~arpegStream }).next(ev),
		debugpats;
	Pnsym1(Pkey(\row).collect(_.asSymbol), debugpats = ev[\chordItem][\hierarchyDict].collect { |row|
		ArpegPat(arpeg).asPattern(row)
	}.postcs).collect { |n| if(Mode(\g).cps(n) < 30) {
		[n, ev[\row].asCompileString, ev[\row].asSymbol.asCompileString, debugpats[ev[\row].asSymbol]].debug("oh shit");
		debugpats.keysDo { |k| [k, ev[\row].asSymbol, k === ev[\row].asSymbol, k.asSymbol, ev[\row].asSymbol, k.asSymbol === ev[\row].asSymbol].asCompileString.debug("test") };
	}; n }
}/*, 2)*/;


