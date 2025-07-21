local M = {}
local data = require("togglecomment.session.data")
local unicode_symbols = require("togglecomment.unicode_symbols")
local LinecommentDef = require("togglecomment.prefixcomment").LinecommentDef

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
}

function M.set_config(config)
	local lc_prefixes = vim.tbl_extend("keep", vim.tbl_get(config, "linecomment", "prefixes") or {}, default_config.linecomment.prefixes)
	local lc_spaces = vim.tbl_extend("keep", vim.tbl_get(config, "linecomment", "spaces") or {}, default_config.linecomment.spaces)

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

	data.linecomment_defs = vim.tbl_map(function(commentstring)
		return LinecommentDef.new(lc_spaces, commentstring)
	end, lc_prefixes)
end

-- set default values.
function M.initialize()
	M.set_config(default_config)
end

return M
