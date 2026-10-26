; Insert scenarios type characters through an untraced internal operation; the generator has no insert target commands.
; Resize is a terminal event without a command target. These six IDs remain no-trace until generation supports them.
(
 (:id "r6:text:fullwidth:move"
  :commands ("forward-char")
  :rule "r6"
  :lane "W3-4"
  :entry "move"
  :state "text:fullwidth"
  :outcome "move fullwidth text"
  :observe ("cursor")
  :scenario "r6/text/fullwidth/move")
 (:id "r6:text:fullwidth:insert"
  :commands ()
  :rule "r6"
  :lane "W3-4"
  :entry "insert"
  :state "text:fullwidth"
  :outcome "insert fullwidth text"
  :observe ("file_bytes")
  :scenario "r6/text/fullwidth/insert")
 (:id "r6:text:fullwidth:delete"
  :commands ("delete-char")
  :rule "r6"
  :lane "W3-4"
  :entry "delete"
  :state "text:fullwidth"
  :outcome "delete fullwidth text"
  :observe ("file_bytes")
  :scenario "r6/text/fullwidth/delete")
 (:id "r6:text:fullwidth:undo"
  :commands ("undo")
  :rule "r6"
  :lane "W3-4"
  :entry "undo"
  :state "text:fullwidth"
  :outcome "undo fullwidth text"
  :observe ("file_bytes")
  :scenario "r6/text/fullwidth/undo")
 (:id "r6:text:fullwidth:save"
  :commands ("save-buffer")
  :rule "r6"
  :lane "W3-4"
  :entry "save"
  :state "text:fullwidth"
  :outcome "save fullwidth text"
  :observe ("file_bytes")
  :scenario "r6/text/fullwidth/save")
 (:id "r6:text:combining:move"
  :commands ("forward-char")
  :rule "r6"
  :lane "W3-4"
  :entry "move"
  :state "text:combining"
  :outcome "move combining text"
  :observe ("cursor")
  :scenario "r6/text/combining/move")
 (:id "r6:text:combining:insert"
  :commands ()
  :rule "r6"
  :lane "W3-4"
  :entry "insert"
  :state "text:combining"
  :outcome "insert combining text"
  :observe ("file_bytes")
  :scenario "r6/text/combining/insert")
 (:id "r6:text:combining:delete"
  :commands ("delete-char")
  :rule "r6"
  :lane "W3-4"
  :entry "delete"
  :state "text:combining"
  :outcome "delete combining text"
  :observe ("file_bytes")
  :scenario "r6/text/combining/delete")
 (:id "r6:text:combining:undo"
  :commands ("undo")
  :rule "r6"
  :lane "W3-4"
  :entry "undo"
  :state "text:combining"
  :outcome "undo combining text"
  :observe ("file_bytes")
  :scenario "r6/text/combining/undo")
 (:id "r6:text:combining:save"
  :commands ("save-buffer")
  :rule "r6"
  :lane "W3-4"
  :entry "save"
  :state "text:combining"
  :outcome "save combining text"
  :observe ("file_bytes")
  :scenario "r6/text/combining/save")
 (:id "r6:text:emoji:move"
  :commands ("forward-char")
  :rule "r6"
  :lane "W3-4"
  :entry "move"
  :state "text:emoji"
  :outcome "move emoji text"
  :observe ("cursor")
  :scenario "r6/text/emoji/move")
 (:id "r6:text:emoji:insert"
  :commands ()
  :rule "r6"
  :lane "W3-4"
  :entry "insert"
  :state "text:emoji"
  :outcome "insert emoji text"
  :observe ("file_bytes")
  :scenario "r6/text/emoji/insert")
 (:id "r6:text:emoji:delete"
  :commands ("delete-char")
  :rule "r6"
  :lane "W3-4"
  :entry "delete"
  :state "text:emoji"
  :outcome "delete emoji text"
  :observe ("file_bytes")
  :scenario "r6/text/emoji/delete")
 (:id "r6:text:emoji:undo"
  :commands ("undo")
  :rule "r6"
  :lane "W3-4"
  :entry "undo"
  :state "text:emoji"
  :outcome "undo emoji text"
  :observe ("file_bytes")
  :scenario "r6/text/emoji/undo")
 (:id "r6:text:emoji:save"
  :commands ("save-buffer")
  :rule "r6"
  :lane "W3-4"
  :entry "save"
  :state "text:emoji"
  :outcome "save emoji text"
  :observe ("file_bytes")
  :scenario "r6/text/emoji/save")
 (:id "r6:text:wrap:move"
  :commands ("forward-char")
  :rule "r6"
  :lane "W3-4"
  :entry "move"
  :state "text:wrap"
  :outcome "move wrap text"
  :observe ("cursor")
  :scenario "r6/text/wrap/move")
 (:id "r6:text:wrap:insert"
  :commands ()
  :rule "r6"
  :lane "W3-4"
  :entry "insert"
  :state "text:wrap"
  :outcome "insert wrap text"
  :observe ("file_bytes")
  :scenario "r6/text/wrap/insert")
 (:id "r6:text:wrap:delete"
  :commands ("delete-char")
  :rule "r6"
  :lane "W3-4"
  :entry "delete"
  :state "text:wrap"
  :outcome "delete wrap text"
  :observe ("file_bytes")
  :scenario "r6/text/wrap/delete")
 (:id "r6:text:wrap:undo"
  :commands ("undo")
  :rule "r6"
  :lane "W3-4"
  :entry "undo"
  :state "text:wrap"
  :outcome "undo wrap text"
  :observe ("file_bytes")
  :scenario "r6/text/wrap/undo")
 (:id "r6:text:wrap:save"
  :commands ("save-buffer")
  :rule "r6"
  :lane "W3-4"
  :entry "save"
  :state "text:wrap"
  :outcome "save wrap text"
  :observe ("file_bytes")
  :scenario "r6/text/wrap/save")
 (:id "r6:text:truncate:move"
  :commands ("forward-char")
  :rule "r6"
  :lane "W3-4"
  :entry "move"
  :state "text:truncate"
  :outcome "move truncate text"
  :observe ("cursor")
  :scenario "r6/text/truncate/move")
 (:id "r6:text:truncate:insert"
  :commands ()
  :rule "r6"
  :lane "W3-4"
  :entry "insert"
  :state "text:truncate"
  :outcome "insert truncate text"
  :observe ("file_bytes")
  :scenario "r6/text/truncate/insert")
 (:id "r6:text:truncate:delete"
  :commands ("delete-char")
  :rule "r6"
  :lane "W3-4"
  :entry "delete"
  :state "text:truncate"
  :outcome "delete truncate text"
  :observe ("file_bytes")
  :scenario "r6/text/truncate/delete")
 (:id "r6:text:truncate:undo"
  :commands ("undo")
  :rule "r6"
  :lane "W3-4"
  :entry "undo"
  :state "text:truncate"
  :outcome "undo truncate text"
  :observe ("file_bytes")
  :scenario "r6/text/truncate/undo")
 (:id "r6:text:truncate:save"
  :commands ("save-buffer")
  :rule "r6"
  :lane "W3-4"
  :entry "save"
  :state "text:truncate"
  :outcome "save truncate text"
  :observe ("file_bytes")
  :scenario "r6/text/truncate/save")
 (:id "r6:resize"
  :commands ()
  :rule "r6"
  :lane "W3-4"
  :entry "terminal-resize"
  :state "resized-terminal"
  :outcome "screen redraws"
  :observe ("screen_text" "cursor")
  :scenario "r6/resize")
(:id "r3:capitalize-word:read-only" :commands ("execute-extended-command" "toggle-read-only" "capitalize-word") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"alt\"]}]}" :state "read-only-buffer" :outcome "rejected without byte changes" :observe (:file_bytes) :scenario "command-path/buffer/r3/capitalize-word/read-only")
 (:id "r3:delete-backward-char:effect" :commands ("forward-char" "delete-backward-char" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"backspace\",\"modifiers\":[]}]}" :state "editable-buffer" :outcome "buffer changes" :observe (:file_bytes) :scenario "command-path/buffer/r3/delete-backward-char/effect")
 (:id "r3:delete-backward-char:undo" :commands ("forward-char" "delete-backward-char" "undo" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"backspace\",\"modifiers\":[]}]}" :state "after-one-change" :outcome "original bytes restored" :observe (:file_bytes) :scenario "command-path/buffer/r3/delete-backward-char/undo")
 (:id "r3:delete-backward-char:macro-replay" :commands ("start-kbd-macro" "forward-char" "delete-backward-char" "end-kbd-macro" "undo" "move-beginning-of-line" "call-last-kbd-macro" "save-buffer") :rule :r3 :lane "W3-4" :entry "macro" :state "macro-recording" :outcome "replay has the same effect" :observe (:file_bytes) :scenario "command-path/buffer/r3/delete-backward-char/macro-replay")
 (:id "r3:downcase-word:read-only" :commands ("execute-extended-command" "toggle-read-only" "downcase-word") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"l\",\"modifiers\":[\"alt\"]}]}" :state "read-only-buffer" :outcome "rejected without byte changes" :observe (:file_bytes) :scenario "command-path/buffer/r3/downcase-word/read-only")
 (:id "r3:fill-paragraph:effect" :commands ("fill-paragraph" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"q\",\"modifiers\":[\"alt\"]}]}" :state "editable-buffer" :outcome "buffer changes" :observe (:file_bytes) :scenario "command-path/buffer/r3/fill-paragraph/effect")
 (:id "r3:fill-paragraph:read-only" :commands ("execute-extended-command" "toggle-read-only" "fill-paragraph") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"q\",\"modifiers\":[\"alt\"]}]}" :state "read-only-buffer" :outcome "rejected without byte changes" :observe (:file_bytes) :scenario "command-path/buffer/r3/fill-paragraph/read-only")
 (:id "r3:fill-paragraph:macro-replay" :commands ("start-kbd-macro" "fill-paragraph" "end-kbd-macro" "undo" "beginning-of-buffer" "call-last-kbd-macro" "save-buffer") :rule :r3 :lane "W3-4" :entry "macro" :state "macro-recording" :outcome "replay has the same effect" :observe (:file_bytes) :scenario "command-path/buffer/r3/fill-paragraph/macro-replay")
 (:id "r3:newline:effect" :commands ("forward-char" "execute-extended-command" "newline" "save-buffer") :rule :r3 :lane "W3-4" :entry "mx" :state "editable-buffer" :outcome "buffer changes" :observe (:file_bytes) :scenario "command-path/buffer/r3/newline/effect")
 (:id "r3:open-line:effect" :commands ("forward-char" "open-line" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"o\",\"modifiers\":[\"control\"]}]}" :state "editable-buffer" :outcome "buffer changes" :observe (:file_bytes) :scenario "command-path/buffer/r3/open-line/effect")
 (:id "r3:redo:effect" :commands ("redo" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"_\",\"modifiers\":[\"alt\",\"control\"]}]}" :state "editable-buffer" :outcome "buffer changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/redo/effect")
 (:id "r3:transpose-chars:effect" :commands ("transpose-chars" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"t\",\"modifiers\":[\"control\"]}]}" :state "editable-buffer" :outcome "buffer changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/transpose-chars/effect")
 (:id "r3:transpose-chars:read-only" :commands ("execute-extended-command" "toggle-read-only" "transpose-chars") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"t\",\"modifiers\":[\"control\"]}]}" :state "read-only-buffer" :outcome "rejected without byte changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/transpose-chars/read-only")
 (:id "r3:transpose-chars:macro-replay" :commands ("start-kbd-macro" "transpose-chars" "end-kbd-macro" "undo" "move-beginning-of-line" "forward-char" "call-last-kbd-macro" "save-buffer") :rule :r3 :lane "W3-4" :entry "macro" :state "macro-recording" :outcome "replay has the same effect" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/transpose-chars/macro-replay")
 (:id "r3:undo:effect" :commands ("undo" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"/\",\"modifiers\":[\"control\"]}]}" :state "editable-buffer" :outcome "buffer changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/undo/effect")
 (:id "r3:upcase-word:read-only" :commands ("execute-extended-command" "toggle-read-only" "upcase-word") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"u\",\"modifiers\":[\"alt\"]}]}" :state "read-only-buffer" :outcome "rejected without byte changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/upcase-word/read-only")
 (:id "r3:upcase-word:effect" :commands ("upcase-word" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"u\",\"modifiers\":[\"alt\"]}]}" :state "editable-buffer" :outcome "buffer changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/upcase-word/effect")
)
