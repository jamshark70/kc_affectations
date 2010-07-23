// todo:
// then do running across the floor

// video notes:
// keep sparse at first
// turning backstage to launch new variations
// what is the pitch theme?
// straight line vs curved
// parallel vs crossing paths
// track fwd/back position of dancers for 'distance' parm?


Library.put(\chucklib, \midiSearches, #["remote"]); BP.loadGui;
#[glrvbmc, glrvb, lcrvbmc, lcrvb, master].do({ |obj| obj.envirGet.free; obj.envirPut(nil) });
s.waitForBoot(e { (Document.current.path.dirname +/+ "feet-defs.scd").debug("loading").loadPath });

(
~glrvbmc => MCG(5);
~lcrvbmc => MCG(6);
~master => MCG(7);

m = MixerChannel(\test1, s, 1, 2, outbus: ~master);
n = MixerChannel(\test2, s, 2, 2, outbus: ~master);
m => MCG(0); n => MCG(1);

[m, n].do { |ch|
	ch.sendsSignalTo(~glrvbmc);
	ch.sendsSignalTo(~lcrvbmc);
};
)


[~glrvb, ~lcrvb].do(_.run(false));
[~glrvb, ~lcrvb].do(_.run(true));

PeakMonitor(~master)

b.free;
b = Buffer.readAndQuery(s, topEnvironment[\feetdir].dirname +/+ "samples/feet/58454_sinatra314_footsteps_wooden_floor_loop.wav");

~pt = TabFileReader.read(b.path.dirname +/+ "58454_labels.txt");
~pt = ~pt.flop[0].asFloat;
~ptd = ~pt.differentiate.drop(1);
~mean = ~ptd.mean;

c.free;
c = Buffer.readAndQuery(s, b.path.splitext[0] ++ "-pv512.aiff");
f = 512;
c = Buffer.alloc(s, b.duration.calcPVRecSize(f, 0.25));

a = {
	var	sig = PlayBuf.ar(1, b, BufRateScale.kr(b), 1, 0, 0),
		fft = FFT(LocalBuf(f, 1), sig, 0.25, 1),
		stop = Line.kr(0, 1, b.duration, doneAction: 2);
	PV_RecordBuf(fft, c, run: 1, hop: 0.25, wintype: 1);
	stop.poll(Done.kr(stop), "over");
	Silent.ar(1)
}.play;

c.write(b.path.splitext[0] ++ "-pv512.aiff", sampleFormat: "float");


~xys = { Bus.control(s, 2) } ! 10;
~xys = ~xys.collect(SharedBus.newFrom(_, \me));

WrapInstr("xy", { |distNear = 5, distFar = 20, mul = 0.25, send = 0|
	var	theta, r, x, y;
	theta = DemandEnvGen.kr(
		Dwhite(-2pi, 2pi, inf),
		Dwhite(0.25, 0.9, inf),
		Env.shapeNumber(\sine)
	);
	r = DemandEnvGen.kr(
		Dwhite(0.1, 1.0, inf),
		Dwhite(0.0, 1.0, inf).linexp(0, 1, 0.6, 2.0),
		Env.shapeNumber(\sine)
	);
	x = theta.cos * r;
	y = theta.sin * r;
	x = x * mul;
	y = (y * mul).linlin(-1, 1, distNear, distFar);
	SendReply.kr(send * Impulse.kr(10), "/xy", [x, y]);
	[x, y]
}, [#[1, 50], #[1, 50], #[0.01, 1.0, \exp]]);


~xysynths = ~xys.collect { |xybus|
	WrapPatch("xy", [5, 20, 1, `0]).play(bus: xybus)
};

~xymaps = ~xys.collect({ |bus| [bus.asMap, ("c" ++ (bus.index+1)).asSymbol] });



// start: fast + stretched steps
SynthDescLib.at(\pvplayStereoDist).controls.do(_.postln); ""

Pdefn(\pan, Pwhite(-1.0, 1.0, inf));
Pdefn(\distance, Pwhite(5.0, 20.0, inf));
Pdefn(\rate, Pexprand(0.05, 1.0, inf));
//Pdefn(\rate, Pswitch1([Pexprand(0.05, 0.2, inf), Pexprand(0.6, 1.2, inf)], Pwrand(#[0, 1], #[0.3, 0.7], inf)));
Pdefn(\time, 0.25 / Pkey(\rate));
Pdefn(\decay, Pkey(\time) * 0.14);
Pdefn(\amp, 15.dbamp); // Pwhite(0, 5, inf).dbamp
Pdefn(\delta, Pkey(\time) * Ptempo() * Pwhite(0.3, 0.6, inf));

Pdefn(\delta, Ptempo() * max(Pwhite(0.3, 0.6, inf) * Pseq([
	Pn(1, { rrand(2, 5) }),
	Pexprand(0.05, 0.2, { rrand(8, 14) })
], inf), Pkey(\time) * 0.1));

Pdefn(\shiftS, Pwhite(8, 30, inf));
Pdefn(\shiftE, Pkey(\shiftS) * Pwhite(0.1, 0.4, inf));


z = 5;
a = n.play(Ptpar([
	0, Pbind(
		\instrument, \pvplayStereoDist,
		\pvbuf, c,
		\rate, Pgeom.fromEndpoints(1, 0.02, z),
		\time, 0.25 * Pkey(\rate).reciprocal,
		\decay, Pkey(\time) * 0.14,
		\amp, 5.dbamp,
		//	\n, 3,
		\pt, Pn(Pshuf(~pt, 1), inf),
		\startFrame, Pkey(\pt) * (((c.numFrames - 3) / 512) / b.duration),
		\pan, Pstutter(2, Pseries.fromEndpoints(-1.0, 0, (z * 0.5).roundUp.asInteger))
			* Pseq(#[1, -1], inf, { 2.rand }),
		\distance, Pseries.fromEndpoints(15, 5, z),
		\glrvbout, ~glrvbmc.inbus, \glrvbamt, 0.3,
		\lcrvbout, ~lcrvbmc.inbus,
		\delta, 0 // Pkey(\time) * Ptempo() * Pwhite(0.75, 0.9, inf)
	),
	{ rrand(0.5, 2.0) }, Pbind(
		\instrument, \pvplayStereoDist,
		\distNear, 5, \distFar, 20,
		\glrvbout, ~glrvbmc.inbus,
		\lcrvbout, ~lcrvbmc.inbus,
		\pvbuf, c,
		\pt, Pn(Pshuf(~pt, 1), inf),
		\startFrame, Pkey(\pt) * (((c.numFrames - 3) / 512) / b.duration),
		#[pan, distance], Pseq(~xymaps, inf),
		\shiftS, Pdefn(\shiftS),
		\shiftE, Pdefn(\shiftE),
		\rate, Pdefn(\rate),
		\time, Pdefn(\time),
		\decay, Pdefn(\decay),
		\amp, Pdefn(\amp),
		\delta, Pdefn(\delta)
	)//.trace(prefix: $\n)
]));

a.stop;

f = SoundFile.openRead(Document.current.path.dirname.dirname +/+ "samples/feet/58454_sinatra314_footsteps_wooden_floor_loop-pv512.aiff");

BP(\op).maxSynths = 8;

(
Proto {
	~numSynths = 10;
	~prep = {
		~group = Group.before(s.asTarget);

		SynthDef("xy1", { |distNear = 5, distFar = 20, mul = 0.25, send = 0, out = 0|
			var	theta, r, x, y;
			theta = DemandEnvGen.kr(
				Dwhite(-2pi, 2pi, inf),
				Dwhite(0.25, 0.9, inf),
				Env.shapeNumber(\sine)
			);
			r = DemandEnvGen.kr(
				Dwhite(0.1, 1.0, inf),
				Dwhite(0.0, 1.0, inf).linexp(0, 1, 0.6, 2.0),
				Env.shapeNumber(\sine)
			);
			x = theta.cos * r;
			y = theta.sin * r;
			x = x * mul;
			y = (y * mul).linlin(-1, 1, distNear, distFar);
			SendReply.kr(send * Impulse.kr(10), "/xy", [x, y]);
			Out.kr(out, [x, y]);
		}, #[\ir, \ir]).add;

		~xys = { Bus.control(s, 2) } ! ~numSynths;
		~xymaps = ~xys.collect({ |bus| [bus.asMap, ("c" ++ (bus.index+1)).asSymbol] });
		~clients = IdentitySet.new;
	};

	~freeCleanup = {
		[~group, ~xys].free;
	};

	~makeSynths = {
		~xysynths ?? {
			~xysynths = ~xys.collect { |xybus|
				Synth(\xy1, [mul: 1, send: 0, out: xybus], ~group);
			}
		};
	};

	~removeSynths = {
		~xysynths !? {
			~xysynths.do(_.free);
			~xysynths = nil;
		};
	};

	~isUsedBy = { |name|
		if(~clients.includes(name)) {
			"% is already used by %.".format(~collIndex, name).warn
		} {
			~clients.add(name);
			~makeSynths.();
		}
	};

	~notUsedBy = { |name|
		~clients.remove(name);
		if(~clients.isEmpty) {
			~removeSynths.()
		}
	};
} => PR(\trajectories);
)

BP(\traj).free;
PR(\trajectories) => BP(\traj);

(
(
keys: #[master, glrvbmc, lcrvbmc],
make: { |name|
	BP(name).free;
	PR(\basicSynthChooser).chuck(BP(name), nil, (
		event: (eventKey: \singleSynthPlayNotify),
		sfpath: topEnvironment[\feetdir].dirname +/+ "samples/feet/58454_sinatra314_footsteps_wooden_floor_loop.wav",
		pvpath: topEnvironment[\feetdir].dirname +/+ "samples/feet/58454_sinatra314_footsteps_wooden_floor_loop-pv512.aiff",
		inChannels: 2,
		master: ~master,
		glrvbmc: ~glrvbmc,
		lcrvbmc: ~lcrvbmc,
		requiredKeys: #[readyToPlay],
		readyToPlay: nil,
		alwaysReset: true,
		numSplashEv: 5,
		maxSynths: 8,
		trajectoryKey: \traj,
		initAmp: 0.36,
		userprep: {
			var	sf;

			[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\receivesSignalFrom, ~chan));

			~pvbuf = Buffer.readAndQuery(s, ~pvpath.standardizePath, completionFunc: e {
				~pvbuf.getn(0, 3, e { |val|
					~fftSize = val[0];
					~hop = val[1];
					~winType = val[2];
					~numPvFrames = (~pvbuf.numFrames - 3) / ~fftSize;
					// [~fftSize, ~hop, ~winType, ~numPvFrames].debug("pv specs");
					~readyToPlay = true;
				});
			});
			if((sf = SoundFile.openRead(~sfpath.standardizePath)).notNil) {
				~sfdur = sf.duration;
			} {
				"Couldn't get duration from %. ~sfdur remains empty.".format(~sfpath).warn;
			};
			~readLabels.();
			~activeSynths = IdentitySet.new;
			~ampCtl = GenericGlobalControl(\amp, nil, ~initAmp, \amp);
		},
		useGui: { |vpi| ~ampCtl => VP(vpi) },
		userfree: {
			[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\stopsReceivingFrom, ~chan));
			[~pvbuf, ~ampCtl].free;
		},
		preparePlay: {
			BP(~trajectoryKey).isUsedBy(~collIndex);
		},
		recvEventNotify: { |node|
			var	self, ufunc;
			if(node.isKindOf(Synth)) {
				self = currentEnvironment;
				ufunc = { |obj, what|
					if(what == \n_end) {
						obj.removeDependant(ufunc);
						self[\activeSynths].remove(obj);
						if(self[\isPlaying].not and: { self[\activeSynths].isEmpty }) {
							BP(self[\trajectoryKey]).notUsedBy(self.collIndex);
						};
					}
				};
				~activeSynths.add(node);
				NodeWatcher.register(node);
				node.addDependant(ufunc);
			};
		},
		synth: \pv,
		objects: (
			pv: (
				def: \pvplayStereoDist,
				args: [
					distNear: 5, distFar: 20,
					glrvbout: ~glrvbmc.inbus,
					lcrvbout: ~lcrvbmc.inbus,
					pvbuf: Plazy { ~pvbuf.asPattern },
					pt: Plazy { Pn(Pshuf(~pt, 1), inf) },
					startFrame: Plazy { Pkey(\pt) * (~numPvFrames / ~sfdur) },
					#[pan, distance]: Plazy { Pseq(BP(~trajectoryKey).xymaps, inf) },
					shiftS: Pif(Ptime() <= 36, Pwhite(8, 30, inf) * Env(#[1, 0], #[36], \lin)),
// 					shiftS: Pwhite(8, 30, inf) * Pseg(
// 						Pseq([1, 0, Ppatlace([Pwhite(0.2, 0.6, inf), 0], inf)], inf),
// 						Pseq([20, Pwrand([Pwhite(4.0, 8.0, 1), Pwhite(0.2, 0.6, 1)], #[0.8, 0.2], inf)]),
// 						\lin
// 					),
					shiftE: Pkey(\shiftS) * Pwhite(0.1, 0.4, inf),
					rate: Pif(Pwhite(0.0, 1.0, inf) < 0.1, Pwhite(0.05, 0.09, inf), Pexprand(Env(#[0.05, 1], #[90], \exp), 1.0, inf)),
// 					rate: Pexprand(Env(#[0.05, 1], #[90], \exp), 1.0, inf),
					time: 0.25 / Pkey(\rate),
					decay: Pkey(\time) * 0.14,
					amp: Pif(Pkey(\rate) < 0.1, 4, 1) * Env([0, 2, 2, 0], #[3, 26, 7], #[2.1, 0, -2.1]),
					ampMap: Plazy { Pn(~ampCtl.asMap, inf) },
// 					amp: Env(#[0, 2, 2, 0], #[3, 26, 7], #[2.1, 0, -2.1]),
					delta: Ptempo() * max(Pwhite(0.3, 0.6, inf) * Pseq([
						Pn(1, { rrand(2, 5) }),
						Pexprand(0.05, 0.2, { rrand(8, 14) })
					], inf), Pkey(\time) * 0.1),
					instrument: Pfunc { |ev|
						if(~activeSynths.size < ~maxSynths) { ev[\instrument] } { \rest }
					}
				]
			)
		),
		superPattern: PR(\basicSynthChooser).v[\asPattern],
		splashPattern: {
			Pbind(
				\instrument, \pvplayStereoDist,
				\pvbuf, ~pvbuf,
				\rate, Pgeom.fromEndpoints(1, 0.02, ~numSplashEv),
				\time, 0.6 / Pkey(\rate),
				\decay, Pkey(\time) * 0.14,
				\amp, 12.dbamp, //BPStream(\pvamp),
				\ampMap, ~ampCtl.asMap,
				\pt, Pn(Pshuf(~pt, 1), inf),
				\startFrame, BPStream(\pvstartFrame),
				\pan, Pstutter(2, Pseries.fromEndpoints(-1.0, 0, (~numSplashEv * 0.5).roundUp.asInteger))
				* Pseq(#[1, -1], inf, { 2.rand }),
				\distance, Pseries.fromEndpoints(15, 5, ~numSplashEv),
				\glrvbout, ~glrvbmc.inbus, \glrvbamt, 0.3,
				\lcrvbout, ~lcrvbmc.inbus,
				\chan, ~chan,
				\delta, 0
			)
		},
		asPattern: {
			Pseq([
				~splashPattern.(),
				Event.silent(rrand(0.15, 0.45)),
				~superPattern.()
			])
		},
		processLabels: PR(\steps1).v[\processLabels],
		readLabels: {
			~pt = TabFileReader.read(~sfpath.dirname +/+ ~sfpath.basename[.. ~sfpath.basename.indexOf($_)]
				++ "labels.txt");
			~processLabels.();
		},
		reset: {
			var	str;
			currentEnvironment.env.keys.do { |key|
				if((str = key.asString).contains("Stream")) {
					~makeStreamForKey.(str[ .. str.size - 7].asSymbol);
				}
			}
		}
	));
	0 => BP(name);
}, type: \bp) => Fact(\opening);
)


o = OSCresponderNode(s.addr, '/n_go', { |t, r, m|
	r.remove;
	Synth.basicNew(\dummy, s, m[1]).trace
}).add;

Pdefn(\speed, Pexprand(0.1, 1.2, inf));
Pdefn(\numev, Pfunc { |speed| (speed.linlin(0.1, 1.2, 12, 4) * rrand(0.7, 1.4)).round.asInteger });

Pdefn(\pan, Pn(
	Plazy { |ev|
		Pseries.fromEndpoints(rrand(-1.0, -0.2), rrand(0.2, 1.0), ev[\numev]) * #[-1, 1].choose
	},
	inf
));
Pdefn(\distance, Pn(
	Plazy { |ev|
		Pseries.fromEndpoints(0, 1, ev[\numev]).linlin(0, 1, rrand(5.0, 20.0), rrand(5.0, 20.0))
	},
	inf
));
Pdefn(\rate, Plazy { |ev|
	Pn(ev[\speed].linexp(0.1, 1.2, 1, 0.04), inf)
});
Pdefn(\delta, Plazy { |ev|
	Pexprand(0.7, 1.5, inf) * ev[\speed] * 0.25
});

a = n.play(
	Ppar([
		Pbind(
			\instrument, \pvplayStereoDist,
			\pvbuf, c,
			\rate, Pgeom.fromEndpoints(1, 0.02, z),
			\time, 0.25 * Pkey(\rate).reciprocal,
			\decay, Pkey(\time) * 0.14,
			\amp, 5.dbamp,
			\pt, Pn(Pshuf(~pt, 1), inf),
			\startFrame, Pkey(\pt) * (((c.numFrames - 3) / 512) / b.duration),
			\pan, Pstutter(2, Pseries.fromEndpoints(-1.0, 0, (z * 0.5).roundUp.asInteger))
				* Pseq(#[1, -1], inf, { 2.rand }),
			\distance, Pseries.fromEndpoints(15, 5, z),
			\glrvbout, ~glrvbmc.inbus, \glrvbamt, 0.4,
			\lcrvbout, ~lcrvbmc.inbus,
			\delta, 0 // Pkey(\time) * Ptempo() * Pwhite(0.75, 0.9, inf)
		),
		Pspawner({ |sp|
			var	speed, numev,
				speedStrm = Pdefn(\speed).asStream, numevStrm = Pdefn(\numev).asStream;
			loop {
				sp.wait(exprand(0.3, 1.2));
				speed = speedStrm.next;
				numev = numevStrm.next(speed);
				sp.seq(Pbind(
					\instrument, \pvplayStereoDist,
					\distNear, 5, \distFar, 20,
					\speed, speed, \numev, numev,
					\glrvbout, ~glrvbmc.inbus,
					\lcrvbout, ~lcrvbmc.inbus,
					\pvbuf, c,
					\pt, Pfin(numev, Pn(Pshuf(~pt, 1), inf)),
					\startFrame, Pkey(\pt) * (((c.numFrames - 3) / 512) / b.duration),
					*[[
						\pan,
						\distance,
						\rate,
						\time,
						\decay,
						\amp,
						\delta
					], [
						Pdefn(\pan).source,
						Pdefn(\distance).source,
						Pdefn(\rate).source,
						Pdefn(\time).source,
						Pdefn(\decay).source,
						Pdefn(\amp).source,
						Pdefn(\delta).source
					]].flop.flat)
				);
			};
		})
	])
);

a.stop;

();
BP(\op).use {
//	~pvshiftS = Pwhite(8, 30, inf) * Env(#[1, 0], #[24], \lin);
	~pvshiftS = Pwhite(8, 30, inf) * Pseg(
		Pseq([1, 0, Ppatlace([Pwhite(0.2, 0.6, inf), 0], inf)], inf), //.trace(prefix: "shift endpoint: "),
		Pseq([20, Pwrand([Pwhite(4.0, 8.0, 1), Pwhite(0.2, 0.6, 1)], #[0.8, 0.2], inf)], 1),
		\lin
	);
	~pvshiftE = Pkey(\shiftS) * Pwhite(0.1, 0.4, inf);
	~pvrate = Pexprand(Env(#[0.05, 1], #[90], \exp), 1.0, inf);
	~pvamp = Env([0, 2], #[3], 2.1);
};

BP(\op).pvshiftS.postcs
BP(\op).pvrate.postcs

BP(\op).pvshiftS = Pif(Ptime() <= 36, Pwhite(8, 30, inf) * Env(#[1, 0], #[36], \lin));
BP(\op).pvamp = Env([0, 2, 2, 0], #[3, 26, 7], #[2.1, 0, -2.1]);

// play with rate to get this condition to fire more often
BP(\op).pvrate = Pif(Pwhite(0.0, 1.0, inf) < 0.1, Pwhite(0.05, 0.09, inf), Pexprand(Env(#[0.05, 1], #[90], \exp), 1.0, inf));
BP(\op).pvamp = (Pif(Pkey(\rate) < 0.1, 4, 1) * Env([0, 2, 2, 0], #[3, 26, 7], #[2.1, 0, -2.1]));

BP(\op).pvinstrument = Pfunc({ |ev|
	if(ev[\rate] < 0.1 and: { ~activeSynths.size < ~maxSynths }) { ev[\instrument] } { \rest }
});

BP(\op).pvinstrument = Pfunc({ |ev|
	if(~activeSynths.size < ~maxSynths) { ev[\instrument] } { \rest }
});


BP(\op).splashPattern = { Event.silent(0) };

BP(\op).splashPattern = {
		Pbind(
			\instrument, \pvplayStereoDist,
			\pvbuf, ~pvbuf,
			\rate, Pgeom.fromEndpoints(1, 0.02, ~numSplashEv),
			\time, 0.6 / Pkey(\rate),
			\decay, Pkey(\time) * 0.14,
			\amp, 12.dbamp, //BPStream(\pvamp),
			\pt, Pn(Pshuf(~pt, 1), inf),
			\startFrame, BPStream(\pvstartFrame),
			\pan, Pstutter(2, Pseries.fromEndpoints(-1.0, 0, (~numSplashEv * 0.5).roundUp.asInteger))
				* Pseq(#[1, -1], inf, { 2.rand }),
			\distance, Pseries.fromEndpoints(15, 5, ~numSplashEv),
			\glrvbout, ~glrvbmc.inbus, \glrvbamt, 0.3,
			\lcrvbout, ~lcrvbmc.inbus,
			\chan, ~chan,
			\delta, 0
		)
	};

t = TLSequenceIterator([
	{ ~master.startRecord(thisProcess.platform.recordingsDir +/+ "steps-clatter.aiff");
		1
	},
	bpCmd: (name: \st, dur: 45),
	\cmdSync,
	2,
	{ ~master.stopRecord; 0 }
]).play;


Error.debug = true;
Server.default.queryAllNodes;

o.remove;

// need to borrow pvbuf from opening
Fact(\opening) => BP(\op);

(
BP(\st).free;
PR(\basicBufferPlayer).chuck(BP(\st), nil, (
	event: (eventKey: \singleSynthPlayer, instrument: \bufGrainPanFiltDist),
	alwaysReset: true,

	bufPaths: [topEnvironment[\feetdir].dirname +/+ "samples/feet/58454_sinatra314_footsteps_wooden_floor_loop.wav"],
	pvSource: \op,

	inChannels: 2,
	master: ~master,
	glrvbmc: ~glrvbmc,
	lcrvbmc: ~lcrvbmc,

	autoRun: true,

	gest: Pfunc { ~gestures.keys.choose },
	initAmp: 0.3,

	early: 0.1,
	buf: 0,
	ptIndex: Plazy { Pwhite(0, ~pt.size-2, inf) },
	start: Pfunc { |ev|
		(~pt[ev[\pt]] - (~early * ev[\rate])) * ~buffers[ev[\bufIndex]].sampleRate
	},
	time: 0.4,
	rate: Pexprand(0.9, 1.7, inf),
	ffreq: 18000,
	fastDelta: Pexprand(0.08, 0.3, inf),
	amp: 7.dbamp,
	numEv: Pwhite(5, 12, inf),
	gDelta: Pwhite(0.5, 2.5, inf),
	distNear: 5,
	distFar: 20,

	kfreq: Pexprand(300, 800, inf),
	kdecay: Pexprand(0.01, 0.1, inf),
	kamp: 1,

	postMCCreation: { |chan|
		[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\receivesSignalFrom, ~chan));

		~ampCtl = GenericGlobalControl(\amp, nil, ~initAmp, \amp);
		~event.putAll((
			// just in case reverb channels don't exist,
			// push them to hw input buses (to suppress output)
			glrvbout: ~glrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels },
			lcrvbout: ~lcrvbmc.tryPerform(\inbus) ?? { s.options.numOutputBusChannels },
			chan: ~chan,
			ampMap: ~ampCtl.asMap
		));
		~readLabels.();

		if(BP.exists(~pvSource)) {
			#[pvbuf, fftSize, hop, numPvFrames].do { |key|
				key.envirPut(BP(~pvSource)[key]);
			}
		} {
			"BP(%) not found; can't use any pv gestures.".format(~pvSource.asCompileString).warn
		};
	},
	useGui: { |vpi| ~ampCtl => VP(vpi) },
	free: {
		[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\stopsReceivingFrom, ~chan));
		~ampCtl.free;
	},
	stopCleanup: {
		~spawner = nil
	},

	// external hook to drop a gesture in!
	runGesture: { |parms|
		if(~isPlaying) {
			parms ?? { parms = () };
			parms[\gest] ?? { parms[\gest] = ~gestStream.next };
			if(parms[\gest].notNil) {
				parms[\numEv] ?? { parms[\numEv] = ~numEvStream.next };
				~spawner.par(~makeGesture.(parms))
			} {
				"BP(%): runGesture failed; gesture is empty and ~gest pattern ended.\n"
				.postf(~collIndex.asCompileString);
			};
		} {
			"BP(%) is not playing, can't run a gesture".format(~collIndex.asCompileString).warn;
		};
	},

	makeGesture: { |parms|
		Pchain(
			~gestures[parms[\gest]].value(parms),
			~baseValuePat.value(parms),
			(parms: parms)
		)
	},

	// more later
	xyPat: { |parms|
		Ptuple([
			Pseries.fromEndpoints(rrand(-1.0, 0.2), rrand(0.2, 1.0), parms[\numEv]) * #[-1, 1].choose,
			Pseries.fromEndpoints(rrand(~distNear, ~distFar), rrand(~distNear, ~distFar),
				parms[\numEv])
		])
	},

	gestures: (
		clatter: { |parms|
			Pbind(
				#[pan, distance], ~xyPat.(parms),
				\delta, BPStream(\fastDelta),
				\amp, BPStream(\amp)
			)
		},
		oneKlank: { |parms|
			Pbind(
				\instrument, Pn(\bufGrainPanKlankDist, 1),
				#[pan, distance], parms[\xy] ?? {
					[rrand(-1.0, 1.0), rrand(~distNear, ~distFar)]
				},
				\delta, 0.5,
				\amp, BPStream(\amp),
				\filtFreq, BPStream(\kfreq),
				\filtAttack, 0.01,
				\filtDecay, BPStream(\kdecay),
				\filtAmp, BPStream(\kamp),
// 				\chorusFreq, 
// 				\chorusAmt, 
// 				\chorusDelay, 
//				\ffreq, 
//				\lprq, 
//				\harm, 
//				\amps, 
//				\decays, 
				\chorusAmps, #[0, 0, 0]
			)
		},
		oneKlankSteps: { |parms|
			Pbind(
				\instrument, Pseq([\bufGrainPanKlankDist, Pkey(\instrument)], 1),
				#[pan, distance], ~xyPat.(parms),
				\delta, BPStream(\fastDelta),
				\amp, BPStream(\amp),
				\filtFreq, BPStream(\kfreq),
				\filtAttack, 0.01,
				\filtDecay, BPStream(\kdecay),
				\filtAmp, BPStream(\kamp),
				\chorusAmps, #[0, 0, 0]
			)
		}
	),

	asPattern: {
		~numEvStream ?? { ~makeStreamForKey.(\numEv) };
		~gDeltaStream ?? { ~makeStreamForKey.(\gDelta) };
		~gestStream ?? { ~makeStreamForKey.(\gest) };
		Pspawner { |sp|
			~spawner = sp;
			if(~autoRun) {
				"BP(%): autoRun enabled\n".postf(~collIndex.asCompileString);
				loop {
					~runGesture.();
					sp.wait(~gDeltaStream.next());
				}
			} {
				loop {
					sp.wait(0.1);
				}
			}
		}
	},
	baseValuePat: {
		Pbind(
			\distNear, Pfunc { ~distNear },
			\distFar, Pfunc { ~distFar },
			\bufIndex, Plazy { BPStream(\buf) },
			\bufnum, Pfunc { |ev| ~buffers[ev[\bufIndex]].bufnum },
			\pt, Plazy { BPStream(\ptIndex) },
			\rate, Plazy { BPStream(\rate) },
			\start, Plazy { BPStream(\start) },
			\time, Plazy { BPStream(\time) },
			\ffreq, Plazy { BPStream(\ffreq) } //,
//			\amp, Plazy { BPStream(\amp) }
		)
	},
	processLabels: PR(\steps1).v[\processLabels],
	readLabels: {
		~pt = TabFileReader.read(~bufPaths[0].dirname
			+/+ ~bufPaths[0].basename[.. ~bufPaths[0].basename.indexOf($_)]
			++ "labels.txt");
		~processLabels.();
	}
));
0 => BP(\st);
)

BP(\st).gest = \oneKlank;
BP(\st).gest = \oneKlankSteps;
BP(\st).event.put(\glrvbout, s.options.numOutputBusChannels).put(\lcrvbout, s.options.numOutputBusChannels);

BP(\st).free = {
	[~glrvbmc, ~lcrvbmc].do(_.tryPerform(\stopsReceivingFrom, ~chan));
	~ampCtl.free;
};

BP(\st).v[\free].postcs

o = OSCresponderNode(s.addr, '/n_go', { |t, r, m|
	r.remove;
	Synth.basicNew(\dummy, s, m[1]).trace
}).add;

BP(\st).fastDelta = Pexprand(0.08, 0.3, inf);
BP(\st).amp = 7.dbamp;
BP(\st).gDelta = Pwhite(0.5, 2.5, inf);

BP(\st).xyPat = { |parms|
		Ptuple([
			Pseries.fromEndpoints(rrand(-1.0, 0.2), rrand(0.2, 1.0), parms[\numEv]) * #[-1, 1].choose,
			Pseries.fromEndpoints(rrand(~distNear, ~distFar), rrand(~distNear, ~distFar),
				parms[\numEv])
		])
	};

BP(\st).autoRun = false;
BP(\st).autoRun = true;

Proto {
	~doAction = {
		BP(\st).runGesture;
	}
} => BP(\run);
0 => BP(\run);

SynthDescLib.at(\bufGrainPanKlankDist).controls.do(_.postln); ""
SynthDescLib.at(\bufGrainPanFiltDist).controls.do(_.postln); ""
BP(\st).event.instrument

// bit boring
BP(\st).slowDelta = Pn(Plazy { |ev| Pn(rrand(0.3, 0.6), ev[\parms][\numEv] ? 1) }, inf);
BP(\st).slowRate = Pwhite(0.6, 0.8, inf);
BP(\st).gestures.slowSteps = { |parms|
	Pbind(
		\instrument, \pvplayPanDist,
		\pvbuf, ~pvbuf,
		\startFrame, Pkey(\start) / ~buffers[0].numFrames * ~numPvFrames,
		#[pan, distance], ~xyPat.(parms),
		\delta, BPStream(\slowDelta),
		\rate, BPStream(\slowRate),
		\time, Pkey(\delta),
		\amp, BPStream(\amp),
		\shiftS, rrand(-15, -4, inf),
		\shiftE, Pkey(\shiftS)
	)
};
BP(\st).gest = \slowSteps;
BP(\st).numEv = Pwhite(3, 5, inf);
BP(\st).gDelta = Pwhite(2.5, 4.0, inf);