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
  :scenario "editing/undo-one-group")
 (:id "r1:recenter-top-bottom:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22l%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("recenter-top-bottom") :rule :r1 :lane "W3-1" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"l\",\"modifiers\":[\"control\"]}]}" :state "default" :outcome "recenters the point line in the selected window without changing buffer bytes" :observe (:screen_text :file_bytes :cursor) :scenario "movement/recenter-top-bottom")
 (:id "r1:transpose-chars:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22t%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("transpose-chars") :rule :r1 :lane "W3-1" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"t\",\"modifiers\":[\"control\"]}]}" :state "default" :outcome "swaps the characters before and at point" :observe (:file_bytes :cursor) :scenario "editing/transpose-chars")
 (:id "r1:upcase-word:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22u%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D" :commands ("upcase-word") :rule :r1 :lane "W3-1" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"u\",\"modifiers\":[\"alt\"]}]}" :state "default" :outcome "uppercases the following word and advances point" :observe (:file_bytes :cursor) :scenario "editing/upcase-word")
 (:id "r1:downcase-word:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22l%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D" :commands ("downcase-word") :rule :r1 :lane "W3-1" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"l\",\"modifiers\":[\"alt\"]}]}" :state "default" :outcome "lowercases the following word and advances point" :observe (:file_bytes :cursor) :scenario "editing/downcase-word")
 (:id "r1:capitalize-word:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22c%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D" :commands ("capitalize-word") :rule :r1 :lane "W3-1" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"alt\"]}]}" :state "default" :outcome "capitalizes the following word and advances point" :observe (:file_bytes :cursor) :scenario "editing/capitalize-word")
 (:id "r1:fill-paragraph:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22q%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D" :commands ("fill-paragraph") :rule :r1 :lane "W3-1" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"q\",\"modifiers\":[\"alt\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "editing/fill-paragraph")
 (:id "r1:fill-paragraph:mx" :commands ("fill-paragraph") :rule :r1 :lane "W3-1" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "editing/fill-paragraph")
 (:id "r1:delete-indentation:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22%5E%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D" :commands ("delete-indentation") :rule :r1 :lane "W3-1" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"^\",\"modifiers\":[\"alt\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "editing/delete-indentation")
 (:id "r1:delete-indentation:mx" :commands ("delete-indentation") :rule :r1 :lane "W3-1" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "editing/delete-indentation")
 (:id "r1:execute-extended-command:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D" :commands ("execute-extended-command") :rule :r1 :lane "W3-1" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"alt\"]}]}" :state "r1 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r1/execute-extended-command/key")
 (:id "r1:keyboard-quit:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22g%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("keyboard-quit") :rule :r1 :lane "W3-1" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"g\",\"modifiers\":[\"control\"]}]}" :state "r1 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r1/keyboard-quit/key")
 (:id "r1:keyboard-quit:mx" :commands ("execute-extended-command" "keyboard-quit") :rule :r1 :lane "W3-1" :entry "mx" :state "r1 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r1/keyboard-quit/mx")
 (:id "r1:universal-argument:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22u%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("universal-argument") :rule :r1 :lane "W3-1" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"u\",\"modifiers\":[\"control\"]}]}" :state "r1 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r1/universal-argument/key")
 (:id "r1:universal-argument:mx" :commands ("execute-extended-command" "universal-argument") :rule :r1 :lane "W3-1" :entry "mx" :state "r1 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r1/universal-argument/mx")
 (:id "r2:execute-extended-command:prompt-1:completion:accept" :commands ("execute-extended-command" "capitalize-word" "save-buffer") :rule :r2 :lane "W3-1" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"alt\"]}]};prompt:1:completion" :state "r2 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r2/accept")
 (:id "r2:execute-extended-command:prompt-1:completion:cancel" :commands ("execute-extended-command") :rule :r2 :lane "W3-1" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"alt\"]}]};prompt:1:completion" :state "r2 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r2/cancel")
 (:id "r2:execute-extended-command:prompt-1:completion:empty" :commands ("execute-extended-command") :rule :r2 :lane "W3-1" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"alt\"]}]};prompt:1:completion" :state "r2 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r2/empty")
 (:id "r2:execute-extended-command:prompt-1:completion:tab" :commands ("execute-extended-command" "capitalize-word" "save-buffer") :rule :r2 :lane "W3-1" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"alt\"]}]};prompt:1:completion" :state "r2 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r2/tab")
 (:id "r2:execute-extended-command:prompt-1:completion:history" :commands ("execute-extended-command" "forward-char") :rule :r2 :lane "W3-1" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"alt\"]}]};prompt:1:completion" :state "r2 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r2/history")
 (:id "r2:execute-extended-command:prompt-1:completion:invalid" :commands ("execute-extended-command") :rule :r2 :lane "W3-1" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"alt\"]}]};prompt:1:completion" :state "r2 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r2/invalid")
 (:id "r1:capitalize-word:mx" :commands ("execute-extended-command" "capitalize-word" "save-buffer") :rule :r1 :lane "W3-4" :entry "mx" :state "r1 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r1/capitalize-word/mx")
 (:id "r1:downcase-word:mx" :commands ("execute-extended-command" "downcase-word" "save-buffer") :rule :r1 :lane "W3-4" :entry "mx" :state "r1 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r1/downcase-word/mx")
 (:id "r1:upcase-word:mx" :commands ("execute-extended-command" "upcase-word" "save-buffer") :rule :r1 :lane "W3-4" :entry "mx" :state "r1 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r1/upcase-word/mx")
 (:id "r1:transpose-chars:mx" :commands ("execute-extended-command" "forward-char" "transpose-chars" "save-buffer") :rule :r1 :lane "W3-4" :entry "mx" :state "r1 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r1/transpose-chars/mx")
 (:id "r1:recenter-top-bottom:mx" :commands ("execute-extended-command" "next-line" "recenter-top-bottom") :rule :r1 :lane "W3-4" :entry "mx" :state "r1 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r1/recenter-top-bottom/mx")
 (:id "r3:delete-char:effect" :commands ("delete-char" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"d\",\"modifiers\":[\"control\"]}]}" :state "r3 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r3/delete-char/effect")
 (:id "r3:delete-char:undo" :commands ("delete-char" "undo" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"d\",\"modifiers\":[\"control\"]}]}" :state "r3 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r3/delete-char/undo")
 (:id "r3:delete-char:read-only" :commands ("execute-extended-command" "toggle-read-only" "delete-char") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"d\",\"modifiers\":[\"control\"]}]}" :state "r3 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r3/delete-char/read-only")
 (:id "r3:delete-char:macro-replay" :commands ("start-kbd-macro" "delete-char" "end-kbd-macro" "call-last-kbd-macro" "undo" "save-buffer") :rule :r3 :lane "W3-4" :entry "macro" :state "r3 strict scenario" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/r3/delete-char/macro-replay")
)

