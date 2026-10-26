(
  (:id "r1:format-current-buffer:mx"
   :commands (:format-current-buffer)
   :rule :r1
   :entry "mx"
   :state "default"
   :outcome "command runs from M-x"
   :observe (:screen_text)
   :scenario "format/real-nixfmt-success"
   :lane "W3-11")
  (:id "r1:format-on-save-mode:mx"
   :commands (:format-on-save-mode)
   :rule :r1
   :entry "mx"
   :state "default"
   :outcome "command runs from M-x"
   :observe (:screen_text :file_bytes)
   :scenario "format/format-on-save-real-nixfmt"
   :lane "W3-11")
  (:id "r1:set-format-command:mx"
   :commands (:set-format-command)
   :rule :r1
   :entry "mx"
   :state "default"
   :outcome "command runs from M-x"
   :observe (:screen_text)
   :scenario "format/format-on-save-real-nixfmt"
   :lane "W3-11")
  (:id "r5:format-current-buffer:shell:success"
   :commands (:format-current-buffer)
   :rule :r5
   :entry "mx"
   :state "tool:shell"
   :outcome "success"
   :observe (:external_state)
   :scenario "format/real-nixfmt-success"
   :lane "W3-11")
  (:id "r5:format-current-buffer:shell:missing"
   :commands (:format-current-buffer)
   :rule :r5
   :entry "mx"
   :state "tool:shell"
   :outcome "missing"
   :observe (:external_state)
   :scenario "format/missing-formatter"
   :lane "W3-11")
  (:id "r5:format-current-buffer:shell:nonzero"
   :commands (:format-current-buffer)
   :rule :r5
   :entry "mx"
   :state "tool:shell"
   :outcome "nonzero"
   :observe (:external_state)
   :scenario "format/real-nixfmt-nonzero"
   :lane "W3-11")
  (:id "r5:format-current-buffer:shell:interrupted"
   :commands (:format-current-buffer)
   :rule :r5
   :entry "mx"
   :state "tool:shell"
   :outcome "interrupted"
   :observe (:screen_text)
   :scenario "format/interrupted-formatter"
   :lane "W3-11")
  (:id "r2:format-current-buffer:prompt-1:free-string:accept"
   :commands (:format-current-buffer)
   :rule :r2
   :entry "mx;prompt:1:free-string"
   :state "prompt:free-string"
   :outcome "accept"
   :observe (:screen_text)
   :scenario "format/format-current-buffer-prompt-accept"
   :lane "W3-11")
  (:id "r2:format-current-buffer:prompt-1:free-string:cancel"
   :commands (:format-current-buffer)
   :rule :r2
   :entry "mx;prompt:1:free-string"
   :state "prompt:free-string"
   :outcome "cancel"
   :observe (:screen_text)
   :scenario "format/format-current-buffer-prompt-cancel"
   :lane "W3-11")
  (:id "r2:format-current-buffer:prompt-1:free-string:empty"
   :commands (:format-current-buffer)
   :rule :r2
   :entry "mx;prompt:1:free-string"
   :state "prompt:free-string"
   :outcome "empty"
   :observe (:screen_text)
   :scenario "format/format-current-buffer-prompt-empty"
   :lane "W3-11")
  (:id "r2:format-current-buffer:prompt-1:free-string:tab"
   :commands (:format-current-buffer)
   :rule :r2
   :entry "mx;prompt:1:free-string"
   :state "prompt:free-string"
   :outcome "tab"
   :observe (:screen_text)
   :scenario "format/format-current-buffer-prompt-tab"
   :lane "W3-11")
  (:id "r2:format-current-buffer:prompt-1:free-string:history"
   :commands (:format-current-buffer)
   :rule :r2
   :entry "mx;prompt:1:free-string"
   :state "prompt:free-string"
   :outcome "history"
   :observe (:screen_text)
   :scenario "format/format-current-buffer-prompt-history"
   :lane "W3-11")
  (:id "r2:set-format-command:prompt-1:free-string:accept"
   :commands (:set-format-command)
   :rule :r2
   :entry "mx;prompt:1:free-string"
   :state "prompt:free-string"
   :outcome "accept"
   :observe (:screen_text)
   :scenario "format/set-format-command-prompt-accept"
   :lane "W3-11")
  (:id "r2:set-format-command:prompt-1:free-string:cancel"
   :commands (:set-format-command)
   :rule :r2
   :entry "mx;prompt:1:free-string"
   :state "prompt:free-string"
   :outcome "cancel"
   :observe (:screen_text)
   :scenario "format/set-format-command-prompt-cancel"
   :lane "W3-11")
  (:id "r2:set-format-command:prompt-1:free-string:empty"
   :commands (:set-format-command)
   :rule :r2
   :entry "mx;prompt:1:free-string"
   :state "prompt:free-string"
   :outcome "empty"
   :observe (:screen_text)
   :scenario "format/set-format-command-prompt-empty"
   :lane "W3-11")
  (:id "r2:set-format-command:prompt-1:free-string:tab"
   :commands (:set-format-command)
   :rule :r2
   :entry "mx;prompt:1:free-string"
   :state "prompt:free-string"
   :outcome "tab"
   :observe (:screen_text)
   :scenario "format/set-format-command-prompt-tab"
   :lane "W3-11")
  (:id "r2:set-format-command:prompt-1:free-string:history"
   :commands (:set-format-command)
   :rule :r2
   :entry "mx;prompt:1:free-string"
   :state "prompt:free-string"
   :outcome "history"
   :observe (:screen_text :external_state :file_bytes)
   :scenario "format/set-format-command-prompt-history"
   :lane "W3-11")
  (:id "r3:format-current-buffer:read-only"
   :commands (:toggle-read-only :format-current-buffer)
   :rule :r3
   :entry "mx"
   :state "read-only-buffer"
   :outcome "rejected without byte changes"
   :observe (:file_bytes)
   :scenario "format/format-current-buffer-read-only"
   :lane "W3-11")
  (:id "r3:format-current-buffer:narrow"
   :commands (:set-mark-command :narrow-to-region :format-current-buffer)
   :rule :r3
   :entry "mx"
   :state "narrowed-buffer"
   :outcome "outside range remains unchanged"
   :observe (:file_bytes)
   :scenario "format/format-current-buffer-narrow"
   :lane "W3-11")
  (:id "r3:format-current-buffer:split-window"
   :commands (:split-window-below :format-current-buffer :save-buffer)
   :rule :r3
   :entry "mx"
   :state "split-window"
   :outcome "both views reflect the change"
   :observe (:screen_text)
   :scenario "format/format-current-buffer-split-window"
   :lane "W3-11")
  (:id "r3:format-current-buffer:prefix-u4"
   :commands (:format-current-buffer :save-buffer)
   :rule :r3
   :entry "mx"
   :state "prefix-C-u-4"
   :outcome "specified prefix behavior is observed"
   :observe (:file_bytes)
   :scenario "format/format-current-buffer-prefix-u4"
   :lane "W3-11")
  (:id "r3:format-current-buffer:effect"
   :commands (:format-current-buffer :save-buffer)
   :rule :r3
   :entry "mx"
   :state "editable-buffer"
   :outcome "buffer changes"
   :observe (:screen_text :file_bytes :cursor)
   :scenario "format/format-current-buffer-effect"
   :lane "W3-11")
  (:id "r3:format-current-buffer:undo"
   :commands (:format-current-buffer :undo :save-buffer)
   :rule :r3
   :entry "mx"
   :state "after-one-change"
   :outcome "original bytes restored"
   :observe (:screen_text :file_bytes)
   :scenario "format/format-current-buffer-undo"
   :lane "W3-11")
  (:id "r3:format-current-buffer:macro-replay" :commands (:format-current-buffer) :rule :r3 :lane "W3-11" :entry "macro" :state "macro-recording" :outcome "replay has the same effect" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r3/format-current-buffer/macro-replay")
)
