---@alias Togglecomment.BufRange [integer, integer, integer, integer]
---Represents a range in a buffer, {from_row, from_col, to_row, to_col}, all
---0-indexed, start-in-, end-exclusive, columns in bytes.

---@alias Togglecomment.ByteColPosition [integer, integer]
---Position in the buffer, {row, col}, both 0-indexed, and col in bytes.

---@class Togglecomment.CommentDef
