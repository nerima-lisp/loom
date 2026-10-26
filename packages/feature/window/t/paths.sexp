((:id "r1:delete-other-windows:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%221%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
 :commands ("delete-other-windows")
 :rule :r1
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"1\",\"modifiers\":[]}]}"
 :state "default"
 :outcome "command runs from its key sequence"
 :observe (:screen_text)
 :scenario "command-path/r1/delete-other-windows/key")

(:id "r1:delete-other-windows:mx"
 :commands ("delete-other-windows")
 :rule :r1
 :lane "W3-10"
 :entry "mx"
 :state "default"
 :outcome "command runs from M-x"
 :observe (:screen_text)
 :scenario "command-path/r1/delete-other-windows/mx")

(:id "r1:delete-window:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%220%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
 :commands ("delete-window")
 :rule :r1
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"0\",\"modifiers\":[]}]}"
 :state "default"
 :outcome "command runs from its key sequence"
 :observe (:screen_text)
 :scenario "command-path/r1/delete-window/key")

(:id "r1:delete-window:mx"
 :commands ("delete-window")
 :rule :r1
 :lane "W3-10"
 :entry "mx"
 :state "default"
 :outcome "command runs from M-x"
 :observe (:screen_text)
 :scenario "command-path/r1/delete-window/mx")

(:id "r1:other-window:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22o%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
 :commands ("other-window")
 :rule :r1
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"o\",\"modifiers\":[]}]}"
 :state "default"
 :outcome "command runs from its key sequence"
 :observe (:screen_text)
 :scenario "command-path/r1/other-window/key")

(:id "r1:other-window:mx"
 :commands ("other-window")
 :rule :r1
 :lane "W3-10"
 :entry "mx"
 :state "default"
 :outcome "command runs from M-x"
 :observe (:screen_text)
 :scenario "command-path/r1/other-window/mx")

(:id "r1:scroll-down-command:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22v%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D"
 :commands ("scroll-down-command")
 :rule :r1
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"v\",\"modifiers\":[\"alt\"]}]}"
 :state "default"
 :outcome "command runs from its key sequence"
 :observe (:screen_text)
 :scenario "command-path/r1/scroll-down-command/key")

(:id "r1:scroll-down-command:mx"
 :commands ("scroll-down-command")
 :rule :r1
 :lane "W3-10"
 :entry "mx"
 :state "default"
 :outcome "command runs from M-x"
 :observe (:screen_text)
 :scenario "command-path/r1/scroll-down-command/mx")

(:id "r1:scroll-up-command:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22v%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D"
 :commands ("scroll-up-command")
 :rule :r1
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"v\",\"modifiers\":[\"control\"]}]}"
 :state "default"
 :outcome "command runs from its key sequence"
 :observe (:screen_text)
 :scenario "command-path/r1/scroll-up-command/key")

(:id "r1:scroll-up-command:mx"
 :commands ("scroll-up-command")
 :rule :r1
 :lane "W3-10"
 :entry "mx"
 :state "default"
 :outcome "command runs from M-x"
 :observe (:screen_text)
 :scenario "command-path/r1/scroll-up-command/mx")

(:id "r1:split-window-below:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%222%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
 :commands ("split-window-below")
 :rule :r1
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"2\",\"modifiers\":[]}]}"
 :state "default"
 :outcome "command runs from its key sequence"
 :observe (:screen_text)
 :scenario "command-path/r1/split-window-below/key")

(:id "r1:split-window-below:mx"
 :commands ("split-window-below")
 :rule :r1
 :lane "W3-10"
 :entry "mx"
 :state "default"
 :outcome "command runs from M-x"
 :observe (:screen_text)
 :scenario "command-path/r1/split-window-below/mx")

(:id "r1:split-window-right:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%223%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
 :commands ("split-window-right")
 :rule :r1
 :lane "W3-10"
 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"3\",\"modifiers\":[]}]}"
 :state "default"
 :outcome "command runs from its key sequence"
 :observe (:screen_text)
 :scenario "command-path/r1/split-window-right/key")

(:id "r1:split-window-right:mx"
 :commands ("split-window-right")
 :rule :r1
 :lane "W3-10"
 :entry "mx"
 :state "default"
 :outcome "command runs from M-x"
 :observe (:screen_text)
 :scenario "command-path/r1/split-window-right/mx"))
