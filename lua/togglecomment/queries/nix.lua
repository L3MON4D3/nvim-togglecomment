return {
	binding = {
		query = [[
			(binding) @togglecomment
		]],
		fields = {},
		symbols = { "binding" },
		anon_symbols = {}
	},
	formal = {
		query = [[
			(formal) @togglecomment
		]],
		fields = {},
		symbols = { "formal" },
		anon_symbols = {}
	},
	attrset_expr = {
		query = [[
			(attrset_expression @togglecomment)
		]],
		fields = {},
		symbols = { "attrset_expression" },
		anon_symbols = {}
	},
} --[[@as {[string]: Togglecomment.QueryDef}]]
