(
  (:id "r1:format-current-buffer:mx"
   :commands (:format-current-buffer)
   :rule :r1
   :entry "mx"
   :state "default"
   :outcome "command runs from M-x"
   :observe (:screen_text)
   :scenario "format/real-nixfmt-success"
   :lane "W3-11")
  (:id "r1:format-on-save-mode:mx"
   :commands (:format-on-save-mode)
   :rule :r1
   :entry "mx"
   :state "default"
   :outcome "command runs from M-x"
   :observe (:screen_text :file_bytes)
   :scenario "format/format-on-save-real-nixfmt"
   :lane "W3-11")
  (:id "r1:set-format-command:mx"
   :commands (:set-format-command)
   :rule :r1
   :entry "mx"
   :state "default"
   :outcome "command runs from M-x"
   :observe (:screen_text)
   :scenario "format/format-on-save-real-nixfmt"
   :lane "W3-11")
  (:id "r5:format-current-buffer:shell:success"
   :commands (:format-current-buffer)
   :rule :r5
   :entry "mx"
   :state "tool:shell"
   :outcome "success"
   :observe (:external_state)
   :scenario "format/real-nixfmt-success"
   :lane "W3-11")
  (:id "r5:format-current-buffer:shell:missing"
   :commands (:format-current-buffer)
   :rule :r5
   :entry "mx"
   :state "tool:shell"
   :outcome "missing"
   :observe (:external_state)
   :scenario "format/missing-formatter"
   :lane "W3-11")
  (:id "r5:format-current-buffer:shell:nonzero"
   :commands (:format-current-buffer)
   :rule :r5
   :entry "mx"
   :state "tool:shell"
   :outcome "nonzero"
   :observe (:external_state)
   :scenario "format/real-nixfmt-nonzero"
   :lane "W3-11")
  (:id "r5:format-current-buffer:shell:interrupted"
   :commands (:format-current-buffer)
   :rule :r5
   :entry "mx"
   :state "tool:shell"
   :outcome "interrupted"
   :observe (:screen_text)
   :scenario "format/interrupted-formatter"
   :lane "W3-11")
)
