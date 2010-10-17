// sounds for torso

MIDIPort.init([3]);  // linux

MIDIPort.init([2]);  // mac+ultralite
MIDIPort.autoFreeSockets = false;

s.options.preferredDeviceFunc_(nil).device_("Aggregate Device");

BP.loadGui;

MT(1).gui;

ChuckableBrowser.newWindow;
\makeEmptyMixer8.eval;

(Document.current.path.dirname.dirname +/+ "common/common-defs.scd").loadPath;

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
// ~cRvbMc => MCG(4);

PeakMonitor(m);
PeakMonitor(n);
PeakMonitor(~master);
PeakMonitor(~glrvbmc);


[~glrvb, ~lcrvb].do(_.run(false)); [~glrvbmc, ~lcrvbmc].do(_.mute(true));
[~glrvb, ~lcrvb].do(_.run(true)); [~glrvbmc, ~lcrvbmc].do(_.mute(false));

~cavernousRvb.run(false); ~cRvbMc.mute(true);
~cavernousRvb.run(true); ~cRvbMc.mute(false);

VoicerProxy.new => VP.prNew(0);
4.do { VP(0).v.addControlProxy(VoicerGCProxy(nil, VP(0).v), addAlways: true) };
VP(0).v.gui;



///// suspension

(Document.current.path.dirname.dirname +/+ "torso/torso-defs.scd").loadPath;

// nope
\makeTmelVC.eval(\tmel);

k.free;
k = VoicerMIDISocket(0, VC(\tmel).v);

k.transpose = -1;


Fact(\armsmelVC).chuck(VC(\sus), nil, (isMono: false));

k.free;
k = VoicerMIDISocket(0, VC(\sus).v);

k.transpose = -1;


SynthDef(\finalRotate, { |outbus,
	radiusSpeed = 0.2, radiusLo = 0.5, radiusHi = 1.0,
	angleSpeedLo = 0.1, angleSpeedHi = 0.6, angleSpeedChRate = 0.7,
	distNear = 5, distFar = 20|
	var	radius = LFDNoise1.kr(radiusSpeed).range(radiusLo, radiusHi),
		angle = Integrator.kr(
			LFDNoise1.kr(angleSpeedChRate).range(angleSpeedLo, angleSpeedHi) * ControlDur.ir
		);
	Out.kr(outbus, [
		cos(angle) * radius,
		(sin(angle) * radius).linlin(-1.0, 1.0, distNear, distFar)
	]);
}).add;


p = Pbind(
	\instrument, \susDef,
	\chan, VC(\sus).env.target,
	\freq, Pseq(#[83, 92, 97], 1).midicps,
	\delta, 3,
	\sustain, 20 - Pseries(0, Pkey(\delta), inf),
	\gate, 0.1,
	\distNear, 50,
	\distFar, 180,
	\ampMul, 0.3,
	\pan, { ~lock.bus.asMap },
	\distance, { ("c" ++ (~lock.bus.index + 1)).asSymbol },
	\lpcEv, Pbind(
		\instrument, \finalRotate,
		\radiusLo, 0.75,
		\radiusSpeed, Pwhite(0.4, 1.4, inf),
		\angleSpeedLo, Prand(#[7.0, -7.0], inf),
		\angleSpeedHi, 14.0 * Pkey(\angleSpeedLo).sign,
		\angleSpeedChRate, Pwhite(0.8, 1.6, inf)
	)
);


q = p.play(protoEvent: ProtoEvent(\polySynthKrBusLock).copy.proto_(topEnvironment[\rvbEvent].proto));
q.stop;


e = p.asStream.next(ProtoEvent(\polySynthKrBusLock).copy.proto_(topEnvironment[\rvbEvent].proto));
e.sustain = 2;
e.play;

e.lock.listVars;
e.node.do(_.trace);
e.lpcEv.node.trace;


SynthDescLib.at(\finalRotate).controls.do(_.postln); ""

(
PR(\abstractProcess).clone {
	~event = (eventKey: \polySynthKrBusLock);
	~repeats = inf;
	~requiredKeys = #[vcKey];
	~resetSources = true;

	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;
		~ampCtl = GenericGlobalControl(\amp, nil, 0.3, \amp);
	};
	~freeCleanup = { ~ampCtl.free };
	~useGui = { |vp| ~ampCtl => VP(vp) };

	~phraseDur = Pwhite(7.0, 10.0, inf);
	~delta = Pexprand(0.07, 0.6, inf);
	~sustain = Pkey(\phraseDur) - Pseries(0, Pkey(\delta), inf);
	~gate = 0.1;
	~distNear = 50;
	~distFar = 180;
	~ampMul = Plazy({ Pn(~ampCtl.asMap, inf) });
	~mode = \e0;
	~degree = Pseries({ rrand(39, 44) }, Pwrand(#[1, 2, 3], #[0.15, 0.5, 0.35], inf), { rrand(3, 5) });

	~radiusLo = 0.75;
	~radiusSpeed = Pwhite(0.4, 1.4, inf);
	~angleSpeedLo = Prand(#[7.0, -7.0], inf);
	~angleSpeedHi = 14.0 * Pkey(\angleSpeedLo).sign;
	~angleSpeedChRate = Pwhite(0.8, 1.6, inf);
	~lpcEv = Plazy({
		Pbind(
			\instrument, \finalRotate,
			\radiusLo, BPStream(\radiusLo),
			\radiusSpeed, BPStream(\radiusSpeed),
			\angleSpeedLo, BPStream(\angleSpeedLo),
			\angleSpeedHi, BPStream(\angleSpeedHi),
			\angleSpeedChRate, BPStream(\angleSpeedChRate)
		);
	});

	~phrasePat = {
		Pbind(
			\mode, BPStream(\mode, ~resetSources/*, envir: currentEnvironment*/),
			\degree, BPStream(\degree, ~resetSources/*, envir: currentEnvironment*/),
			\freq, Pfunc({ |ev| ev[\mode].asMode.cps(ev[\degree]) }),
			\delta, BPStream(\delta, ~resetSources/*, envir: currentEnvironment*/),
			\sustain, BPStream(\sustain, ~resetSources/*, envir: currentEnvironment*/),
			\gate, BPStream(\gate, ~resetSources/*, envir: currentEnvironment*/),
			\distNear, BPStream(\distNear, ~resetSources/*, envir: currentEnvironment*/),
			\distFar, BPStream(\distFar, ~resetSources/*, envir: currentEnvironment*/),
			\ampMul, BPStream(\ampMul, ~resetSources/*, envir: currentEnvironment*/),
			\lpcEv, BPStream(\lpcEv, ~resetSources/*, envir: currentEnvironment*/),
			\pan, { ~lock.bus.asMap },
			\distance, { ("c" ++ (~lock.bus.index + 1)).asSymbol }
		);
	};
	~asPattern = {
		var	phraseDurPat = Pbind(
			\phraseDur, BPStream(\phraseDur),
			\phraseStartTime, Pfunc({ thisThread.clock.beats })
		);
		PR(\psetp2).copy.prep(
			if(~repeats == inf) {
				PnNilSafe(phraseDurPat, ~repeats)
			} {
				Pfin(~repeats, phraseDurPat)
			},
			Pseq([
				~phrasePat.(),
				Pbind(
					\instrument, \rest,
					\delta, Pfuncn({ |ev| ev[\phraseDur] + ev[\phraseStartTime] - thisThread.clock.beats })
				)
			], 1),
			currentEnvironment  // environment in which 2 patterns will run
		).outerOverridesInner_(false).asPattern
	};

	~bindVoicer = { |vc|
		~vcKey = VC.keys.detect { |key| VC(key).value === vc };
		~event.putAll((
			chan: VC(~vcKey).env.target,
			instrument: VC(~vcKey).v.nodes[0].defname
		));
	};
} => PR(\finalSus);
)

BP(\fs).free;
PR(\finalSus) => BP(\fs);
VC(\sus) => BP(\fs);
BP(\fs) => MT(1);
0 => BP(\fs);

BP(\fs).repeats = 2;

p = BP(\fs);

p.use {
	~delta = Pexprand(0.07, 0.6, inf).trace(prefix: "\ndelta: ");
	~sustain = (Pkey(\phraseDur).trace(prefix: "total dur: ") - Pseries(0, Pkey(\delta), inf)).trace(prefix: "note dur: ");
};

#[83, 92, 97].mapMode(\e0);

p.repeats = 1;
p.phraseDur = 24;
p.degree = Pseq(#[48, 53, 56], 1);
p.delta = Pexprand(3.0, 6.0, inf);

p.phraseDur = 18;
p.degree = Pseq(#[35, 36, 38, 38.5, 41, 47.5], 1);
p.delta = Pexprand(3.0, 6.0, inf) * 0.35;

p.degree = Pseq(#[40, 43, 45, 46, 49, 52.5], 1);

#[35, 36, 38, 38.5, 41, 47.5].unmapMode(\e0)


///// quick cuts

// arms axial
\addRvbOut.eval(\bellskid, { |noisebuf, nfreq = 440, beats = 4.64,
	chDepth = 0.05, chSpeed = 1.2, chPre = 0.06,
	loffreq = 440, hiffreq = 440, rdecay = 0.01,
	loTime = 0.12, hiTime = 0.22, timeMul = 1,
	amp = 1, pan, sustain = 1|
	var	sig,
		ddelta = Dstutter(2, Dwhite(0.0, 1.0, inf).linexp(0, 1, loTime, hiTime)),
		trig = TDuty.kr(ddelta, 0, ddelta),
		time = Latch.kr(trig, trig) * timeMul;
	sig = WrapInstr("arms.airskid").valueArray([
		noisebuf, nfreq, beats, trig, chDepth, chSpeed, chPre,
		{ |trig, decay|
			var	proportion = TRand.kr(0.02, 0.9, trig); //,
			Env([loffreq, hiffreq, loffreq],
				[proportion, 1 - proportion] * decay, \exp)
		}, rdecay, time, { |sig, rfreq, rdecay|
			Klank.ar(`[
				(1..6) + ({ Rand(-0.2, 0.2) } ! 6),
				1 ! 6,
				{ Rand(0.75, 1.25) } ! 6
			], sig, rfreq, 0, rdecay)
		}, amp,
		{ |trig, decay|
			var	proportion = TRand.kr(0.02, 0.9, trig);
			Env([0, 1, 0], [proportion, 1 - proportion] * decay, #[3, -3])
		},
		/*numOverlaps:*/ 3
	]);
	sig = sig * EnvGen.kr(Env.linen(0.1, sustain, 0.1, curve: -2), doneAction: 2);
	Pan2.ar(sig, pan);
}).add;

BP(\bskid).free;
PR(\armsSkidMel).chuck(BP(\bskid), nil, (def: \bellskid).putAll(Library.at(\rvbs)));

BP(\bskid).chan.postSettings

BP(\bskid).prepareForPlay;
2.do { BP(\bskid).triggerOneEvent(0) };

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;

o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| s.sendMsg(\n_trace, m[1]) }).add;


// arms locomotive
Fact(\armsChordVC).chuck(VC(\ac), nil, Library.at(\rvbs));

VC(\ac).globalControls

