(in-package #:loom/feature/window)

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
