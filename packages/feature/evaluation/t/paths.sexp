((:id "r1:eval-last-sexp:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22e%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%5D%7D"
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
  :state "default"
  :outcome "eval-buffer runs from M-x"
  :observe (:screen_text)
  :scenario "macros/eval-buffer"))
