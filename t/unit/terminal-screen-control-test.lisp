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
      (expect (terminal-screen-text screen) :to-contain "q")))

  (it "preserves a partial CSI sequence across output chunks"
    (let ((screen (make-terminal-screen :width 6 :height 2)))
      (terminal-screen-feed screen (format nil "abc~C[" (code-char 27)))
      (terminal-screen-feed screen "2DXY")
      (expect (terminal-screen-text screen) :to-equal "aXY")))

  (it "keeps CSI cursor and line editing operations stateful"
    (let* ((escape (code-char 27))
           (csi (lambda (sequence)
                  (format nil "~C[~A" escape sequence)))
           (screen (make-terminal-screen :width 10 :height 5)))
      (terminal-screen-feed screen "abc")
      (terminal-screen-feed screen (funcall csi "2D"))
      (terminal-screen-feed screen (funcall csi "2C"))
      (terminal-screen-feed screen (funcall csi "2B"))
      (terminal-screen-feed screen (funcall csi "1A"))
      (terminal-screen-feed screen (funcall csi "1E"))
      (terminal-screen-feed screen (funcall csi "1F"))
      (terminal-screen-feed screen (funcall csi "5G"))
      (terminal-screen-feed screen (funcall csi "2`"))
      (terminal-screen-feed screen (funcall csi "3H"))
      (terminal-screen-feed screen (funcall csi "2;4f"))
      (terminal-screen-feed screen (funcall csi "3d"))
      (terminal-screen-feed screen (funcall csi "2a"))
      (terminal-screen-feed screen (funcall csi "1e"))
      (expect (loom/feature/terminal::terminal-screen-cursor-row screen) :to-be 3)
      (expect (loom/feature/terminal::terminal-screen-cursor-column screen) :to-be 5)
      (terminal-screen-feed screen (funcall csi "s"))
      (terminal-screen-feed screen (funcall csi "1;1H"))
      (terminal-screen-feed screen (funcall csi "u"))
      (expect (loom/feature/terminal::terminal-screen-cursor-row screen) :to-be 3)
      (expect (loom/feature/terminal::terminal-screen-cursor-column screen) :to-be 5)
      (let ((editing (make-terminal-screen :width 8 :height 4)))
        (terminal-screen-feed editing "aaaa")
        (terminal-screen-feed editing
          (format nil "~C~Cbbbb~C~Ccccc~C~Cdddd"
                  #\Return #\Newline
                  #\Return #\Newline
                  #\Return #\Newline))
        (terminal-screen-feed editing (funcall csi "1;1H"))
        (terminal-screen-feed editing (funcall csi "2@ZZ"))
        (expect (terminal-screen-text editing) :to-contain "ZZaaaa")
        (terminal-screen-feed editing (funcall csi "1;1H"))
        (terminal-screen-feed editing (funcall csi "2P"))
        (expect (terminal-screen-text editing) :to-contain "aaaa")
        (terminal-screen-feed editing (funcall csi "1;2H"))
        (terminal-screen-feed editing (funcall csi "2X"))
        (expect (terminal-screen-text editing) :to-contain "a  a")
        (terminal-screen-feed editing (funcall csi "2;1H"))
        (terminal-screen-feed editing (funcall csi "1L"))
        (terminal-screen-feed editing (funcall csi "1M"))
        (terminal-screen-feed editing (funcall csi "1;1H"))
        (terminal-screen-feed editing (funcall csi "1S"))
        (terminal-screen-feed editing (funcall csi "1T"))
        (expect (terminal-screen-text editing)
                :to-equal (format nil "~%bbbb~%cccc")))))

  (it "resizes the screen while preserving visible top-left content"
    (let ((screen (make-terminal-screen :width 6 :height 2)))
      (terminal-screen-feed screen
        (format nil "top~C~Cbottom" (code-char 13) (code-char 10)))
      (terminal-screen-resize screen 4 3)
      (expect (terminal-screen-text screen) :to-equal (format nil "top~%bott"))
      (expect (terminal-screen-width screen) :to-equal 4)
      (expect (terminal-screen-height screen) :to-equal 3))))
