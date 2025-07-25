# Development Documentation

# Queries
Usually, queries are provided a `./queries/` directory, which supports
merging/overriding user-defined queries. These queries are always used as-is,
which can cause issues if users have different versions of parsers; sometimes
the names for symbols change from one version to the next, and parsing a query
with an unsupported name causes an error.
We could of course update our queries to the newest parser-version, but this
also means that users are forced to one common parser version (most likely the
one provided by `nvim-treesitter`).  
While probably a good thing for the ecosystem, I don't like that every time
users will be unable to use all the queries just because there is one
incompatible query in the file.
Examples:
* `vim-matchup` has a few of these.
  https://github.com/andymass/vim-matchup/issues?q=is%3Aissue%20invalid%20node%20type
  Although, it's not really as dramatic as I thought. Still, I'd like to get
  ahead of this kind of issue.
  

So, we opt for a different system: queries are defined as
`Togglecomment.QueryDef`, which are objects that contain both the query-string
and all fields, symbols, and anonymous symbols the query needs. At runtime, we
can match this data with the result of `vim.treesitter.language.inspect` and
immediately discard the queries that won't be able to be compiled with the
parser (but we keep the ones that are still compatible!).
Another nice advantage is that we associate queries with identifiers, and
blacklist them very granularly that way:
```lua
tc.setup({
    disabled_plugin_queries = {
        cpp = {
            ["<<"] = true,
            class = true,
            for_stmt = true
        }
    }
})
```

To make writing these easier, source `require("togglecomment.dev")`. It will
create an usercommand, `:TCQC`, which can be invoked on a line with a
treesitter-query (or a visual selection that contains one), and it will parse
that query and generate a (hopefully complete, but check it!!)
`Togglecomment.QueryDef` in its place (actually it expands a snippet for fast
naming, so this requires that luasnip is available. If that is a problem, feel
free to make a version that only inserts the lines).
