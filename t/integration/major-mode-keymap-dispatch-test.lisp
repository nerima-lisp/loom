;;;; t/integration/major-mode-keymap-dispatch-test.lisp
;;;;
;;;; Mode-local keymap dispatch with inherited and global fallbacks.
(in-package #:loom/test)

(describe
  "mode-local keymap dispatch"
  (it
    "routes local, inherited, and global bindings after a mode switch"
    (let* ((state (%fresh-editor-state "" :with-minibuffer t))
           (*editor-state* state)
           (buffer (%selected-test-buffer))
           (root (editor-state-keymap state))
           (keymap-state (make-keymap-state root))
           (hit (gensym "HIT-")))
      (unwind-protect
           (progn
             (register-major-mode
              :loom-test-parent-dispatch-mode
              :name "Loom Test Parent Dispatch"
              :keybindings
              (list
               (cons '(:control #\p)
                     (lambda ()
                       (%loom-test-parent-dispatch-command hit)))))
             (register-major-mode
              :loom-test-child-dispatch-mode
              :name "Loom Test Child Dispatch"
              :parent :loom-test-parent-dispatch-mode
              :keybindings
              (list
               (cons '(:control #\x)
                     (lambda ()
                       (%loom-test-child-dispatch-command hit)))))
             (keymap-define-key
              root
              (list (cons '(:control) #\x))
              (lambda ()
                (%loom-test-global-dispatch-command hit)))
             (buffer-set-major-mode buffer :loom-test-child-dispatch-mode)
             (flet ((dispatch (character)
                      (setf (symbol-value hit) nil)
                      (loom::%dispatch-key-event
                       (cl-tty-kit:make-key-event
                        :type :character
                        :code character
                        :modifiers '(:control))
                       keymap-state)))
               (dispatch #\x)
               (expect (symbol-value hit) :to-be :child)
               (dispatch #\p)
               (expect (symbol-value hit) :to-be :parent)
               (buffer-set-major-mode buffer
                                      :loom-test-parent-dispatch-mode)
               (dispatch #\x)
               (expect (symbol-value hit) :to-be :global)))
        (unregister-major-mode :loom-test-child-dispatch-mode)
        (unregister-major-mode :loom-test-parent-dispatch-mode)))))
