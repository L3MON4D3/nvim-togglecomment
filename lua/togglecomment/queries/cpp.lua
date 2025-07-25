return {
	struct = {
		query = [[
			(translation_unit
			  (struct_specifier) @togglecomment )
		]],
		fields = {},
		symbols = { "translation_unit", "struct_specifier" },
		anon_symbols = {}
	},
	template = {
		query = [[
			(translation_unit
			  (template_declaration) @togglecomment )
		]],
		fields = {},
		symbols = { "translation_unit", "template_declaration" },
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
	expr = {
		query = [[
			(expression_statement) @togglecomment
		]],
		fields = {},
		symbols = { "expression_statement" },
		anon_symbols = {}
	},
	decl = {
		query = [[
			(declaration) @togglecomment
		]],
		fields = {},
		symbols = { "declaration" },
		anon_symbols = {}
	},
	field = {
		query = [[
			(field_declaration) @togglecomment
		]],
		fields = {},
		symbols = { "field_declaration" },
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
			((class_specifier) . ";" . ) @togglecomment
		]],
		fields = {},
		symbols = { "class_specifier" },
		anon_symbols = { '";"' }
	},
	["<<"] = {
		query = [[
			(binary_expression
			  operator: "<<" @op
			  right: (_) @rhs
			  (#togglecomment-make-tc-range! @op "start" 0 0 @rhs "end" 0 0)
			)
		]],
		fields = { "operator", "right" },
		symbols = { "binary_expression" },
		anon_symbols = { '"<<"' }
	},
} --[[@as {[string]: Togglecomment.QueryDef}]]
