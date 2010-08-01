// really isn't good enough...

\makeEmptyMixer8.eval;

m = MixerChannel(\test, s, 1, 2);
m => MCG(0);

b = Bus.audio(s, 1);
k = Bus.control(s, 1);

w = Window(\test, Rect(Window.screenBounds.width - 150, 10, 145, 50));
Button(w, w.view.bounds.insetBy(2, 2))
	.states_([["click"]])
	.action_({ z.set(\t_trig, 1) });
w.front;

a = {
	var	sig = In.ar(b, 1),
		fft = FFT(LocalBuf(1024, 1), sig),
		beat, half, qrt, tempo;
	#beat, half, qrt, tempo = BeatTrack.kr(fft);
	tempo.poll(beat);
	beat
}.play(outbus: k);

z = { |t_trig = 0|
	SinOsc.ar(220) * Decay2.kr(t_trig, 0.01, 0.08)
}.play(outbus: b);


a.free; z.free;