

SynthDef(\simpleLPCfxPan, { |inbus, outbus, lpcbuf, voxdur = 1, start, end = 1, time = 1, amp = 1, freq = 440, noiseMul = 1, hpf = 1600, xfscale = 0.25, lpf = 15000, pan = 0, attack = 0.05, decay = 0.05|
	var	src = In.ar(inbus, 1),
		// note, ar because LPCVals.ar with .kr pos input is broken
		pos = Line.ar(start, end, time) / voxdur,
 		lpcv = LPCVals.ar(lpcbuf, pos),
 		noise = HPF.ar(WhiteNoise.ar(noiseMul), hpf),
		sig = LPCSynth.ar(lpcbuf, XFade2.ar(src, noise, (xfscale * lpcv[2]).madd(2, -1)), pos, amp * lpcv[1]),
		eg = EnvGen.kr(Env.linen(attack, time - attack - decay, decay), doneAction: 2);
	sig = LPF.ar(sig, lpf);
	sig = LeakDC.ar(sig);
	Out.ar(outbus, Pan2.ar(Limiter.ar(sig * eg), pan));
}).add;



// bus lock object - release bus when all the locking objects are gone
Proto {
	~prep = { |args|
		if(args.respondsTo(\keysValuesDo)) {
			currentEnvironment.putAll(args);
		};
		~locks = IdentitySet.new;
		// this way, makeStuff can have whatever args it needs
		// and it will pull them from the environment (after being put there by putAll)
		currentEnvironment.env.use { ~makeStuff.valueEnvir };
		currentEnvironment
	};

	~numCh = 1;
	~rate = \audio;
	~server = { Server.default };

	// user overrides
	~makeStuff = { |numCh, rate, server|
		~server = server.value;
		if((~bus = Bus.perform(rate, ~server, numCh)).isNil) {
			Error("couldn't get % bus".format(rate)).throw;
		};
		~bus //.debug("made");
	};

	~freeStuff = {
		~bus /*.debug("freed")*/ .free;
		~killNodes.do(_.free);
	};

	~addNode = { |node|
		var	endFunc = e { |obj, what|
			if(what == \n_end) {
				node.removeDependant(endFunc);
				~removeLock.(node);
			};
		};
		~locks.add(node);
		NodeWatcher.register(node);
		node.addDependant(endFunc);
	};

	~removeLock = { |obj|
		~locks.remove(obj);
		if(~locks.isEmpty) {
			~freeStuff.();
		};
	};
} => PR(\busLock);

PR(\busLock).clone {
	~busFreeDelay = 1;
	~freeStuff = {
		~stopThings.do(_.stop);
		~killNodes.do(_.free);
		AppClock.sched(~busFreeDelay, e { ~bus.free });
	};
} => PR(\busFxPatLock);

(parent: ProtoEvent(\polySynthPlayer).v.parent.copy.putAll((
	lockKey: \busLock,
	superPlay: ProtoEvent(\polySynthPlayer).v[\play],
	play: {
		var	chan = ~chan;
		~numCh ?? { ~numCh = ~chan.inChannels };
		~lock = PR(~lockKey).copy.prep((
			numCh: ~numCh, server: ~chan.server
		));
		~bus = ~lock.bus;
		~target = ~chan.synthgroup;
		~chan = nil;
		~superPlay.();

		if(~node.notNil and: { (~node.tryPerform(\isEmpty) ? false).not }) {
			~playExtraProcess.(chan);
			~node.do { |node| ~lock.addNode(node) };
		} {
			~lock.freeStuff;
		};
	},
	playExtraProcess: { |chan|
		if(~lpcEv.size > 0) {
			~lpcEv.putAll((
				bus: chan.inbus,
				target: chan.effectgroup,
				chan: nil,
				inbus: ~lock.bus,
				collIndex: ~collIndex,
					// effectgroup might have post-lpc effect nodes (chorus etc.)
					// so put lpc's up front
				addAction: ~lpcEv[\addAction] ?? { \addToHead }
			))
			// cuz parent: don't work in putAll #@$*$&*$&@#312
			.parent_(ProtoEvent(~lpcProto ?? { \singleSynthPlayer }).v.parent)
			.play;
			~lpcEv[\node].do { |node| ~lock.addNode(node) };
		} {
			~sendNode = Synth("mixers/Send" ++ ~numCh,
				[busin: ~lock.bus, busout: chan.inbus, level: 1],
				chan.effectgroup
			);
			~lock.killNodes = ~sendNode;
		};
	} //,
// 	notifyDependents: {
// 		~node.do { |node| ~lock.addNode(node) };
// 	}
))) => ProtoEvent(\polySynthBusLock);

(parent: ProtoEvent(\polySynthBusLock).v.parent.copy.putAll((
	lockKey: \busFxPatLock,
	playExtraProcess: { |chan|
		~lock.busFreeDelay = ~busFreeDelay ? 1;
		if(~fxPatEv.size > 0 and: { ~fxPatEv[\pat].notNil }) {
			~fxPatEv[\streamPlayer] = ~fxPatEv[\pat].play(
				thisThread.clock,
				Event(
					proto: (
						bus: chan.inbus,
						target: chan.effectgroup,
						chan: nil,
						inbus: ~lock.bus,
						lock: ~lock,
						collIndex: ~collIndex,
							// effectgroup might have post-lpc effect nodes (chorus etc.)
							// so put lpc's up front
						addAction: ~fxPatEv[\addAction] ?? { \addToHead }
					),
					parent: ProtoEvent(~fxProto ?? { \singleSynthPlayer }).v.parent.copy
				),
				~fxPatEv[\quant]
			);
			~lock.stopThings = [~fxPatEv[\streamPlayer]];
		} {
			~sendNode = Synth("mixers/Send" ++ ~numCh,
				[busin: ~lock.bus, busout: chan.inbus, level: 1],
				chan.effectgroup
			);
			~lock.killNodes = ~sendNode;
		};
	}
))) => ProtoEvent(\polySynthFxPatLock);