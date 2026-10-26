((:id "r1:lang-web:extension-modes:find-file"
  :commands ("find-file" "save-buffer")
  :rule :r1
  :entry "path extension"
  :state "file opened"
  :outcome "selects a language mode from its extension and preserves buffer edits"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "lang-web/language-modes"
  :lane "W3-7d"))
