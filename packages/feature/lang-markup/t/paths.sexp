((:id "w3-7e:lang-markup:markdown-list-continuation"
  :commands (:find-file :move-end-of-line :next-line :newline :save-buffer)
  :rule :r1
  :entry "key: RET"
  :state "Markdown list item at end of line"
  :outcome "RET continues unordered, ordered and task markers, advances ordered markers, and deletes empty items"
  :observe (:file_bytes :cursor)
  :scenario "lang-markup/markdown-list-continuation"
  :lane "W3-7e")
 (:id "w3-7e:lang-markup:org-list-continuation"
  :commands (:find-file :move-end-of-line :next-line :newline :save-buffer)
  :rule :r1
  :entry "key: RET"
  :state "Org plain-list item or headline at end of line"
  :outcome "RET continues unordered and ordered lists, advances ordered markers, deletes empty items, and leaves headlines uncontinued"
  :observe (:file_bytes :cursor)
  :scenario "lang-markup/org-list-continuation"
  :lane "W3-7e"))
