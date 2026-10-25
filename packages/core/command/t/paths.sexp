((:id "r1:newline:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22enter%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands ("newline")
  :rule :r1
  :lane "W3-4"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"enter\",\"modifiers\":[]}]}"
  :state "default"
  :outcome "command runs from its key sequence"
  :observe (:screen_text)
  :scenario "command/cr-ret-unknown-escape-mouse-survival"))
