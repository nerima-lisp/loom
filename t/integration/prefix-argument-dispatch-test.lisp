;;;; t/integration/prefix-argument-dispatch-test.lisp
;;;;
;;;; Exercise prefix arguments through the real decoded key-event dispatcher,
;;;; covering repetition and pending keymaps.
(in-package #:loom/test)

(defun %prefix-event (code &optional modifiers)
  (cl-tty-kit:make-key-event :type :character
                              :code code
                              :modifiers modifiers))

(describe
  "prefix argument dispatch"
  (it
    "repeats self-insertion after C-u and an explicit digit"
    (let* ((*editor-state* (%fresh-editor-state "" :with-minibuffer t))
           (keymap (loom/application:install-default-keybindings (make-keymap)))
           (keymap-state (make-keymap-state keymap))
           (buffer (%selected-test-buffer)))
      (setf (editor-state-keymap *editor-state*) keymap)
      (flet ((dispatch (code &optional modifiers)
               (loom::%dispatch-key-event
                (%prefix-event code modifiers)
                keymap-state)))
        (dispatch #\u '(:control))
        (dispatch #\3)
        (dispatch #\a))
      (expect (buffer-text buffer) :to-equal "aaa")
      (expect (prefix-argument-active-p
               (editor-state-prefix-argument *editor-state*))
              :to-be nil)))

  (it
    "repeats movement in the negative direction"
    (let* ((*editor-state* (%fresh-editor-state "abcd" :with-minibuffer t))
           (keymap (loom/application:install-default-keybindings (make-keymap)))
           (keymap-state (make-keymap-state keymap))
           (buffer (%selected-test-buffer)))
      (setf (editor-state-keymap *editor-state*) keymap)
      (buffer-set-point buffer 0 3)
      (flet ((dispatch (code &optional modifiers)
               (loom::%dispatch-key-event
                (%prefix-event code modifiers)
                keymap-state)))
        (dispatch #\u '(:control))
        (dispatch #\-)
        (dispatch #\2)
        (dispatch #\f '(:control)))
      (expect buffer :to-have-point (cons 0 1))
      (expect (prefix-argument-active-p
               (editor-state-prefix-argument *editor-state*))
              :to-be nil)))

  (it
    "keeps the prefix alive while a multi-chord key sequence is pending"
    (let* ((*editor-state* (%fresh-editor-state "" :with-minibuffer t))
           (keymap (loom/application:install-default-keybindings (make-keymap)))
           (keymap-state (make-keymap-state keymap))
           (seen-prefix nil))
      (setf (editor-state-keymap *editor-state*) keymap)
      (keymap-define-key
       keymap
       (list (cons '(:control) #\x) (cons nil #\q))
       (lambda ()
         (setf seen-prefix loom:*current-prefix-argument*)))
      (flet ((dispatch (code &optional modifiers)
               (loom::%dispatch-key-event
                (%prefix-event code modifiers)
                keymap-state)))
        (dispatch #\u '(:control))
        (dispatch #\x '(:control))
        (dispatch #\q))
      (expect seen-prefix :to-equal 4)
      (expect (loom:keymap-state-sequence keymap-state) :to-be nil)
      (expect (prefix-argument-active-p
               (editor-state-prefix-argument *editor-state*))
              :to-be nil))))
