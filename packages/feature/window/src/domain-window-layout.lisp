;;;; packages/feature/window/src/domain-window-layout.lisp
;;;;
;;;; Window-tree layout description and restoration. This keeps the public
;;;; persistence-facing layout protocol separate from the core window model in
;;;; domain-window.lisp and the mutating operations in domain-window-operations.lisp.
(in-package #:loom/feature/window)

(defun window-tree-layout (tree)
  "Return TREE's nested layout description.

The description is a list of (:LEAF BUFFER SCROLL-LINE) or
(:SPLIT DIRECTION CHILD-1 CHILD-2) forms. It contains domain values only;
callers that persist it should replace BUFFER objects with stable identifiers."
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
    (describe-node (window-tree-root tree))))

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
       (error "make-window-tree-from-layout: invalid direction ~S"
              (second layout)))
     (make-window-split-node
      :direction (second layout)
      :children (list (%make-window-node-from-layout (third layout))
                      (%make-window-node-from-layout (fourth layout)))))
    (otherwise
     (error "make-window-tree-from-layout: unknown node ~S" (first layout)))))

(defun make-window-tree-from-layout (layout width height &key (selected-index 0))
  "Create a window tree from a nested layout description.

LAYOUT uses (:LEAF BUFFER SCROLL-LINE) and (:SPLIT DIRECTION CHILD-1
CHILD-2). SELECTED-INDEX selects a leaf in depth-first order and defaults to
zero. The input tree is fully built before the returned tree is laid out."
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
      tree)))

(defun window-tree-selected-index (tree)
  "Return the zero-based depth-first index of TREE's selected window."
  (or (position (window-tree-selected tree)
                (window-tree-windows tree))
      (error "window-tree-selected-index: selected window is not in tree")))

(defun window-tree-select-index (tree index)
  "Select the zero-based depth-first window INDEX in TREE and return TREE."
  (let ((window (nth index (window-tree-windows tree))))
    (unless window
      (error "window-tree-select-index: index ~S out of range" index))
    (setf (window-tree-selected tree) window)
    tree))
