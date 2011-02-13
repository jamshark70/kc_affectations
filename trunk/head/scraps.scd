				indices = (0..17).scramble.keep((i*1.5).round.asInteger);
			indices.do { |i| amps[i] = rrand(0.0, 0.1) };

//[test = ~fullSet.any { |x| ~activeRatios.includes(x).not }, (~fullSet - ~activeRatios).size > 0, not(~fullSet == ~activeRatios), ~fullSet.class, ~activeRatios.class, ~fullSet.size, ~activeRatios.size].debug("tests");


			result = Pfset(
				{ self.activeRatios.add(ratio) },
				Pfin(repeats, Pbind(
					\instrument, \partial1bgated,
					\ratio, ratio,
					\freq, BPStream(\fund) * ratio,
					\egRate, ~tempoCtl.asMap,
					\egRateMul, ratio,
					\delta, ratio.reciprocal,
					\sustain, Pkey(\delta) * 0.5,
					\egBuf, ~egbuf,
					\chan, ~chan
				)),
				{ self.activeRatios.remove(ratio) }
			);


		// took way too long to figure this out but...
		// this test is OK if both are Sets (not IdentitySets) and fullSet starts at 1.0
		// this is faster b/c == fails if the collection sizes are different




MIDIRecBuf(\a41, [
	#[68, 70, 72, 73, 72, 70, 68],
	#[1, 1, 1, 2, 1, 3, 0.1],
	#[1, 1, 1, 2, 1, 3, 3],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\a42, [
	#[63, 65.01, 66, 65.01, 67, 68, 67, 63],
	#[1, 1, 1, 1, 1, 3, 1, 0.1],
	#[1, 1, 1, 1, 1, 3, 1, 3],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\t4, [
	#[60, 58, 56, 58, 63, 63, 61, 60],
	#[1, 1, 1, 1, 1, 2, 2, 0.1],
	#[1, 1, 1, 1, 1, 2, 2, 3],
	0.5
].asNotes, ~tprop) => MBM(0);

MIDIRecBuf(\b4, [
	#[44, 49.01, 48, 46, 44, 51, 44],
	#[1, 1, 1, 2, 1, 3, 0.1],
	#[1, 1, 1, 2, 1, 3, 3],
	0.5
].asNotes, (type: \c, voice: \bass, xfer: \lpfxfer2)) => MBM(0);


MBM(0)[\a41].copy.name_(\a51) => MBM(0);
MBM(0)[\a51].notes.last.length_(8);

MIDIRecBuf(\a52, [
	#[r, 63, 65, 67, 68, 66, 65.01, 65, 63, 61, 60],
	#[2, 1, 1, 1, 2, 1, 1, 1, 1, 1, 0.1],
	#[2, 1, 1, 1, 2, 1, 1, 1, 1, 1, 5],
	0.5
].asNotes, ~aprop) => MBM(0);

MIDIRecBuf(\t5, [
	#[r, 63, 61, 60, 58, 61, 56, 63],
	#[5, 1, 1, 1, 1, 1, 2, 0.1],
	#[5, 1, 1, 1, 1, 1, 2, 5],
	0.5
].asNotes, ~tprop) => MBM(0);

MIDIRecBuf(\b5, [
	#[r, 44, 46, 48, 49.01, 49, 48, 46, 44],
	#[5, 1, 1, 1, 1, 1, 1, 1, 0.1],
	#[5, 1, 1, 1, 1, 1, 1, 1, 5],
	0.5
].asNotes, (type: \c, voice: \bass, xfer: \lpfxfer2)) => MBM(0);


	~superPattern = ~asPattern;
	~asPattern = {
		var	self = currentEnvironment, resp;
		Pfset({ ~lpfbus = Bus.control(s, 1) },
			Ptpar([
				0, ~superPattern.(),
				0.01, Pfuncn { |ev|
					(	type: \on, instrument: \ctlEnv, outbus: ev[\lpfbus],
						time: self[\phraseDur] + self[\relStream].next(ev),
						connect: 0, env: self.lpfEnv,
						group: self.chan.synthgroup,
						callback: { |event|
							resp = OSCpathResponder(s.addr, ['/n_end', event[\id][0]], {
								ev[\lpfbus].free; resp.remove;
							}).add
						},
						delta: 0
					).parent_(nil)  // force default parent event
				},
			])//,
//			{	(e { ~lpfbus.free }).defer(5.0) }
		)
	};


// just in case...

BP(\cd).notePattern = { //|p5, sharp, shortFirst|
		// 61.01 is needed for Bb/Db and Bb/Gb
		// .01 has no effect on D-nat or G-nat (already tuned pure against Bb)
		var	freqs = if(~oneNoteStream.next) { #[[56], [63]] } {
				[	#[56, 58, 56],
					[63, 61.01 + ~sharpStream.next.binaryValue, 63]
				]
			},
			fsize = freqs[0].size,
			durs = { ~durStream.next(fsize) } ! fsize, notes;
		switch(~p5Stream.next)
			{ 0 } { freqs = freqs.copy.put(1, freqs[1] + 5) }
			{ 2 } { freqs = freqs.add(freqs[1] + 5) };
//		if(~p5Stream.next.not) { freqs = freqs.copy.put(1, freqs[1] + 5) };
		if(~shortFirstStream.next) { durs[0] = ~shortDurStream.next(fsize) };
		~phraseDur = durs.sum;	// BAD HACK
		notes = freqs.flop.collect { |f, i|
			SequenceNote(f, durs[i], durs[i] * ~legatoStream.next, ~gateStream.next(fsize))
		};
		notes.last.dur_(0.1);
		Pseq(notes, 1)
	};


p = BP(\cpt);
p.seqKeys = #[t3, a31, a32];
p.tempoPat = 1;
p.useLpf = true;

p.seqKeys.do { |k| MBM(0)[k].dumpSeq }; ""

p.asPattern = {
		var	self = currentEnvironment, resp, pat = ~moreHorribleIndirectionPattern.();
		(if(~useLpf ? false) { 
			Pfset({ ~lpfbus = Bus.control(s, 1) },
				Ptpar([
					0, pat,
					0.01, Pfuncn { |ev|
						(	type: \on, instrument: \ctlEnv, outbus: ev[\lpfbus],
							time: self[\phraseDur] + self[\relStream].next(ev),
							connect: 0, env: self.lpfEnv,
							group: self.chan.synthgroup,
							callback: { |event|
								resp = OSCpathResponder(s.addr, ['/n_end', event[\id][0]], {
									ev[\lpfbus].free; resp.remove;
								}).add
							},
							delta: 0
						).parent_(nil)  // force default parent event
					},  // else nil
				])
			)
		} { pat }).debug("asPat");
	};

s.queryAllNodes;
s.sendMsg(\n_trace, 118249)

MBM(0).v.bufs.do({ |buf| buf.properties.debug(buf.name) }); ""
s.sendMsg(\n_free, 118249);

p.xferKey = { |currentKey| MBM(0)[currentKey.debug("in xferkey")].properties[\xfer] ?? { \formantXfer2 } };

BP(\cd).xferEvent = { |ev, fspecs, lockref, key|
		(
			protoEvent: \singleSynthPlayNotify,
			instrument: ~xferKey.(key), //~evalEnvir.(\xferKey),
			ffreq: ~lpfxferFreqStream.next(ev),
			lpfxAmp: ~lpfxferAmpStream.next(ev),
			ffreqs: fspecs[0],
			amps: fspecs[1],
			qs: fspecs[2],
			sustain: nil,
			delta: 0.1,
			collIndex: ~collIndex,
			notifyDependents: {
				lockref.value = ~lock;
				~lock.killNodes = ~lock.killNodes.add(~node);
			},
			lpfreq: ev[\lpfbus] !? { ev[\lpfbus].asMap }
		).debug("cd xfer")
	}

BP.all.do(_.reset);



{ |gest|
								if(once) {
									saven = bp.n;
									saveFactor = bp.factor;
[bp.collIndex, thisThread.beats].debug("made cleanupstream for");
									bp.n = CleanupStream(
										Pseed(Pn(seed, 1), Pfin(num, saven)).postcs.asStream,
										e { "cleanup func".debug;
											bp.n = saven;
											bp.factor = saveFactor;
											~stop.()
										}
									);
									bp.factor = Pseed(seed, saveFactor);
									once = false;
								};
								gest
							}

BP(\eq).free;
PR(\basicBufferPlayer).chuck(BP(\eq), nil, (
	buffers: BP(\drum3).buffers,
	inChannels: 1,
	postMCCreation: { |chan|
		defer(e { ~eq = MultiEQ(1).edit(chan) });
		~ampCtl = GenericGlobalControl(\amp, nil, 1, [1/25, 25, \exp, 0]);
	},
	free: { ~ampCtl.free },
	useGui: { |vpi| ~ampCtl => VP(vpi) },
	def: \bufGrain,
	time: 0.8,
	rate: 1,
	start: 0,
	amp: Plazy { Pn(~ampCtl.asMap, inf) },
	delta: 1,
	bufIndex: Pseq((0..3), inf)
));

// destructive eq on udu-finger samples
MultiEQ.new(1, \hipass, 231.636, 0.dbamp, 1, \eq, 767.739, -9.291.dbamp, 0.104, \eq, 703.961, -3.937.dbamp, 0.057, \eq, 1134.832, -8.031.dbamp, 0.057, \eq, 1852.963, -4.567.dbamp, 0.057)

BP(\eq).buffers[0].path.dirname
BP(\eq).buffers.collect(_.path)

t = TLSequenceIterator([
	bpCmd: (name: \eq, quant: DelayTimeSpec(1), prepareBP: { |bp|
		bp.bufIndex = Pseries(0, 1, 4);
		bp.chan.startRecord(BP(\eq).buffers[0].path.dirname +/+ "udu-eq.aiff");
	}),
	\sync,
	1,
	{ BP(\eq).chan.stopRecord; 0 }
]).play;




/*
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
		if(~tempo.isNumber) { thisThread.clock.tempo = ~tempo }
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
*/



BP:stop
if(#[drum7, drum8].includes(collIndex)) {
	"\n\n\nSTOPPED %\n".postf(collIndex);
	this.dumpBackTrace;
	"^^ This is a DEBUG backtrace; don't panic.".postln;
};

stopNow
if(#[drum7, drum8].includes(collIndex)) {
	"\n\n\nSTOPPED NOW %\n".postf(collIndex);
	this.dumpBackTrace;
	"^^ This is a DEBUG backtrace; don't panic.".postln;
};

streamCleanupFunc
if(#[drum7, drum8].includes(collIndex)) {
	"\n\n\nSTOPPED BY CLEANUP %\n".postf(collIndex);
	this.dumpBackTrace;
	"^^ This is a DEBUG backtrace; don't panic.".postln;
};



o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m|
	OSCpathResponder(s.addr, ['/n_set', m[1], \amp], { |t, r, m|
		r.remove;
		m[3].debug("amp")
	}).add;
	s.sendMsg(\s_get, m[1], \amp);
}).add;

s.sendMsg(\s_get, ~master.synth.nodeID, \pan);
o.remove;
o = OSCresponderNode(s.addr, '/n_set', { |t, r, m| r.remove; m.postcs }).add;

OSCresponder.all.select { |resp| resp.isKindOf(OSCpathDispatcher) }.do { |resp|
	resp.pathResponders.copy.do { |r|
		if(r.cmdName == '/n_set') { r.path.postln; r.remove };
	};
};

p.use {
	x = Pwrand(#[0, 1], Pif(Pkey(\delta) >= (~messedUpMulCtl.asPattern * 0.25), #[0.75, 0.25], #[0.1, 0.9]), inf).asStream;
};

x.next((delta: 0.1))
