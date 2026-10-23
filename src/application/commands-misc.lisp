(in-package #:loom)

(defun keyboard-quit ()
  "Report a Quit message (C-g)."
  (prefix-argument-reset (prefix-argument-for-editor))
  (minibuffer-message (editor-state-minibuffer *editor-state*) "Quit"))

(defun execute-extended-command ()
  "Prompt for a registered command and execute it (M-x)."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((input "M-x "
              :completion-function
              (function loom/core/command:command-completion-candidates)))
    (let ((spec (loom/core/command:find-extended-command-spec input)))
      (if spec
          (invoke-command (getf spec :command) :mx)
          (minibuffer-message
           minibuffer
           (format nil "Unknown command: ~A" input))))))

(defun help-command ()
  "Show a compact reference for the primary editor commands."
  (minibuffer-message
   (editor-state-minibuffer *editor-state*)
   (loom/core/command:help-summary-message)))
