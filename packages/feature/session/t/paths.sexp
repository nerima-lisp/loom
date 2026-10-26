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
(:id "r1:load-session:mx"
 :commands ("load-session")
 :rule :r1
 :lane "W3-10"
 :entry "mx"
 :state "default"
 :outcome "command runs from M-x"
 :observe (:screen_text)
 :scenario "command-path/r1/load-session/mx")
(:id "r1:save-session:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22r%22%2C%22modifiers%22%3A%5B%5D%7D%2C%7B%22key%22%3A%22S%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
 :commands ("save-session")
 :rule :r1
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"r\",\"modifiers\":[]},{\"key\":\"S\",\"modifiers\":[]}]}"
 :state "default"
 :outcome "command runs from its key sequence"
 :observe (:screen_text)
 :scenario "command-path/r1/save-session/key")
(:id "r1:save-session:mx"
 :commands ("save-session")
 :rule :r1
 :lane "W3-10"
 :entry "mx"
 :state "default"
 :outcome "command runs from M-x"
 :observe (:screen_text)
 :scenario "command-path/r1/save-session/mx")
(
 :id "r2:load-session:prompt-1:free-string:accept"
 :commands ("load-session")
 :rule :r2
 :lane "W3-10"
 :entry "mx;prompt:1:free-string"
 :state "prompt:free-string"
 :outcome "accept"
 :observe (:screen_text)
 :scenario "command-path/r2/load-session/free-string/accept"
)
(
 :id "r2:load-session:prompt-1:free-string:cancel"
 :commands ("load-session")
 :rule :r2
 :lane "W3-10"
 :entry "mx;prompt:1:free-string"
 :state "prompt:free-string"
 :outcome "cancel"
 :observe (:screen_text)
 :scenario "command-path/r2/load-session/free-string/cancel"
)
(
 :id "r2:load-session:prompt-1:free-string:empty"
 :commands ("load-session")
 :rule :r2
 :lane "W3-10"
 :entry "mx;prompt:1:free-string"
 :state "prompt:free-string"
 :outcome "empty"
 :observe (:screen_text)
 :scenario "command-path/r2/load-session/free-string/empty"
)
(
 :id "r2:load-session:prompt-1:free-string:tab"
 :commands ("load-session")
 :rule :r2
 :lane "W3-10"
 :entry "mx;prompt:1:free-string"
 :state "prompt:free-string"
 :outcome "tab"
 :observe (:screen_text)
 :scenario "command-path/r2/load-session/free-string/tab"
)
(
 :id "r2:save-session:prompt-1:free-string:accept"
 :commands ("save-session")
 :rule :r2
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"r\",\"modifiers\":[]},{\"key\":\"S\",\"modifiers\":[]}]};prompt:1:free-string"
 :state "prompt:free-string"
 :outcome "accept"
 :observe (:screen_text)
 :scenario "command-path/r2/save-session/free-string/accept"
)
(
 :id "r2:save-session:prompt-1:free-string:cancel"
 :commands ("save-session")
 :rule :r2
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"r\",\"modifiers\":[]},{\"key\":\"S\",\"modifiers\":[]}]};prompt:1:free-string"
 :state "prompt:free-string"
 :outcome "cancel"
 :observe (:screen_text)
 :scenario "command-path/r2/save-session/free-string/cancel"
)
(
 :id "r2:save-session:prompt-1:free-string:empty"
 :commands ("save-session")
 :rule :r2
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"r\",\"modifiers\":[]},{\"key\":\"S\",\"modifiers\":[]}]};prompt:1:free-string"
 :state "prompt:free-string"
 :outcome "empty"
 :observe (:screen_text)
 :scenario "command-path/r2/save-session/free-string/empty"
)
(
 :id "r2:save-session:prompt-1:free-string:tab"
 :commands ("save-session")
 :rule :r2
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"r\",\"modifiers\":[]},{\"key\":\"S\",\"modifiers\":[]}]};prompt:1:free-string"
 :state "prompt:free-string"
 :outcome "tab"
 :observe (:screen_text)
 :scenario "command-path/r2/save-session/free-string/tab"
)
(:id "r2:load-session:prompt-1:free-string:history" :commands ("load-session") :rule :r2 :lane "W3-10" :entry "mx;prompt:1:free-string" :state "prompt:free-string" :outcome "history" :observe (:screen_text) :scenario "command-path/r2/load-session/free-string/history")
(:id "r2:save-session:prompt-1:free-string:history" :commands ("save-session") :rule :r2 :lane "W3-10" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"r\",\"modifiers\":[]},{\"key\":\"S\",\"modifiers\":[]}]};prompt:1:free-string" :state "prompt:free-string" :outcome "history" :observe (:screen_text) :scenario "command-path/r2/save-session/free-string/history")
