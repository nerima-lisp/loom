;;;; t/integration/prefix-argument-macro-test.lisp
;;;;
;;;; Exercise prefix arguments through keyboard macro replay.
(in-package #:loom/test)

(describe
  "prefix argument keyboard macro replay"
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
              :to-be nil))))
