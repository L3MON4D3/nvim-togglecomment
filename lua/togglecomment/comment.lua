local util = require("togglecomment.util")
local contiguous_linerange = require("togglecomment.contiguous_linerange")
local range_selectors = require("togglecomment.range_selectors")
local LineCommentType = require("togglecomment.linecomment").LineCommentType
local data = require("togglecomment.session.data")

---@class Togglecomment.Comment.CommentFnOpts
---@field langtree vim.treesitter.LanguageTree freshly parsed languagetree.
---@field buffer_lines ToggleComment.LazyContiguousLinerange
---@field pos Togglecomment.ByteColPosition cursor position
---@field comment_def Togglecomment.CommentDef

local function get_blockcomment_range(opts)
	local comment_def = opts.comment_def
	local commentnode_type = comment_def.commentnode_type
	local langtree = opts.langtree
	local pos = opts.pos
	local buffer_lines = opts.buffer_lines

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

local function comment_block_range(range, opts)
	local comment_def = opts.comment_def
	local langtree = opts.langtree
	-- for some reason, just :parse() is not enough sometimes (seems to affect
	-- injected languages).
	-- Explicitly reparse the range we're interested in.
	langtree:parse(range)

	local cursor_tree = util.tree_for_range(langtree, range)
	if not cursor_tree then
		error("Unexpected: Could not find tree for requested range!")
	end

	local query = vim.treesitter.query.parse(langtree:lang(), ("((%s) @comment (#trim! @comment 1 1 1 1))"):format(comment_def.commentnode_type))

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
	vim.api.nvim_buf_set_text(0, range[3], range[4], range[3], range[4], {comment_def.block_end})
	for i = #comments_in_comment_range, 1, -1 do
		local commentrange = comments_in_comment_range[i]
		vim.api.nvim_buf_set_text(0, commentrange[3], commentrange[4]-#comment_def.block_end, commentrange[3], commentrange[4], {comment_def.placeholder_end})
		vim.api.nvim_buf_set_text(0, commentrange[1], commentrange[2], commentrange[1], commentrange[2]+#comment_def.block_begin, {comment_def.placeholder_begin})
	end
	vim.api.nvim_buf_set_text(0, range[1], range[2], range[1], range[2], {comment_def.block_begin})
end

local function uncomment_block_range(range, opts)
	local comment_def = opts.comment_def
	local buffer_lines = opts.buffer_lines

	local toplevel_placeholders = comment_def:toplevel_placeholders(buffer_lines, range)

	-- again, back to front for correct offsets.

	vim.api.nvim_buf_set_text(0, range[3], range[4]-#comment_def.block_end, range[3], range[4], {})
	for i = #toplevel_placeholders, 1, -1 do
		local placeholder = toplevel_placeholders[i]
		vim.api.nvim_buf_set_text(0, placeholder.to[1], placeholder.to[2]-#comment_def.placeholder_end, placeholder.to[1], placeholder.to[2], {comment_def.block_end})
		vim.api.nvim_buf_set_text(0, placeholder.from[1], placeholder.from[2], placeholder.from[1], placeholder.from[2]+#comment_def.placeholder_begin, {comment_def.block_begin})
	end
	vim.api.nvim_buf_set_text(0, range[1], range[2], range[1], range[2]+#comment_def.block_begin, {})
end

-- return range from, to-inclusive.
local function get_linecomment_range(opts)
	local linecomment_def = opts.comment_def
	local buffer_lines = opts.buffer_lines
	local linenr = opts.pos[1]

	buffer_lines = contiguous_linerange.new({center = linenr})

	local pos_linetype = linecomment_def:linetype(buffer_lines[linenr])

	if pos_linetype == LineCommentType.singleline then
		return {linenr, 0, linenr, 0}
	end
	if pos_linetype == nil then
		return nil
	end

	local from_linenr = pos_linetype == LineCommentType.to and linenr-1 or linenr
	while true do
		if from_linenr == -1 then
			return nil
		end
		local from_linetype = linecomment_def:linetype(buffer_lines[from_linenr])

		if from_linetype == nil or from_linetype == LineCommentType.to or from_linetype == LineCommentType.singleline then
			-- line is not a connecting line, and we have not reached the
			-- `from` => this is not a comment-range.
			return nil
		elseif from_linetype == LineCommentType.from then
			break
		end
		from_linenr = from_linenr - 1
	end

	local to_linenr = pos_linetype == LineCommentType.from and linenr+1 or linenr
	while true do
		if to_linenr == buffer_lines.n_lines then
			return nil
		end
		local to_linetype = linecomment_def:linetype(buffer_lines[to_linenr])

		if to_linetype == nil or to_linetype == LineCommentType.from or to_linetype == LineCommentType.singleline then
			return nil
		elseif to_linetype == LineCommentType.to then
			break
		end
		to_linenr = to_linenr + 1
	end

	return {from_linenr, 0, to_linenr, 0}
end

local function uncomment_line_range(range, opts)
	local from, to = range[1], range[3]
	local linecomment_def = opts.comment_def
	local buffer_lines = opts.buffer_lines

	for i = from, to do
		local first_non_space_col = buffer_lines[i]:find("[^%s]")
		-- if nil, this is a blank line, which is completely valid.
		if first_non_space_col then
			first_non_space_col = first_non_space_col-1
			vim.api.nvim_buf_set_text(0, i, first_non_space_col, i, first_non_space_col + linecomment_def.prefix_len, {})
		end
	end
end

local function comment_line_range(range, opts)
	local linecomment_def = opts.comment_def
	local buffer_lines = opts.buffer_lines
	local from, to = range[1], range[3]

	local from_char = from == to and linecomment_def.ssingleline or linecomment_def.sfrom
	for i = from, to do
		local comment_char = (i == from and from_char) or (i == to and linecomment_def.sto) or linecomment_def.sconnect
		local first_non_space_col = buffer_lines[i]:find("[^%s]")
		-- if nil, this is a blank line, which we will not comment.
		if first_non_space_col then
			first_non_space_col = first_non_space_col-1
			vim.api.nvim_buf_set_text(0, i, first_non_space_col, i, first_non_space_col, {comment_char})
		end
	end
end

---@enum Togglecomment.ActionType
local ActionTypes = {
	comment_lines = 1,
	uncomment_lines = 2,
	nop = 3,
	comment_block = 4,
	uncomment_block = 5
}

---@class RangeAction
---@field prefix_def table
---@field range integer[]
---@field type Togglecomment.ActionType

local nop_action = {range = {}, type = ActionTypes.nop}

local action_fns = {
	[ActionTypes.comment_lines] = {
		apply = comment_line_range,
		undo = uncomment_line_range
	},
	[ActionTypes.uncomment_lines] = {
		undo = comment_line_range,
		apply = uncomment_line_range
	},
	[ActionTypes.comment_block] = {
		apply = comment_block_range,
		undo = uncomment_block_range
	},
	[ActionTypes.uncomment_block] = {
		undo = comment_block_range,
		apply = uncomment_block_range
	},
}
local function do_action(mode, action, buffer_lines)
	if action.type == ActionTypes.nop then
		return
	end

	local opts = {
		buffer_lines = buffer_lines,
		comment_def = action.comment_def,
		langtree = action.langtree,
	}
	local row, col, details = unpack(vim.api.nvim_buf_get_extmark_by_id(0, data.namespace, action.extmark_id, {details = true}))

	assert(row)
	assert(col)
	assert(details)

	opts.langtree:parse()
	local range = {row, col, details.end_row, details.end_col}

	action_fns[action.type][mode](range, opts)
end

local last_actions = nil

local idx = 1
local function set_continuing_action(val)
	-- make copy, s.t. check below does not just check global idx!
	local current_idx = idx
	last_actions = {
		val = val,
		idx = current_idx,
		cursor = util.get_cursor_0ind(),
		changedtick = vim.b.changedtick
	}

	vim.defer_fn(function()
		-- make sure we can only delete the last_toggle-val set in this call.
		if last_actions.idx == current_idx then
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

return function()
	local mode = vim.fn.mode()
	if mode:sub(1,1):lower() == "v" then
		local getpos_dot = vim.fn.getpos(".")
		local getpos_v = vim.fn.getpos("v")

		local pos_dot = {getpos_dot[2]-1, getpos_dot[3]-1}
		local pos_v = {getpos_v[2]-1, getpos_v[3]-1}
		local from, to
		if util.pos_cmp(pos_dot, pos_v) < 0 then
			from, to = pos_dot, pos_v
		else
			from, to = pos_v, pos_dot
		end

		-- linecomment ignores the columns, so this is fine, and more accurate for getting a tree.
		-- range should exclude the last char.
		local range = {from[1], from[2], to[1], to[2]+1}

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
		-- For block-comments, I'm not so sure, but using the innermost range
		-- seems like a good default.

		-- language_for_range descends into injections.
		local langtree = root_parser:language_for_range(range)
		local lang = langtree:lang()

		local comment_range
		local opts = {
			buffer_lines = contiguous_linerange.new({from = from[1], to = to[1]+1}),
			langtree = langtree,
		}

		local comment_def = data.linecomment_defs[lang]
		if comment_def then
			comment_range = comment_line_range
			opts.comment_def = comment_def
		else
			comment_def = data.blockcomment_defs[lang]
			if not comment_def then
				-- we cannot deal with this language.
				return
			end
			comment_range = comment_block_range
			opts.comment_def = comment_def
		end

		comment_range(range, opts)
		-- immediately exit visual selection.
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", true)
		return
	elseif mode == "n" then
		local cursor = util.get_cursor_0ind()

		local buffer_lines = contiguous_linerange.new({center = cursor[1]})

		local continue_action = get_continuing_action()
		if continue_action then
			-- undo previous action.
			do_action("undo", continue_action.actions[continue_action.applied_action_idx], buffer_lines)

			-- find index of next action.
			continue_action.applied_action_idx = continue_action.applied_action_idx + 1
			if continue_action.applied_action_idx > #continue_action.actions then
				continue_action.applied_action_idx = 1
			end

			-- apply next action
			do_action("apply", continue_action.actions[continue_action.applied_action_idx], buffer_lines)

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

			local common_fn_opts = {
				langtree = languagetree,
				buffer_lines = buffer_lines,
				pos = cursor
			}
			---@class Togglecomment.Comment.CommentTypeOpts
			---@field get_comment_range fun(Togglecomment.Comment.CommentFnOpts): Togglecomment.BufRange
			---@field uncomment_range fun(Togglecomment.BufRange, ToggleComment.Comment.CommentFnOpts)
			---@field make_cursor_check_range fun(Togglecomment.BufRange): Togglecomment.BufRange
			---@field make_comment_range fun(Togglecomment.BufRange): Togglecomment.BufRange
			---Creates the ranges that are ultimately compared with one another.
			---For example the line-ranges may have to be extended to reach to
			---the end of the line.
			---@field commenttype_valid_range fun(Togglecomment.BufRange): boolean
			---Return whether the range can be commented with the functions
			---provided here (with linecomments, for example, the range has to cover entire lines).
			---@field comment_actiontype Togglecomment.ActionType
			---@field comment_fn_opts Togglecomment.Comment.CommentFnOpts

			local commenttypes = ({} --[[@as Togglecomment.Comment.CommentTypeOpts[] ]])

			local linecomment_def = data.linecomment_defs[lang]
			if linecomment_def then
				local fn_opts = util.shallow_copy(common_fn_opts)
				fn_opts.comment_def = linecomment_def
				local make_cursor_check_range = function(node_range)
					-- Since we are in line-mode, we treat the cursor as inside as long as it's on the correct line.
					-- (extend from-column to beginning of line, end-column to end)
					local cursor_check_range = util.shallow_copy(node_range)
					cursor_check_range[2] = 0
					cursor_check_range[4] = #buffer_lines[node_range[3]]-1
					return cursor_check_range
				end
				table.insert(commenttypes, {
					get_comment_range = get_linecomment_range,
					uncomment_range = uncomment_line_range,
					make_cursor_check_range = make_cursor_check_range,
					commenttype_valid_range = function(node_range)
						-- only allow this range as comment if there are only
						-- whitespace characters before it and if it reaches the
						-- end of the final line.
						local node_begin_line = buffer_lines[node_range[1]]
						local node_end_line = buffer_lines[node_range[3]]

						local node_begin_line_first_non_whitespace = node_begin_line:find("[^%s]")-1

						return node_begin_line_first_non_whitespace == node_range[2] and #node_end_line == node_range[4]
					end,
					-- the comment-range is identical, in this case.
					-- TODO: don't extend from-col to 0, only to first
					-- non-whitespace char?
					make_comment_range = make_cursor_check_range,
					comment_actiontype = ActionTypes.comment_lines,
					comment_fn_opts = fn_opts
				})
			end
			local blockcomment_def = data.blockcomment_defs[lang]
			if blockcomment_def then
				local fn_opts = util.shallow_copy(common_fn_opts)
				fn_opts.comment_def = blockcomment_def

				table.insert(commenttypes, {
					get_comment_range = get_blockcomment_range,
					uncomment_range = uncomment_block_range,
					-- don't modify block-range for cursor check.
					make_cursor_check_range = util.id,
					-- block-comments can handle all ranges.
					commenttype_valid_range = util.yes,
					-- comment-range is identical to nodes' range.
					make_comment_range = util.id,
					comment_actiontype = ActionTypes.comment_block,
					comment_fn_opts = fn_opts
				})
			end
			if #commenttypes == 0 then
				-- we cannot deal with this language, continue.
				goto continue
			end

			for _, ct in ipairs(commenttypes) do
				local range = ct.get_comment_range(ct.comment_fn_opts)

				if range then
					-- line is commented, simply uncomment.
					ct.uncomment_range(range, ct.comment_fn_opts)
					-- I think if we find an uncommentable range, it should be
					-- uncommented immediately..?
					-- Also, we can abort here, we don't want to uncomment twice.
					return
				end
			end

			-- look for commentable ranges.

			-- only find matches that include the cursor-line.
			for _, match, metadata in query:iter_matches(cursor_tree:root(), 0, cursor[1], cursor[1]+1) do
				-- prefer range set via metadata, it has to be set explicitly,
				-- so probably only exists if there was some extra effort to enable it.
				local node_range = metadata.togglecomment
				if not node_range then
					for id, nodes in pairs(match) do
						local name = query.captures[id]
						if name == "togglecomment" then
							-- set this way by #trim!.
							node_range = metadata[id] and metadata[id].range
							if not node_range then
								node_range = {nodes[1]:range(false)}
							end
							break
						end
					end
				end

				for _, ct in ipairs(commenttypes) do
					local cursor_check_range = ct.make_cursor_check_range(node_range)
					if
						util.range_includes_pos(cursor_check_range, cursor) and
						ct.commenttype_valid_range(node_range) then

						selector.record({
							comment_def = ct.comment_fn_opts.comment_def,
							-- node_range is end-exclusive, but it excludes the
							-- last column, not the last line.
							range = ct.make_comment_range(node_range),
							type = ct.comment_actiontype,
							langtree = languagetree
						})
						-- once we have found a fitting commenttype for this
						-- match, don't insert it again.
						break
					end
				end
			end
			::continue::
		end

		-- track ranges via extmark; the ranges have to be on the correct char
		-- when (un)commenting, and extmarks are much easier than manually
		-- shifting indices.
		local actions_range_sorted = vim.tbl_map(function(range_record)
			local extmark_id = vim.api.nvim_buf_set_extmark(0, data.namespace, range_record.range[1], range_record.range[2], {
				end_row = range_record.range[3],
				end_col = range_record.range[4],
				right_gravity = false,
				end_right_gravity = true
			})
			return {
				comment_def = range_record.comment_def,
				type = range_record.type,
				extmark_id = extmark_id,
				langtree = range_record.langtree
			}
		end, selector.retrieve())

		if #actions_range_sorted == 0 then
			vim.notify("No toggleable node at cursor.", vim.log.levels.WARN)
			return
		end

		table.insert(actions_range_sorted, nop_action)

		do_action("apply", actions_range_sorted[1], buffer_lines)
		set_continuing_action({cursor = cursor, applied_action_idx = 1, actions = actions_range_sorted})
	end
end
