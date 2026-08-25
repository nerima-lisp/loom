(in-package #:loom/test)

(describe
    "git command execution"
  (it "runs status in the requested directory"
      (let ((result
              (make-test-git-result
               :stdout ""
               :stderr ""
               :status 0))
            command
            captured-directory
            captured-timeout)
        (with-replaced-function
            (vcs-kit:run-git
             (lambda (repository subcommand arguments &key directory timeout)
               (setf command (list repository subcommand arguments)
                     captured-directory directory
                     captured-timeout timeout)
               result))
          (expect (run-git-status :directory "/repo/") :to-be result)
          (expect command :to-equal '(nil "status" ("--short" "--branch")))
          (expect captured-directory :to-equal "/repo/")
          (expect captured-timeout :to-equal *git-command-timeout-seconds*))))

    (it "runs the requested kind of diff in the requested directory"
      (let ((result
              (make-test-git-result
               :stdout ""
               :stderr ""
               :status 0))
            command
            captured-directory
            captured-timeout)
        (with-replaced-function
            (vcs-kit:run-git
             (lambda (repository subcommand arguments &key directory timeout)
               (setf command (list repository subcommand arguments)
                     captured-directory directory
                     captured-timeout timeout)
               result))
          (expect (run-git-diff :directory "/repo/" :staged t) :to-be result)
          (expect command :to-equal '(nil "diff" ("--cached")))
          (expect captured-directory :to-equal "/repo/")
          (expect captured-timeout :to-equal *git-command-timeout-seconds*)))))

(describe
    "git status"
  (it "displays captured status in a read-only result buffer"
    (%with-minibuffer-state (minibuffer "")
      (let ((result
              (make-test-git-result
               :stdout (format nil "## main~% M README.md~%")
               :stderr ""
               :status 0)))
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
      (let ((result (make-test-git-result
                     :stdout ""
                     :stderr "not a repository"
                     :status 128)))
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
      (let ((first-result (make-test-git-result
                           :stdout (format nil "first~%")
                           :stderr ""
                           :status 0))
            (second-result (make-test-git-result
                            :stdout (format nil "second~%")
                            :stderr ""
                            :status 0)))
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
  (it "displays a captured working-tree diff in a read-only result buffer"
    (%with-minibuffer-state (minibuffer "")
      (let ((result
              (make-test-git-result
               :stdout (format nil "diff --git a/README.md b/README.md~%")
               :stderr ""
               :status 0)))
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
              (make-test-git-result
               :stdout (format nil "diff --cached~%")
               :stderr ""
               :status 0)))
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
      (let ((result (make-test-git-result
                     :stdout ""
                     :stderr "diff failed"
                     :status 1)))
        (with-replaced-function
            (loom/feature/git:run-git-diff
             (lambda (&key directory staged)
               (declare (ignore directory staged))
               result))
          (expect (git-diff) :to-be result)
          (expect (minibuffer-message-string minibuffer)
                  :to-equal "Git diff exited with status 1")))))
