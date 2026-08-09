;;;; packages/feature/window/src/domain-window.lisp
;;;;
;;;; Domain layer: the window-tree protocol. Pure split/select/resize layout
;;;; math over a tree of windows; it never touches an actual terminal or
;;;; renderer -- that wiring belongs to infrastructure/terminal-renderer.lisp
;;;; and, later, presentation/layout.lisp. Mutating window operations live in
;;;; domain-window-operations.lisp so this file can stay focused on the model
;;;; and its layout serialization.
;;;;
;;;; A window tree lays out one or more windows, each showing one buffer, over
;;;; the terminal area, supporting horizontal/vertical splits (C-x 2 / C-x 3),
;;;; window selection (C-x o), and per-window buffer switching (C-x b).
(in-package #:loom/feature/window)

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
  selected
  width
  height)

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

(defgeneric window-tree-layout (tree)
  (:documentation
   "Return TREE's nested layout description.

The description is a list of (:LEAF BUFFER SCROLL-LINE) or
(:SPLIT DIRECTION CHILD-1 CHILD-2) forms. It contains domain values only;
callers that persist it should replace BUFFER objects with stable identifiers.")
  (:method (tree)
    (labels ((describe-node (node)
               (if (window-leaf-p node)
                   (list :leaf
                         (window-leaf-buffer node)
                         (window-leaf-scroll-line node))
                   (list :split
                         (window-split-node-direction node)
                         (describe-node
                          (first (window-split-node-children node)))
                         (describe-node
                          (second (window-split-node-children node)))))))
      (describe-node (window-tree-root tree)))))

(defun %make-window-node-from-layout (layout)
  "Build a window node from WINDOW-TREE-LAYOUT's public description."
  (unless (listp layout)
    (error "make-window-tree-from-layout: malformed layout ~S" layout))
  (case (first layout)
    (:leaf
     (unless (= (length layout) 3)
       (error "make-window-tree-from-layout: malformed leaf ~S" layout))
     (make-window-leaf :buffer (second layout)
                       :scroll-line (max 0 (third layout))))
    (:split
     (unless (= (length layout) 4)
       (error "make-window-tree-from-layout: malformed split ~S" layout))
     (unless (member (second layout) '(:horizontal :vertical))
       (error "make-window-tree-from-layout: invalid direction ~S" (second layout)))
     (make-window-split-node
      :direction (second layout)
      :children (list (%make-window-node-from-layout (third layout))
                      (%make-window-node-from-layout (fourth layout)))))
    (otherwise
     (error "make-window-tree-from-layout: unknown node ~S" (first layout)))))

(defgeneric make-window-tree-from-layout (layout width height &key selected-index)
  (:documentation
   "Create a window tree from a nested layout description.

LAYOUT uses (:LEAF BUFFER SCROLL-LINE) and (:SPLIT DIRECTION CHILD-1
CHILD-2). SELECTED-INDEX selects a leaf in depth-first order and defaults to
zero. The input tree is fully built before the returned tree is laid out.")
  (:method (layout width height &key (selected-index 0))
    (let* ((root (%make-window-node-from-layout layout))
           (windows (%window-collect-leaves root)))
      (unless (and (integerp selected-index)
                   (<= 0 selected-index)
                   (< selected-index (length windows)))
        (error "make-window-tree-from-layout: selected index ~S out of range"
               selected-index))
      (let ((tree (%make-window-tree :root root
                                     :selected (nth selected-index windows)
                                     :width width
                                     :height height)))
        (%window-layout root 0 0 width height)
        tree))))

(defgeneric window-tree-selected-index (tree)
  (:documentation
   "Return the zero-based depth-first index of TREE's selected window.")
  (:method (tree)
    (or (position (window-tree-selected tree)
                  (window-tree-windows tree))
        (error "window-tree-selected-index: selected window is not in tree"))))

(defgeneric window-tree-select-index (tree index)
  (:documentation
   "Select the zero-based depth-first window INDEX in TREE and return TREE.")
  (:method (tree index)
    (let ((window (nth index (window-tree-windows tree))))
      (unless window
        (error "window-tree-select-index: index ~S out of range" index))
      (setf (window-tree-selected tree) window)
      tree)))
