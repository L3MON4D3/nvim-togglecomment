return {
	macrocall = {
		query = [[
			(macrocall_expression) @togglecomment
		]],
		fields = {},
		symbols = { "macrocall_expression" },
		anon_symbols = {}
	},
	struct = {
		query = [[
			(struct_definition) @togglecomment
		]],
		fields = {},
		symbols = { "struct_definition" },
		anon_symbols = {}
	},
	assignment = {
		query = [[
			(assignment) @togglecomment
		]],
		fields = {},
		symbols = { "assignment" },
		anon_symbols = {}
	},
	call = {
		query = [[
			(call_expression) @togglecomment
		]],
		fields = {},
		symbols = { "call_expression" },
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
	for_stmt = {
		query = [[
			(for_statement) @togglecomment
		]],
		fields = {},
		symbols = { "for_statement" },
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
	local_stmt = {
		query = [[
			(local_statement) @togglecomment
		]],
		fields = {},
		symbols = { "local_statement" },
		anon_symbols = {}
	},
	compound_assignment = {
		query = [[
			(compound_assignment_expression) @togglecomment
		]],
		fields = {},
		symbols = { "compound_assignment_expression" },
		anon_symbols = {}
	},
} --[[@as {[string]: Togglecomment.QueryDef}]]
