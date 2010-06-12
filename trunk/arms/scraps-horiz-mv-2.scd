


// random debugging stuff follows, never mind...

TempoClock.default.queue.size

s.freeAll;



BP(\pt).chan.play(Pbind(
	\instrument, BP(\pt).def.name.asSymbol,
	\degree, Paccumbounce(-7, 21, Pwrand(#[-1, 1, 2], #[0.2, 0.5, 0.3], inf), { rrand(6, 11) }).postcs,
	\dur, rrand(0.1, 0.2),
	\sustain, 1,
	\gate, 1, \amp, 1
).trace)

s.queryAllNodes;
s.sendMsg(\n_free, 1131)
(1226..1231).do(s.sendMsg(\n_free, _));

( 'instrument': \Cczyy, 'degree': 1, 'dur': 0.12176060676575, 'gate': 1, 'sustain': 1, 'amp': 1 ).play

s.sendMsg(\n_trace, 1132)
s.sendMsg(\n_free, 1132)

SynthDescLib.at(\Cczyy).hasGate
SynthDescLib.at(\Cczyy).msgFuncKeepGate = true;
SynthDescLib.at(\Cczyy).msgFunc.postcs

( 'instrument': \Cczyy, 'degree': 1, 'dur': 0.12176060676575, 'gate': 1, 'sustain': 4, 'amp': 1 ).asOSC

MixingBoard(\x, nil, BP(\pt).chan);

BP(\pt).mapSpecs[\freq].prob = 0.1;

WrapInstr("osc2.fm1").openFile


WrapInstr.argBrowser


BP(\pt).mapSpecs.mod_lev[\hi] = { rrand(6.0, 12.0) };
BP(\pt).mapSpecs.mod_lev[\mid] = { rrand(0.5, 0.9) };

BP(\pt).carbuf.sine1(Array.squareAmps(3))
BP(\pt).modbuf.sine1(#[1, 0.5, 0.1]);

Array.squareAmps(5)
Signal.square(256, 5).plot
Signal.sineFill(256, #[1, 0.5, 0.1]).plot;

((-1.0, -0.99 .. 1.0).distort * 2).plot;
Env(#[-1, 1], #[1], \sin).plot;
Env(#[-1, 0, 1], #[0.5, 0.5], #[3, -3]).plot;

((-1.0, -0.99 .. 1.0).tanh / 1.0.tanh).plot;

0.5.sqrt

ModalSpec(#[0, 2, 4, 5, 7, 9, 11], 12, 3).transposeRoot(0) => Mode(\Eb1);
BP(\pt).mode = \Eb1;
BP(\pt).mode = \default;

BP(\pt).mode = Prand([\Eb1, \default], inf).trace(prefix: "mode: ");

z = \Eb1.asMode;
z.scale
z.root

BP(\pt).delta = Pexprand(0.5, 1.8, inf);
BP(\pt).degree = BP(\pt).degree + 35;
BP(\pt).degree.postcs
BP(\pt).degree = Pfin({ rrand(5, 9) }, Pshuf((-7..7), 1)) + 35;

BP(\pt).restDelta = Pwhite(8.0, 14.0, inf).trace(prefix: "rest: ");
BP(\pt).restDelta.postcs

BP(\pt).mapSpecs[\mod_lev][\hi] = { rrand(7.0, 12.0) };

BP(\pt).mapSpecs[\mod_lev][\ornaments][\arpeg].postcs
BP(\pt).mapSpecs[\mod_lev][\ornaments][\arpeg] = { |nodeEvent| 
					var	mode = nodeEvent[\mode].asMode,
						numEvents = rrand(6, 11),
						panDir = #[-1, 1].choose;
					Pbind(
						\instrument, ~def.name.asSymbol,
						// nodeEvent[\degree]: 35 = mid c; -21 = start 8va higher
						\degree, Paccumbounce(-7, 28, Pwrand(#[-1, 1, 2], #[0.1, 0.45, 0.45], inf), numEvents, nodeEvent[\degree] - 28),
						\scale, mode.scale + mode.root,
						\dur, rrand(0.1, 0.2),
						\mod_lev, Pexprand(1.0, 5.0, inf),
						\sustain, 2.5,
						\gate, 0.5, \amp, 1,
						\physicalPan, Pseries.fromEndpoints(panDir.neg, panDir,
							numEvents) * rrand(0.7, 0.9)
					)
				};


BP(\pt).panXferEnv = Env(#[-1, 0, 1], 0.5 ! 2, #[1.8, -1.8]);
BP(\pt).panXferEnv.plot

BP(\pt).ornamentProb = 0.15;

(0+1).log + 0.02 * 600