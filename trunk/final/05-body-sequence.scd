// Affectations: Body controller sequence

(Document.current.path.dirname.dirname +/+ "/body/body-defs.scd")/*.debug*/.loadPath;

[
	PR(\tlsAff).copy.putAll((
		name: "B2500-Laura 1",
		segID: 2500,
		initProcesses: {
			\chuckIf.eval(PR(\armsSkidMel), BP, \bskid, nil,
				(def: \bellskid).putAll(Library.at(\rvbs)));
			BP(\bskid).prepareForPlay;
		},
		unloadProcesses: { BP(\bskid).free },
		seqPattern: {
			Pn((
				sequence: [
					{	p = BP(\bskid).v.reset;
						0
					},
					loopCmd: (
						id: \am1,
						autoSync: false,
						firstWait: false,
						cmds: [
							{	if(~firstWait) {
									PR(\funcCmd).copy.putAll(topEnvironment[\trigParms])
								} {
									~firstWait = true;
									PR(\funcCmd).copy  // will stop immediately
								}
							},
							\cmdSync,
							{ 2.do { BP(\bskid).triggerOneEvent(0) }; 0 }
						]
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2510,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2510-reset axial",
		segID: 2510,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					{	p = BP(\bskid).v.reset;
						0
					},
					loopCmd: (
						id: \am1,
						autoSync: false,
						firstWait: false,
						cmds: [
							// {	if(~firstWait) {
							// 		PR(\funcCmd).copy.putAll(topEnvironment[\trigParms])
							// 	} {
							// 		~firstWait = true;
							// 		PR(\funcCmd).copy  // will stop immediately
							// 	}
							// },
							// \cmdSync,
							{ 2.do { BP(\bskid).triggerOneEvent(0) }; rrand(0.6, 1.1) }
						]
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2520,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2520-locomotive",
		segID: 2520,
		initProcesses: {
			\chuckIf.eval(Fact(\dataIn), BP, \di, nil, (
				filename: "arms/hands-1_data2.wav"
			));
			\chuckIf.eval(Fact(\armsChordVC), VC, \ac, nil, Library.at(\rvbs));
			\chuckIf.eval(PR(\armsChord), BP, \acDisp, nil, (
				angleBus: BP(\di).bus.index + 1, // ??
				rotSpeedBus: BP(\di).bus.index + 4
			));
			BP(\acDisp) => VC(\ac);
			0 => BP(\acDisp);
			BP(\acDisp).mod_lev = Pkey(\distance).linlin(Pkey(\distNear), Pkey(\distFar), 9.0, 5.0);
			// inharmonic spectra
			BP(\acDisp).mod_ratio = Pwhite(1, 6, inf) + Pswitch1([
				Pwhite(0.1, 0.3, inf),
				Pwhite(0.7, 0.9, inf)
			], Prand(#[0, 1], inf));
		},
		unloadProcesses: { VC(\ac).free; BP(\acDisp).free },
		seqPattern: {
			Pn((
				sequence: [
					{	
						BP(\acDisp).mod_lev = Pkey(\distance)
							.linlin(Pkey(\distNear), Pkey(\distFar), 9.0, 5.0);
						// inharmonic spectra
						BP(\acDisp).mod_ratio = Pwhite(1, 6, inf) + Pswitch1([
							Pwhite(0.1, 0.3, inf),
							Pwhite(0.7, 0.9, inf)
						], Prand(#[0, 1], inf));
						BP(\acDisp).spawnChild(0);
						0
					}
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2530,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2530-stop low, arm up",
		segID: 2530,
		initProcesses: {
			\chuckIf.eval(Fact(\shimmerpad), VC, \sp, nil, (
				env: Env.adsr(0.5, 0.4, 0.8, 1.8, curve: -2),
				fenv: Env.adsr(0.5, 0.5, 0.1, 3, peakLevel: 1, bias: 1)
			).putAll(Library.at(\rvbs)));
			VC(\sp).env.target.newPostSend(topEnvironment[\glrvbmc], 0.6);
			\chuckIf.eval(Fact(\formantfx2), BP, \ffx2, nil,
				(chan: VC(\sp).env.target, fmtSearch: "sopr"));
			BP(\ffx2).fadeIn_(0.05).fadeOut_(3);
		},
		unloadProcesses: { VC(\sp).free; BP(\ffx2).free },
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \ffx2/*, dur: 15*/, shouldSync: false),
					0.07,
					funcCmd: (
						dur: 12,
						func: {
							fork {
								~nodes = VC(\sp).v.trigger(#[55, 110], 0.4,
									[glrvbamt: 0, lcrvbamt: 0, freqlag: 10], lat: s.latency);
								0.05.wait;
								#[59, 71].midicps.do { |f, i| ~nodes[i].set([freq: f], latency: s.latency) }
							};
						},
						clearDoneSignal: { defer(e { ~nodes.do(_.release) }, 3.5) }
					)
				],
				onStop: { defer({ BP(\ffx2).stop(0) }, 4.0) },
				dur: \trigger,  // or \sync
				id: 2540,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2540-reset axial 2",
		segID: 2540,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					{	p = BP(\bskid).v.reset;
						0
					},
					loopCmd: (
						id: \am1,
						autoSync: false,
						firstWait: false,
						cmds: [
							// {	if(~firstWait) {
							// 		PR(\funcCmd).copy.putAll(topEnvironment[\trigParms])
							// 	} {
							// 		~firstWait = true;
							// 		PR(\funcCmd).copy  // will stop immediately
							// 	}
							// },
							// \cmdSync,
							// { 2.do { BP(\bskid).triggerOneEvent(0) }; 0 }
							{ 2.do { BP(\bskid).triggerOneEvent(0) }; rrand(0.6, 1.1) }
						]
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2550,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2550-Locomotive",
		segID: 2550,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					{	
						BP(\acDisp).mod_lev = Pkey(\distance)
							.linlin(Pkey(\distNear), Pkey(\distFar), 9.0, 5.0);
						// inharmonic spectra
						BP(\acDisp).mod_ratio = Pwhite(1, 6, inf) + Pswitch1([
							Pwhite(0.1, 0.3, inf),
							Pwhite(0.7, 0.9, inf)
						], Prand(#[0, 1], inf));
						BP(\acDisp).spawnChild(0);
						0
					}
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2560,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "B2560-Wild arms",
		segID: 2560,
		initProcesses: {
			\chuckIf.eval(Fact(\messyDrums), BP, \md, nil, (master: topEnvironment[\master]));
			\chuckIf.eval(Fact(\words), BP, \sw, nil, Library.at(\rvbs));
		},
		unloadProcesses: { BP(#[md, sw]).free },
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \ffx2/*, dur: 15*/, shouldSync: false),
					0.07,
					funcCmd: (
						dur: 12,
						func: {
							fork {
								~nodes = VC(\sp).v.trigger(#[55, 110], 0.4,
									[glrvbamt: 0, lcrvbamt: 0, freqlag: 10], lat: s.latency);
								0.05.wait;
								#[68, 80].midicps.do { |f, i| ~nodes[i].set([freq: f], latency: s.latency) }
							};
						},
						clearDoneSignal: { defer(e { ~nodes.do(_.release) }, 3.5) }
					),
					2.0,
					bpCmd: (name: \md, prepareBP: { |bp|
						bp.ampCtl.value = 0.2;
					}),
					bpCmd: (name: \sw, prepareBP: { |bp|
						bp.noisydelta = Pwhite(0.3, 0.6, inf);
						bp.noisytime = Pkey(\delta).linlin(0.3, 0.6, 0.4, 0.4);
						bp.word = Plazy({ Prand(~pts, inf) });
						bp.pitcheddelta = Pwhite(0.1, 0.4, inf);
						bp.pitchedtime = Pkey(\delta) * Pwhite(1.4, 2.1, inf);
						bp.pitchProb.value = 0.88;
						bp.mode = Pseq([
							Pn(\e0, { rrand(12, 24) }),
							Pstutter(Pwhite(2, 6, inf), Prand(Mode.keys.asArray.select { |key|
								key != \e0 and: { key.asString.last == $0 }
							}, { rrand(1, 4) }))
						], inf);
					})
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2570,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	// PR(\tlsAff).copy.putAll((
	// 	name: "",
	// 	segID: 0,
	// 	initProcesses: {},
	// 	unloadProcesses: {},
	// 	seqPattern: {
	// 		Pn((
	// 			sequence: [
	// 			],
	// 			// onStop: {},
	// 			dur: \trigger,  // or \sync
	// 			id: 0,  // trig id
	// 			init: Func(\nextThingTrig).v,
	// 			clear: Func(\clearNextTrig).v
	// 		), 1)
	// 	}
	// )),

]