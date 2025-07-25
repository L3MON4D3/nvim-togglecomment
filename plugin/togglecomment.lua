-- set default-values.
require("togglecomment.session").initialize()

vim.treesitter.query.add_directive("togglecomment-make-tc-range!", function(match, _, _, pred, metadata)
	-- extract node-ranges
	local r1 = {match[pred[2]]:range()}
	local r2 = {match[pred[6]]:range()}

	-- extract correct positions
	local p1 = pred[3] == "end" and {r1[3], r1[4]} or {r1[1], r1[2]}
	local p2 = pred[7] == "end" and {r2[3], r2[4]} or {r2[1], r2[2]}

	-- apply offsets.
	p1[1] = p1[1] + pred[4]
	p1[2] = p1[2] + pred[5]
	p2[1] = p2[1] + pred[8]
	p2[2] = p2[2] + pred[9]

	metadata["togglecomment"] = {p1[1], p1[2], p2[1], p2[2]}
end, {})

vim.treesitter.query.add_predicate("togglecomment-root-child?", function(match, _, _, predicate)
	local node = match[predicate[2]]
	return node[#node]:parent():parent() == nil
end, {})

vim.treesitter.query.add_predicate("togglecomment-tc-query-file?", function(_, _, src, _, _)
	return type(src) == "number" and vim.api.nvim_buf_get_name(src):match("lua/togglecomment/queries/.*.lua") ~= nil
end)
