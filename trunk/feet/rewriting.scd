// h. james harkins

(
Proto {
	~rules = [];
	~defaultRule = (nil -> { |in| in });
	~autoStreamArrays = true;
	~keepLowerLevels = false;
	
	~prep = { |pattern, levelPat, rules|
// 		if(pattern.estimateLength == inf) {
// 			Error("Pattern (%) supplied to rewriter is infinite!!!".format(pattern)).throw;
// 		};
		~pattern = pattern;
		~levelPat = levelPat;
		rules !? { ~rules = rules };
		currentEnvironment
	};

	~embedInStream = { |inval|
		var	levelStream = ~levelPat.asStream,
			level, outputs = List.new;
		while { (level = levelStream.next(inval)).notNil } {
			inval = ~recurse.(inval, ~pattern.asStream, level, outputs);
		};
		inval
	};

	~recurse = { |inval, inStream, level, outputs|
		var	rule;
		if(~keepLowerLevels and: { outputs[level].notNil }) {
			inval = Pseq(outputs[level], 1).embedInStream(inval);
		} {
			// mondo sucko that I have to hack into the List
			outputs.array = outputs.array.extend(max(level+1, outputs.size));
			outputs[level] = List.new;
			if(level > 0) {
				r { |inval| ~recurse.(inval, inStream, level-1, outputs) }
				.do { |item|
					case
						{ (rule = ~rules.detect { |assn| assn.key.matchItem(item) }).notNil }
							{ inval = ~rewrite.(item, rule, inval, level, outputs) }
						{ ~defaultRule.key.matchItem(item) }
							{ inval = ~rewrite.(item, ~defaultRule, inval, level, outputs) }
							{ outputs[level].add(item); inval = item.embedInStream(inval) };
				};
			} {
				inval = inStream.collect { |item|
					outputs[level].add(item);
					item
				}.embedInStream(inval);
			};
		};
		inval
	};

	~rewrite = { |item, rule, inval, level, outputs|
		var	result = rule.value.value(item, level, inval);
		if(~autoStreamArrays and: { result.isSequenceableCollection }) {
			result = Pseq(result, 1);
		};
		inval = result.asStream.collect { |item| outputs[level].add(item); item }.embedInStream(inval);
	};
	~canEmbed = true;  // allow the Proto to act as a pattern
	~asStream = { |inval|
		r { ~embedInStream.(inval) }
	};
} => PR(\rewriter);
)

(
p = PR(\rewriter).copy
	.starter_(Pseries(0, 1, inf).asStream)
	.prep(Pfuncn { ~starter.next }, Pseries(0, 1, inf), [
		_.isNumber -> { |x, lev| [x, x + (rrand(1, 9) * (10 ** lev))] }
	]);

p.keepLowerLevels = false;  // try with 'true' also
q = p.asStream;
)

q.next;

20.do { q.next.postln }; ""


MIDIPort.init([2]);
MIDIPort.resetAll;

(
[m, n].free;
m = MixerChannel(\test1, s, 1, 2);
n = MixerChannel(\test2, s, 2, 2);
//MixingBoard(\test, nil, m, n);

b = MixingBoard.new;
8.do { |i|
	MixerChannelGUI.new(nil, b) => MCG.prNew(i);
	if(MIDIPort.initialized) {
		MixerMIDIControl(\omni, nil, MCG(i).v);
	};
	b.add(MCG(i).v);
};

m => MCG(0); n => MCG(1);
//~master => MCG(7);

{ MixingBoard.at(0).refresh }.defer(3.0);
)

// in case I forgot to init midi first
8.do { |i| MixerMIDIControl(\omni, nil, MCG(i).v); };


PR(\rewriter).listMethods;

q = PR(\rewriter).copy.prep(Ptuple([Pseq([4, 7, 6], 1), 0], 1), Pseries(0, 1, inf), [
	{ true } -> { |in, level|
		Ptuple([
			Pseq(([in[0]] ++ ({ #[-2, -1, 1, 2].choose } ! 2)).integrate, 1),
			Pseq([in[1], Pn(level, inf)], 1)
		], 1)
	}
]).keepLowerLevels_(true)
.asStream;

q.next;


(
f = { |int, in, level|
	if(int.every(_.inclusivelyBetween(-10, 10))) {
		Ptuple([
			Pseq(int, 1),
			Pseq([in[1], Pn(level+1, inf)], 1)
		], 1)
	} {
		Pn([0, 0], 0)	// <-- drop this branch totally
	}
};
p = n.play(Pbind(
	\root, 7,
	\octave, 5,
	#[degree, level], PR(\rewriter).copy.prep(Ptuple([Pseq([4, 7, 6], 1), 1], 1), Pseries(0, 1, inf), [
		{ |in| in[0] < 0 } -> { |in, level|
			var int = if(0.7.coin) { #[3, -1].debug(">>> add motive") }
				{ { #[-1, 1, 2, 3].choose } ! rrand(1, 2) };
			f.(([in[0]] ++ int).integrate, in, level);
		},
		{ |in| in[0] > 14 } -> { |in, level|
			var int = if(0.1.coin) { #[3, -1].debug(">>> add motive") }
				{ { #[-3, -2, -1, 1].choose } ! rrand(1, 2) };
			f.(([in[0]] ++ int).integrate, in, level);
		},
		{ true } -> { |in, level|
			var int = if(0.45.coin) { #[3, -1].debug(">>> add motive") }
				{ { #[-2, -1, 1, 2].choose } ! rrand(1, 2) };
			f.(([in[0]] ++ int).integrate, in, level);
		}
	]).keepLowerLevels_(true).asStream.trace,
	\dur, 0.5 / Pkey(\level),
	\legato, Pkey(\level).linexp(1, 5, 2, 0.8, clip: \none),
	\amp, 0.4 / Pkey(\level)
));
)

p.stop;
