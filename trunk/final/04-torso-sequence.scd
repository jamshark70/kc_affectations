// Affectations: Torso controller sequence

(Document.current.path.dirname.dirname +/+ "/torso/torso-defs.scd").debug.loadPath;

[
	PR(\tlsAff).copy.putAll((
		name: "T2000-low tones",
		segID: 2000,
		initProcesses: {
			if(VC.exists(\tton).not) { Func(\makettoneVC).value(\tton) };
			\chuckIf.eval(Fact(\ttonesBP), BP, \tton, nil);
		},
		unloadProcesses: {
			VC(\tton).free; BP(\tton).free;
		},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \tton, shouldSync: false, prepareBP: { |bp|
						bp.speedMul.value = 0.1;
						bp.fshift.value = 0;
						bp.distance.value = 17;
					}),
					gcAutoSynthCmd: (gc: { VC(\tton).v.globalControls[\ffreq] },
						name: \ctlEnv, outName: \outbus,
						env: Env(#[800, 7000, 1000], #[0.5, 0.5], \exp),
						time: 140
					),
					10,
					gcAutoSynthCmd: (gc: { BP(\tton).fshift },
						name: \ctlEnv, outName: \outbus,
						env: Env(#[0, 60], #[1], 6),
						time: 60
					),
					30,
					gcAutoSynthCmd: (gc: { BP(\tton).speedMul },
						name: \ctlEnv, outName: \outbus,
						env: Env(#[0.1, 0.7], #[1], \exp),
						time: 45
					)
				],
				// onStop: { BP(\tton).stop(0) },
				dur: \trigger,  // or \sync
				id: 2010,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2010-stephen solo",
		segID: 2010,
		initProcesses: {
			\chuckIf.eval(Fact(\torsoSolo), BP, \ssd);
		},
		unloadProcesses: { BP(\ssd).free },
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \ssd, shouldSync: false),
					[15, { BP(\tton).stop(0); 0 }],
					loopCmd: (
						cmds: [
							funcCmd: topEnvironment[\trigParms],
							\cmdSync,
							funcCmd: (
								doneSignal: true,
								func: {
									var p = BP(\ssd);
									if(p[\savesynthStream].isNil) {
										p.override(\synth, Pxrand(#[distance, pan, ffreq], 10));
										p.override(\delta, Pwhite(0.2, 0.8, 10));
										p.override(\sustain, (Pkey(\delta) * Pwhite(1.5, 3.0, 10)).trace, false, e { ~doneSignal = nil; ~stop.() });
									} { ~doneSignal = nil; ~stop.() };
								}
							),
							\cmdSync
						]
					)
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2020,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2020-plus Ilana",
		segID: 2020,
		initProcesses: {
			\chuckIf.eval(Fact(\torsoSolo), BP, \ssd2, nil, (
				gcSpecs: (
					distance: #[5, 20],
					center: \freq.asSpec.copy.default_(exprand(100, 140)),
					width: #[0, 80, \lin, 0, 10],
					speed: #[0.05, 20, \exp, 0, 8],
					ffreq: \freq.asSpec.copy.default_(exprand(500, 900)),
					rq: \myrq.asSpec.copy.default_(0.2),
					amp: [0, 10.dbamp, \lin, 0, 0.4],
					pan: \bipolar
				)
			));

			BP(\ssd2).ffreqlevels = Pfunc({
				var	n = rrand(3, 5);
				[{ exprand(600.0, 1000.0) } ! n, { exprand(1800.0, 2100.0) } ! n]
				.lace(n*2).drop(#[-1, 0].choose)
			});
			BP(\ssd2).centerlevels = Ptuple([30, Pexprand(600.0, 2100.0, inf), Pexprand(80.0, 140.0, inf)], inf);
			BP(\ssd2).amplevels = (Ptuple([1, Pwhite(0.6, 0.8, inf), Pwhite(0.18, 0.23, inf)], inf) * 2.5);

			BP(\ssd2).panlevels = Pfunc({
				var	n = rrand(3, 5);
				[{ rrand(-1.0, -0.75) } ! n, { rrand(0.75, 1.0) } ! n]
				.lace(n*2).drop(#[-1, -2].choose).add(0.7.rand2)
				* #[-1, 1].choose
			});

			BP(\ssd2).delta = Pwhite(0.6, 1.8, inf);
			BP(\ssd2).sustain = Pkey(\delta) * Pwhite(0.8, 1.8, inf);
		},
		unloadProcesses: { BP(\ssd2).free },
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \ssd, shouldSync: false, playWarning: false),
					bpCmd: (name: \ssd2, shouldSync: false),
					loopCmd: (
						cmds: [
							funcCmd: topEnvironment[\trigParms],
							\cmdSync,
							funcCmd: (
								doneSignal: true,
								func: {
									var p = BP(\ssd);
									if(BP(\ssd)[\savesynthStream].isNil) {
										BP(#[ssd, ssd2]).do { |p|
											p.override(\synth, Pxrand(#[distance, pan, ffreq], 10));
											p.override(\delta, Pwhite(0.2, 0.8, 10));
											p.override(\sustain, (Pkey(\delta) * Pwhite(1.5, 3.0, 10)).trace, false, e { ~doneSignal = nil; ~stop.() });
										};
									} { ~doneSignal = nil; ~stop.() };
								}
							),
							\cmdSync
						]
					)
				],
				// onStop: { BP(#[ssd, ssd2]).stop(0) },
				dur: \trigger,  // or \sync
				id: 2030,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2030-energy-exch",
		segID: 2030,
		initProcesses: {
			\chuckIf.eval(Fact(\torsoDrone), BP, \td);
			\chuckIf.eval(Fact(\nrgThrows), BP, \thr);
			BP(\td).sustain = Pkey(\delta) + Pwhite(5.0, 8.5, inf);
			BP(\td).droneamp = 4.dbamp;
			BP(\td).rq = 0.11;
			BP(\td).fshift = Pwhite(4.0, 12.0, inf);
		},
		unloadProcesses: { BP(#[td, thr]).free },
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \thr, shouldSync: false, prepareBP: { |bp|
						bp.delta = Pswitch1([
							Pwhite(1.5, 3.0, inf),
							Pexprand(0.2, 0.9, inf)
						], Pwrand([0, Pn(1, Prand(#[1, 2, 3, 4], inf).asStream)], #[0.7, 0.3], inf));
						bp.sustain = Pexprand(0.7, 2.8, inf);
						bp.throwfLow = Pwhite(200, 400, inf);
						bp.throwfHi = Pwhite(1000, 3000, inf);
						bp.throwampenv = `[Env(#[0, 0.1, 1, 0.1, 0] * 0.5, #[0.3, 0.1, 0.1, 0.5], \sin)];
						bp.amp = 1;
					}),
					bpCmd: (name: \td, shouldSync: false, prepareBP: { |bp|
						bp.speedMul = Pwhite(0.7, 2.0, inf);
						bp.fshift = Pexprand(4.0, 36.0, inf);
					}),
					[10, { BP(#[ssd, ssd2]).stop(0); 0 }]
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2040,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2040-ensemble",
		segID: 2040,
		initProcesses: {
			if(VC.exists(\tmel).not) { \makeTmelVC.eval(\tmel) };
			\chuckIf.eval(Fact(\fastnotesBP), BP, \fastnotes);
			VC(\tmel) => BP(\fastnotes);
			BP(\fastnotes).originalDelta = BP(\fastnotes).changingDelta;
		},
		unloadProcesses: {
			VC(\tmel).free; BP(\fastnotes).free;
		},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \thr, shouldSync: false, playWarning: false),
					bpCmd: (name: \td, shouldSync: false, playWarning: false),
					{	var r = BP(\thr);
						r.delta = Prand([
							Pstutter(inf, Pexprand(0.08, 0.14, 1)) * Pseq([Pn(1, { rrand(3, 7) }), 3], 1),
							Pexprand(0.08, 0.2, { rrand(8, 17) }),
							// Plazy({ Pgeom.fromEndpoints(rrand(0.06, 0.09), rrand(0.18, 0.35), rrand(8, 14).debug("endpts")) }),
							Plazy({
								var	curve = Env([rrand(0.06, 0.09), rrand(0.18, 0.35)], #[1], 5).asArray;
								Pseries.fromEndpoints(0.0, 1.0, rrand(8, 14)).collect { |x| curve.envAt(x) }
							})
						], inf) * Env(#[4, 1], #[8], -2);

						r.sustain = max(0.08, Pkey(\delta) * Pwhite(0.25, 0.6, inf));

						r.throwfLow = Prand([
							Plazy({ Pser({ exprand(600, 1400) } ! 2, rrand(2, 4) * 2 + 1) }),
							Plazy({ Pgeom.fromEndpoints(rrand(200, 500), rrand(2000, 4500), rrand(8, 14)) }),
							Pexprand(600, 1800, { rrand(8, 17) })
						], inf);
						r.throwfHigh = Pkey(\fLow) * Pwrand([1, Pwhite(0.6, 0.8, 1), Pwhite(1.2, 1.4, 1)], #[0.7, 0.15, 0.15], inf);
						r.throwampenv = Prand([
							[Env.perc(0.9, 0.1, 0.2).asArray],
							[Env.perc(0.1, 0.9, 0.2).asArray]
						], inf);
						r.amp = 1;
						6
					},
					bpCmd: (name: \fastnotes, shouldSync: false, prepareBP: { |bp|
						bp.useModGCs = false;
						bp.num = 0;
						bp.mod_ratio = Pwhite(2, 7, inf) + Pwhite(0.14, 0.88, inf);
						bp.mod_lev = Pexprand(6, 14, inf);
						bp.finalAmp = VC(\tmel).v.globalControls[\finalAmp].asMap;
					}),
					gcAutoSynthCmd: (gc: { VC(\tmel).v.globalControls[\finalAmp] },
						name: \ctlEnv, outName: \outbus, shouldSync: false,
						env: Env(#[0.001, 0.16, 0.11], #[8, 2], \exp), connect: 0,
						time: 1
					),
				],
				onStop: { BP(#[thr, td]).stop(0) },
				dur: \trigger,  // or \sync
				id: 2050,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2050-Ilana to floor",
		segID: 2050,
		initProcesses: {
			\chuckIf.eval(PR(\tposes), BP, \tp);
			VC(\tmel) => BP(\tp);
			0 => BP(\tp);
		},
		unloadProcesses: { BP(\tp).free },
		seqPattern: {
			Pn((
				sequence: [
					{	// Pif stops this stream, which will stop the BP
						BP(\fastnotes).finalAmp = Pif(
							Ptime() <= 3.5,
							Env([VC(\tmel).v.globalControls[\finalAmp].value, 0.001], #[8], -1.7).postcs
						);
						0
					},
					// for slow notes
					gcAutoSynthCmd: (gc: { VC(\tmel).v.globalControls[\finalAmp] },
						name: \ctlEnv, outName: \outbus, shouldSync: false,
						env: Env(#[0.16, 0.16], #[1], \exp), connect: 1,
						time: 6
					),
					synthCmd: (
						name: \nrgxch2, target: VC(\tmel).env.target,
						outbus: [VC(\tmel).env.sideBus, BP(\ssd).noisebuf, 10, 4],
						amp: 16.dbamp, moveTime: 24,
						fenv: Env([100, 100, 71.midicps] * 2, #[0.12, 0.3], \exp),
						rqenv: Env(0.1 ! 2, #[1]),
						ampenv: Env.linen(0.05, 0.75, 0.2),
						ctrenv: Env([100, 100, 71.midicps], #[0.12, 0.3], \exp)
					),
					bpCmd: (name: \tp, prepareBP: { |bp| bp.reset })
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2060,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2060-Fast ensemble",
		segID: 2060,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					{	var bp = BP(\fastnotes);
						bp.useModGCs = false;
						bp.num = Pwrand(#[1, 2, 3], #[0.7, 0.2, 0.1], inf);
						bp.mod_ratio = blend(Pwhite(2, 7, inf) + Pwhite(0.14, 0.88, inf),
							3, Pseg(Pseq([0, 1], inf), Pwhite(2.0, 4.0, inf), \sine));
						bp.mod_lev = Pseg(Ppatlace([Pexprand(6, 14, inf), 1.6], inf),
							Pwhite(2.0, 4.0, inf), \sine);

						bp = BP(\thr);
						bp.delta = Prand([
							Pstutter(inf, Pexprand(0.08, 0.14, 1)) * Pseq([Pn(1, { rrand(3, 7) }), 3], 1),
							Pexprand(0.08, 0.2, { rrand(8, 17) }),
							// Plazy({ Pgeom.fromEndpoints(rrand(0.06, 0.09), rrand(0.18, 0.35), rrand(8, 14).debug("endpts")) }),
							Plazy({
								var	curve = Env([rrand(0.06, 0.09), rrand(0.18, 0.35)], #[1], 5).asArray;
								Pseries.fromEndpoints(0.0, 1.0, rrand(8, 14)).collect { |x| curve.envAt(x) }
							})
						], inf);

						bp.sustain = max(0.08, Pkey(\delta) * Pwhite(0.25, 0.6, inf));

						bp.throwfLow = Prand([
							Plazy({ Pser({ exprand(600, 1400) } ! 2, rrand(2, 4) * 2 + 1) }),
							Plazy({ Pgeom.fromEndpoints(rrand(200, 500), rrand(2000, 4500), rrand(8, 14)) }),
							Pexprand(600, 1800, { rrand(8, 17) })
						], inf);
						bp.throwfHigh = Pkey(\fLow) * Pwrand([1, Pwhite(0.6, 0.8, 1), Pwhite(1.2, 1.4, 1)], #[0.7, 0.15, 0.15], inf);
						bp.throwampenv = Prand([
							[Env.perc(0.9, 0.1, 0.5).asArray],
							[Env.perc(0.1, 0.9, 0.5).asArray]
						], inf);
						
						0
					},
					loopCmd: (
						// proc: Pseq(#[fastnotes, thr], inf).asStream,
						cmds: [
							{	var dur = exprand(2.0, 3.5);
								// [thisThread.clock.beats, dur, thisThread.clock.beats + dur].debug("fastnotes");
								TLSequenceIterator([
									{ BP(\fastnotes).stop(0); 0.02 },
									bpCmd: (name: \fastnotes, shouldSync: false, dur: dur,
										prepareBP: { |bp|
											bp.finalAmp = Env([0.16, 0.01], [dur], 1);
										}
									),
									dur * rrand(0.45, 0.65)
								], autoSync: false)
							},
							\sync,
							{	var dur = exprand(2.0, 3.5);
								// [thisThread.clock.beats, dur, thisThread.clock.beats + dur].debug("thr");
								TLSequenceIterator([
									{ BP(\thr).stop(0); 0.02 },
									bpCmd: (name: \thr, shouldSync: false, dur: dur,
										prepareBP: { |bp|
											bp.amp = Env([1, 0.01], [dur], 1);
										}
									),
									dur * rrand(0.45, 0.65)
								], autoSync: false)
							},
							\sync
						]
					)
				],
				onStop: {},
				dur: \trigger,  // or \sync
				id: 2070,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2070-Slow down",
		segID: 2070,
		// initProcesses: {},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					
				],
				// onStop: {},
				dur: \trigger,  // or \sync
				id: 2080,  // trig id
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