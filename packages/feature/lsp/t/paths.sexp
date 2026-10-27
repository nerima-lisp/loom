((:id "r1:lsp-start:mx"
      :commands
      (:lsp-start)
      :rule
      :r1
      :entry
      "mx"
      :state
      "default"
      :outcome
      "command runs from M-x"
      :observe
      (:screen_text)
      :scenario
      "lsp/server-nonzero-exit"
      :lane
      "W3-9")
 (:id "r5:lsp-start:lsp-server:nonzero"
      :commands
      (:lsp-start)
      :rule
      :r5
      :entry
      "mx"
      :state
      "tool:lsp-server"
      :outcome
      "nonzero"
      :observe
      (:external_state)
      :scenario
      "lsp/server-nonzero-exit"
      :lane
      "W3-9")
 (:id "r2:lsp-start:prompt-1:free-string:empty"
      :commands
      ("lsp-start")
      :rule
      :r2
      :lane
      "W3-9"
      :entry
      "mx;prompt:1:free-string"
      :state
      "prompt:free-string"
      :outcome
      "empty"
      :observe
      (:screen_text)
      :scenario
      "command-path/r2/lsp-start/free-string/empty")

 (:id "r1:lsp-completion-at-point:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22i%22%2C%22modifiers%22%3A%5B%22alt%22%2C%22control%22%5D%7D%5D%7D"
      :commands ("lsp-completion-at-point")
      :rule :r1
      :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"i\",\"modifiers\":[\"alt\",\"control\"]}]}"
      :state "default"
      :outcome "command runs from its key sequence"
      :observe (:screen_text)
      :scenario "command-path/r1/lsp-completion-at-point/key"
      :lane "W3-9")

 (:id "r1:lsp-completion-at-point:mx"
      :commands ("lsp-completion-at-point")
      :rule :r1
      :entry "mx"
      :state "default"
      :outcome "command runs from M-x"
      :observe (:screen_text)
      :scenario "command-path/r1/lsp-completion-at-point/mx"
      :lane "W3-9")

 (:id "r1:lsp-diagnostics:mx"
      :commands ("lsp-diagnostics")
      :rule :r1
      :entry "mx"
      :state "default"
      :outcome "command runs from M-x"
      :observe (:screen_text)
      :scenario "command-path/r1/lsp-diagnostics/mx"
      :lane "W3-9")

 (:id "r1:lsp-find-definition:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22.%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D"
      :commands ("lsp-find-definition")
      :rule :r1
      :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\".\",\"modifiers\":[\"alt\"]}]}"
      :state "default"
      :outcome "command runs from its key sequence"
      :observe (:screen_text)
      :scenario "command-path/r1/lsp-find-definition/key"
      :lane "W3-9")

 (:id "r1:lsp-find-definition:mx"
      :commands ("lsp-find-definition")
      :rule :r1
      :entry "mx"
      :state "default"
      :outcome "command runs from M-x"
      :observe (:screen_text)
      :scenario "command-path/r1/lsp-find-definition/mx"
      :lane "W3-9")

 (:id "r1:lsp-pop-definition:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22%2C%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D"
      :commands ("lsp-pop-definition")
      :rule :r1
      :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\",\",\"modifiers\":[\"alt\"]}]}"
      :state "default"
      :outcome "command runs from its key sequence"
      :observe (:screen_text)
      :scenario "command-path/r1/lsp-pop-definition/key"
      :lane "W3-9")

 (:id "r1:lsp-pop-definition:mx"
      :commands ("lsp-pop-definition")
      :rule :r1
      :entry "mx"
      :state "default"
      :outcome "command runs from M-x"
      :observe (:screen_text)
      :scenario "command-path/r1/lsp-pop-definition/mx"
      :lane "W3-9")

 (:id "r1:lsp-stop:mx"
      :commands ("lsp-stop")
      :rule :r1
      :entry "mx"
      :state "default"
      :outcome "command runs from M-x"
      :observe (:screen_text)
      :scenario "command-path/r1/lsp-stop/mx"
      :lane "W3-9")

 (:id "r2:lsp-start:prompt-1:free-string:accept"
      :commands ("lsp-start")
      :rule :r2
      :entry "mx;prompt:1:free-string"
      :state "prompt:free-string"
      :outcome "accept"
      :observe (:screen_text)
      :scenario "command-path/r2/lsp-start/free-string/accept"
      :lane "W3-9")

 (:id "r2:lsp-start:prompt-1:free-string:cancel"
      :commands ("lsp-start")
      :rule :r2
      :entry "mx;prompt:1:free-string"
      :state "prompt:free-string"
      :outcome "cancel"
      :observe (:screen_text)
      :scenario "command-path/r2/lsp-start/free-string/cancel"
      :lane "W3-9")

 (:id "r2:lsp-start:prompt-1:free-string:tab"
      :commands ("lsp-start")
      :rule :r2
      :entry "mx;prompt:1:free-string"
      :state "prompt:free-string"
      :outcome "tab"
      :observe (:screen_text)
      :scenario "command-path/r2/lsp-start/free-string/tab"
      :lane "W3-9")

 (:id "r2:lsp-start:prompt-1:free-string:history"
      :commands ("lsp-start")
      :rule :r2
      :entry "mx;prompt:1:free-string"
      :state "prompt:free-string"
      :outcome "history"
      :observe (:screen_text)
      :scenario "command-path/r2/lsp-start/free-string/history"
      :lane "W3-9")

 (:id "r2:lsp-start:prompt-2:yes-no:accept"
      :commands ("lsp-start")
      :rule :r2
      :entry "mx;prompt:2:yes-no"
      :state "prompt:yes-no"
      :outcome "accept"
      :observe (:screen_text)
      :scenario "command-path/r2/lsp-start/yes-no/accept"
      :lane "W3-9")

 (:id "r2:lsp-start:prompt-2:yes-no:cancel"
      :commands ("lsp-start")
      :rule :r2
      :entry "mx;prompt:2:yes-no"
      :state "prompt:yes-no"
      :outcome "cancel"
      :observe (:screen_text)
      :scenario "command-path/r2/lsp-start/yes-no/cancel"
      :lane "W3-9")

 (:id "r2:lsp-start:prompt-2:yes-no:empty"
      :commands ("lsp-start")
      :rule :r2
      :entry "mx;prompt:2:yes-no"
      :state "prompt:yes-no"
      :outcome "empty"
      :observe (:screen_text)
      :scenario "command-path/r2/lsp-start/yes-no/empty"
      :lane "W3-9")

 (:id "r2:lsp-start:prompt-2:yes-no:tab"
      :commands ("lsp-start")
      :rule :r2
      :entry "mx;prompt:2:yes-no"
      :state "prompt:yes-no"
      :outcome "tab"
      :observe (:screen_text)
      :scenario "command-path/r2/lsp-start/yes-no/tab"
      :lane "W3-9")

 (:id "r2:lsp-start:prompt-2:yes-no:history"
      :commands ("lsp-start")
      :rule :r2
      :entry "mx;prompt:2:yes-no"
      :state "prompt:yes-no"
      :outcome "history"
      :observe (:screen_text)
      :scenario "command-path/r2/lsp-start/yes-no/history"
      :lane "W3-9")

 (:id "r2:lsp-start:prompt-2:yes-no:invalid"
      :commands ("lsp-start")
      :rule :r2
      :entry "mx;prompt:2:yes-no"
      :state "prompt:yes-no"
      :outcome "invalid"
      :observe (:screen_text)
      :scenario "command-path/r2/lsp-start/yes-no/invalid"
      :lane "W3-9")
 (:id "r1:lsp-hover-at-point:mx"
      :commands ("lsp-hover-at-point")
      :rule :r1
      :entry "mx"
      :state "default"
      :outcome "command runs from M-x"
      :observe (:screen_text)
      :scenario "command-path/r1/lsp-hover-at-point/mx"
      :lane "W3-9")
)
