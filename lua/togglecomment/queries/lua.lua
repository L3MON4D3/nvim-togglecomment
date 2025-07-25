return {
	name = {
		query = [[
			(variable_declaration) @togglecomment
		]],
		fields = {},
		symbols = { "variable_declaration" },
		anon_symbols = {}
	},
	fdec = {
		query = [[
			(function_declaration) @togglecomment
		]],
		fields = {},
		symbols = { "function_declaration" },
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
	while_stmt = {
		query = [[
			(while_statement) @togglecomment
		]],
		fields = {},
		symbols = { "while_statement" },
		anon_symbols = {}
	},
	return_stmt = {
		query = [[
			(return_statement) @togglecomment
		]],
		fields = {},
		symbols = { "return_statement" },
		anon_symbols = {}
	},
	root_assignment = {
		query = [[
			; make sure assignment-statement does not work in (local_declaration
			; (assignment_statement)), only if it is a top-level statement, or in a body.
			( (assignment_statement) @togglecomment (#togglecomment-root-child? @togglecomment) )
		]],
		fields = {},
		symbols = { "assignment_statement" },
		anon_symbols = {}
	},
	block_assignment = {
		query = [[
			(block (assignment_statement) @togglecomment)
		]],
		fields = {},
		symbols = { "block", "assignment_statement" },
		anon_symbols = {}
	},
	fcall = {
		query = [[
			; same as assignment-statement, only allow commenting function-calls if they're
			; not part of an assignment.
			( (function_call) @togglecomment (#togglecomment-root-child? @togglecomment) )
		]],
		fields = {},
		symbols = { "function_call" },
		anon_symbols = {}
	},
	block_fcall = {
		query = [[
			(block (function_call) @togglecomment)
		]],
		fields = {},
		symbols = { "block", "function_call" },
		anon_symbols = {}
	},
	field = {
		query = [[
			(field) @togglecomment
		]],
		fields = {},
		symbols = { "field" },
		anon_symbols = {}
	},
	field_comma = {
		query = [[
			; comment field and , together.
			(
			  ((field) @f . "," @sep)
			  (#togglecomment-make-tc-range! @f "start" 0 0 @sep "end" 0 0)
			)
		]],
		fields = {},
		symbols = { "field" },
		anon_symbols = { '","' }
	},
} --[[@as {[string]: Togglecomment.QueryDef}]]
