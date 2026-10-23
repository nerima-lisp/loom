(in-package #:loom)

(defstruct (keymap-state (:constructor %make-keymap-state))
  keymap
  root-keymap
  (sequence nil))

(defun make-keymap-state (keymap)
  "Create and return a new dispatch state for KEYMAP that tracks
in-progress prefix-key accumulation across successive KEYMAP-STATE-DISPATCH
calls, starting with no keys accumulated."
  (%make-keymap-state :keymap keymap :root-keymap keymap :sequence nil))

(defun keymap-state-dispatch (state key-event &optional command-invoker)
  "Feed KEY-EVENT into STATE and invoke a bound command through COMMAND-INVOKER.

COMMAND-INVOKER, when present, receives the command designator. Prefixes return
:PENDING and unbound keys return NIL."
  (setf (keymap-state-sequence state)
        (append (keymap-state-sequence state) (list key-event)))
  (let ((result (keymap-lookup (keymap-state-keymap state)
                               (keymap-state-sequence state))))
    (cond
      ((eq result :prefix)
       :pending)
      ((null result)
       (setf (keymap-state-sequence state) nil)
       nil)
      (t
       (setf (keymap-state-sequence state) nil)
       (if command-invoker
           (funcall command-invoker result)
           (funcall result))))))
