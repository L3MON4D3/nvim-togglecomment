return {
	section = {
		query = [[
			(
			  (section) @togglecomment
			 (#trim! @togglecomment 1 1 1 1)
			)
		]],
		fields = {},
		symbols = { "section" },
		anon_symbols = {}
	},
	paragraph = {
		query = [[
			(
			  (paragraph) @togglecomment
			 (#trim! @togglecomment 1 1 1 1)
			)
		]],
		fields = {},
		symbols = { "paragraph" },
		anon_symbols = {}
	},
	fenced_code_block = {
		query = [[
			(
			  (fenced_code_block) @togglecomment
			 (#trim! @togglecomment 1 1 1 1)
			)
		]],
		fields = {},
		symbols = { "fenced_code_block" },
		anon_symbols = {}
	},
} --[[@as {[string]: Togglecomment.QueryDef}]]
