// Affectations: Body controller sequence

(Document.current.path.dirname.dirname +/+ "/body/body-defs.scd").debug.loadPath;

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
				filename: "arms/NACL_Arms.wav"
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
			VC(\sp).env.target.newPostSend(~glrvbmc, 0.6);
			\chuckIf.eval(Fact(\formantfx2), BP, \ffx2, nil,
				(chan: VC(\sp).env.target, fmtSearch: "sopr"));
			BP(\ffx2).fadeIn_(0.05).fadeOut_(3);
		},
		unloadProcesses: { VC(\sp).free; BP(\ffx2).free },
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \ffx2, dur: 15),
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
						clearDoneSignal: { ~nodes.do(_.release) }
					)
				],
				// onStop: {},
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
				id: 2520,  // trig id
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