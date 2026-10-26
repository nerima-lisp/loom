; Insert scenarios type characters through core/self-insert, but the generator has no insert target commands.
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
  :commands ("core/self-insert")
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
  :commands ("core/self-insert")
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
  :commands ("core/self-insert")
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
  :commands ("core/self-insert")
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
  :commands ("core/self-insert")
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
)
