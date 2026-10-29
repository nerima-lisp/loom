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
 (:id "r1:lsp-find-references:mx"
      :commands ("lsp-find-references")
      :rule :r1
      :entry "mx"
      :state "default"
      :outcome "command runs from M-x"
      :observe (:screen_text)
      :scenario "command-path/r1/lsp-find-references/mx"
      :lane "W3-9")
 (:id "r1:lsp-rename:mx"
      :commands ("lsp-rename")
      :rule :r1
      :entry "mx"
      :state "default"
      :outcome "command runs from M-x"
      :observe (:screen_text)
      :scenario "command-path/r1/lsp-rename/mx"
      :lane "W3-9")
 (:id "r1:lsp-format-buffer:mx"
      :commands ("lsp-format-buffer")
      :rule :r1
      :entry "mx"
      :state "default"
      :outcome "command runs from M-x"
      :observe (:screen_text)
      :scenario "command-path/r1/lsp-format-buffer/mx"
      :lane "W3-9")
 (:id "r5:lsp-diagnostics:lsp-server:success"
      :commands
      (:lsp-diagnostics)
      :rule
      :r5
      :entry
      "mx"
      :state
      "tool:lsp-server"
      :outcome
      "success"
      :observe
      (:external_state)
      :scenario
      "lsp/diagnostics"
      :lane
      "W3-9")

 (:id "r2:lsp-rename:prompt-1:free-string:accept"
      :commands ("execute-extended-command" "lsp-start" "lsp-rename")
      :rule :r2
      :lane "W3-9"
      :entry "mx;prompt:1:free-string"
      :state "prompt:free-string"
      :outcome "accept"
      :observe (:screen_text)
      :scenario "command-path/r2/lsp-rename/free-string/accept")
 (:id "r2:lsp-rename:prompt-1:free-string:cancel"
      :commands ("execute-extended-command" "lsp-start" "lsp-rename")
      :rule :r2
      :lane "W3-9"
      :entry "mx;prompt:1:free-string"
      :state "prompt:free-string"
      :outcome "cancel"
      :observe (:screen_text)
      :scenario "command-path/r2/lsp-rename/free-string/cancel")
 (:id "r2:lsp-rename:prompt-1:free-string:empty"
      :commands ("execute-extended-command" "lsp-start" "lsp-rename")
      :rule :r2
      :lane "W3-9"
      :entry "mx;prompt:1:free-string"
      :state "prompt:free-string"
      :outcome "empty"
      :observe (:screen_text)
      :scenario "command-path/r2/lsp-rename/free-string/empty")
 (:id "r2:lsp-rename:prompt-1:free-string:tab"
      :commands ("execute-extended-command" "lsp-start" "lsp-rename")
      :rule :r2
      :lane "W3-9"
      :entry "mx;prompt:1:free-string"
      :state "prompt:free-string"
      :outcome "tab"
      :observe (:screen_text)
      :scenario "command-path/r2/lsp-rename/free-string/tab")
 (:id "r2:lsp-rename:prompt-1:free-string:history"
      :commands ("execute-extended-command" "lsp-start" "lsp-rename")
      :rule :r2
      :lane "W3-9"
      :entry "mx;prompt:1:free-string"
      :state "prompt:free-string"
      :outcome "history"
      :observe (:screen_text)
      :scenario "command-path/r2/lsp-rename/free-string/history")
 (:id "r3:lsp-rename:effect"
      :commands ("execute-extended-command" "lsp-start" "lsp-rename")
      :rule :r3
      :lane "W3-9"
      :entry "mx"
      :state "editable-buffer"
      :outcome "buffer changes"
      :observe (:file_bytes)
      :scenario "command-path/r3/lsp-rename/effect")
 (:id "r3:lsp-rename:undo"
      :commands ("execute-extended-command" "lsp-start" "lsp-rename" "undo")
      :rule :r3
      :lane "W3-9"
      :entry "mx"
      :state "after-one-change"
      :outcome "original bytes restored"
      :observe (:file_bytes)
      :scenario "command-path/r3/lsp-rename/undo")
 (:id "r3:lsp-rename:read-only"
      :commands ("execute-extended-command" "lsp-start" "lsp-rename" "toggle-read-only")
      :rule :r3
      :lane "W3-9"
      :entry "mx"
      :state "read-only-buffer"
      :outcome "rejected without byte changes"
      :observe (:file_bytes)
      :scenario "command-path/r3/lsp-rename/read-only")
 (:id "r3:lsp-rename:narrow"
      :commands ("execute-extended-command" "lsp-start" "lsp-rename" "narrow-to-region")
      :rule :r3
      :lane "W3-9"
      :entry "mx"
      :state "narrowed-buffer"
      :outcome "outside range remains unchanged"
      :observe (:file_bytes)
      :scenario "command-path/r3/lsp-rename/narrow")
 (:id "r3:lsp-rename:split-window"
      :commands ("execute-extended-command" "lsp-start" "lsp-rename" "split-window-below")
      :rule :r3
      :lane "W3-9"
      :entry "mx"
      :state "split-window"
      :outcome "both views reflect the change"
      :observe (:screen_text)
      :scenario "command-path/r3/lsp-rename/split-window")
 (:id "r3:lsp-rename:macro-replay"
      :commands ("execute-extended-command" "lsp-start" "lsp-rename" "start-kbd-macro" "end-kbd-macro" "undo" "call-last-kbd-macro")
      :rule :r3
      :lane "W3-9"
      :entry "macro"
      :state "macro-recording"
      :outcome "replay has the same effect"
      :observe (:file_bytes)
      :scenario "command-path/r3/lsp-rename/macro-replay")
 (:id "r3:lsp-rename:prefix-u4"
      :commands ("execute-extended-command" "lsp-start" "lsp-rename")
      :rule :r3
      :lane "W3-9"
      :entry "mx"
      :state "prefix-C-u-4"
      :outcome "specified prefix behavior is observed"
      :observe (:file_bytes)
      :scenario "command-path/r3/lsp-rename/prefix-u4")
 (:id "r3:lsp-format-buffer:effect"
      :commands ("execute-extended-command" "lsp-start" "lsp-format-buffer")
      :rule :r3
      :lane "W3-9"
      :entry "mx"
      :state "editable-buffer"
      :outcome "buffer changes"
      :observe (:file_bytes)
      :scenario "command-path/r3/lsp-format-buffer/effect")
 (:id "r3:lsp-format-buffer:undo"
      :commands ("execute-extended-command" "lsp-start" "lsp-format-buffer" "undo")
      :rule :r3
      :lane "W3-9"
      :entry "mx"
      :state "after-one-change"
      :outcome "original bytes restored"
      :observe (:file_bytes)
      :scenario "command-path/r3/lsp-format-buffer/undo")
 (:id "r3:lsp-format-buffer:read-only"
      :commands ("execute-extended-command" "lsp-start" "toggle-read-only" "lsp-format-buffer")
      :rule :r3
      :lane "W3-9"
      :entry "mx"
      :state "read-only-buffer"
      :outcome "rejected without byte changes"
      :observe (:file_bytes)
      :scenario "command-path/r3/lsp-format-buffer/read-only")
 (:id "r3:lsp-format-buffer:narrow"
      :commands ("execute-extended-command" "lsp-start" "narrow-to-region" "lsp-format-buffer")
      :rule :r3
      :lane "W3-9"
      :entry "mx"
      :state "narrowed-buffer"
      :outcome "outside range remains unchanged"
      :observe (:file_bytes)
      :scenario "command-path/r3/lsp-format-buffer/narrow")
 (:id "r3:lsp-format-buffer:split-window"
      :commands ("execute-extended-command" "lsp-start" "split-window-below" "lsp-format-buffer")
      :rule :r3
      :lane "W3-9"
      :entry "mx"
      :state "split-window"
      :outcome "both views reflect the change"
      :observe (:screen_text)
      :scenario "command-path/r3/lsp-format-buffer/split-window")
 (:id "r3:lsp-format-buffer:macro-replay"
      :commands ("execute-extended-command" "lsp-start" "start-kbd-macro" "lsp-format-buffer" "end-kbd-macro" "undo" "call-last-kbd-macro")
      :rule :r3
      :lane "W3-9"
      :entry "macro"
      :state "macro-recording"
      :outcome "replay has the same effect"
      :observe (:file_bytes)
      :scenario "command-path/r3/lsp-format-buffer/macro-replay")
 (:id "r3:lsp-format-buffer:prefix-u4"
      :commands ("execute-extended-command" "lsp-start" "lsp-format-buffer")
      :rule :r3
      :lane "W3-9"
      :entry "mx"
      :state "prefix-C-u-4"
      :outcome "specified prefix behavior is observed"
      :observe (:file_bytes)
      :scenario "command-path/r3/lsp-format-buffer/prefix-u4")

 (:id "r5:lsp-start:lsp-server:success"
      :commands (:lsp-start)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "success"
      :observe (:external_state)
      :scenario "lsp/r5-typescript-success/start"
      :lane "W3-9")
 (:id "r5:lsp-stop:lsp-server:success"
      :commands (:lsp-stop)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "success"
      :observe (:external_state)
      :scenario "lsp/r5-typescript-success/stop"
      :lane "W3-9")
 (:id "r5:lsp-completion-at-point:lsp-server:success"
      :commands (:lsp-completion-at-point)
      :rule :r5
      :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"i\",\"modifiers\":[\"alt\",\"control\"]}]}"
      :state "tool:lsp-server"
      :outcome "success"
      :observe (:external_state)
      :scenario "lsp/r5-typescript-success/hover-completion"
      :lane "W3-9")
 (:id "r5:lsp-find-definition:lsp-server:success"
      :commands (:lsp-find-definition)
      :rule :r5
      :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\".\",\"modifiers\":[\"alt\"]}]}"
      :state "tool:lsp-server"
      :outcome "success"
      :observe (:external_state)
      :scenario "lsp/r5-typescript-success/definition"
      :lane "W3-9")
 (:id "r5:lsp-hover-at-point:lsp-server:success"
      :commands (:lsp-hover-at-point)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "success"
      :observe (:external_state)
      :scenario "lsp/r5-typescript-success/hover-completion"
      :lane "W3-9")
 (:id "r5:lsp-find-references:lsp-server:success"
      :commands (:lsp-find-references)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "success"
      :observe (:external_state)
      :scenario "lsp/r5-typescript-success/editing"
      :lane "W3-9")
 (:id "r5:lsp-rename:lsp-server:success"
      :commands (:lsp-rename)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "success"
      :observe (:external_state)
      :scenario "lsp/r5-typescript-success/editing"
      :lane "W3-9")
 (:id "r5:lsp-format-buffer:lsp-server:success"
      :commands (:lsp-format-buffer)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "success"
      :observe (:external_state)
      :scenario "lsp/r5-typescript-success/editing"
      :lane "W3-9")
 (:id "r5:lsp-start:lsp-server:missing"
      :commands (:lsp-start)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "missing"
      :observe (:external_state)
      :scenario "lsp/r5-missing-server"
      :lane "W3-9")
 (:id "r5:lsp-stop:lsp-server:missing"
      :commands (:lsp-stop)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "missing"
      :observe (:external_state)
      :scenario "lsp/r5-missing-server"
      :lane "W3-9")
 (:id "r5:lsp-diagnostics:lsp-server:missing"
      :commands (:lsp-diagnostics)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "missing"
      :observe (:external_state)
      :scenario "lsp/r5-missing-server"
      :lane "W3-9")
 (:id "r5:lsp-completion-at-point:lsp-server:missing"
      :commands (:lsp-completion-at-point)
      :rule :r5
      :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"i\",\"modifiers\":[\"alt\",\"control\"]}]}"
      :state "tool:lsp-server"
      :outcome "missing"
      :observe (:external_state)
      :scenario "lsp/r5-missing-server"
      :lane "W3-9")
 (:id "r5:lsp-find-definition:lsp-server:missing"
      :commands (:lsp-find-definition)
      :rule :r5
      :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\".\",\"modifiers\":[\"alt\"]}]}"
      :state "tool:lsp-server"
      :outcome "missing"
      :observe (:external_state)
      :scenario "lsp/r5-missing-server"
      :lane "W3-9")
 (:id "r5:lsp-find-references:lsp-server:missing"
      :commands (:lsp-find-references)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "missing"
      :observe (:external_state)
      :scenario "lsp/r5-missing-server"
      :lane "W3-9")
 (:id "r5:lsp-hover-at-point:lsp-server:missing"
      :commands (:lsp-hover-at-point)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "missing"
      :observe (:external_state)
      :scenario "lsp/r5-missing-server"
      :lane "W3-9")
 (:id "r5:lsp-rename:lsp-server:missing"
      :commands (:lsp-rename)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "missing"
      :observe (:external_state)
      :scenario "lsp/r5-missing-server"
      :lane "W3-9")
 (:id "r5:lsp-format-buffer:lsp-server:missing"
      :commands (:lsp-format-buffer)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "missing"
      :observe (:external_state)
      :scenario "lsp/r5-missing-server"
      :lane "W3-9")
 (:id "r5:lsp-completion-at-point:lsp-server:nonzero"
      :commands (:lsp-completion-at-point)
      :rule :r5
      :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"i\",\"modifiers\":[\"alt\",\"control\"]}]}"
      :state "tool:lsp-server"
      :outcome "nonzero"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-nonzero"
      :lane "W3-9")
 (:id "r5:lsp-diagnostics:lsp-server:nonzero"
      :commands (:lsp-diagnostics)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "nonzero"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-nonzero"
      :lane "W3-9")
 (:id "r5:lsp-find-definition:lsp-server:nonzero"
      :commands (:lsp-find-definition)
      :rule :r5
      :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\".\",\"modifiers\":[\"alt\"]}]}"
      :state "tool:lsp-server"
      :outcome "nonzero"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-nonzero"
      :lane "W3-9")
 (:id "r5:lsp-find-references:lsp-server:nonzero"
      :commands (:lsp-find-references)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "nonzero"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-nonzero"
      :lane "W3-9")
 (:id "r5:lsp-format-buffer:lsp-server:nonzero"
      :commands (:lsp-format-buffer)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "nonzero"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-nonzero"
      :lane "W3-9")
 (:id "r5:lsp-hover-at-point:lsp-server:nonzero"
      :commands (:lsp-hover-at-point)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "nonzero"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-nonzero"
      :lane "W3-9")
 (:id "r5:lsp-rename:lsp-server:nonzero"
      :commands (:lsp-rename)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "nonzero"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-nonzero"
      :lane "W3-9")
 (:id "r5:lsp-stop:lsp-server:nonzero"
      :commands (:lsp-stop)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "nonzero"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-nonzero"
      :lane "W3-9")
 (:id "r5:lsp-start:lsp-server:interrupted"
      :commands (:lsp-start)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "interrupted"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-interrupted"
      :lane "W3-9")
 (:id "r5:lsp-completion-at-point:lsp-server:interrupted"
      :commands (:lsp-completion-at-point)
      :rule :r5
      :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"i\",\"modifiers\":[\"alt\",\"control\"]}]}"
      :state "tool:lsp-server"
      :outcome "interrupted"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-interrupted"
      :lane "W3-9")
 (:id "r5:lsp-diagnostics:lsp-server:interrupted"
      :commands (:lsp-diagnostics)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "interrupted"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-interrupted"
      :lane "W3-9")
 (:id "r5:lsp-find-definition:lsp-server:interrupted"
      :commands (:lsp-find-definition)
      :rule :r5
      :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\".\",\"modifiers\":[\"alt\"]}]}"
      :state "tool:lsp-server"
      :outcome "interrupted"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-interrupted"
      :lane "W3-9")
 (:id "r5:lsp-find-references:lsp-server:interrupted"
      :commands (:lsp-find-references)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "interrupted"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-interrupted"
      :lane "W3-9")
 (:id "r5:lsp-format-buffer:lsp-server:interrupted"
      :commands (:lsp-format-buffer)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "interrupted"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-interrupted"
      :lane "W3-9")
 (:id "r5:lsp-hover-at-point:lsp-server:interrupted"
      :commands (:lsp-hover-at-point)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "interrupted"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-interrupted"
      :lane "W3-9")
 (:id "r5:lsp-rename:lsp-server:interrupted"
      :commands (:lsp-rename)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "interrupted"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-interrupted"
      :lane "W3-9")
 (:id "r5:lsp-stop:lsp-server:interrupted"
      :commands (:lsp-stop)
      :rule :r5
      :entry "mx"
      :state "tool:lsp-server"
      :outcome "interrupted"
      :observe (:external_state)
      :scenario "lsp/r5-nixd-interrupted"
      :lane "W3-9"))
