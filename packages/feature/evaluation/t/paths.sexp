(
 (:id "r1:eval-last-sexp:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22e%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D"
  :commands ("eval-last-sexp")
  :rule :r1
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"e\",\"modifiers\":[\"control\"]}]}"
  :state "Common Lisp buffer at point before the first expression"
  :outcome "C-x C-e reaches eval-last-sexp and reports no preceding expression without changing the file bytes or cursor"
  :observe (:screen_text :cursor :file_bytes)
  :scenario "evaluation/eval-last-sexp")
 (:id "r1:eval-last-sexp:mx"
  :commands ("eval-last-sexp")
  :rule :r1
  :lane "W3-7b"
  :entry "mx"
  :state "Common Lisp buffer at point before the first expression"
  :outcome "M-x eval-last-sexp reports no preceding expression without changing the file bytes or cursor"
  :observe (:screen_text :cursor :file_bytes)
  :scenario "evaluation/eval-last-sexp-mx")
 (:id "r1:eval-buffer:mx"
  :commands ("eval-buffer")
  :rule :r1
  :lane "W3-7b"
  :entry "mx"
  :state "Common Lisp buffer containing (+ 1 2)"
  :outcome "M-x eval-buffer silently evaluates the source and preserves its bytes"
  :observe (:screen_text :file_bytes)
  :scenario "evaluation/eval-buffer-mx")
 (:id "r1:eval-expression:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22%3A%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D"
  :commands ("eval-expression")
  :rule :r1
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\":\",\"modifiers\":[\"alt\"]}]}"
  :state "default"
  :outcome "command runs from its key sequence"
  :observe (:screen_text)
  :scenario "command-path/r1/eval-expression/key")
 (:id "r1:eval-expression:mx"
  :commands ("eval-expression")
  :rule :r1
  :lane "W3-7b"
  :entry "mx"
  :state "default"
  :outcome "command runs from M-x"
  :observe (:screen_text)
  :scenario "command-path/r1/eval-expression/mx")
 (:id "r2:eval-expression:prompt-1:free-string:accept"
  :commands ("eval-expression")
  :rule :r2
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\":\",\"modifiers\":[\"alt\"]}]};prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "accept"
  :observe (:screen_text)
  :scenario "command-path/r2/eval-expression/prompt-1/free-string/accept")
 (:id "r2:eval-expression:prompt-1:free-string:cancel"
  :commands ("eval-expression")
  :rule :r2
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\":\",\"modifiers\":[\"alt\"]}]};prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "cancel"
  :observe (:screen_text)
  :scenario "command-path/r2/eval-expression/prompt-1/free-string/cancel")
 (:id "r2:eval-expression:prompt-1:free-string:empty"
  :commands ("eval-expression")
  :rule :r2
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\":\",\"modifiers\":[\"alt\"]}]};prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "empty"
  :observe (:screen_text)
  :scenario "command-path/r2/eval-expression/prompt-1/free-string/empty")
 (:id "r2:eval-expression:prompt-1:free-string:tab"
  :commands ("eval-expression")
  :rule :r2
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\":\",\"modifiers\":[\"alt\"]}]};prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "tab"
  :observe (:screen_text)
  :scenario "command-path/r2/eval-expression/prompt-1/free-string/tab")
 (:id "r2:eval-expression:prompt-1:free-string:history"
  :commands ("eval-expression")
  :rule :r2
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\":\",\"modifiers\":[\"alt\"]}]};prompt:1:free-string"
  :state "prompt:free-string"
  :outcome "history"
  :observe (:screen_text)
  :scenario "command-path/r2/eval-expression/prompt-1/free-string/history")
 (:id "r3:eval-expression:effect"
  :commands ("eval-expression")
  :rule :r3
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\":\",\"modifiers\":[\"alt\"]}]}"
  :state "editable-buffer"
  :outcome "buffer changes"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-expression/effect")
 (:id "r3:eval-expression:undo"
  :commands ("eval-expression")
  :rule :r3
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\":\",\"modifiers\":[\"alt\"]}]}"
  :state "after-one-change"
  :outcome "original bytes restored"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-expression/undo")
 (:id "r3:eval-expression:read-only"
  :commands ("eval-expression")
  :rule :r3
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\":\",\"modifiers\":[\"alt\"]}]}"
  :state "read-only-buffer"
  :outcome "rejected without byte changes"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-expression/read-only")
 (:id "r3:eval-expression:narrow"
  :commands ("eval-expression")
  :rule :r3
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\":\",\"modifiers\":[\"alt\"]}]}"
  :state "narrowed-buffer"
  :outcome "outside range remains unchanged"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-expression/narrow")
 (:id "r3:eval-expression:split-window"
  :commands ("eval-expression")
  :rule :r3
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\":\",\"modifiers\":[\"alt\"]}]}"
  :state "split-window"
  :outcome "both views reflect the change"
  :observe (:screen_text)
  :scenario "command-path/r3/eval-expression/split-window")
 (:id "r3:eval-expression:macro-replay"
  :commands ("eval-expression")
  :rule :r3
  :lane "W3-7b"
  :entry "macro"
  :state "macro-recording"
  :outcome "replay has the same effect"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-expression/macro-replay")
 (:id "r3:eval-expression:prefix-u4"
  :commands ("eval-expression")
  :rule :r3
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\":\",\"modifiers\":[\"alt\"]}]}"
  :state "prefix-C-u-4"
  :outcome "specified prefix behavior is observed"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-expression/prefix-u4")
 (:id "r3:eval-last-sexp:effect"
  :commands ("eval-last-sexp")
  :rule :r3
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"e\",\"modifiers\":[\"control\"]}]}"
  :state "editable-buffer"
  :outcome "buffer changes"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-last-sexp/effect")
 (:id "r3:eval-last-sexp:undo"
  :commands ("eval-last-sexp")
  :rule :r3
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"e\",\"modifiers\":[\"control\"]}]}"
  :state "after-one-change"
  :outcome "original bytes restored"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-last-sexp/undo")
 (:id "r3:eval-last-sexp:read-only"
  :commands ("eval-last-sexp")
  :rule :r3
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"e\",\"modifiers\":[\"control\"]}]}"
  :state "read-only-buffer"
  :outcome "rejected without byte changes"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-last-sexp/read-only")
 (:id "r3:eval-last-sexp:narrow"
  :commands ("eval-last-sexp")
  :rule :r3
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"e\",\"modifiers\":[\"control\"]}]}"
  :state "narrowed-buffer"
  :outcome "outside range remains unchanged"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-last-sexp/narrow")
 (:id "r3:eval-last-sexp:split-window"
  :commands ("eval-last-sexp")
  :rule :r3
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"e\",\"modifiers\":[\"control\"]}]}"
  :state "split-window"
  :outcome "both views reflect the change"
  :observe (:screen_text)
  :scenario "command-path/r3/eval-last-sexp/split-window")
 (:id "r3:eval-last-sexp:macro-replay"
  :commands ("eval-last-sexp")
  :rule :r3
  :lane "W3-7b"
  :entry "macro"
  :state "macro-recording"
  :outcome "replay has the same effect"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-last-sexp/macro-replay")
 (:id "r3:eval-last-sexp:prefix-u4"
  :commands ("eval-last-sexp")
  :rule :r3
  :lane "W3-7b"
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"e\",\"modifiers\":[\"control\"]}]}"
  :state "prefix-C-u-4"
  :outcome "specified prefix behavior is observed"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-last-sexp/prefix-u4")
 (:id "r3:eval-buffer:effect"
  :commands ("eval-buffer")
  :rule :r3
  :lane "W3-7b"
  :entry "mx"
  :state "editable-buffer"
  :outcome "buffer changes"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-buffer/effect")
 (:id "r3:eval-buffer:undo"
  :commands ("eval-buffer")
  :rule :r3
  :lane "W3-7b"
  :entry "mx"
  :state "after-one-change"
  :outcome "original bytes restored"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-buffer/undo")
 (:id "r3:eval-buffer:read-only"
  :commands ("eval-buffer")
  :rule :r3
  :lane "W3-7b"
  :entry "mx"
  :state "read-only-buffer"
  :outcome "rejected without byte changes"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-buffer/read-only")
 (:id "r3:eval-buffer:narrow"
  :commands ("eval-buffer")
  :rule :r3
  :lane "W3-7b"
  :entry "mx"
  :state "narrowed-buffer"
  :outcome "outside range remains unchanged"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-buffer/narrow")
 (:id "r3:eval-buffer:split-window"
  :commands ("eval-buffer")
  :rule :r3
  :lane "W3-7b"
  :entry "mx"
  :state "split-window"
  :outcome "both views reflect the change"
  :observe (:screen_text)
  :scenario "command-path/r3/eval-buffer/split-window")
 (:id "r3:eval-buffer:macro-replay"
  :commands ("eval-buffer")
  :rule :r3
  :lane "W3-7b"
  :entry "macro"
  :state "macro-recording"
  :outcome "replay has the same effect"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-buffer/macro-replay")
 (:id "r3:eval-buffer:prefix-u4"
  :commands ("eval-buffer")
  :rule :r3
  :lane "W3-7b"
  :entry "mx"
  :state "prefix-C-u-4"
  :outcome "specified prefix behavior is observed"
  :observe (:file_bytes)
  :scenario "command-path/r3/eval-buffer/prefix-u4")
)
