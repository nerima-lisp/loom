(in-package #:loom/test)

(defmacro %with-file-tree-cancelled-prompt ((dir path) command path-form &body body)
  `(host-kit:with-temporary-directory (,dir)
     (%with-minibuffer-state (minibuffer "")
       (let ((,path ,path-form))
         (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree ,dir))
         (funcall ,command)
         (%type-string minibuffer (namestring ,path))
         (minibuffer-handle-key minibuffer (%special-key :control-g))
         (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")
         ,@body))))

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
  "prompt cancellation"
  (it-each
      (("find-file" loom/feature/file-tree:find-file)
       ("save-buffer on a path-less buffer" loom/feature/file-tree:save-buffer)
       ("write-file" loom/feature/file-tree:write-file)
       ("search-forward" loom/feature/search::search-forward)
       ("search-backward" loom/feature/search::search-backward)
       ("replace-string" loom/feature/search::replace-string)
       ("goto-line" loom::goto-line)
       ("switch-workspace" loom/feature/workspace:switch-workspace)
       ("switch-to-buffer" loom/feature/window:switch-to-buffer)
       ("execute-extended-command" loom::execute-extended-command))
      "~A reports Quit on C-g" (label command)
    (declare (ignore label))
    (%with-minibuffer-state (minibuffer "hi")
      (funcall command)
      (expect (minibuffer-active-p minibuffer) :to-be-truthy)
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (minibuffer-active-p minibuffer) :to-be-falsy)
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")))

  (it
    "cancelling replace-string's second prompt quits without replacing"
    (%with-minibuffer-state (minibuffer "alpha alpha")
      (loom/feature/search::replace-string)
      (%type-string minibuffer "alpha")
      (minibuffer-handle-key minibuffer (%special-key :enter))
      (%expect-minibuffer-prompt minibuffer (%replace-with-prompt-string))
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")
      (expect (buffer-text (%selected-test-buffer)) :to-equal "alpha alpha")))

  (it-each
      (("file-tree-create-file-command" loom/feature/file-tree:file-tree-create-file-command
        "unwanted.txt")
       ("file-tree-create-directory-command"
        loom/feature/file-tree:file-tree-create-directory-command
        "unwanted-dir/"))
      "cancelling ~A creates nothing" (label command relative-path)
    (declare (ignore label))
    (%with-file-tree-cancelled-prompt (dir path)
        command
        (merge-pathnames relative-path dir)
      (expect (host-kit:path-exists-p path) :to-be-falsy)))

  (it
    "cancelling file-tree-rename-command leaves the selected entry unchanged"
    (%with-selected-file-tree-entry-prompt (dir old-path "old.txt")
      (let ((new-path (merge-pathnames "new.txt" dir)))
        (loom/feature/file-tree:file-tree-rename-command)
        (%type-string minibuffer (namestring new-path))
        (minibuffer-handle-key minibuffer (%special-key :control-g))
        (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")
        (expect (host-kit:path-exists-p old-path) :to-be-truthy)
        (expect (host-kit:path-exists-p new-path) :to-be-falsy))))

  (it
    "cancelling save-buffers-kill-terminal's quit prompt reports Quit"
    (%with-minibuffer-state (minibuffer "")
      (buffer-insert-string (%selected-test-buffer) "unsaved")
      (loom::save-buffers-kill-terminal)
      (expect (minibuffer-active-p minibuffer) :to-be-truthy)
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit"))))
