s.boot;

s.bufferAllocator.debug;

(
var	sf;

"choose a file inside the directory you want to audition".postln;
Dialog.getPaths { |paths|
	~dir = paths[0].dirname;

	~filters = [_.contains(".aif"), _.contains(".wav")];

	~files = (~dir +/+ "*").pathMatch.select { |path|
		~filters.any(_.value(path))
	}.collect { |path|
		if((sf = SoundFile.openRead(path)).isOpen) {
			sf.close;
			(path: path, numChan: sf.numChannels, dur: sf.duration)
		} {
			"% couldn't be opened".format(path).warn;
		};
	};

	~volBus = Bus.control(s, 1).set(1);

	~window = ResizeFlowWindow("sample audition", Window.screenBounds);
	~playstop = StaticText(~window, Rect(0, 0, 300, 20))
		.align_(\center)
		.string_("spc to play");
	~vol = EZSlider(~window, Rect(0, 0, 400, 20), "volume", \amp, { |view| ~volBus.set(view.value) }, 1);
	Button(~window, Rect(0, 0, 120, 20))
		.states_([["sfview off"], ["sfview ON"]])
		.action_({ |view|
			~enableSFView.(view.value > 0);
		});

	~window.startRow;
	~fileList = ListView(~window, Rect(0, 0, 300, Window.screenBounds.height - 50))
		.items_(~files.collect({ |file| file.path.basename }))
		.action_({ |view|
			~showSF.(~files[view.value]);
		})
		.keyDownAction_({ |view, char|  // mods, unicode, keycode
			case
			{ char == $  } { ~togglePlay.(~files[view.value]) };
		});

	~sfvContainer = CompositeView(~window, Rect(0, 0, ~window.view.decorator.indentedRemaining.width, Window.screenBounds.height - 50))
		.background_(Color.blue(alpha: 0.1));

	~window.recursiveResize
		.onClose_({
			~window.onClose_(nil);
			~freeCleanup.();
		})
		.front;

	~makeSynthDefs = {
		~files.collect(_.numChan).as(IdentitySet).do { |numch|
			SynthDef("sampPlay" ++ numch, { |bufnum, gate = 1, amp = 1, vol = 1, start = 0, out|
				var	sig = PlayBuf.ar(numch, bufnum, BufRateScale.ir(bufnum), startPos: start,
					loop: 0, doneAction: 2),
				eg = EnvGen.kr(Env.asr(0.01, amp, 0.02), gate, doneAction: 2);
				sig = sig * eg * vol;
				if(numch == 1) { sig = sig ! 2 };
				Out.ar(out, sig);
			}).add;
		};
	};

	~togglePlay = { |file|
		var	sf, peaks;
		if(~nowPlaying.isNil) {
			~nowPlaying = file;
			Routine {
				if(file.peak.isNil) {
					if((sf = SoundFile.openRead(file.path)).isOpen) {
						"Please wait: determining peak value of %\n".postf(file.path.basename);
						0.01.wait;
						protect { 
							peaks = sf.channelPeaks(threaded: true);
							file.peak = peaks.maxItem;
						} { sf.close };
					} {
						"Couldn't open %\n".postf(file.path.basename);
					};
				};
				file.buf ?? {
					file.buf = Buffer.read(s, file.path);
					s.sync;
				};
				file.playNode = Synth("sampPlay" ++ file.numChan, [
					bufnum: file.buf, amp: file.peak.reciprocal, vol: ~volBus.asMap
				]);
				{ ~playstop.string_("spc to stop") }.defer;
				OSCpathResponder(s.addr, ['/n_end', file.playNode.nodeID], { |time, resp, msg|
					{ ~playstop.string_("spc to play") }.defer;
					~nowPlaying = nil;
					resp.remove;
				}).add;
			}.play(AppClock);
		} {
			{ ~playstop.string_("spc to play") }.defer;
			~nowPlaying.playNode.release;
			~nowPlaying = nil;
		};
	};
	
	~freeCleanup = {
		~nowPlaying !? { ~togglePlay.() };
		~volBus.free;
		// some buffers don't get freed without pausing?
		fork {
			~files.do { |file|
				file.buf.free;
				0.01.wait;
			};
		};
	};
	
	~makeSynthDefs.();
	~fileList.focus;
	
};
)

Help.gui;
FlowLayout.browse;

s.sendMsg(\n_trace, 1000)