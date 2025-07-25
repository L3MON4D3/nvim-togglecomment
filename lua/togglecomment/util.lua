local M = {}

function M.nop() end

function M.id(x) return x end

function M.yes() return true end

function M.get_cursor_0ind(winid)
	local c = vim.api.nvim_win_get_cursor(winid or 0)
	c[1] = c[1] - 1
	return c
end

function M.shallow_copy(t)
	local t2 = {}
	for k,v in pairs(t) do
		t2[k] = v
	end
	return t2
end

-- just compare two integers.
function M.cmp(i1, i2)
	-- lets hope this ends up as one cmp.
	if i1 < i2 then
		return -1
	end
	if i1 > i2 then
		return 1
	end
	return 0
end

-- pos1 == pos2 => 0
-- pos1 <  pos2 => <0
-- pos1 >  pos2 => >0
function M.pos_cmp(pos1, pos2)
	-- if row is different it determines result, otherwise the column does.
	return 2 * M.cmp(pos1[1], pos2[1]) + M.cmp(pos1[2], pos2[2])
end

-- ranges are end-exclusive, pos "covers" (think block cursor) pos.
function M.range_includes_pos(range, pos)
	local s = { range[1], range[2] }
	local e = { range[3], range[4] }

	return M.pos_cmp(s, pos) <= 0 and M.pos_cmp(pos, e) < 0
end

-- assumption: r1 and r2 don't partially overlap, either one is included in the other, or they don't overlap.
-- return whether r1 completely includes r2.
-- r1, r2 are 4-tuple-ranges
function M.range_includes_range(r1, r2)
	local s1 = { r1[1], r1[2] }
	local e1 = { r1[3], r1[4] }
	local s2 = { r2[1], r2[2] }
	local e2 = { r2[3], r2[4] }

	return M.pos_cmp(s1, s2) <= 0 and M.pos_cmp(e2, e1) <= 0
end

function M.range_from(range)
	return {range[1], range[2]}
end

function M.range_to(range)
	return {range[3], range[4]}
end

function M.range_from_endpoints(from, to)
	return {from[1], from[2], to[1], to[2]}
end

function M.sort_ranges(ranges)
	table.sort(ranges, function(r1, r2)
		return M.pos_cmp(M.range_from(r1), M.range_from(r2)) < 0
	end)
end

-- code adapted from github:nvim/runtime/lua/vim/treesitter/query.lua
function M.trim_node(node, bufnr)
	local start_row, start_col, end_row, end_col = node:range()

	local node_text = vim.split(vim.treesitter.get_node_text(node, bufnr), '\n')
	if end_col == 0 then
		-- get_node_text() will ignore the last line if the node ends at column 0
		node_text[#node_text + 1] = ''
	end

	local end_idx = #node_text
	local start_idx = 1

	while end_idx > 0 and node_text[end_idx]:find('^%s*$') do
		end_idx = end_idx - 1
		end_row = end_row - 1
		-- set the end position to the last column of the next line, or 0 if we just trimmed the
		-- last line
		end_col = end_idx > 0 and #node_text[end_idx] or 0
	end
	if end_idx == 0 then
		end_row = start_row
		end_col = start_col
	else
		local whitespace_start = node_text[end_idx]:find('(%s*)$')
		end_col = (whitespace_start - 1) + (end_idx == 1 and start_col or 0)
	end

	while start_idx <= end_idx and node_text[start_idx]:find('^%s*$') do
		start_idx = start_idx + 1
		start_row = start_row + 1
		start_col = 0
	end
	local _, whitespace_end = node_text[start_idx]:find('^(%s*)')
	whitespace_end = whitespace_end or 0
	start_col = (start_idx == 1 and start_col or 0) + whitespace_end

	-- If this produces an invalid range, we just skip it.
	if start_row < end_row or (start_row == end_row and start_col <= end_col) then
		return {start_row, start_col, end_row, end_col}
	end
	return nil
end

function M.fuse_buffer_ranges(ranges, buffer_lines)
	local fused_ranges = {ranges[1]}
	for i = 2, #ranges do
		local range = ranges[i]
		local last_range = fused_ranges[#fused_ranges]
		local text_between = table.concat(buffer_lines:get_text(M.range_from_endpoints(M.range_to(last_range), M.range_from(range)))):sub(1, -1)

		if text_between:match("%s*") then
			fused_ranges[#fused_ranges] = M.range_from_endpoints(M.range_from(last_range), M.range_to(range))
		else
			table.insert(fused_ranges, range)
		end
	end
	return fused_ranges
end

function M.tree_for_range(langtree, range, buffer_lines)
	local trees = langtree:trees()
	for _, tree in ipairs(trees) do
		local tsranges = tree:included_ranges(false)
		local ranges = M.shallow_copy(tsranges)
		M.sort_ranges(ranges)

		local fused_ranges = M.fuse_buffer_ranges(ranges, buffer_lines)
		for _, tree_range in ipairs(fused_ranges) do
			if M.range_includes_range(tree_range, range) then
				return tree
			end
		end
	end
	return nil
end

function M.langtree_for_range(langtree, range, buffer_lines)
	for _, childlangtree in pairs(langtree:children()) do
		if M.tree_for_range(childlangtree, range, buffer_lines) then
			return M.langtree_for_range(childlangtree, range, buffer_lines)
		end
	end

	return langtree
end

function M.langtrees_for_range(langtree, range, buffer_lines)
	local res = {}
	if M.tree_for_range(langtree, range, buffer_lines) then
		table.insert(res, langtree)
	end
	for _, child_langtree in pairs(langtree:children()) do
		vim.list_extend(res, M.langtrees_for_range(child_langtree, range, buffer_lines))
	end

	return res
end

function M.lazy_table(lazy_t, lazy_defs)
	return setmetatable(lazy_t, {
		__index = function(t, k)
			local v = lazy_defs[k]
			if v then
				local v_resolved = v()
				rawset(t, k, v_resolved)
				return v_resolved
			end
			return nil
		end,
	})
end

function M.list_to_set(list)
	local res = {}
	for _, v in ipairs(list) do
		res[v] = true
	end
	return res
end

return M
