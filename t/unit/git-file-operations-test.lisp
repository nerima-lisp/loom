(in-package #:loom/test)

(describe
    "git file operations"
  (it "uses the project directory when no project root is found"
    (let ((selected-buffer (make-buffer :name "notes" :path #P"/repo/src/notes.lisp")))
      (with-replaced-function
          (loom/feature/git::%selected-buffer
           (lambda () selected-buffer))
        (with-replaced-function
            (project-find-root
             (lambda (path)
               (declare (ignore path))
               nil))
          (expect (namestring (loom/feature/git::%git-status-directory))
                  :to-equal
                  "/repo/src/")))))

  (it "runs stage and unstage with the requested directory"
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
        (expect (run-git-stage "README.md" :directory "/repo/")
                :to-be
                result)
        (expect command :to-equal '(nil "add" ("--" "README.md")))
        (expect captured-directory :to-equal "/repo/")
        (expect captured-timeout :to-equal *git-command-timeout-seconds*)
        (expect (run-git-unstage "README.md" :directory "/repo/")
                :to-be
                result)
        (expect command :to-equal '(nil "restore" ("--staged" "--" "README.md")))
        (expect captured-directory :to-equal "/repo/")
        (expect captured-timeout :to-equal *git-command-timeout-seconds*)))))

  (it "builds status and diff commands with the requested directory"
    (let ((result (make-test-git-result :status 0))
          commands)
      (with-replaced-function
          (vcs-kit:run-git
           (lambda (repository subcommand arguments &key directory timeout)
             (push (list repository subcommand arguments directory timeout)
                   commands)
             result))
        (expect (run-git-status :directory "/repo/") :to-be result)
        (expect (run-git-diff :directory "/repo/") :to-be result)
        (expect (run-git-diff :directory "/repo/" :staged t) :to-be result)
        (expect (nreverse commands)
                :to-equal
                `((nil "status" ("--short" "--branch") "/repo/"
                        ,*git-command-timeout-seconds*)
                  (nil "diff" nil "/repo/"
                        ,*git-command-timeout-seconds*)
                  (nil "diff" ("--cached") "/repo/"
                        ,*git-command-timeout-seconds*))))))

  (it "prompts for a path before staging it"
    (%with-minibuffer-state (minibuffer "")
      (let ((result
              (make-test-git-result
               :stdout ""
               :stderr ""
               :status 0))
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
              (make-test-git-result
               :stdout ""
               :stderr ""
               :status 0))
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

  (it "reports a failed stage operation"
    (%with-minibuffer-state (minibuffer "")
      (let ((result
              (make-test-git-result
               :stdout ""
               :stderr "not found"
               :status 2)))
        (with-replaced-function
            (loom/feature/git:run-git-stage
             (lambda (path &key directory)
               (declare (ignore path directory))
               result))
          (git-stage-file)
          (funcall (loom::%minibuffer-on-confirm minibuffer) "README.md")
          (expect (minibuffer-message-string minibuffer)
                  :to-equal "Git stage exited with status 2")))))

  (it "cancels a blank path without invoking Git"
    (%with-minibuffer-state (minibuffer "")
      (let ((called nil))
        (with-replaced-function
            (loom/feature/git:run-git-stage
             (lambda (&rest arguments)
               (declare (ignore arguments))
               (setf called t)))
          (git-stage-file)
          (funcall (loom::%minibuffer-on-confirm minibuffer)
                   (format nil "  ~C " #\Tab))
          (expect called :to-be-falsy)
          (expect (minibuffer-message-string minibuffer)
                  :to-equal "Git stage cancelled")))))

  (it "reports an unstage error and supports prompt cancellation"
    (%with-minibuffer-state (minibuffer "")
      (let ((result (make-test-git-result
                     :stdout ""
                     :stderr "failed"
                     :status 3)))
        (with-replaced-function
            (loom/feature/git:run-git-unstage
             (lambda (path &key directory)
               (declare (ignore path directory))
               result))
          (git-unstage-file)
          (funcall (loom::%minibuffer-on-confirm minibuffer) "README.md")
          (expect (minibuffer-message-string minibuffer)
                  :to-equal "Git unstage exited with status 3"))))
    (%with-minibuffer-state (minibuffer "")
      (git-unstage-file)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "   ")
      (expect (minibuffer-message-string minibuffer)
              :to-equal "Git unstage cancelled")))

  (it "reports exceptions from stage and unstage"
    (%with-minibuffer-state (minibuffer "")
      (with-replaced-function
          (loom/feature/git:run-git-stage
           (lambda (path &key directory)
             (declare (ignore path directory))
             (error "stage unavailable")))
        (git-stage-file)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "README.md")
        (expect (minibuffer-message-string minibuffer)
                :to-equal "Git stage error: stage unavailable")))
    (%with-minibuffer-state (minibuffer "")
      (with-replaced-function
          (loom/feature/git:run-git-unstage
           (lambda (path &key directory)
             (declare (ignore path directory))
             (error "unstage unavailable")))
        (git-unstage-file)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "README.md")
        (expect (minibuffer-message-string minibuffer)
                :to-equal "Git unstage error: unstage unavailable"))))
