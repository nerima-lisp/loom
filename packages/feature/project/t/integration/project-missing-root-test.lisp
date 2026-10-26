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
               (let ((tree (make-window-tree buffer 80 24)))
                 (make-editor-state
                  :window-tree tree
                  :minibuffer (make-minibuffer)
                  :keymap (make-keymap)
                  :file-tree nil
                  :renderer nil
                  :session (%make-project-test-session
                            (list buffer)
                            :window-tree tree)
                  :kill-ring nil)))
             (loom/core/editor-session:*editor-session*
              (loom/core/editor-session:editor-state-session *editor-state*))
             (loom/feature/project::+project-marker-names+
               '(".loom-missing-root-test-marker")))
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
