(in-package #:loom/test)

(defmacro %with-selected-file-tree-entry ((dir relative-path) &body body)
  `(host-kit:with-temporary-directory (,dir)
     (let ((path (merge-pathnames ,relative-path ,dir)))
       (let ((*editor-state* (%fresh-editor-state "")))
         (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree ,dir))
         (loom/feature/file-tree:file-tree-select-next)
         ,@body))))

(describe
  "file-tree commands"
  (it
    "toggle-file-tree flips the sidebar's visibility"
    (let ((*editor-state* (%fresh-editor-state "")))
      (setf (editor-state-file-tree *editor-state*) (make-file-tree "/root/"))
      (expect (file-tree-visible-p (editor-state-file-tree *editor-state*)) :to-be-falsy)
      (loom/feature/file-tree:toggle-file-tree)
      (expect (file-tree-visible-p (editor-state-file-tree *editor-state*)) :to-be-truthy)))

  (it
    "invalidates the file-tree runtime cache after a path mutation"
    (let ((runtime
            (loom/feature/file-tree:make-loom-concurrent-runtime
             :directory-lister
             (lambda (path)
               (declare (ignore path))
               nil))))
      (unwind-protect
           (let* ((*editor-state* (%fresh-editor-state ""))
                  (path "/root/child/file.txt")
                  (parent "/root/child/")
                  (entries '(("/root/child/file.txt" . :file))))
             (setf (editor-state-concurrent-runtime *editor-state*) runtime)
             (loom/feature/file-tree:loom-concurrent-runtime-prime-directory runtime parent entries)
             (loom/feature/file-tree:loom-concurrent-runtime-prime-directory runtime path entries)
             (loom/feature/file-tree::%invalidate-file-tree-path path)
             (multiple-value-bind (cached present-p)
                 (loom/feature/file-tree:loom-concurrent-runtime-directory-entries runtime parent)
               (declare (ignore cached))
               (expect present-p :to-be nil))
             (multiple-value-bind (cached present-p)
                 (loom/feature/file-tree:loom-concurrent-runtime-directory-entries runtime path)
               (declare (ignore cached))
               (expect present-p :to-be nil)))
        (ignore-errors
          (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime)))))

  (it
    "file-tree-select-next and file-tree-select-previous move the selection"
    (host-kit:with-temporary-directory (dir)
      (host-kit:write-file-string "a" (merge-pathnames "a.txt" dir))
      (host-kit:write-file-string "b" (merge-pathnames "b.txt" dir))
      (let ((*editor-state* (%fresh-editor-state "")))
        (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree dir))
        (let ((tree (editor-state-file-tree *editor-state*)))
          (loom/feature/file-tree:file-tree-select-next)
          (let ((first (file-tree-selected-path tree)))
            (loom/feature/file-tree:file-tree-select-next)
            (expect (equal (file-tree-selected-path tree) first) :to-be nil)
            (loom/feature/file-tree:file-tree-select-previous)
            (expect (file-tree-selected-path tree) :to-equal first))))))

  (it
    "file-tree-open-selected opens a file entry as a buffer in the selected window"
    (%with-selected-file-tree-entry (dir "note.txt")
      (host-kit:write-file-string "hello" path)
      (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree dir))
      (loom/feature/file-tree:file-tree-select-next)
      (loom/feature/file-tree:file-tree-open-selected)
      (expect (buffer-name (%selected-test-buffer)) :to-equal "note.txt")
      (expect (member (%selected-test-buffer)
                      (editor-state-buffers *editor-state*))
              :to-be-truthy)))

  (it
    "file-tree-open-selected does nothing when no entry is selected"
    (let ((*editor-state* (%fresh-editor-state "")))
      (setf (editor-state-file-tree *editor-state*) (make-file-tree "/root/"))
      (expect (loom/feature/file-tree:file-tree-open-selected) :to-be nil)))

  (it
    "file-tree-open-selected reports an entry that disappeared"
    (let ((*editor-state* (%fresh-editor-state ""))
          (tree (make-file-tree "/root/")))
      (setf (editor-state-file-tree *editor-state*) tree
            (loom/feature/file-tree::file-tree-selection tree) "/root/vanished.txt")
      (with-replaced-function
          (file-tree-entry-kind
           (lambda (tree path)
             (declare (ignore tree path))
             nil))
        (signals error (loom/feature/file-tree:file-tree-open-selected)))))

  (it
    "file-tree-open-selected expands a directory entry instead of opening it"
    (%with-selected-file-tree-entry (dir "sub/")
      (ensure-directories-exist path)
      (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree dir))
      (let ((tree (editor-state-file-tree *editor-state*)))
        (loom/feature/file-tree:file-tree-select-next)
        (loom/feature/file-tree:file-tree-open-selected)
        (expect (gethash (file-tree-selected-path tree) (loom/feature/file-tree::file-tree-expanded tree))
                :to-be-truthy)))))
