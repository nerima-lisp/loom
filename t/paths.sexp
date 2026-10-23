((:id "r1:save-buffer:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22s%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D"
  :commands (:save-buffer)
  :rule :r1
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"s\",\"modifiers\":[\"control\"]}]}"
  :state "default"
  :outcome "command runs from its key sequence"
  :observe (:screen_text)
  :scenario "file and buffer commands"
  :lane "W3-3"))
