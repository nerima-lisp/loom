(in-package #:loom/core/command)

(defstruct
    (keymap-state (:constructor %make-keymap-state) (:conc-name %keymap-state-))
  (keymap nil)
  (root-keymap nil)
  (sequence nil))

(defun keymap-state-use-keymap (state keymap)
  "Select KEYMAP for STATE and clear pending keys if it changes."
  (check-type state keymap-state)
  (check-type keymap keymap)
  (unless (eq (%keymap-state-keymap state) keymap)
    (setf (%keymap-state-sequence state) nil))
  (setf (%keymap-state-keymap state) keymap)
  state)

(defun keymap-state-sequence (state)
  "Return the accumulated key sequence for STATE."
  (%keymap-state-sequence state))

(defun make-keymap-state (keymap)
  "Create and return a new dispatch state for KEYMAP that tracks
in-progress prefix-key accumulation across successive KEYMAP-STATE-DISPATCH
calls, starting with no keys accumulated."
  (%make-keymap-state :keymap keymap :root-keymap keymap :sequence nil))

(defun keymap-state-dispatch (state key-event command-invoker)
  "Feed KEY-EVENT into STATE and invoke bindings through COMMAND-INVOKER.

COMMAND-INVOKER receives the command, normalized key sequence, and owning
keymap name. Prefixes return :PENDING and unbound keys return NIL."
  (setf (%keymap-state-sequence state) (append (%keymap-state-sequence state)
                                               (list key-event)))
  (multiple-value-bind (result owner)
      (keymap-lookup (%keymap-state-keymap state)
                     (%keymap-state-sequence state))
    (cond
      ((eq result :prefix) :pending)
      ((null result)
        (setf (%keymap-state-sequence state) nil)
        nil)
      (t
       (let ((sequence
              (mapcar #'normalize-key-descriptor (%keymap-state-sequence state))))
         (setf (%keymap-state-sequence state) nil)
         (funcall command-invoker result sequence (keymap-name owner)))))))
