(in-package #:loom/test)

(describe
  "%window-delete-node"
  (it
    "handles leaf targets and direct split children"
    (let* ((leaf (loom/core/window-tree::make-window-leaf :buffer :leaf))
           (other (loom/core/window-tree::make-window-leaf :buffer :other))
           (node (loom/core/window-tree::make-window-split-node
                   :direction :vertical
                   :children (list leaf other))))
      (multiple-value-bind (result deleted)
          (loom/core/window-tree::%window-delete-node leaf other)
        (expect result :to-be leaf)
        (expect deleted :to-be-falsy))
      (multiple-value-bind (result deleted)
          (loom/core/window-tree::%window-delete-node node leaf)
        (expect result :to-be other)
        (expect deleted :to-be-truthy))
      (multiple-value-bind (result deleted)
          (loom/core/window-tree::%window-delete-node node other)
        (expect result :to-be leaf)
        (expect deleted :to-be-truthy))))

  (it
    "recurses through nested split nodes and reports missing targets"
    (let* ((left (loom/core/window-tree::make-window-leaf :buffer :left))
           (middle (loom/core/window-tree::make-window-leaf :buffer :middle))
           (right (loom/core/window-tree::make-window-leaf :buffer :right))
           (nested (loom/core/window-tree::make-window-split-node
                    :direction :horizontal
                    :children (list left middle)))
           (root (loom/core/window-tree::make-window-split-node
                  :direction :vertical
                  :children (list nested right))))
      (multiple-value-bind (result deleted)
          (loom/core/window-tree::%window-delete-node root left)
        (expect result :to-be root)
        (expect deleted :to-be-truthy)
        (expect (first (loom/core/window-tree::window-split-node-children root))
                :to-be middle)))
    (let* ((left (loom/core/window-tree::make-window-leaf :buffer :left))
           (middle (loom/core/window-tree::make-window-leaf :buffer :middle))
           (right (loom/core/window-tree::make-window-leaf :buffer :right))
           (nested (loom/core/window-tree::make-window-split-node
                    :direction :horizontal
                    :children (list middle right)))
           (root (loom/core/window-tree::make-window-split-node
                  :direction :vertical
                  :children (list left nested)))
           (missing (loom/core/window-tree::make-window-leaf :buffer :missing)))
      (multiple-value-bind (result deleted)
          (loom/core/window-tree::%window-delete-node root right)
        (expect result :to-be root)
        (expect deleted :to-be-truthy)
        (expect (second (loom/core/window-tree::window-split-node-children root))
                :to-be middle))
      (multiple-value-bind (result deleted)
          (loom/core/window-tree::%window-delete-node root missing)
        (expect result :to-be root)
        (expect deleted :to-be-falsy)))))
