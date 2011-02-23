// pitchedSlideProb Env

ChuckableBrowser.newWindow;

w = ResizeFlowWindow("amps", Rect(800, 32, 300, 300));
BP(\cwd).ampCtl.gui(w);
w.startRow;
BP(\wtrig).ampCtl.gui(w);
w.recursiveResize.front;

d = DDWTimer.new;

~lim = BP(\cwd).chan.playfx(Instr("busfx.limiter"), [0, 2, 0.9, 0.01]);


(
t.stop;
t = TLSequenceIterator([
	Quant(-1, -0.05),
	{
		var x = (Pseed(Pn(Date.seed, 1), Pwhite(2, 4, inf)) / BP(\drum7).messedUpMulCtl).round * 3,
			y = (Pseed(Pn(Date.seed + 234321, 1), Pwhite(3, 9, inf))
				* Env(#[1, 0.075], #[80], 0.5).asStream).round,
			oldGest = Library.at(\drum78AccGest),
			q1 = BasicTimeSpec(1), qbar = BasicTimeSpec(-1),
			rsyncEnv = Env(#[1, 0], #[90], 1.4).asStream;

d.reset;

		BP(\drum7).gest = Pseq([
			// Pseq([
				// Pn(\ostFilt2, x.asStream.trace(prefix: bp.collIndex ++ " num ost bars: ")),
				\randquant,
				Pn(\messedUp, y.asStream),
				Pfuncn({ ~quant = qbar; \randquant }),
				Pif(Ptime() < Pstutter(1e6, x.asStream), oldGest),
			// ], 2),
			Prout({ |inval|
				var	xstream = x.asStream,
					muPats = [
						Pn(\messedUp, y.asStream),
						Pfuncn({
							if(~collIndex == \drum7) { BP(\wtrig).triggerOneEvent(0) };
							\messedUp1
						}, Pwhite(1, Env(#[1, 1, 5], #[10, 50]), inf).round.asStream
							.collect { |num| ~mUp1Num = num; num }
						)
					];
				NotificationCenter.notify(\drum7, \disintegrationAdvance);
				inval = Pseq([\randsync, muPats[0], \randsync, muPats[1]])
				.embedInStream(inval);
				loop {
					if(rsyncEnv.next.coin) { inval = \randsync.embedInStream(inval) };
					inval = Pseq(muPats, 1).embedInStream(inval);
					// inval = muPats[1].embedInStream(inval);
				};
			})
		]).collect { |gest| ~lastGesture = gest };
		BP(\drum8).gest = Pfunc({ BP(\drum7).lastGesture });
		BP(\drum7).messedUpMulCtl.value = 1;
		BP(\wtrig).delta = Pfunc({ BP(\drum7).lastMessedUpBeats });
		BP(\wtrig).sustain = (Pkey(\delta) / Ptempo());
		BP(\wtrig).ffreqTopCtl.value = 18000;
		BP(\wtrig).distCtl.value = 8;
		BP(\wtrig).ampCtl.value = 1;
		BP(\wtrig).playAttack = true;
		BP(\wtrig).offset = Pseq([
			0.75,
			Pseq([
				Pn(0, { BP(\drum7).mUp1Num - 1 }),
				min(Pwhite(1, 3, 1) * 0.5, Pkey(\delta) - 0.5)
			], inf)
		]);
		BP(\cwd).use {
			~pitchProb.value = 1;
			~ampCtl.value = 20.dbamp;
			~pitchednormAmp = ~ampCtl.asMap.asPattern;
			~pitchedenv = [Env(#[0, 1, 0.35, 0.35, 0], #[0.01, 0.1, 0.69, 0.2], -4)];
			~pfreq = (Paccumbounce(35, 46, Pwrand(#[-2, -1, 1, 2], #[0.2, 0.2, 0.3, 0.3], inf), inf)
				-.x Pseries(0, Pwhite(1, 4, Pkey(\numInChord).asStream)))
			.clump(Pfunc({ |ev| ev[\numInChord] = rrand(7, 11); ev[\numInChord] }))
			.collect { |deg, ev| Mode(ev[\mode]).cps(deg) };
			~pitchedSlideProb = Env(#[0, 0.5], #[45], 2);
			~pitchedtime = Pfunc({ BP(\wtrig).lastEvent.sustain });
			~preparePlay.();
		};
		BP(\drum7).messedUp1Beats = Pseq([
			Pwhite(4, 7, 1),
			Pseq([
				Pwrand(#[1, 1.5, 2, 2.5, 3], #[3, 4, 2, 1, 1].normalizeSum, { ~mUp1Num - 1 }),
				Pwhite(4, 7, 1),
			], inf)
		]);
		0
		// 18
	},

	{	BP(#[drum4, drum5, drum6]).stop;
		BP(\drum7).pan = -1;
		BP(\drum8).pan = 1;
		BP(\drum7).quant = -1;
		BP(\drum8).quant = #[-1, 0.75];
		BP(\drum7).distCtl.value = 5;
		BP(\drum7).finalLpfCtl.value = 18000;
		0
	},

	bpCmd: (name: #[drum7, drum8], quant: -1, /*shouldSync: false,*/ prepareBP: { |bp|
		bp.ostFiltCtl.value = 1;
		bp.fmltDcyCtl.value = 0.25;
		bp.fmltWetCtl.value = 0.1;
		bp[\chan].level = -7.dbamp;
	}),

	funcCmd: (
		setDoneSignal: {
			~doneSignal = NotificationCenter.register(\drum7, \disintegrationAdvance, \wait, e{
				~stop.();
			});
		},
		clearDoneSignal: { ~doneSignal.remove }
	),
	\cmdSync,

	gcAutoSynthCmd: (gc: { BP(\drum7).messedUpMulCtl }, name: \ctlEnv, outName: \outbus,
		env: Env(#[1, 3], #[45])),

	12,
	[	0.05,
		{
			PR(\gcAutoSynthCmd).copy.putAll((
				gc: BP(\drum7).finalLpfCtl, name: \bassVelMap, outName: \outbus,
				inbus: BP(\drum7).distCtl.bus,
				inMin: 5, inMax: 20, outMin: 18000, outMax: 400, slewUp: 1e6, slewDown: 1e6
			))
		},
		20,
		gcAutoSynthCmd: (gc: BP(\wtrig).distCtl, name: \ctlPoint, outName: \outbus,
			value: 20, time: 100),
		gcAutoSynthCmd: (gc: BP(\wtrig).ffreqTopCtl, name: \ctlPoint, outName: \outbus,
			value: 300, time: 140, curve: -2.1),
		gcAutoSynthCmd: (gc: BP(\wtrig).ampCtl, name: \ctlPoint, outName: \outbus,
			value: 0, time: 150, curve: -2.1,
			stopAction: { BP(\wtrig).playAttack = false }
		),
		70,
		gcAutoSynthCmd: (gc: BP(\cwd).ampCtl, name: \ctlPoint, outName: \outbus,
			value: 0, time: 125, curve: -2.1),
	],
	gcAutoSynthCmd: (gc: { BP(\drum7).distCtl }, name: \ctlEnv, outName: \outbus,
		env: Env(#[5, 20], #[120])),
	\cmdSync,
//	{ BP(#[drum7, drum8]).stop(0); 0 }
]).play(0, ~clock108);
)

BP(\wtrig).distCtl.gui


BP(\wtrig).free; BP(\cwd).free;