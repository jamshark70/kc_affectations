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

