local util = require("togglecomment.util")
local contiguous_linerange = require("togglecomment.contiguous_linerange")
local range_selectors = require("togglecomment.range_selectors")
local LineCommentType = require("togglecomment.linecomment").LineCommentType
local data = require("togglecomment.session.data")

-- return range from, to-inclusive.
local function get_linecomment_range(prefix_def, buffer_lines, linenr)
	buffer_lines = contiguous_linerange.new({center = linenr})

	local pos_linetype = prefix_def:linetype(buffer_lines[linenr])

	if pos_linetype == LineCommentType.singleline then
		return linenr, linenr
	end
	if pos_linetype == nil then
		return nil, nil
	end

	local from_linenr = pos_linetype == LineCommentType.to and linenr-1 or linenr
	while true do
		if from_linenr == -1 then
			return nil,nil
		end
		local from_linetype = prefix_def:linetype(buffer_lines[from_linenr])

		if from_linetype == nil or from_linetype == LineCommentType.to or from_linetype == LineCommentType.singleline then
			-- line is not a connecting line, and we have not reached the
			-- `from` => this is not a comment-range.
			return nil,nil
		elseif from_linetype == LineCommentType.from then
			break
		end
		from_linenr = from_linenr - 1
	end

	local to_linenr = pos_linetype == LineCommentType.from and linenr+1 or linenr
	while true do
		if to_linenr == buffer_lines.n_lines then
			return nil,nil
		end
		local to_linetype = prefix_def:linetype(buffer_lines[to_linenr])

		if to_linetype == nil or to_linetype == LineCommentType.from or to_linetype == LineCommentType.singleline then
			return nil,nil
		elseif to_linetype == LineCommentType.to then
			break
		end
		to_linenr = to_linenr + 1
	end

	return from_linenr, to_linenr
end

local function uncomment_line_range(prefix_def, buffer_lines, from, to)
	for i = from, to do
		local first_non_space_col = buffer_lines[i]:find("[^%s]")
		-- if nil, this is a blank line, which is completely valid.
		if first_non_space_col then
			first_non_space_col = first_non_space_col-1
			vim.api.nvim_buf_set_text(0, i, first_non_space_col, i, first_non_space_col + prefix_def.prefix_len, {})
		end
	end
end

local function comment_line_range(prefix_def, buffer_lines, from, to)
	local from_char = from == to and prefix_def.ssingleline or prefix_def.sfrom
	for i = from, to do
		local comment_char = (i == from and from_char) or (i == to and prefix_def.sto) or prefix_def.sconnect
		local first_non_space_col = buffer_lines[i]:find("[^%s]")
		-- if nil, this is a blank line, which we will not comment.
		if first_non_space_col then
			first_non_space_col = first_non_space_col-1
			vim.api.nvim_buf_set_text(0, i, first_non_space_col, i, first_non_space_col, {comment_char})
		end
	end
end

---@enum ActionType
local ActionTypes = {
	comment_lines = 1,
	uncomment_lines = 2,
	nop = 3,
}

---@class RangeAction
---@field prefix_def table
---@field range integer[]
---@field type ActionType

local nop_action = {range = {}, type = ActionTypes.nop}

local function apply_action(action, buffer_lines)
	local fn = {
		[ActionTypes.comment_lines] = comment_line_range,
		[ActionTypes.uncomment_lines] = uncomment_line_range,
		[ActionTypes.nop] = util.nop,
	}
	fn[action.type](action.prefix_def, buffer_lines, action.range[1], action.range[3])
end
local function undo_action(action, buffer_lines)
	local fn = {
		[ActionTypes.comment_lines] = uncomment_line_range,
		[ActionTypes.uncomment_lines] = comment_line_range,
		[ActionTypes.nop] = util.nop,
	}
	fn[action.type](action.prefix_def, buffer_lines, action.range[1], action.range[3])
end

local last_actions = nil

local idx = 1
local function set_continuing_action(val)
	-- make copy, s.t. check below does not just check global idx!
	local current_idx = idx
	val.idx = current_idx
	last_actions = {
		val = val,
		cursor = util.get_cursor_0ind(),
		changedtick = vim.b.changedtick
	}

	vim.defer_fn(function()
		-- make sure we can only delete the last_toggle-val set in this call.
		if last_actions.idx == current_idx then
			-- print("removing lt " .. vim.inspect(last_toggle))
			last_actions = nil
		end
	end, 1000)

	idx = idx + 1
end

local function get_continuing_action()
	if last_actions and vim.deep_equal(last_actions.cursor, util.get_cursor_0ind()) and vim.b.changedtick == last_actions.changedtick then
		return last_actions.val
	end
end

local function line_range(from, to)
	-- 0 for end seems appropriate because that is where (approximately) the
	-- comment-chars are inserted.
	-- So, if we compare this with a regular range, it would very likely!!
	-- insert its commend-end-symbol behind the line-comment-symbol of this
	-- line range.
	return {from, 0, to, 0}
end


return function()
	local mode = vim.fn.mode()
	if mode:sub(1,1) == "V" then
		local line_dot = vim.fn.getpos(".")[2]-1
		local line_v = vim.fn.getpos("v")[2]-1
		local from = math.min(line_dot, line_v)
		local to = math.max(line_dot, line_v)

		local range = {from, 0, to, 0}

		local root_parser = vim.treesitter.get_parser(0)
		if not root_parser then
			error("Could not get parser!")
		end

		root_parser:parse()
		-- for line-comments, the innermost tree should be the one we want to comment:
		-- It does not make sense to comment out part of a vim.cmd, for example:
		-- ```lua
		-- vim.cmd([[
		--     set nocompatible
		--     set nocompatible
		--     set nocompatible
		--     set nocompatible
		-- ]])
		-- ```
		-- if we Visually select the two inner set nocompatible-lines, and
		-- toggle_comment, they definitely should no be commented with `-- `.

		-- language_for_range descends into injections.
		local lang = root_parser:language_for_range(range):lang()

		local linecomment_def = data.linecomment_defs[lang]
		if not linecomment_def then
			-- we cannot deal with this language.
			return
		end

		comment_line_range(linecomment_def, contiguous_linerange.new({from = from, to = to+1}), from, to)
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", true)
		return
	elseif mode == "n" then
		local cursor = util.get_cursor_0ind()

		local buffer_lines = contiguous_linerange.new({center = cursor[1]})

		local continue_action = get_continuing_action()
		if continue_action then
			-- undo previous action.
			undo_action(continue_action.actions[continue_action.applied_action_idx], buffer_lines)

			-- find index of next action.
			continue_action.applied_action_idx = continue_action.applied_action_idx + 1
			if continue_action.applied_action_idx > #continue_action.actions then
				continue_action.applied_action_idx = 1
			end

			-- apply next action
			apply_action(continue_action.actions[continue_action.applied_action_idx], buffer_lines)

			-- allow action to continue.
			set_continuing_action(continue_action)
			return
		end

		-- get top-level parser.
		local root_parser = vim.treesitter.get_parser(0)
		if not root_parser then
			error("Could not get parser!")
		end

		-- important!!! :children returns languagetree._children directly, if we
		-- modify that table, we're in for bad recursion in languagetree:_edit :|
		local languagetrees = util.shallow_copy(root_parser:children())
		-- languagetrees only contains children of the top-level-parser, but
		-- not the top-level-parser itself => add it.
		languagetrees[root_parser:lang()] = root_parser

		local selector = range_selectors.sorted()
		for lang, languagetree in pairs(languagetrees) do
			local linecomment_def = data.linecomment_defs[lang]
			if not linecomment_def then
				-- we cannot deal with this language, continue.
				goto continue
			end

			local line_comment_from, line_comment_to = get_linecomment_range(linecomment_def, buffer_lines, cursor[1])

			if line_comment_from then
				-- line is commented, simply uncomment.
				uncomment_line_range(linecomment_def, buffer_lines, line_comment_from, line_comment_to)
				-- I think if we find an uncommentable range, it should be
				-- uncommented immediately..?
				return
			end

			-- look for commentable ranges.

			local cursor_tree = languagetree:tree_for_range({
						cursor[1],
						cursor[2],
						cursor[1],
						cursor[2],
						-- we will look at the other languagetrees later.
					}, {ignore_injections = true})

			if not cursor_tree then
				goto continue;
			end

			local query = vim.treesitter.query.get(lang, "togglecomment")
			if query == nil then
				goto continue;
			end

			-- only find matches that include the cursor-line.
			for _, match, _ in query:iter_matches(cursor_tree:root(), 0, cursor[1], cursor[1]+1) do
				for id, nodes in pairs(match) do
					local name = query.captures[id]
					local node_range = {nodes[1]:range()}
					-- Since we are in line-mode, we treat the cursor as inside as long as it's on the correct line.
					-- (extend from-column to beginning of line, end-column to end)
					local cursor_check_range = util.shallow_copy(node_range)
					cursor_check_range[2] = 0
					cursor_check_range[4] = 10000
					local node_begin_line = buffer_lines[node_range[1]]
					local node_begin_line_first_non_whitespace = node_begin_line:find("[^%s]")-1
					if
						name == "togglecomment" and
						util.range_includes_pos(cursor_check_range, cursor) and
						-- only allow this range as comment if there are only
						-- whitespace characters before it
						node_begin_line_first_non_whitespace == node_range[2] then

						selector.record({
							prefix_def = linecomment_def,
							-- node_range is end-exclusive, but it excludes the
							-- last column, not the last line.
							range = line_range(node_range[1], node_range[3]),
							type = ActionTypes.comment_lines
						})
					end
				end
			end
			::continue::
		end

		local actions_range_sorted = selector.retrieve()
		if #actions_range_sorted == 0 then
			print("No toggleable node at cursor.")
			return
		end
		table.insert(actions_range_sorted, nop_action)

		apply_action(actions_range_sorted[1], buffer_lines)
		set_continuing_action({cursor = cursor, applied_action_idx = 1, actions = actions_range_sorted})
	end
end
