// Affectations
// Main process loader

// This is so I can put section defs into separate files
// instead of having one massive navigation-hell file for the whole piece.

// BP.loadGui;  // <-- this is for James's development work - no need in the performance


// this block loads everything: cursor on open-paren, then ctrl-alt-x
(
var	mypath = thisProcess.nowExecutingPath, indices;
if(BP.exists(\transports)) { BP(\transports).free };

value {
	var p = Pipe("hostname", "r"), l;
	Library.at(\isJamesBox) ?? {
		try {
			if(p.isOpen) {
				l = p.getLine;
				if(l.notNil) { Library.put(\isJamesBox, l.contains("dlm")) }
				{ Library.put(\isJamesBox, false) };
			};
			p.close;
		} { p.tryPerform(\close) };  // make sure pipe gets closed even on error
	};
};

s = Server.local;
s.waitForBoot {
	var	cond = Condition.new;

	// s.controlBusAllocator.reserve(4000, 96, warn: false);
	if(s.controlBusAllocator.size != 4000) {
		s.controlBusAllocator = ContiguousBlockAllocator(4000, 0);
	};

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

			~eventTrigsWaiting = IdentityDictionary.new;

			~playStopResp = OSCresponderNode(s.addr, ~message, e { |time, resp, msg|
				var	sectI, sect, ssq = topEnvironment[\seq], initted;
				case
					{ msg[3].inclusivelyBetween(1, 99999) and: { ssq.isRunning.not } } {
						sectI = ssq.sections.detectIndex { |sct| sct.segID == msg[3] };
						if(sectI.isNil) {
							"Segment % doesn't exist; ignored.".format(msg[3]).warn;
						} {
							sect = ssq.sections[sectI];
							initted = sect.isLoaded;
							ssq.gotoSection(sectI);
							if(initted) {
								ssq.play
							} {
								fork {
									2.0.wait;  // maybe not enough, but...
									ssq.play
								}
							};
						}
					}
					{ msg[3] == 100000 and: { ssq.isRunning } } {
						ssq.stop;
					};
			}).add;
		},
		userfree: { (e { ~window.close }).defer; ~playStopResp.remove },
		eventActive: { |cmd, action, eventID(1)|
			if(cmd.notNil) {
				if(~eventTrigsWaiting[eventID].isNil) {
					~eventTrigsWaiting[eventID] = [cmd, action];
					// ~eventTrigCmd = cmd;
					// ~eventTrigAction = action;
				} {
					Exception("event trigger with id % is already active: can't register new event"
						.format(eventID)).throw;
				}
			} {
				~eventTrigsWaiting[eventID] = nil
			};
			(e { ~eventBtn.enabled = ~eventTrigsWaiting.notEmpty }).defer;
		},
		eventTrigAction: {
			// no id given through GUI: fire earliest (lowest ID) event
			// if(~eventTrigsWaiting.notEmpty) {
			// 	~eventTrigsWaiting[~eventTrigsWaiting.keys.minItem].[1].value
			// };
			~eventTrigsWaiting.copy.do { |eventTrig| eventTrig[1].value };
		},
		eventTrigCmdByID: { |eventID| ~eventTrigsWaiting[eventID][0] },
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
	.do { |path|
		var	result = path.loadPath;
		if(result.isNil) { Error("Section % failed to load".format(path.basename)).throw };
		indices = indices.add(~sections.size);
		~sections = ~sections ++ result;
	};

	~seq = PR(\affSectSeq).copy.sections_(~sections).startLoadingAt_(indices);

	~seq.loadResources(0);
	PR(\transports).chuck(BP(\transports), nil, (model: ~seq));

	BP(\transports).userfree = { |bp, what|
		topEnvironment[\seq].releaseDependants;
		BP(#[segTrig, evTrig]).debug("freeing").free;
	};

	if(d.notNil) {
		~timerUpdater = Updater(~seq, e { |obj, what|
			switch(what)
				{ \play } { d.reset }
		});
	};
};
)



// DEBUG SNIPS

ChuckableBrowser.newWindow;

MT(1).gui;

BP.all.stop;

d = DDWTimer.new;


// if you need to clear everything, do this:
BP.all.do { |bp| if(#[mstClock, di, traj].includes(bp.collIndex).not) { bp.free } }; VC.all.free;
if(BP.exists(\mstClock)) { BP(\mstClock).free };
if(BP.exists(\di)) { BP(\di).free };
if(BP.exists(\traj)) { BP(\traj).free };

[~glrvb, ~lcrvb, ~cavernousRvb].do(_.run(false)); [~glrvbmc, ~lcrvbmc, ~cRvbMc].do(_.mute(true));
[~glrvb, ~lcrvb, ~cavernousRvb].do(_.run(true)); [~glrvbmc, ~lcrvbmc, ~cRvbMc].do(_.mute(false));

~seq.sections.do(_.prUnload);


// test note data sending
~oscRecvFile = File("sent_osc_" ++ Date.localtime.stamp, "w");

o.do(_.remove);
o = #['/note', '/perc'].collect { |key|
	OSCresponderNode(nil, key, 
		if(~oscRecvFile.tryPerform(\isOpen) ? false) { e { |t, r, m| ~oscRecvFile << ([t] ++ m) << Char.nl } }
		{ e { |t, r, m| Post <<* ([t] ++ m) << Char.nl } }
	).add;
};

~oscRecvFile.close;

sent_osc_110208_145746

NetAddr.localAddr


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
	case
	{ num < 60 } {
		BP(\segTrig).bus.set(99999);
	}
	{ num == 72 } {
		BP(\evTrig).bus.set(2);
	}
	{ BP(\evTrig).bus.set(1) };
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


o.do(_.remove);
o = #['/eventTrig', '/segTrig', '/nowPlaying'].collect { |key|
	OSCresponderNode(nil, key, { |t, r, m| m.postln }).add
};

NetAddr.localAddr