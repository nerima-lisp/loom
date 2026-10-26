((:id "r1:save-buffer:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22s%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D"
  :commands (:save-buffer)
  :rule :r1
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"s\",\"modifiers\":[\"control\"]}]}"
  :state "default"
  :outcome "command runs from its key sequence"
  :observe (:file_bytes)
  :scenario "file and buffer commands"
  :lane "W3-3")
 (:id "r1:find-file:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22f%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D"
  :commands (:find-file :switch-to-buffer :save-buffer :save-buffers-kill-terminal)
  :rule :r1
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"f\",\"modifiers\":[\"control\"]}]}"
  :state "same.txt in left/ edited; same.txt exists in right/"
  :outcome "reopening focuses the left buffer and right file is named same.txt<right>"
  :observe (:screen_text :buffer_name :buffer_path :file_bytes)
  :scenario "find-file buffer reuse and names"
  :lane "W3-3"))
