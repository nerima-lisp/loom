;;;; packages/feature/window/src/domain-window.lisp
;;;;
;;;; Domain layer: the window-tree protocol. Pure split/select/resize layout
;;;; math over a tree of windows; it never touches an actual terminal or
;;;; renderer -- that wiring belongs to infrastructure/terminal-renderer.lisp
;;;; and, later, presentation/layout.lisp. Mutating window operations live in
;;;; domain-window-operations.lisp, while layout serialization/restoration
;;;; lives in domain-window-layout.lisp, so this file can stay focused on the
;;;; core model and layout math.
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
  (scroll-line 0)
  ;; The horizontal viewport offset, in screen cells rather than characters.
  ;; Unlike SCROLL-LINE this stays out of WINDOW-TREE-LAYOUT: the layout
  ;; description is what sessions persist, while viewport offsets are runtime
  ;; state and are deliberately not part of the persisted layout.
  (scroll-column 0)
  ;; Which wrapped segment of SCROLL-LINE sits on the window's first row. Only
  ;; a wrapping buffer ever leaves this at anything but 0, and like
  ;; SCROLL-COLUMN it is transient viewport state rather than layout.
  (scroll-sub-row 0))

(defstruct window-split-node
  direction ; :HORIZONTAL or :VERTICAL
  children) ; a list of exactly two elements, each a WINDOW-LEAF or WINDOW-SPLIT-NODE

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
