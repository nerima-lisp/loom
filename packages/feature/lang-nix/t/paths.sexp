((:id "w3-7c:lang-nix:indentation-ret"
  :commands (:newline :save-buffer)
  :rule :r1
  :entry "key: RET"
  :state "Nix buffer with a brace opener"
  :outcome "RET inserts the next line with two-space indentation"
  :observe (:file_bytes)
  :scenario "lang-nix-indentation-ret"
  :lane "W3-7c")
 (:id "w3-7c:lang-nix:indentation-tab"
  :commands (:indent-for-tab-command :save-buffer)
  :rule :r1
  :entry "key: TAB"
  :state "Nix attrsets with } inside strings and comments, plus a with assignment"
  :outcome "TAB indents a with body from its assignment and ignores later binding semicolons"
  :observe (:file_bytes)
  :scenario "lang-nix-indentation-tab"
  :lane "W3-7c")
 (:id "w3-7c:lang-nix:indentation-control-meta-backslash"
  :commands (:set-mark-command :indent-for-tab-command :save-buffer)
  :rule :r1
  :entry "key: C-M-backslash"
  :state "Nix region with let/in, list, parenthesis, and with expressions"
  :outcome "C-M-backslash applies Nix indentation and aligns matching clauses"
  :observe (:file_bytes)
  :scenario "lang-nix-indentation-control-meta-backslash"
  :lane "W3-7c")
 (:id "w3-7c:lang-nix:comment-dwim"
  :commands ("comment-line")
  :rule :r1
  :entry "key: M-;"
  :state "Nix code line and a whole-line comment"
  :outcome "M-; appends an inline comment marker and toggles the selected comment off"
  :observe (:file_bytes)
  :scenario "lang-nix-comment-dwim"
  :lane "W3-7c")
 (:id "w3-7c:lang-nix:pair-completion"
  :commands (:save-buffer)
  :rule :r1
  :entry "keys: { [ ( then ) ] }"
  :state "Nix mode with registered {}, [], and () pairs"
  :outcome "Openers insert closers and existing closers are skipped"
  :observe (:file_bytes)
  :scenario "lang-nix-pair-completion"
  :lane "W3-7c")
 (:id "r1:lang-nix:mode-assignment"
  :commands (:find-file)
  :rule :r1
  :entry "path extension"
  :state "Nix file exists while another file is active"
  :outcome ".nix selects Nix mode"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "lang-nix-mode-assignment"
  :lane "W3-7c"))
