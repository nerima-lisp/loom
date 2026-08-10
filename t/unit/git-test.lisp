(in-package #:loom/test)

(describe
    "git status"
  (it "builds a concise branch-aware status command"
    (expect (git-status-command)
            :to-equal
            "git status --short --branch"))

  (it "displays captured status in a read-only result buffer"
    (%with-minibuffer-state (minibuffer "")
      (let ((result
              (make-shell-command-result
               :command "git status --short --branch"
               :directory "/repo/"
               :output (format nil "## main~% M README.md~%")
               :error-output ""
               :exit-code 0)))
        (with-replaced-function
            (loom/feature/git:run-git-status
             (lambda (&key directory)
               (declare (ignore directory))
               result))
          (expect (git-status) :to-be result))
        (let ((buffer (%selected-test-buffer)))
          (expect (buffer-name buffer) :to-equal "*Loom-Git-Status*")
          (expect (buffer-text buffer) :to-contain "## main")
          (expect (buffer-text buffer) :to-contain "README.md")
          (expect (buffer-read-only-p buffer) :to-be-truthy)
          (expect (minibuffer-message-string minibuffer)
                  :to-equal
                  "Git status refreshed"))))))

(describe
    "git diff"
  (it "builds working-tree and staged diff commands"
    (expect (git-diff-command)
            :to-equal
            "git diff")
    (expect (git-diff-command :staged t)
            :to-equal
            "git diff --cached"))

  (it "displays a captured working-tree diff in a read-only result buffer"
    (%with-minibuffer-state (minibuffer "")
      (let ((result
              (make-shell-command-result
               :command "git diff"
               :directory "/repo/"
               :output (format nil "diff --git a/README.md b/README.md~%")
               :error-output ""
               :exit-code 0)))
        (with-replaced-function
            (loom/feature/git:run-git-diff
             (lambda (&key directory staged)
               (declare (ignore directory))
               (expect staged :to-be nil)
               result))
          (expect (git-diff) :to-be result))
        (let ((buffer (%selected-test-buffer)))
          (expect (buffer-name buffer) :to-equal "*Loom-Git-Diff*")
          (expect (buffer-text buffer) :to-contain "diff --git")
          (expect (buffer-read-only-p buffer) :to-be-truthy)
          (expect (minibuffer-message-string minibuffer)
                  :to-equal
                  "Git diff refreshed"))))))

  (it "displays a captured staged diff and passes the staged selector"
    (%with-minibuffer-state (minibuffer "")
      (let ((result
              (make-shell-command-result
               :command "git diff --cached"
               :directory "/repo/"
               :output (format nil "diff --cached~%")
               :error-output ""
               :exit-code 0)))
        (with-replaced-function
            (loom/feature/git:run-git-diff
             (lambda (&key directory staged)
               (declare (ignore directory))
               (expect staged :to-be-truthy)
               result))
          (expect (git-diff-staged) :to-be result))
        (expect (minibuffer-message-string minibuffer)
                :to-equal
                "Git staged diff refreshed"))))

(describe
    "git file operations"
  (it "quotes repository paths before building stage commands"
    (expect (git-stage-command "src/file name's.txt")
            :to-equal
            "git add -- 'src/file name'\\''s.txt'")
    (expect (git-unstage-command "src/file name's.txt")
            :to-equal
            "git restore --staged -- 'src/file name'\\''s.txt'"))

  (it "runs stage and unstage with the requested directory"
    (let ((result
            (make-shell-command-result
             :command "git operation"
             :directory "/repo/"
             :output ""
             :error-output ""
             :exit-code 0))
          command
          captured-directory)
      (with-replaced-function
          (loom/feature/shell:run-shell-command
           (lambda (candidate-command &key directory)
             (setf command candidate-command
                   captured-directory directory)
             result))
        (expect (run-git-stage "README.md" :directory "/repo/")
                :to-be
                result)
        (expect command :to-equal "git add -- 'README.md'")
        (expect captured-directory :to-equal "/repo/")
        (expect (run-git-unstage "README.md" :directory "/repo/")
                :to-be
                result)
        (expect command :to-equal "git restore --staged -- 'README.md'")
        (expect captured-directory :to-equal "/repo/")))))

  (it "prompts for a path before staging it"
    (%with-minibuffer-state (minibuffer "")
      (let ((result
              (make-shell-command-result
               :command "git add -- 'README.md'"
               :directory "/repo/"
               :output ""
               :error-output ""
               :exit-code 0))
            path
            captured-directory)
        (with-replaced-function
            (loom/feature/git::%git-status-directory
             (lambda () "/repo/"))
          (with-replaced-function
              (loom/feature/git:run-git-stage
              (lambda (candidate-path &key directory)
                 (setf path candidate-path
                       captured-directory directory)
                 result))
            (git-stage-file)
            (expect (minibuffer-prompt-string minibuffer)
                    :to-equal
                    "Git stage file: ")
            (funcall (loom::%minibuffer-on-confirm minibuffer)
                     " README.md ")
            (expect path :to-equal "README.md")
            (expect captured-directory :to-equal "/repo/")
            (expect (minibuffer-message-string minibuffer)
                    :to-equal
                    "Git staged README.md"))))))

  (it "prompts for a path before unstaging it"
    (%with-minibuffer-state (minibuffer "")
      (let ((result
              (make-shell-command-result
               :command "git restore --staged -- README.md"
               :directory "/repo/"
               :output ""
               :error-output ""
               :exit-code 0))
            path
            captured-directory)
        (with-replaced-function
            (loom/feature/git::%git-status-directory
             (lambda () "/repo/"))
          (with-replaced-function
              (loom/feature/git:run-git-unstage
              (lambda (candidate-path &key directory)
                 (setf path candidate-path
                       captured-directory directory)
                 result))
            (git-unstage-file)
            (funcall (loom::%minibuffer-on-confirm minibuffer)
                     " README.md ")
            (expect path :to-equal "README.md")
            (expect captured-directory :to-equal "/repo/")
            (expect (minibuffer-message-string minibuffer)
                    :to-equal
                    "Git unstaged README.md"))))))
