// use Lorne's osc log

// run this block first, then skip to the bottom for more instructions
(
PR(\abstractProcess).clone {
	~event = (
		play: {
			s.sendMsg(\c_set, ~bus, ~value)
		}
	);
	~sampDir = topEnvironment[\sampleDir];
	~filename = "OSC-110320-1955.log";
	~startAt = 2000;
	~alwaysReset = true;
	~quant = 0;
	~prep = {
		~array = CSVFileReader.read(~sampDir +/+ ~filename);
		~array = ~array.select { |row| row[1] == " SEND" }
			.collect { |row|
				#[0, 2, 3].do { |i| row[i] = row[i].asFloat };
				row
			};
		~clock = TempoClock.new(1);
	};
	~freeCleanup = { ~clock.stop };

	~asPattern = {
		var	i = ~array.detectIndex { |row| row.last == ~startAt },
			flopped;
		if(i.isNil) {
			"Couldn't find %; starting at the beginning".format(~startAt).warn;
			i = 0;
		};
		flopped = ~array[i..].flop;
		flopped.do { |stream| stream.postcs };
		Pbind(
			\delta, Pdiff(Pseq(flopped[0] ++ 273645.1549, 1)),
			\bus, Pseq(flopped[2]),
			\value, Pseq(flopped[3])
		).trace
	};
	~stopCleanup = {
		topEnvironment[\seq].stop;
	};
} => PR(\osclogplayer);

BP(\osclog).free;
PR(\osclogplayer) => BP(\osclog);
~seq[\doNotReset] = #[osclog];
~seq.oscLoggingOn = false;
)


// to set the segment number to start playing:
// change the number after "startAt = "
// then run this block
(
var i;

BP(\osclog).startAt = 1;
i = ~seq.sections.detectIndex({ |sect| sect.segID == BP(\osclog).startAt });
if(i.isNil) {
	"Segment % doesn't exist, try again".format(BP(\osclog).startAt).warn; ""
} {
	~seq.gotoSection(i);
};
)


// GO
BP(\osclog).play(0);


// stop -- make sure to stop HERE!
BP(\osclog).stop(0);
