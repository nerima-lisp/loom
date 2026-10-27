(in-package #:loom/test)

(describe "prefix-aware Emacs command behavior"
          (it
           "applies C-u to the next four words for case commands and supports undo"
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
                       (%prefix-event #\u (quote (:control)))
                       keymap-state)
                      (loom::%dispatch-key-event
                       (%prefix-event command-key (quote (:alt)))
                       keymap-state)
                      (expect (buffer-text buffer) :to-equal expected)
                      (loom/core/buffer:buffer-undo buffer)
                      (expect (buffer-text buffer) :to-equal text))))
             (check-case-command (format nil "one two three four five~%")
                                 #\u
                                 (format nil "ONE TWO THREE FOUR five~%"))
             (check-case-command (format nil "ONE TWO THREE FOUR five~%")
                                 #\l
                                 (format nil "one two three four five~%"))
             (check-case-command (format nil "one two three four five~%")
                                 #\c
                                 (format nil "One Two Three Four five~%"))))
          (it
           "transposes the character at point with the character four places ahead and supports undo"
           (let* ((*editor-state*
                   (%fresh-editor-state "abcdef" :with-minibuffer t))
                  (keymap
                   (loom/application:install-default-keybindings (make-keymap)))
                  (keymap-state (make-keymap-state keymap))
                  (buffer (%selected-test-buffer)))
             (setf (editor-state-keymap *editor-state*) keymap)
             (loom::%dispatch-key-event (%prefix-event #\f (quote (:control)))
                                        keymap-state)
             (loom::%dispatch-key-event (%prefix-event #\u (quote (:control)))
                                        keymap-state)
             (loom::%dispatch-key-event (%prefix-event #\t (quote (:control)))
                                        keymap-state)
             (expect (buffer-text buffer) :to-equal "bcdeaf")
             (expect buffer :to-have-point (cons 0 5))
             (loom/core/buffer:buffer-undo buffer)
             (expect (buffer-text buffer) :to-equal "abcdef")))
          (it
           "joins following lines for a positive delete-indentation prefix and supports undo"
           (let* ((*editor-state*
                   (%fresh-editor-state (format nil "one~%two~%outside~%")
                                        :with-minibuffer
                                        t))
                  (keymap
                   (loom/application:install-default-keybindings (make-keymap)))
                  (keymap-state (make-keymap-state keymap))
                  (buffer (%selected-test-buffer)))
             (setf (editor-state-keymap *editor-state*) keymap)
             (loom::%dispatch-key-event (%prefix-event #\u (quote (:control)))
                                        keymap-state)
             (loom::%dispatch-key-event (%prefix-event #\^ (quote (:alt)))
                                        keymap-state)
             (expect (buffer-text buffer)
                     :to-equal
                     (format nil "one two~%outside~%"))
             (expect buffer :to-have-point (cons 0 3))
             (loom/core/buffer:buffer-undo buffer)
             (expect (buffer-text buffer)
                     :to-equal
                     (format nil "one~%two~%outside~%"))))
          (it
           "fully justifies filled lines for a positive fill-paragraph prefix and supports undo"
           (let* ((*editor-state*
                   (%fresh-editor-state
                    (format nil
                            "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon~%")
                    :with-minibuffer
                    t))
                  (keymap
                   (loom/application:install-default-keybindings (make-keymap)))
                  (keymap-state (make-keymap-state keymap))
                  (buffer (%selected-test-buffer))
                  (original-text (buffer-text buffer)))
             (setf (editor-state-keymap *editor-state*) keymap)
             (loom::%dispatch-key-event (%prefix-event #\u (quote (:control)))
                                        keymap-state)
             (loom::%dispatch-key-event (%prefix-event #\q (quote (:alt)))
                                        keymap-state)
             (expect (buffer-text buffer)
                     :to-equal
                     (format nil
                             "alpha beta gamma delta epsilon zeta  eta theta iota kappa lambda mu nu~%xi omicron pi rho sigma tau upsilon~%"))
             (expect buffer :to-have-point (cons 0 0))
             (loom/core/buffer:buffer-undo buffer)
             (expect (buffer-text buffer) :to-equal original-text)))
          (it
           "joins the preceding line without a prefix through M-^ and supports undo"
           (let* ((*editor-state*
                    (%fresh-editor-state
                     (format nil "one~%  two~%")
                     :with-minibuffer
                     t))
                  (keymap
                   (loom/application:install-default-keybindings (make-keymap)))
                  (keymap-state (make-keymap-state keymap))
                  (buffer (%selected-test-buffer)))
             (setf (editor-state-keymap *editor-state*) keymap)
             (loom/core/buffer:buffer-set-point buffer 1 0)
             (loom::%dispatch-key-event (%prefix-event #\^ (quote (:alt)))
                                        keymap-state)
             (expect (buffer-text buffer)
                     :to-equal
                     (format nil "one two~%"))
             (expect buffer :to-have-point (cons 0 3))
             (loom/core/buffer:buffer-undo buffer)
             (expect (buffer-text buffer)
                     :to-equal
                     (format nil "one~%  two~%"))
             ;; GNU Emacs 31.1 restores point at the start of the joined line.
             (expect buffer :to-have-point (cons 1 0))))
          (it
           "fills a paragraph without justification when M-q has no prefix"
           (let* ((*editor-state*
                    (%fresh-editor-state
                     (format nil
                             "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon~%")
                     :with-minibuffer
                     t))
                  (keymap
                   (loom/application:install-default-keybindings (make-keymap)))
                  (keymap-state (make-keymap-state keymap))
                  (buffer (%selected-test-buffer))
                  (original-text (buffer-text buffer)))
             (setf (editor-state-keymap *editor-state*) keymap)
             (loom::%dispatch-key-event (%prefix-event #\q (quote (:alt)))
                                        keymap-state)
             (expect (buffer-text buffer)
                     :to-equal
                     (format nil
                             "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu~%xi omicron pi rho sigma tau upsilon~%"))
             (loom/core/buffer:buffer-undo buffer)
             (expect (buffer-text buffer) :to-equal original-text))))
