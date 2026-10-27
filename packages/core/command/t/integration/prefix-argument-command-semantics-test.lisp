(in-package #:loom/test)

(describe "prefix-aware Emacs command behavior"
          (it "applies C-u to the next four words for case commands"
              (flet ((check-case-command (text command-key expected)
                       (let* ((*editor-state*
                               (%fresh-editor-state text :with-minibuffer t))
                              (keymap
                               (loom/application:install-default-keybindings
                                (make-keymap)))
                              (keymap-state (make-keymap-state keymap))
                              (buffer (%selected-test-buffer)))
                         (setf (editor-state-keymap *editor-state*) keymap)
                         (loom::%dispatch-key-event
                          (%prefix-event #\u '(:control))
                          keymap-state)
                         (loom::%dispatch-key-event
                          (%prefix-event command-key '(:alt))
                          keymap-state)
                         (expect (buffer-text buffer) :to-equal expected)
                         (expect buffer :to-have-point (cons 0 18))))
                     (check-case-command "one two three four five\n"
                       #\u
                       "ONE TWO THREE FOUR five\n")
                     (check-case-command "ONE TWO THREE FOUR five\n"
                       #\l
                       "one two three four five\n")
                     (check-case-command "ONE TWO THREE FOUR five\n"
                       #\c
                       "One Two Three Four five\n")))
              (it
               "transposes the character at point with the character four places ahead"
               (let* ((*editor-state*
                       (%fresh-editor-state "abcdef" :with-minibuffer t))
                      (keymap
                       (loom/application:install-default-keybindings
                        (make-keymap)))
                      (keymap-state (make-keymap-state keymap))
                      (buffer (%selected-test-buffer)))
                 (setf (editor-state-keymap *editor-state*) keymap)
                 (loom::%dispatch-key-event (%prefix-event #\u '(:control))
                                            keymap-state)
                 (loom::%dispatch-key-event (%prefix-event #\t '(:control))
                                            keymap-state)
                 (expect (buffer-text buffer) :to-equal "bcdeaf")
                 (expect buffer :to-have-point (cons 0 5))))
              (it
               "joins following lines for a positive delete-indentation prefix"
               (let* ((*editor-state*
                       (%fresh-editor-state "one\ntwo\noutside\n"
                                            :with-minibuffer
                                            t))
                      (keymap
                       (loom/application:install-default-keybindings
                        (make-keymap)))
                      (keymap-state (make-keymap-state keymap))
                      (buffer (%selected-test-buffer)))
                 (setf (editor-state-keymap *editor-state*) keymap)
                 (loom::%dispatch-key-event (%prefix-event #\u '(:control))
                                            keymap-state)
                 (loom::%dispatch-key-event (%prefix-event #\^ '(:alt))
                                            keymap-state)
                 (expect (buffer-text buffer) :to-equal "one two\noutside\n")
                 (expect buffer :to-have-point (cons 0 4))))
              (it
               "fully justifies filled lines for a positive fill-paragraph prefix"
               (let* ((*editor-state*
                       (%fresh-editor-state
                        "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon\n"
                        :with-minibuffer
                        t))
                      (keymap
                       (loom/application:install-default-keybindings
                        (make-keymap)))
                      (keymap-state (make-keymap-state keymap))
                      (buffer (%selected-test-buffer)))
                 (setf (editor-state-keymap *editor-state*) keymap)
                 (loom::%dispatch-key-event (%prefix-event #\u '(:control))
                                            keymap-state)
                 (loom::%dispatch-key-event (%prefix-event #\q '(:alt))
                                            keymap-state)
                 (expect (buffer-text buffer)
                         :to-equal
                         "alpha beta gamma delta epsilon zeta  eta theta iota kappa lambda mu nu\nxi omicron pi rho sigma tau upsilon\n")
                 (expect buffer :to-have-point (cons 0 0))))))
