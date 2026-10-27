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
 (:id "r1:delete-backward-char:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22backspace%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D" :commands ("forward-char" "delete-backward-char" "save-buffer") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"backspace\",\"modifiers\":[]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/delete-backward-char/key")
 (:id "r1:delete-char:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22d%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("delete-char" "save-buffer") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"d\",\"modifiers\":[\"control\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/delete-char/key")
 (:id "r1:exchange-point-and-mark:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("execute-extended-command" "set-mark-command" "forward-char" "exchange-point-and-mark") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"x\",\"modifiers\":[\"control\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/exchange-point-and-mark/key")
 (:id "r1:delete-backward-char:mx" :commands ("forward-char" "execute-extended-command" "delete-backward-char" "save-buffer") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/delete-backward-char/mx")
 (:id "r1:delete-char:mx" :commands ("execute-extended-command" "delete-char" "save-buffer") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/delete-char/mx")
 (:id "r1:exchange-point-and-mark:mx" :commands ("execute-extended-command" "set-mark-command" "forward-char" "exchange-point-and-mark") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/exchange-point-and-mark/mx")
 (:id "r1:goto-line:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22g%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%2C%7B%22key%22%3A%22g%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D" :commands ("goto-line") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"g\",\"modifiers\":[\"alt\"]},{\"key\":\"g\",\"modifiers\":[\"alt\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/goto-line/key-meta-g-meta-g")
 (:id "r1:goto-line:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22g%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%2C%7B%22key%22%3A%22g%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D" :commands ("goto-line") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"g\",\"modifiers\":[\"alt\"]},{\"key\":\"g\",\"modifiers\":[]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/goto-line/key-meta-g-g")
 (:id "r1:mark-whole-buffer:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22h%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D" :commands ("forward-char" "mark-whole-buffer") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"h\",\"modifiers\":[]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/mark-whole-buffer/key")
 (:id "r1:mark-whole-buffer:mx" :commands ("forward-char" "execute-extended-command" "mark-whole-buffer") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/mark-whole-buffer/mx")
 (:id "r1:open-line:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22o%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("forward-char" "open-line" "save-buffer") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"o\",\"modifiers\":[\"control\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/open-line/key")
 (:id "r1:set-mark-command:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22%20%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("forward-char" "set-mark-command") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\" \",\"modifiers\":[\"control\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/set-mark-command/key")
 (:id "r1:open-line:mx" :commands ("forward-char" "execute-extended-command" "open-line" "save-buffer") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/open-line/mx")
 (:id "r1:set-mark-command:mx" :commands ("forward-char" "execute-extended-command" "set-mark-command") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/set-mark-command/mx")
 (:id "r1:goto-line:mx" :commands ("execute-extended-command" "goto-line") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/goto-line/mx")
 (:id "r1:narrow-to-region:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22n%22%2C%22modifiers%22%3A%5B%5D%7D%2C%7B%22key%22%3A%22n%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D" :commands ("forward-char" "set-mark-command" "narrow-to-region") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"n\",\"modifiers\":[]},{\"key\":\"n\",\"modifiers\":[]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/narrow-to-region/key")
 (:id "r1:narrow-to-region:mx" :commands ("forward-char" "set-mark-command" "execute-extended-command" "narrow-to-region") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/narrow-to-region/mx")
 (:id "r1:newline:mx" :commands ("execute-extended-command" "newline" "save-buffer") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/newline/mx")
 (:id "r1:redo:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22_%22%2C%22modifiers%22%3A%5B%22alt%22%2C%22control%22%5D%7D%5D%7D" :commands ("delete-char" "undo" "redo" "save-buffer") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"_\",\"modifiers\":[\"alt\",\"control\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/redo/key")
 (:id "r1:redo:mx" :commands ("delete-char" "undo" "execute-extended-command" "redo" "save-buffer") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/redo/mx")
 (:id "r1:backward-char:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22b%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("forward-char" "backward-char") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"b\",\"modifiers\":[\"control\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/backward-char/key")
 (:id "r1:backward-word:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22b%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D" :commands ("forward-char" "backward-word") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"b\",\"modifiers\":[\"alt\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/backward-word/key")
 (:id "r1:beginning-of-buffer:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22%3C%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D" :commands ("forward-char" "beginning-of-buffer") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"<\",\"modifiers\":[\"alt\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/beginning-of-buffer/key")
 (:id "r1:end-of-buffer:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22%3E%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D" :commands ("forward-char" "end-of-buffer") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\">\",\"modifiers\":[\"alt\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/end-of-buffer/key")
 (:id "r1:backward-char:mx" :commands ("forward-char" "execute-extended-command" "backward-char") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/backward-char/mx")
 (:id "r1:backward-word:mx" :commands ("forward-char" "execute-extended-command" "backward-word") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/backward-word/mx")
 (:id "r1:beginning-of-buffer:mx" :commands ("forward-char" "execute-extended-command" "beginning-of-buffer") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/beginning-of-buffer/mx")
 (:id "r1:end-of-buffer:mx" :commands ("forward-char" "execute-extended-command" "end-of-buffer") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/end-of-buffer/mx")
 (:id "r1:forward-char:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22f%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("forward-char") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"f\",\"modifiers\":[\"control\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/forward-char/key")
 (:id "r1:forward-char:mx" :commands ("execute-extended-command" "forward-char") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/forward-char/mx")
 (:id "r1:forward-word:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22f%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D" :commands ("forward-word") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"f\",\"modifiers\":[\"alt\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/forward-word/key")
 (:id "r1:forward-word:mx" :commands ("execute-extended-command" "forward-word") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/forward-word/mx")
 (:id "r1:move-beginning-of-line:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22a%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("forward-char" "move-beginning-of-line") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"a\",\"modifiers\":[\"control\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/move-beginning-of-line/key")
 (:id "r1:move-end-of-line:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22e%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("forward-char" "move-end-of-line") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"e\",\"modifiers\":[\"control\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/move-end-of-line/key")
 (:id "r1:next-line:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22n%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("forward-char" "next-line") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"n\",\"modifiers\":[\"control\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/next-line/key")
 (:id "r1:previous-line:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22p%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("forward-char" "next-line" "previous-line") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"p\",\"modifiers\":[\"control\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/previous-line/key")
 (:id "r1:move-beginning-of-line:mx" :commands ("forward-char" "execute-extended-command" "move-beginning-of-line") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/move-beginning-of-line/mx")
 (:id "r1:move-end-of-line:mx" :commands ("forward-char" "execute-extended-command" "move-end-of-line") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/move-end-of-line/mx")
 (:id "r1:next-line:mx" :commands ("forward-char" "execute-extended-command" "next-line") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/next-line/mx")
 (:id "r1:previous-line:mx" :commands ("forward-char" "next-line" "execute-extended-command" "previous-line") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/previous-line/mx")
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
 (:id "r3:newline:effect" :commands ("forward-char" "newline" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"enter\",\"modifiers\":[]}]}" :state "editable-buffer" :outcome "buffer changes" :observe (:file_bytes) :scenario "command-path/buffer/r3/newline/effect")
 (:id "r3:open-line:effect" :commands ("forward-char" "open-line" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"o\",\"modifiers\":[\"control\"]}]}" :state "editable-buffer" :outcome "buffer changes" :observe (:file_bytes) :scenario "command-path/buffer/r3/open-line/effect")
 (:id "r3:redo:effect" :commands ("redo" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"_\",\"modifiers\":[\"alt\",\"control\"]}]}" :state "editable-buffer" :outcome "buffer changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/redo/effect")
 (:id "r3:transpose-chars:effect" :commands ("transpose-chars" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"t\",\"modifiers\":[\"control\"]}]}" :state "editable-buffer" :outcome "buffer changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/transpose-chars/effect")
 (:id "r3:transpose-chars:read-only" :commands ("execute-extended-command" "toggle-read-only" "transpose-chars") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"t\",\"modifiers\":[\"control\"]}]}" :state "read-only-buffer" :outcome "rejected without byte changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/transpose-chars/read-only")
 (:id "r3:transpose-chars:macro-replay" :commands ("start-kbd-macro" "transpose-chars" "end-kbd-macro" "undo" "move-beginning-of-line" "forward-char" "call-last-kbd-macro" "save-buffer") :rule :r3 :lane "W3-4" :entry "macro" :state "macro-recording" :outcome "replay has the same effect" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/transpose-chars/macro-replay")
 (:id "r3:undo:effect" :commands ("undo" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"/\",\"modifiers\":[\"control\"]}]}" :state "editable-buffer" :outcome "buffer changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/undo/effect")
 (:id "r3:upcase-word:read-only" :commands ("execute-extended-command" "toggle-read-only" "upcase-word") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"u\",\"modifiers\":[\"alt\"]}]}" :state "read-only-buffer" :outcome "rejected without byte changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/upcase-word/read-only")
 (:id "r3:upcase-word:effect" :commands ("upcase-word" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"u\",\"modifiers\":[\"alt\"]}]}" :state "editable-buffer" :outcome "buffer changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/upcase-word/effect")

 (:id "r3:capitalize-word:effect" :commands ("capitalize-word" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"alt\"]}]}" :state "editable-buffer" :outcome "buffer changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/capitalize-word/effect")
 (:id "r3:capitalize-word:undo" :commands ("capitalize-word" "undo" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"alt\"]}]}" :state "after-one-change" :outcome "original bytes restored" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/capitalize-word/undo")
 (:id "r3:downcase-word:effect" :commands ("downcase-word" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"l\",\"modifiers\":[\"alt\"]}]}" :state "editable-buffer" :outcome "buffer changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/downcase-word/effect")
 (:id "r3:downcase-word:undo" :commands ("downcase-word" "undo" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"l\",\"modifiers\":[\"alt\"]}]}" :state "after-one-change" :outcome "original bytes restored" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/downcase-word/undo")
 (:id "r3:upcase-word:undo" :commands ("upcase-word" "undo" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"u\",\"modifiers\":[\"alt\"]}]}" :state "after-one-change" :outcome "original bytes restored" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/upcase-word/undo")


 (:id "r3:capitalize-word:macro-replay" :commands ("start-kbd-macro" "capitalize-word" "end-kbd-macro" "undo" "move-beginning-of-line" "call-last-kbd-macro" "save-buffer") :rule :r3 :lane "W3-4" :entry "macro" :state "macro-recording" :outcome "replay has the same effect" :observe (:file_bytes) :scenario "command-path/buffer/r3/capitalize-word/macro-replay")
 (:id "r3:delete-indentation:macro-replay" :commands ("start-kbd-macro" "forward-char" "delete-indentation" "end-kbd-macro" "undo" "beginning-of-buffer" "call-last-kbd-macro" "save-buffer") :rule :r3 :lane "W3-4" :entry "macro" :state "macro-recording" :outcome "replay has the same effect" :observe (:file_bytes) :scenario "command-path/buffer/r3/delete-indentation/macro-replay")
 (:id "r3:downcase-word:macro-replay" :commands ("start-kbd-macro" "downcase-word" "end-kbd-macro" "undo" "move-beginning-of-line" "call-last-kbd-macro" "save-buffer") :rule :r3 :lane "W3-4" :entry "macro" :state "macro-recording" :outcome "replay has the same effect" :observe (:file_bytes) :scenario "command-path/buffer/r3/downcase-word/macro-replay")
 (:id "r3:newline:macro-replay" :commands ("start-kbd-macro" "forward-char" "execute-extended-command" "newline" "end-kbd-macro" "undo" "beginning-of-buffer" "forward-char" "call-last-kbd-macro" "save-buffer") :rule :r3 :lane "W3-4" :entry "macro" :state "macro-recording" :outcome "replay has the same effect" :observe (:file_bytes) :scenario "command-path/buffer/r3/newline/macro-replay")
 (:id "r3:open-line:macro-replay" :commands ("start-kbd-macro" "forward-char" "open-line" "end-kbd-macro" "undo" "beginning-of-buffer" "forward-char" "call-last-kbd-macro" "save-buffer") :rule :r3 :lane "W3-4" :entry "macro" :state "macro-recording" :outcome "replay has the same effect" :observe (:file_bytes) :scenario "command-path/buffer/r3/open-line/macro-replay")
 (:id "r3:redo:macro-replay" :commands ("start-kbd-macro" "redo" "end-kbd-macro" "undo" "move-beginning-of-line" "call-last-kbd-macro" "save-buffer") :rule :r3 :lane "W3-4" :entry "macro" :state "macro-recording" :outcome "replay has the same effect" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/redo/macro-replay")
 (:id "r3:undo:macro-replay" :commands ("start-kbd-macro" "undo" "end-kbd-macro" "undo" "move-beginning-of-line" "call-last-kbd-macro" "save-buffer") :rule :r3 :lane "W3-4" :entry "macro" :state "macro-recording" :outcome "replay has the same effect" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/undo/macro-replay")
 (:id "r3:upcase-word:macro-replay" :commands ("start-kbd-macro" "upcase-word" "end-kbd-macro" "undo" "move-beginning-of-line" "call-last-kbd-macro" "save-buffer") :rule :r3 :lane "W3-4" :entry "macro" :state "macro-recording" :outcome "replay has the same effect" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/upcase-word/macro-replay")
 (:id "r3:capitalize-word:narrow" :commands ("set-mark-command" "narrow-to-region" "capitalize-word" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"alt\"]}]}" :state "narrowed-buffer" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/capitalize-word/narrow")
 (:id "r3:delete-char:prefix-u4" :commands ("universal-argument" "delete-char" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"d\",\"modifiers\":[\"control\"]}]}" :state "prefix-argument-4" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/delete-char/prefix-u4")
 (:id "r3:delete-indentation:split-window" :commands ("split-window-below" "delete-indentation" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"^\",\"modifiers\":[\"alt\"]}]}" :state "split-window" :outcome "exact screen, body cursor, and file bytes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/delete-indentation/split-window")
 (:id "r3:fill-paragraph:undo" :commands ("fill-paragraph" "undo" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"q\",\"modifiers\":[\"alt\"]}]}" :state "after-one-change" :outcome "original bytes restored" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/fill-paragraph/undo")
 (:id "r3:transpose-chars:undo" :commands ("transpose-chars" "undo" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"t\",\"modifiers\":[\"control\"]}]}" :state "after-one-change" :outcome "original bytes restored" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/transpose-chars/undo")
 (:id "r3:newline:undo" :commands ("forward-char" "newline" "undo" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"enter\",\"modifiers\":[]}]}" :state "after-one-change" :outcome "original bytes restored" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/newline/undo")
 (:id "r3:open-line:undo" :commands ("forward-char" "open-line" "undo" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"o\",\"modifiers\":[\"control\"]}]}" :state "after-one-change" :outcome "original bytes restored" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/open-line/undo")
 (:id "r2:goto-line:prompt-1:numeric:accept" :commands ("goto-line") :rule :r2 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"g\",\"modifiers\":[\"alt\"]},{\"key\":\"g\",\"modifiers\":[\"alt\"]}]};prompt:1:numeric" :state "prompt:numeric" :outcome "accept" :observe (:screen_text) :scenario "command-path/buffer/r2/goto-line/prompt-1-numeric-accept")
 (:id "r2:goto-line:prompt-1:numeric:cancel" :commands ("goto-line") :rule :r2 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"g\",\"modifiers\":[\"alt\"]},{\"key\":\"g\",\"modifiers\":[\"alt\"]}]};prompt:1:numeric" :state "prompt:numeric" :outcome "cancel" :observe (:screen_text) :scenario "command-path/buffer/r2/goto-line/prompt-1-numeric-cancel")
 (:id "r2:goto-line:prompt-1:numeric:history" :commands ("goto-line") :rule :r2 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"g\",\"modifiers\":[\"alt\"]},{\"key\":\"g\",\"modifiers\":[\"alt\"]}]};prompt:1:numeric" :state "prompt:numeric" :outcome "history" :observe (:screen_text) :scenario "command-path/buffer/r2/goto-line/prompt-1-numeric-history")
 (:id "r1:toggle-read-only:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22q%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("toggle-read-only") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"q\",\"modifiers\":[\"control\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/toggle-read-only/key")
 (:id "r1:toggle-read-only:mx" :commands ("execute-extended-command" "toggle-read-only") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/toggle-read-only/mx")
 (:id "r1:undo:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22%2F%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("undo" "save-buffer") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"/\",\"modifiers\":[\"control\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/undo/key:%2F")
 (:id "r1:undo:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22_%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D" :commands ("undo" "save-buffer") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"_\",\"modifiers\":[\"control\"]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/undo/key:%5F")
 (:id "r1:undo:mx" :commands ("execute-extended-command" "undo" "save-buffer") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/undo/mx")
 (:id "r1:widen:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22n%22%2C%22modifiers%22%3A%5B%5D%7D%2C%7B%22key%22%3A%22w%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D" :commands ("forward-char" "set-mark-command" "narrow-to-region" "widen") :rule :r1 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"n\",\"modifiers\":[]},{\"key\":\"w\",\"modifiers\":[]}]}" :state "default" :outcome "command runs from its key sequence" :observe (:screen_text) :scenario "command-path/buffer/r1/widen/key")
 (:id "r1:widen:mx" :commands ("forward-char" "set-mark-command" "narrow-to-region" "execute-extended-command" "widen") :rule :r1 :lane "W3-4" :entry "mx" :state "default" :outcome "command runs from M-x" :observe (:screen_text) :scenario "command-path/buffer/r1/widen/mx")
 (:id "r3:delete-backward-char:read-only" :commands ("execute-extended-command" "toggle-read-only" "delete-backward-char") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"backspace\",\"modifiers\":[]}]}" :state "read-only-buffer" :outcome "rejected without byte changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/delete-backward-char/read-only")
 (:id "r3:delete-indentation:read-only" :commands ("execute-extended-command" "toggle-read-only" "delete-indentation") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"^\",\"modifiers\":[\"alt\"]}]}" :state "read-only-buffer" :outcome "rejected without byte changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/delete-indentation/read-only")
 (:id "r3:newline:read-only" :commands ("execute-extended-command" "toggle-read-only" "newline") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"enter\",\"modifiers\":[]}]}" :state "read-only-buffer" :outcome "rejected without byte changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/newline/read-only")
 (:id "r3:open-line:read-only" :commands ("execute-extended-command" "toggle-read-only" "open-line") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"o\",\"modifiers\":[\"control\"]}]}" :state "read-only-buffer" :outcome "rejected without byte changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/open-line/read-only")
 (:id "r3:redo:read-only" :commands ("save-buffer" "execute-extended-command" "toggle-read-only" "redo") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"_\",\"modifiers\":[\"alt\",\"control\"]}]}" :state "read-only-buffer" :outcome "rejected without byte changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/redo/read-only")
 (:id "r3:undo:read-only" :commands ("save-buffer" "execute-extended-command" "toggle-read-only" "undo") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"/\",\"modifiers\":[\"control\"]}]}" :state "read-only-buffer" :outcome "rejected without byte changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/undo/read-only")
 (:id "r3:delete-indentation:effect" :commands ("delete-indentation" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"^\",\"modifiers\":[\"alt\"]}]}" :state "editable-buffer" :outcome "buffer changes" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/delete-indentation/effect")
 (:id "r3:delete-indentation:undo" :commands ("delete-indentation" "undo" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"^\",\"modifiers\":[\"alt\"]}]}" :state "after-one-change" :outcome "original bytes restored" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/delete-indentation/undo")
 (:id "r3:redo:undo" :commands ("redo" "undo" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"_\",\"modifiers\":[\"alt\",\"control\"]}]}" :state "after-one-change" :outcome "original bytes restored" :observe (:screen_text :file_bytes :cursor) :scenario "command-path/buffer/r3/redo/undo")

 (:id "r3:delete-backward-char:narrow" :commands ("execute-extended-command" "beginning-of-buffer" "set-mark-command" "move-end-of-line" "forward-char" "narrow-to-region" "beginning-of-buffer" "delete-backward-char" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"backspace\",\"modifiers\":[]}]}" :state "narrowed-buffer" :outcome "outside range remains unchanged" :observe (:file_bytes) :scenario "command-path/buffer/r3/delete-backward-char/narrow")
 (:id "r3:delete-char:narrow" :commands ("execute-extended-command" "beginning-of-buffer" "set-mark-command" "move-end-of-line" "forward-char" "narrow-to-region" "beginning-of-buffer" "delete-char" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"d\",\"modifiers\":[\"control\"]}]}" :state "narrowed-buffer" :outcome "outside range remains unchanged" :observe (:file_bytes) :scenario "command-path/buffer/r3/delete-char/narrow")
 (:id "r3:delete-indentation:narrow" :commands ("execute-extended-command" "beginning-of-buffer" "set-mark-command" "next-line" "narrow-to-region" "beginning-of-buffer" "delete-indentation" "save-buffer") :rule :r3 :lane "W3-4" :entry "macro" :state "narrowed-buffer" :outcome "outside range remains unchanged" :observe (:file_bytes) :scenario "command-path/buffer/r3/delete-indentation/narrow")
 (:id "r3:downcase-word:narrow" :commands ("execute-extended-command" "beginning-of-buffer" "set-mark-command" "move-end-of-line" "forward-char" "narrow-to-region" "beginning-of-buffer" "downcase-word" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"l\",\"modifiers\":[\"alt\"]}]}" :state "narrowed-buffer" :outcome "outside range remains unchanged" :observe (:file_bytes) :scenario "command-path/buffer/r3/downcase-word/narrow")
 (:id "r3:fill-paragraph:narrow" :commands ("execute-extended-command" "beginning-of-buffer" "set-mark-command" "next-line" "move-end-of-line" "forward-char" "narrow-to-region" "beginning-of-buffer" "fill-paragraph" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"q\",\"modifiers\":[\"alt\"]}]}" :state "narrowed-buffer" :outcome "outside range remains unchanged" :observe (:file_bytes) :scenario "command-path/buffer/r3/fill-paragraph/narrow")
 (:id "r3:newline:narrow" :commands ("execute-extended-command" "beginning-of-buffer" "set-mark-command" "move-end-of-line" "forward-char" "narrow-to-region" "beginning-of-buffer" "newline" "save-buffer") :rule :r3 :lane "W3-4" :entry "mx" :state "narrowed-buffer" :outcome "outside range remains unchanged" :observe (:file_bytes) :scenario "command-path/buffer/r3/newline/narrow")
 (:id "r3:open-line:narrow" :commands ("execute-extended-command" "beginning-of-buffer" "set-mark-command" "move-end-of-line" "forward-char" "narrow-to-region" "beginning-of-buffer" "open-line" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"o\",\"modifiers\":[\"control\"]}]}" :state "narrowed-buffer" :outcome "outside range remains unchanged" :observe (:file_bytes) :scenario "command-path/buffer/r3/open-line/narrow")
 (:id "r3:transpose-chars:narrow" :commands ("execute-extended-command" "beginning-of-buffer" "set-mark-command" "move-end-of-line" "forward-char" "narrow-to-region" "beginning-of-buffer" "transpose-chars" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"t\",\"modifiers\":[\"control\"]}]}" :state "narrowed-buffer" :outcome "outside range remains unchanged" :observe (:file_bytes) :scenario "command-path/buffer/r3/transpose-chars/narrow")
 (:id "r3:upcase-word:narrow" :commands ("execute-extended-command" "beginning-of-buffer" "set-mark-command" "move-end-of-line" "forward-char" "narrow-to-region" "beginning-of-buffer" "upcase-word" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"u\",\"modifiers\":[\"alt\"]}]}" :state "narrowed-buffer" :outcome "outside range remains unchanged" :observe (:file_bytes) :scenario "command-path/buffer/r3/upcase-word/narrow")
 (:id "r3:undo:narrow" :commands ("execute-extended-command" "beginning-of-buffer" "move-end-of-line" "set-mark-command" "forward-char" "narrow-to-region" "beginning-of-buffer" "undo" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"/\",\"modifiers\":[\"control\"]}]}" :state "narrowed-buffer" :outcome "outside range remains unchanged" :observe (:file_bytes) :scenario "command-path/buffer/r3/undo/narrow")
 (:id "r3:capitalize-word:prefix-u4" :commands ("universal-argument" "capitalize-word" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"c\",\"modifiers\":[\"alt\"]}]}" :state "prefix-C-u-4" :outcome "specified prefix behavior is observed" :observe (:file_bytes) :scenario "command-path/buffer/r3/capitalize-word/prefix-u4")
 (:id "r3:delete-backward-char:prefix-u4" :commands ("move-end-of-line" "universal-argument" "delete-backward-char" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"backspace\",\"modifiers\":[]}]}" :state "prefix-C-u-4" :outcome "specified prefix behavior is observed" :observe (:file_bytes) :scenario "command-path/buffer/r3/delete-backward-char/prefix-u4")
 (:id "r3:delete-indentation:prefix-u4" :commands ("universal-argument" "delete-indentation" "save-buffer") :rule :r3 :lane "W3-4" :entry "macro" :state "prefix-C-u-4" :outcome "specified prefix behavior is observed" :observe (:file_bytes) :scenario "command-path/buffer/r3/delete-indentation/prefix-u4")
 (:id "r3:downcase-word:prefix-u4" :commands ("universal-argument" "downcase-word" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"l\",\"modifiers\":[\"alt\"]}]}" :state "prefix-C-u-4" :outcome "specified prefix behavior is observed" :observe (:file_bytes) :scenario "command-path/buffer/r3/downcase-word/prefix-u4")
 (:id "r3:fill-paragraph:prefix-u4" :commands ("universal-argument" "fill-paragraph" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"q\",\"modifiers\":[\"alt\"]}]}" :state "prefix-C-u-4" :outcome "specified prefix behavior is observed" :observe (:file_bytes) :scenario "command-path/buffer/r3/fill-paragraph/prefix-u4")
 (:id "r3:open-line:prefix-u4" :commands ("universal-argument" "open-line" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"o\",\"modifiers\":[\"control\"]}]}" :state "prefix-C-u-4" :outcome "specified prefix behavior is observed" :observe (:file_bytes) :scenario "command-path/buffer/r3/open-line/prefix-u4")
 (:id "r3:transpose-chars:prefix-u4" :commands ("universal-argument" "transpose-chars" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"t\",\"modifiers\":[\"control\"]}]}" :state "prefix-C-u-4" :outcome "specified prefix behavior is observed" :observe (:file_bytes) :scenario "command-path/buffer/r3/transpose-chars/prefix-u4")
 (:id "r3:upcase-word:prefix-u4" :commands ("universal-argument" "upcase-word" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"u\",\"modifiers\":[\"alt\"]}]}" :state "prefix-C-u-4" :outcome "specified prefix behavior is observed" :observe (:file_bytes) :scenario "command-path/buffer/r3/upcase-word/prefix-u4")
 (:id "r3:end-of-buffer:effect" :commands ("end-of-buffer" "save-buffer") :rule :r3 :lane "W3-4" :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\">\",\"modifiers\":[\"alt\"]}]}" :state "default" :outcome "moves point to end of buffer" :observe (:file_bytes :cursor) :scenario "command-path/buffer/r3/end-of-buffer/effect")
)
