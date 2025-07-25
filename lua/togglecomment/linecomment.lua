---@alias Togglecomment.LineCommentName "from"|"connect"|"to"|"singleline"

local LineCommentType = {
	from = 1,
	connect = 2,
	to = 3,
	singleline = 4,
	connect_maybe = 5
} --[[@as {[Togglecomment.LineCommentName | "connect_maybe"]: any} ]]

---@class Togglecomment.LinecommentDef : Togglecomment.CommentDef
local LinecommentDef = {}
LinecommentDef.__index = LinecommentDef
LinecommentDef.id = "linecomment"

function LinecommentDef.new(spacestr, commentstr)
	local o = {
		sfrom = commentstr .. spacestr.from,
		sto = commentstr .. spacestr.to,
		sconnect = commentstr .. spacestr.connect,
		ssingleline = commentstr .. spacestr.singleline,
	}
	o.prefixes = {
		[o.sfrom] = LineCommentType.from,
		[o.sto] = LineCommentType.to,
		[o.sconnect] = LineCommentType.connect,
		[o.ssingleline] = LineCommentType.singleline,
	}
	-- all have the same length!
	o.prefix_len = #o.sfrom

	return setmetatable(o, LinecommentDef)
end

function LinecommentDef:linetype(line)
	if line:match("^%s*$") then
		return LineCommentType.connect_maybe
	end
	local _, whitespace_to = line:find("^%s*")
	return self.prefixes[line:sub(whitespace_to+1, whitespace_to+self.prefix_len)]
end
-- returns the column where a comment should be inserted/where the comment is
-- at. These should always be the same.
-- nil if there should be no comment on this line.
function LinecommentDef:comment_at_col(line)
	if line:match("^%s*$") then
		return nil
	end
	local _, whitespace_to = line:find("^%s*")
	return whitespace_to
end

-- return range from, to-inclusive.
function LinecommentDef:get_comment_range(opts)
	local buffer_lines = opts.buffer_lines
	local linenr = opts.pos[1]

	local pos_linetype = self:linetype(buffer_lines[linenr])

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
		local from_linetype = self:linetype(buffer_lines[from_linenr])

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
		local to_linetype = self:linetype(buffer_lines[to_linenr])

		if to_linetype == nil or to_linetype == LineCommentType.from or to_linetype == LineCommentType.singleline then
			return nil
		elseif to_linetype == LineCommentType.to then
			break
		end
		to_linenr = to_linenr + 1
	end

	return {from_linenr, 0, to_linenr, 0}
end
function LinecommentDef:uncomment(range, opts)
	local from, to = range[1], range[3]
	local buffer_lines = opts.buffer_lines

	for i = from, to do
		local first_non_space_col = buffer_lines[i]:find("[^%s]")
		-- if nil, this is a blank line, which is completely valid.
		if first_non_space_col then
			first_non_space_col = first_non_space_col-1
			vim.api.nvim_buf_set_text(0, i, first_non_space_col, i, first_non_space_col + self.prefix_len, {})
		end
	end
end
function LinecommentDef:comment(range, opts)
	local buffer_lines = opts.buffer_lines
	local from, to = range[1], range[3]

	local from_char = from == to and self.ssingleline or self.sfrom
	for i = from, to do
		local comment_char = (i == from and from_char) or (i == to and self.sto) or self.sconnect
		local first_non_space_col = buffer_lines[i]:find("[^%s]")
		-- if nil, this is a blank line, which we will not comment.
		if first_non_space_col then
			first_non_space_col = first_non_space_col-1
			vim.api.nvim_buf_set_text(0, i, first_non_space_col, i, first_non_space_col, {comment_char})
		end
	end
end

return {
	LinecommentDef = LinecommentDef,
	LineCommentType = LineCommentType
}
