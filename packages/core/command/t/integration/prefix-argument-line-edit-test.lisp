(in-package #:loom/test)

(describe "prefix-aware line-edit commands"
          (it "inserts four newlines at point for C-u RET"
              (let* ((*editor-state*
                      (%fresh-editor-state "abc\n" :with-minibuffer t))
                     (keymap
                      (loom/application:install-default-keybindings
                       (make-keymap)))
                     (keymap-state (make-keymap-state keymap))
                     (buffer (%selected-test-buffer)))
                (setf (editor-state-keymap *editor-state*) keymap)
                (loom::%dispatch-key-event (%prefix-event #\f '(:control))
                                           keymap-state)
                (loom::%dispatch-key-event (%prefix-event #\u '(:control))
                                           keymap-state)
                (loom::%dispatch-key-event (%prefix-event #\Newline)
                                           keymap-state)
                (expect (buffer-text buffer) :to-equal "a\n\n\n\nbc\n")
                (expect buffer :to-have-point (cons 4 0))))
          (it "opens four lines after point for C-u C-o"
              (let* ((*editor-state*
                      (%fresh-editor-state "abc\n" :with-minibuffer t))
                     (keymap
                      (loom/application:install-default-keybindings
                       (make-keymap)))
                     (keymap-state (make-keymap-state keymap))
                     (buffer (%selected-test-buffer)))
                (setf (editor-state-keymap *editor-state*) keymap)
                (loom::%dispatch-key-event (%prefix-event #\f '(:control))
                                           keymap-state)
                (loom::%dispatch-key-event (%prefix-event #\u '(:control))
                                           keymap-state)
                (loom::%dispatch-key-event (%prefix-event #\o '(:control))
                                           keymap-state)
                (expect (buffer-text buffer) :to-equal "a\n\n\n\nbc\n")
                (expect buffer :to-have-point (cons 0 1)))))
