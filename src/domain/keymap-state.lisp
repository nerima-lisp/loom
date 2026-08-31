;;;; src/domain/keymap-state.lisp
;;;;
;;;; Domain layer: incremental keymap dispatch state. This file owns the
;;;; state machine that accumulates key descriptors across calls and resolves
;;;; them through src/domain/keymap.lisp's trie lookup.
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

(defun keymap-state-dispatch (state key-event)
  "Feed one KEY-EVENT (as returned by CL-TTY-KIT:DECODE-INPUT-CHUNK) into
STATE. Appends KEY-EVENT to the sequence accumulated so far and looks it up
in STATE's keymap:

- If the accumulated sequence is a prefix (KEYMAP-LOOKUP returns :PREFIX),
  returns the keyword :PENDING and keeps the accumulated sequence for the
  next call.
- If the accumulated sequence resolves to a bound command, invokes that
  command (a function of zero arguments) and returns its return value,
  resetting STATE's accumulated sequence to empty.
- If the accumulated sequence is bound to nothing, resets STATE's
  accumulated sequence to empty and returns NIL."
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
       (funcall result)))))
