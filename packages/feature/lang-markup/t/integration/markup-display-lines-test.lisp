(in-package #:loom/test)

(describe
  "markup-display-lines"
  (it
    "returns AST-backed Markdown headings, comments, and code lines"
    (expect
     (loom/feature/lang-markup:markup-display-lines
      "# Heading
<!-- begin
middle
end -->
```text
literal
```"
      :markdown)
     :to-equal
     '(
       ((:heading "# Heading"))
       ((:comment "<!-- begin"))
       ((:comment "middle"))
       ((:comment "end -->"))
       ((:code "```text"))
       ((:code "literal"))
       ((:code "```")))))

  (it
    "returns AST-backed Org headlines, comments, and source lines"
    (expect
     (loom/feature/lang-markup:markup-display-lines
      "* Heading
# line comment
#+BEGIN_COMMENT
hidden
#+END_COMMENT
#+BEGIN_SRC text
literal
#+END_SRC"
      :org)
     :to-equal
     '(
       ((:heading "* Heading"))
       ((:comment "# line comment"))
       ((:comment "#+BEGIN_COMMENT"))
       ((:comment "hidden"))
       ((:comment "#+END_COMMENT"))
       ((:code "#+BEGIN_SRC text"))
       ((:code "literal"))
       ((:code "#+END_SRC")))))
)

(describe
  "mode display-lines providers"
  (it
    "uses markup kinds through the mode query for Markdown and Org"
    (expect
     (loom/feature/mode:major-mode-display-lines "# Heading" :markdown)
     :to-equal '(((:heading "# Heading"))))
    (expect
     (loom/feature/mode:major-mode-display-lines "* Heading" :org)
     :to-equal '(((:heading "* Heading"))))))
