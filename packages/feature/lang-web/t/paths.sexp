((:id "r1:lang-web:extension-modes:find-file"
  :commands ("find-file" "save-buffer")
  :rule :r1
  :entry "path extension"
  :state "file opened"
  :outcome "selects a language mode from its extension and preserves buffer edits"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "lang-web/language-modes"
  :lane "W3-7d")
 (:id "r1:lang-web:syntax-indentation:tab"
  :commands ("find-file" "indent-for-tab-command" "save-buffer")
  :rule :r1
  :entry "key:tab"
  :state "file opened"
  :outcome "indents nested brackets by mode width and ignores string and comment brackets"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "lang-web/syntax-indentation"
  :lane "W3-7d")
 (:id "r1:lang-web:default-indentation:tab"
  :commands ("find-file" "indent-for-tab-command" "save-buffer")
  :rule :r1
  :entry "key:tab"
  :state "file opened"
  :outcome "HTML, CSS, and YAML align to the previous line"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "lang-web/default-indentation"
  :lane "W3-7d")
 (:id "r1:lang-web:comments:meta-semicolon"
  :commands ("find-file" "save-buffer")
  :rule :r1
  :entry "key:M-;"
  :state "language mode buffer with current line or active region"
  :outcome "M-; toggles language comment syntax and leaves JSON unchanged"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "lang-web/comments"
  :lane "W3-7d")
 (:id "r1:lang-web:pair-completion:delimiter-pairs"
  :commands ("find-file" "save-buffer")
  :rule :r1
  :entry "key:open-delimiter"
  :state "language mode buffer at an opening delimiter"
  :outcome "inserts registered delimiter pairs and skips existing closers only when the mode enables it"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "lang-web/pair-completion"
  :lane "W3-7d"))
