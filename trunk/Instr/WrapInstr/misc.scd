//WrapInstr([\misc, \harmonic], { arg freq, gate, freqlag, rq;
// var amp;
// amp = Latch.kr(gate, gate);
// freq = Lag.kr(freq, freqlag);
// Resonz.ar(Saw.ar(32.midicps), freq, rq)
// * EnvGen.kr(Env.adsr(0.05, 0.4, 0.75, 0.1), gate, doneAction:2)
//}, #[nil, nil, nil, \myrq]);

1 // have to return something
