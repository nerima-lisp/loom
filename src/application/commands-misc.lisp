;;;; src/application/commands-misc.lisp
;;;;
;;;; Application layer: help, M-x, and keyboard-quit commands.
;;;; The command catalogue is kept in application/command-definitions.lisp;
;;;; the registry implementation is in application/command-registry.lisp.
(in-package #:loom)

;; KEYBOARD-QUIT's own cancel path is narrower than it looks: a literal C-g
;; typed while the minibuffer has focus is already handled entirely inside
;; MINIBUFFER-HANDLE-KEY (see its contract in application/minibuffer.lisp --
;; it calls ON-CANCEL and deactivates the minibuffer itself for a C-g
;; KEY-EVENT), so that path never reaches this top-level command at all.
;; MINIBUFFER-HANDLE-KEY's KEY-EVENT is documented as an opaque CL-TTY-KIT
;; object this layer has no business fabricating, and no other public
;; minibuffer operation cancels a prompt programmatically, so this command's
;; only well-defined job is the global-keymap fallback: report "Quit", same
;; as Emacs's top-level C-g when there is nothing else to cancel.
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
    (let ((command (loom/application:find-extended-command input)))
      (if command
          (funcall command)
          (minibuffer-message
           minibuffer
           (format nil "Unknown command: ~A" input))))))

(defun help-command ()
  "Show a compact reference for the primary editor commands."
  (minibuffer-message
   (editor-state-minibuffer *editor-state*)
   (loom/application:help-summary-message)))
