return {
	var_decl = {
		query = [[
			(variable_declaration) @togglecomment
		]],
		fields = {},
		symbols = { "variable_declaration" },
		anon_symbols = {}
	},
	expr_stmt = {
		query = [[
			(expression_statement) @togglecomment
		]],
		fields = {},
		symbols = { "expression_statement" },
		anon_symbols = {}
	},
	test_decl = {
		query = [[
			(test_declaration) @togglecomment
		]],
		fields = {},
		symbols = { "test_declaration" },
		anon_symbols = {}
	},
	fdecl = {
		query = [[
			(function_declaration) @togglecomment
		]],
		fields = {},
		symbols = { "function_declaration" },
		anon_symbols = {}
	},
} --[[@as {[string]: Togglecomment.QueryDef}]]
