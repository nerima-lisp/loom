;;;; t/integration/input-routing-minibuffer-test.lisp

(in-package #:loom/test)

(describe
  "%dispatch-key-event"
  (it
    "self-inserts a plain unmodified character when no prefix key is pending"
    (let ((*editor-state* (%fresh-editor-state "hllo")))
      (setf (editor-state-minibuffer *editor-state*) (make-minibuffer))
      (let ((keymap-state (make-keymap-state (make-keymap))))
        (buffer-set-point (%selected-test-buffer) 0 1)
        (loom::%dispatch-key-event
         (cl-tty-kit:make-key-event :type :character :code #\e)
         keymap-state)
        (expect (buffer-line (%selected-test-buffer) 0) :to-equal "hello"))))

  (it
    "dispatches a bound key through the keymap instead of self-inserting"
    (let* ((*editor-state* (%fresh-editor-state "hi"))
           (keymap (loom/application:install-default-keybindings (make-keymap)))
           (keymap-state (make-keymap-state keymap)))
      (setf (editor-state-minibuffer *editor-state*) (make-minibuffer)
            (editor-state-keymap *editor-state*) keymap)
      (buffer-set-point (%selected-test-buffer) 0 0)
      (loom::%dispatch-key-event
       (cl-tty-kit:make-key-event :type :character :code #\f :modifiers '(:control))
       keymap-state)
      (expect (buffer-point-column (%selected-test-buffer)) :to-equal 1)))

  (it
    "does not self-insert a plain character while a prefix sequence is pending"
    (let* ((*editor-state* (%fresh-editor-state "hi"))
           (keymap (loom/application:install-default-keybindings (make-keymap)))
           (keymap-state (make-keymap-state keymap)))
      (setf (editor-state-minibuffer *editor-state*) (make-minibuffer)
            (editor-state-keymap *editor-state*) keymap)
      (buffer-set-point (%selected-test-buffer) 0 0)
      (loom::%dispatch-key-event
       (cl-tty-kit:make-key-event :type :character :code #\x :modifiers '(:control))
       keymap-state)
      (loom::%dispatch-key-event
       (cl-tty-kit:make-key-event :type :character :code #\q)
       keymap-state)
      (expect (buffer-line (%selected-test-buffer) 0) :to-equal "hi"))))
