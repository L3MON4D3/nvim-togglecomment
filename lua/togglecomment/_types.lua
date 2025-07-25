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

---@class Togglecomment.QueryDef
---Defines a smallest sub-query (for lack of a better word), which can be
---validated against any given `vim.treesitter.language.inspect(<lang>)`-info.
---@field query string The query-text.
---@field fields string[] Fields used in the query.
---@field symbols string[] Symbols used in the query.
---@field anon_symbols string[] Anonymous symbols used in the query.
