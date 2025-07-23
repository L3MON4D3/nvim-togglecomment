local util = require("togglecomment.util")

---@class Togglecomment.BlockcommentDef : Togglecomment.CommentDef
local BlockcommentDef = {}
BlockcommentDef.__index = BlockcommentDef

function BlockcommentDef.new(begin_str, end_str, placeholder_begin, placeholder_end, commentnode_type)
	return setmetatable({
		block_begin = begin_str,
		block_end = end_str,
		placeholder_begin = placeholder_begin,
		placeholder_end = placeholder_end,
		placeholder_len = #placeholder_begin,
		-- fixed for now, allow customization if necessary.
		commentnode_type = commentnode_type,
	}, BlockcommentDef)
end

local BlockcommentParser = {}
BlockcommentParser.__index = BlockcommentParser

function BlockcommentDef:valid(continuous_linerange, range)
	local block_begin_maybe = continuous_linerange:get_text({range[1], range[2], range[1], range[2] + #self.block_begin})[1]
	local block_end_maybe = continuous_linerange:get_text({range[3], range[4] - #self.block_end, range[3], range[4]})[1]

	return block_begin_maybe == self.block_begin and block_end_maybe == self.block_end
end

---@class Togglecomment.PlaceholderRange
---@field from [integer, integer]
---@field to [integer, integer]

---@class Togglecomment.Placeholder
---@field begin boolean
---@field pos [integer, integer]

function BlockcommentDef:toplevel_placeholders(continuous_linerange, range)
	local toplevel_placeholder_ranges = {}

	local text = continuous_linerange:get_text(range)

	local placeholder_stack = {} --[[@as Togglecomment.Placeholder[] ]]

	local line_i = 1
	local line_start_buf_offset = {range[1], range[2]}
	local line_handled_columns = 0
	while true do
		local line = text[line_i]
		if not line then
			return toplevel_placeholder_ranges
		end
		local next_begin_idx = line:find(self.placeholder_begin, line_handled_columns+1, true)
		local next_end_idx = line:find(self.placeholder_end, line_handled_columns+1, true)

		if next_begin_idx == nil and next_end_idx == nil then
			-- no more matches in this line, advance.

			line_i = line_i + 1
			-- every line but the first begins at column 0.
			line_start_buf_offset = {line_start_buf_offset[1]+1, 0}
			-- for find, from which column to start the search.
			line_handled_columns = 0
		else
			local is_begin = next_begin_idx and ((next_end_idx and next_begin_idx < next_end_idx) or not next_end_idx)
			local idx = is_begin and next_begin_idx or next_end_idx

			local placeholder_from = {line_start_buf_offset[1], line_start_buf_offset[2]+idx-1}

			if not is_begin and placeholder_stack[1] and placeholder_stack[#placeholder_stack].begin then
				-- have found pair! record it if it leaves the stack empty, then
				-- remove it.
				if #placeholder_stack == 1 then
					-- placeholders are not nested inside another pair!! record
					-- them.
					table.insert(toplevel_placeholder_ranges, {
						from = placeholder_stack[1].pos,
						to = {placeholder_from[1], placeholder_from[2]+self.placeholder_len}
					})
				end
				placeholder_stack[#placeholder_stack] = nil
			else
				-- push placeholder onto stack.
				table.insert(placeholder_stack, {begin = is_begin, pos = placeholder_from })
			end

			line_handled_columns = idx + self.placeholder_len
		end
	end
end

function BlockcommentDef:get_comment_range(opts)
	local langtree = opts.langtree
	local pos = opts.pos
	local buffer_lines = opts.buffer_lines

	local comment_def = self
	local commentnode_type = comment_def.commentnode_type

	-- apparently parses all nodes covering the position :)
	langtree:parse({pos[1], pos[2], pos[1], pos[2]+1})

	local node = langtree:named_node_for_range({pos[1],pos[2],pos[1],pos[2]}, {ignore_injections = true})
	local comment_range
	while true do
		if not node then
			return nil
		end

		if node:type() == commentnode_type then
			comment_range = util.trim_node(node, 0)
			break
		end
		node = node:parent()
	end

	if comment_def:valid(buffer_lines, comment_range) then
		return comment_range
	end
end
function BlockcommentDef:comment(range, opts)
	local langtree = opts.langtree

	-- for some reason, just :parse() is not enough sometimes (seems to affect
	-- injected languages).
	-- Explicitly reparse the range we're interested in.
	langtree:parse(range)

	local cursor_tree = util.tree_for_range(langtree, range)
	if not cursor_tree then
		error("Unexpected: Could not find tree for requested range!")
	end

	local query = vim.treesitter.query.parse(langtree:lang(), ("((%s) @comment (#trim! @comment 1 1 1 1))"):format(self.commentnode_type))

	local comments_in_comment_range = {}
	for _, _, metadata in query:iter_matches(cursor_tree:root(), 0, range[1], range[3]+1) do
		-- only one pattern and one captured node, and we always trim, so metadata has the correct range.
		local node_range = metadata[1].range
		if util.range_includes_range(range, node_range) then
			table.insert(comments_in_comment_range, node_range)
		end
	end

	-- these ranges cannot overlap, so we can sort them by comparing their row.
	util.sort_ranges(comments_in_comment_range)

	-- start inserting characters, back to front so we don't have to adjust
	-- positions.
	vim.api.nvim_buf_set_text(0, range[3], range[4], range[3], range[4], {self.block_end})
	for i = #comments_in_comment_range, 1, -1 do
		local commentrange = comments_in_comment_range[i]
		vim.api.nvim_buf_set_text(0, commentrange[3], commentrange[4]-#self.block_end, commentrange[3], commentrange[4], {self.placeholder_end})
		vim.api.nvim_buf_set_text(0, commentrange[1], commentrange[2], commentrange[1], commentrange[2]+#self.block_begin, {self.placeholder_begin})
	end
	vim.api.nvim_buf_set_text(0, range[1], range[2], range[1], range[2], {self.block_begin})
end
function BlockcommentDef:uncomment(range, opts)
	local buffer_lines = opts.buffer_lines

	local toplevel_placeholders = self:toplevel_placeholders(buffer_lines, range)

	-- again, back to front for correct offsets.

	vim.api.nvim_buf_set_text(0, range[3], range[4]-#self.block_end, range[3], range[4], {})
	for i = #toplevel_placeholders, 1, -1 do
		local placeholder = toplevel_placeholders[i]
		vim.api.nvim_buf_set_text(0, placeholder.to[1], placeholder.to[2]-#self.placeholder_end, placeholder.to[1], placeholder.to[2], {self.block_end})
		vim.api.nvim_buf_set_text(0, placeholder.from[1], placeholder.from[2], placeholder.from[1], placeholder.from[2]+#self.placeholder_begin, {self.block_begin})
	end
	vim.api.nvim_buf_set_text(0, range[1], range[2], range[1], range[2]+#self.block_begin, {})
end

return {
	BlockcommentDef = BlockcommentDef
}
