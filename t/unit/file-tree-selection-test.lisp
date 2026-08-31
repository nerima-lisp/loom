;;;; t/unit/file-tree-selection-test.lisp
(in-package #:loom/test)

(defun %fake-lister (path)
  (cond
    ((equal path "/root/")
     '(("/root/a.txt" . :file) ("/root/sub/" . :directory)))
    ((equal path "/root/sub/")
     '(("/root/sub/b.txt" . :file) ("/root/sub/nested/" . :directory)))
    ((equal path "/root/sub/nested/")
     '(("/root/sub/nested/c.txt" . :file)))
    (t nil)))

(describe
  "file-tree-next-selection"
  (cl-weave:it-each
      ((:down nil ("a" "b") "a")
       (:up nil ("a" "b") "b")
       (:down "a" ("a" "b") "b")
       (:up "b" ("a" "b") "a")
       (:down "b" ("a" "b") "b")
       (:up "a" ("a" "b") "a"))
      "moves from ~S in ~S through ~S"
      (direction selected paths expected)
    (expect (loom/feature/file-tree::%file-tree-next-selection
             paths selected direction)
            :to-equal expected))

  (it
    "returns nil for an empty visible path list"
    (expect (loom/feature/file-tree::%file-tree-next-selection
             nil nil :down)
            :to-be nil))

  (it
    "rejects an unknown direction after a known selection"
    (signals error
      (loom/feature/file-tree::%file-tree-next-selection
       '("a") "a" :sideways)))

  (describe
    "stateful selection"
  (it
    "walks forward through visible entries and stops at the last one"
    (let ((tree (make-file-tree "/root/")))
      (loom/feature/file-tree:file-tree-install-child-lister tree #'%fake-lister)
      (expect (file-tree-move-selection tree :down) :to-equal "/root/a.txt")
      (expect (file-tree-move-selection tree :down) :to-equal "/root/sub/")
      (expect (file-tree-move-selection tree :down) :to-equal "/root/sub/")))

  (it
    "walks backward through visible entries and stops at the first one"
    (let ((tree (make-file-tree "/root/")))
      (loom/feature/file-tree:file-tree-install-child-lister tree #'%fake-lister)
      (file-tree-move-selection tree :down)
      (file-tree-move-selection tree :down)
      (expect (file-tree-move-selection tree :up) :to-equal "/root/a.txt")
      (expect (file-tree-move-selection tree :up) :to-equal "/root/a.txt")
      (expect (file-tree-selected-path tree) :to-equal "/root/a.txt")))

  (it
    "moving :up with no prior selection selects the last visible entry"
    (let ((tree (make-file-tree "/root/")))
      (loom/feature/file-tree:file-tree-install-child-lister tree #'%fake-lister)
      (expect (file-tree-move-selection tree :up) :to-equal "/root/sub/")))

  (it
    "signals an error for an unknown direction"
    (let ((tree (make-file-tree "/root/")))
      (loom/feature/file-tree:file-tree-install-child-lister tree #'%fake-lister)
      (file-tree-move-selection tree :down)
      (signals error (file-tree-move-selection tree :sideways))))

  (it
    "is a no-op on a tree with no visible entries"
    (let ((tree (make-file-tree "/nowhere/")))
      (loom/feature/file-tree:file-tree-install-child-lister tree #'%fake-lister)
      (expect (file-tree-move-selection tree :down) :to-be-falsy)))))
