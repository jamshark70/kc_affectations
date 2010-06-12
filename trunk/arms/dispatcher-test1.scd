
(Document.current.path.dirname +/+ "arms-defs.scd").loadPath;
ChuckableBrowser.newWindow;
SynthDescLib.global.browse;
Object.browse;
s.queryAllNodes;
BP.all.free;
Help.gui;
Error.debug = true;
Error.debug = false;


BP(\xy).free;
PR(\xyDispatch) => BP(\xy);
0 => BP(\xy);
BP(\xy).alwaysReset = true;

// test xy only
BP(\xy).trackDefs[\yReverseDir].activateOnPlay = false;
BP(\xy).trackDefs[\yReverseDir].activateOnPlay = true;

BP(\xy).play;
BP(\xy).stop;

BP(\xy).listVars;
{ BP(\xy).trackSynth.trace }.defer(4.0)

(
PR(\trackviz).chuck(BP(\viz), nil, (
	model: \xy,
	useMouse: true,
	diffScale: 10
));
)

BP(\viz).free;

BP(\xy).trackDefs.yReverseDir.node.set(\dirThresh, 1e-05);
BP(\xy).trackDefs.yReverseDir.node.trace

{ BP(\xy).trackDefs.yReverseDir.node.trace }.defer(4);

// test theta oscillation
a = { SinOsc.kr(0.5, mul: 0.2, add: 0.5pi) }.play(BP(\xy).trackDefs.yReverseDir.node, BP(\xy).busnumForParm(\theta), addAction: \addBefore);
a.free;

-20.4204.wrap(0, pi)

BP(\xy).trackDefs.yReverseDir[\args] = [dirThresh: 1e-04, zeroTimeThresh: 0.01];

// theta tracking arg:
BP(\xy).trackDefs.yReverseDir[\args] = [crossTheta: 0];

BP(\xy).trackDefs.yReverseDir.action = { BP(\vertNotes).triggerOneEvent(0) };
BP(\xy).trackDefs.yReverseDir[\action] = { |msg| msg[3].debug("\nhit"); ~trackDefs.yReverseDir.node.trace };
//BP(\xy).trackDefs.yReverseDir[\args] = { |def| ~baseArgs.(def) ++ [dirThresh: 2.6e-05] };

BP(\xy).trackDefs.yReverseDir.action = {
	BP(\vertNotes).triggerOneEvent(0);
	[~busParms, ~busParms.collect(_.envirGet)].flop.do(_.postln); "".postln;
};

WrapInstr("osc2.fm2car_pan_lfo").listArgs

(
(make: { |name|
// 	var	out;
	~target = MixerChannel(name, s, 2, 2, level: -17.dbamp);
	~cb = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg(#[1, 2, 3].reciprocal) });
	~mb = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg(#[1]) });

	Voicer(20, WrapInstr("osc2.fm2car_pan_lfo"), [
		basefreq: `440, keyScale: `0.28621534453893,
		car_buf: ~cb, mod_buf: ~mb,
 		car_env: Env.adsr(0.5, 0.8, 0.75, 1.0),
// 		mod_env: ,
		mod_ratio: `1, detune: `0, car_detune: `0.99798261661993,
		car_vs: `0.66141732283465, mod_vs: `0
	], target: ~target);
},
free: { [~cb, ~mb, ~target].free }, type: \voicer) => Fact(\fmping);

(make: { |name|
// 	var	out;
	~target = MixerChannel(name, s, 1, 2, level: -17.dbamp);
	~cb = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg(#[1, 2, 3].reciprocal) });
	~mb = Buffer.alloc(s, 1024, 1, { |buf| buf.sine1Msg(#[1]) });

	Voicer(20, WrapInstr("osc2.fm2car_bass_tlfo"), [
		basefreq: `440, keyScale: `0.28621534453893,
		car_buf: ~cb, mod_buf: ~mb,
 		car_env: Env.adsr(0.5, 0.8, 0.75, 1.0),
// 		mod_env: ,
		mod_ratio: `1, detune: 0, car_detune: `0.99798261661993,
		car_vs: 0.66141732283465, mod_vs: `0
	], target: ~target);
},
free: { [~cb, ~mb, ~target].free }, type: \voicer) => Fact(\armsBass);


PR(\abstractProcess).clone {
	~event = (eventKey: \chordChooser);

// 	~chords = Mode.keys
// 		.reject(#[cmin, default].includes(_))
// 		.reject({ |key| key.asString.last == $0 })
// 		.asArray.scramble[..5]
// 		.collect { |key|
// 			(mode: key,
// 				notes: #[21, 25, 28, 30, 31.5, 33, 34, 36, 39, 41, 42.5, 44, 45.5, 47, 50, 51, 53.5])
// 		};

	~prep = {
		~intervals ?? {
			~intervals = Pxrand(~intervalSets, inf);
		};

		// dependent processes need to have some event to use
		// before this process starts playing
		BP(~collIndex).prepareForPlay;
		~eventStream.next(~event.copy);
	};

	~freeCleanup = {
		currentEnvironment.releaseDependants;
	};

	~intervalSets = [
		[-3, -1, -2, -2, -1, -3, -2, -4]
	];

	// assumes root = 0; will be transposed
	~top = Paccumbounce(42, 58, Pwrand(#[-2, -1, 1, 2], #[1, 2, 2, 1].normalizeSum, inf), inf);
	~mode = Pxrand(Mode.keys.select { |key|
		key = key.asString;
		key.size <= 2 and: { key.first.inclusivelyBetween($a, $g) and: { key.last != $0 } }
	}.asArray, inf);
	~slideTime = Pexprand(1.8, 4.4, inf);

	~asPattern = {
		Pbind(
			\top0, BPStream(\top),
			\mode, BPStream(\mode),
			\mode0, Pfunc { |ev| ~getZeroMode.(ev) },
			\top, Pfunc { |ev| ev[\top0].unmapMode(ev[\mode0]).mapMode(ev[\mode]) },
			\intervals, BPStream(\intervals),
// 			\chord, Pxrand(~chords, inf),
			\chord, Pfunc { |ev| ~makeChord.(ev) },
			\delta, Pwhite(3, 6, inf) * 5,
			\slideTime, BPStream(\slideTime)
		).collect({ |ev| ~lastEvent = ev; ev })
	};

// 	~makeChord = { |ev|
// 		var	chs = List.new, stats;
// 		\traverseIntervalTree.eval([ev[\top]], ev[\intervals], chs);
// 		stats = chs.collect { |ch, i|
// 			[\chPitchFit.eval(ch, ev[\top], 0, ev[\mode], Library.at(\fitFactors)), i]
// 		};
// 		stats = stats.sort({ |a, b| a[0] > b[0] });
// 		chs[stats.oneOfTop(3)[1]]
// 	};

	// above "homogenizes" the chords too much (and is SLOW!), so...
	// throw out the fitness calculation and just choose a random order of intervals
	~makeChord = { |ev|
		var	chord = Array(ev[\intervals].size + 1).add(ev[\top]);
		ev[\intervals].scramble.do { |int|
			chord.add(chord.last + int);
		};
		chord
	};

	~getZeroMode = { |ev|
		var	mode = ev[\mode].asString;
		if(mode.last != $0) { mode.add($0).asSymbol } { ev[\mode] };
	};
} => PR(\chordChooser);

(
play: {
	// many processes could be listening to me
// currentEnvironment.debug("chordChooser");
	BP(~collIndex).v.changed(\chord, currentEnvironment);
}
) => ProtoEvent(\chordChooser);

)

(
if(VC.exists(\fmp).not) { Fact(\fmping) => VC(\fmp) };
if(VC.exists(\fmb).not) { Fact(\armsBass) => VC(\fmb) };

BP(\vertNotes).free;
BP(\cchs).free;

PR(\chordChooser) => BP(\cchs);
0 => BP(\cchs);

PR(\patternTop).chuck(BP(\vertNotes), nil, (
	driver: \cchs,
	event: (eventKey: \voicerNotePostponeRelease,
		// user hook: to allow sliding to next chord
		finish: {
//"event finish".debug;
			BP(~collIndex).recvEventNotify(currentEnvironment);
		}
	),

	modeChooser: \default,
	mode: \default,
//	chord: #[21, 25, 28, 30, 31.5, 33, 34, 36, 39, 41, 42.5, 44, 45.5, 47, 50, 51, 53.5],
	ampLow: 0.5,
	ampTimeRatio: 0.4,

	dispatcher: \xy,
	prep: {
		//		~chan = MixerChannel(~collIndex, s, 2, 2);
		~activeNodes = IdentitySet.new;
		~activeEvents = IdentitySet.new;
		if(~modeChooser.notNil) {
			~makeStreamForKey.(\modeChooser);
			~mode = ~modeChooserStream.next;
		};
// 		~makeStreamForKey.(\slideTime);

		BP(~driver).v.addDependant(currentEnvironment);
	},
	freeCleanup: {
		BP(~driver).v.removeDependant(currentEnvironment);
	},
// 	degSpec: #[21, 49, -3].asSpec,
// 	deg: Pfunc { ~degSpec.map(BP(~dispatcher).mousey.neg * 0.5 + 0.5).round },
	deg: Pfunc { ~chord[BP(~dispatcher).mousey.linlin(1, -1, 0, ~chord.size-0.001, \none).trunc] },
	delta: 1,
	length: Pwhite(1.5, 6.0, inf),
	dtSpeed: Pexprand(0.3, 1.7, inf),
		// note, 'freq' is actually scale degree here
		// lower register is less tolerant of modulating detune
	dtAmp: Pkey(\freq).linexp(16, 56, 0.2, 4, clip: \none),
	envScaleSpec: #[0.1, 10, \exp].asSpec,
	envScale: Pfunc {
		~envScaleSpec.map(BP(~dispatcher).radius
			.linlin(0.0001, 0.002, 0, 1, \minmax)).reciprocal
	},
	mod_levelSpec: #[0.8, 2.3].asSpec,
	mod_level: Pfunc {
		~mod_levelSpec.map(BP(~dispatcher).radius
			.linlin(0.0001, 0.002, 0, 1, \minmax))
	},
//	modLfoSpeedSpec, ,
//	modLfoAmpSpec, #[1, 1].asSpec,
	modLfoDecaySpec: #[0.1, 7.0, \exp].asSpec,
	modLfoRangeSpec: #[1, 2.5, \exp].asSpec,
	modLfoSpeed: Pexprand(3.0, 8.0, inf),
	modLfoAmp: 1,
	modLfoDecay: Pfunc {
		~modLfoDecaySpec.map(BP(~dispatcher).radius
			.linlin(0.0001, 0.002, 0, 1, \minmax))
	},
		// -0.5 for lower bound means slower movement won't trigger lfo
	modLfoRange: Pfunc {
		~modLfoRangeSpec.map(BP(~dispatcher).radius
			.linlin(0.0001, 0.002, -0.5, 1, \minmax))
	},
	basePattern: PR(\patternTop).v[\asPattern],

	recvEventNotify: { |ev|
		ev[\countReleased] = 0;
		~activeEvents.add(ev);
		~activeNodes.addAll(ev[\nodes]);
		// trickery (or work around design flaw):
		// the VoicerNodes don't have the Synth nodes yet,
		// but if I wait until the thread yields, they will be
		// oh... and, I know which event the node belongs to b/c of lexical scope!
		defer(e {
			ev[\nodes].do { |node|
				var	upd = Updater(node.synth, e { |obj, what|
					if(what == \n_end) {
						~activeNodes.remove(node);
						ev[\countReleased] = ev[\countReleased] + 1;
						if(ev[\countReleased] == ev[\nodes].size) {
							~activeEvents.remove(ev);
						};
						upd.remove;
					}
				});
			};
		});
	},

	update: { |obj, what, event|
		if(obj.collIndex == ~driver and: { what == \chord }) {
			~chord_.(event[\chord], event[\mode], event);
		};
	},

	chord_: { |notes, mode(\default), event|
		~chord = notes.sort;
		~mode = mode;
		~slideNotes.(event);
	},

	slideNotes: { |ev|
		// need to control slide distance
		// so, map from event's 'freq' + newModeRoot - oldModeRoot
		// to chord notes within a range around it
		var	//pitches = Pshuf(~chord, inf).asStream.nextN(~activeNodes.size),
			slideTime = ev[\slideTime],
			releaseAbsTime = thisThread.clock.beats + slideTime + 2.5,
			event, nodeI, center,
			pool = ~chord.copy, newPitch;
		~activeNodes.do { |node, i|
			event = ~activeEvents.detect { |ev| ev[\nodes].includes(node) };
			// don't slide if the event can't be found
			if(event.notNil) {
				nodeI = event[\nodes].indexOf(node);
// nodeI.debug("\nnodeI");
				center = event[\freq].asArray[nodeI] - ~mode.asMode.root + event[\mode].asMode.root;
// center.debug("center");
				newPitch = pool.select { |p| p.inclusivelyBetween(center - 8, center + 8) }
					.choose;
// newPitch.debug("newPitch");
				if(newPitch.notNil) {
					pool.remove(newPitch);
					node.set([freq: Mode(~mode).cps(newPitch), freqlag: slideTime]);
// 						.frequency_(newPitch);
					event[\postponeReleaseTo] = releaseAbsTime;
				} {
					// couldn't slide, so release instead
					node.release(freq: event[\newFreq][nodeI]);
				};
			};
		};
	},

	asPattern: {
		Pseq([
// 			Plazy {
// 				Pif(Ptime() < (5 * rrand(2, 6)),
					Pbind(
//						\envTimeScale, BPStream(\envScale),
						\ampLow, BPStream(\ampLow),
						\ampTimeRatio, BPStream(\ampTimeRatio),
						\mod_level, BPStream(\mod_level),
						\detuneLfoSpeed, BPStream(\dtSpeed),
						\detuneLfoAmp, BPStream(\dtAmp),
						\modLfoSpeed, BPStream(\modLfoSpeed),
						\modLfoAmp, BPStream(\modLfoAmp),
						\modLfoDecay, BPStream(\modLfoDecay),
						\modLfoRange, BPStream(\modLfoRange)
					)
					<>
					~basePattern.()
// 				)
// 			},
// 			Pfuncn {
// 				~chord_.(~chord, ~modeChooserStream.next);
// 				(type: \rest, delta: 0)
// 			}
		], inf)
	}
));

BP(\vertNotes) => VC(\fmp);
VC(\fmp) => MCG(2);

if(BP.exists(\xy)) {
	BP(\xy).trackDefs.yReverseDir.action = { BP(\vertNotes).triggerOneEvent(0) };
};
)

MixingBoard(\test, nil, VC(\fmp));

BP(\vertNotes).deg = Pfunc { ~degSpec.map(BP(~dispatcher).mousey.neg * 0.5 + 0.5).round };
BP(\vertNotes).length = Pwhite(1.5, 6.0, inf);

BP(\vertNotes).envScale = BP(\vertNotes).envScale.trace(prefix: "envscale");

BP(\vertNotes).envScale = Pfunc {
		~envScaleSpec.map(BP(~dispatcher).radius
			.linlin(0.0001, 0.002, 0, 1, \minmax)).reciprocal
	}.trace(prefix: "envscale: ");


{ VC(\fmp).v.trace }.defer(5);
k.free;

BP(\vertNotes).slideTime = 5;
BP(\vertNotes).ampLow = 0.5;
BP(\vertNotes).ampTimeRatio = 0.4;
BP(\vertNotes).modeChooser = Pxrand(#[default, eb, ab], inf);

#[eb, 3, ab, 8].pairsDo { |key, root| Mode(\default).v.copy.root_(root) => Mode(key) };
Mode(\eb).v.postcs

