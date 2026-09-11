(in-package #:loom/feature/window)


(defstruct window-leaf
  buffer
  x
  y
  width
  height
  (scroll-line 0)
  (scroll-column 0)
  (scroll-sub-row 0))

(defstruct window-split-node
  direction
  children)

(defstruct (window-tree (:constructor %make-window-tree))
  root
  selected
  width
  height)

(defgeneric make-window-tree (initial-buffer width height)
  (:documentation
   "Create and return a new window tree containing a single window that
displays INITIAL-BUFFER and occupies the entire WIDTH by HEIGHT area (in
terminal columns and rows). That single window is initially selected.")
  (:method (initial-buffer width height)
    (let ((leaf (make-window-leaf :buffer initial-buffer
                                   :x 0 :y 0 :width width :height height)))
      (%make-window-tree :root leaf :selected leaf
                         :width width :height height))))

(defgeneric window-tree-windows (tree)
  (:documentation
   "Return a list of every leaf window in TREE, in a stable, implementation-
defined order.")
  (:method (tree)
    (%window-collect-leaves (window-tree-root tree))))

(defgeneric window-tree-selected-window (tree)
  (:documentation "Return TREE's currently selected (focused) window.")
  (:method (tree)
    (window-tree-selected tree)))
