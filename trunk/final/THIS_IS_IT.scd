// Affectations
// Main process loader

// This is so I can put section defs into separate files
// instead of having one massive navigation-hell file for the whole piece.


// this block loads everything: cursor on open-paren, then ctrl-alt-x
(
var	mypath = thisProcess.nowExecutingPath, indices;
if(BP.exists(\transports)) { BP(\transports).free };

s = Server.local;
s.waitForBoot {
	var	cond = Condition.new;
	(mypath.dirname.dirname +/+ "/common/common-defs.scd").debug.loadPath;
	NotificationCenter.registerOneShot(\lcrvb, \lcrvbexists, \feetSeq, {
		cond.unhang;
	});
	cond.hang;

	if(~master.mcgui.isNil) { MixingBoard(\arms, nil, ~master) };

	BP(\segTrig).free;
	PR(\busTrig).chuck(BP(\segTrig), nil, (message: '/segment'));
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
};
)



// DEBUG SNIPS

ChuckableBrowser.newWindow;

// if you need to clear everything, do this:
BP.all.do { |bp| if(bp.collIndex != \mstClock) { bp.free } }; VC.all.free;
if(BP.exists(\mstClock)) { BP(\mstClock).free };

~seq.sections.do(_.prUnload);

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