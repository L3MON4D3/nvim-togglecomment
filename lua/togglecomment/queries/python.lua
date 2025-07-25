return {
	expr_stmt = {
		query = [[
			(expression_statement) @togglecomment
		]],
		fields = {},
		symbols = { "expression_statement" },
		anon_symbols = {}
	},
	if_stmt = {
		query = [[
			(if_statement) @togglecomment
		]],
		fields = {},
		symbols = { "if_statement" },
		anon_symbols = {}
	},
	for_stmt = {
		query = [[
			(for_statement) @togglecomment
		]],
		fields = {},
		symbols = { "for_statement" },
		anon_symbols = {}
	},
	class = {
		query = [[
			(class_definition) @togglecomment
		]],
		fields = {},
		symbols = { "class_definition" },
		anon_symbols = {}
	},
	fdef = {
		query = [[
			(function_definition) @togglecomment
		]],
		fields = {},
		symbols = { "function_definition" },
		anon_symbols = {}
	},
} --[[@as {[string]: Togglecomment.QueryDef}]]
