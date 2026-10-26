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
  :lane "W3-7e")
 (:id "r1:lang-markup:markdown:indent-ret"
  :commands (:newline :save-buffer)
  :rule :r1
  :entry "key: RET"
  :state "Markdown list item with a continuation line"
  :outcome "RET continues the list item with indentation from the list syntax tree"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "lang-markup/markdown-indent-ret"
  :lane "W3-7e")
 (:id "r1:lang-markup:markdown:indent-tab"
  :commands (:indent-for-tab-command :save-buffer)
  :rule :r1
  :entry "key: TAB"
  :state "Markdown list item with a nested continuation line"
  :outcome "TAB reindents the current line from the list syntax tree"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "lang-markup/markdown-indent-tab"
  :lane "W3-7e")
 (:id "r1:lang-markup:markdown:indent-region"
  :commands (:set-mark-command :indent-for-tab-command :save-buffer)
  :rule :r1
  :entry "key: C-M-backslash"
  :state "Markdown list region with nested items"
  :outcome "C-M-backslash reindents the selected list region from the syntax tree"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "lang-markup/markdown-indent-region"
  :lane "W3-7e")
 (:id "r1:lang-markup:org:indent-ret"
  :commands (:newline :save-buffer)
  :rule :r1
  :entry "key: RET"
  :state "Org list item with a continuation line"
  :outcome "RET continues the list item with indentation from the list syntax tree"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "lang-markup/org-indent-ret"
  :lane "W3-7e")
 (:id "r1:lang-markup:org:indent-tab"
  :commands (:indent-for-tab-command :save-buffer)
  :rule :r1
  :entry "key: TAB"
  :state "Org list item with a nested continuation line"
  :outcome "TAB reindents the current line from the list syntax tree"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "lang-markup/org-indent-tab"
  :lane "W3-7e")
 (:id "r1:lang-markup:org:indent-region"
  :commands (:set-mark-command :indent-for-tab-command :save-buffer)
  :rule :r1
  :entry "key: C-M-backslash"
  :state "Org list region with nested items"
  :outcome "C-M-backslash reindents the selected list region from the syntax tree"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "lang-markup/org-indent-region"
  :lane "W3-7e"))
