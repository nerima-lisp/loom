;;;; src/application/minibuffer-activation.lisp
;;;;
;;;; Application layer: minibuffer activation/message lifecycle. This file
;;;; keeps state transitions separate from the minibuffer struct/query protocol
;;;; in src/application/minibuffer.lisp, from history snapshot/install in
;;;; src/application/minibuffer-history.lisp, and from keystroke-driven input
;;;; handling in src/application/minibuffer-input.lisp.
(in-package #:loom)

(defun %minibuffer-deactivate (minibuffer)
  "Reset MINIBUFFER to the inactive state, discarding prompt/input/callbacks."
  (setf (%minibuffer-active-p minibuffer) nil
        (%minibuffer-prompt minibuffer) nil
        (%minibuffer-input minibuffer) ""
        (%minibuffer-on-confirm minibuffer) nil
        (%minibuffer-on-cancel minibuffer) nil
        (%minibuffer-completion-function minibuffer) nil)
  (let ((history (%minibuffer-history minibuffer)))
    (when history
      (history-kit:history-reset-navigation history)))
  minibuffer)

(defgeneric minibuffer-activate (minibuffer prompt &key on-confirm on-cancel
                                                   completion-function)
  (:documentation
   "Begin an interactive input session in MINIBUFFER, displaying PROMPT and
accepting keystrokes via MINIBUFFER-HANDLE-KEY. ON-CONFIRM, when supplied, is
a function of one argument (the final input string) called when the user
confirms the input (e.g. RET). ON-CANCEL, when supplied, is a function of
zero arguments called when the user cancels (e.g. C-g). COMPLETION-FUNCTION,
when supplied, is a function of the current input string that returns a list
of candidate strings for Tab completion. Returns MINIBUFFER.")
  (:method (minibuffer prompt &key on-confirm on-cancel completion-function)
    (when (and completion-function (not (functionp completion-function)))
      (error "COMPLETION-FUNCTION must be a function or NIL: ~S"
             completion-function))
    (let ((history (%minibuffer-history minibuffer)))
      (when history
        (history-kit:history-reset-navigation history)))
    (setf (%minibuffer-active-p minibuffer) t
          (%minibuffer-prompt minibuffer) prompt
          (%minibuffer-input minibuffer) ""
          (%minibuffer-on-confirm minibuffer) on-confirm
          (%minibuffer-on-cancel minibuffer) on-cancel
          (%minibuffer-completion-function minibuffer) completion-function
          (%minibuffer-message minibuffer) nil)
    minibuffer))

(defgeneric minibuffer-message (minibuffer text)
  (:documentation
   "Display TEXT in MINIBUFFER as a transient status message: unlike
MINIBUFFER-ACTIVATE, this does not solicit input and does not affect
MINIBUFFER-ACTIVE-P. Returns MINIBUFFER.")
  (:method (minibuffer text)
    (setf (%minibuffer-message minibuffer) text)
    minibuffer))
