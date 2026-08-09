;;;; t/integration/project-test.lisp
;;;;
;;;; Real temporary-directory traversal, project search, and project commands.
(in-package #:loom/test)

(describe
  "project filesystem integration"
  (it
    "finds the root, skips ignored directories, and searches files"
    (host-kit:with-temporary-directory (directory)
      (let* ((root (truename directory))
             (main-path (merge-pathnames "src/main.py" root))
             (ignored-path (merge-pathnames "target/generated.py" root)))
        (ensure-directories-exist main-path)
        (ensure-directories-exist ignored-path)
        (host-kit:write-file-string "" (merge-pathnames "flake.nix" root))
        (host-kit:write-file-string "print('needle')" main-path)
        (host-kit:write-file-string "needle" ignored-path)

        (expect (namestring (project-find-root main-path))
                :to-equal
                (namestring root))
        (expect (mapcar (lambda (path) (project-relative-path root path))
                        (project-list-files root))
                :to-equal
                '("flake.nix" "src/main.py"))
        (let ((results (project-search-files root "needle")))
          (expect (length results) :to-equal 1)
          (expect (project-relative-path root (getf (first results) :path))
                  :to-equal "src/main.py")))))

  (it
    "opens a project file and reports project search results through commands"
    (host-kit:with-temporary-directory (directory)
      (let* ((root (truename directory))
             (main-path (merge-pathnames "src/main.py" root))
             (current (make-buffer :name "current.py"
                                   :path main-path
                                   :initial-content "print('needle')"))
             (tree (make-window-tree current 80 24))
             (minibuffer (make-minibuffer))
             (*editor-state*
               (make-editor-state :window-tree tree
                                  :minibuffer minibuffer
                                  :keymap (make-keymap)
                                  :file-tree nil
                                  :renderer nil
                                  :buffers (list current)
                                  :kill-ring nil)))
        (ensure-directories-exist main-path)
        (host-kit:write-file-string "" (merge-pathnames "flake.nix" root))
        (host-kit:write-file-string "print('needle')" main-path)

        (loom::project-find-file)
        (expect (minibuffer-prompt-string minibuffer) :to-equal "Project file: ")
        (funcall (loom::%minibuffer-on-confirm minibuffer) "src/main.py")
        (expect (namestring (buffer-path (%selected-test-buffer)))
                :to-equal
                (namestring main-path))
        (expect (buffer-major-mode (%selected-test-buffer)) :to-be :python)

        (loom::project-search)
        (expect (minibuffer-prompt-string minibuffer)
                :to-equal
                "Project search: ")
        (funcall (loom::%minibuffer-on-confirm minibuffer) "needle")
        (expect (loom::%minibuffer-message minibuffer)
                :to-equal
                "Matches: src/main.py:1")))))
