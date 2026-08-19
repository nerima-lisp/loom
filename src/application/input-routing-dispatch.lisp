;;;; src/application/input-routing-dispatch.lisp
;;;;
;;;; Event routing orchestration after the key event is classified.
(in-package #:loom)

(defun %dispatch-key-event-action
    (event keymap-state decision)
  "Run the selected routing action for EVENT and return its dispatch outcome.
The outcome is NIL for an unbound key, :PENDING for an incomplete prefix, and
:HANDLED for an action that was selected even when its command returns NIL."
  (let ((minibuffer (input-routing-decision-minibuffer decision))
        (minibuffer-was-active
          (input-routing-decision-minibuffer-was-active decision))
        (descriptor (input-routing-decision-descriptor decision))
        (prefix-argument
          (input-routing-decision-prefix-argument decision))
        (prefix-action (input-routing-decision-prefix-action decision))
        (terminal-event-p
          (input-routing-decision-terminal-event-p decision))
        (self-insert-event-p
          (input-routing-decision-self-insert-event-p decision))
        (command (input-routing-decision-command decision)))
    (cond
      (minibuffer-was-active
       (minibuffer-handle-key minibuffer event)
       :handled)
      (terminal-event-p
       (loom/feature/terminal:terminal-handle-key-event event)
       :handled)
      (prefix-action
       (apply-prefix-argument-action (car prefix-action)
                                     (cdr prefix-action))
       :handled)
      (self-insert-event-p
       (%dispatch-self-insert-event event)
       :handled)
      (t
       (let ((dispatch-result
               (%dispatch-keymap-command
                keymap-state descriptor prefix-argument command)))
         (cond
           ((eq dispatch-result :pending) :pending)
           ((null command) nil)
           (t :handled)))))))

(defun %dispatch-key-event (event keymap-state)
  "Route one decoded KEY-EVENT to the minibuffer, prefix logic, self-insert,
terminal input, or keymap dispatch. Expected command errors are reported in
the minibuffer instead of unwinding the event loop; LOOM-QUIT still escapes
  because it is signalled, not raised as an ERROR."
  (%refresh-active-keymap keymap-state)
  (let* ((macro (editor-state-keyboard-macro *editor-state*))
         (decision (%classify-key-event event keymap-state))
         (dispatched-p nil))
    (handler-case
        (setf dispatched-p
              (%dispatch-key-event-action event keymap-state decision))
      (error (condition)
        (minibuffer-message
         (input-routing-decision-minibuffer decision)
         (format nil "~A" condition))))
    (when (and (eq dispatched-p :handled)
               (input-routing-decision-recording-before decision)
               macro
               (loom/feature/keyboard-macro:keyboard-macro-recording-p macro)
               (not (loom/feature/keyboard-macro:keyboard-macro-replaying-p macro)))
      (%record-keyboard-macro-event
       macro
       event
       (input-routing-decision-descriptor decision)
       (input-routing-decision-self-insert-event-p decision)))))
