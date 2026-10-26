(
 (:id "r1:file-tree-create-directory:key:%7B%22keymap%22%3A%22file-tree-local%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22c%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22d%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands ("toggle-file-tree" "file-tree-create-directory")
  :rule :r1
  :lane "W3-10"
  :entry "key:{\"keymap\":\"file-tree-local\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"control\"]},{\"key\":\"d\",\"modifiers\":[]}]}"
  :state "r1 strict scenario"
  :outcome "exact screen, body cursor, and file bytes"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "command-path/r1/file-tree-create-directory/key")
 (:id "r1:file-tree-create-directory:mx"
  :commands ("execute-extended-command" "file-tree-create-directory")
  :rule :r1
  :lane "W3-10"
  :entry "mx"
  :state "r1 strict scenario"
  :outcome "exact screen, body cursor, and file bytes"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "command-path/r1/file-tree-create-directory/mx")
 (:id "r1:file-tree-create-file:key:%7B%22keymap%22%3A%22file-tree-local%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22c%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22c%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands ("toggle-file-tree" "file-tree-create-file")
  :rule :r1
  :lane "W3-10"
  :entry "key:{\"keymap\":\"file-tree-local\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"control\"]},{\"key\":\"c\",\"modifiers\":[]}]}"
  :state "r1 strict scenario"
  :outcome "exact screen, body cursor, and file bytes"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "command-path/r1/file-tree-create-file/key")
 (:id "r1:file-tree-create-file:mx"
  :commands ("execute-extended-command" "file-tree-create-file")
  :rule :r1
  :lane "W3-10"
  :entry "mx"
  :state "r1 strict scenario"
  :outcome "exact screen, body cursor, and file bytes"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "command-path/r1/file-tree-create-file/mx")
 (:id "r1:file-tree-delete:mx"
  :commands ("execute-extended-command" "file-tree-delete")
  :rule :r1
  :lane "W3-10"
  :entry "mx"
  :state "r1 strict scenario"
  :outcome "exact screen, body cursor, and file bytes"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "command-path/r1/file-tree-delete/mx")
 (:id "r1:file-tree-open-selected:key:%7B%22keymap%22%3A%22file-tree-local%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22c%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22o%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands ("toggle-file-tree" "file-tree-select-next" "file-tree-open-selected")
  :rule :r1
  :lane "W3-10"
  :entry "key:{\"keymap\":\"file-tree-local\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"control\"]},{\"key\":\"o\",\"modifiers\":[]}]}"
  :state "r1 strict scenario"
  :outcome "exact screen, body cursor, and file bytes"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "command-path/r1/file-tree-open-selected/key")
 (:id "r1:file-tree-open-selected:mx"
  :commands ("toggle-file-tree" "file-tree-select-next" "execute-extended-command" "file-tree-open-selected")
  :rule :r1
  :lane "W3-10"
  :entry "mx"
  :state "r1 strict scenario"
  :outcome "exact screen, body cursor, and file bytes"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "command-path/r1/file-tree-open-selected/mx")
 (:id "r1:file-tree-rename:mx"
  :commands ("execute-extended-command" "file-tree-rename")
  :rule :r1
  :lane "W3-10"
  :entry "mx"
  :state "r1 strict scenario"
  :outcome "exact screen, body cursor, and file bytes"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "command-path/r1/file-tree-rename/mx")
 (:id "r1:file-tree-select-next:key:%7B%22keymap%22%3A%22file-tree-local%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22c%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22n%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands ("toggle-file-tree" "file-tree-select-next")
  :rule :r1
  :lane "W3-10"
  :entry "key:{\"keymap\":\"file-tree-local\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"control\"]},{\"key\":\"n\",\"modifiers\":[]}]}"
  :state "r1 strict scenario"
  :outcome "exact screen, body cursor, and file bytes"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "command-path/r1/file-tree-select-next/key")
 (:id "r1:file-tree-select-next:mx"
  :commands ("toggle-file-tree" "execute-extended-command" "file-tree-select-next")
  :rule :r1
  :lane "W3-10"
  :entry "mx"
  :state "r1 strict scenario"
  :outcome "exact screen, body cursor, and file bytes"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "command-path/r1/file-tree-select-next/mx")
 (:id "r1:file-tree-select-previous:key:%7B%22keymap%22%3A%22file-tree-local%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22c%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22p%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands ("toggle-file-tree" "file-tree-select-previous")
  :rule :r1
  :lane "W3-10"
  :entry "key:{\"keymap\":\"file-tree-local\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"control\"]},{\"key\":\"p\",\"modifiers\":[]}]}"
  :state "r1 strict scenario"
  :outcome "exact screen, body cursor, and file bytes"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "command-path/r1/file-tree-select-previous/key")
 (:id "r1:file-tree-select-previous:mx"
  :commands ("toggle-file-tree" "file-tree-select-next" "execute-extended-command" "file-tree-select-previous")
  :rule :r1
  :lane "W3-10"
  :entry "mx"
  :state "r1 strict scenario"
  :outcome "exact screen, body cursor, and file bytes"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "command-path/r1/file-tree-select-previous/mx")

 (:id "r1:toggle-file-tree:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22d%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands ("toggle-file-tree")
  :rule :r1
  :lane "W3-10"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"d\",\"modifiers\":[]}]}"
  :state "r1 strict scenario"
  :outcome "exact screen, body cursor, and file bytes"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "command-path/r1/toggle-file-tree/key")
 (:id "r1:toggle-file-tree:mx"
  :commands ("execute-extended-command" "toggle-file-tree")
  :rule :r1
  :lane "W3-10"
  :entry "mx"
  :state "r1 strict scenario"
  :outcome "exact screen, body cursor, and file bytes"
  :observe (:screen_text :file_bytes :cursor)
  :scenario "command-path/r1/toggle-file-tree/mx")
 (:id "r2:file-tree-create-file:prompt-1:free-string:accept"
  :commands ("file-tree-create-file")
  :rule :r2
  :lane "W3-10"
  :entry "key:{\"keymap\":\"file-tree-local\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"control\"]},{\"key\":\"c\",\"modifiers\":[]}]};prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "accept"
  :observe (:screen_text)
  :scenario "command-path/r2/file-tree-create-file/free-string/accept")
 (:id "r2:file-tree-create-file:prompt-1:free-string:cancel"
  :commands ("file-tree-create-file")
  :rule :r2
  :lane "W3-10"
  :entry "key:{\"keymap\":\"file-tree-local\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"control\"]},{\"key\":\"c\",\"modifiers\":[]}]};prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "cancel"
  :observe (:screen_text)
  :scenario "command-path/r2/file-tree-create-file/free-string/cancel")
 (:id "r2:file-tree-create-file:prompt-1:free-string:empty"
  :commands ("file-tree-create-file")
  :rule :r2
  :lane "W3-10"
  :entry "key:{\"keymap\":\"file-tree-local\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"control\"]},{\"key\":\"c\",\"modifiers\":[]}]};prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "empty"
  :observe (:screen_text)
  :scenario "command-path/r2/file-tree-create-file/free-string/empty")
 (:id "r2:file-tree-create-file:prompt-1:free-string:tab"
  :commands ("file-tree-create-file")
  :rule :r2
  :lane "W3-10"
  :entry "key:{\"keymap\":\"file-tree-local\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"control\"]},{\"key\":\"c\",\"modifiers\":[]}]};prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "tab"
  :observe (:screen_text)
  :scenario "command-path/r2/file-tree-create-file/free-string/tab")
 (:id "r2:file-tree-create-directory:prompt-1:free-string:accept"
  :commands ("file-tree-create-directory")
  :rule :r2
  :lane "W3-10"
  :entry "key:{\"keymap\":\"file-tree-local\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"control\"]},{\"key\":\"d\",\"modifiers\":[]}]};prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "accept"
  :observe (:screen_text)
  :scenario "command-path/r2/file-tree-create-directory/free-string/accept")
 (:id "r2:file-tree-create-directory:prompt-1:free-string:cancel"
  :commands ("file-tree-create-directory")
  :rule :r2
  :lane "W3-10"
  :entry "key:{\"keymap\":\"file-tree-local\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"control\"]},{\"key\":\"d\",\"modifiers\":[]}]};prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "cancel"
  :observe (:screen_text)
  :scenario "command-path/r2/file-tree-create-directory/free-string/cancel")
 (:id "r2:file-tree-create-directory:prompt-1:free-string:empty"
  :commands ("file-tree-create-directory")
  :rule :r2
  :lane "W3-10"
  :entry "key:{\"keymap\":\"file-tree-local\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"control\"]},{\"key\":\"d\",\"modifiers\":[]}]};prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "empty"
  :observe (:screen_text)
  :scenario "command-path/r2/file-tree-create-directory/free-string/empty")
 (:id "r2:file-tree-create-directory:prompt-1:free-string:tab"
  :commands ("file-tree-create-directory")
  :rule :r2
  :lane "W3-10"
  :entry "key:{\"keymap\":\"file-tree-local\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"control\"]},{\"key\":\"d\",\"modifiers\":[]}]};prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "tab"
  :observe (:screen_text)
  :scenario "command-path/r2/file-tree-create-directory/free-string/tab")
 (:id "r2:file-tree-rename:prompt-1:free-string:accept"
  :commands ("file-tree-rename")
  :rule :r2
  :lane "W3-10"
  :entry "mx;prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "accept"
  :observe (:screen_text)
  :scenario "command-path/r2/file-tree-rename/free-string/accept")
 (:id "r2:file-tree-rename:prompt-1:free-string:cancel"
  :commands ("file-tree-rename")
  :rule :r2
  :lane "W3-10"
  :entry "mx;prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "cancel"
  :observe (:screen_text)
  :scenario "command-path/r2/file-tree-rename/free-string/cancel")
 (:id "r2:file-tree-rename:prompt-1:free-string:empty"
  :commands ("file-tree-rename")
  :rule :r2
  :lane "W3-10"
  :entry "mx;prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "empty"
  :observe (:screen_text)
  :scenario "command-path/r2/file-tree-rename/free-string/empty")
 (:id "r2:file-tree-rename:prompt-1:free-string:tab"
  :commands ("file-tree-rename")
  :rule :r2
  :lane "W3-10"
  :entry "mx;prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "tab"
  :observe (:screen_text)
  :scenario "command-path/r2/file-tree-rename/free-string/tab")
 (:id "r2:file-tree-create-file:prompt-1:free-string:history"
  :commands ("file-tree-create-file")
  :rule :r2
  :lane "W3-10"
  :entry "key:{\"keymap\":\"file-tree-local\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"control\"]},{\"key\":\"c\",\"modifiers\":[]}]};prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "history"
  :observe (:screen_text)
  :scenario "command-path/r2/file-tree-create-file/free-string/history")
 (:id "r2:file-tree-create-directory:prompt-1:free-string:history"
  :commands ("file-tree-create-directory")
  :rule :r2
  :lane "W3-10"
  :entry "key:{\"keymap\":\"file-tree-local\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"control\"]},{\"key\":\"d\",\"modifiers\":[]}]};prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "history"
  :observe (:screen_text)
  :scenario "command-path/r2/file-tree-create-directory/free-string/history")
 (:id "r2:file-tree-rename:prompt-1:free-string:history"
  :commands ("file-tree-rename")
  :rule :r2
  :lane "W3-10"
  :entry "mx;prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "history"
  :observe (:screen_text)
  :scenario "command-path/r2/file-tree-rename/free-string/history")
)
