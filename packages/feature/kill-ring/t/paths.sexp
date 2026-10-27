((:id
  "r1:backward-kill-word:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22backspace%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D"
  :commands
  ("backward-kill-word")
  :rule
  :r1
  :lane
  "W3-8"
  :entry
  "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"backspace\",\"modifiers\":[\"alt\"]}]}"
  :state
  "default"
  :outcome
  "command runs from its key sequence"
  :observe
  (:screen_text)
  :scenario
  "command-path/kill-ring/r1/backward-kill-word/key")
 (:id "r1:backward-kill-word:mx"
      :commands
      ("backward-kill-word")
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
      "command-path/kill-ring/r1/backward-kill-word/mx")
 (:id
  "r1:kill-line:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22k%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D"
  :commands
  ("kill-line")
  :rule
  :r1
  :lane
  "W3-8"
  :entry
  "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"k\",\"modifiers\":[\"control\"]}]}"
  :state
  "default"
  :outcome
  "command runs from its key sequence"
  :observe
  (:screen_text)
  :scenario
  "command-path/kill-ring/r1/kill-line/key")
 (:id "r1:kill-line:mx"
      :commands
      ("kill-line")
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
      "command-path/kill-ring/r1/kill-line/mx")
 (:id
  "r1:kill-region:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22w%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D"
  :commands
  ("kill-region")
  :rule
  :r1
  :lane
  "W3-8"
  :entry
  "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"w\",\"modifiers\":[\"control\"]}]}"
  :state
  "default"
  :outcome
  "command runs from its key sequence"
  :observe
  (:screen_text)
  :scenario
  "command-path/kill-ring/r1/kill-region/key")
 (:id "r1:kill-region:mx"
      :commands
      ("kill-region")
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
      "command-path/kill-ring/r1/kill-region/mx")
 (:id
  "r1:kill-ring-save:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22w%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D"
  :commands
  ("kill-ring-save")
  :rule
  :r1
  :lane
  "W3-8"
  :entry
  "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"w\",\"modifiers\":[\"alt\"]}]}"
  :state
  "default"
  :outcome
  "command runs from its key sequence"
  :observe
  (:screen_text)
  :scenario
  "command-path/kill-ring/r1/kill-ring-save/key")
 (:id "r1:kill-ring-save:mx"
      :commands
      ("kill-ring-save")
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
      "command-path/kill-ring/r1/kill-ring-save/mx")
 (:id
  "r1:kill-word:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22d%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D"
  :commands
  ("kill-word")
  :rule
  :r1
  :lane
  "W3-8"
  :entry
  "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"d\",\"modifiers\":[\"alt\"]}]}"
  :state
  "default"
  :outcome
  "command runs from its key sequence"
  :observe
  (:screen_text)
  :scenario
  "command-path/kill-ring/r1/kill-word/key")
 (:id "r1:kill-word:mx"
      :commands
      ("kill-word")
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
      "command-path/kill-ring/r1/kill-word/mx")
 (:id
  "r1:yank-pop:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22y%22%2C%22modifiers%22%3A%5B%22alt%22%5D%7D%5D%7D"
  :commands
  ("yank-pop")
  :rule
  :r1
  :lane
  "W3-8"
  :entry
  "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"y\",\"modifiers\":[\"alt\"]}]}"
  :state
  "default"
  :outcome
  "command runs from its key sequence"
  :observe
  (:screen_text)
  :scenario
  "command-path/kill-ring/r1/yank-pop/key")
 (:id "r1:yank-pop:mx"
      :commands
      ("yank-pop")
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
      "command-path/kill-ring/r1/yank-pop/mx")
 (:id
  "r1:yank:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22y%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D"
  :commands
  ("yank")
  :rule
  :r1
  :lane
  "W3-8"
  :entry
  "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"y\",\"modifiers\":[\"control\"]}]}"
  :state
  "default"
  :outcome
  "command runs from its key sequence"
  :observe
  (:screen_text)
  :scenario
  "command-path/kill-ring/r1/yank/key")
 (:id "r1:yank:mx"
      :commands
      ("yank")
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
      "command-path/kill-ring/r1/yank/mx")
 (:id "r3:backward-kill-word:effect"
      :commands
      ("backward-kill-word")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"backspace\",\"modifiers\":[\"alt\"]}]}"
      :state
      "editable-buffer"
      :outcome
      "buffer changes"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/backward-kill-word/effect")
 (:id "r3:backward-kill-word:macro-replay"
      :commands
      ("backward-kill-word")
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
      "command-path/kill-ring/r3/backward-kill-word/macro-replay")
 (:id "r3:backward-kill-word:narrow"
      :commands
      ("backward-kill-word")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"backspace\",\"modifiers\":[\"alt\"]}]}"
      :state
      "narrowed-buffer"
      :outcome
      "outside range remains unchanged"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/backward-kill-word/narrow")
 (:id "r3:backward-kill-word:prefix-u4"
      :commands
      ("backward-kill-word")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"backspace\",\"modifiers\":[\"alt\"]}]}"
      :state
      "prefix-C-u-4"
      :outcome
      "specified prefix behavior is observed"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/backward-kill-word/prefix-u4")
 (:id "r3:backward-kill-word:read-only"
      :commands
      ("backward-kill-word")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"backspace\",\"modifiers\":[\"alt\"]}]}"
      :state
      "read-only-buffer"
      :outcome
      "rejected without byte changes"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/backward-kill-word/read-only")
 (:id "r3:backward-kill-word:split-window"
      :commands
      ("backward-kill-word")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"backspace\",\"modifiers\":[\"alt\"]}]}"
      :state
      "split-window"
      :outcome
      "both views reflect the change"
      :observe
      (:screen_text)
      :scenario
      "command-path/kill-ring/r3/backward-kill-word/split-window")
 (:id "r3:backward-kill-word:undo"
      :commands
      ("backward-kill-word")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"backspace\",\"modifiers\":[\"alt\"]}]}"
      :state
      "after-one-change"
      :outcome
      "original bytes restored"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/backward-kill-word/undo")
 (:id "r3:kill-line:effect"
      :commands
      ("kill-line")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"k\",\"modifiers\":[\"control\"]}]}"
      :state
      "editable-buffer"
      :outcome
      "buffer changes"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/kill-line/effect")
 (:id "r3:kill-line:macro-replay"
      :commands
      ("kill-line")
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
      "command-path/kill-ring/r3/kill-line/macro-replay")
 (:id "r3:kill-line:narrow"
      :commands
      ("kill-line")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"k\",\"modifiers\":[\"control\"]}]}"
      :state
      "narrowed-buffer"
      :outcome
      "outside range remains unchanged"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/kill-line/narrow")
 (:id "r3:kill-line:prefix-u4"
      :commands
      ("kill-line")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"k\",\"modifiers\":[\"control\"]}]}"
      :state
      "prefix-C-u-4"
      :outcome
      "specified prefix behavior is observed"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/kill-line/prefix-u4")
 (:id "r3:kill-line:read-only"
      :commands
      ("kill-line")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"k\",\"modifiers\":[\"control\"]}]}"
      :state
      "read-only-buffer"
      :outcome
      "rejected without byte changes"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/kill-line/read-only")
 (:id "r3:kill-line:split-window"
      :commands
      ("kill-line")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"k\",\"modifiers\":[\"control\"]}]}"
      :state
      "split-window"
      :outcome
      "both views reflect the change"
      :observe
      (:screen_text)
      :scenario
      "command-path/kill-ring/r3/kill-line/split-window")
 (:id "r3:kill-line:undo"
      :commands
      ("kill-line")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"k\",\"modifiers\":[\"control\"]}]}"
      :state
      "after-one-change"
      :outcome
      "original bytes restored"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/kill-line/undo")
 (:id "r3:kill-region:effect"
      :commands
      ("kill-region")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"w\",\"modifiers\":[\"control\"]}]}"
      :state
      "editable-buffer"
      :outcome
      "buffer changes"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/kill-region/effect")
 (:id "r3:kill-region:macro-replay"
      :commands
      ("kill-region")
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
      "command-path/kill-ring/r3/kill-region/macro-replay")
 (:id "r3:kill-region:narrow"
      :commands
      ("kill-region")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"w\",\"modifiers\":[\"control\"]}]}"
      :state
      "narrowed-buffer"
      :outcome
      "outside range remains unchanged"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/kill-region/narrow")
 (:id "r3:kill-region:prefix-u4"
      :commands
      ("kill-region")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"w\",\"modifiers\":[\"control\"]}]}"
      :state
      "prefix-C-u-4"
      :outcome
      "specified prefix behavior is observed"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/kill-region/prefix-u4")
 (:id "r3:kill-region:read-only"
      :commands
      ("kill-region")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"w\",\"modifiers\":[\"control\"]}]}"
      :state
      "read-only-buffer"
      :outcome
      "rejected without byte changes"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/kill-region/read-only")
 (:id "r3:kill-region:split-window"
      :commands
      ("kill-region")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"w\",\"modifiers\":[\"control\"]}]}"
      :state
      "split-window"
      :outcome
      "both views reflect the change"
      :observe
      (:screen_text)
      :scenario
      "command-path/kill-ring/r3/kill-region/split-window")
 (:id "r3:kill-region:undo"
      :commands
      ("kill-region")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"w\",\"modifiers\":[\"control\"]}]}"
      :state
      "after-one-change"
      :outcome
      "original bytes restored"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/kill-region/undo")
 (:id "r3:kill-word:effect"
      :commands
      ("kill-word")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"d\",\"modifiers\":[\"alt\"]}]}"
      :state
      "editable-buffer"
      :outcome
      "buffer changes"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/kill-word/effect")
 (:id "r3:kill-word:macro-replay"
      :commands
      ("kill-word")
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
      "command-path/kill-ring/r3/kill-word/macro-replay")
 (:id "r3:kill-word:narrow"
      :commands
      ("kill-word")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"d\",\"modifiers\":[\"alt\"]}]}"
      :state
      "narrowed-buffer"
      :outcome
      "outside range remains unchanged"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/kill-word/narrow")
 (:id "r3:kill-word:prefix-u4"
      :commands
      ("kill-word")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"d\",\"modifiers\":[\"alt\"]}]}"
      :state
      "prefix-C-u-4"
      :outcome
      "specified prefix behavior is observed"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/kill-word/prefix-u4")
 (:id "r3:kill-word:read-only"
      :commands
      ("kill-word")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"d\",\"modifiers\":[\"alt\"]}]}"
      :state
      "read-only-buffer"
      :outcome
      "rejected without byte changes"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/kill-word/read-only")
 (:id "r3:kill-word:split-window"
      :commands
      ("kill-word")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"d\",\"modifiers\":[\"alt\"]}]}"
      :state
      "split-window"
      :outcome
      "both views reflect the change"
      :observe
      (:screen_text)
      :scenario
      "command-path/kill-ring/r3/kill-word/split-window")
 (:id "r3:kill-word:undo"
      :commands
      ("kill-word")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"d\",\"modifiers\":[\"alt\"]}]}"
      :state
      "after-one-change"
      :outcome
      "original bytes restored"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/kill-word/undo")
 (:id "r3:yank-pop:effect"
      :commands
      ("yank-pop")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"y\",\"modifiers\":[\"alt\"]}]}"
      :state
      "editable-buffer"
      :outcome
      "buffer changes"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/yank-pop/effect")
 (:id "r3:yank-pop:macro-replay"
      :commands
      ("yank-pop")
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
      "command-path/kill-ring/r3/yank-pop/macro-replay")
 (:id "r3:yank-pop:narrow"
      :commands
      ("yank-pop")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"y\",\"modifiers\":[\"alt\"]}]}"
      :state
      "narrowed-buffer"
      :outcome
      "outside range remains unchanged"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/yank-pop/narrow")
 (:id "r3:yank-pop:prefix-u4"
      :commands
      ("yank-pop")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"y\",\"modifiers\":[\"alt\"]}]}"
      :state
      "prefix-C-u-4"
      :outcome
      "specified prefix behavior is observed"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/yank-pop/prefix-u4")
 (:exclude :id "r3:yank-pop:read-only" :reason "M-x toggle-read-only clears the previous yank context before M-y, so this path cannot reach the yank-pop read-only guard" :evidence "src/application/input-routing-effects.lisp:4")
 (:id "r3:yank-pop:split-window"
      :commands
      ("yank-pop")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"y\",\"modifiers\":[\"alt\"]}]}"
      :state
      "split-window"
      :outcome
      "both views reflect the change"
      :observe
      (:screen_text)
      :scenario
      "command-path/kill-ring/r3/yank-pop/split-window")
 (:id "r3:yank-pop:undo"
      :commands
      ("yank-pop")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"y\",\"modifiers\":[\"alt\"]}]}"
      :state
      "after-one-change"
      :outcome
      "original bytes restored"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/yank-pop/undo")
 (:id "r3:yank:effect"
      :commands
      ("yank")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"y\",\"modifiers\":[\"control\"]}]}"
      :state
      "editable-buffer"
      :outcome
      "buffer changes"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/yank/effect")
 (:id "r3:yank:macro-replay"
      :commands
      ("yank")
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
      "command-path/kill-ring/r3/yank/macro-replay")
 (:id "r3:yank:narrow"
      :commands
      ("yank")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"y\",\"modifiers\":[\"control\"]}]}"
      :state
      "narrowed-buffer"
      :outcome
      "outside range remains unchanged"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/yank/narrow")
 (:id "r3:yank:prefix-u4"
      :commands
      ("yank")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"y\",\"modifiers\":[\"control\"]}]}"
      :state
      "prefix-C-u-4"
      :outcome
      "specified prefix behavior is observed"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/yank/prefix-u4")
 (:id "r3:yank:read-only"
      :commands
      ("yank")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"y\",\"modifiers\":[\"control\"]}]}"
      :state
      "read-only-buffer"
      :outcome
      "rejected without byte changes"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/yank/read-only")
 (:id "r3:yank:split-window"
      :commands
      ("yank")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"y\",\"modifiers\":[\"control\"]}]}"
      :state
      "split-window"
      :outcome
      "both views reflect the change"
      :observe
      (:screen_text)
      :scenario
      "command-path/kill-ring/r3/yank/split-window")
 (:id "r3:yank:undo"
      :commands
      ("yank")
      :rule
      :r3
      :lane
      "W3-8"
      :entry
      "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"y\",\"modifiers\":[\"control\"]}]}"
      :state
      "after-one-change"
      :outcome
      "original bytes restored"
      :observe
      (:file_bytes)
      :scenario
      "command-path/kill-ring/r3/yank/undo")
 (:id "r5:kill-line:clipboard:success"
      :commands
      ("kill-line")
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
      "r5/clipboard/kill-line/success")
 (:id "r5:kill-line:clipboard:missing"
      :commands
      ("kill-line")
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
      "r5/clipboard/kill-line/missing")
 (:id "r5:kill-line:clipboard:nonzero"
      :commands
      ("kill-line")
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
      "r5/clipboard/kill-line/nonzero")
 (:id "r5:kill-line:clipboard:interrupted"
      :commands
      ("kill-line")
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
      "r5/clipboard/kill-line/interrupted")
 (:id "r5:kill-word:clipboard:success"
      :commands
      ("kill-word")
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
      "r5/clipboard/kill-word/success")
 (:id "r5:kill-word:clipboard:missing"
      :commands
      ("kill-word")
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
      "r5/clipboard/kill-word/missing")
 (:id "r5:kill-word:clipboard:nonzero"
      :commands
      ("kill-word")
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
      "r5/clipboard/kill-word/nonzero")
 (:id "r5:kill-word:clipboard:interrupted"
      :commands
      ("kill-word")
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
      "r5/clipboard/kill-word/interrupted")
 (:id "r5:backward-kill-word:clipboard:success"
      :commands
      ("backward-kill-word")
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
      "r5/clipboard/backward-kill-word/success")
 (:id "r5:backward-kill-word:clipboard:missing"
      :commands
      ("backward-kill-word")
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
      "r5/clipboard/backward-kill-word/missing")
 (:id "r5:backward-kill-word:clipboard:nonzero"
      :commands
      ("backward-kill-word")
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
      "r5/clipboard/backward-kill-word/nonzero")
 (:id "r5:backward-kill-word:clipboard:interrupted"
      :commands
      ("backward-kill-word")
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
      "r5/clipboard/backward-kill-word/interrupted")
 (:id "r5:kill-region:clipboard:success"
      :commands
      ("kill-region")
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
      "r5/clipboard/kill-region/success")
 (:id "r5:kill-region:clipboard:missing"
      :commands
      ("kill-region")
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
      "r5/clipboard/kill-region/missing")
 (:id "r5:kill-region:clipboard:nonzero"
      :commands
      ("kill-region")
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
      "r5/clipboard/kill-region/nonzero")
 (:id "r5:kill-region:clipboard:interrupted"
      :commands
      ("kill-region")
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
      "r5/clipboard/kill-region/interrupted")
 (:id "r5:kill-ring-save:clipboard:success"
      :commands
      ("kill-ring-save")
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
      "r5/clipboard/kill-ring-save/success")
 (:id "r5:kill-ring-save:clipboard:missing"
      :commands
      ("kill-ring-save")
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
      "r5/clipboard/kill-ring-save/missing")
 (:id "r5:kill-ring-save:clipboard:nonzero"
      :commands
      ("kill-ring-save")
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
      "r5/clipboard/kill-ring-save/nonzero")
 (:id "r5:kill-ring-save:clipboard:interrupted"
      :commands
      ("kill-ring-save")
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
      "r5/clipboard/kill-ring-save/interrupted")
 (:id "r4:kill-region:region-present"
      :commands
      ("kill-region")
      :rule
      :r4
      :lane
      "W3-8"
      :entry
      "mx"
      :state
      "region-present"
      :outcome
      "command operates on region"
      :observe
      (:file_bytes :screen_text)
      :scenario
      "kill-ring/r4/kill-region/region-present")
 (:id "r4:kill-region:region-absent"
      :commands
      ("kill-region")
      :rule
      :r4
      :lane
      "W3-8"
      :entry
      "mx"
      :state
      "region-absent"
      :outcome
      "command handles missing region"
      :observe
      (:file_bytes :screen_text)
      :scenario
      "kill-ring/r4/kill-region/region-absent")
 (:id "r4:kill-ring-save:region-present"
      :commands
      ("kill-ring-save")
      :rule
      :r4
      :lane
      "W3-8"
      :entry
      "mx"
      :state
      "region-present"
      :outcome
      "command operates on region"
      :observe
      (:file_bytes :screen_text)
      :scenario
      "kill-ring/r4/kill-ring-save/region-present")
 (:id "r4:kill-ring-save:region-absent"
      :commands
      ("kill-ring-save")
      :rule
      :r4
      :lane
      "W3-8"
      :entry
      "mx"
      :state
      "region-absent"
      :outcome
      "command handles missing region"
      :observe
      (:file_bytes :screen_text)
      :scenario
      "kill-ring/r4/kill-ring-save/region-absent"))
