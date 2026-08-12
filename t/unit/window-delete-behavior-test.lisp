;;;; t/unit/window-delete-behavior-test.lisp
;;;;
;;;; Window deletion behavior.
(in-package #:loom/test)

(describe
  "window-delete"
  (it
    "keeps the only window when deletion is requested"
    (let* ((tree (make-window-tree :scratch 10 10))
           (window (window-tree-selected-window tree)))
      (expect (window-delete tree window) :to-be window)
      (expect (window-tree-windows tree) :to-have-length 1)
      (expect (window-tree-selected-window tree) :to-be window)))

  (it
    "deletes a selected split and restores the root dimensions"
    (let* ((tree (make-window-tree :scratch 10 10))
           (original (window-tree-selected-window tree))
           (selected (window-split tree original :horizontal)))
      (expect (window-delete tree selected) :to-be original)
      (expect (window-tree-windows tree) :to-have-length 1)
      (expect (window-tree-selected-window tree) :to-be original)
      (expect (window-width original) :to-equal 10)
      (expect (window-height original) :to-equal 10)))

  (it
    "selects the first leaf after deleting a selected nested window"
    (let* ((tree (make-window-tree :scratch 20 10))
           (left (window-tree-selected-window tree))
           (right (window-split tree left :vertical))
           (bottom (window-split tree right :horizontal)))
      (expect (window-delete tree bottom) :to-be left)
      (expect (window-tree-windows tree) :to-have-length 2)
      (expect (window-tree-selected-window tree) :to-be left)))

  (it
    "keeps the current selection when deleting a different window"
    (let* ((tree (make-window-tree :scratch 10 10))
           (original (window-tree-selected-window tree))
           (selected (window-split tree original :vertical)))
      (expect (window-delete tree original) :to-be selected)
      (expect (window-tree-windows tree) :to-have-length 1)
      (expect (window-tree-selected-window tree) :to-be selected)))

  (it
    "ignores a missing target in a multi-window tree"
    (let* ((tree (make-window-tree :scratch 10 10))
           (original (window-tree-selected-window tree))
           (selected (window-split tree original :vertical))
           (missing (loom/feature/window::make-window-leaf :buffer :missing)))
      (expect (window-delete tree missing) :to-be selected)
      (expect (window-tree-windows tree) :to-have-length 2)
      (expect (window-tree-selected-window tree) :to-be selected))))
