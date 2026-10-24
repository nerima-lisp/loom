(in-package #:loom/feature/keyboard-macro)

(defun start-kbd-macro ()
  "Start recording a new keyboard macro (C-x ()."
  (keyboard-macro-start-recording (editor-state-keyboard-macro *editor-state*))
  (minibuffer-message (editor-state-minibuffer *editor-state*)
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
  (minibuffer-message (editor-state-minibuffer *editor-state*)
                      "Keyboard macro defined"))

(defun end-kbd-macro ()
  "Stop recording the current keyboard macro (C-x ))."
  (let ((macro (editor-state-keyboard-macro *editor-state*)))
    (if (keyboard-macro-recording-p macro)
        (%finish-kbd-macro macro)
        (minibuffer-message (editor-state-minibuffer *editor-state*)
                            "No keyboard macro is being defined"))))

(defun %replay-keyboard-macro-prefix-action (descriptor keymap-state argument)
  (and (null (keymap-state-sequence keymap-state))
       (prefix-argument-action descriptor argument)))

(defun %replay-keyboard-macro-dispatch-key (descriptor keymap-state argument)
  (record-undo-boundary-for-command nil)
  (let ((dispatch-result nil))
    (unwind-protect
        (let ((*current-prefix-argument* (prefix-argument-value-for-editor)))
          (setf dispatch-result (keymap-state-dispatch keymap-state
                                                       descriptor
                                                       (lambda
                                                           (command-id sequence
                                                                       keymap-name)
                                                         (invoke-key-command
                                                          command-id
                                                          :macro
                                                          sequence
                                                          keymap-name)))))
      (unless (eq dispatch-result :pending)
        (prefix-argument-reset argument)))))

(defun %replay-keyboard-macro-key-event (event keymap-state)
  (let* ((descriptor (keyboard-macro-event-value event))
         (argument (prefix-argument-for-editor))
         (prefix-action
          (%replay-keyboard-macro-prefix-action descriptor
                                                keymap-state
                                                argument)))
    (if prefix-action
        (if (eq (car prefix-action) :universal)
            (invoke-key-command "universal-argument"
                                :macro
                                (list descriptor)
                                "global")
            (apply-prefix-argument-action (car prefix-action)
                                          (cdr prefix-action)))
        (%replay-keyboard-macro-dispatch-key descriptor keymap-state argument))))

(defun %replay-keyboard-macro-event (event keymap-state)
  (flet ((key-input-handled-p (key-event)
           (eq
            (loom/core/editor-session:run-session-hooks :key-input
                                                        (loom/core/editor-session:editor-state-session
                                                         *editor-state*)
                                                        key-event
                                                        :macro)
            :handled)))
    (ecase (keyboard-macro-event-kind event)
      (:self-insert
       (let* ((value (keyboard-macro-event-value event))
              (key-event
               (cl-tty-kit:make-key-event :type :character :code value)))
         (unless (key-input-handled-p key-event)
           (record-undo-boundary-for-command t)
           (let ((*current-prefix-argument*
                  (consume-prefix-argument-for-editor)))
             (invoke-command "core/self-insert" :macro value)))))
      (:key
       (let* ((descriptor (keyboard-macro-event-value event))
              (code (cdr descriptor))
              (key-event
               (cl-tty-kit:make-key-event :type
                                          (if (characterp code)
                                              :character
                                              :special)
                                          :code
                                          code
                                          :modifiers
                                          (car descriptor))))
         (unless (key-input-handled-p key-event)
           (%replay-keyboard-macro-key-event event keymap-state)))))))

(defun call-last-kbd-macro ()
  "Replay the last recorded keyboard macro (C-x e)."
  (let* ((macro (editor-state-keyboard-macro *editor-state*))
         (events (keyboard-macro-events macro)))
    (if events
        (let ((keymap-state
               (make-keymap-state (editor-state-keymap *editor-state*))))
          (keyboard-macro-begin-replay macro)
          (unwind-protect
              (dolist (event events)
                (%replay-keyboard-macro-event event keymap-state))
            (keyboard-macro-end-replay macro)))
        (minibuffer-message (editor-state-minibuffer *editor-state*)
                            "Keyboard macro is empty"))))
