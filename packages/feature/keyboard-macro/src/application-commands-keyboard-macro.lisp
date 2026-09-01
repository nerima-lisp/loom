;;;; packages/feature/keyboard-macro/src/application-commands-keyboard-macro.lisp
;;;;
;;;; Application layer: start/stop/replay commands for the keyboard-macro
;;;; domain value.  Input recording itself is completed by main.lisp after a
;;;; command succeeds, so command keys cannot accidentally become part of the
;;;; macro that they control.
(in-package #:loom/feature/keyboard-macro)

(defun start-kbd-macro ()
  "Start recording a new keyboard macro (C-x ()."
  (keyboard-macro-start-recording
   (editor-state-keyboard-macro *editor-state*))
  (minibuffer-message (editor-state-minibuffer *editor-state*)
                      "Defining keyboard macro"))

(defun end-kbd-macro ()
  "Stop recording the current keyboard macro (C-x ))."
  (let ((macro (editor-state-keyboard-macro *editor-state*)))
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

(defun %replay-keyboard-macro-prefix-action (descriptor keymap-state argument)
  (and (null (loom:keymap-state-sequence keymap-state))
       (loom:prefix-argument-action descriptor argument)))

(defun %replay-keyboard-macro-dispatch-key (descriptor keymap-state argument)
  (loom:record-undo-boundary-for-command nil)
  (let ((dispatch-result nil))
    (unwind-protect
         (let ((loom:*current-prefix-argument*
                 (loom:prefix-argument-value-for-editor)))
           (setf dispatch-result
                 (keymap-state-dispatch keymap-state descriptor)))
      (unless (eq dispatch-result :pending)
        (prefix-argument-reset argument)))))

(defun %replay-keyboard-macro-key-event (event keymap-state)
  (let* ((descriptor (keyboard-macro-event-value event))
         (argument (loom:prefix-argument-for-editor))
         (prefix-action
           (%replay-keyboard-macro-prefix-action descriptor keymap-state
                                                 argument)))
    (if prefix-action
        (loom:apply-prefix-argument-action (car prefix-action)
                                            (cdr prefix-action))
        (%replay-keyboard-macro-dispatch-key descriptor keymap-state
                                              argument))))

(defun %replay-keyboard-macro-event (event keymap-state)
  (ecase (keyboard-macro-event-kind event)
    (:self-insert
     (loom:record-undo-boundary-for-command t)
     (let ((loom:*current-prefix-argument*
             (loom:consume-prefix-argument-for-editor)))
       (loom:self-insert-command (keyboard-macro-event-value event))))
    (:key
     (%replay-keyboard-macro-key-event event keymap-state))))

(defun call-last-kbd-macro ()
  "Replay the last recorded keyboard macro (C-x e)."
  (let* ((macro (editor-state-keyboard-macro *editor-state*))
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
