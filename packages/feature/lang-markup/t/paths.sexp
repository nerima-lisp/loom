((:id "r1:comment-line:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22%3B%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D"
  :commands (:comment-line)
  :rule :r1
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\";\",\"modifiers\":[\"alt\"]}]}"
  :state "Markdown or Org buffer with M-; available"
  :outcome "M-; comments Markdown with an HTML block and Org with #, including a selected region"
  :observe (:file_bytes :cursor)
  :scenario "lang-markup/markdown-org-comment-dwim"
  :lane "W3-7e"))
