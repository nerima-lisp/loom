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
