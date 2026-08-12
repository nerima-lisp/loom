;;;; t/unit/terminal-screen-basic-test.lisp
;;;;
;;;; Terminal screen baseline drawing behavior.
(in-package #:loom/test)

(describe
  "terminal screen basic behavior"
  (it "applies cursor addressing, erasure, and alternate-screen output"
    (let ((screen (make-terminal-screen :width 12 :height 4)))
      (terminal-screen-feed
       screen
       (format nil "one~C~Ctwo" (code-char 13) (code-char 10)))
      (expect (terminal-screen-text screen) :to-equal (format nil "one~%two"))
      (terminal-screen-feed
       screen
       (format nil "~C[1;1HTOP~C[2K~C[2;1Hbottom"
               (code-char 27) (code-char 27) (code-char 27)))
      (expect (terminal-screen-text screen) :to-equal (format nil "~%bottom"))
      (terminal-screen-feed
       screen
       (format nil "~C[?1049h~C[1;1HALT~C[?1049l"
               (code-char 27) (code-char 27) (code-char 27)))
      (expect (terminal-screen-text screen) :to-equal (format nil "~%bottom"))
      (let ((default-screen (make-terminal-screen :width 12 :height 2)))
        (terminal-screen-feed default-screen "abcdef")
        (terminal-screen-feed
         default-screen
         (format nil "~C[3G~C[K" (code-char 27) (code-char 27)))
        (expect (terminal-screen-text default-screen) :to-equal "ab")))))
