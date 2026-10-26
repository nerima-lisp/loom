(in-package #:loom)

(defun execute-extended-command ()
  "Prompt for a registered command and execute it (M-x)."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((input "M-x "
              :completion-function
              (lambda (input)
                (declare (ignore input))
                (loom/core/command:command-completion-names ""))))
    (let ((spec (loom/core/command:find-extended-command-spec input)))
      (if spec
          (invoke-command
           (loom/core/command:command-spec-id spec)
           (if (eq loom/core/command:*current-command-route* :macro)
               :macro
               :mx))
          (minibuffer-message
           minibuffer
           (format nil "Unknown command: ~A" input))))))
