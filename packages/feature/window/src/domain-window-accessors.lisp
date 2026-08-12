;;;; packages/feature/window/src/domain-window-accessors.lisp
;;;;
;;;; Public leaf-window coordinate and size accessors shared by presentation
;;;; and application layers.
(in-package #:loom/feature/window)

(defgeneric window-x (window)
  (:documentation
   "Return WINDOW's left edge, in terminal columns, relative to its window
tree's origin.")
  (:method (window)
    (window-leaf-x window)))

(defgeneric window-y (window)
  (:documentation
   "Return WINDOW's top edge, in terminal rows, relative to its window
tree's origin.")
  (:method (window)
    (window-leaf-y window)))

(defgeneric window-width (window)
  (:documentation "Return WINDOW's width in terminal columns.")
  (:method (window)
    (window-leaf-width window)))

(defgeneric window-height (window)
  (:documentation "Return WINDOW's height in terminal rows.")
  (:method (window)
    (window-leaf-height window)))
