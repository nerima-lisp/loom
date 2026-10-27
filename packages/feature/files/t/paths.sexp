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
  :lane "W3-3")
 (:id "r1:save-buffer:mx" :commands (:save-buffer) :rule :r1 :entry "mx" :state "BOM, mixed CRLF/LF, and invalid-byte file at point zero" :outcome "M-x save-buffer preserves the BOM, invalid byte, and each original line ending after a leading ASCII insertion" :observe (:screen_text :file_bytes) :scenario "files/file-format-preservation" :lane "W3-3")
 (:id "r1:revert-buffer:mx" :commands (:revert-buffer) :rule :r1 :entry "mx" :state "locally modified file differs from an external replacement" :outcome "M-x revert-buffer confirms discard and displays the exact external file contents" :observe (:screen_text :file_bytes) :scenario "files/external-file-change-revert" :lane "W3-3")
 (:id "r5:save-buffer:shell:success" :commands (:save-buffer) :rule :r5 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"s\",\"modifiers\":[\"control\"]}]}" :state "tool:shell" :outcome "success" :observe (:external_state) :scenario "files/save-buffer-shell-success" :lane "W3-3")
 (:id "r5:save-buffer:shell:missing" :commands (:save-buffer) :rule :r5 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"s\",\"modifiers\":[\"control\"]}]}" :state "tool:shell" :outcome "missing" :observe (:external_state) :scenario "files/save-buffer-shell-missing" :lane "W3-3")
 (:id "r5:save-buffer:shell:nonzero" :commands (:save-buffer) :rule :r5 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"s\",\"modifiers\":[\"control\"]}]}" :state "tool:shell" :outcome "nonzero" :observe (:external_state) :scenario "files/save-buffer-shell-nonzero" :lane "W3-3")
 (:id "r5:save-buffer:shell:interrupted" :commands (:save-buffer) :rule :r5 :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"s\",\"modifiers\":[\"control\"]}]}" :state "tool:shell" :outcome "interrupted" :observe (:external_state) :scenario "files/save-buffer-shell-interrupted" :lane "W3-3"))
