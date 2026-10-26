(
 (:id "r1:lsp-start:mx"
  :commands (:lsp-start)
  :rule :r1
  :entry "mx"
  :state "default"
  :outcome "command runs from M-x"
  :observe (:screen_text)
  :scenario "lsp/server-nonzero-exit"
  :lane "W3-9")
 (:id "r5:lsp-start:lsp-server:nonzero"
  :commands (:lsp-start)
  :rule :r5
  :entry "mx"
  :state "tool:lsp-server"
  :outcome "nonzero"
  :observe (:external_state)
  :scenario "lsp/server-nonzero-exit"
  :lane "W3-9"))
