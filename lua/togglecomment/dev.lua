local function get_names(parser, query, text)
	local names = {}
	for id, node, metadata in query:iter_captures(parser:trees()[1]:root(), 0) do
		table.insert(names, vim.treesitter.get_node_text(node, text))
	end
	return names
end

local function translate(args)
	local from = args.line1-1
	local to = args.line2-1

	local lines = vim.api.nvim_buf_get_lines(0, from, to+1, false)
	local tc_query = table.concat(lines, "\n")
	local parser = vim.treesitter.get_string_parser(tc_query, "query")
	parser:parse()

	local field_query = vim.treesitter.query.parse("query", "(field_definition name: (identifier) @name)")
	local symbol_query = vim.treesitter.query.parse("query", "(named_node name: (identifier) @name)")
	local anon_symbol_query = vim.treesitter.query.parse("query", "(anonymous_node name: (string) @name)")

	local fields = get_names(parser, field_query, tc_query)
	local symbols = get_names(parser, symbol_query, tc_query)
	local anon_symbols = get_names(parser, anon_symbol_query, tc_query)

	tc_query = tc_query
	local str = ([=[{
	query = [[
		%s
	]],
	fields = %s,
	symbols = %s,
	anon_symbols = %s
},]=]):format(tc_query:gsub("\n", "\n\t\t"), vim.inspect(fields), vim.inspect(symbols), vim.inspect(anon_symbols))
	local ls = require("luasnip")
	ls.snip_expand(ls.s("", {
		ls.i(1, "name"), ls.t" = ", ls.t(vim.split(str, "\n"))
	}), {
		clear_region = {from = {from, 0}, to = {to, #lines[#lines]}},
		pos = {from, 0}
	})
end

-- togglecomment-query-create.
vim.api.nvim_create_user_command("TCQC", translate, {range = true})
