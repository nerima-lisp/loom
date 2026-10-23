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

(defun keymap-state-dispatch (state key-event command-invoker)
  "Feed KEY-EVENT into STATE and invoke bindings through COMMAND-INVOKER.

COMMAND-INVOKER receives the command, normalized key sequence, and owning
keymap name. Prefixes return :PENDING and unbound keys return NIL."
  (setf (keymap-state-sequence state)
        (append (keymap-state-sequence state) (list key-event)))
  (multiple-value-bind (result owner)
      (keymap-lookup (keymap-state-keymap state)
                     (keymap-state-sequence state))
    (cond
      ((eq result :prefix)
       :pending)
      ((null result)
       (setf (keymap-state-sequence state) nil)
       nil)
      (t
       (let ((sequence
               (mapcar #'normalize-key-descriptor
                       (keymap-state-sequence state))))
         (setf (keymap-state-sequence state) nil)
         (funcall command-invoker result sequence (keymap-name owner)))))))
