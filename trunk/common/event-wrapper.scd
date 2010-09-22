// event wrapper to send data to Lorne

ChuckableBrowser.newWindow;
PeakMonitor(0);

// default event prototype
e = Event.default;

e[\play].postcs

Event.addEventType(\dataWrap, {
	~type = ~evType;
	~play.value;  // do real action
	\eventDataToViz.eval;
});

p = Pbind(
	\type, \dataWrap,
	\evType, \note,
	\degree, Pwhite(-7, 7, 8),
	\dur, 0.25
).play;

// good, flow of control works
{ [~degree, ~freq].debug } => Func(\eventDataToViz);

{
	var	parms;
	if(~dataToViz ? true) {
		if(~vizKeys.notNil) {
			if(~vizKeys.isKindOf(Dictionary)) {
				parms = Array(~vizKeys.size * 2);
				~vizKeys.keysValuesDo { |key, val|
					parms.add(key);
					if(val.isSymbol) { parms.add(val.envirGet) }
					{ parms.add(val.value(key)) }
				};
			} {
				// asArray b/c envirPairs is stupidly defined only for Array
				parms = ~vizKeys.asArray.envirPairs;
			};
		} {
			parms = ~args ?? { ~getMsgFunc.valueEnvir.valueEnvir };
		};
	};
	if(parms.includes(\latency).not) {
		parms = parms.add(\latency).add(~latency ? (~server ?? { Server.default }).latency);
	};
	(~vizAddr ?? { Library.at(\vizAddr) }).sendMsg();
} => Func(\eventDataToViz);



// changed single/poly synth players - regression test

p = Pbind(
	\instrument, \default,
	\degree, Pwhite(-7, 7, 8),
	\freq, (Pkey(\degree).degreeToKey(#[0, 2, 4, 5, 7, 9, 11]) + 60).midicps,
	\delta, 0.25,
	\sustain, 0.2,
	\pan, Pwhite(-1.0, 1.0, inf),
	\amp, 0.1
).play(protoEvent: ProtoEvent(\singleSynthPlayer).copy);

p = Pbind(
	\instrument, \default,
	\degree, Pxrand((-7 .. 7), 16).clump(2),
	\freq, (Pkey(\degree).degreeToKey(#[0, 2, 4, 5, 7, 9, 11]) + 60).midicps,
	\delta, 0.25,
	\sustain, 0.2,
	\pan, Pwhite(-1.0, 1.0, inf),
	\amp, 0.1,
	\debug, true
)
.collect { |ev| defer { ev.args.debug("\nargs"); ev.msgArgs.debug("msgArgs") }; ev }
.play(protoEvent: ProtoEvent(\polySynthPlayer).copy);

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;

SynthDef(\dTrig, { arg out=0, freq=440, amp=0.1, pan=0, t_trig=1;
	var z;
	z = LPF.ar(
		Mix.new(VarSaw.ar(freq + [0, Rand(-0.4,0.0), Rand(0.0,0.4)], 0, 0.3)),
		XLine.kr(Rand(4000,5000), Rand(2500,3200), 1)
	) * EnvGen.kr(Env.perc(0.01, 0.1), t_trig);
	OffsetOut.ar(out, Pan2.ar(z, pan, amp));
}).add;

n = Synth(\dTrig);

p = Pbind(
	\instrument, \default,
	\degree, Pwhite(-7, 7, 8),
	\freq, (Pkey(\degree).degreeToKey(#[0, 2, 4, 5, 7, 9, 11]) + 60).midicps,
	\delta, 0.25,
	\pan, Pwhite(-1.0, 1.0, inf),
	\amp, 0.1,
	\node, n,
	\trig, 1
).play(protoEvent: ProtoEvent(\singleSynthTrigger).copy);

n.free;

n = { Synth(\dTrig) } ! 2;

p = Pbind(
	\degree, Pxrand((-7 .. 7), 16).clump(2),
	\freq, (Pkey(\degree).degreeToKey(#[0, 2, 4, 5, 7, 9, 11]) + 60).midicps,
	\delta, 0.25,
	\pan, Pwhite(-1.0, 1.0, inf),
	\amp, 0.1,
	\node, n,
	\trig, 1
)
.collect { |ev| defer { ev.args.debug("\nargs"); ev.msgArgs.debug("msgArgs") }; ev }
.play(protoEvent: ProtoEvent(\polySynthTrigger).copy);

n.free;
