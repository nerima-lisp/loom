(in-package #:loom/core/minibuffer)
(defvar *message-sinks* nil)
(defun register-message-sink (owner function)
  "Register FUNCTION to receive minibuffer messages for OWNER.

OWNER must be a keyword. A later registration for the same owner replaces its
function without changing its position. Sinks receive message text in
registration order. Callback errors propagate and stop dispatch."
  (unless (keywordp owner)
    (error "Message sink owner must be a keyword: ~S" owner))
  (check-type function function)
  (let ((entry (assoc owner *message-sinks* :test (function eq))))
    (if entry
        (setf (cdr entry) function)
        (setf *message-sinks*
              (append *message-sinks* (list (cons owner function))))))
  function)

(defun %minibuffer-deactivate (minibuffer)
  "Reset MINIBUFFER to the inactive state, discarding prompt/input/callbacks."
  (setf (%minibuffer-active-p minibuffer) nil
        (%minibuffer-prompt minibuffer) nil
        (%minibuffer-input minibuffer) ""
        (%minibuffer-point minibuffer) 0
        (%minibuffer-on-confirm minibuffer) nil
        (%minibuffer-on-cancel minibuffer) nil
        (%minibuffer-on-change minibuffer) nil
        (%minibuffer-on-key minibuffer) nil
        (%minibuffer-completion-function minibuffer) nil
        (%minibuffer-completion-candidates minibuffer) nil
        (%minibuffer-history-origin minibuffer) nil)
  (let ((history (%minibuffer-history minibuffer)))
    (when history
      (history-kit:history-reset-navigation history)))
  minibuffer)
(defun minibuffer-deactivate (minibuffer)
  "Deactivate MINIBUFFER, clearing prompt/input and callbacks without invoking them. Returns MINIBUFFER."
  (%minibuffer-deactivate minibuffer))

(defun %minibuffer-validate-function-option (value name)
  (when (and value (not (functionp value)))
    (error "~A must be a function or NIL: ~S" name value))
  value)

(defun minibuffer-activate (minibuffer prompt &key on-confirm on-cancel
                                                   on-change on-key
                                                   completion-function)
  "Begin an interactive input session in MINIBUFFER, displaying PROMPT and
accepting keystrokes via MINIBUFFER-HANDLE-KEY. ON-CONFIRM, when supplied, is
a function of one argument (the final input string) called when the user
confirms the input (e.g. RET). ON-CANCEL, when supplied, is a function of
zero arguments called when the user cancels (e.g. C-g). ON-CHANGE, when
supplied, is a function of the current input string called after every edit to
it, which is what lets a prompt act while it is still being typed rather than
only at RET. ON-KEY, when supplied, is a function of one key event called
before MINIBUFFER-HANDLE-KEY classifies it; returning true consumes the event,
which is how a caller keeps a chord like C-s from being typed into the input.
COMPLETION-FUNCTION, when supplied, is a function of the current input string
that returns a list of candidate strings for Tab completion. Returns
MINIBUFFER."
  (%minibuffer-validate-function-option completion-function ":completion-function")
  (%minibuffer-validate-function-option on-change ":on-change")
  (%minibuffer-validate-function-option on-key ":on-key")
  (let ((history (%minibuffer-history minibuffer)))
    (when history
      (history-kit:history-reset-navigation history)))
  (setf (%minibuffer-active-p minibuffer) t
        (%minibuffer-prompt minibuffer) prompt
        (%minibuffer-input minibuffer) ""
        (%minibuffer-point minibuffer) 0
        (%minibuffer-on-confirm minibuffer) on-confirm
        (%minibuffer-on-cancel minibuffer) on-cancel
        (%minibuffer-on-change minibuffer) on-change
        (%minibuffer-on-key minibuffer) on-key
        (%minibuffer-completion-function minibuffer) completion-function
        (%minibuffer-completion-candidates minibuffer) nil
        (%minibuffer-history-origin minibuffer) nil
        (%minibuffer-message minibuffer) nil)
  minibuffer)

(defun minibuffer-set-prompt (minibuffer prompt)
  "Replace an active MINIBUFFER's PROMPT without disturbing its input.

A prompt that reports state -- incremental search saying it is now failing --
has to change mid-session, and it cannot use MINIBUFFER-MESSAGE for that: the
message line is the same row the active prompt occupies. Inactive minibuffers
ignore this. Returns MINIBUFFER."
  (when (%minibuffer-active-p minibuffer)
    (setf (%minibuffer-prompt minibuffer) prompt))
  minibuffer)

(defun minibuffer-message (minibuffer text)
  "Display TEXT in MINIBUFFER and notify registered message sinks.

This does not solicit input or affect MINIBUFFER-ACTIVE-P. Sink callbacks run
synchronously in registration order after the message is stored. Callback
errors propagate and stop dispatch. Returns MINIBUFFER."
  (setf (%minibuffer-message minibuffer) text)
  (dolist (sink
           (mapcar (lambda (entry) (cons (car entry) (cdr entry)))
                   *message-sinks*))
    (funcall (cdr sink) text))
  minibuffer)
