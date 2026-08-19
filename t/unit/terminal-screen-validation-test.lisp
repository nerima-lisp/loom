;;;; t/unit/terminal-screen-validation-test.lisp
;;;;
;;;; Terminal screen dimension validation behavior.
(in-package #:loom/test)

(describe
  "terminal screen validation"
  (it "rejects non-positive terminal dimensions"
    (signals error (make-terminal-screen :width 0 :height 2))
    (signals error (make-terminal-screen :width 2 :height 0))
    (let ((screen (make-terminal-screen :width 2 :height 2)))
      (signals error (terminal-screen-resize screen 0 2))
      (signals error (terminal-screen-resize screen 2 0))
      (expect (terminal-screen-width screen) :to-equal 2)
      (expect (terminal-screen-height screen) :to-equal 2))))
