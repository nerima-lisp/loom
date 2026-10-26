((:id "r1:comment-line:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22%3B%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D"
  :commands (:comment-line)
  :rule :r1
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\";\",\"modifiers\":[\"alt\"]}]}"
  :state "Markdown or Org buffer with M-; available"
  :outcome "M-; comments Markdown with an HTML block and Org with #, including a selected region"
  :observe (:file_bytes :cursor)
  :scenario "lang-markup/markdown-org-comment-dwim"
  :lane "W3-7e")
 (:id "r1:eval-expression:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22%3A%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D"
   :commands (:eval-expression)
   :rule :r1
   :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\":\",\"modifiers\":[\"alt\"]}]}"
   :state "Markdown buffer with M-: eval-expression available"
   :outcome "M-: returns AST-backed Markdown and Org multiline display values without changing the source buffer"
   :observe (:file_bytes :screen_text)
   :scenario "lang-markup/display-values"
   :lane "W3-7e")
 (:id "r1:switch-to-buffer:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22b%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
   :commands (:switch-to-buffer)
   :rule :r1
   :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"b\",\"modifiers\":[]}]}"
   :state "Evaluation result buffer selected with original Markdown buffer open"
   :outcome "C-x b returns to the Markdown source at its original cursor position"
   :observe (:file_bytes :cursor)
   :scenario "lang-markup/display-values"
   :lane "W3-7e"))
