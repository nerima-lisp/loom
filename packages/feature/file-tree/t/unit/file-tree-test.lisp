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

(defun %cyclic-fake-lister (path)
  (cond
    ((equal path "/root/") '(("/root/loop/" . :directory)))
    ((equal path "/root/loop/") '(("/root/" . :directory)))
    (t nil)))

(defun %shared-fake-lister (path)
  (cond
    ((equal path "/root/")
     '(("/root/a/" . :directory) ("/root/b/" . :directory)))
    ((member path '("/root/a/" "/root/b/") :test #'equal)
     '(("/root/shared/" . :directory)))
    ((equal path "/root/shared/")
     '(("/root/shared.txt" . :file)))
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
      (loom/feature/file-tree:file-tree-install-child-lister tree #'%fake-lister)
      (expect (file-tree-entries tree)
              :to-equal
              '(("/root/a.txt" . 0) ("/root/sub/" . 0)))))

  (it
    "reports the public kind of each reachable entry"
    (let ((tree (make-file-tree "/root/")))
      (loom/feature/file-tree:file-tree-install-child-lister tree #'%fake-lister)
      (expect (file-tree-entry-kind tree "/root/a.txt") :to-equal :file)
      (expect (file-tree-entry-kind tree "/root/sub/") :to-equal :directory)
      (expect (file-tree-entry-kind tree "/does/not/exist") :to-be nil)))

  (it
    "expands a directory to reveal its children one level deeper, lazily"
    (let ((tree (make-file-tree "/root/")))
      (loom/feature/file-tree:file-tree-install-child-lister tree #'%fake-lister)
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
      (loom/feature/file-tree:file-tree-install-child-lister tree #'%fake-lister)
      (file-tree-toggle-expand tree "/root/sub/")
      (expect (file-tree-toggle-expand tree "/root/sub/") :to-be-falsy)
      (expect (file-tree-entries tree)
              :to-equal
              '(("/root/a.txt" . 0) ("/root/sub/" . 0)))))

  (it
    "signals an error when toggling a path that is a file, not a directory"
    (let ((tree (make-file-tree "/root/")))
      (loom/feature/file-tree:file-tree-install-child-lister tree #'%fake-lister)
      (signals error (file-tree-toggle-expand tree "/root/a.txt"))))

  (it
    "signals an error when toggling a path not present in the tree"
    (let ((tree (make-file-tree "/root/")))
      (loom/feature/file-tree:file-tree-install-child-lister tree #'%fake-lister)
      (signals error (file-tree-toggle-expand tree "/does/not/exist"))))

  (it
    "finds and expands a directory nested inside an already-expanded directory"
    (let ((tree (make-file-tree "/root/")))
      (loom/feature/file-tree:file-tree-install-child-lister tree #'%fake-lister)
      (file-tree-toggle-expand tree "/root/sub/")
      (expect (file-tree-toggle-expand tree "/root/sub/nested/") :to-be-truthy)
      (expect (file-tree-entries tree)
              :to-equal
              '(("/root/a.txt" . 0) ("/root/sub/" . 0)
                ("/root/sub/b.txt" . 1) ("/root/sub/nested/" . 1)
                ("/root/sub/nested/c.txt" . 2))))))
(describe
  "file-tree directory pathname restoration"
  (it
    "matches a restored directory pathname to its listed path"
    (host-kit:with-temporary-directory (root)
      (let* ((nested-path (merge-pathnames "nested/" root)))
        (host-kit:create-directory nested-path)
        (let* ((resolved-directory (truename nested-path))
               (listed-directory (merge-pathnames "nested" root))
               (restored-directory
                 (make-pathname :directory (pathname-directory resolved-directory)
                                :defaults resolved-directory))
               (nested-file (merge-pathnames "child.txt" restored-directory))
               (tree (make-file-tree root)))
          (host-kit:write-file-string "child" nested-file)
          (loom/feature/file-tree:file-tree-install-child-lister
           tree (function loom/feature/file-tree:loom-fs-list-directory))
          (expect (pathname-name listed-directory) :to-equal "nested")
          (expect (pathname-name restored-directory) :to-be nil)
          (expect (file-tree-entry-kind tree restored-directory)
                  :to-equal :directory)
          (expect (file-tree-toggle-expand tree restored-directory)
                  :to-be-truthy)
          (expect (find nested-file (file-tree-entries tree)
                        :key (function car) :test (function equal))
                  :to-be-truthy)
          (expect (file-tree-toggle-expand tree listed-directory)
                  :to-be-falsy)
          (expect (find nested-file (file-tree-entries tree)
                        :key (function car) :test (function equal))
                  :to-be nil)
          (expect (rest (file-tree-prefetch-paths tree)) :to-equal nil))))))

(describe
  "file-tree cycle handling"
  (it
    "terminates when expanded directories contain a cycle"
    (let ((tree (make-file-tree "/root/")))
      (loom/feature/file-tree:file-tree-install-child-lister
       tree #'%cyclic-fake-lister)
      (file-tree-toggle-expand tree "/root/loop/")
      (expect (file-tree-entries tree)
              :to-equal '(("/root/loop/" . 0) ("/root/" . 1)))
      (expect (file-tree-entry-kind tree "/root/loop/")
              :to-equal :directory))))

(describe
  "file-tree shared path handling"
  (it
    "retains a shared directory under each expanded display path"
    (let ((tree (make-file-tree "/root/")))
      (loom/feature/file-tree:file-tree-install-child-lister
       tree #'%shared-fake-lister)
      (file-tree-toggle-expand tree "/root/a/")
      (file-tree-toggle-expand tree "/root/b/")
      (file-tree-toggle-expand tree "/root/shared/")
      (expect (file-tree-entries tree)
              :to-equal
              '(("/root/a/" . 0)
                ("/root/shared/" . 1)
                ("/root/shared.txt" . 2)
                ("/root/b/" . 0)
                ("/root/shared/" . 1)
                ("/root/shared.txt" . 2))))))

(describe
  "file-tree-prefetch-paths"
  (it
    "returns the root and currently expanded directories"
    (let ((tree (make-file-tree "/root/")))
      (loom/feature/file-tree:file-tree-install-child-lister tree #'%fake-lister)
      (file-tree-toggle-expand tree "/root/sub/")
      (let ((paths (file-tree-prefetch-paths tree)))
        (expect (first paths) :to-equal "/root/")
        (expect (member "/root/sub/" paths :test #'equal) :to-be-truthy)))))
