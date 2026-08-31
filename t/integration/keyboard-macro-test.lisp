(in-package #:loom/test)

(describe
  "keyboard macro commands"
  (it
    "covers the explicit command lifecycle and empty replay"
    (%with-minibuffer-state (minibuffer "")
      (start-kbd-macro)
      (expect (keyboard-macro-recording-p
               (editor-state-keyboard-macro *editor-state*))
              :to-be-truthy)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal
              "Defining keyboard macro")
      (end-kbd-macro)
      (expect (keyboard-macro-recording-p
               (editor-state-keyboard-macro *editor-state*))
              :to-be nil)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal
              "Keyboard macro defined")
      (end-kbd-macro)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal
              "No keyboard macro is being defined")
      (call-last-kbd-macro)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal
              "Keyboard macro is empty")))

  (it
    "removes the terminating control-x prefix from a recorded macro"
    (%with-minibuffer-state (minibuffer "")
      (let ((macro (make-keyboard-macro)))
        (setf (editor-state-keyboard-macro *editor-state*) macro)
        (start-kbd-macro)
        (keyboard-macro-record-event
         macro
         (make-keyboard-macro-event
          :kind :key
          :value (cons '(:control) #\x)))
        (end-kbd-macro)
        (expect (keyboard-macro-events macro) :to-be nil)
        (expect (keyboard-macro-recording-p macro) :to-be nil)
        (expect (loom:minibuffer-message-string minibuffer)
                :to-equal
                "Keyboard macro defined"))))

  (it
    "does not record an unbound modified key"
    (%with-minibuffer-state (minibuffer "")
      (let* ((keymap (make-keymap))
             (keymap-state (make-keymap-state keymap))
             (macro (make-keyboard-macro)))
        (setf (editor-state-keymap *editor-state*) keymap
              (editor-state-keyboard-macro *editor-state*) macro)
        (keyboard-macro-start-recording macro)
        (loom::%dispatch-key-event
         (cl-tty-kit:make-key-event
          :type :character :code #\q :modifiers '(:control))
         keymap-state)
        (expect (keyboard-macro-events macro) :to-be nil)
        (expect (keyboard-macro-recording-p macro) :to-be-truthy))))

  (it
    "records a self insertion and replays it through the key dispatch path"
    (let* ((*editor-state* (%fresh-editor-state "" :with-minibuffer t))
           (keymap (loom/application:install-default-keybindings (make-keymap)))
           (keymap-state (make-keymap-state keymap))
           (buffer (%selected-test-buffer)))
      (setf (editor-state-keymap *editor-state*) keymap
            (editor-state-keyboard-macro *editor-state*)
        (make-keyboard-macro))
        (flet ((dispatch (event)
               (loom::%dispatch-key-event event keymap-state)))
        (buffer-set-point buffer 0 0)
        (dispatch (cl-tty-kit:make-key-event
                   :type :character :code #\x :modifiers '(:control)))
        (dispatch (cl-tty-kit:make-key-event
                   :type :character :code #\( :modifiers nil))
        (dispatch (cl-tty-kit:make-key-event
                   :type :character :code #\a :modifiers nil))
        (dispatch (cl-tty-kit:make-key-event
                   :type :character :code #\x :modifiers '(:control)))
        (dispatch (cl-tty-kit:make-key-event
                   :type :character :code #\) :modifiers nil))
        (expect (keyboard-macro-recording-p
                 (editor-state-keyboard-macro *editor-state*))
                :to-be nil)
        (expect (length (keyboard-macro-events
                         (editor-state-keyboard-macro *editor-state*)))
                :to-equal 1)
        (dispatch (cl-tty-kit:make-key-event
                   :type :character :code #\x :modifiers '(:control)))
        (dispatch (cl-tty-kit:make-key-event
                   :type :character :code #\e :modifiers nil))
        (expect (buffer-text buffer) :to-equal "aa"))))

  (it
    "replays a bound key event through the keymap dispatcher"
    (%with-minibuffer-state (minibuffer "")
      (let* ((invoked nil)
             (keymap (make-keymap))
             (macro (make-keyboard-macro))
             (descriptor (cons nil #\q)))
        (keymap-define-key
         keymap
         (list descriptor)
         (lambda ()
           (setf invoked t)
           :done))
        (setf (editor-state-keymap *editor-state*) keymap
              (editor-state-keyboard-macro *editor-state*) macro)
        (keyboard-macro-start-recording macro)
        (keyboard-macro-record-event
         macro
         (make-keyboard-macro-event :kind :key :value descriptor))
        (keyboard-macro-stop-recording macro)
        (call-last-kbd-macro)
        (expect invoked :to-be-truthy)
        (expect (minibuffer-active-p minibuffer) :to-be-falsy)
        (expect (keyboard-macro-replaying-p macro) :to-be nil)))))

  (it
    "keeps recording when a modified key is unbound"
    (%with-minibuffer-state (minibuffer "")
      (let* ((keymap (make-keymap))
             (keymap-state (make-keymap-state keymap))
             (macro (make-keyboard-macro)))
        (declare (ignore minibuffer))
        (setf (editor-state-keymap *editor-state*) keymap
              (editor-state-keyboard-macro *editor-state*) macro)
        (keyboard-macro-start-recording macro)
        (loom::%dispatch-key-event
         (cl-tty-kit:make-key-event
          :type :character :code #\q :modifiers '(:control))
         keymap-state)
        (expect (keyboard-macro-events macro) :to-be nil)
        (expect (keyboard-macro-recording-p macro) :to-be-truthy))))
