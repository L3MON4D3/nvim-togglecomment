return {
	echom = {
		query = [[
			(echomsg_statement) @togglecomment
		]],
		fields = {},
		symbols = { "echomsg_statement" },
		anon_symbols = {}
	},
	set = {
		query = [[
			(set_statement) @togglecomment
		]],
		fields = {},
		symbols = { "set_statement" },
		anon_symbols = {}
	},
	source = {
		query = [[
			(source_statement) @togglecomment
		]],
		fields = {},
		symbols = { "source_statement" },
		anon_symbols = {}
	},
	augroup = {
		query = [[
			(augroup_statement) @togglecomment
		]],
		fields = {},
		symbols = { "augroup_statement" },
		anon_symbols = {}
	},
	autocmd = {
		query = [[
			(autocmd_statement) @togglecomment
		]],
		fields = {},
		symbols = { "autocmd_statement" },
		anon_symbols = {}
	},
} --[[@as {[string]: Togglecomment.QueryDef}]]
