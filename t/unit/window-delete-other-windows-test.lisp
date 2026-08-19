;;;; t/unit/window-delete-other-windows-test.lisp
;;;;
;;;; Collapse non-selected windows.
(in-package #:loom/test)

(describe
  "window-delete-other-windows"
  (it
    "collapses every other leaf while preserving the selected leaf"
    (let* ((tree (make-window-tree :scratch 20 10))
           (left (window-tree-selected-window tree))
           (right (window-split tree left :vertical))
           (bottom (window-split tree right :horizontal)))
      (expect (window-delete-other-windows tree bottom) :to-be bottom)
      (expect (window-tree-windows tree) :to-have-length 1)
      (expect (window-tree-selected-window tree) :to-be bottom)
      (expect (window-x bottom) :to-equal 0)
      (expect (window-y bottom) :to-equal 0)
      (expect (window-width bottom) :to-equal 20)
      (expect (window-height bottom) :to-equal 10))))
