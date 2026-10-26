(in-package #:loom/test)
(progn
  (defun %make-project-test-session (&optional buffers &key window-tree)
    (let ((session
            (loom/core/editor-session:make-editor-session
             '(:core/window-tree
               :feature/buffers
               :feature/workspace
               :feature/keyboard-macro
               :feature/search
               :feature/project)
             :initial-slices (list (cons :core/window-tree window-tree)))))
      (dolist (buffer (reverse buffers))
        (loom/feature/buffers:register-buffer session buffer))
      session)))
