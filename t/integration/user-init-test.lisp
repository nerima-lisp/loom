;;;; t/integration/user-init-test.lisp
;;;;
;;;; Integration coverage for the optional startup file and its public
;;;; command/keymap extension API.
(in-package #:loom/test)

(describe
  "user init"
  (it
    "loads a user command into the registry and active keymap"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "init.lisp" directory)))
        (host-kit:write-file-string
         (format nil
                 "(defun init-test-command () :loaded)~%~%
(define-command \"init-test-command\" #'init-test-command
  :keys '(((:control #\\x) #\\i)))~%")
         path)
        (let* ((*editor-state* (%fresh-editor-state ""))
               (loom::*command-specs* (copy-tree loom::*command-specs*)))
          (expect (load-user-init path) :to-equal (probe-file path))
          (expect (fboundp 'loom-user::init-test-command) :to-be-truthy)
          (expect (funcall (loom::%find-extended-command
                            "INIT-TEST-COMMAND"))
                  :to-equal
                  :loaded)
          (let ((binding
                  (keymap-lookup
                   (editor-state-keymap *editor-state*)
                   (loom::%defkeys-key-sequence
                    '((:control #\x) #\i)))))
            (expect (funcall binding) :to-equal :loaded))))))

  (it
    "binds an existing command without changing the command registry"
    (let* ((*editor-state* (%fresh-editor-state ""))
           (loom::*command-specs* (copy-tree loom::*command-specs*))
           (before (copy-tree loom::*command-specs*)))
      (expect (bind-key '((:control #\x) (:control #\i))
                        "save-buffer")
              :to-equal
              'loom::save-buffer)
      (expect loom::*command-specs* :to-equal before)
      (expect
       (keymap-lookup
        (editor-state-keymap *editor-state*)
        (loom::%defkeys-key-sequence
         '((:control #\x) (:control #\i))))
       :to-equal
       'loom::save-buffer)))

  (it
    "treats an absent explicit init path as a no-op"
    (host-kit:with-temporary-directory (directory)
      (expect (load-user-init (merge-pathnames "missing.lisp" directory))
              :to-be nil)))

  (it
    "rejects invalid names, commands, and duplicate registry entries"
    (let ((*editor-state* nil)
          (loom::*command-specs* (copy-tree loom::*command-specs*)))
      (signals error (define-command "" #'loom::forward-char))
      (signals error (define-command "new-user-command" 42))
      (signals error (define-command "SAVE-BUFFER" #'loom::forward-char)))))
