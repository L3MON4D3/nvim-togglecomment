local M = {}
local data = require("togglecomment.session.data")
local unicode_symbols = require("togglecomment.unicode_symbols")
local LinecommentDef = require("togglecomment.linecomment").LinecommentDef
local BlockcommentDef = require("togglecomment.blockcomment").BlockcommentDef

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
			vim = "\")"
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
			xml = { "<!-- ", " -->", comment_query = "(Comment) @comment"},
			cpp = { "/* ", " */"},
			markdown = { "<!-- ", " -->", comment_query = "((html_block) @comment (#trim! @comment 1 1 1 1) (#match? @comment \"^<!--\"))" },
			markdown_inline = { "<!-- ", " -->", comment_query = "((html_tag) @comment (#trim! @comment 1 1 1 1) (#match? @comment \"^<!--\"))" },
			html = {"<!-- ", " -->", comment_query = "(comment) @comment"}
		},
		-- have to have same length.
		placeholder_open = unicode_symbols.misc_symbols.left_ceiling .. unicode_symbols.spaces.braille_blank,
		placeholder_close = unicode_symbols.spaces.braille_blank .. unicode_symbols.misc_symbols.right_floor
	}
}

function M.setup(config)
	local lc_prefixes = vim.tbl_extend("keep", vim.tbl_get(config, "linecomment", "prefixes") or {}, default_config.linecomment.prefixes)
	local lc_spaces = vim.tbl_extend("keep", vim.tbl_get(config, "linecomment", "spaces") or {}, default_config.linecomment.spaces)

	local bc_prefixes = vim.tbl_extend("keep", vim.tbl_get(config, "blockcomment", "prefixes") or {}, default_config.blockcomment.defs)
	local bc_open = vim.tbl_get(config, "blockcomment", "placeholder_open") or default_config.blockcomment.placeholder_open
	local bc_close = vim.tbl_get(config, "blockcomment", "placeholder_close") or default_config.blockcomment.placeholder_close

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

	data.blockcomment_defs = vim.tbl_map(function(commentstrings)
		return BlockcommentDef.new(commentstrings[1], commentstrings[2], bc_open, bc_close, commentstrings.comment_query or "((comment) @comment (#trim! @comment 1 1 1 1))")
	end, bc_prefixes)
end

-- set default values.
function M.initialize()
	M.setup({})
end

return M
