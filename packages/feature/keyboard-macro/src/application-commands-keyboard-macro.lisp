(in-package #:loom/feature/keyboard-macro)

(defun start-kbd-macro ()
  "Start recording a new keyboard macro (C-x ()."
  (keyboard-macro-start-recording
   (loom/core/editor-session:editor-state-keyboard-macro
    loom/core/editor-session:*editor-state*))
  (loom/core/minibuffer:minibuffer-message
   (loom/core/editor-session:editor-state-minibuffer
    loom/core/editor-session:*editor-state*)
   "Defining keyboard macro"))

(defun %kbd-macro-termination-event-p (event)
  (and event
       (eq (keyboard-macro-event-kind event) :key)
       (equal (keyboard-macro-event-value event) (cons '(:control) #\x))))

(defun %remove-kbd-macro-termination-prefix (macro)
  (when
      (%kbd-macro-termination-event-p
       (car (last (keyboard-macro-events macro))))
    (keyboard-macro-remove-last-event macro)))

(defun %finish-kbd-macro (macro)
  (%remove-kbd-macro-termination-prefix macro)
  (keyboard-macro-stop-recording macro)
  (loom/core/minibuffer:minibuffer-message
   (loom/core/editor-session:editor-state-minibuffer
    loom/core/editor-session:*editor-state*)
   "Keyboard macro defined"))

(defun end-kbd-macro ()
  "Stop recording the current keyboard macro (C-x ))."
  (let ((macro
         (loom/core/editor-session:editor-state-keyboard-macro
          loom/core/editor-session:*editor-state*)))
    (if (keyboard-macro-recording-p macro)
        (%finish-kbd-macro macro)
        (loom/core/minibuffer:minibuffer-message
         (loom/core/editor-session:editor-state-minibuffer
          loom/core/editor-session:*editor-state*)
         "No keyboard macro is being defined"))))

(defun %replay-keyboard-macro-prefix-action (descriptor keymap-state argument)
  (and (null (loom/core/command:keymap-state-sequence keymap-state))
       (loom:prefix-argument-action descriptor argument)))

(defun %replay-keyboard-macro-dispatch-key (descriptor keymap-state argument)
  (loom:record-undo-boundary-for-command nil)
  (let ((dispatch-result nil))
    (unwind-protect
        (let ((loom/core/command:*current-prefix-argument*
               (loom:prefix-argument-value-for-editor)))
          (setf dispatch-result (loom/core/command:keymap-state-dispatch
                                 keymap-state
                                 descriptor
                                 (lambda (command sequence keymap-name)
                                   (loom/core/command:invoke-command command
                                                                     :macro
                                                                     sequence
                                                                     keymap-name)))))
      (unless (eq dispatch-result :pending)
        (loom/core/command:prefix-argument-reset argument)))))

(defun %replay-keyboard-macro-key-event (event keymap-state)
  (let* ((descriptor (keyboard-macro-event-value event))
         (argument (loom:prefix-argument-for-editor))
         (prefix-action
          (%replay-keyboard-macro-prefix-action descriptor
                                                keymap-state
                                                argument)))
    (if prefix-action
        (if (eq (car prefix-action) :universal)
            (loom/core/command:invoke-command
             (getf
              (loom/core/command:find-extended-command-spec
               "universal-argument")
              :command)
             :macro
             (list descriptor)
             "global")
            (loom:apply-prefix-argument-action (car prefix-action)
                                               (cdr prefix-action)))
        (%replay-keyboard-macro-dispatch-key descriptor keymap-state argument))))

(defun %replay-keyboard-macro-event (event keymap-state)
  (ecase (keyboard-macro-event-kind event)
    (:self-insert
      (loom:record-undo-boundary-for-command t)
      (let ((loom/core/command:*current-prefix-argument*
             (loom:consume-prefix-argument-for-editor)))
        (loom:self-insert-command (keyboard-macro-event-value event))))
    (:key (%replay-keyboard-macro-key-event event keymap-state))))

(defun call-last-kbd-macro ()
  "Replay the last recorded keyboard macro (C-x e)."
  (let* ((macro
          (loom/core/editor-session:editor-state-keyboard-macro
           loom/core/editor-session:*editor-state*))
         (events (keyboard-macro-events macro)))
    (if events
        (let ((keymap-state
               (loom/core/command:make-keymap-state
                (loom/core/editor-session:editor-state-keymap
                 loom/core/editor-session:*editor-state*))))
          (keyboard-macro-begin-replay macro)
          (unwind-protect
              (dolist (event events)
                (%replay-keyboard-macro-event event keymap-state))
            (keyboard-macro-end-replay macro)))
        (loom/core/minibuffer:minibuffer-message
         (loom/core/editor-session:editor-state-minibuffer
          loom/core/editor-session:*editor-state*)
         "Keyboard macro is empty"))))
