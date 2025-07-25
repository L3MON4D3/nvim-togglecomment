local M = {}
local data = require("togglecomment.session.data")
local unicode_symbols = require("togglecomment.unicode_symbols")
local LinecommentDef = require("togglecomment.linecomment").LinecommentDef
local BlockcommentDef = require("togglecomment.blockcomment").BlockcommentDef
local util = require("togglecomment.util")
local notify = require("togglecomment.util.notify")

local function validate_queries(lang, query_defs, disabled_queries)
	local lang_exists, lang_info = pcall(vim.treesitter.language.inspect, lang)
	if not lang_exists then
		return nil
	end

	local valid_queries = {}

	local valid_fields = util.list_to_set(lang_info.fields)
	local valid_symbols = lang_info.symbols
	for query_name, query_def in pairs(query_defs) do
		if disabled_queries[query_name] then
			goto continue
		end

		local parser_compatible = true
		for _, anon_symbol in ipairs(query_def.anon_symbols) do
			if valid_symbols[anon_symbol] ~= false then
				notify.warn("query %s requires anonymous symbol %s which is not provided by the parser for %s.", query_def.query, anon_symbol, lang)
				parser_compatible = false
			end
		end
		for _, symbol in ipairs(query_def.symbols) do
			if valid_symbols[symbol] ~= true then
				notify.warn("query %s requires symbol %s which is not provided by the parser for %s.", query_def.query, symbol, lang)
				parser_compatible = false
			end
		end
		for _, field in ipairs(query_def.fields) do
			if valid_fields[field] == nil then
				notify.warn("query %s requires field %s which is not provided by the parser for %s.", query_def.query, field, lang)
				parser_compatible = false
			end
		end

		if not parser_compatible then
			notify.warn("query %s is incompatible with the current parser for parser for %s, disabling it.", query_def.query, lang)
		else
			table.insert(valid_queries, ([[
				(
					%s
					(#set! "togglecomment_id" "%s.%s")
				)
			]]):format(query_def.query, lang, query_name))
		end

		::continue::
	end

	local ok, query = pcall(vim.treesitter.query.parse, lang, table.concat(valid_queries, "\n"))
	if not ok then
		notify.warn("Error while parsing query: %s", query)
		return nil
	else
		return query
	end
end

local default_config = {
	linecomment = {
		prefixes = {
			bash = "#",
			python = "#",
			julia = "#",
			nix = "#",
			query = ";",
			lua = "--",
			cpp = "//",
			latex = "%",
			zig = "//",
			vim = "\""
		},
		spaces = {
			from = unicode_symbols.spaces.en_quad,
			connect = unicode_symbols.spaces.em_quad,
			to = unicode_symbols.spaces.en_space,
			singleline = unicode_symbols.spaces.em_space,
		}
	},
	blockcomment = {
		defs = {
			lua = { [===[--[=[ ]===], [===[ ]=]]===] },
			xml = { "<!-- ", " -->", comment_query_def = {
				query = "(Comment) @comment",
				fields = {},
				symbols = { "Comment" },
				anon_symbols = {}
			}},
			cpp = { "/* ", " */"},
			typst = { "/* ", " */"},
			markdown = { "<!-- ", " -->", comment_query_def = {
				query = "((html_block) @comment (#trim! @comment 1 1 1 1) (#match? @comment \"^<!--\"))",
				fields = {},
				symbols = { "html_block" },
				anon_symbols = {}
			}},
			markdown_inline = { "<!-- ", " -->", comment_query_def = {
				query = "((html_tag) @comment (#trim! @comment 1 1 1 1) (#match? @comment \"^<!--\"))",
				fields = {},
				symbols = { "html_tag" },
				anon_symbols = {}
			}},
			html = {"<!-- ", " -->"}
		},
		-- have to have same length.
		placeholder_open = unicode_symbols.misc_symbols.left_ceiling .. unicode_symbols.spaces.braille_blank,
		placeholder_close = unicode_symbols.spaces.braille_blank .. unicode_symbols.misc_symbols.right_floor
	},
	disabled_plugin_queries = nil
}

local default_comment_query_def = {
	query = "((comment) @comment (#trim! @comment 1 1 1 1))",
	fields = {},
	symbols = { "comment" },
	anon_symbols = {}
}

function M.setup(config)
	local lc_prefixes = vim.tbl_extend("keep", vim.tbl_get(config, "linecomment", "prefixes") or {}, default_config.linecomment.prefixes)
	local lc_spaces = vim.tbl_extend("keep", vim.tbl_get(config, "linecomment", "spaces") or {}, default_config.linecomment.spaces)

	local user_prefixes = vim.tbl_get(config, "blockcomment", "prefixes") or {}
	for _, prefixdef in pairs(user_prefixes) do
		if prefixdef.comment_query then
			-- we treat a query provided by the user as always compatible with
			-- their parser.
			prefixdef.comment_query_def = {
				query = prefixdef.comment_query,
				fields = {},
				symbols = {},
				anon_symbols = {}
			}
			prefixdef.comment_query = nil
		end
	end

	local bc_prefixes = vim.tbl_extend("keep", user_prefixes, default_config.blockcomment.defs)
	local bc_open = vim.tbl_get(config, "blockcomment", "placeholder_open") or default_config.blockcomment.placeholder_open
	local bc_close = vim.tbl_get(config, "blockcomment", "placeholder_close") or default_config.blockcomment.placeholder_close

	local disabled_queries = config.disabled_plugin_queries or {}

	-- validate

	for k, v in pairs(lc_spaces) do
		local next_k = k
		while true do
			local next_v
			next_k, next_v = next(lc_spaces,next_k)
			if not next_k then
				break
			end
			if v == next_v then
				error(("space-characters %s and %s are represented by the same codepoint"):format(k, next_k))
			end

			if #v ~= #next_v then
				error(("space-characters %s and %s have inequal byte-length."):format(k, next_k))
			end
		end
	end

	if #bc_open ~= #bc_close then
		error("placeholder_open and placeholder_close have different lengths.")
	end

	data.linecomment_defs = vim.tbl_map(function(commentstring)
		return LinecommentDef.new(lc_spaces, commentstring)
	end, lc_prefixes)

	local function build_query(lang)
		-- all plugin-queries disabled.
		if disabled_queries[lang] == true then
			return nil
		end

		local lang_exists, lang_info = pcall(vim.treesitter.language.inspect, lang)
		if not lang_exists then
			return nil
		end

		local query_modulepath = "togglecomment.queries." .. lang
		local module_exists, queries = pcall(require, query_modulepath)
		if not module_exists then
			return nil
		end

		return validate_queries(lang, queries, disabled_queries[lang] or {})
	end

	-- these two emit logs for unsupported languages and generally do a bit of
	-- work (and also need all parsers to be loaded, which, if the parsers are
	-- lazy-loaded somehow, may not be the case if this is executed).
	-- Therefore, only load them when actually requested, lazily, and not
	-- eagerly on `setup`.
	data.queries = setmetatable({}, {
		__index = function(t,k)
			local query = build_query(k)
			-- set false for missing query, so we don't have to redo the
			-- checks for determining if the query or parser exists.
			rawset(t, k, vim.F.if_nil(query, false))
			return query
		end
	})

	data.blockcomment_defs = setmetatable({}, {
		__index = function(t,k)
			local bc_def = bc_prefixes[k]
			if bc_def then
				local bc_query = validate_queries(k, {comment = bc_def.comment_query_def or default_comment_query_def}, {})
				if bc_query then
					local res = BlockcommentDef.new(bc_def[1], bc_def[2], bc_open, bc_close, bc_query)
					rawset(t,k,res)
					return res
				end
			end

			rawset(t,k,false)
			return false
		end
	})
end

-- set default values.
function M.initialize()
	M.setup({})
end

return M
