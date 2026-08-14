(in-package #:loom/test)

(describe
    "git command execution"
  (it "runs status in the requested directory"
      (let ((result
              (make-shell-command-result
               :command "git status --short --branch"
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
          (expect (run-git-status :directory "/repo/") :to-be result)
          (expect command :to-equal "git status --short --branch")
          (expect captured-directory :to-equal "/repo/"))))

    (it "runs the requested kind of diff in the requested directory"
      (let ((result
              (make-shell-command-result
               :command "git diff --cached"
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
          (expect (run-git-diff :directory "/repo/" :staged t) :to-be result)
          (expect command :to-equal "git diff --cached")
          (expect captured-directory :to-equal "/repo/")))))

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
  (it "reports a failed status command"
    (%with-minibuffer-state (minibuffer "")
      (let ((result (make-shell-command-result
                     :command "git status --short --branch"
                     :directory "/repo/"
                     :output ""
                     :error-output "not a repository"
                     :exit-code 128)))
        (with-replaced-function
            (loom/feature/git:run-git-status
             (lambda (&key directory)
               (declare (ignore directory))
               result))
          (expect (git-status) :to-be result)
          (expect (minibuffer-message-string minibuffer)
                  :to-equal "Git status exited with status 128")))))
  (it "reuses the existing status result buffer"
    (%with-minibuffer-state (minibuffer "")
      (let ((first-result (make-shell-command-result
                           :command "git status --short --branch"
                           :directory "/repo/"
                           :output (format nil "first~%")
                           :error-output ""
                           :exit-code 0))
            (second-result (make-shell-command-result
                            :command "git status --short --branch"
                            :directory "/repo/"
                            :output (format nil "second~%")
                            :error-output ""
                            :exit-code 0)))
        (with-replaced-function
            (loom/feature/git:run-git-status
             (let ((results (list first-result second-result)))
               (lambda (&key directory)
                 (declare (ignore directory))
                 (pop results))))
          (git-status)
          (let ((buffer (%selected-test-buffer)))
            (git-status)
            (expect (%selected-test-buffer) :to-be buffer)
            (expect (buffer-text buffer) :to-contain "second"))))))
  (it "reports status errors without leaving the command active"
    (%with-minibuffer-state (minibuffer "")
      (with-replaced-function
          (loom/feature/git:run-git-status
           (lambda (&key directory)
             (declare (ignore directory))
             (error "status unavailable")))
        (expect (git-status) :to-be nil)
        (expect (minibuffer-message-string minibuffer)
                :to-contain "Git status error: status unavailable"))))

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
  (it "reports a failed diff command"
    (%with-minibuffer-state (minibuffer "")
      (let ((result (make-shell-command-result
                     :command "git diff"
                     :directory "/repo/"
                     :output ""
                     :error-output "diff failed"
                     :exit-code 1)))
        (with-replaced-function
            (loom/feature/git:run-git-diff
             (lambda (&key directory staged)
               (declare (ignore directory staged))
               result))
          (expect (git-diff) :to-be result)
          (expect (minibuffer-message-string minibuffer)
                  :to-equal "Git diff exited with status 1")))))
