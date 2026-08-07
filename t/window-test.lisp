;;;; t/window-test.lisp
;;;;
;;;; Domain layer: the window-tree protocol (src/domain/window.lisp).
;;;; Exercises MAKE-WINDOW-TREE, WINDOW-SPLIT, WINDOW-SELECT-NEXT,
;;;; WINDOW-SET-BUFFER, and WINDOW-TREE-RESIZE purely in memory, with no
;;;; terminal or renderer involved.
(in-package #:loom/test)

(describe
  "make-window-tree"
  (it
    "creates a single selected window filling the whole area"
    (let* ((tree (make-window-tree :scratch 10 10))
           (window (window-tree-selected-window tree)))
      (expect (window-tree-windows tree) :to-have-length 1)
      (expect (first (window-tree-windows tree)) :to-be window)
      (expect (window-buffer window) :to-be :scratch)
      (expect (window-x window) :to-equal 0)
      (expect (window-y window) :to-equal 0)
      (expect (window-width window) :to-equal 10)
      (expect (window-height window) :to-equal 10))))

(describe
  "window-split"
  (it
    "splits :vertical side by side, giving the extra column to the first child"
    (let* ((tree (make-window-tree :scratch 10 10))
           (original (window-tree-selected-window tree))
           (new-window (window-split tree original :vertical)))
      (expect (window-tree-windows tree) :to-have-length 2)
      (expect (window-tree-selected-window tree) :to-be new-window)
      (expect (window-buffer new-window) :to-be :scratch)
      (expect (window-x original) :to-equal 0)
      (expect (window-width original) :to-equal 5)
      (expect (window-height original) :to-equal 10)
      (expect (window-x new-window) :to-equal 5)
      (expect (window-width new-window) :to-equal 5)
      (expect (window-height new-window) :to-equal 10)))

  (it
    "splits :horizontal top/bottom, giving the extra row to the first child"
    (let* ((tree (make-window-tree :scratch 8 7))
           (original (window-tree-selected-window tree))
           (new-window (window-split tree original :horizontal)))
      (expect (window-y original) :to-equal 0)
      (expect (window-height original) :to-equal 4)
      (expect (window-width original) :to-equal 8)
      (expect (window-y new-window) :to-equal 4)
      (expect (window-height new-window) :to-equal 3)
      (expect (window-width new-window) :to-equal 8)))

  (it
    "splits a second time, replacing a leaf nested under an existing split node"
    (let* ((tree (make-window-tree :scratch 20 10))
           (original (window-tree-selected-window tree))
           (second (window-split tree original :vertical))
           (third (window-split tree second :horizontal)))
      (expect (window-tree-windows tree) :to-have-length 3)
      (expect (window-tree-selected-window tree) :to-be third)
      (expect (window-buffer third) :to-be :scratch))))

(describe
  "window-select-next"
  (it
    "cycles through windows and wraps back to the first"
    (let* ((tree (make-window-tree :scratch 10 10))
           (first-window (window-tree-selected-window tree)))
      (window-split tree first-window :vertical)
      ;; selection is now the newly created second window
      (let ((back-to-first (window-select-next tree)))
        (expect back-to-first :to-be first-window)
        (expect (window-tree-selected-window tree) :to-be first-window)))))

(describe
  "window-set-buffer"
  (it
    "replaces the displayed buffer and leaves selection unchanged"
    (let* ((tree (make-window-tree :scratch 10 10))
           (window (window-tree-selected-window tree)))
      (expect (window-set-buffer window :other) :to-be window)
      (expect (window-buffer window) :to-be :other)
      (expect (window-tree-selected-window tree) :to-be window))))

(describe
  "window-tree-resize"
  (it
    "re-lays-out every window proportionally to the new size"
    (let* ((tree (make-window-tree :scratch 10 10))
           (left (window-tree-selected-window tree))
           (right (window-split tree left :vertical)))
      (expect (window-tree-resize tree 20 10) :to-be tree)
      (expect (window-x left) :to-equal 0)
      (expect (window-width left) :to-equal 10)
      (expect (window-x right) :to-equal 10)
      (expect (window-width right) :to-equal 10)
      (expect (window-height left) :to-equal 10)
      (expect (window-height right) :to-equal 10)))

  (it
    "recurses into a nested split node, not just a flat two-window split"
    (let* ((tree (make-window-tree :scratch 20 10))
           (left (window-tree-selected-window tree))
           (right (window-split tree left :vertical))
           (bottom (window-split tree right :horizontal)))
      (expect (window-tree-resize tree 20 10) :to-be tree)
      (expect (window-x left) :to-equal 0)
      (expect (window-width left) :to-equal 10)
      (expect (window-height left) :to-equal 10)
      (expect (window-x right) :to-equal 10)
      (expect (window-y right) :to-equal 0)
      (expect (window-width right) :to-equal 10)
      (expect (window-height right) :to-equal 5)
      (expect (window-x bottom) :to-equal 10)
      (expect (window-y bottom) :to-equal 5)
      (expect (window-width bottom) :to-equal 10)
      (expect (window-height bottom) :to-equal 5))))

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
