(in-package #:loom/test)

(describe
  "shell command timeouts"
  (it "returns a structured timeout result"
    (let ((result (run-shell-command "sleep 2"
                                     :timeout-seconds 0.01)))
      (expect (shell-command-result-success-p result) :to-be-falsy)
      (expect (shell-command-result-exit-code result) :to-equal 124)
      (expect (shell-command-result-error-output result)
              :to-contain "timed out")))
  (it "rejects invalid command options"
    (signals type-error (run-shell-command 42))
    (signals type-error (run-shell-command "true" :timeout-seconds -1))
    (signals type-error (run-shell-command "true" :input 42))))

(describe
  "shell command results"
  (it "renders both process streams and the exit status"
    (let ((result
            (make-shell-command-result
             :command "build"
             :directory "/tmp/"
             :output "stdout"
             :error-output "stderr"
             :exit-code 7)))
      (expect (shell-command-result-success-p result) :to-be-falsy)
      (expect (shell-command-result-text result)
              :to-equal
              (format nil
                      "$ build~%Directory: /tmp/~%Output:~%stdout~%Error output:~%stderr~%Exit code: 7~%"))))
  (it "renders stream sections only when they contain text"
    (expect
     (shell-command-result-text
      (make-shell-command-result :command "true" :directory "/tmp/"))
     :to-equal
     (format nil "$ true~%Directory: /tmp/~%Exit code: 0~%"))
    (expect
     (shell-command-result-text
      (make-shell-command-result :command "true" :directory "/tmp/"
                                  :output (format nil "output~%")
                                  :error-output (format nil "error~%")))
     :to-equal
     (format nil
             "$ true~%Directory: /tmp/~%Output:~%output~%Error output:~%error~%Exit code: 0~%")))
  (it "runs a shell command and captures its streams and status"
    (let ((result
            (run-shell-command
             "printf 'stdout'; printf 'stderr' >&2; exit 7"
             :directory (uiop:getcwd))))
      (expect (shell-command-result-output result) :to-equal "stdout")
      (expect (shell-command-result-error-output result) :to-equal "stderr")
      (expect (shell-command-result-exit-code result) :to-equal 7)
      (expect (shell-command-result-directory result)
              :to-equal
              (namestring (truename (uiop:getcwd)))))))
  (it "preserves the final component of a string directory"
    (let* ((directory (truename (uiop:getcwd)))
           (result (run-shell-command "pwd"
                                      :directory (namestring directory))))
      (expect (shell-command-result-output result)
              :to-equal
              (format nil "~A~%"
                      (string-right-trim "/" (namestring directory))))
      (expect (shell-command-result-directory result)
              :to-equal
              (namestring directory))
      (expect (shell-command-result-exit-code result) :to-equal 0)))
  (it "normalizes pathname directories and the default directory"
    (let ((directory (truename (uiop:getcwd))))
      (expect (namestring (loom/feature/shell::%shell-directory-pathname
                           directory))
              :to-equal
              (namestring directory))
      (expect (namestring (loom/feature/shell::%shell-directory-pathname
                           nil))
              :to-equal
              (namestring (truename (uiop:getcwd))))))
  (it "uses the parent directory for a file pathname"
    (let* ((directory (uiop:temporary-directory))
           (file (merge-pathnames "loom-shell-directory-file.txt" directory)))
      (with-open-file (stream file :direction :output :if-exists :supersede)
        (write-line "fixture" stream))
      (expect (namestring (loom/feature/shell::%shell-directory-pathname file))
              :to-equal
              (namestring (truename directory)))))
  (it "passes string input to process standard input"
    (let ((result (run-shell-command "tr 'a-z' 'A-Z'"
                                     :input "abc")))
      (expect (shell-command-result-output result) :to-equal "ABC")
      (expect (shell-command-result-error-output result) :to-equal "")
      (expect (shell-command-result-exit-code result) :to-equal 0)))

(describe
  "pipe-command"
  (it "runs in the selected file directory and displays a result buffer"
    (let* ((directory (uiop:temporary-directory))
           (source-path (merge-pathnames "loom-shell-source.txt" directory))
           (state
             (let ((buffer (make-buffer :name "source.txt"
                                        :path source-path
                                        :initial-content "source")))
               (let ((tree (make-window-tree buffer 80 24)))
                 (make-editor-state
                  :window-tree tree
                  :workspaces (make-workspace-manager tree :name "main")
                  :minibuffer (make-minibuffer)
                  :keymap (make-keymap)
                  :file-tree nil
                  :renderer nil
                  :buffers (list buffer)
                  :kill-ring nil)))))
      (let ((*editor-state* state)
            (minibuffer (editor-state-minibuffer state)))
        (pipe-command)
        (expect (minibuffer-prompt-string minibuffer)
                :to-equal "Pipe command: ")
        (funcall (loom::%minibuffer-on-confirm minibuffer)
                 "printf 'stdout'; printf 'stderr' >&2; exit 3")
        (let ((result (find "*Loom-Pipe-Command*"
                            (editor-state-buffers state)
                            :key #'buffer-name
                            :test #'string=)))
          (expect result :to-be-truthy)
          (expect (buffer-text result) :to-contain "stdout")
          (expect (buffer-text result) :to-contain "stderr")
          (expect (buffer-text result) :to-contain "Exit code: 3")
          (expect (buffer-text result) :to-contain
                  (format nil "Directory: ~A" (namestring (truename directory))))
          (expect (buffer-modified-p result) :to-be nil)
          (expect (window-buffer
                   (window-tree-selected-window
                    (editor-state-window-tree state)))
                  :to-be result)
          (expect (minibuffer-message-string minibuffer)
                  :to-equal "Pipe command exited with code 3")
          (pipe-command)
          (funcall (loom::%minibuffer-on-confirm minibuffer)
                   "printf 'second'")
          (expect (buffer-text result) :to-contain "$ printf 'second'")
          (expect (buffer-text result) :to-contain "second")
          (expect (minibuffer-message-string minibuffer)
                  :to-equal "Pipe command finished successfully"))))))

  (it "reports cancellation for an empty command"
    (let* ((buffer (make-buffer :name "source.txt" :initial-content "source"))
           (tree (make-window-tree buffer 80 24))
           (state (make-editor-state
                   :window-tree tree
                   :workspaces (make-workspace-manager tree :name "main")
                   :minibuffer (make-minibuffer)
                   :keymap (make-keymap)
                   :file-tree nil
                   :renderer nil
                   :buffers (list buffer)
                   :kill-ring nil)))
      (let ((*editor-state* state)
            (minibuffer (editor-state-minibuffer state)))
        (pipe-command)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "  ")
        (expect (minibuffer-message-string minibuffer)
                :to-equal "Pipe command cancelled"))))

  (it "reports command errors without creating a result buffer"
    (let* ((buffer (make-buffer :name "source.txt" :initial-content "source"))
           (tree (make-window-tree buffer 80 24))
           (state (make-editor-state
                   :window-tree tree
                   :workspaces (make-workspace-manager tree :name "main")
                   :minibuffer (make-minibuffer)
                   :keymap (make-keymap)
                   :file-tree nil
                   :renderer nil
                   :buffers (list buffer)
                   :kill-ring nil)))
      (let ((*editor-state* state)
            (minibuffer (editor-state-minibuffer state)))
        (with-replaced-function
            (loom/feature/shell:run-shell-command
             (lambda (command &key directory)
               (declare (ignore command directory))
               (error "synthetic shell failure")))
          (pipe-command)
          (funcall (loom::%minibuffer-on-confirm minibuffer) "false"))
        (expect (minibuffer-message-string minibuffer)
                :to-contain "Pipe command error: synthetic shell failure")
                (expect (find "*Loom-Pipe-Command*" (editor-state-buffers state)
                      :key #'buffer-name :test #'string=)
                :to-be nil))))
