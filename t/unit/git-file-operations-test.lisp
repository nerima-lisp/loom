(in-package #:loom/test)

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
