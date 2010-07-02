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