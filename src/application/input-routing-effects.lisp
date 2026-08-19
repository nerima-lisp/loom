;;;; src/application/input-routing-effects.lisp
;;;;
;;;; Mutating helpers used by input-routing dispatch after classification.
(in-package #:loom)

(defun %prepare-dispatched-command-state (command)
  "Clear transient editor state before dispatching COMMAND when needed."
  (unless (or (eq command :prefix)
              (member command +yank-command-names+ :test #'eq)
              (loom/feature/multiple-cursors:multiple-cursors-preserving-command-p
               command))
    (%clear-last-yank)
    (loom/feature/multiple-cursors:multiple-cursors-reset)))

(defun %dispatch-self-insert-event (event)
  "Execute EVENT as a self-insert command in the current editor state."
  (record-undo-boundary-for-command t)
  (%clear-last-yank)
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (let ((*current-prefix-argument*
          (consume-prefix-argument-for-editor)))
    (self-insert-command (cl-tty-kit:key-event-code event))))

(defun %dispatch-keymap-command
    (keymap-state descriptor prefix-argument command)
  "Dispatch DESCRIPTOR through KEYMAP-STATE and update transient command state."
  (%prepare-dispatched-command-state command)
  (record-undo-boundary-for-command nil)
  (let ((dispatch-result nil))
    (unwind-protect
         (let ((*current-prefix-argument*
                 (prefix-argument-value-for-editor)))
           (setf dispatch-result
                 (keymap-state-dispatch keymap-state descriptor)))
      (unless (eq dispatch-result :pending)
        (prefix-argument-reset prefix-argument)))
    (unless (eq dispatch-result :pending)
      (setf (editor-state-last-command-kill-p *editor-state*)
            (and (member command +kill-command-names+ :test #'eq) t)))
    dispatch-result))

(defun %record-keyboard-macro-event
    (macro event descriptor self-insert-event-p)
  "Record the already-dispatched EVENT in MACRO."
  (loom/feature/keyboard-macro:keyboard-macro-record-event
   macro
   (loom/feature/keyboard-macro:make-keyboard-macro-event
    :kind (if self-insert-event-p :self-insert :key)
    :value (if self-insert-event-p
               (cl-tty-kit:key-event-code event)
               descriptor))))
