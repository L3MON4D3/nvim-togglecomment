local util = require("togglecomment.util")
local contiguous_linerange = require("togglecomment.contiguous_linerange")
local range_selectors = require("togglecomment.range_selectors")
local data = require("togglecomment.session.data")

---@enum Togglecomment.ActionType
local ActionTypes = {
	comment = 1,
	uncomment = 2,
	nop = 3,
}

---@class RangeAction
---@field prefix_def table
---@field range integer[]
---@field type Togglecomment.ActionType

local nop_action = {range = {}, type = ActionTypes.nop}

local action_fns = {
	[ActionTypes.comment] = {
		apply = "comment",
		undo = "uncomment",

	},
	[ActionTypes.uncomment] = {
		apply = "uncomment",
		undo = "comment",

	}
}
local function do_action(mode, action, buffer_lines)
	if action.type == ActionTypes.nop then
		return
	end

	local opts = {
		buffer_lines = buffer_lines,
		-- langtree is not up-to-date, but will be parsed by the functions that
		-- need it.
		langtree = action.langtree,
	}
	local row, col, details = unpack(vim.api.nvim_buf_get_extmark_by_id(0, data.namespace, action.extmark_id, {details = true}))

	assert(row)
	assert(col)
	assert(details)

	local range = {row, col, details.end_row, details.end_col}

	action.comment_def[action_fns[action.type][mode]](action.comment_def, range, opts)
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


		local buffer_lines = contiguous_linerange.new({from = from[1], to = to[1]+1})
		if mode:sub(1,1) == "V" then
			from[2] = 0
			to[2] = #buffer_lines[to[1]]
		else
			-- clamp columns to last character!
			-- +1: getpos gives positions as end-inclusive, we want end-exclusive
			from[2] = math.min(#buffer_lines[from[1]], from[2])
			to[2] = math.min(#buffer_lines[to[1]], to[2]+1)
		end

		-- linecomment ignores the columns, so this is fine, and more accurate for getting a tree.
		-- range should exclude the last char.
		local range = util.range_from_endpoints(from, to)

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
		local langtree = util.langtree_for_range(root_parser, range, buffer_lines)
		local lang = langtree:lang()

		-- variables, will be completed after deciding whether block- or
		-- line-comments should be used.
		local opts = {
			buffer_lines = buffer_lines,
			langtree = langtree,
		}
		local comment_def

		local linecomment_def = data.linecomment_defs[lang]
		local blockcomment_def = data.blockcomment_defs[lang]
		local prefer_linecomment = mode:sub(1,1) == "V"

		if linecomment_def and (prefer_linecomment or blockcomment_def == nil) then
			comment_def = linecomment_def
		else
			comment_def = blockcomment_def
		end
		if not comment_def then
			vim.notify("Cannot toggle comments for filetype " .. lang, vim.log.levels.WARN)
			return
		end

		comment_def:comment(range, opts)
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
		root_parser:parse()

		local selector = range_selectors.sorted()
		local cursor_range = util.range_from_endpoints(cursor, cursor)
		for _, languagetree in ipairs(util.langtrees_for_range(root_parser, cursor_range, buffer_lines)) do
			local lang = languagetree:lang()
			local cursor_tree = languagetree:tree_for_range(cursor_range, {ignore_injections = true})

			if not cursor_tree then
				goto continue;
			end

			local fn_opts = {
				langtree = languagetree,
				buffer_lines = buffer_lines,
				pos = cursor
			}
			---@class Togglecomment.Comment.CommentTypeOpts
			---@field make_cursor_check_range fun(range: Togglecomment.BufRange): Togglecomment.BufRange
			---@field make_comment_range fun(range: Togglecomment.BufRange): Togglecomment.BufRange
			---Creates the ranges that are ultimately compared with one another.
			---For example the line-ranges may have to be extended to reach to
			---the end of the line.
			---@field commenttype_valid_range fun(range: Togglecomment.BufRange): boolean
			---Return whether the range can be commented with the functions
			---provided here (with linecomments, for example, the range has to cover entire lines).
			---@field comment_actiontype Togglecomment.ActionType
			---@field comment_fn_opts Togglecomment.Comment.CommentFnOpts
			---@field comment_def Togglecomment.CommentDef

			local commenttypes = ({} --[[@as Togglecomment.Comment.CommentTypeOpts[] ]])

			local linecomment_def = data.linecomment_defs[lang]
			if linecomment_def then
				local make_cursor_check_range = function(node_range)
					-- Since we are in line-mode, we treat the cursor as inside as long as it's on the correct line.
					-- (extend from-column to beginning of line, end-column to end)
					local cursor_check_range = util.shallow_copy(node_range)
					cursor_check_range[2] = 0
					cursor_check_range[4] = #buffer_lines[node_range[3]]
					return cursor_check_range
				end
				table.insert(commenttypes, {
					comment_def = linecomment_def,
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
					comment_actiontype = ActionTypes.comment,
				})
			end
			local blockcomment_def = data.blockcomment_defs[lang]
			if blockcomment_def then
				table.insert(commenttypes, {
					comment_def = blockcomment_def,
					-- don't modify block-range for cursor check.
					make_cursor_check_range = util.id,
					-- block-comments can handle all ranges.
					commenttype_valid_range = util.yes,
					-- comment-range is identical to nodes' range.
					make_comment_range = util.id,
					comment_actiontype = ActionTypes.comment,
				})
			end
			if #commenttypes == 0 then
				-- we cannot deal with this language, continue.
				goto continue
			end

			for _, ct in ipairs(commenttypes) do
				local range = ct.comment_def:get_comment_range(fn_opts)

				if range then
					-- line is commented, simply uncomment.
					ct.comment_def:uncomment(range, fn_opts)
					-- I think if we find an uncommentable range, it should be
					-- uncommented immediately..?
					-- Also, we can abort here, we don't want to uncomment twice.
					return
				end
			end

			-- look for commentable ranges.

			local query = vim.treesitter.query.get(lang, "togglecomment")
			if query == nil then
				goto continue;
			end

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
							comment_def = ct.comment_def,
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
