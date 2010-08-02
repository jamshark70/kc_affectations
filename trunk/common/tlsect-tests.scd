ChuckableBrowser.newWindow;

o = PR(\tlseg).copy.putAll((
	cmds: [
		funcCmd: (func: { "going...".postln }, dur: 1, clearDoneSignal: { "whoa nelly!".postln })
	]
));

u.remove;
u = Updater(o, { |...x| x.debug("updater") });

o.play;

o.listVars;

o.tlseq.dependants;
o.dependants;

o.stop;


o.freeCleanup;
o = PR(\sectDispatch).copy.prep.put(\sections, (
	f0: PR(\tlseg).copy.putAll((
		cmds: [
			funcCmd: (func: { "going...".postln }, dur: 10, clearDoneSignal: { "whoa nelly!".postln })
		]
	))
));

thisProcess.recvOSCmessage(Main.elapsedTime, NetAddr("127.0.0.1", 57121), ['/play', 'f0']);

o.listVars;

o.sections.f0.dependants