;;;; packages/feature/keyboard-macro/src/application-commands-keyboard-macro.lisp
;;;;
;;;; Application layer: start/stop/replay commands for the keyboard-macro
;;;; domain value.  Input recording itself is completed by main.lisp after a
;;;; command succeeds, so command keys cannot accidentally become part of the
;;;; macro that they control.
(in-package #:loom)

(defun %keyboard-macro-for-editor ()
  "Return the current state's keyboard macro, creating it for old fixtures."
  (or (editor-state-keyboard-macro *editor-state*)
      (setf (editor-state-keyboard-macro *editor-state*)
            (make-keyboard-macro))))

(defun start-kbd-macro ()
  "Start recording a new keyboard macro (C-x ()."
  (keyboard-macro-start-recording (%keyboard-macro-for-editor))
  (minibuffer-message (editor-state-minibuffer *editor-state*)
                      "Defining keyboard macro"))

(defun end-kbd-macro ()
  "Stop recording the current keyboard macro (C-x ))."
  (let ((macro (%keyboard-macro-for-editor)))
    (if (keyboard-macro-recording-p macro)
        (progn
          ;; The dispatcher records the C-x prefix after it is successfully
          ;; dispatched.  C-x ) is the command that terminates recording, so
          ;; that prefix is not part of the user's macro and must be removed.
          (let ((last-event (car (last (keyboard-macro-events macro)))))
            (when (and last-event
                       (eq (keyboard-macro-event-kind last-event) :key)
                       (equal (keyboard-macro-event-value last-event)
                              (cons '(:control) #\x)))
              (keyboard-macro-remove-last-event macro)))
          (keyboard-macro-stop-recording macro)
          (minibuffer-message (editor-state-minibuffer *editor-state*)
                              "Keyboard macro defined"))
        (minibuffer-message (editor-state-minibuffer *editor-state*)
                            "No keyboard macro is being defined"))))

(defun %replay-keyboard-macro-event (event keymap-state)
  (ecase (keyboard-macro-event-kind event)
    (:self-insert
     (%record-undo-boundary-for-command t)
     (let ((*current-prefix-argument*
             (%consume-prefix-argument-for-editor)))
       (self-insert-command (keyboard-macro-event-value event))))
    (:key
     (let* ((descriptor (keyboard-macro-event-value event))
            (argument (%prefix-argument-for-editor))
            (prefix-action
              (and (null (keymap-state-sequence keymap-state))
                   (%prefix-argument-action descriptor argument))))
       (if prefix-action
           (%apply-prefix-argument-action (car prefix-action)
                                          (cdr prefix-action))
           (progn
             (%record-undo-boundary-for-command nil)
             (let ((dispatch-result nil))
               (unwind-protect
                    (let ((*current-prefix-argument*
                            (%prefix-argument-value-for-editor)))
                      (setf dispatch-result
                            (keymap-state-dispatch keymap-state descriptor)))
                 (unless (eq dispatch-result :pending)
                   (prefix-argument-reset argument))))))))))

(defun call-last-kbd-macro ()
  "Replay the last recorded keyboard macro (C-x e)."
  (let* ((macro (%keyboard-macro-for-editor))
         (events (keyboard-macro-events macro)))
    (if (null events)
        (minibuffer-message (editor-state-minibuffer *editor-state*)
                            "Keyboard macro is empty")
        (let ((keymap-state (make-keymap-state
                             (editor-state-keymap *editor-state*))))
          (keyboard-macro-begin-replay macro)
          (unwind-protect
               (dolist (event events)
                 (%replay-keyboard-macro-event event keymap-state))
            (keyboard-macro-end-replay macro))))))
