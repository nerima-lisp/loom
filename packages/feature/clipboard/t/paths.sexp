((:id "r1:clipboard-yank:mx"
      :commands
      ("clipboard-yank")
      :rule
      :r1
      :lane
      "W3-8"
      :entry
      "mx"
      :state
      "default"
      :outcome
      "command runs from M-x"
      :observe
      (:screen_text)
      :scenario
      "command-path/r1/clipboard-yank/mx")
 (:id "r3:clipboard-yank:effect"
      :commands
      ("clipboard-yank")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "mx"
      :state
      "editable-buffer"
      :outcome
      "buffer changes"
      :observe
      (:file_bytes)
      :scenario
      "command-path/r3/clipboard-yank/effect")
 (:id "r3:clipboard-yank:macro-replay"
      :commands
      ("clipboard-yank")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "macro"
      :state
      "macro-recording"
      :outcome
      "replay has the same effect"
      :observe
      (:file_bytes)
      :scenario
      "command-path/r3/clipboard-yank/macro-replay")
 (:id "r3:clipboard-yank:narrow"
      :commands
      ("clipboard-yank")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "mx"
      :state
      "narrowed-buffer"
      :outcome
      "outside range remains unchanged"
      :observe
      (:file_bytes)
      :scenario
      "command-path/r3/clipboard-yank/narrow")
 (:id "r3:clipboard-yank:prefix-u4"
      :commands
      ("clipboard-yank")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "mx"
      :state
      "prefix-C-u-4"
      :outcome
      "specified prefix behavior is observed"
      :observe
      (:file_bytes)
      :scenario
      "command-path/r3/clipboard-yank/prefix-u4")
 (:id "r3:clipboard-yank:read-only"
      :commands
      ("clipboard-yank")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "mx"
      :state
      "read-only-buffer"
      :outcome
      "rejected without byte changes"
      :observe
      (:file_bytes)
      :scenario
      "command-path/r3/clipboard-yank/read-only")
 (:id "r3:clipboard-yank:split-window"
      :commands
      ("clipboard-yank")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "mx"
      :state
      "split-window"
      :outcome
      "both views reflect the change"
      :observe
      (:screen_text)
      :scenario
      "command-path/r3/clipboard-yank/split-window")
 (:id "r3:clipboard-yank:undo"
      :commands
      ("clipboard-yank")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "mx"
      :state
      "after-one-change"
      :outcome
      "original bytes restored"
      :observe
      (:file_bytes)
      :scenario
      "command-path/r3/clipboard-yank/undo")
 (:id "r5:clipboard-yank:clipboard:success"
      :commands
      ("clipboard-yank")
      :rule
      :r5
      :lane
      "W3-8"
      :entry
      "mx"
      :state
      "tool:clipboard"
      :outcome
      "success"
      :observe
      (:external_state)
      :scenario
      "r5/clipboard/clipboard-yank/success")
 (:id "r5:clipboard-yank:clipboard:missing"
      :commands
      ("clipboard-yank")
      :rule
      :r5
      :lane
      "W3-8"
      :entry
      "mx"
      :state
      "tool:clipboard"
      :outcome
      "missing"
      :observe
      (:external_state)
      :scenario
      "r5/clipboard/clipboard-yank/missing")
 (:id "r5:clipboard-yank:clipboard:nonzero"
      :commands
      ("clipboard-yank")
      :rule
      :r5
      :lane
      "W3-8"
      :entry
      "mx"
      :state
      "tool:clipboard"
      :outcome
      "nonzero"
      :observe
      (:external_state)
      :scenario
      "r5/clipboard/clipboard-yank/nonzero")
 (:id "r5:clipboard-yank:clipboard:interrupted"
      :commands
      ("clipboard-yank")
      :rule
      :r5
      :lane
      "W3-8"
      :entry
      "mx"
      :state
      "tool:clipboard"
      :outcome
      "interrupted"
      :observe
      (:external_state)
      :scenario
      "r5/clipboard/clipboard-yank/interrupted"))
