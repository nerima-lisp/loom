;;;; t/integration/input-routing-keymap-test.lisp

(in-package #:loom/test)

(describe
  "%dispatch-key-event"
  (it
    "dispatches self-insert through the default keymap at point only"
    (let* ((state (%fresh-editor-state (format nil "one~%two~%three")))
           (*editor-state* state)
           (keymap (loom/application:install-default-keybindings (make-keymap)))
           (keymap-state (make-keymap-state keymap))
           (buffer (%selected-test-buffer)))
      (setf (editor-state-minibuffer state) (make-minibuffer)
            (editor-state-keymap state) keymap)
      (buffer-set-point buffer 0 1)
      (loom::%dispatch-key-event
       (cl-tty-kit:make-key-event :type :character :code #\X)
       keymap-state)
      (expect (buffer-text buffer) :to-equal (format nil "oXne~%two~%three"))
      (expect (buffer-point-line buffer) :to-equal 0)
      (expect (buffer-point-column buffer) :to-equal 2)))

  (it
    "dispatches copy, yank, and yank-pop through the default keymap"
    (let* ((state (%fresh-editor-state "hello world"))
           (*editor-state* state)
           (keymap (loom/application:install-default-keybindings (make-keymap)))
           (keymap-state (make-keymap-state keymap)))
      (setf (editor-state-minibuffer state) (make-minibuffer)
            (editor-state-keymap state) keymap)
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 0)
        (buffer-set-mark buffer 0 5)
        (loom::%dispatch-key-event
         (cl-tty-kit:make-key-event :type :character :code #\w :modifiers '(:alt))
         keymap-state)
        (expect (buffer-text buffer) :to-equal "hello world")
        (expect (first (editor-state-kill-ring state)) :to-equal "hello")
        (setf (editor-state-kill-ring state) '("hello" "goodbye"))
        (buffer-set-point buffer 0 11)
        (loom::%dispatch-key-event
         (cl-tty-kit:make-key-event :type :character :code #\y :modifiers '(:control))
         keymap-state)
        (expect (buffer-text buffer) :to-equal "hello worldhello")
        (loom::%dispatch-key-event
         (cl-tty-kit:make-key-event :type :character :code #\y :modifiers '(:alt))
         keymap-state)
        (expect (buffer-text buffer) :to-equal "hello worldgoodbye"))))

  (it
    "coalesces adjacent kill-region commands dispatched through the keymap"
    (let* ((state (%fresh-editor-state "abcdef"))
           (*editor-state* state)
           (keymap (loom/application:install-default-keybindings (make-keymap)))
           (keymap-state (make-keymap-state keymap)))
      (setf (editor-state-minibuffer state) (make-minibuffer)
            (editor-state-keymap state) keymap)
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 0)
        (buffer-set-mark buffer 0 2)
        (loom::%dispatch-key-event
         (cl-tty-kit:make-key-event :type :character :code #\w :modifiers '(:control))
         keymap-state)
        (buffer-set-point buffer 0 0)
        (buffer-set-mark buffer 0 1)
        (loom::%dispatch-key-event
         (cl-tty-kit:make-key-event :type :character :code #\w :modifiers '(:control))
         keymap-state)
        (expect (buffer-text buffer) :to-equal "def")
        (expect (first (editor-state-kill-ring state)) :to-equal "abc"))))

  (it
    "reports a dispatched command's error in the minibuffer instead of propagating it"
    (let* ((state (%fresh-editor-state "hi"))
           (minibuffer (make-minibuffer))
           (*editor-state* state)
           (keymap (make-keymap))
           (keymap-state (make-keymap-state keymap)))
      (setf (editor-state-minibuffer state) minibuffer)
      (keymap-define-key keymap (list (cons '(:control) #\z))
                         (lambda () (error "boom")))
      (loom::%dispatch-key-event
       (cl-tty-kit:make-key-event :type :character :code #\z :modifiers '(:control))
       keymap-state)
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "boom"))))
