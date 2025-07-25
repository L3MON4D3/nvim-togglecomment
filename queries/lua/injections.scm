;; extends

(
  (field
    name: (identifier) @name
    value: (string content: (string_content) @injection.content))
  (#eq? @name "query")
  ; enable this injection only in our files.
  (#togglecomment-tc-query-file?)
  (#set! injection.language "query")
)
