((:id "r9:daily"
  :commands ("project-find-file" "indent-for-tab-command" "forward-slurp-sexp"
             "comment-line" "newline" "save-buffer" "back-to-indentation"
             "delete-horizontal-space" "eval-expression" "toggle-file-tree"
             "file-tree-select-next" "lsp-start" "lsp-completion-at-point"
             "lsp-find-definition" "lsp-stop" "list-buffers"
             "save-buffers-kill-terminal" "search-query-replace"
             "save-some-buffers")
  :rule :r9
  :lane "T9"
  :entry "daily"
  :state "one scratch HOME shared by loom processes started in turn"
  :outcome "every scene of the day shows its expected effect"
  :observe (:screen_text :cursor :cell_attrs :file_bytes :external_state)
  :scenario "r9/daily"))
