(in-package #:loom)

(defun %prepare-dispatched-command-state (command)
  "Clear transient editor state before dispatching COMMAND when needed."
  (unless (or (eq command :prefix)
              (member command +yank-command-names+ :test #'equal)
              (member command +yank-preserving-command-names+ :test #'equal))
    (editor-state-clear-last-yank *editor-state*)))

(defun %dispatch-self-insert-event (event)
  "Execute EVENT as a self-insert command in the current editor state."
  (minibuffer-message (editor-state-minibuffer *editor-state*) nil)
  (record-undo-boundary-for-command t)
  (editor-state-clear-last-yank *editor-state*)
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (let ((*current-prefix-argument*
          (consume-prefix-argument-for-editor)))
    (invoke-key-command "core/self-insert"
                        :key
                        (list (key-event->descriptor event))
                        "global"
                        (cl-tty-kit:key-event-code event))))

(defun %dispatch-keymap-command
    (keymap-state descriptor prefix-argument command)
  "Dispatch DESCRIPTOR through KEYMAP-STATE and update transient command state."
  (unless (eq command :prefix)
    (minibuffer-message (editor-state-minibuffer *editor-state*) nil))
  (%prepare-dispatched-command-state command)
  (record-undo-boundary-for-command nil)
  (let ((dispatch-result nil))
    (unwind-protect
         (let ((*current-prefix-argument*
                 (and (loom/core/command:prefix-argument-active-p prefix-argument)
                     (prefix-argument-value-for-editor))))
           (setf dispatch-result
                 (keymap-state-dispatch
                  keymap-state
                  descriptor
                  (lambda (command-id sequence keymap-name)
                    (invoke-key-command command-id
                                        :key
                                        sequence
                                        keymap-name)))))
      (unless (eq dispatch-result :pending)
        (prefix-argument-reset prefix-argument)))
    (unless (eq dispatch-result :pending)
      (setf (editor-state-last-command-kill-p *editor-state*)
            (and (member command +kill-command-names+ :test (function equal)) t)))
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
