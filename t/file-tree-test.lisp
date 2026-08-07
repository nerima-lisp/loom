;;;; t/file-tree-test.lisp
;;;;
;;;; Domain layer: the pure file-tree state generics (src/domain/file-tree.lisp)
;;;; -- visibility, selection, expand/collapse, and FILE-TREE-ENTRIES'
;;;; lazy depth-first flattening. No real filesystem access: each test that
;;;; needs children installs a fake CHILD-LISTER via the internal
;;;; LOOM::FILE-TREE-CHILD-LISTER seam that infrastructure/filesystem.lisp is
;;;; expected to override in the real editor.
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
  "make-file-tree"
  (it
    "starts not visible with no entries under the default child-lister"
    (let ((tree (make-file-tree "/root/")))
      (expect (file-tree-visible-p tree) :to-be-falsy)
      (expect (file-tree-entries tree) :to-equal nil)
      (expect (file-tree-selected-path tree) :to-be-falsy))))

(describe
  "file-tree-visible-p and file-tree-toggle"
  (it
    "flips visibility and returns the new state"
    (let ((tree (make-file-tree "/root/")))
      (expect (file-tree-toggle tree) :to-be-truthy)
      (expect (file-tree-visible-p tree) :to-be-truthy)
      (expect (file-tree-toggle tree) :to-be-falsy)
      (expect (file-tree-visible-p tree) :to-be-falsy))))

(describe
  "file-tree-entries and file-tree-toggle-expand"
  (it
    "always shows the root's direct children at depth 0"
    (let ((tree (make-file-tree "/root/")))
      (setf (loom::file-tree-child-lister tree) #'%fake-lister)
      (expect (file-tree-entries tree)
              :to-equal
              '(("/root/a.txt" . 0) ("/root/sub/" . 0)))))

  (it
    "reports the public kind of each reachable entry"
    (let ((tree (make-file-tree "/root/")))
      (setf (loom::file-tree-child-lister tree) #'%fake-lister)
      (expect (file-tree-entry-kind tree "/root/a.txt") :to-equal :file)
      (expect (file-tree-entry-kind tree "/root/sub/") :to-equal :directory)
      (expect (file-tree-entry-kind tree "/does/not/exist") :to-be nil)))

  (it
    "expands a directory to reveal its children one level deeper, lazily"
    (let ((tree (make-file-tree "/root/")))
      (setf (loom::file-tree-child-lister tree) #'%fake-lister)
      (expect (file-tree-toggle-expand tree "/root/sub/") :to-be-truthy)
      (expect (file-tree-entries tree)
              :to-equal
              '(("/root/a.txt" . 0)
                ("/root/sub/" . 0)
                ("/root/sub/b.txt" . 1)
                ("/root/sub/nested/" . 1)))))

  (it
    "collapses back on a second toggle"
    (let ((tree (make-file-tree "/root/")))
      (setf (loom::file-tree-child-lister tree) #'%fake-lister)
      (file-tree-toggle-expand tree "/root/sub/")
      (expect (file-tree-toggle-expand tree "/root/sub/") :to-be-falsy)
      (expect (file-tree-entries tree)
              :to-equal
              '(("/root/a.txt" . 0) ("/root/sub/" . 0)))))

  (it
    "signals an error when toggling a path that is a file, not a directory"
    (let ((tree (make-file-tree "/root/")))
      (setf (loom::file-tree-child-lister tree) #'%fake-lister)
      (signals error (file-tree-toggle-expand tree "/root/a.txt"))))

  (it
    "signals an error when toggling a path not present in the tree"
    (let ((tree (make-file-tree "/root/")))
      (setf (loom::file-tree-child-lister tree) #'%fake-lister)
      (signals error (file-tree-toggle-expand tree "/does/not/exist"))))

  (it
    "finds and expands a directory nested inside an already-expanded directory"
    (let ((tree (make-file-tree "/root/")))
      (setf (loom::file-tree-child-lister tree) #'%fake-lister)
      (file-tree-toggle-expand tree "/root/sub/")
      (expect (file-tree-toggle-expand tree "/root/sub/nested/") :to-be-truthy)
      (expect (file-tree-entries tree)
              :to-equal
              '(("/root/a.txt" . 0) ("/root/sub/" . 0)
                ("/root/sub/b.txt" . 1) ("/root/sub/nested/" . 1)
                ("/root/sub/nested/c.txt" . 2))))))

(describe
  "file-tree-move-selection"
  (it
    "walks forward through visible entries and stops at the last one"
    (let ((tree (make-file-tree "/root/")))
      (setf (loom::file-tree-child-lister tree) #'%fake-lister)
      (expect (file-tree-move-selection tree :down) :to-equal "/root/a.txt")
      (expect (file-tree-move-selection tree :down) :to-equal "/root/sub/")
      ;; no-op at the end of the visible entry list
      (expect (file-tree-move-selection tree :down) :to-equal "/root/sub/")))

  (it
    "walks backward through visible entries and stops at the first one"
    (let ((tree (make-file-tree "/root/")))
      (setf (loom::file-tree-child-lister tree) #'%fake-lister)
      (file-tree-move-selection tree :down)
      (file-tree-move-selection tree :down)
      (expect (file-tree-move-selection tree :up) :to-equal "/root/a.txt")
      ;; no-op at the start of the visible entry list
      (expect (file-tree-move-selection tree :up) :to-equal "/root/a.txt")
      (expect (file-tree-selected-path tree) :to-equal "/root/a.txt")))

  (it
    "moving :up with no prior selection selects the last visible entry"
    (let ((tree (make-file-tree "/root/")))
      (setf (loom::file-tree-child-lister tree) #'%fake-lister)
      (expect (file-tree-move-selection tree :up) :to-equal "/root/sub/")))

  (it
    "signals an error for an unknown direction"
    (let ((tree (make-file-tree "/root/")))
      (setf (loom::file-tree-child-lister tree) #'%fake-lister)
      (file-tree-move-selection tree :down)
      (signals error (file-tree-move-selection tree :sideways))))

  (it
    "is a no-op on a tree with no visible entries"
    ;; %FAKE-LISTER's (T NIL) clause gives this root zero children.
    (let ((tree (make-file-tree "/nowhere/")))
      (setf (loom::file-tree-child-lister tree) #'%fake-lister)
      (expect (file-tree-move-selection tree :down) :to-be-falsy))))
