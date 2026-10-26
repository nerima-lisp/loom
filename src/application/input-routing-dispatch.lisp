(in-package #:loom)

(defun %dispatch-keymap-action (keymap-state decision)
  (let ((dispatch-result
         (%dispatch-keymap-command keymap-state
                                   (input-routing-decision-descriptor decision)
                                   (input-routing-decision-prefix-argument
                                    decision)
                                   (input-routing-decision-command decision))))
    (cond
      ((eq dispatch-result :pending) :pending)
      ((null (input-routing-decision-command decision)) nil)
      (t :handled))))

(defun %dispatch-key-event-action (event keymap-state decision)
  "Run the selected routing action for EVENT and return its dispatch outcome.
The outcome is NIL for an unbound key, :PENDING for an incomplete prefix, and
:HANDLED for an action that was selected even when its command returns NIL."
  (let ((minibuffer (input-routing-decision-minibuffer decision))
        (minibuffer-was-active
         (input-routing-decision-minibuffer-was-active decision))
        (prefix-action (input-routing-decision-prefix-action decision))
        (descriptor (input-routing-decision-descriptor decision))
        (terminal-event-p (input-routing-decision-terminal-event-p decision))
        (self-insert-event-p
         (input-routing-decision-self-insert-event-p decision)))
    (cond
      (minibuffer-was-active
        (minibuffer-handle-key minibuffer event)
        :handled)
      ((%completion-popup-handle-key event) :handled)
      (terminal-event-p
        (loom/feature/terminal:terminal-handle-key-event event)
        :handled)
      (prefix-action
        (if (eq (car prefix-action) :universal)
            (invoke-key-command "universal-argument"
                                :key
                                (list descriptor)
                                "global")
            (apply-prefix-argument-action (car prefix-action)
                                          (cdr prefix-action)))
        :handled)
      (self-insert-event-p
        (%dispatch-self-insert-event event)
        :handled)
      (t (%dispatch-keymap-action keymap-state decision)))))

(defun %record-dispatched-key-event (macro event decision)
  (when
      (and (input-routing-decision-recording-before decision)
           macro
           (loom/feature/keyboard-macro:keyboard-macro-recording-p macro)
           (not (loom/feature/keyboard-macro:keyboard-macro-replaying-p macro)))
    (%record-keyboard-macro-event macro
                                  event
                                  (input-routing-decision-descriptor decision)
                                  (input-routing-decision-self-insert-event-p
                                   decision))))

(defun %dispatch-key-event (event keymap-state
                                  &optional
                                  (run-key-input-hook-p t))
  "Run the key-input hook when requested, then default routing and dispatch."
  (let* ((active-keymap (%refresh-active-keymap keymap-state))
         (macro (editor-state-keyboard-macro *editor-state*))
         (decision (%classify-key-event event keymap-state active-keymap))
         (session (editor-state-session *editor-state*))
         (dispatched-p nil))
    (handler-case (setf dispatched-p (if (and run-key-input-hook-p
                                              (eq
                                               (loom/core/editor-session:run-session-hooks
                                                :key-input
                                                session
                                                event
                                                :key)
                                               :handled))
                                         :handled
                                         (%dispatch-key-event-action event
                                                                     keymap-state
                                                                     decision)))
      (error (condition)
        (minibuffer-message (input-routing-decision-minibuffer decision)
                            (princ-to-string condition))))
    (when (member dispatched-p '(:handled :pending) :test #'eq)
      (%record-dispatched-key-event macro event decision))))
