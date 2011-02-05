// Affectations
// Main process loader

// This is so I can put section defs into separate files
// instead of having one massive navigation-hell file for the whole piece.

// BP.loadGui;  // <-- this is for James's development work - no need in the performance



// Reproduced the drum7/drum8 stop issue once. Grrrrrrr.
// I think keepGoing = false could be the issue.
// Maybe fixed by adding a tolerance to PnNilSafe.

// Something weird happened. I replayed from F1520 and the master level bus value changed
// without updating ~master. Something is using bus 0 wrongly.


// fade out drone and 'int' toward end of drum section
// go into torso section earlier, maybe 28:20 something (Laura moves fwd/back)


// this block loads everything: cursor on open-paren, then ctrl-alt-x
(
var	mypath = thisProcess.nowExecutingPath, indices;
if(BP.exists(\transports)) { BP(\transports).free };

Library.at(\isJamesBox) ?? {
	try {
		var p = Pipe("hostname", "r"), l;
		if(p.isOpen) {
			l = p.getLine;
			if(l.notNil) { Library.put(\isJamesBox, l.contains("dlm")) }
				{ Library.put(\isJamesBox, false) };
		};
		p.close;
	} { p.tryPerform(\close) };  // make sure pipe gets closed even on error
};

s = Server.local;
s.waitForBoot {
	var	cond = Condition.new;
	(mypath.dirname.dirname +/+ "/common/common-defs.scd").loadPath;
	NotificationCenter.registerOneShot(\lcrvb, \lcrvbexists, \feetSeq, {
		cond.unhang;
	});
	cond.hang;

	if(~master.mcgui.isNil) {
		if(MCG.exists(7)) {
			~master => MCG(7)
		} {
			MixingBoard("volume", nil, ~master)
		};
	};

	BP(\segTrig).free;
	PR(\busTrig).chuck(BP(\segTrig), nil, (
		message: '/segment',
		userprep: {
			~sbounds = Window.screenBounds;
			~window = Window("triggers", Rect(~sbounds.right - 120, ~sbounds.height - 150, 120, 110));
			~eventBtn = Button(~window, Rect(2, 2, 116, 51))
				.states_([["event"]])
				.enabled_(false)
				.action_(e { |view|
					~eventTrigAction.();
//					~eventActive.(nil);
				});
			~segBtn = Button(~window, Rect(2, 57, 116, 51))
				.states_([["to next seg"]])
				.enabled_(false)
				.action_(e {
					~segTrigAction.();
//					~segActive.(nil);
					// ~stop.(nil, ~isLastSection ? false)
				});
			~window.front.userCanClose_(false)
				.onClose_(e { ~window = nil });
		},
		eventActive: { |action|
			~eventTrigAction = action;
			(e { ~eventBtn.enabled = action.notNil }).defer;
		},
		segActive: { |action, segID|
			~segTrigAction = action;
			(e {
				~segBtn.enabled = action.notNil;
				if(segID.notNil) {
					~segBtn.states = [["to seg" + segID]]
				} {
					~segBtn.states = [["to next seg"]]
				};
			}).defer;
		}
	));
	BP(\evTrig).free;
	PR(\busTrig).chuck(BP(\evTrig), nil, (message: '/event', busIndex: 4094));
	0.5.wait;
	BP(#[segTrig, evTrig]).play(0);

	Library.put(\diparms, (id: \lc_data, name: \di, quant: 0,
		playWarning: false, shouldSync: false));

	// load section files from disk
	~sections = Array.new;

	// to my surprise, this actually does match only filenames starting with numbers!
	(mypath.dirname +/+ "[0-9]*.scd").pathMatch.sort
	// (mypath.dirname +/+ "03*.scd").pathMatch.sort
	.do { |path|
		indices = indices.add(~sections.size);
		~sections = ~sections ++ path.loadPath;
	};

	~seq = PR(\affSectSeq).copy.sections_(~sections).startLoadingAt_(indices);

	~seq.loadResources(0);
	PR(\transports).chuck(BP(\transports), nil, (model: ~seq));

	BP(\transports).userfree = { |bp, what|
		BP(#[segTrig, evTrig]).debug("freeing").free;
	};
};
)



// DEBUG SNIPS

ChuckableBrowser.newWindow;

MT(1).gui;

BP.all.stop;

// if you need to clear everything, do this:
BP.all.do { |bp| if(#[mstClock, di, traj].includes(bp.collIndex).not) { bp.free } }; VC.all.free;
if(BP.exists(\mstClock)) { BP(\mstClock).free };
if(BP.exists(\di)) { BP(\di).free };
if(BP.exists(\traj)) { BP(\traj).free };

~seq.sections.do(_.prUnload);


// debugging drum7/8 problem
// disable drone/formants
BP(#[fmt, hsd]).do({ |bp| bp.requiredKeys = bp[\requiredKeys].add(\disableByRequiringAVariableThatWillNeverExist) });

// after "sung 9" plays
BP(\int).requiredKeys = BP(\int)[\requiredKeys].add(\disableByRequiringAVariableThatWillNeverExist);


BP(\st).streamsToStop
BP(\st).free;
BP(\st).removeAutoRun;

BP.all.stop;

s.nextNodeID

BP(\st).free;

PeakMonitor(~master);
PeakMonitor(~glrvbmc);

o.remove;
o = OSCresponderNode(s.addr, '/n_go', { |t, r, m| r.remove; s.sendMsg(\n_trace, m[1]) }).add;


~seq.sections[~seq.currentSection].currentIterator.activeCmds;
~seq.sections[~seq.currentSection].currentIterator.activeCmds.do(_.listVars); ""

"\n\n".postln;

~seq.sections[~seq.currentSection].savedCmds
~seq.sections[~seq.currentSection].savedCmds.do(_.listVars); ""

t = ~seq.sections[~seq.currentSection].currentIterator;
t.dependants
t.changed(\done)

~seq.listVars
~seq.sections.last.listVars;

BP(\st) => MT(1);


~seq[\stop].postcs
~seq.startingSection = 0;

~seq.sections[0].listVars
~seq.sections.collectIndices(_.isLoaded);

~seq.use {
	var startAt;
		if(startAt.isNil or: { startAt < ~currentSection }) {
			if((startAt = ~startLoadingAt.detectIndex { |item| item > ~currentSection }).notNil) {
				startAt = ~startLoadingAt[max(0, startAt - 1)];
			} {
				startAt = ~startLoadingAt.last;
			};
			startAt.debug("loadResources auto-chose startAt");
		};
};


BP(\tton).listVars

Error.debug = true;
Error.debug = false;

BP(\st).v.env.keys.select { |key| key.asString.contains("auto") };

VC(\am).v.portaTime_(0.9)

BP(BP(\acDisp).lastSpawned).amp.postcs

BP(#[drum7, drum8]).collect(_.isPlaying);

BP.all.do { |bp| [bp.collIndex, bp.isPlaying].postln }; ""


~seq.sections[~seq.currentSection].currentIterator.activeCmds.do({ |cmd|
	if(cmd.class === Proto) {
	if(cmd[\subIter].notNil) {
		cmd.listVars;
		cmd.subIter.activeCmds.do(_.listVars);
		"\n--------\n".postln;
	};
	if(cmd[\name].notNil) {
		cmd.listVars;
		"\n--------\n".postln;
	};
	};
}); ""

~seq.sections[~seq.currentSection].savedCmds.do({ |cmd|
	if(cmd.isKindOf(TLSequenceIterator)) {
		cmd.activeCmds.do(_.tryPerform(\listVars));
	} {
		if(cmd[\subIter].notNil) {
			cmd.listVars;
			cmd.subIter.isRunning.debug("subiter running");
			cmd.subIter.activeCmds.do(_.listVars);
			"\n--------\n".postln;
		};
		if(cmd[\name].notNil) {
			cmd.listVars;
			"\n--------\n".postln;
		};
	};
}); ""


t = List.new;
Object.dependantsDictionary.keysValuesDo { |obj, dep|
	if(obj.class == TLSequenceIterator and: { dep.postln.any { |depn| depn.tryPerform(\id).notNil } }) {
		t.add(obj);
	}
};

t


Object.dependantsDictionary.keys.count { |obj| obj.class == TLSequenceIterator };



// for recording
MIDIPort.init([3]); // linux

// hook MIDI into OSC-trigger synths
k.free;
k = BasicMIDISocket(0, { |num|
	if(num < 60) {
		BP(\segTrig).bus.set(99999);
	} {
		BP(\evTrig).bus.set(1);
	}
});

PeakMonitor(~master);

~master.stopRecord;

// recording:
~master.startRecord(thisProcess.platform.recordingsDir +/+ "feet%.aiff".format(Date.getDate.stamp));

~master.startRecord(thisProcess.platform.recordingsDir +/+ "arms%.aiff".format(Date.getDate.stamp));

~master.startRecord(thisProcess.platform.recordingsDir +/+ "head%.aiff".format(Date.getDate.stamp));

~master.startRecord(thisProcess.platform.recordingsDir +/+ "drums78seq-%.aiff".format(Date.getDate.stamp));

~master.startRecord(thisProcess.platform.recordingsDir +/+ "drone-%.aiff".format(Date.getDate.stamp));

~master.startRecord(thisProcess.platform.recordingsDir +/+ "torso-ssolo%.aiff".format(Date.getDate.stamp));

~master.startRecord(thisProcess.platform.recordingsDir +/+ "body%.aiff".format(Date.getDate.stamp));

~master.stopRecord;


/*
5:10 - B2500 - First Arm Axial Sequence
5:32 - B2510 - Restart of Axial Sequence
5:35 - B2520 - Locomotion
5:43 - B2530 - Moving Up From Triangle (Laura thought this worked better if it was triggered as she started to come up instead of when she stops)
5:53 - B2540 - 2nd Restart of Axial Sequence
5:55 - B2550 - Locomotion
6:18 - B2560 - Wild Arm Motions
*/

e = (play: { if(~proc != \rest) { BP(~proc).bus.set(99999) } });


~master.startRecord(thisProcess.platform.recordingsDir +/+ "body%.aiff".format(Date.getDate.stamp));

~seq.play;
p = Pseq([
	(proc: \rest, delta: 1),
	Pfindur(22, Pbind(
		\proc, \evTrig, 
		\delta, Pwhite(0.8, 1.2, inf) * Env(#[1, 1, 4], #[4, 18])
	)),
	Pbind(
		\proc, \segTrig,
		\delta, Pseq(#[3, 8, 10, 2, 23, 19, 1], 1)
	)
]).trace.play(protoEvent: e);

p.stop


~master.stopRecord;

BP(\mstClock).chan

BP.all.stop

BP(\mstClock).clock.tempo = 0.245;
BP(\hsd).play;
BP(\hsd).tophCtl.value = 32;
BP(\fmt).play;
BP(\mstClock).play;

BP.all.stop