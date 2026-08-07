;;;; src/domain/window.lisp
;;;;
;;;; Domain layer: the window-tree protocol. Pure split/select/resize layout
;;;; math over a tree of windows; it never touches an actual terminal or
;;;; renderer -- that wiring belongs to infrastructure/terminal-renderer.lisp
;;;; and, later, presentation/layout.lisp.
;;;;
;;;; A window tree lays out one or more windows, each showing one buffer, over
;;;; the terminal area, supporting horizontal/vertical splits (C-x 2 / C-x 3),
;;;; window selection (C-x o), and per-window buffer switching (C-x b).
(in-package #:loom)

;;; Representation: a window tree is a binary tree. Leaves are WINDOW-LEAF
;;; structs (an actual on-screen window: a buffer plus its computed x/y/width/
;;; height rect). Internal nodes are WINDOW-SPLIT-NODE structs (a :HORIZONTAL
;;; or :VERTICAL split with exactly two children, each itself a leaf or a
;;; nested split node). WINDOW-TREE holds the root of that binary tree plus a
;;; direct reference to the currently selected leaf (so selection reads don't
;;; require a tree walk) and the tree's overall width/height (so
;;; WINDOW-TREE-RESIZE has something to lay out against).
;;;
;;; None of these struct names collide with the protocol's generic function
;;; names above: leaf accessors are WINDOW-LEAF-*, not WINDOW-*, and
;;; WINDOW-TREE's own constructor is renamed (%MAKE-WINDOW-TREE) to avoid
;;; clashing with the MAKE-WINDOW-TREE generic function defined below.

(defstruct window-leaf
  buffer
  x
  y
  width
  height
  (scroll-line 0))

(defstruct window-split-node
  direction ; :HORIZONTAL or :VERTICAL
  children) ; a list of exactly two elements, each a WINDOW-LEAF or WINDOW-SPLIT-NODE

(defstruct (window-tree (:constructor %make-window-tree))
  root
  selected)

(defgeneric %window-collect-leaves (node)
  (:documentation
   "Return every WINDOW-LEAF under NODE, depth-first, first child before
second child. A method per node type -- rather than an ETYPECASE branching
on both -- since WINDOW-LEAF and WINDOW-SPLIT-NODE are the tree's only two
node shapes and this is the recursion's exhaustive base/recursive-case
split, not a true either/or decision within one case.")
  (:method ((node window-leaf)) (list node))
  (:method ((node window-split-node))
    (append (%window-collect-leaves (first (window-split-node-children node)))
            (%window-collect-leaves (second (window-split-node-children node))))))

(defun %window-split-rects (x y w h direction)
  "Divide the rect (X Y W H) into two child rects along DIRECTION, using
integer division and giving any extra row/column to the first child. Returns
(VALUES RECT1 RECT2), each a list (X Y WIDTH HEIGHT)."
  (ecase direction
    (:horizontal
     (let* ((half (floor h 2))
            (h1 (- h half))
            (h2 half))
       (values (list x y w h1) (list x (+ y h1) w h2))))
    (:vertical
     (let* ((half (floor w 2))
            (w1 (- w half))
            (w2 half))
       (values (list x y w1 h) (list (+ x w1) y w2 h))))))

(defun %window-replace (node target replacement)
  "Return NODE with the subtree EQ to TARGET replaced by REPLACEMENT,
mutating WINDOW-SPLIT-NODE children in place as it descends."
  (cond
    ((eq node target) replacement)
    ((window-split-node-p node)
     (setf (window-split-node-children node)
           (mapcar (lambda (child) (%window-replace child target replacement))
                   (window-split-node-children node)))
     node)
    (t node)))

(defgeneric %window-layout (node x y w h)
  (:documentation
   "Recompute every leaf rect under NODE to fill (X Y W H), recursing into
WINDOW-SPLIT-NODE children using the same proportional halving rule as
%WINDOW-SPLIT-RECTS. A method per node type, matching %WINDOW-COLLECT-LEAVES'
own base-case/recursive-case split across the tree's only two node shapes.")
  (:method ((node window-leaf) x y w h)
    (setf (window-leaf-x node) x
          (window-leaf-y node) y
          (window-leaf-width node) w
          (window-leaf-height node) h))
  (:method ((node window-split-node) x y w h)
    (multiple-value-bind (rect1 rect2)
        (%window-split-rects x y w h (window-split-node-direction node))
      (destructuring-bind (x1 y1 w1 h1) rect1
        (%window-layout (first (window-split-node-children node)) x1 y1 w1 h1))
      (destructuring-bind (x2 y2 w2 h2) rect2
        (%window-layout (second (window-split-node-children node)) x2 y2 w2 h2)))))

(defgeneric make-window-tree (initial-buffer width height)
  (:documentation
   "Create and return a new window tree containing a single window that
displays INITIAL-BUFFER and occupies the entire WIDTH by HEIGHT area (in
terminal columns and rows). That single window is initially selected.")
  (:method (initial-buffer width height)
    (let ((leaf (make-window-leaf :buffer initial-buffer
                                   :x 0 :y 0 :width width :height height)))
      (%make-window-tree :root leaf :selected leaf))))

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

(defgeneric window-split (tree window direction)
  (:documentation
   "Split WINDOW (a leaf window of TREE) into two windows along DIRECTION,
which is :HORIZONTAL (stacking the two windows top/bottom, i.e. C-x 2) or
:VERTICAL (placing the two windows side by side, i.e. C-x 3). Both resulting
windows initially display the same buffer WINDOW displayed. Selection moves
to the newly created window. Returns the newly created window.")
  (:method (tree window direction)
    (let ((buffer (window-leaf-buffer window)))
      (multiple-value-bind (rect1 rect2)
          (%window-split-rects (window-leaf-x window) (window-leaf-y window)
                                (window-leaf-width window) (window-leaf-height window)
                                direction)
        (destructuring-bind (x1 y1 w1 h1) rect1
          (destructuring-bind (x2 y2 w2 h2) rect2
            ;; WINDOW is mutated in place to become the first half, rather
            ;; than being discarded in favor of a fresh struct, so that any
            ;; reference to it a caller already holds stays valid -- and
            ;; correctly reflects the post-split size -- instead of becoming
            ;; silently stale. %WINDOW-REPLACE below still finds it by EQ,
            ;; which mutating its slots does not affect.
            (setf (window-leaf-x window) x1
                  (window-leaf-y window) y1
                  (window-leaf-width window) w1
                  (window-leaf-height window) h1)
            (let* ((leaf2 (make-window-leaf :buffer buffer :x x2 :y y2 :width w2 :height h2))
                   (split-node (make-window-split-node :direction direction
                                                        :children (list window leaf2))))
              (setf (window-tree-root tree)
                    (%window-replace (window-tree-root tree) window split-node))
              (setf (window-tree-selected tree) leaf2)
              leaf2)))))))

(defgeneric window-select-next (tree)
  (:documentation
   "Select the next window in TREE, cycling back to the first after the
last (C-x o). Returns the newly selected window.")
  (:method (tree)
    (let* ((windows (%window-collect-leaves (window-tree-root tree)))
           (n (length windows))
           (pos (position (window-tree-selected tree) windows)))
      (let ((next (nth (mod (1+ (or pos 0)) n) windows)))
        (setf (window-tree-selected tree) next)
        next))))

(defgeneric window-buffer (window)
  (:documentation "Return the buffer currently displayed in WINDOW.")
  (:method (window)
    (window-leaf-buffer window)))

(defgeneric window-set-buffer (window buffer)
  (:documentation
   "Display BUFFER in WINDOW (C-x b), replacing whatever buffer it
previously displayed. Returns WINDOW.")
  (:method (window buffer)
    (setf (window-leaf-buffer window) buffer
          (window-leaf-scroll-line window) 0)
    window))

(defgeneric window-scroll-line (window)
  (:documentation
   "Return WINDOW's zero-based first visible buffer line.")
  (:method (window)
    (window-leaf-scroll-line window)))

(defgeneric (setf window-scroll-line) (line window)
  (:documentation
   "Set WINDOW's zero-based first visible buffer LINE.")
  (:method (line window)
    (setf (window-leaf-scroll-line window) (max 0 line))))

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

(defgeneric window-tree-resize (tree width height)
  (:documentation
   "Resize TREE to the given WIDTH and HEIGHT (terminal columns and rows,
typically in response to a terminal resize event), re-laying-out every
window in TREE proportionally. Returns TREE.")
  (:method (tree width height)
    (%window-layout (window-tree-root tree) 0 0 width height)
    tree))
