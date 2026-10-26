((:id "r1:kill-workspace:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22t%22%2C%22modifiers%22%3A%5B%5D%7D%2C%7B%22key%22%3A%22k%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
 :commands ("kill-workspace")
 :rule :r1
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"t\",\"modifiers\":[]},{\"key\":\"k\",\"modifiers\":[]}]}"
 :state "default"
 :outcome "command runs from its key sequence"
 :observe (:screen_text)
 :scenario "command-path/r1/kill-workspace/key")

(:id "r1:kill-workspace:mx"
 :commands ("kill-workspace")
 :rule :r1
 :lane "W3-10"
 :entry "mx"
 :state "default"
 :outcome "command runs from M-x"
 :observe (:screen_text)
 :scenario "command-path/r1/kill-workspace/mx")

(:id "r1:new-workspace:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22t%22%2C%22modifiers%22%3A%5B%5D%7D%2C%7B%22key%22%3A%222%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
 :commands ("new-workspace")
 :rule :r1
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"t\",\"modifiers\":[]},{\"key\":\"2\",\"modifiers\":[]}]}"
 :state "default"
 :outcome "command runs from its key sequence"
 :observe (:screen_text)
 :scenario "command-path/r1/new-workspace/key")

(:id "r1:new-workspace:mx"
 :commands ("new-workspace")
 :rule :r1
 :lane "W3-10"
 :entry "mx"
 :state "default"
 :outcome "command runs from M-x"
 :observe (:screen_text)
 :scenario "command-path/r1/new-workspace/mx")

(:id "r1:next-workspace:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22t%22%2C%22modifiers%22%3A%5B%5D%7D%2C%7B%22key%22%3A%22n%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
 :commands ("next-workspace")
 :rule :r1
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"t\",\"modifiers\":[]},{\"key\":\"n\",\"modifiers\":[]}]}"
 :state "default"
 :outcome "command runs from its key sequence"
 :observe (:screen_text)
 :scenario "command-path/r1/next-workspace/key")

(:id "r1:next-workspace:mx"
 :commands ("next-workspace")
 :rule :r1
 :lane "W3-10"
 :entry "mx"
 :state "default"
 :outcome "command runs from M-x"
 :observe (:screen_text)
 :scenario "command-path/r1/next-workspace/mx")

(:id "r1:previous-workspace:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22t%22%2C%22modifiers%22%3A%5B%5D%7D%2C%7B%22key%22%3A%22p%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
 :commands ("previous-workspace")
 :rule :r1
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"t\",\"modifiers\":[]},{\"key\":\"p\",\"modifiers\":[]}]}"
 :state "default"
 :outcome "command runs from its key sequence"
 :observe (:screen_text)
 :scenario "command-path/r1/previous-workspace/key")

(:id "r1:previous-workspace:mx"
 :commands ("previous-workspace")
 :rule :r1
 :lane "W3-10"
 :entry "mx"
 :state "default"
 :outcome "command runs from M-x"
 :observe (:screen_text)
 :scenario "command-path/r1/previous-workspace/mx")

(:id "r1:switch-workspace:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22t%22%2C%22modifiers%22%3A%5B%5D%7D%2C%7B%22key%22%3A%22o%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
 :commands ("switch-workspace")
 :rule :r1
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"t\",\"modifiers\":[]},{\"key\":\"o\",\"modifiers\":[]}]}"
 :state "default"
 :outcome "command runs from its key sequence"
 :observe (:screen_text)
 :scenario "command-path/r1/switch-workspace/key")

(:id "r1:switch-workspace:mx"
 :commands ("switch-workspace")
 :rule :r1
 :lane "W3-10"
 :entry "mx"
 :state "default"
 :outcome "command runs from M-x"
 :observe (:screen_text)
 :scenario "command-path/r1/switch-workspace/mx")
(:id "r2:switch-workspace:prompt-1:completion:accept"
  :commands ("switch-workspace")
  :rule :r2
  :lane "W3-10"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"t\",\"modifiers\":[]},{\"key\":\"o\",\"modifiers\":[]}]};prompt:1:completion"
  :state "prompt:completion"
  :outcome "accept"
  :observe (:screen_text)
  :scenario "command-path/r2/switch-workspace/completion/accept")
(:id "r2:switch-workspace:prompt-1:completion:cancel"
  :commands ("switch-workspace")
  :rule :r2
  :lane "W3-10"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"t\",\"modifiers\":[]},{\"key\":\"o\",\"modifiers\":[]}]};prompt:1:completion"
  :state "prompt:completion"
  :outcome "cancel"
  :observe (:screen_text)
  :scenario "command-path/r2/switch-workspace/completion/cancel")
(:id "r2:switch-workspace:prompt-1:completion:empty"
  :commands ("switch-workspace")
  :rule :r2
  :lane "W3-10"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"t\",\"modifiers\":[]},{\"key\":\"o\",\"modifiers\":[]}]};prompt:1:completion"
  :state "prompt:completion"
  :outcome "empty"
  :observe (:screen_text)
  :scenario "command-path/r2/switch-workspace/completion/empty")
(:id "r2:switch-workspace:prompt-1:completion:invalid"
  :commands ("switch-workspace")
  :rule :r2
  :lane "W3-10"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"t\",\"modifiers\":[]},{\"key\":\"o\",\"modifiers\":[]}]};prompt:1:completion"
  :state "prompt:completion"
  :outcome "invalid"
  :observe (:screen_text)
  :scenario "command-path/r2/switch-workspace/completion/invalid")
(
 :id "r2:switch-workspace:prompt-1:completion:tab"
 :commands ("switch-workspace")
 :rule :r2
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"t\",\"modifiers\":[]},{\"key\":\"o\",\"modifiers\":[]}]};prompt:1:completion"
 :state "prompt:completion"
 :outcome "tab"
 :observe (:screen_text)
 :scenario "command-path/r2/switch-workspace/completion/tab"
)
(:id "r2:switch-workspace:prompt-1:completion:history" :commands ("switch-workspace") :rule :r2 :lane "W3-10" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"t\",\"modifiers\":[]},{\"key\":\"o\",\"modifiers\":[]}]};prompt:1:completion" :state "prompt:completion" :outcome "history" :observe (:screen_text) :scenario "command-path/r2/switch-workspace/completion/history")
)
