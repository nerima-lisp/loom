;;;; t/unit/terminal-screen-cursor-test.lisp
;;;;
;;;; Terminal screen cursor movement and editing behavior.
(in-package #:loom/test)

(describe
  "terminal screen cursor behavior"
  (it "implements the cursor movement and editing CSI commands"
    (let ((screen (make-terminal-screen :width 8 :height 4)))
      (terminal-screen-feed screen "abcd")
      (terminal-screen-feed screen (format nil "~C[2D" (code-char 27)))
      (expect (terminal-screen-cursor-column screen) :to-equal 2)
      (terminal-screen-feed screen (format nil "~C[2C~C[2A"
                                           (code-char 27) (code-char 27)))
      (expect (terminal-screen-cursor-row screen) :to-equal 0)
      (expect (terminal-screen-cursor-column screen) :to-equal 4)
      (terminal-screen-feed screen (format nil "~C[2B~C[3D~C[2G"
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)))
      (expect (terminal-screen-cursor-row screen) :to-equal 2)
      (expect (terminal-screen-cursor-column screen) :to-equal 1)
      (terminal-screen-feed screen (format nil "~C[1;4H~C[1;2fZ"
                                           (code-char 27) (code-char 27)))
      (expect (terminal-screen-text screen) :to-equal "aZcd")
      (expect (terminal-screen-cursor-row screen) :to-equal 0)
      (expect (terminal-screen-cursor-column screen) :to-equal 2)
      (terminal-screen-feed screen (format nil "~C[2;3H~C[s~C[1;1H~C[u"
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)))
      (expect (terminal-screen-cursor-row screen) :to-equal 1)
      (expect (terminal-screen-cursor-column screen) :to-equal 2)
      (terminal-screen-feed screen (format nil "~C[2;1Hxy~C[1D~C[@~C[P"
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)))
      (expect (terminal-screen-text screen) :to-contain "xy")))

  (it "covers remaining cursor and screen control operations"
    (let ((screen (make-terminal-screen :width 6 :height 4)))
      (terminal-screen-feed screen "abcdef")
      (terminal-screen-feed screen (format nil "~C[2E~C[1F~C[2d~C[2a~C[1e"
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)))
      (expect (terminal-screen-cursor-row screen) :to-equal 2)
      (expect (terminal-screen-cursor-column screen) :to-equal 2)
      (terminal-screen-feed screen (format nil "~C[1L~C[1M~C[1S~C[1T"
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)))
      (terminal-screen-feed screen (format nil "~C7~C[1;1H~C8~C~C~C"
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 27)
                                           (code-char 13)
                                           (code-char 10)))
      (expect (and (<= 0 (terminal-screen-cursor-row screen))
                   (< (terminal-screen-cursor-row screen) 4))
              :to-be-truthy)
      (expect (and (<= 0 (terminal-screen-cursor-column screen))
                   (< (terminal-screen-cursor-column screen) 6))
              :to-be-truthy))))
