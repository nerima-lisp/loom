(in-package #:loom/feature/clipboard)

(defun %clipboard-copy-with (command text)
  (handler-case (let ((available
                       (run-shell-command
                        (format nil "command -v ~A >/dev/null 2>&1" command)
                        :timeout-seconds
                        0.5)))
                  (when (shell-command-result-success-p available)
                    (let ((result
                           (run-shell-command command
                                              :input
                                              text
                                              :timeout-seconds
                                              0.5)))
                      (if (shell-command-result-success-p result)
                          (values t nil)
                          (values nil
                                  (or (shell-command-result-error-output result)
                                      (format nil
                                              "~A exited with status ~D"
                                              command
                                              (shell-command-result-exit-code
                                               result))))))))
    (error (condition)
      (values nil condition))))

(defun %system-clipboard-copy-to-local (text)
  (multiple-value-bind (copied failure) (%clipboard-copy-with "pbcopy" text)
    (when copied
      (return-from %system-clipboard-copy-to-local (values t nil)))
    (multiple-value-bind (copied fallback-failure)
        (%clipboard-copy-with "wl-copy" text)
      (values copied (or fallback-failure failure)))))

(progn
  (defun %system-clipboard-read-text ()
    (let ((failure nil))
      (dolist (command (list "pbpaste" "wl-paste --no-newline"))
        (handler-case
            (let ((result
                    (run-shell-command command :timeout-seconds 0.5)))
              (if (shell-command-result-success-p result)
                  (return-from %system-clipboard-read-text
                    (values (shell-command-result-output result)
                            command
                            nil))
                  (unless (= (shell-command-result-exit-code result) 127)
                    (setf failure
                          (or failure
                              (let ((error-output
                                      (shell-command-result-error-output result)))
                                (and (stringp error-output)
                                     (plusp (length error-output))
                                     error-output))
                              (format nil "~A exited with status ~D"
                                      command
                                      (shell-command-result-exit-code result)))))))
          (error (condition)
            (setf failure (or failure condition)))))
      (values nil nil failure)))
  (setf *clipboard-read-provider* (function %system-clipboard-read-text)
        *clipboard-local-writer* (function %system-clipboard-copy-to-local)))
