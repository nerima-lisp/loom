(in-package #:loom/test)

(defmacro %with-file-tree-prompt ((dir path) command path-form &body body)
  `(host-kit:with-temporary-directory (,dir)
     (%with-minibuffer-state (minibuffer ""
                              (,path ,path-form))
       (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree ,dir))
       (funcall ,command)
       ,@body)))

(defmacro %with-selected-file-tree-entry ((dir path relative-path) &body body)
  `(host-kit:with-temporary-directory (,dir)
     (let ((,path (merge-pathnames ,relative-path ,dir)))
       (host-kit:write-file-string "content" ,path)
       (let ((*editor-state* (%fresh-editor-state "")))
         (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree ,dir))
         (loom/feature/file-tree:file-tree-select-next)
         ,@body))))

(defmacro %with-selected-file-tree-entry-prompt ((dir path relative-path) &body body)
  `(host-kit:with-temporary-directory (,dir)
     (let ((,path (merge-pathnames ,relative-path ,dir)))
       (host-kit:write-file-string "content" ,path)
       (%with-minibuffer-state (minibuffer "")
         (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree ,dir))
         (loom/feature/file-tree:file-tree-select-next)
         ,@body))))

(describe
  "file-tree commands"
  (it-each
      (("file-tree-create-file-command" loom/feature/file-tree:file-tree-create-file-command
        "created.txt")
       ("file-tree-create-directory-command"
        loom/feature/file-tree:file-tree-create-directory-command
        "created-dir/"))
      "~A creates the prompted path" (label command relative-path)
    (declare (ignore label))
    (%with-file-tree-prompt (dir path)
        command
        (merge-pathnames relative-path dir)
      (funcall (loom::%minibuffer-on-confirm minibuffer) path)
      (expect (host-kit:path-exists-p path) :to-be-truthy)))

  (it-each
      (("file-tree-create-file-command" loom/feature/file-tree:file-tree-create-file-command
        "cancelled.txt")
       ("file-tree-create-directory-command"
        loom/feature/file-tree:file-tree-create-directory-command
        "cancelled-dir/"))
      "~A leaves the filesystem unchanged when its prompt is cancelled"
      (label command relative-path)
    (declare (ignore label))
    (%with-file-tree-prompt (dir path)
        command
        (merge-pathnames relative-path dir)
      (funcall (loom::%minibuffer-on-cancel minibuffer))
      (expect (host-kit:path-exists-p path) :to-be-falsy)
      (expect (minibuffer-message-string minibuffer) :to-equal "Quit")))

  (it
    "file-tree-rename-command renames the selected entry"
    (%with-selected-file-tree-entry-prompt (dir old-path "old.txt")
      (let ((new-path (merge-pathnames "new.txt" dir)))
        (loom/feature/file-tree:file-tree-rename-command)
        (funcall (loom::%minibuffer-on-confirm minibuffer) new-path)
        (expect (host-kit:path-exists-p old-path) :to-be-falsy)
        (expect (host-kit:path-exists-p new-path) :to-be-truthy))))

  (it
    "file-tree-delete-command deletes the selected entry immediately"
    (%with-selected-file-tree-entry (dir path "doomed.txt")
      (loom/feature/file-tree:file-tree-delete-command)
      (expect (host-kit:path-exists-p path) :to-be-falsy))))
