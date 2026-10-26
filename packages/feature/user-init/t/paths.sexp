(
  (:id "r7:git-commit"
   :commands ("save-buffer" "save-buffers-kill-terminal")
   :rule :r7
   :lane "W3-2"
   :entry "git-commit"
   :state "$EDITOR invocation"
   :outcome "git-commit flow completes"
   :observe (:file_bytes :external_state)
   :scenario "user-init R7 git commit")
  (:id "r7:interactive-rebase"
   :commands ("save-buffer" "save-buffers-kill-terminal")
   :rule :r7
   :lane "W3-2"
   :entry "git-rebase -i"
   :state "$EDITOR invocation"
   :outcome "interactive-rebase flow completes"
   :observe (:file_bytes :external_state)
   :scenario "user-init R7 git rebase -i")
  (:id "r7:crontab"
   :commands ("save-buffer" "save-buffers-kill-terminal")
   :rule :r7
   :lane "W3-2"
   :entry "crontab-style editor"
   :state "$EDITOR invocation"
   :outcome "crontab flow completes"
   :observe (:file_bytes :external_state)
   :scenario "user-init R7 crontab-style editor")
  (:id "r7:xargs-non-tty"
   :commands ("save-buffer")
   :rule :r7
   :lane "W3-2"
   :entry "xargs with non-TTY stdin"
   :state "$EDITOR invocation"
   :outcome "xargs-non-tty flow completes"
   :observe (:file_bytes :external_state)
   :scenario "user-init R7 xargs non-tty stdin")
  (:id "r7:plus-n"
   :commands ("save-buffers-kill-terminal")
   :rule :r7
   :lane "W3-2"
   :entry "+N FILE"
   :state "$EDITOR invocation"
   :outcome "plus-n flow completes"
   :observe (:file_bytes :external_state)
   :scenario "user-init R7 +N FILE")
  (:id "r7:new-file"
   :commands ("save-buffer")
   :rule :r7
   :lane "W3-2"
   :entry "new file"
   :state "$EDITOR invocation"
   :outcome "new-file flow completes"
   :observe (:file_bytes :external_state)
   :scenario "user-init R7 new file")
  (:id "r7:interruption"
   :commands ("keyboard-quit")
   :rule :r7
   :lane "W3-2"
   :entry "editor interruption"
   :state "$EDITOR invocation"
   :outcome "interruption flow completes"
   :observe (:file_bytes :external_state)
   :scenario "user-init R7 interruption"))
