# nvim-togglecomment

The purpose of this plugin is to make commenting and subsequently uncommenting
blocks of code as comfortable as possible.

# Features
* Define commentable regions using treesitter queries, which are extremely
  flexible.
  A small example for Lua looks like
  ```query
  [
   (variable_declaration)
   (function_declaration)
   (if_statement)
   (for_statement)
   (while_statement)
  ]@togglecomment
  ```
  This also means `nvim-togglecomment` is treesitter-injection aware and will
  choose a commentstring based on the position in the buffer, not just its
  filetype.  
  A downside of this is that `nvim-togglecomment` only works when a
  treesitter-grammar is available.

* If there are multiple commentable regions at the cursor, they can be cycled
  through. This even extends beyond treesitter injections!

* Create comment from visual selection.

* Remembers comment-regions created by `nvim-togglecomment` beyond closing of a
  file.  
  This is achieved by tagging the comments with uncommon unicode symbols (but
  can be configured if some other tooling does not handle them gracefully, or if
  the used symbols are not as uncommon as assumed).

* Remembers previously commented regions when they are nested in a
  new comment, and restores them on uncommenting.  
  While trivial for line-comments, block-comments can often not be nested (in
  C++, for example). To circumvent this, we replace the comment-symbols with
  other (again, hopefully unique) unicode symbols. Again, the used symbols can
  be configured and swapped to just ASCII if desired.

* All insertions to the buffer modify the smallest possible region. This is to
  preserve existing extmarks as well as possible (if entire lines are inserted
  at once, extmarks lose their position, which can mess up e.g. snippets).

* For line-comments spanning multiple lines, the symbols are always inserted
  immediately before text, and not s.t. they form a vertical line.
  I believe this is a good choice because it is guaranteed to leave indent
  intact.

# Example
The following session shows a good chunk of the features of
`nvim-togglecomment`

https://github.com/user-attachments/assets/99e174d5-db38-411e-bf6e-64343b500d7d

Note that:
* Uncommenting uncomments exactly the range commented before.
* Since C++ has both line- and block-comments, line-comments are used when
  possible, and we fall back to block-comments when the range that should be
  commented does not cover an entire line.
* Pressing the comment-function repeatedly extends the region.
* In this case, the symbols used for remembering nested comment-regions are `⌈⠀...⠀⌋`.

<details>
<summary>Relevant queries are:</summary>

* `cpp/togglecomment.scm`
```query
[
  (expression_statement)
  (for_statement)
] @togglecomment

(binary_expression
  operator: "<<" @op
  right: (_) @rhs
  (#make-range-extended! "togglecomment" @op "start" 0 0 @rhs "end_" 0 0)
)
```
* `markdown/togglecomment.scm`
```query
((fenced_code_block
  (fenced_code_block_delimiter) @fstart
  (fenced_code_block_delimiter) @fend
 )
 ; make sure to cover the entire line.
 (#make-range-extended! "togglecomment" @fstart "start" 0 0 @fend "end_" 0 0)
)

(
 [
  (section)
  (paragraph)
 ] @togglecomment
 (#trim! @togglecomment 1 1 1 1)
)
```
Where the make-range-extended directive is defined
[here](https://github.com/L3MON4D3/Dotfiles/blob/a5d8f963edc7bfc88ef59b4522e79fa6a0c24f3f/nvim/lua/init.lua#L111-L127)
and allows creating ranges from endpoints of captured nodes.
</details>



# Setup
0. Install `L3MON4D3/nvim-togglecomment` with your favorite plugin-manager.
1. Add a keybinding for the function `require("togglecomment").comment`. For
   example:
   ```lua
   vim.keymap.set({"n","v"}, "<leader>d", tc.comment, {noremap = true, silent = true})
   ```
2. (optional) Call `require("togglecomment").setup` to add comment-symbols for
   missing languages, or override existing ones.  
   For now there is no documentation on this, but check [this file](lua/togglecomment/session/init.lua)
   for the default-configuration, it shows the structure expected by `setup`.
