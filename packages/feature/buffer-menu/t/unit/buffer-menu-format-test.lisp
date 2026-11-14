(in-package #:loom/test)

(describe
  "buffer menu line formatting"
  (it
    "puts the mark in column 0 and the current, read-only, and modified flags in columns 2-4"
    (expect (loom/feature/buffer-menu::buffer-menu-format-lines
             (list (list nil t nil nil "a" 1 "Text" "")
                   (list :delete nil t nil "b" 2 "Text" "")
                   (list :save nil nil t "c" 3 "Text" "")))
            :to-equal
            (format nil "  .   a 1 Text~%D  %  b 2 Text~%S   * c 3 Text")))

  (it
    "aligns names, right-aligns sizes, and pads modes from the widest value"
    (expect (loom/feature/buffer-menu::buffer-menu-format-lines
             (list (list nil nil nil nil "short" 7 "Text" "~/a.txt")
                   (list nil nil nil nil "*Buffer List*" 1234 "Buffer Menu" "")))
            :to-equal
            (format nil "      short            7 Text        ~~/a.txt~%      *Buffer List* 1234 Buffer Menu")))

  (it
    "returns one line per row with no header and no trailing newline"
    (let ((text (loom/feature/buffer-menu::buffer-menu-format-lines
                 (list (list nil nil nil nil "x" 0 "Fundamental" "")
                       (list nil nil nil nil "y" 0 "Fundamental" "")))))
      (expect (count #\Newline text) :to-equal 1)
      (expect (char text (1- (length text))) :to-equal #\l)))

  (it
    "abbreviates the home directory to ~ only at a directory boundary"
    (let ((abbreviate #'loom/feature/buffer-menu::buffer-menu-abbreviate-path))
      (expect (funcall abbreviate "/home/me/src/a.txt" "/home/me") :to-equal "~/src/a.txt")
      (expect (funcall abbreviate "/home/me/src/a.txt" "/home/me/") :to-equal "~/src/a.txt")
      (expect (funcall abbreviate "/home/me" "/home/me/") :to-equal "~")
      (expect (funcall abbreviate "/home/meadow/a.txt" "/home/me") :to-equal "/home/meadow/a.txt")
      (expect (funcall abbreviate "/tmp/a.txt" "/home/me") :to-equal "/tmp/a.txt")
      (expect (funcall abbreviate "/tmp/a.txt" nil) :to-equal "/tmp/a.txt")
      (expect (funcall abbreviate nil "/home/me") :to-equal "")))

  (it
    "recognizes internal buffer names"
    (expect (loom/feature/buffer-menu::buffer-menu-special-name-p "*Messages*") :to-be-truthy)
    (expect (loom/feature/buffer-menu::buffer-menu-special-name-p "*") :to-be nil)
    (expect (loom/feature/buffer-menu::buffer-menu-special-name-p "a.txt") :to-be nil)))
