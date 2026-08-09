;;;; t/integration/prefix-argument-test.lisp
;;;;
;;;; Exercise prefix arguments through the same decoded key-event dispatcher
;;;; used by the real event loop.  This keeps keymap pending state, command
;;;; repetition, and macro replay in one executable specification.
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
              :to-be nil)))

  (it
    "replays prefix events in a keyboard macro"
    (let* ((*editor-state* (%fresh-editor-state "" :with-minibuffer t))
           (keymap (loom/application:install-default-keybindings (make-keymap)))
           (macro (make-keyboard-macro))
           (buffer (%selected-test-buffer)))
      (setf (editor-state-keymap *editor-state*) keymap
            (editor-state-keyboard-macro *editor-state*) macro)
      (keyboard-macro-start-recording macro)
      (keyboard-macro-record-event
       macro
       (make-keyboard-macro-event
        :kind :key
        :value (cons '(:control) #\u)))
      (keyboard-macro-record-event
       macro
       (make-keyboard-macro-event
        :kind :key
        :value (cons nil #\2)))
      (keyboard-macro-record-event
       macro
       (make-keyboard-macro-event :kind :self-insert :value #\a))
      (keyboard-macro-stop-recording macro)
      (loom/feature/keyboard-macro:call-last-kbd-macro)
      (expect (buffer-text buffer) :to-equal "aa")
      (expect (prefix-argument-active-p
               (editor-state-prefix-argument *editor-state*))
              :to-be nil)))

  (it
    "applies direct actions and reports the resulting prefix"
    (%with-minibuffer-state (minibuffer "")
      (loom:apply-prefix-argument-action :universal nil)
      (loom:apply-prefix-argument-action :digit 2)
      (loom:apply-prefix-argument-action :negative nil)
      (expect (loom:prefix-argument-value-for-editor) :to-equal -2)
      (loom::universal-argument)
      (expect (loom:prefix-argument-value-for-editor) :to-equal -8)
      (expect (loom::%minibuffer-message minibuffer)
              :to-equal "Prefix argument: -8")
      (signals error
        (loom:apply-prefix-argument-action :unknown nil)))))
