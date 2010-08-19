// todo:
// then do running across the floor

// video notes:
// keep sparse at first
// turning backstage to launch new variations
// what is the pitch theme?
// straight line vs curved
// parallel vs crossing paths
// track fwd/back position of dancers for 'distance' parm?

BP.all.free;

s.options.preferredDeviceFunc_(nil).device_("Aggregate Device");
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

//(BP(\op).sfpath.dirname +/+ "58454_labels.txt").openDocument

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
		readLabels: PR(\steps1).v[\readLabels],
		labelPath: {
			~sfpath.dirname +/+ ~sfpath.basename[.. ~sfpath.basename.indexOf($_)] ++ "labels3.txt"
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
	event: (eventKey: \polySynthPlayer, instrument: \bufGrainPanFiltDist),
	alwaysReset: true,

	bufPaths: [topEnvironment[\feetdir].dirname +/+ "samples/feet/58454_sinatra314_footsteps_wooden_floor_loop.wav"],
	pvSource: \op,

	inChannels: 2,
	master: ~master,
	glrvbmc: ~glrvbmc,
	lcrvbmc: ~lcrvbmc,

	autoRun: true,

	gest: Pfunc { ~gestures.keys.choose },
	defaultParms: nil,
	initAmp: 0.3,

	early: 0.1,
	buf: 0,
	ptIndex: Plazy { Pwhite(0, ~pt.size-2, inf) },
	start: Pfunc { |ev|
		(~pt[ev[\pt]] - ((ev[\early] ?? { ev[\parms][\early] ?? { ~early } }) * ev[\rate]))
			* ~buffers[ev[\bufIndex]].sampleRate
	},
	time: 0.4,
	rate: Pexprand(0.9, 1.7, inf),
	ffreq: 18000,
	fastDelta: Pexprand(0.08, 0.3, inf),
	amp: Pindex(Pfunc { |ev|
		var	early = ev[\early] ?? { ev[\parms][\early] ?? { ~early } };
		~peaks[(early <= 0).binaryValue]
	}, Pfin(1, Pkey(\pt)), inf).reciprocal, //.trace(prefix: "amp: "),
	numEv: Pwhite(5, 12, inf),
	gDelta: Pwhite(0.5, 2.5, inf),
	distNear: 5,
	distFar: 20,

	slowDelta: Pn(Plazy { |ev| Pn(rrand(0.3, 0.6), ev[\parms][\numEv] ? 1) }, inf),
	slowRate: Pwhite(0.5, 0.8, inf),
	slowShift: Pexprand(1, 15, inf) - 3,

//	kfreq: Pseq(#[74, 79, 78], inf).trace(prefix: "kfreq: ").midicps,
	rewriteEmbedder: { |int, in, level|
		if(int.every(_.inclusivelyBetween(-16, 16))) {
			Ptuple([
				Pseq(int, 1),
				Pseq([in[1], Pn(level+1, inf)], 1)
			], 1)
		} {
//			[int, level].debug("dropped");
			Pn([0, 0], 0)	// <-- drop this branch totally
		}
	},
	kfreq: //Pcollect({ |pair| pair.copy.put(0, Mode(\g).cps(pair[0] + 35)) },
		// w/o Plazy, rewriteEmbedder would come from the wrong environment
		Plazy {
			PR(\rewriter).copy.prep(Ptuple([Pseq([4, 7, 6], 1), 1], 1), Pseries(0, 1, inf), [
				{ |in| in[0] < 0 } -> { |in, level|
					var int = if(0.5.coin) { #[3, -1] /*.debug(">>> add motive")*/ }
						{ { #[-1, 1, 2, 3].choose } ! rrand(1, 3) };
					~rewriteEmbedder.(([in[0]] ++ int).integrate, in, level);
				},
				{ |in| in[0] > 10 } -> { |in, level|
					var int = if(0.5.coin) { #[-3, 1] /*.debug(">>> add motive")*/ }
						{ { #[-3, -2, -1, 1].choose } ! rrand(1, 3) };
					~rewriteEmbedder.(([in[0]] ++ int).integrate, in, level);
				},
				{ true } -> { |in, level|
					var int = if(0.45.coin) { #[[-3, 1], [3, -1]].choose/*.debug(">>> add motive")*/ }
						{ { #[-2, -1, 1, 2].choose } ! rrand(1, 3) };
					~rewriteEmbedder.(([in[0]] ++ int).integrate, in, level);
				}
			]).keepLowerLevels_(true).rewriteEmbedder_(~rewriteEmbedder)
		}
	/*)*/,
	nextLowerInt: Pseries({ rrand(1, 3) }, Prand(#[-2, -1, 1, 2], inf), inf)
		.fold(-10, 10).reject { |x, ev| x >= ev[\filtDegree] } - Pkey(\filtDegree),
	chordInt: Pwhite(-3, -1, inf),
	chordN: 0,
	kdecay: Pexprand(0.011, 0.1, inf),
	kamp: 1,
	defaultKlankHarm: (1..5),
	defaultKlankAmps: (1..5).reciprocal,
	defaultKlankDecays: 1 ! 5,
	defaultChorusAmps: (1..3).reciprocal * 0.3,

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

	xyPat: { |parms|
		Ptuple([
			if(parms[\xEnds].notNil) {
				Pseries.fromEndpoints(*(parms[\xEnds] ++ parms[\numEv]))
			} {
				Pseries.fromEndpoints(
					rrand(-1.0, 0.2), rrand(0.2, 1.0), parms[\numEv]
				) * #[-1, 1].choose
			},
			if(parms[\yEnds].notNil) {
				Pseries.fromEndpoints(*(parms[\yEnds] ++ parms[\numEv]))
			} {
				Pseries.fromEndpoints(rrand(~distNear, ~distFar), rrand(~distNear, ~distFar),
					parms[\numEv]
				)
			}
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
// 				#[pan, distance], parms[\xy] ?? {
// 					[rrand(-1.0, 1.0), rrand(0.1, 0.5).linlin(0, 1, ~distNear, ~distFar)]
// 				},
				\delta, 0.5,
				\amp, BPStream(\amp),
				#[filtDegree, level], BPStream(\kfreq),
				\filtFreq, Pkey(\filtDegree).collect { |deg| Mode(\g).cps(deg + 35) },
				\filtAttack, 0.01,
				\filtDecay, BPStream(\kdecay),
				\filtAmp, BPStream(\kamp),
				\chorusFreq, parms[\chorusFreq] ?? { Pstutter(inf, Pwhite(0.05, 0.11, inf)) },
				\chorusAmt, parms[\chorusAmt] ?? { 0.02 },
				\chorusDelay, parms[\chorusDelay] ?? { 0.03 },
				\chorusAmps, parms[\chorusAmps] ?? { [~defaultChorusAmps] },
				\harm, parms[\harm] ?? { [~defaultKlankHarm] },
				\amps, parms[\amps] ?? { [~defaultKlankAmps] },
				\decays, parms[\decays] ?? { [~defaultKlankDecays] },
				\pan, rrand(-1.0, 1.0),
				\distance, Pkey(\level).linlin(1, 6, ~distNear, ~distFar)
			)
		},
		klankHarmonize: { |parms|
			Pbind(
				\nextLower, BPStream(\nextLowerInt),
				\chord, Pclump(BPStream(\chordN), BPStream(\chordInt)),
				\filtFreq, Ptuple([Pkey(\filtDegree), Pkey(\nextLower), Pkey(\chord)], inf)
					.collect { |item| Mode(\g).cps(item.flat.integrate + 35) }
			)
			<> ~gestures[\oneKlank].(parms)
		},
		oneKlankSteps: { |parms|
			Pseq(
				#[oneKlank, clatter].collect { |key| ~gestures[key].(parms) },
				1
			)
		},
		klankHrmSteps: { |parms|
			Pseq(
				#[klankHarmonize, clatter].collect { |key| ~gestures[key].(parms) },
				1
			)
		},
		decay: { |parms|
			parms[\numEv] = rrand(18, 28);
			parms[\yEnds] = [rrand(0.3, 0.4), rrand(0.75, 1.0)].linlin(0, 1, ~distNear, ~distFar);
			Pbind(
				#[pan, distance], ~xyPat.(parms),
				\early, 0,
				\pt, Pstutter(inf, BPStream(\ptIndex).reject(#[3, 10, 14].includes(_))),
				\start, Pstutter(inf, BPStream(\start)),
				\delta, rrand(0.06, 0.09),//.debug("decay delta"),
				\time, Pkey(\delta) * rrand(1.75, 2.2), //rrand(0.6, 0.8),
				\rate, Pstutter(inf, Pkey(\rate)),
				\amp, Pstutter(inf, BPStream(\amp)) / Pindex(~ampCorrections, Pkey(\pt), inf)
					* Pgeom.fromEndpoints(1, -25.dbamp, parms[\numEv]) * -6.dbamp,
				\ffreq, Pstutter(inf, Pkey(\ffreq))
					* Pgeom.fromEndpoints(1, rrand(0.005, 0.012), parms[\numEv])
			);
		},
		slowSteps: { |parms|
			Pbind(
				\instrument, \pvplayPanDist,
				\pvbuf, ~pvbuf,
				\pt, BPStream(\ptIndex).clump(3),
				\start, ~start,
				\startFrame, Pkey(\start) / ~buffers[0].numFrames * ~numPvFrames,
				#[pan, distance], ~xyPat.(parms),
				\delta, BPStream(\slowDelta),
				\rate, BPStream(\slowRate).clump(3),
				\time, Pkey(\delta),
				\amp, BPStream(\amp) * (-4.dbamp),
				\shiftS, BPStream(\slowShift).clump(3),
				\shiftE, Pkey(\shiftS)
			)
		},
		slowStepStretch: { |parms|
			parms[\xEnds] ?? {
				parms[\xEnds] = [rrand(0.5, 1.0) * #[-1, 1].choose, 0]
			};
			parms[\yEnds] ?? {
				parms[\yEnds] = [rrand(0.5, 1.0).linlin(0.0, 1.0, ~distNear, ~distFar), ~distNear]
			};
			Pbind(
				\instrument, \pvplayPanDist,
				\early, 0,
				\pvbuf, ~pvbuf,
				\pt, BPStream(\ptIndex).clump(3),
				\start, ~start,
				\startFrame, Pkey(\start) / ~buffers[0].numFrames * ~numPvFrames,
				#[pan, distance], Pseq([
					Pfin(parms[\numEv] /* - 1 */, ~xyPat.(parms)),
					[#[-1, 0, 1], ~distNear]
				]),
				\delta, (BPStream(\slowDelta) * Pgeom.fromEndpoints(1.8, rrand(0.5, 0.7),
					parms[\numEv])) ++ 0.4,
				\rate, Pseq([
					Pfin(parms[\numEv] /* - 1 */, BPStream(\slowRate).clump(3)),
					Pwhite(0.04, 0.1, 1)
				]),
				\time, Pseq([
					Pfin(parms[\numEv] /* - 1 */, Pkey(\delta)),
					Pkey(\delta) / Pkey(\rate)
				]),
				\amp, BPStream(\amp) * -4.dbamp,
// 				\amp, BPStream(\amp) * Pseq([
// 					Pn(-4.dbamp, parms[\numEv] /* - 1 */),
// 					1
// 				]),
				\origShiftS, BPStream(\slowShift).clump(3),
				\shiftS, Pkey(\origShiftS) + Pseq([
					Pfin(parms[\numEv] /* - 1 */, 0),
					Pwhite(3, 9, 1)
				]),
				\shiftE, Pkey(\origShiftS)
			) //.collect { |ev| if(ev[\shiftS][0] > ev[\origShiftS][0]) { ev.postcs } { ev } }
		},
		clatterDecay: { |parms|
			Pseq(#[clatter, decay].collect { |key| ~gestures[key].(parms) }, 1)
		},
		klankDecay: { |parms|
			Pseq(#[oneKlankSteps, decay].collect { |key| ~gestures[key].(parms) }, 1)
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
					~runGesture.(~defaultParms.().copy);
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
	readLabels: PR(\steps1).v[\readLabels],
	labelPath: {
		~bufPaths[0].dirname
			+/+ ~bufPaths[0].basename[.. ~bufPaths[0].basename.indexOf($_)]
			++ "labels3.txt"
	},

	// oh earth mother, this is a damnably wretched hack but I had to do SOMETHING!!
	ampCorrections: #[0.28807148337364, 0.17774771153927, 0.36427477002144, 0.12500120289816, 0.38182136416435, 0.18799524009228, 0.58741980791092, 0.052831564053287, 0.20307244360447, 0.24629978835583, 0.42413705587387, 0.16614802181721, 0.30681470036507, 0.090353488922119, 0.089508562163331, 0.12378922104836, 0.42652836441994, 0.83408385515213, 0.15755517780781, 0.15393386781216, 0.15342317521572, 0.43515829067847, 0.074556715786457, 0.24919280409813, 0.6793058514595, 0.092316187918186, 0.26444959640503, 0.052370578050613],
	listGest: { ~gestures.keys.asArray.sort.do(_.postln); "" }
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

BP(\st).gest = Pseq(BP(\st).gestures.keys.asArray.sort, inf).trace;

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

// kinda wack mixing 3 together, slowed down so much
BP(\st).slowDelta = Pn(Plazy { |ev| Pn(rrand(0.3, 0.6), ev[\parms][\numEv] ? 1) }, inf);
BP(\st).slowRate = Pwhite(0.5, 0.8, inf);
BP(\st).slowRate = Pwhite(0.2, 0.5, inf);
BP(\st).slowShift = Pexprand(1, 15, inf) - 3;

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
		\time, Pkey(\delta),
		\amp, BPStream(\amp) * (-4.dbamp),
		\shiftS, BPStream(\slowShift).clump(3),
		\shiftE, Pkey(\shiftS)
	)
};

BP(\st).gestures.slowStepStretch = { |parms|
	parms[\xEnds] ?? {
		parms[\xEnds] = [rrand(0.5, 1.0) * #[-1, 1].choose, 0]
	};
	parms[\yEnds] ?? {
		parms[\yEnds] = [rrand(0.5, 1.0).linlin(0.0, 1.0, ~distNear, ~distFar), ~distNear]
	};
	Pbind(
		\instrument, \pvplayPanDist,
		\early, 0,
		\pvbuf, ~pvbuf,
		\pt, BPStream(\ptIndex).clump(3),
		\start, ~start,
		\startFrame, Pkey(\start) / ~buffers[0].numFrames * ~numPvFrames,
		#[pan, distance], Pseq([
			Pfin(parms[\numEv] /* - 1 */, ~xyPat.(parms)),
			[#[-1, 0, 1], ~distNear]
		]),
		\delta, (BPStream(\slowDelta) * Pgeom.fromEndpoints(1.8, rrand(0.5, 0.7), parms[\numEv]))
			++ 0.4,
		\rate, Pseq([
			Pfin(parms[\numEv] /* - 1 */, BPStream(\slowRate).clump(3)),
			Pwhite(0.04, 0.1, 1)
		]),
		\time, Pseq([
			Pfin(parms[\numEv] /* - 1 */, Pkey(\delta)),
			Pkey(\delta) / Pkey(\rate)
		]),
		\amp, BPStream(\amp) * (-4.dbamp),
// 		\amp, BPStream(\amp) * Pseq([
// 			Pn(-4.dbamp, parms[\numEv] /* - 1 */),
// 			1
// 		]),
		\origShiftS, BPStream(\slowShift).clump(3),
		\shiftS, Pkey(\origShiftS) + Pseq([
			Pfin(parms[\numEv] /* - 1 */, 0),
			Pwhite(3, 9, 1)
		]),
		\shiftE, Pkey(\origShiftS)
	) //.collect { |ev| if(ev[\shiftS][0] > ev[\origShiftS][0]) { ev.postcs } { ev } }
};


BP(\st).gest = \slowStepStretch;

BP(\st).gest = \slowSteps;
BP(\st).numEv = Pwhite(3, 5, inf);
BP(\st).gDelta = Pwhite(2.5, 4.0, inf);

BP(\st).event.eventKey = \polySynthPlayer;

1/0.070451948642731

BP(\st).gest = \decay;

BP(\st).use {
	var parms;
	parms = (yEnds: [rrand(0.15, 0.4), rrand(0.75, 1.0)].linlin(0, 1, ~distNear, ~distFar),
		numEv: 10);
parms.debug;
	Pseries.fromEndpoints(*(parms[\yEnds] ++ parms[\numEv]).debug).postcs
};

BP(\st).gestures.decay = { |parms|
			parms[\numEv] = rrand(18, 28);
			parms[\yEnds] = [rrand(0.3, 0.4), rrand(0.75, 1.0)].linlin(0, 1, ~distNear, ~distFar);
			Pbind(
				#[pan, distance], ~xyPat.(parms),
				\early, 0,
				\pt, Pstutter(inf, BPStream(\ptIndex).reject(#[3, 10, 14].includes(_))),
				\start, Pstutter(inf, BPStream(\start)),
				\delta, rrand(0.06, 0.09),//.debug("decay delta"),
				\time, Pkey(\delta) * rrand(1.75, 2.2), //rrand(0.6, 0.8),
				\rate, Pstutter(inf, Pkey(\rate)),
				\amp, Pstutter(inf, BPStream(\amp)) / Pindex(~ampCorrections, Pkey(\pt), inf)
					* Pgeom.fromEndpoints(1, -25.dbamp, parms[\numEv]) * -6.dbamp,
				\ffreq, Pstutter(inf, Pkey(\ffreq))
					* Pgeom.fromEndpoints(1, rrand(0.005, 0.012), parms[\numEv])
			);
		};

BP(\st).use {
	~amp = Pindex(Pfunc { |ev|
		var	early = ev[\early] ?? { ev[\parms][\early] ?? { ~early } };
~peaks.flop[ev[\pt]].debug("both");
		~peaks[(early <= 0).binaryValue.debug("which")]
	}, Pfin(1, Pkey(\pt).trace(prefix: "pt: ")), inf).reciprocal.trace(prefix: "amp: ");
};

BP(\st).pt[[9, 3]]
[315652, 134374] / 44100

m = BP(\st).chan;
z = PeakMonitor(m);
p = BP(\st);

y = z.dependants.detect(_.notNil);
y.dump
y.instVarAt(8)

m.play(\bufGrainPan, [start: (p.pt[9] - 0.000) * 44100, time: 0.08*0.6, rate: 1, amp: p.peaks[1][9].reciprocal, bufnum: p.buffers[0]]);

i = 14; m.play(\bufGrainPan, [start: (p.pt[i] - 0.000) * 44100, time: 0.08*0.6, rate: 1, amp: p.peaks[1][i].reciprocal, bufnum: p.buffers[0]]);

w = ResizeFlowWindow("x", Rect(10, 10, 200, 100));
Button(w, 100@20).states_([["click"]]).action_({ [~i, y.instVarAt(8).flop[0].maxItem].postln });
w.recursiveResize.front;

q = m.play(Ptpar([
	0, Pbind(
		\instrument, \bufGrainPan,
		\i, Pn(Pseries(0, 1, p.pt.size), inf).collect { |x| ~i = x },
		\start, Pindex(p.pt, Pkey(\i), inf) * 44100,
		\time, 0.08 * 0.6,
		\amp, Pindex(p.peaks[1], Pkey(\i), inf).reciprocal / Pseq(#[0.28807148337364, 0.17774771153927, 0.36427477002144, 0.12500120289816, 0.38182136416435, 0.18799524009228, 0.58741980791092, 0.052831564053287, 0.20307244360447, 0.24629978835583, 0.42413705587387, 0.16614802181721, 0.30681470036507, 0.090353488922119, 0.089508562163331, 0.12378922104836, 0.42652836441994, 0.83408385515213, 0.15755517780781, 0.15393386781216, 0.15342317521572, 0.43515829067847, 0.074556715786457, 0.24919280409813, 0.6793058514595, 0.092316187918186, 0.26444959640503, 0.052370578050613], inf) * -12.dbamp,
		\bufnum, p.buffers[0],
		\delta, 2
	),
	0.5, Pbind(
		\play, { [topEnvironment[\i], y.instVarAt(8).flop[0].maxItem].postln },
		\delta, 2
	)
]));

q.stop;
p.peaks[1][[6, 10, 16, 17]] / [0.58741980791092, 0.62214255332947, 0.42652836441994, 0.83408385515213] * -15.dbamp;


p.peaks[1][[2, 5, 6, 10, 16, 17, 21, 24, 26]]

BP(\st).labelPath = BP(\st).labelPath.replace("3.", "5.");
BP(\st).readLabels;


1/1.5096764904905

BP(\st).peaks.size
BP(\st).peaks.do(_.postln); ""

( 'instrument': bufGrainPanFiltDist, 'pt': 4, 'clock': a TempoClock, 'eventKey': singleSynthPlayer, 
  'rate': 0.95516796320561, 'collIndex': st, 'glrvbout': SharedBus(audio, 18, 2, localhost), 'bufIndex': 0, 'distFar': 20, 
  'removeFromCleanup': [  ], 'delta': 0.10389504432678, 'distNear': 5, 'bufnum': 1, 'ampMap': c11, 
  'lcrvbout': SharedBus(audio, 20, 2, localhost), 'propagateDownward': a Function, 'distance': 19, 'time': 0.075599667303675, 'pan': -0.92339754104614, 
  'start': 160702.17298226, 'amp': 4.3262391523084, 'ffreq': 18000, 'timingOffset': 0, 'chan': a MixerChannel, 
  'parms': ( 'numEv': 12, 'gest': decay ) )

BP(\st).peaks[1][23].reciprocal

~savePt = BP(\st).ptIndex;
BP(\st).ptIndex = 4;

164914.4637 / 44100
BP(\st).pt[4]

BP(\st).start = Pfunc { |ev|
		(~pt[ev[\pt]] - ((ev[\early] ?? { ev[\parms][\early] ?? { ~early } }) * ev[\rate]))
			* ~buffers[ev[\bufIndex]].sampleRate
	};

BP(\st).amp = BP(\st).amp.pattern;

BP(\st).listGest = { ~gestures.keys.asArray.sort.do(_.postln); "" };


BP(\st).gestures.oneKlank = { |parms|
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
				\chorusAmps, #[[0, 0, 0]]
			)
		};

BP(\st).gestures.oneKlankSteps = { |parms|
	var once = true;
			Pbind(
				\instrument, Pseq([\bufGrainPanKlankDist, Pkey(\instrument)], 1),
				#[pan, distance], ~xyPat.(parms),
				\delta, BPStream(\fastDelta),
				\amp, BPStream(\amp),
				\filtFreq, Pstutter(inf, BPStream(\kfreq)),
				\filtAttack, 0.01,
				\filtDecay, BPStream(\kdecay),
				\filtAmp, BPStream(\kamp),
				\chorusFreq, Pstutter(inf, Pwhite(0.05, 0.11, inf)),
				\chorusAmt, 0.02,
				\chorusDelay, 0.03,
				\chorusAmps, [(1..3).reciprocal * 0.3],
				\ffreq, BPStream(\ffreq)
			).collect { |ev|
				if(once) { once = false; ev.filtDecay.debug };
				ev
			}
		};

BP(\st).kdecay = Pwhite(0.5, 0.8, inf);
BP(\st).gest = \oneKlankSteps;


BP(\st).gestures.clatterDecay = { |parms|
	Pseq(#[clatter, decay].collect { |key| ~gestures[key].(parms) }, 1)
};
BP(\st).gestures.klankDecay = { |parms|
	Pseq(#[oneKlankSteps, decay].collect { |key| ~gestures[key].(parms) }, 1)
};


// melody adaptation without using full melody BP... possible?
~dummy = Proto.new;
m = PR(\melSegWithAdapt).copy.prepare([
	#[74, 79, 78],
	4, 4, 1
].asNotes, SequenceNote(74, 1, 1, 1), ~dummy, (mode: \g), true);

m.listVars
m.segs[0].listVars

// maybe reasonable
10.do {
	o = \affSplitNote3.eval(m.segs.last);
	// o.do(_.postln);
	o !? { m.addAdapt(o, ()) };
};

m.segs.last.notes.do(_.postln); ""
m.segs.last.notes.collect({ |n| n.freq }).unmapMode(\g).collect { |n| n.asInteger.asMIDINote };


// choose note just outside range
// need variant that will keep intervals smaller
{ |source| var i = source.notes.size.rand, out, dur, new;
	out = source.notes.copy;
	dur = out[i].dur;
	out[i] = out[i].copy.dur_(rrand(0.25, dur).round(0.25));
	(out[i].dur != dur).if({
		while {
			(new = (out[i].freq/*.debug("old")*/ + 2.rand2)/*.debug("+rand")*/.fold(source.loNote - 3, source.hiNote + 3)).round/*.debug("new")*/ == out[i].freq
		};
		out = out.insert(i+1, SequenceNote(new, dur = dur - out[i].dur, dur + rrand(-0.1, 0.1), out[i].args));
		out
	}, { nil });	// nil == no adaptation
} => Func(\affSplitNote3);



// string rewriting - fail
p = BP(\st).chan.play(Pbind(
	\root, 7,
	\degree, Pseq(#[4, 7, 6]) ++ \patRejectLastN.eval(Prewrite(Pseq(#[4, 7, 6], inf), (
		0: #[5, 0, 6],
		1: #[1, 0, 2, 3],
		2: #[6, 7, 4],
		3: #[3, 0, 6, 5],
		4: #[4, 5, 1],
		5: #[5, 7, 6],
		6: #[6, 7, 10],
		7: #[9, 7, 5, 6],
// 		8: #[]
		9: #[9, 4, 3],
		10: #[10, 9, 5, 9]
	), 10), 1),
	\dur, 1
));

p.stop;

x = Prewrite(Pn(0, inf).trace(prefix: "root: "), (
	0: Pwhite(1, 2, 1).trace(prefix: "rw0: "),
	1: Prand(#[0, 2], 1).trace(prefix: "rw1: "),
	2: Pwhite(0, 1, 1).trace(prefix: "rw2: ")
), 2).asStream;

10.do { x.next.postln };


f = { |count, level, rules| [count, level].debug; { "dgf".choose } ! 2 };
x = Plsys(Pseq("dgf", 2), [
	"d" -> f,
	"g" -> f,
	"f" -> f
], level: 2).asStream;

x.nextN(20);

35.asDigit

[1, 2].integrate

Mode(\default).v.copy.root_(7) => Mode(\g);
Mode(\g).v.postcs

($B.digit + 28).unmapMode(\g).asInteger.asMIDINote

x = Plsys(Pseq("BED", 1), (0..35).collect { |i|
	String.with(i.asDigit) -> { |in|
		([in[0].digit] ++ ({ #[-2, -1, 1, 2].choose } ! 2)).integrate
		.collect(_.asDigit).as(String)
	}
}, level: 0);

p = Penvir((level: Pseries(0, 1, inf).asStream, curLevel: 0), Pbind(
	\root, 7,
	\octave, 4,
	\amp, 0.02 * Pseq([2, Pn(1, { ((3 pow: ~curLevel).asInteger - 1) })], inf).trace,
	\legato, Pseq([4, Pn(0.8, { (3 pow: ~curLevel).asInteger - 1 })], inf),
	\delta, 1,
	\degree, Pn(Plazy { x.level_(~curLevel = ~level.next) }, inf).collect(_.digit)
)).play;

p.stop;

.collect { |ch| (ch.digit + 28).unmapMode(\g) };

x.next;

// sequence
Fact(\opening) => BP(\op);
Fact(\openingSteps) => BP(\st);
Fact(\waterch) => BP(\waterch);
Fact(\waterpad) => VC(\waterpad);
BP(\waterch) => VC(\waterpad);


PR(\trajectories) => BP(\traj);
d = DDWTimer.new;

t.stop;

(
t = TLSequenceIterator([
	{ ~master.level = -10.dbamp;
//		~master.startRecord(thisProcess.platform.recordingsDir +/+ "feet-open.aiff");
		1
	},
	bpCmd: (name: \op, dur: 35, prepareBP: { |bp|
		bp.ampCtl.value = 0.68;
		if(d.class == DDWTimer) { d.reset };
	}),
	12,
	gcAutoSynthCmd: (gc: BP(\op).ampCtl, name: \ctlPoint, outName: \outbus,
		value: 0, time: 22, curve: -2),
	bpCmd: (name: \st, prepareBP: { |bp|
		bp.ampCtl.value = 0;
		bp.gest = Pseq([Pn(\slowSteps, { rrand(2, 4) }), \slowStepStretch], inf);
		bp.numEv = Pwhite(4, 7, inf);
		bp.gDelta = Pwhite(2.5, 4.0, inf);
		bp.slowRate = Pwhite(0.5, 0.8, inf);
		bp.defaultParms = nil;
		bp.kdecay = Pexprand(0.014, 0.017, inf).trace(prefix: "kdecay: ");
		bp.makeStreamForKey(\kfreq);	// reset this one
		bp.autoRun = true;

		bp.gestures.oneKlankStepsCallback = { |parms|
			CleanupStream(~gestures[\oneKlankSteps].(parms).asStream, parms[\callback])
		};
	}),
	gcAutoSynthCmd: (gc: BP(\st).ampCtl, name: \ctlPoint, outName: \outbus,
		value: 0.7, time: 14, curve: 2),
	\cmdSync,
	20,
	loopCmd: (repeats: 3,
		cmds: [
			funcCmd: (
				setDoneSignal: {
					~doneSignal = true;
					defer(e {
						~window = Window("go", Rect.aboutPoint(Window.screenBounds.center, 50, 20));
						Button(~window, ~window.view.bounds.insetBy(2, 2))
							.states_([["play note soon"]])
							.action_(e { ~stop.() });
						~window.front;
					});
				},
				func: 0,
				clearDoneSignal: {
					defer(e { ~window.close });
				}
			),
			\cmdSync,
			funcCmd: (
				doneSignal: true,
				func: {
					BP(\st).override(\gest, Pn(\oneKlankStepsCallback, 1), false,
						// override cleanup will always hit before the next gesture is picked
						// therefore it won't use defaultParms that aren't meant for it
						{ BP(\st).defaultParms = nil });
					// guarantee next "note" can't happen until last note gesture is done
					BP(\st).defaultParms = (numEv: rrand(10, 20), callback: e { ~stop.() });
				}
			),
			\cmdSync
		]
	),
	\cmdSync,
	{ "post-loop".debug; 5 },
	{	var	bp = BP(\st);
// 		bp.gest = Pseq([
// 			Pwrand(#[clatter, oneKlankSteps, clatterDecay, klankDecay, slowSteps],
// 				#[4, 2, 3, 1, 1].normalizeSum, { rrand(3, 6) }),
// 			\slowStepStretch
// 		], inf);
		bp.chordN = 0;
		bp.kdecay = (Pwhite(0.1, 0.3, inf) * Env(#[0.1, 0.25], #[100], 7));//.trace(prefix: "kdecay: ");
		bp.gest = Pswitch1([
			Pseq([
				Pwrand(#[clatter, oneKlankSteps, clatterDecay, klankDecay, slowSteps],
					#[4, 2, 3, 1, 1].normalizeSum, { rrand(3, 6) }),
				\slowStepStretch
			], inf),
			Prand(#[oneKlankSteps, klankDecay, klankHarmonize, klankHrmSteps], inf)
		], (Pwhite(0.0, 1.0, inf) < Env(#[0.0, 1.0], #[120])).collect(_.binaryValue));
		bp.gDelta = Pwhite(1.5, 3.0, inf) * Env(#[1, 0.36], #[90]);
		bp.numEv = Pwhite(6, 14, inf);
		90
	},
	{	BP(\st).chordN = 1;
		20
	},
	bpCmd: (name: \waterch, dur: 36, prepareBP: { |bp|
		bp.reset;
		BP(\st).stop(0);
		SynthDef(\waterauto, { |outbus|
			var amp = LFNoise1.kr(0.8).exprange(0.01, 0.1);
			Out.kr(outbus, SinOsc.kr(LFNoise1.kr(0.5).exprange(0.2, 1.2), 0, amp, 1))
		}).add;
	}),
	gcAutoSynthCmd: (gc: VC(\waterpad).v.globalControls[\freqmul], name: \waterauto, outName: \outbus,
		dur: 40),
	16,
	mixerAutoSynthCmd: (mixer: ~master, name: \ctlPoint, outName: \outbus,
		value: 0, time: 20, curve: -2.1, stopAction: { BP(\st).stop }),
	\cmdSync,
	{ "over".debug;
//		~master.stopRecord;
		0
	}
]).play;
)

t.stop;
t.isRunning

BP(\st).gestStream.next;
BP(\st).kfreqStream.next;

BP(\st).gDelta = Pwhite(0.5, 1.2, inf);



BP(\st).nextLowerInt = Pseries({ rrand(1, 3) }, Prand(#[-2, -1, 1, 2], inf), inf)
		.fold(-10, 10).reject { |x, ev| x.debug("x") >= ev[\filtDegree].debug("filtdeg"); } - Pkey(\filtDegree);

BP(\st).nextLowerIntStream.next((filtDegree: 4));


BP(\st).gestures.klankHarmonize = { |parms|
			Pbind(
				\nextLower, BPStream(\nextLowerInt),
				\chord, Pclump(BPStream(\chordN), BPStream(\chordInt)),
				\filtFreq, Ptuple([Pkey(\filtDegree), Pkey(\nextLower), Pkey(\chord)], inf)
					.collect { |item| Mode(\g).cps(item.flat.integrate + 35) }
			)
			<> ~gestures[\oneKlank].(parms)
		};

BP(\st).gest = \klankHarmonize;

BP(\st).play(0); { BP(\st).stop(0) }.defer(1);

BP(\st).prepareForPlay;
BP(\st).reset; BP(\st).makeStreamForKey(\kfreq);

BP(\st).v[\isPlaying] = true;
e = BP(\st).eventStream.next(BP(\st).event.copy);
e.asKeyValuePairs.clump(2).sort { |a, b| a[0] < b[0] }.do(_.postln);
BP(\st).v[\isPlaying] = false; ""

e.asKeyValuePairs.clump(2).sort { |a, b| a[0] < b[0] }.do(_.postln); ""

e.copy.play;

BP(\st).chordN = 1;
BP(\st).kdecay.postcs

k = VC(\waterpad).globalControls[\freqmul];
k => VP(2);

k.watch.automate {
	var amp = LFNoise1.kr(0.8).exprange(0.01, 0.1);
	SinOsc.kr(LFNoise1.kr(0.5).exprange(0.2, 1.2), 0, amp, 1)
};

k.autoSynth.trace

k.stopWatching.stopAuto;

VC(\waterpad).v.nodes.detect(_.isPlaying).trace