(in-package #:loom/test)

(describe
  "keyboard macro commands"
  (it
    "records a self insertion and replays it through the key dispatch path"
    (let* ((*editor-state* (%fresh-editor-state "" :with-minibuffer t))
           (keymap (loom::install-default-keybindings (make-keymap)))
           (keymap-state (make-keymap-state keymap))
           (buffer (%selected-test-buffer)))
      (setf (editor-state-keymap *editor-state*) keymap
            (editor-state-keyboard-macro *editor-state*)
            (make-keyboard-macro))
        (flet ((dispatch (event)
               (declare (ignore *editor-state*))
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
        (expect (buffer-text buffer) :to-equal "aa")))))
