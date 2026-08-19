;;;; t/unit/window-delete-node-test.lisp
;;;;
;;;; Internal window deletion node behavior.
(in-package #:loom/test)

(describe
  "%window-delete-node"
  (it
    "handles leaf targets and direct split children"
    (let* ((leaf (loom/feature/window::make-window-leaf :buffer :leaf))
           (other (loom/feature/window::make-window-leaf :buffer :other))
           (node (loom/feature/window::make-window-split-node
                   :direction :vertical
                   :children (list leaf other))))
      (multiple-value-bind (result deleted)
          (loom/feature/window::%window-delete-node leaf other)
        (expect result :to-be leaf)
        (expect deleted :to-be-falsy))
      (multiple-value-bind (result deleted)
          (loom/feature/window::%window-delete-node node leaf)
        (expect result :to-be other)
        (expect deleted :to-be-truthy))
      (multiple-value-bind (result deleted)
          (loom/feature/window::%window-delete-node node other)
        (expect result :to-be leaf)
        (expect deleted :to-be-truthy))))

  (it
    "recurses through nested split nodes and reports missing targets"
    (let* ((left (loom/feature/window::make-window-leaf :buffer :left))
           (middle (loom/feature/window::make-window-leaf :buffer :middle))
           (right (loom/feature/window::make-window-leaf :buffer :right))
           (nested (loom/feature/window::make-window-split-node
                    :direction :horizontal
                    :children (list left middle)))
           (root (loom/feature/window::make-window-split-node
                  :direction :vertical
                  :children (list nested right))))
      (multiple-value-bind (result deleted)
          (loom/feature/window::%window-delete-node root left)
        (expect result :to-be root)
        (expect deleted :to-be-truthy)
        (expect (first (loom/feature/window::window-split-node-children root))
                :to-be middle)))
    (let* ((left (loom/feature/window::make-window-leaf :buffer :left))
           (middle (loom/feature/window::make-window-leaf :buffer :middle))
           (right (loom/feature/window::make-window-leaf :buffer :right))
           (nested (loom/feature/window::make-window-split-node
                    :direction :horizontal
                    :children (list middle right)))
           (root (loom/feature/window::make-window-split-node
                  :direction :vertical
                  :children (list left nested)))
           (missing (loom/feature/window::make-window-leaf :buffer :missing)))
      (multiple-value-bind (result deleted)
          (loom/feature/window::%window-delete-node root right)
        (expect result :to-be root)
        (expect deleted :to-be-truthy)
        (expect (second (loom/feature/window::window-split-node-children root))
                :to-be middle))
      (multiple-value-bind (result deleted)
          (loom/feature/window::%window-delete-node root missing)
        (expect result :to-be root)
        (expect deleted :to-be-falsy)))))
