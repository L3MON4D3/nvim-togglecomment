local LineCommentType = {
	from = 1,
	connect = 2,
	to = 3,
	singleline = 4,
	connect_maybe = 5
}

---@class Togglecomment.LinecommentDef : Togglecomment.CommentDef
local LinecommentDef = {}
LinecommentDef.__index = LinecommentDef

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

return {
	LinecommentDef = LinecommentDef,
	LineCommentType = LineCommentType
}
