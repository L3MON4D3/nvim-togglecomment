---@alias Togglecomment.BufRange [integer, integer, integer, integer]
---Represents a range in a buffer, {from_row, from_col, to_row, to_col}, all
---0-indexed, start-in-, end-exclusive, columns in bytes.

---@alias Togglecomment.ByteColPosition [integer, integer]
---Position in the buffer, {row, col}, both 0-indexed, and col in bytes.

---@class Togglecomment.CommentDef
---@field get_comment_range fun(self: Togglecomment.CommentDef, opts: Togglecomment.Comment.CommentFnOpts): Togglecomment.BufRange
---@field comment fun(self: Togglecomment.CommentDef, range: Togglecomment.BufRange, opts: Togglecomment.Comment.CommentFnOpts)
---@field uncomment fun(self: Togglecomment.CommentDef, range: Togglecomment.BufRange, opts: Togglecomment.Comment.CommentFnOpts)

---@class Togglecomment.Comment.CommentFnOpts
---@field langtree vim.treesitter.LanguageTree freshly parsed languagetree.
---@field buffer_lines ToggleComment.LazyContiguousLinerange
---@field pos Togglecomment.ByteColPosition cursor position

