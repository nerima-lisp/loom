;;;; t/integration/project-missing-root-test.lisp
;;;;
;;;; Real temporary-directory coverage for missing project roots.
(in-package #:loom/test)

(describe
  "project filesystem integration without a root"
  (it
    "reports missing project roots through every project command"
    (host-kit:with-temporary-directory (directory)
      (let* ((path (merge-pathnames "plain.txt" directory))
             (buffer (make-buffer :name "plain.txt"
                                  :path path
                                  :initial-content "plain"))
             (*editor-state*
               (make-editor-state
                :window-tree (make-window-tree buffer 80 24)
                :minibuffer (make-minibuffer)
                :keymap (make-keymap)
                :file-tree nil
                :renderer nil
                :buffers (list buffer)
                :kill-ring nil)))
        (host-kit:write-file-string "plain" path)
        (loom/feature/project::project-root)
        (expect (loom:minibuffer-message-string
                 (editor-state-minibuffer *editor-state*))
                :to-equal
                "No project root found")
        (loom/feature/project::project-find-file)
        (expect (loom:minibuffer-message-string
                 (editor-state-minibuffer *editor-state*))
                :to-equal
                "No project root found")
        (loom/feature/project::project-search)
        (expect (loom:minibuffer-message-string
                 (editor-state-minibuffer *editor-state*))
                :to-equal
                "No project root found")))))
