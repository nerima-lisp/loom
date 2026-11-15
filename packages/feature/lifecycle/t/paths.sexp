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
  (:id "r1:recover-file:mx" :commands ("recover-file")
   :rule :r1 :lane "W3-2" :entry "mx"
   :state "default" :outcome "command runs from M-x"
   :observe (:screen_text)
   :scenario "command-path/r1/recover-file/mx")
  (:id "r1:list-recoverable-files:mx" :commands ("list-recoverable-files")
   :rule :r1 :lane "W3-2" :entry "mx"
   :state "default" :outcome "command runs from M-x"
   :observe (:screen_text)
   :scenario "command-path/r1/list-recoverable-files/mx")
  (:id "r2:recover-file:prompt-1:char:accept" :commands ("recover-file")
   :rule :r2 :lane "W3-2" :entry "mx;prompt:1:char"
   :state "prompt:char" :outcome "accept"
   :observe (:screen_text)
   :scenario "command-path/r2/recover-file/prompt-1/accept")
  (:id "r2:recover-file:prompt-1:char:cancel" :commands ("recover-file")
   :rule :r2 :lane "W3-2" :entry "mx;prompt:1:char"
   :state "prompt:char" :outcome "cancel"
   :observe (:screen_text)
   :scenario "command-path/r2/recover-file/prompt-1/cancel")
  (:id "r2:recover-file:prompt-1:char:invalid" :commands ("recover-file")
   :rule :r2 :lane "W3-2" :entry "mx;prompt:1:char"
   :state "prompt:char" :outcome "invalid"
   :observe (:screen_text)
   :scenario "command-path/r2/recover-file/prompt-1/invalid")
  (:id "r3:recover-file:effect" :commands ("recover-file")
   :rule :r3 :lane "W3-2" :entry "mx"
   :state "editable-buffer" :outcome "buffer changes"
   :observe (:file_bytes)
   :scenario "command-path/r3/recover-file/effect")
  (:id "r3:recover-file:undo" :commands ("recover-file")
   :rule :r3 :lane "W3-2" :entry "mx"
   :state "after-one-change" :outcome "original bytes restored"
   :observe (:file_bytes)
   :scenario "command-path/r3/recover-file/undo")
  (:id "r3:recover-file:read-only" :commands ("recover-file")
   :rule :r3 :lane "W3-2" :entry "mx"
   :state "read-only-buffer" :outcome "rejected without byte changes"
   :observe (:file_bytes)
   :scenario "command-path/r3/recover-file/read-only")
  (:id "r3:recover-file:narrow" :commands ("recover-file")
   :rule :r3 :lane "W3-2" :entry "mx"
   :state "narrowed-buffer" :outcome "outside range remains unchanged"
   :observe (:file_bytes)
   :scenario "command-path/r3/recover-file/narrow")
  (:id "r3:recover-file:split-window" :commands ("recover-file")
   :rule :r3 :lane "W3-2" :entry "mx"
   :state "split-window" :outcome "both views reflect the change"
   :observe (:screen_text)
   :scenario "command-path/r3/recover-file/split-window")
  (:id "r3:recover-file:macro-replay" :commands ("recover-file")
   :rule :r3 :lane "W3-2" :entry "macro"
   :state "macro-recording" :outcome "replay has the same effect"
   :observe (:file_bytes)
   :scenario "command-path/r3/recover-file/macro-replay")
  (:id "r3:recover-file:prefix-u4" :commands ("recover-file")
   :rule :r3 :lane "W3-2" :entry "mx"
   :state "prefix-C-u-4" :outcome "specified prefix behavior is observed"
   :observe (:file_bytes)
   :scenario "command-path/r3/recover-file/prefix-u4")
  (:id "r6:recovery:auto-save-kill9" :commands ()
   :rule :r6 :lane "W3-2" :entry "SIGKILL after auto-save, then reopen"
   :state "auto-save sidecar newer than its file" :outcome "notice appears and r restores the sidecar text"
   :observe (:screen_text :file_bytes)
   :scenario "lifecycle/recovery-auto-save-kill9")
  (:id "r6:recovery:sigterm-meta" :commands ()
   :rule :r6 :lane "W3-2" :entry "SIGTERM, then reopen"
   :state "modified buffer at SIGTERM" :outcome "body and metadata are written and reopening shows the notice"
   :observe (:screen_text :external_state)
   :scenario "lifecycle/recovery-sigterm-meta")
  (:id "r6:recovery:sigterm-meta-watchdog" :commands ()
   :rule :r6 :lane "W3-2" :entry "SIGTERM during a stuck evaluation"
   :state "modified buffer while an evaluation cannot reach its boundary" :outcome "the watchdog thread writes the body and metadata and exits 143"
   :observe (:external_state)
   :scenario "lifecycle/recovery-sigterm-meta-watchdog")
  (:id "r6:recovery:older-candidate" :commands ()
   :rule :r6 :lane "W3-2" :entry "open file"
   :state "sidecar older than its file" :outcome "no notice and recover-file reports no unsaved work"
   :observe (:screen_text)
   :scenario "lifecycle/recovery-older-candidate")
  (:id "r6:recovery:same-content" :commands ()
   :rule :r6 :lane "W3-2" :entry "open file"
   :state "newer sidecar and recovery entry holding the file text" :outcome "no notice and recover-file reports no unsaved work"
   :observe (:screen_text)
   :scenario "lifecycle/recovery-same-content")
  (:id "r6:recovery:other-loom" :commands ()
   :rule :r6 :lane "W3-2" :entry "open file held by another loom"
   :state "another loom holds the file lock" :outcome "the other-loom notice names its pid"
   :observe (:screen_text)
   :scenario "lifecycle/recovery-other-loom")
  (:id "r6:recovery:save-deletes" :commands ()
   :rule :r6 :lane "W3-2" :entry "save-buffer"
   :state "sidecar with matching, unrelated, and legacy recovery entries" :outcome "sidecar and matching entry are deleted and the others remain"
   :observe (:external_state :file_bytes)
   :scenario "lifecycle/recovery-save-deletes")
  (:id "r6:recovery:permissions" :commands ()
   :rule :r6 :lane "W3-2" :entry "auto-save, save, new file, then SIGTERM"
   :state "original file mode 0640" :outcome "sidecar and backup keep 0640, new sidecar is 0600, lock and recovery files are 0600 in 0700 directories"
   :observe (:external_state)
   :scenario "lifecycle/recovery-permissions")
  (:id "r6:recovery:backup-collision" :commands ()
   :rule :r6 :lane "W3-2" :entry "save-buffer"
   :state "a backup already uses the first index" :outcome "the existing backup is unchanged and the next index receives the copy"
   :observe (:file_bytes)
   :scenario "lifecycle/recovery-backup-collision")
  (:id "r6:recovery:special-name-writes" :commands ()
   :rule :r6 :lane "W3-2" :entry "auto-save and save-buffer"
   :state "file name containing glob characters and a backslash" :outcome "sidecar, saved bytes, and backup use the literal name"
   :observe (:file_bytes :external_state)
   :scenario "lifecycle/recovery-special-name-writes")
  (:id "r6:recovery:special-name-file-tree" :commands ()
   :rule :r6 :lane "W3-2" :entry "file-tree open"
   :state "file name containing glob characters and a backslash" :outcome "file-tree opens the file"
   :observe (:screen_text)
   :scenario "lifecycle/recovery-special-name-file-tree")
)
