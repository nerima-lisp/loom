((:id "r1:newline:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22enter%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands ("newline")
  :rule :r1
  :lane "W3-4"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"enter\",\"modifiers\":[]}]}"
  :state "default"
  :outcome "command runs from its key sequence"
  :observe (:screen_text)
  :scenario "command/cr-ret-unknown-escape-mouse-survival")
 (:id "r1:forward-char:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22right%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands ("forward-char")
  :rule :r1
  :lane "W3-4"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"right\",\"modifiers\":[]}]}"
  :state "default"
  :outcome "command runs from its key sequence"
  :observe (:cursor)
  :scenario "movement/terminal-navigation-arrows")
 (:id "r1:backward-char:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22left%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands ("backward-char")
  :rule :r1
  :lane "W3-4"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"left\",\"modifiers\":[]}]}"
  :state "default"
  :outcome "command runs from its key sequence"
  :observe (:cursor)
  :scenario "movement/terminal-navigation-arrows")
 (:id "r1:next-line:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22down%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands ("next-line")
  :rule :r1
  :lane "W3-4"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"down\",\"modifiers\":[]}]}"
  :state "default"
  :outcome "command runs from its key sequence"
  :observe (:cursor)
  :scenario "movement/terminal-navigation-arrows")
 (:id "r1:previous-line:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22up%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands ("previous-line")
  :rule :r1
  :lane "W3-4"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"up\",\"modifiers\":[]}]}"
  :state "default"
  :outcome "command runs from its key sequence"
  :observe (:cursor)
  :scenario "movement/terminal-navigation-arrows")
 (:id "r1:move-beginning-of-line:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22home%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands ("move-beginning-of-line")
  :rule :r1
  :lane "W3-4"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"home\",\"modifiers\":[]}]}"
  :state "default"
  :outcome "command runs from its key sequence"
  :observe (:cursor)
  :scenario "movement/terminal-navigation-home-end")
 (:id "r1:move-end-of-line:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22end%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands ("move-end-of-line")
  :rule :r1
  :lane "W3-4"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"end\",\"modifiers\":[]}]}"
  :state "default"
  :outcome "command runs from its key sequence"
  :observe (:cursor)
  :scenario "movement/terminal-navigation-home-end")
 (:id "r1:delete-char:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22delete%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands ("delete-char")
  :rule :r1
  :lane "W3-4"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"delete\",\"modifiers\":[]}]}"
  :state "default"
  :outcome "command runs from its key sequence"
  :observe (:screen_text)
  :scenario "movement/terminal-navigation-delete")
 (:id "r1:undo:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22u%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands ("undo")
  :rule :r1
  :lane "W3-4"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"u\",\"modifiers\":[]}]}"
  :state "default"
  :outcome "command runs from its key sequence"
  :observe (:screen_text)
  :scenario "editing/undo-one-group"))
