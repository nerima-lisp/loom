;;;; t/unit/terminal-screen-control-test.lisp
;;;;
;;;; Terminal screen control sequences, scrolling, and resizing.
(in-package #:loom/test)

(describe
  "terminal screen control behavior"
  (it "handles terminal control sequences, scrolling, and resizing"
    (let ((screen (make-terminal-screen :width 4 :height 2)))
      (terminal-screen-feed screen (format nil "1234~C~C5678"
                                           (code-char 27) (code-char 10)))
      (terminal-screen-feed screen (format nil "~C[1;1H~C[2X~C[2J"
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)))
      (expect (terminal-screen-text screen) :to-equal "")
      (terminal-screen-feed screen "ab")
      (terminal-screen-feed screen (format nil "~C[1;1H~C[L~C[M~C[S~C[T"
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)))
      (terminal-screen-feed screen (format nil "~C7~C[1;3H~C8"
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)))
      (terminal-screen-feed screen (format nil "~C]0;title~C~C]0;title~C"
                                           (code-char 27)
                                           (code-char 7)
                                           (code-char 27)
                                           (code-char 27)))
      (terminal-screen-feed screen (format nil "~C[2;2Hq~C[1;1H~C[2;2H"
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)))
      (terminal-screen-resize screen 6 3)
      (expect (terminal-screen-width screen) :to-equal 6)
      (expect (terminal-screen-height screen) :to-equal 3)
      (expect (terminal-screen-text screen) :to-contain "q"))))
