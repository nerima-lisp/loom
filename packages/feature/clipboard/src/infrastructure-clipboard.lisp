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

(defmethod %clipboard-copy-to-local ((text string))
  (multiple-value-bind (copied failure) (%clipboard-copy-with "pbcopy" text)
    (when copied
      (return-from %clipboard-copy-to-local
        (values t nil)))
    (multiple-value-bind (copied fallback-failure)
        (%clipboard-copy-with "wl-copy" text)
      (values copied (or fallback-failure failure)))))

(defmethod clipboard-read-text ()
  (let ((failure nil))
    (dolist (command (list "pbpaste" "wl-paste --no-newline"))
      (handler-case (let ((result
                           (run-shell-command command :timeout-seconds 0.5)))
                      (cond
                        ((shell-command-result-success-p result)
                         (return-from clipboard-read-text
                           (values (shell-command-result-output result)
                                   command
                                   nil)))
                        (t
                         (setf failure (or
                                        (shell-command-result-error-output
                                         result)
                                        (format nil
                                                "~A exited with status ~D"
                                                command
                                                (shell-command-result-exit-code
                                                 result)))))))
        (error (condition)
          (setf failure condition))))
    (values nil nil failure)))
