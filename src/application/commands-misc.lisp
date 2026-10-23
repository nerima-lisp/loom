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
              #'loom/application:command-completion-candidates))
    (let ((spec (loom/application:find-extended-command-spec input)))
      (if spec
          (invoke-command (getf spec :command) :mx)
          (minibuffer-message
           minibuffer
           (format nil "Unknown command: ~A" input))))))

(defun help-command ()
  "Show a compact reference for the primary editor commands."
  (minibuffer-message
   (editor-state-minibuffer *editor-state*)
   (loom/application:help-summary-message)))
(defun invoke-command (command route)
  "Trace registered COMMAND through ROUTE and then execute it."
  (let ((trace-error
          (loom/application:record-command-trace command route))
        (minibuffer (editor-state-minibuffer *editor-state*)))
    (when (and trace-error minibuffer)
      (minibuffer-message minibuffer trace-error)))
  (funcall command))
