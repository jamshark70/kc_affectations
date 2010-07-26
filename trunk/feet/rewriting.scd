

Proto {
	~prep = { |pattern, levelPat, rules|
		if(pattern.estimateLength == inf) {
			Error("Pattern % supplied to rewriter is infinite!!!".format(pattern)).throw;
		};
		~pattern = pattern;
		~levelPat = levelPat;
		rules !? { ~rules = rules };
		currentEnvironment
	};

	~rules = [];
	~defaultRule = (nil -> { |in| in }).inspect;
	
	~embedInStream = { |inval|
		var	//inStream = ~pattern.asStream,
			levelStream = ~levelPat.asStream,
			level; //, outputs = List.new;
		
		block { |break|
			while { (level = levelStream.next(inval)).notNil } {
				inval = ~recurse.(inval, ~pattern.asStream, level/*, outputs*/);
			};
			inval
		};
	};

	~recurse = { |inval, inStream, level/*, outputs*/|
		var	rule;
// 		// mondo sucko that I have to hack into the List
// 		outputs.array = outputs.array.extend(max(level+1, outputs.size)).put(level, []);
// 		if(outputs[level-1].notNil) {
// 		} {
			if(level > 0) {
				r { |inval| ~recurse.(inval, inStream, level-1/*, outputs*/) }
				.do { |item|
					case
						{ (rule = ~rules.detect { |assn| assn.key.matchItem(item) }).notNil }
							{ inval = ~rewrite.(item, rule, inval, level) }
						{ ~defaultRule.key.matchItem(item) }
							{ inval = ~rewrite.(item, ~defaultRule, inval, level) }
							{ inval = item.embedInStream(inval) };
				};				
			} {
				inval = inStream.embedInStream(inval);
			}
// 		};
	};

	~rewrite = { |item, rule, inval, level|
		var	result = rule.value.value(item, level);
		//......
	};
} => PR(\rewriter);