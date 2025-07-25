return {
	named_node = {
		query = [[
			(named_node) @togglecomment
		]],
		fields = {},
		symbols = { "named_node" },
		anon_symbols = {}
	},
	grouping = {
		query = [[
			(grouping) @togglecomment
		]],
		fields = {},
		symbols = { "grouping" },
		anon_symbols = {}
	},
	predicate = {
		query = [[
			(predicate) @togglecomment
		]],
		fields = {},
		symbols = { "predicate" },
		anon_symbols = {}
	},
	list = {
		query = [[
			(list) @togglecomment
		]],
		fields = {},
		symbols = { "list" },
		anon_symbols = {}
	},
} --[[@as {[string]: Togglecomment.QueryDef}]]
