;;;; packages/feature/window/src/domain-window-accessors.lisp
;;;;
;;;; Public leaf-window coordinate and size accessors shared by presentation
;;;; and application layers.
(in-package #:loom/feature/window)

(defun window-x (window)
  "Return WINDOW's left edge, in terminal columns, relative to its window
tree's origin."
  (window-leaf-x window))

(defun window-y (window)
  "Return WINDOW's top edge, in terminal rows, relative to its window
tree's origin."
  (window-leaf-y window))

(defun window-width (window)
  "Return WINDOW's width in terminal columns."
  (window-leaf-width window))

(defun window-height (window)
  "Return WINDOW's height in terminal rows."
  (window-leaf-height window))
