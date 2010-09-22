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

{	var	parms;
	if(~dataToViz ? true) {
		if(~vizKeys.notNil) {
			if(~vizKeys.isKindOf(Dictionary)) {
				parms = Array(~vizKeys.size * 2);
				~vizKeys.keysValuesDo { |key, val|
					parms.add(key);
					if(val.isSymbol) { parms.add(val.envirGet) }
					{ parms.add(val.value(key.envirGet, key)) }
				};
			} {
				// asArray b/c envirPairs is stupidly defined only for Array
				parms = ~vizKeys.asArray.envirPairs;
			};
		} {
			parms = ~evArgs ?? { ~getMsgFunc.valueEnvir.valueEnvir };
		};
	};
	if(parms.includes(\latency).not) {
		parms = parms.add(\latency).add(~latency ? (~server ?? { Server.default }).latency);
	};
	(~vizAddr ?? { Library.at(\vizAddr) }).sendBundle(nil,
		((~vizPath.collect(_.valueEnvir) ? #[note]).asArray ++ parms).asOSCArgArray);
	// ((~vizPath.collect(_.valueEnvir) ? #[note]).asArray ++ parms).asOSCArgArray.postln;
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


// wrapper for custom events
{	|key, newKey|
	var	protoEv;
	if(ProtoEvent.exists(key)) {
		protoEv = ProtoEvent(key);
		if(protoEv[\originalPlayFunction].isNil) {
			protoEv = protoEv.copy;
			protoEv[\originalPlayFunction] = protoEv[\play];
			protoEv[\play] = { |server|
				~originalPlayFunction.(server);
				\eventDataToViz.eval;
			};
			newKey ?? { newKey = (key ++ "Data").asSymbol };
			protoEv => ProtoEvent(newKey);
		} {
			"ProtoEvent(%) is already wrapped - don't rewrap.".format(key.asCompileString).warn;
			nil
		}
	} {
		"ProtoEvent(%) doesn't exist, can't wrap.".format(key.asCompileString).warn;
		nil
	};
} => Func(\dataWrapProtoEvent);

\dataWrapProtoEvent.eval(\singleSynthPlayer);

// use ~evArgs (default)
p = Pbind(
	\instrument, \default,
	\degree, Pwhite(-7, 7, 8),
	\freq, (Pkey(\degree).degreeToKey(#[0, 2, 4, 5, 7, 9, 11]) + 60).midicps,
	\delta, 0.25,
	\sustain, 0.2,
	\pan, Pwhite(-1.0, 1.0, inf),
	\amp, 0.1
).play(protoEvent: ProtoEvent(\singleSynthPlayerData).copy);

// use ~vizKeys array
p = Pbind(
	\instrument, \default,
	\degree, Pwhite(-7, 7, 8),
	\freq, (Pkey(\degree).degreeToKey(#[0, 2, 4, 5, 7, 9, 11]) + 60).midicps,
	\delta, 0.25,
	\sustain, 0.2,
	\pan, Pwhite(-1.0, 1.0, inf),
	\amp, 0.1,
	\vizKeys, #[degree, pan]
).play(protoEvent: ProtoEvent(\singleSynthPlayerData).copy);

// use ~vizKeys dict

Library.put(\vizAddr, NetAddr("127.0.0.1", NetAddr.langPort));

NetAddr("127.0.0.1", NetAddr.langPort).sendMsg(\test, \a, 0);

o.remove;
o = OSCresponderNode(Library.at(\vizAddr).copy, '/pbind', { |t, r, m| m.postcs }).add;
o = OSCresponderNode(Library.at(\vizAddr).copy.port_(nil), nil, { |t, r, m| m.postcs }).add;

o = OSCresponderNode(Library.at(\vizAddr).copy, '/note', { |t, r, m| m.postcs }).add;
o.inspect

o = OSCpathResponder(Library.at(\vizAddr).copy, ['/note', 'slowSteps'], { |t, r, m| m.postcs }).add.removeWhenDone;

var bp = BP(\st);
bp.ampCtl.value = 0;
bp.gest = Pn(\slowSteps, 1);
bp.numEv = 2; // Pwhite(4, 7, inf);
bp.gDelta = Pwhite(2.5, 4.0, inf);
bp.slowRate = Pwhite(0.5, 0.8, inf);
bp.defaultParms = nil;
bp.kdecay = Pexprand(0.014, 0.017, inf);
bp.makeStreamForKey(\kfreq);	// reset this one
bp.autoRun = true;		
bp.gestures.oneKlankStepsCallback = { |parms|
	CleanupStream(~gestures[\oneKlankSteps].(parms).asStream, parms[\callback])
};

~resp.remove;
~resp = OSCresponderNode(s.addr, '/n_go', { |t, r, m| m[1].debug("synth") }).add;

BP(\st).event.eventKey = \polySynthPlayNotifyData;
BP(\st).event.notifyDependents = { e = currentEnvironment };
BP(\st).reset;

e.node
e.evArgs.pairsDo({ |a, b| [a, b].postln }); ""
e.msgArgs.do(_.postln); ""

BP(\st).play;
BP(\st).stop;

BP(\st).free;

BP(\st).slowDelta = 5;

BP(\st).gestures.slowSteps = { |parms|
	Pbind(
		\instrument, \pvplayPanDist,
		\pvbuf, ~pvbuf,
		\pt, BPStream(\ptIndex).clump(3),
		\start, ~start,
		\startFrame, Pkey(\start) / ~buffers[0].numFrames * ~numPvFrames,
		#[pan, distance], ~xyPat.(parms),
		\delta, BPStream(\slowDelta),
		\rate, BPStream(\slowRate).clump(3),
		\time, Pkey(\delta) * 0.2,
		\amp, BPStream(\amp) * (-4.dbamp),
		\shiftS, BPStream(\slowShift).clump(3),
		\shiftE, Pkey(\shiftS)
	).trace
};



o.inspect
OSCresponder.all.detect { |r| r.cmdName == '/test' }.inspect
OSCresponder.all.do({ |r| r.cmdName.postln }); ""

thisProcess.recvOSCfunc = nil;
thisProcess.recvOSCfunc = { |t, a, m|
	if(#['status.reply', '/status.reply', '/info'].includes(m[0]).not) {
		m.postcs;
	}
};

~ad.matches(o.addr)

p = Pbind(
	\instrument, \default,
	\degree, Pwhite(-7, 7, 8),
	\freq, (Pkey(\degree).degreeToKey(#[0, 2, 4, 5, 7, 9, 11]) + 60).midicps,
	\delta, 0.25,
	\sustain, 0.2,
	\pan, Pwhite(-1.0, 1.0, inf),
	\amp, 0.1
	// // note, don't do this b/c of Event:embedInStream
	// \vizKeys, (scaledeg: \degree, pan: { |pan| pan*0.5 + 0.5 })
	// instead:
).play(protoEvent: ProtoEvent(\singleSynthPlayerData).copy.proto_((
	vizKeys: (scaledeg: \degree, pan: { |pan| pan*0.5 + 0.5 }),
	vizPath: [\pbind, { |node| node.nodeID }],
	vizAddr: Library.at(\vizAddr)
)));
