(
  (:id "r1:save-buffers-kill-terminal:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22c%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D"
   :commands ("save-buffers-kill-terminal") :rule :r1 :lane "W3-2"
   :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"c\",\"modifiers\":[\"control\"]}]}"
   :state "default" :outcome "command runs from its key sequence"
   :observe (:screen_text :cursor :file_bytes :external_state)
   :scenario "lifecycle/save-buffers-kill-terminal-key")
  (:id "r1:save-buffers-kill-terminal:mx" :commands ("save-buffers-kill-terminal")
   :rule :r1 :lane "W3-2" :entry "mx" :state "default"
   :outcome "command runs from M-x" :observe (:screen_text :cursor :file_bytes :external_state)
   :scenario "lifecycle/save-buffers-kill-terminal-mx")
  (:id "r2:save-buffers-kill-terminal:prompt-1:free-string:accept"
   :commands ("save-buffers-kill-terminal") :rule :r2 :lane "W3-2"
   :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"c\",\"modifiers\":[\"control\"]}]};prompt:1:free-string"
   :state "prompt:free-string" :outcome "accept"
   :observe (:screen_text :cursor :file_bytes :external_state) :scenario "lifecycle/save-buffer-prompt-accept")
  (:id "r2:save-buffers-kill-terminal:prompt-1:free-string:cancel"
   :commands ("save-buffers-kill-terminal") :rule :r2 :lane "W3-2"
   :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"c\",\"modifiers\":[\"control\"]}]};prompt:1:free-string"
   :state "prompt:free-string" :outcome "cancel"
   :observe (:screen_text :cursor :file_bytes :external_state)
   :scenario "lifecycle/save-buffer-prompt-cancel")
  (:id "r2:save-buffers-kill-terminal:prompt-1:free-string:empty"
   :commands ("save-buffers-kill-terminal") :rule :r2 :lane "W3-2"
   :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"c\",\"modifiers\":[\"control\"]}]};prompt:1:free-string"
   :state "prompt:free-string" :outcome "empty"
   :observe (:screen_text :cursor :file_bytes :external_state)
   :scenario "lifecycle/save-buffer-prompt-empty")
  (:id "r2:save-buffers-kill-terminal:prompt-1:free-string:tab"
   :commands ("save-buffers-kill-terminal") :rule :r2 :lane "W3-2"
   :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"c\",\"modifiers\":[\"control\"]}]};prompt:1:free-string"
   :state "prompt:free-string" :outcome "tab"
   :observe (:screen_text :cursor :file_bytes :external_state)
   :scenario "lifecycle/save-buffer-prompt-tab")
  (:id "r2:save-buffers-kill-terminal:prompt-1:free-string:history"
   :commands ("save-buffers-kill-terminal") :rule :r2 :lane "W3-2"
   :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"c\",\"modifiers\":[\"control\"]}]};prompt:1:free-string"
   :state "prompt:free-string" :outcome "history"
   :observe (:screen_text :cursor :file_bytes :external_state)
   :scenario "lifecycle/save-buffer-prompt-history")
  (:id "r1:kill-loom-abort:mx" :commands ("kill-loom-abort")
   :rule :r1 :lane "W3-2" :entry "mx" :state "default"
   :outcome "command runs from M-x" :observe (:screen_text :cursor :file_bytes :external_state)
   :scenario "lifecycle/abort-exits-one")
  (:id "r2:kill-loom-abort:prompt-1:free-string:accept"
   :commands ("kill-loom-abort") :rule :r2 :lane "W3-2"
   :entry "mx;prompt:1:free-string" :state "prompt:free-string" :outcome "accept"
   :observe (:screen_text :cursor :file_bytes :external_state) :scenario "lifecycle/abort-prompt-accept")
  (:id "r2:kill-loom-abort:prompt-1:free-string:cancel"
   :commands ("kill-loom-abort") :rule :r2 :lane "W3-2"
   :entry "mx;prompt:1:free-string" :state "prompt:free-string" :outcome "cancel"
   :observe (:screen_text :cursor :file_bytes :external_state)
   :scenario "lifecycle/abort-prompt-cancel")
  (:id "r2:kill-loom-abort:prompt-1:free-string:empty"
   :commands ("kill-loom-abort") :rule :r2 :lane "W3-2"
   :entry "mx;prompt:1:free-string" :state "prompt:free-string" :outcome "empty"
   :observe (:screen_text :cursor :file_bytes :external_state)
   :scenario "lifecycle/abort-prompt-empty")
  (:id "r2:kill-loom-abort:prompt-1:free-string:tab"
   :commands ("kill-loom-abort") :rule :r2 :lane "W3-2"
   :entry "mx;prompt:1:free-string" :state "prompt:free-string" :outcome "tab"
   :observe (:screen_text :cursor :file_bytes :external_state)
   :scenario "lifecycle/abort-prompt-tab")
  (:id "r2:kill-loom-abort:prompt-1:free-string:history"
   :commands ("kill-loom-abort") :rule :r2 :lane "W3-2"
   :entry "mx;prompt:1:free-string" :state "prompt:free-string" :outcome "history"
   :observe (:screen_text :cursor :file_bytes :external_state)
   :scenario "lifecycle/abort-prompt-history")
  (:id "r1:suspend-frame:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22z%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D"
   :commands ("suspend-frame") :rule :r1 :lane "W3-2"
   :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"z\",\"modifiers\":[\"control\"]}]}"
   :state "default" :outcome "command runs from its key sequence"
   :observe (:screen_text :cursor :external_state)
   :scenario "lifecycle/c-z-suspend-resume")
  (:id "r1:suspend-frame:mx" :commands ("suspend-frame")
   :rule :r1 :lane "W3-2" :entry "mx" :state "default"
   :outcome "command runs from M-x" :observe (:screen_text :cursor :external_state)
   :scenario "lifecycle/suspend-frame-mx")
  (:id "r6:suspend:c-z" :commands ("suspend-frame") :rule :r6 :lane "W3-2"
   :entry "C-z" :state "running-process" :outcome "process suspends and resumes"
   :observe (:external_state) :scenario "lifecycle/c-z-suspend-resume")
  (:id "r6:signal:sigterm" :commands () :rule :r6 :lane "W3-2"
   :entry "SIGTERM" :state "running-process" :outcome "process exits and recovers state"
   :observe (:external_state) :scenario "lifecycle/sigterm-recovery")
  (:id "r6:signal:sighup" :commands () :rule :r6 :lane "W3-2"
   :entry "SIGHUP" :state "running-process" :outcome "process exits and recovers state"
   :observe (:external_state) :scenario "lifecycle/sighup-recovery")
  (:id "r6:signal:sigtstp-cont" :commands () :rule :r6 :lane "W3-2"
   :entry "SIGTSTP then SIGCONT" :state "running-process"
   :outcome "terminal suspends and resumes"
   :observe (:external_state)
   :scenario "lifecycle/sigtstp-sigcont-suspend-resume")
)
