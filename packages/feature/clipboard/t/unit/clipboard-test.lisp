(in-package #:loom/test)

(defun %clipboard-test-result (command output exit-code)
  (make-shell-command-result :command
                             command
                             :directory
                             "/tmp"
                             :output
                             output
                             :exit-code
                             exit-code))

(describe "clipboard"
          (it "falls back from pbcopy to wl-copy with the exact text"
              (let ((calls nil)
                    (text (format nil "copied~%exact")))
                (with-replaced-function
                 (run-shell-command
                  (function
                   (lambda (command &key input timeout-seconds)
                     (declare (ignore timeout-seconds))
                     (push (list command input) calls)
                     (%clipboard-test-result command
                                             ""
                                             (if (string= command "pbcopy")
                                                 1
                                                 0)))))
                 (expect (loom/feature/clipboard:clipboard-copy-text text)
                         :to-be
                         t))
                (expect (nreverse calls)
                        :to-equal
                        (list (list "command -v pbcopy >/dev/null 2>&1" nil)
                              (list "pbcopy" text)
                              (list "command -v wl-copy >/dev/null 2>&1" nil)
                              (list "wl-copy" text)))))
          (it "skips unavailable clipboard writers without sending text"
              (let ((calls nil))
                (with-replaced-function
                 (run-shell-command
                  (function
                   (lambda (command &key input timeout-seconds)
                     (declare (ignore timeout-seconds))
                     (push (list command input) calls)
                     (%clipboard-test-result command "" 127))))
                 (expect (loom/feature/clipboard:clipboard-copy-text "copied")
                         :to-be
                         nil))
                (expect (nreverse calls)
                        :to-equal
                        (list (list "command -v pbcopy >/dev/null 2>&1" nil)
                              (list "command -v wl-copy >/dev/null 2>&1" nil)))))
          (it "falls back from pbpaste to wl-paste and preserves its text"
              (let ((calls nil)
                    (text (format nil "(root~%~Cvalue)" #\Tab)))
                (with-replaced-function
                 (run-shell-command
                  (function
                   (lambda (command &key input timeout-seconds)
                     (declare (ignore timeout-seconds))
                     (declare (ignore input))
                     (push command calls)
                     (if (string= command "pbpaste")
                         (%clipboard-test-result command "" 1)
                         (%clipboard-test-result command text 0)))))
                 (multiple-value-bind (actual provider)
                     (loom/feature/clipboard:clipboard-read-text)
                   (expect actual :to-equal text)
                   (expect provider :to-equal "wl-paste --no-newline"))
                 (expect (nreverse calls)
                         :to-equal
                         (list "pbpaste" "wl-paste --no-newline")))))
          (it "inserts clipboard text through the paste undo boundary"
              (let* ((*editor-state*
                      (%fresh-editor-state "" :with-minibuffer t))
                     (buffer (%selected-test-buffer))
                     (text (format nil "clipboard~%~Ctext" #\Tab)))
                (with-replaced-function
                 (run-shell-command
                  (function
                   (lambda (command &key input timeout-seconds)
                     (declare (ignore timeout-seconds))
                     (declare (ignore input))
                     (%clipboard-test-result command text 0))))
                 (loom/feature/clipboard:clipboard-yank))
                (expect (buffer-text buffer) :to-equal text)
                (buffer-undo buffer)
                (expect (buffer-text buffer) :to-equal "")))
          (it "copies the coalesced kill-ring entry during an active session"
              (let* ((*editor-state* (%fresh-editor-state ""))
                     (session (editor-state-session *editor-state*))
                     (loom/core/editor-session:*editor-session* session))
                (loom/feature/kill-ring::%kill-ring-push "first")
                (loom/feature/kill-ring::%kill-ring-push " second" :coalesce t)
                (expect
                 (loom/core/editor-session:drain-terminal-clipboard-requests
                  session)
                 :to-equal
                 (list "first" "first second"))
                (expect (editor-state-kill-ring *editor-state*)
                        :to-equal
                        (list "first second")))))

(describe "clipboard failure fallback"
          (it "yanks from the kill ring when clipboard commands are unavailable"
              (let* ((*editor-state*
                      (%fresh-editor-state "" :with-minibuffer t))
                     (buffer (%selected-test-buffer))
                     (commands nil))
                (setf (editor-state-kill-ring *editor-state*) (list
                                                               "from kill ring"))
                (with-replaced-function
                 (run-shell-command
                  (function
                   (lambda (command &key input timeout-seconds)
                     (declare (ignore timeout-seconds))
                     (declare (ignore input))
                     (push command commands)
                     (%clipboard-test-result command "" 127))))
                 (loom/feature/clipboard:clipboard-yank))
                (expect (buffer-text buffer) :to-equal "from kill ring")
                (expect (nreverse commands)
                        :to-equal
                        (list "pbpaste" "wl-paste --no-newline"))
                (expect
                 (loom:minibuffer-message-string
                  (editor-state-minibuffer *editor-state*))
                 :to-equal
                 "Clipboard unavailable; using kill ring")))
          (it "yanks from the kill ring and reports clipboard read errors"
              (let* ((*editor-state*
                      (%fresh-editor-state "" :with-minibuffer t))
                     (buffer (%selected-test-buffer))
                     (commands nil))
                (setf (editor-state-kill-ring *editor-state*) (list
                                                               "from kill ring"))
                (with-replaced-function
                 (run-shell-command
                  (function
                   (lambda (command &key input timeout-seconds)
                     (declare (ignore timeout-seconds))
                     (declare (ignore input))
                     (push command commands)
                     (error
                      (make-condition (quote process-kit:process-io-error)
                                      :stream
                                      :stdin
                                      :cause
                                      nil)))))
                 (loom/feature/clipboard:clipboard-yank))
                (expect (buffer-text buffer) :to-equal "from kill ring")
                (expect (nreverse commands)
                        :to-equal
                        (list "pbpaste" "wl-paste --no-newline"))
                (expect
                 (loom:minibuffer-message-string
                  (editor-state-minibuffer *editor-state*))
                 :to-contain
                 "Failed while draining subprocess STDIN.")
                (expect
                 (loom:minibuffer-message-string
                  (editor-state-minibuffer *editor-state*))
                 :to-contain
                 "using kill ring")))
          (it "falls back after clipboard process I/O failure and reports it"
              (let* ((*editor-state*
                      (%fresh-editor-state "" :with-minibuffer t))
                     (buffer (%selected-test-buffer))
                     (commands nil))
                (setf (editor-state-kill-ring *editor-state*) (list
                                                               "from kill ring"))
                (with-replaced-function
                 (run-shell-command
                  (function
                   (lambda (command &key input timeout-seconds)
                     (declare (ignore timeout-seconds input))
                     (push command commands)
                     (if (string= command "pbpaste")
                         (error
                          (make-condition (quote process-kit:process-io-error)
                                          :stream
                                          :stdin
                                          :cause
                                          nil))
                         (%clipboard-test-result command "" 127)))))
                 (loom/feature/clipboard:clipboard-yank))
                (expect (buffer-text buffer) :to-equal "from kill ring")
                (expect (nreverse commands)
                        :to-equal
                        (list "pbpaste" "wl-paste --no-newline"))
                (expect
                 (loom:minibuffer-message-string
                  (editor-state-minibuffer *editor-state*))
                 :to-contain
                 "Failed while draining subprocess STDIN.")
                (expect
                 (loom:minibuffer-message-string
                  (editor-state-minibuffer *editor-state*))
                 :to-contain
                 "using kill ring")))
          (it
           "reports local clipboard writer errors without losing the kill ring"
           (let* ((*editor-state* (%fresh-editor-state "" :with-minibuffer t))
                  (commands nil))
             (setf (editor-state-kill-ring *editor-state*) (list
                                                            "from kill ring"))
             (with-replaced-function
              (run-shell-command
               (function
                (lambda (command &key input timeout-seconds)
                  (declare (ignore timeout-seconds))
                  (declare (ignore input))
                  (push command commands)
                  (cond
                    ((string= command "command -v pbcopy >/dev/null 2>&1")
                     (%clipboard-test-result command "" 0))
                    ((string= command "pbcopy")
                     (error
                      (make-condition (quote process-kit:process-io-error)
                                      :stream
                                      :stdin
                                      :cause
                                      nil)))
                    (t (%clipboard-test-result command "" 127))))))
              (expect (loom/feature/clipboard:clipboard-copy-text "copied")
                      :to-be
                      nil))
             (expect (nreverse commands)
                     :to-equal
                     (list "command -v pbcopy >/dev/null 2>&1"
                           "pbcopy"
                           "command -v wl-copy >/dev/null 2>&1"))
             (expect (editor-state-kill-ring *editor-state*)
                     :to-equal
                     (list "from kill ring"))
             (expect
              (loom:minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-contain
              "Failed while draining subprocess STDIN.")
             (expect
              (loom:minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-contain
              "kill ring remains available"))))
