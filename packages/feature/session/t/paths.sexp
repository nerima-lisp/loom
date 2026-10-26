(:id "r8:session"
     :commands
     ("save-session" "load-session")
     :rule
     :r8
     :lane
     "W3-10"
     :entry
     "new-process"
     :state
     "saved session saved before process exit"
     :outcome
     "saved session is restored after process restart"
     :observe
     (:screen_text :external_state)
     :scenario
     "session restart restores saved state")

(:id "r8:split-windows"
     :commands
     ("split-window-below" "save-session" "load-session")
     :rule
     :r8
     :lane
     "W3-10"
     :entry
     "new-process"
     :state
     "split windows saved before process exit"
     :outcome
     "split windows is restored after process restart"
     :observe
     (:screen_text :external_state)
     :scenario
     "session restart restores split windows")

(:id "r8:workspace"
     :commands
     ("new-workspace" "switch-workspace" "save-session" "load-session")
     :rule
     :r8
     :lane
     "W3-10"
     :entry
     "new-process"
     :state
     "workspace saved before process exit"
     :outcome
     "workspace is restored after process restart"
     :observe
     (:screen_text :external_state)
     :scenario
     "session restart restores workspace")

(:id "r8:history"
     :commands
     ("execute-extended-command" "save-session" "load-session")
     :rule
     :r8
     :lane
     "W3-10"
     :entry
     "new-process"
     :state
     "command history saved before process exit"
     :outcome
     "command history is restored after process restart"
     :observe
     (:screen_text :external_state)
     :scenario
     "session restart restores command history")
