// affectations needs a simpler segment object

Proto {
	~name = "";		// to display in GUI
	~status = \idle;
	~autoSync = true;	// passed into TLSequenceIterator
	~clock = TempoClock.default;
	~tlPlayTime = 0;
	~cmds = nil;	// array with list of commands

	~isLoaded = false;

		// parent will call this one
		// IT IS UP TO THE PARENT to know when to load/unload resources
	~prInitProc = {
		if(~isLoaded.not) {
			~initProcesses.();
			~isLoaded = true;
		};
	};
	
	~prUnload = {
		if(~isLoaded) {
			~unloadProcesses.();
			~isLoaded = false;
		};
	};

	~initProcesses = nil;		// user-supplied function to load resources
	~unloadProcesses = nil;

	~play = { |savedCmds|
		if(~isRunning.().not) {
			~savedCmds = savedCmds;
//savedCmds.debug("segment:play - savedcmds");
			~clock ?? { ~clock = TempoClock.default };
			~preparePlay.();
			~tlseq = ~makeSeq.(savedCmds);
//~clock.tempo.debug("segment %'s tempo".format(~name));
			~tlseq.play(~tlPlayTime, ~clock, savedCmds);
			~tlseq.addDependant(currentEnvironment);
			~status = \running;
			currentEnvironment.changed(\play);
			~schedDone.();
		};
	};
// 	~schedDone = {
// 		var	now = thisThread.clock.beats;
// 		if(~dur.notNil) {
// 			~clock.sched(~dur - 0.001, e { ~stop.(now + ~dur) });
// 		}	// else, there should be a user input trigger to move to the next segment
// 	};
	~stop = { |notifyTime, manualStop = true|
		if(~isRunning.()) {
			~status = \idle;
			~tlseq.removeDependant(currentEnvironment);
			~currentIterator.stop((manualStop: manualStop ? true));
			~done.();
			~clearDoneSignal.();
			~clock.schedAbs((notifyTime ?? { ~clock.beats }), e {
//~clock.beats.debug("sending done notification at");
//~savedCmds.debug("with these saved commands");
				currentEnvironment.changed(\done, ~savedCmds);
			});
		};
		currentEnvironment
	};
	~done = {
	};

	~makeSeq = {
		TLSequenceIterator(~cmds, nil, ~autoSync);
	};

	~isRunning = { ~status != \idle };
	
	~update = { |obj, what, args|
//[obj, what, args].debug("segment % received update".format(~name));
		if(obj === ~tlseq) {
			switch(what)
				{ \done } {
					obj.removeDependant(currentEnvironment);
						// iterator might remove commands after this happens
					~savedCmds = args.copy;
					~stop.();
				}
		};
			// a command might send a notification that's really meant for the segment sequencer
			// it can set the passthru flag
			// try returns nil if there's an error
		if(try { args[\passthru] } == true) {
			currentEnvironment.changed(what, args)
		};
	};

} => PR(\tlseg);


Proto {
	~segments = ();  // your dictionary of segments
	// NO slashes; OSCresponders will have slashes in cmd names
	~messages = #[load, play];
	~currentSect = nil;
	~addr = nil;
	~prep = {
		~resp = ~messages.collect { |osccmd|
			OSCresponderNode(~addr, ("/" ++ osccmd).asSymbol, e { |time, resp, msg, addr|
				osccmd.envirGet.value(time, resp, msg, addr)
			}).add;
		};
		currentEnvironment
	};
	~freeCleanup = {
		~resp.do(_.remove);
		// probably dodgy, that
		currentEnvironment.releaseFromDependencies;
	};

	~load = { |time, resp, msg, addr|
		if(~segments[msg[1].asSymbol].notNil) {
			~segments[msg[1].asSymbol].prInitProc;
		} {
			"Segment % not found (load).".format(msg[1]).warn;
			addr.sendMsg('/segNotFound', msg[1], \load);
		};
	};

	~play = { |time, resp, msg, addr|
		if(~segments[msg[1].asSymbol].notNil) {
			if(~currentSect.notNil) {
				~currentSect.stop;
			};
			~currentSect = ~segments[msg[1].asSymbol];
			~currentSect.addDependant(currentEnvironment);
			~currentSect.play;
		} {
			"Segment % not found (play).".format(msg[1]).warn;
			addr.sendMsg('/segNotFound', msg[1], \play);
		};
	};

	~update = { |obj, what, args|
		if(what == \done) {
			if(~currentSect === obj) {
				~currentSect = nil;
			};
			obj.removeDependant(currentEnvironment);
		};
	};
} => PR(\sectDispatch);