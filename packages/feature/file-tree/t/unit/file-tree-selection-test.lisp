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

  (cl-weave:it-property
      "keeps generated selection movement inside the visible paths"
      ((size (cl-weave:gen-integer :min 1 :max 16))
       (direction-index (cl-weave:gen-integer :min 0 :max 1)))
    (let* ((paths (loop for index below size
                        collect (format nil "entry-~D" index)))
           (direction (if (zerop direction-index) :up :down))
           (selected (loom/feature/file-tree::%file-tree-next-selection
                      paths nil direction)))
      (expect selected :to-be (if (eq direction :down)
                                  (first paths)
                                  (car (last paths))))
      (expect (member selected paths :test #'equal) :to-be-truthy)))

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

(describe
  "file-tree viewport pure calculations (FR-301 through FR-305)"
  (cl-weave:it-each
      ((10 11 20 5 10)
       (10 13 20 5 10)
       (10 10 20 5 9)
       (10 14 20 5 11)
       (10 0 20 5 0)
       (10 19 20 5 15)
       (10 10 20 3 10)
       (10 12 20 3 10)
       (10 9 20 3 9)
       (10 13 20 3 11)
       (10 10 20 4 9)
       (10 12 20 4 10)
       (10 13 20 4 11)
       (10 10 20 2 10)
       (10 12 20 2 11)
       (10 10 20 1 10)
       (10 11 20 1 11)
       (10 19 20 0 10)
       (10 nil 20 5 10)
       (10 nil 7 5 2)
       (10 nil 0 5 0)
       (10 2 3 5 0)
       (0 0 20 5 0)
       (15 19 20 5 15))
      "follows top ~D index ~S count ~D height ~D"
      (top index count height expected)
    (expect (loom/feature/file-tree:file-tree-scroll-top-for-selection
             top index count height)
            :to-equal expected))

  (cl-weave:it-each
      ((0 20 5 -3 0)
       (2 20 5 -3 0)
       (10 20 5 -3 7)
       (10 20 5 3 13)
       (13 20 5 3 15)
       (15 20 5 3 15)
       (0 0 5 3 0)
       (0 2 5 3 0))
      "scrolls top ~D count ~D height ~D by ~D"
      (top count height delta expected)
    (expect (loom/feature/file-tree:file-tree-scroll-top-for-wheel
             top count height delta)
            :to-equal expected))

  (cl-weave:it-each
      ((10 20 5 10)
       (15 20 5 15)
       (18 20 5 15)
       (10 7 5 2)
       (10 3 5 0)
       (10 0 5 0)
       (10 7 0 7)
       (0 20 0 0))
      "clamps top ~D count ~D height ~D"
      (top count height expected)
    (expect (loom/feature/file-tree:file-tree-clamp-scroll-top top count height)
            :to-equal expected)))

(describe
  "bounded file-tree entries (FR-307)"
  (it
    "retains the old unbounded result and stops before opening excluded children"
    (let ((tree (make-file-tree "/root/"))
          (visited nil))
      (loom/feature/file-tree:file-tree-install-child-lister
       tree (lambda (path)
              (push path visited)
              (%fake-lister path)))
      (file-tree-toggle-expand tree "/root/sub/")
      (setf visited nil)
      (expect (file-tree-entries tree 0) :to-equal nil)
      (expect visited :to-equal nil)
      (expect (file-tree-entries tree 2)
              :to-equal '(("/root/a.txt" . 0) ("/root/sub/" . 0)))
      (expect visited :to-equal '("/root/"))
      (expect (file-tree-entries tree 3 :stop-after-path "/root/a.txt")
              :to-equal '(("/root/a.txt" . 0) ("/root/sub/" . 0)
                          ("/root/sub/b.txt" . 1)))
      (expect (file-tree-entries tree 2 :stop-after-path "/root/sub/b.txt"
                                    :trailing-rows 1)
              :to-equal '(("/root/a.txt" . 0) ("/root/sub/" . 0)
                          ("/root/sub/b.txt" . 1)
                          ("/root/sub/nested/" . 1)))
      (expect (file-tree-entries tree)
              :to-equal '(("/root/a.txt" . 0) ("/root/sub/" . 0)
                          ("/root/sub/b.txt" . 1)
                          ("/root/sub/nested/" . 1)))))

  (it
    "requests following only when selection changes or a directory opens"
    (let ((tree (make-file-tree "/root/")))
      (loom/feature/file-tree:file-tree-install-child-lister tree #'%fake-lister)
      (file-tree-move-selection tree :up)
      (expect (loom/feature/file-tree:file-tree-scroll-follow-needed-p tree)
              :to-be-truthy)
      (setf (loom/feature/file-tree:file-tree-scroll-follow-needed-p tree) nil)
      (file-tree-move-selection tree :down)
      (expect (loom/feature/file-tree:file-tree-scroll-follow-needed-p tree)
              :to-be-falsy)
      (file-tree-toggle-expand tree "/root/sub/")
      (expect (loom/feature/file-tree:file-tree-scroll-follow-needed-p tree)
              :to-be-truthy))))

(describe
  "file-tree resize with an unselected scrolled viewport"
  (it
    "preserves top while the new viewport fits and clamps after entries shrink"
    (let ((tree (make-file-tree "/root/"))
          (children (loop for index below 200
                          collect (cons (format nil "/root/file~3,'0D" index) :file))))
      (loom/feature/file-tree:file-tree-install-child-lister
       tree (lambda (path) (declare (ignore path)) children))
      (loom/feature/file-tree:file-tree-prepare-viewport tree 24 5)
      (dotimes (index 10)
        (loom/feature/file-tree:file-tree-prepare-viewport tree 24 5 :wheel-delta 3))
      (expect (loom/feature/file-tree:file-tree-scroll-top tree) :to-equal 30)
      (expect (loom/feature/file-tree:file-tree-entry-count tree) :to-equal 35)
      (expect (file-tree-selected-path tree) :to-be nil)
      (loom/feature/file-tree:file-tree-prepare-viewport tree 24 10)
      (expect (loom/feature/file-tree:file-tree-scroll-top tree) :to-equal 30)
      (setf children (subseq children 0 35))
      (loom/feature/file-tree:file-tree-prepare-viewport tree 24 10)
      (expect (loom/feature/file-tree:file-tree-scroll-top tree) :to-equal 25)
      (expect (file-tree-selected-path tree) :to-be nil))))

(describe
  "file-tree wheel movement while delayed entries arrive"
  (cl-weave:it-each
      ((3 21) (-3 15))
      "applies wheel delta ~D after following the shifted selection"
      (delta expected)
    (let ((tree (make-file-tree "/root/"))
          (children nil))
      (loom/feature/file-tree:file-tree-install-child-lister
       tree (lambda (path)
              (if (equal path "/root/")
                  '(("/root/a/" . :directory) ("/root/b" . :file)
                    ("/root/c" . :file) ("/root/d" . :file)
                    ("/root/e" . :file) ("/root/f" . :file))
                  children)))
      (loom/feature/file-tree:file-tree-prepare-viewport tree 24 5)
      (file-tree-move-selection tree :down)
      (file-tree-toggle-expand tree "/root/a/")
      (file-tree-move-selection tree :down)
      (loom/feature/file-tree:file-tree-prepare-viewport tree 24 5)
      (setf children (loop for index below 20
                           collect (cons (format nil "/root/a/child~D" index) :file)))
      (loom/feature/file-tree:file-tree-prepare-viewport tree 24 5 :wheel-delta delta)
      (expect (loom/feature/file-tree:file-tree-scroll-top tree) :to-equal expected)
      (expect (file-tree-selected-path tree) :to-equal "/root/b")
      (loom/feature/file-tree:file-tree-prepare-viewport tree 24 5)
      (expect (loom/feature/file-tree:file-tree-scroll-top tree) :to-equal expected))))

(describe
  "file-tree zero-height viewport"
  (it
    "does not traverse toward an offscreen selection when there are no rows"
    (let ((tree (make-file-tree "/root/"))
          (children nil)
          (visits nil))
      (loom/feature/file-tree:file-tree-install-child-lister
       tree (lambda (path)
              (push path visits)
              (if (equal path "/root/")
                  '(("/root/a/" . :directory) ("/root/b" . :file))
                  children)))
      (loom/feature/file-tree:file-tree-prepare-viewport tree 24 5)
      (file-tree-move-selection tree :down)
      (file-tree-toggle-expand tree "/root/a/")
      (file-tree-move-selection tree :down)
      (loom/feature/file-tree:file-tree-prepare-viewport tree 24 5)
      (setf children (loop for index below 20
                           collect (cons (format nil "/root/a/child~D" index) :file))
            visits nil)
      (loom/feature/file-tree:file-tree-prepare-viewport tree 24 0)
      (expect visits :to-equal nil)
      (expect (loom/feature/file-tree:file-tree-scroll-top tree) :to-equal 0)
      (expect (file-tree-selected-path tree) :to-equal "/root/b"))))



