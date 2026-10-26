(in-package #:loom/test)

(describe "keyboard macro commands"
          (it "covers the explicit command lifecycle and empty replay"
              (%with-minibuffer-state (minibuffer "")
                                      (start-kbd-macro)
                                      (expect
                                       (keyboard-macro-recording-p
                                        (editor-state-keyboard-macro
                                         *editor-state*))
                                       :to-be-truthy)
                                      (expect
                                       (loom:minibuffer-message-string
                                        minibuffer)
                                       :to-equal
                                       "Defining keyboard macro")
                                      (end-kbd-macro)
                                      (expect
                                       (keyboard-macro-recording-p
                                        (editor-state-keyboard-macro
                                         *editor-state*))
                                       :to-be
                                       nil)
                                      (expect
                                       (loom:minibuffer-message-string
                                        minibuffer)
                                       :to-equal
                                       "Keyboard macro defined")
                                      (end-kbd-macro)
                                      (expect
                                       (loom:minibuffer-message-string
                                        minibuffer)
                                       :to-equal
                                       "No keyboard macro is being defined")
                                      (call-last-kbd-macro)
                                      (expect
                                       (loom:minibuffer-message-string
                                        minibuffer)
                                       :to-equal
                                       "Keyboard macro is empty")))
          (it "removes the terminating control-x prefix from a recorded macro"
              (%with-minibuffer-state (minibuffer "")
                                      (let ((macro (make-keyboard-macro)))
                                        (setf (editor-state-keyboard-macro
                                               *editor-state*) macro)
                                        (start-kbd-macro)
                                        (keyboard-macro-record-event macro
                                                                     (make-keyboard-macro-event
                                                                      :kind
                                                                      :key
                                                                      :value
                                                                      (cons
                                                                       '(:control)
                                                                       #\x)))
                                        (end-kbd-macro)
                                        (expect (keyboard-macro-events macro)
                                                :to-be
                                                nil)
                                        (expect
                                         (keyboard-macro-recording-p macro)
                                         :to-be
                                         nil)
                                        (expect
                                         (loom:minibuffer-message-string
                                          minibuffer)
                                         :to-equal
                                         "Keyboard macro defined"))))
          (it
           "keeps the final event when it is not the terminating control-x prefix"
           (%with-minibuffer-state (minibuffer "")
                                   (let ((macro (make-keyboard-macro)))
                                     (setf (editor-state-keyboard-macro
                                            *editor-state*) macro)
                                     (start-kbd-macro)
                                     (let ((event
                                            (make-keyboard-macro-event :kind
                                                                       :key
                                                                       :value
                                                                       (cons nil
                                                                             #\q))))
                                       (keyboard-macro-record-event macro event)
                                       (end-kbd-macro)
                                       (let ((events
                                              (keyboard-macro-events macro)))
                                         (expect (length events) :to-equal 1)
                                         (expect
                                          (keyboard-macro-event-kind
                                           (first events))
                                          :to-equal
                                          :key)
                                         (expect
                                          (keyboard-macro-event-value
                                           (first events))
                                          :to-equal
                                          (cons nil #\q))))
                                     (expect (keyboard-macro-recording-p macro)
                                             :to-be
                                             nil)
                                     (expect
                                      (loom:minibuffer-message-string
                                       minibuffer)
                                      :to-equal
                                      "Keyboard macro defined"))))
          (it "does not record an unbound modified key"
              (%with-minibuffer-state (minibuffer "")
                                      (let* ((keymap (make-keymap))
                                             (keymap-state
                                              (make-keymap-state keymap))
                                             (macro (make-keyboard-macro)))
                                        (setf (editor-state-keymap
                                               *editor-state*) keymap
                                              (editor-state-keyboard-macro
                                               *editor-state*) macro)
                                        (keyboard-macro-start-recording macro)
                                        (loom::%dispatch-key-event
                                         (cl-tty-kit:make-key-event :type
                                                                    :character
                                                                    :code
                                                                    #\q
                                                                    :modifiers
                                                                    '(:control))
                                         keymap-state)
                                        (expect (keyboard-macro-events macro)
                                                :to-be
                                                nil)
                                        (expect
                                         (keyboard-macro-recording-p macro)
                                         :to-be-truthy))))
          (it
           "records a self insertion and replays it through the key dispatch path"
           (let* ((*editor-state* (%fresh-editor-state "" :with-minibuffer t))
                  (keymap
                   (loom/application:install-default-keybindings (make-keymap)))
                  (keymap-state (make-keymap-state keymap))
                  (buffer (%selected-test-buffer)))
             (setf (editor-state-keymap *editor-state*) keymap
                   (editor-state-keyboard-macro *editor-state*) (make-keyboard-macro))
             (flet ((dispatch (event)
                      (loom::%dispatch-key-event event keymap-state)))
               (buffer-set-point buffer 0 0)
               (dispatch
                (cl-tty-kit:make-key-event :type
                                           :character
                                           :code
                                           #\x
                                           :modifiers
                                           '(:control)))
               (dispatch
                (cl-tty-kit:make-key-event :type
                                           :character
                                           :code
                                           #\(
                                           :modifiers
                                           nil))
               (dispatch
                (cl-tty-kit:make-key-event :type
                                           :character
                                           :code
                                           #\a
                                           :modifiers
                                           nil))
               (dispatch
                (cl-tty-kit:make-key-event :type
                                           :character
                                           :code
                                           #\x
                                           :modifiers
                                           '(:control)))
               (dispatch
                (cl-tty-kit:make-key-event :type
                                           :character
                                           :code
                                           #\)
                                           :modifiers
                                           nil))
               (expect
                (keyboard-macro-recording-p
                 (editor-state-keyboard-macro *editor-state*))
                :to-be
                nil)
               (expect
                (length
                 (keyboard-macro-events
                  (editor-state-keyboard-macro *editor-state*)))
                :to-equal
                1)
               (dispatch
                (cl-tty-kit:make-key-event :type
                                           :character
                                           :code
                                           #\x
                                           :modifiers
                                           '(:control)))
               (dispatch
                (cl-tty-kit:make-key-event :type
                                           :character
                                           :code
                                           #\e
                                           :modifiers
                                           nil))
               (expect (buffer-text buffer) :to-equal "aa"))))
          (it "replays a bound key event through the keymap dispatcher"
              (%with-minibuffer-state (minibuffer "")
                                      (let* ((invoked nil)
                                             (keymap (make-keymap))
                                             (macro (make-keyboard-macro))
                                             (descriptor (cons nil #\q)))
                                        (let ((command
                                               (lambda ()
                                                 (setf invoked t)
                                                 :done)))
                                          (%register-test-command command)
                                          (keymap-define-key keymap
                                                             (list descriptor)
                                                             command))
                                        (setf (editor-state-keymap
                                               *editor-state*) keymap
                                              (editor-state-keyboard-macro
                                               *editor-state*) macro)
                                        (keyboard-macro-start-recording macro)
                                        (keyboard-macro-record-event macro
                                                                     (make-keyboard-macro-event
                                                                      :kind
                                                                      :key
                                                                      :value
                                                                      descriptor))
                                        (keyboard-macro-stop-recording macro)
                                        (call-last-kbd-macro)
                                        (expect invoked :to-be-truthy)
                                        (expect
                                         (length (keyboard-macro-events macro))
                                         :to-equal
                                         1)
                                        (expect (minibuffer-active-p minibuffer)
                                                :to-be-falsy)
                                        (expect
                                         (keyboard-macro-replaying-p macro)
                                         :to-be
                                         nil))))
          (it "keeps a pending key sequence while replaying a macro"
              (%with-minibuffer-state (minibuffer "")
                                      (let* ((invoked nil)
                                             (keymap (make-keymap))
                                             (macro (make-keyboard-macro))
                                             (first-descriptor
                                              (cons '(:control) #\x))
                                             (second-descriptor (cons nil #\q)))
                                        (let ((command
                                               (lambda ()
                                                 (setf invoked t)
                                                 :done)))
                                          (%register-test-command command)
                                          (keymap-define-key keymap
                                                             (list
                                                              first-descriptor
                                                              second-descriptor)
                                                             command))
                                        (setf (editor-state-keymap
                                               *editor-state*) keymap
                                              (editor-state-keyboard-macro
                                               *editor-state*) macro)
                                        (keyboard-macro-start-recording macro)
                                        (keyboard-macro-record-event macro
                                                                     (make-keyboard-macro-event
                                                                      :kind
                                                                      :key
                                                                      :value
                                                                      first-descriptor))
                                        (keyboard-macro-record-event macro
                                                                     (make-keyboard-macro-event
                                                                      :kind
                                                                      :key
                                                                      :value
                                                                      second-descriptor))
                                        (keyboard-macro-stop-recording macro)
                                        (call-last-kbd-macro)
                                        (expect invoked :to-be-truthy)
                                        (expect (minibuffer-active-p minibuffer)
                                                :to-be-falsy)
                                        (expect
                                         (keyboard-macro-replaying-p macro)
                                         :to-be
                                         nil))))
          (it
           "routes keyboard-macro events through key-input hooks before dispatch"
           (%with-minibuffer-state (minibuffer "")
                                   (let* ((loom/core/editor-session::*session-hooks*
                                           (make-hash-table :test (function eq)))
                                          (invoked nil)
                                          (events nil)
                                          (keymap (make-keymap))
                                          (macro (make-keyboard-macro))
                                          (descriptor (cons nil #\q))
                                          (session
                                           (loom/core/editor-session:editor-state-session
                                            *editor-state*)))
                                     (let ((command
                                            (lambda ()
                                              (setf invoked t)
                                              :done)))
                                       (%register-test-command command)
                                       (keymap-define-key keymap
                                                          (list descriptor)
                                                          command))
                                     (setf (editor-state-keymap *editor-state*) keymap
                                           (editor-state-keyboard-macro
                                            *editor-state*) macro)
                                     (loom/core/editor-session:register-session-hook
                                      :key-input
                                      :feature/keyboard-macro
                                      (lambda (received-session key-event route)
                                        (expect received-session :to-be session)
                                        (expect
                                         (cl-tty-kit:key-event-type key-event)
                                         :to-be
                                         :character)
                                        (push
                                         (list route
                                               (cl-tty-kit:key-event-code
                                                key-event))
                                         events)
                                        (if (eql
                                             (cl-tty-kit:key-event-code
                                              key-event)
                                              #\x)
                                            :handled
                                            :pass)))
                                     (keyboard-macro-start-recording macro)
                                     (keyboard-macro-record-event macro
                                                                  (make-keyboard-macro-event
                                                                   :kind
                                                                   :key
                                                                   :value
                                                                   descriptor))
                                     (keyboard-macro-record-event macro
                                                                  (make-keyboard-macro-event
                                                                   :kind
                                                                   :self-insert
                                                                   :value
                                                                   #\x))
                                     (keyboard-macro-stop-recording macro)
                                     (call-last-kbd-macro)
                                     (expect invoked :to-be-truthy)
                                     (expect (reverse events)
                                             :to-equal
                                             (list (list :macro #\q)
                                                   (list :macro #\x)))
                                     (expect
                                      (buffer-text (%selected-test-buffer))
                                      :to-equal
                                      "")
                                     (expect (keyboard-macro-replaying-p macro)
                                             :to-be
                                             nil)))))

(it "keeps recording when a modified key is unbound"
    (%with-minibuffer-state (minibuffer "")
                            (let* ((keymap (make-keymap))
                                   (keymap-state (make-keymap-state keymap))
                                   (macro (make-keyboard-macro)))
                              (declare (ignore minibuffer))
                              (setf (editor-state-keymap *editor-state*) keymap
                                    (editor-state-keyboard-macro *editor-state*) macro)
                              (keyboard-macro-start-recording macro)
                              (loom::%dispatch-key-event
                               (cl-tty-kit:make-key-event :type
                                                          :character
                                                          :code
                                                          #\q
                                                          :modifiers
                                                          '(:control))
                               keymap-state)
                              (expect (keyboard-macro-events macro) :to-be nil)
                              (expect (keyboard-macro-recording-p macro)
                                      :to-be-truthy))))

(it
 "replays a bound key through the selected buffer keymap"
 (%with-minibuffer-state (minibuffer "")
  (let* ((local-invocations 0)
         (global-invocations 0)
         (global-keymap (make-keymap))
         (mode-keymap (make-keymap))
         (macro (make-keyboard-macro))
         (buffer (%selected-test-buffer))
         (descriptor (cons '(:control) #\q))
         (keymap-state (make-keymap-state global-keymap))
         (event
          (cl-tty-kit:make-key-event :type :character :code #\q :modifiers '(:control))))
   (let ((global-command (lambda () (incf global-invocations)))
         (mode-command (lambda () (incf local-invocations))))
    (%register-test-command global-command)
    (%register-test-command mode-command)
    (keymap-define-key global-keymap (list descriptor) global-command)
    (keymap-define-key mode-keymap (list descriptor) mode-command))
   (setf (editor-state-keymap *editor-state*) global-keymap
         (editor-state-keyboard-macro *editor-state*) macro)
   (with-replaced-function
    (loom/core/command:keymap-for-buffer
     (lambda (session selected-buffer fallback)
      (declare (ignore session))
      (if (eq selected-buffer buffer) mode-keymap fallback)))
    (keyboard-macro-start-recording macro)
    (loom::%dispatch-key-event event keymap-state)
    (keyboard-macro-stop-recording macro)
    (expect local-invocations :to-equal 1)
    (call-last-kbd-macro)
    (expect local-invocations :to-equal 2)
    (expect global-invocations :to-equal 0)))))
(it
 "records minibuffer input and replays an M-x command"
 (%with-minibuffer-state (minibuffer "")
  (let* ((buffer (%selected-test-buffer))
         (keymap (loom/application:install-default-keybindings (make-keymap)))
         (keymap-state (make-keymap-state keymap))
         (macro (make-keyboard-macro))
         (traces nil))
   (setf (editor-state-keymap *editor-state*) keymap
         (editor-state-keyboard-macro *editor-state*) macro)
   (loom/core/buffer:buffer-insert-string buffer "x")
   (buffer-set-point buffer 0 0)
   (with-replaced-function
    (loom/core/command:record-command-trace
     (lambda (id route &optional entry)
      (push (list id route entry) traces)
      nil))
    (flet ((dispatch (code &optional (modifiers nil) (type :character))
             (loom::%dispatch-key-event
              (cl-tty-kit:make-key-event :type type :code code :modifiers modifiers)
              keymap-state)))
     (keyboard-macro-start-recording macro)
     (dispatch #\x '(:alt))
     (loop for character across "delete-char"
           do (dispatch character))
     (dispatch :enter nil :special)
     (keyboard-macro-stop-recording macro)
     (expect (length (keyboard-macro-events macro)) :to-equal 13)
     (expect (minibuffer-active-p minibuffer) :to-be-falsy)
     (loom/core/buffer:buffer-insert-string buffer "x")
     (buffer-set-point buffer 0 0)
     (call-last-kbd-macro)
     (expect (buffer-text buffer) :to-equal "")
     (expect (minibuffer-active-p minibuffer) :to-be-falsy)
     (expect
      (find-if (lambda (trace)
                 (and (equal (first trace) "delete-char")
                      (eq (second trace) :macro)))
               traces)
      :to-be-truthy))))))
