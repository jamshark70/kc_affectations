// converting loose pbinds to PR/BP

PR(\abstractProcess).clone {
	~alwaysReset = true;
	~printStopMsg = false;
	~event = (eventKey: \voicerNote);
	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;
		~ampCtl = GenericGlobalControl(\ampMul, nil, -18.dbamp, \amp);
	};
	~ctlGuiKeys = #[ampCtl];
	~useGui = Func(\bpUseGui).v;
	~freeCleanup = { ~ampCtl.free };

	~pan = 0;
	~distance = 5;
	~dur = Pseg(
		Pseq(#[0.5, 0.1, 0.5], 1),
		3, \exp
	);
	~freq = Pseries(26,
		Pseq(\shufBalance.eval([-1, 1, 2, 3], [6, 9, 11, 4]), 1)
			* Pif(Pkey(\diff) > 0, -1, 1),
		inf
	);
	~mode = \g;
	~gate = Pkey(\dur).linlin(0.1, 0.5, 0.6, 0.2);
	~mod_lev = 2.5;
	~count = Pseries(1, 1, inf);
	~length = Pif(Pkey(\count) < 18, Pwhite(2.0, 3.5, inf),
		(Pwhite(3.6, 4.8, inf) - Pseries(0, Pkey(\dur), inf))); //.trace,
	~attackTimeScale = 1;
	~decayTimeScale = 1;

	~asPattern = {
		Pbind(
			\count, Pseries(1, 1, inf),
			\finalAmp, ~ampCtl.asMap,
			\pan, BPStream(\pan),
			\distance, BPStream(\distance),
			\dur, BPStream(\dur),
			\diff, Pdiff(Pkey(\dur)),
			\freq, BPStream(\freq),
			\mode, BPStream(\mode),
			\gate, BPStream(\gate),
			\mod_lev, BPStream(\mod_lev),
			\count, BPStream(\count),
			\length, BPStream(\length),
			\attackTimeScale, BPStream(\attackTimeScale),
			\decayTimeScale, BPStream(\decayTimeScale)
		)
	};

	~reset = Func(\resetBPStreams).v;
} => PR(\sunrise);

BP(\sr).free;
PR(\sunrise) => BP(\sr);
VC(\ac) => BP(\sr);
0 => BP(\sr);






PR(\abstractProcess).clone {
	~alwaysReset = true;
	~reset = Func(\resetBPStreams).v;
	~printStopMsg = false;
	~event = (eventKey: \voicerNote);
	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;
		~ampCtl = GenericGlobalControl(\ampMul, nil, -18.dbamp, \amp);
	};
	~ctlGuiKeys = #[ampCtl];
	~useGui = Func(\bpUseGui).v;
	~freeCleanup = { ~ampCtl.free };

	~root = Pstutter(Pwrand(#[1, 2], #[0.8, 0.2], inf), Pseq([
		Pwhile1({ |inval, next| next < 40 },
			Pseries(26, Pwrand(#[1, 2, 3], #[1, 4, 3].normalizeSum, inf), inf)
		),
		Pwhile1({ |inval, next| next >= 21 },
			Pseries(40, Pwrand(#[-1, -2, -3], #[1, 4, 3].normalizeSum, inf), inf)
		)
	]));
	~num = Pexprand(2.5, 6.499, inf).round;

	~angle = Pseries(
		{ 2pi.rand },
		Pwhite(0.1, 0.4, inf) * Pstutter(inf, Prand(#[-1, 1], 1)),
		inf
	);
	~radius = Paccumbounce(0.2, 1, Pexprand(0.04, 0.1, inf)).asStream;
	~pan = cos(Pkey(\angle)) * Pkey(\radius);
	~distance = (sin(Pkey(\angle)) * Pkey(\radius)).linlin(-1, 1, 5, 20);
	~dur = Plazy({ |ev|
		Pgeom.fromEndpoints(rrand(0.2, 0.32), rrand(0.09, 0.14), ev[\num])
		* Pexprand(0.75, 1.333, inf)
	});
	~freq = Pwhile1({ |ev, next| next <= 54 },
		Pkey(\root) + Pseries(0,
			Pwrand(#[1, 2, 3, 4], #[1, 4, 3, 2].normalizeSum, inf), Pkey(\num).asStream)
	);
	~mode = \g;
	~gate = 0.5;
	~mod_lev = 2.5;
	~length = Pwhite(3.0, 4.5, inf) - Pseries(0, Pkey(\dur), inf);
	~attackTimeScale = 0.25;
	~decayTimeScale = 1;
	~rest = Pwhite(0.15, 0.35, 1);

	~asPattern = {
		var	self = currentEnvironment;
		~restStream ?? { ~makeStreamForKey.(\rest) };
		PR(\psetp2).copy.prep(
			Pbind(
				\root, BPStream(\root, envir: self),
				\num, BPStream(\num, envir: self)
			),
			Pseq([
				Pbind(
					\finalAmp, ~ampCtl.asMap,
					\angle, BPStream(\angle, envir: self),
					\radius, BPStream(\radius, envir: self),
					\pan, BPStream(\pan, envir: self),
					\distance, BPStream(\distance, envir: self),
					\dur, BPStream(\dur, true, envir: self),
					\freq, BPStream(\freq, true, envir: self),
					\mode, BPStream(\mode, true, envir: self),
					\gate, BPStream(\gate, true, envir: self),
					\mod_lev, BPStream(\mod_lev, true, envir: self),
					\length, BPStream(\length, true, envir: self),
					\attackTimeScale, BPStream(\attackTimeScale, true, envir: self),
					\decayTimeScale, BPStream(\decayTimeScale, true, envir: self)
				),
				Pbind(
					\freq, #[],
					\dur, Pfuncn(e { ~restStream.next }),
					\length, 0.2,
					\gate, 0.1
				)
			], 1)
		)
	};
} => PR(\stacking);


BP(\st).free;
PR(\stacking) => BP(\st);
VC(\ac) => BP(\st);
0 => BP(\st);

BP(\st).root = BP(\st).root.trace;


// inversions sequence
(
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);
	~autoRun = false;
	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;
		~ampCtl = GenericGlobalControl(\ampMul, nil, -18.dbamp, \amp);
	};
	~ctlGuiKeys = #[ampCtl];
	~useGui = Func(\bpUseGui).v;
	~freeCleanup = { ~ampCtl.free };

	~gest = Pseq(#[inversion1, inversion2, lauraslide], inf);
	~numEv = Pwhite(12, 19, inf);
	~totalDur = Pwhite(2.5, 4.0, inf);
	~rest = Pwhite(0.8, 1.6, inf);

	~pan = { |parms|
		Pseries.fromEndpoints(rrand(-1.0, -0.5), rrand(0.5, 1.0), parms[\numEv])
			* #[-1, 1].choose;
	};
	~distance = { |parms|
		Pseries.fromEndpoints(rrand(15.0, 18.0), rrand(5.0, 7.0), parms[\numEv])
	};
	~dur = { |parms|
		Pgeom.fromEndpoints(rrand(0.12, 0.22), rrand(0.06, 0.09), parms[\numEv])
			* Pexprand(0.75, 1.333, inf);
	};
	~freq = { |parms|
		Pwhile1({ |ev, next| next <= 54 },
			~slideNotes[parms[\gest]].value(parms) + 28)
	};
	~mode = \g;
	~ffreq = Pfunc { |ev| Mode(ev[\mode]).cps(ev[\freq]) * 4 };
	~gate = Pkey(\freq).linlin(14, 54, 0.1, 0.8);
// 	~mod_lev = 2.5;
	~length = { |parms|
		(Pwhite(0.8, 1.2, inf) * parms[\totalDur]) - Pseries(0, Pkey(\dur), inf);
	};
	~attackTimeScale = Pkey(\gate).linlin(0.1, 0.8, 1.4, 0.15);
	~decayTimeScale = 1;

	~slideNotes = (
		lauraslide: Pseries(
			{ rrand(-7, 0) },
			Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
			Pkey(\numEv).asStream
		),
		inversion1: Pseries(
			{ rrand(-3, 4) },
			Pstutter(
				Pseq([Pfuncn({ |ev| (ev[\numEv] * 0.6).round }), 100], 1),
				Pseq([1, -1], 1)
			) * Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
			Pkey(\numEv).asStream
		),
		inversion2: Pseries(
			{ rrand(0, 8) },
			Pstutter(
				Pseries(1, 1, inf),
				Pseq([1, -1], inf, 0 /*, { 2.rand }*/)
			) * Pwrand(#[1, 2, 3], #[2, 2, 1].normalizeSum, inf),
			Pkey(\numEv).asStream
		)
	);

	~runGesture = { |parms|
		if(~spawner.notNil) {
			~spawner.seq(~makePhrase.(parms));
		} {
			"BP(%): Not playing; can't run phrase.".format(~collIndex.asCompileString).warn;
		};
	};

	~makePhrase = { |parms(Event.new)|
		block { |break|
			var val;
			#[gest, numEv, totalDur].do { |key|
				parms[key] ?? {
					if((val = (key ++ "Stream").asSymbol.envirGet.next(parms)).isNil) {
						break.(nil)
					};
					parms[key] = val;
				};
			};
			Pbind(
				\parms, parms,
				\numEv, parms[\numEv],
				\finalAmp, ~ampCtl.asMap,
				\pan, ~pan.(parms),
				\distance, ~distance.(parms),
				\dur, ~dur.(parms),
				\freq, ~freq.(parms),
				\mode, BPStream(\mode),
				\ffreq, BPStream(\ffreq),
				\gate, BPStream(\gate),
				\length, ~length.(parms),
				\attackTimeScale, BPStream(\attackTimeScale),
				\decayTimeScale, BPStream(\decayTimeScale)
			)
		}
	};

	~asPattern = {
		#[gest, numEv, totalDur, rest].do { |key|
			(key ++ "Stream").asSymbol.envirGet ?? {
				~makeStreamForKey.(key)
			};
		};
		Pspawner({ |sp|
			~spawner = sp;
			if(~autoRun) {
				"BP(%): autoRun enabled\n".postf(~collIndex.asCompileString);
				loop {
					sp.seq(~makePhrase.());
					sp.wait(~restStream.next());
				}
			} {
				loop {
					sp.wait(0.1);
				}
			}
		})
	};
} => PR(\armsInv);
)

BP(\ai).free;
PR(\armsInv) => BP(\ai);
VC(\sp) => BP(\ai);
0 => BP(\ai);

BP(\ai).autoRun = true;

BP(\ai).gest = Pseq(#[inversion1, inversion2, lauraslide], inf);



// Shiva

Fact(\armsmelVC) => VC(\am);
VC(\am) => VP(0);

(
make: {
	3.collect { |i|
		var	bp = PR(\melody) => BP(("am" ++ i).asSymbol);
		bp.pan = #[0, -0.8, 0.8][i];
		0 => bp;

		bp.event.distFar_(50).lcrvbamt_(0.035).ampMul_(nil);
		bp.gate = Pseg(
			Pstutter(2, Pseq([
				Pexprand(0.1, 0.22, 1),
				Pwhite(0.6, 0.9, 1)
			], inf)),
			// hold, then slide
			Ppatlace([
				Pwhite(3.0, 8.0, inf),
				Pwhite(1.1, 2.2, inf)
			], inf)
		);
		bp.distance = Pkey(\gate).linlin(0.1, 0.75, 45, 8);
	};
},
type: \bp) => Fact(\shivaBPs);


Fact(\shivaBPs).makev;

(play: {
// currentEnvironment.debug;
	min(3, ~i).do { |j|
		BP(("am" ++ j).asSymbol).triggerOneEvent(0);
	};
	if(~playtc and: { BP.exists(\tc) }) { BP(\tc).triggerOneEvent(0.1) };
}) => ProtoEvent(\amTrig);

PR(\abstractProcess).clone {
	~event = (eventKey: \amTrig);
	~quant = NilTimeSpec.new;

	~playtc = 0.5.asPattern.coin;
	~delta = Pwhite(1.5, 3.0, inf);
	~i = Pseries(1, 1, inf);

	~asPattern = {
		Pbind(
			\i, BPStream(\i),
			\playtc, BPStream(\playtc),
			\delta, BPStream(\delta)
		)
	};
	~stopCleanup = {
		BP(#[am0, am1, am2, tc]).stop(0);
	};

	~reset = {
		BP(#[am0, am1, am2, tc]).do(_.reset);
	};
} => PR(\shivaTrig);

BP(\sh).free;
PR(\shivaTrig) => BP(\sh);




// 3 levels
(
keys: #[master, glrvbmc, lcrvbmc],
make: {
	3.collect { |i|
		PR(\armsSkidMel).chuck(BP((\sm ++ i).asSymbol), nil, (
			master: ~master,
			glrvbmc: ~glrvbmc,
			lcrvbmc: ~lcrvbmc,
			amp: 0.9,
			rewriteLevel: Pseq([0, 1, 2, Pwhite(1, 3, inf)], 1),
			loTime: Pwhite(0.22, 0.45, inf),
			hiTime: Pkey(\loTime) * Pexprand(1.0, 1.25, inf)
		)).prepareForPlay;
	};
}, type: \bp) => Fact(\threelevBP);


(play: {
// currentEnvironment.debug;
	min(3, ~i).do { |j|
		BP(("sm" ++ j).asSymbol).triggerOneEvent(0);
	};
	if(~playtc and: { BP.exists(\tc) }) { BP(\tc).triggerOneEvent(0.1) };
}) => ProtoEvent(\l3Trig);

BP.all.free;
Fact(\threelevBP).makev;

PR(\shivaTrig).chuck(BP(\smt), nil, (
	event: (eventKey: \l3Trig),
	playtc: false,
	i: 3
));

3.do { |i| BP(("sm" ++ i).asSymbol).pan = i-1; };

BP.all.do(_.reset);



// s & i
(
PR(\abstractProcess).clone {
	~event = (eventKey: \monoSupport);
	~prep = {
		~event.proto = topEnvironment[\rvbEvent].proto;		
	};

	~mode = \g;
	~high = Pseq([0, 1, Pseq([Pn(0, { rrand(1, 5) }), Pn(1, { rrand(1, 2) })], inf)], 1);
	~prevHigh = Pdelay(Pkey(\high));
	~top = Pswitch1([
		Paccumbounce(30, 40, Pwrand(#[-1, 1, 2, 3], #[3, 3, 2, 1].normalizeSum, inf)),
		Paccumbounce(38, 47, Pwrand(#[-1, 1, 2, 3], #[3, 3, 2, 1].normalizeSum, inf))
	], Pkey(\high));
	~degree = (Pkey(\top) -.x Pseries(0, Pwrand(#[1, 2, 3], #[1, 3, 2].normalizeSum, 3)))
		.clump(3);
	~freq = Pfunc { |ev| Mode(ev[\mode]).cps(ev[\degree].scramble) };
	~delta = Pwhite(1, 4, inf);
	~freqlag = Pkey(\delta) * 0.6;
	~finalAmp = -12.dbamp;
	~protoEvent = Pseq([
		\polySynthPlayNotify,
		Pif(Pkey(\prevHigh) > 0, \polySynthPlayNotify, \polySynthTrigger)
	], 1);
	~sustain = Pif(Pkey(\high) > 0, Pkey(\delta) - 0.6, inf);
	~lag = Pif(Pbinop('==', Pkey(\protoEvent), \polySynthPlayNotify), 0,
		Pn(Pseries(0, Pwhite(0.12, 0.25, inf), 3).clump(3), inf));

	~recvEventNotify = { |node| ~node = node };
	~stopCleanup = { if(~node.notNil) { ~node.do(_.release) }; ~node = nil };

	~asPattern = {
		Pbind(
			\instrument, ~event[\voicer].nodes[0].defname,
			\node, Pfunc { ~node ? 0 },
			\chan, ~event[\voicer].nodes[0].bus.asMixer,
			\ffreq, ~event[\voicer].globalControls[\ffreq].asMap,
			\rq, ~event[\voicer].globalControls[\rq].asMap,
			\mode, BPStream(\mode),
			\high, BPStream(\high),
			\prevHigh, BPStream(\prevHigh),
			\top, BPStream(\top),
			\degree, BPStream(\degree),
			\freq, BPStream(\freq),
			\delta, BPStream(\delta),
			\freqlag, BPStream(\freqlag),
			\finalAmp, BPStream(\finalAmp),
			\protoEvent, BPStream(\protoEvent),
			\sustain, BPStream(\sustain),
			\lag, BPStream(\lag)
		).collect { |ev|
			var	sustain;
			if((sustain = ev[\sustain]).notNil and: { ev[\sustain] != inf }) {
				thisThread.clock.sched(sustain, {
					Func(\schedEventBundleArray).doAction(s.latency, 0, s,
						[\n_set, ~node.asArray.asOSCArgArray, \gate, 0].flop, true);
					nil
				});
			};
			ev
		}
	};
} => PR(\siDuet);
)

BP(\si).free;
PR(\siDuet) => BP(\si);
VC(\sp) => BP(\si);
0 => BP(\si);


// laura manip
(
keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;
	PR(\armsSkidMel).chuck(BP(name), nil, (
		master: ~master,
		glrvbmc: ~glrvbmc,
		lcrvbmc: ~lcrvbmc,
		amp: 0.4,
		def: \combskid,
		rdecay: 2,
		hiffreq: Pfunc { |ev| Mode(ev[\mode]).cps(ev[\degree] + 28) },
		lpffreq: Pexprand(1200, 7000, inf)
	));
	0 => BP(name);
}, type: \bp) => Fact(\threelevBP);

Fact(\threelevBP) => BP(\sm);



BP(\sm).reset;

2.do { BP(\sm).triggerOneEvent(0) };

BP(\sm).loTime = Pexprand(0.4, 0.6, inf);

// THIS STUFF HERE!!
BP(\sm).def = \combskid;
BP(\sm).rdecay = 2;
BP(\sm).listVars;
BP(\sm).hiffreq = Pfunc { |ev| Mode(ev[\mode]).cps(ev[\degree] + 28) };

BP(\sm).lpffreq = Plazy({ Pn(~lpffreqCtl.asMap, inf) });
BP(\sm).lpffreq = Pexprand(1200, 7000, inf);
