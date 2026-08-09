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
               (loom/application:*command-specs* (copy-tree loom/application:*command-specs*)))
          (expect (load-user-init path) :to-equal (probe-file path))
          (expect (fboundp 'loom-user::init-test-command) :to-be-truthy)
          (expect (funcall (loom/application:find-extended-command
                            "INIT-TEST-COMMAND"))
                  :to-equal
                  :loaded)
          (let ((binding
                  (keymap-lookup
                   (editor-state-keymap *editor-state*)
                   (loom/application:defkeys-key-sequence
                    '((:control #\x) #\i)))))
            (expect (funcall binding) :to-equal :loaded))))))

  (it
    "binds an existing command without changing the command registry"
    (let* ((*editor-state* (%fresh-editor-state ""))
           (loom/application:*command-specs* (copy-tree loom/application:*command-specs*))
           (before (copy-tree loom/application:*command-specs*)))
      (expect (bind-key '((:control #\x) (:control #\i))
                        "save-buffer")
              :to-equal
              'loom/feature/file-tree:save-buffer)
      (expect loom/application:*command-specs* :to-equal before)
      (expect
       (keymap-lookup
        (editor-state-keymap *editor-state*)
        (loom/application:defkeys-key-sequence
         '((:control #\x) (:control #\i))))
       :to-equal
       'loom/feature/file-tree:save-buffer)))

  (it
    "treats an absent explicit init path as a no-op"
    (host-kit:with-temporary-directory (directory)
      (expect (load-user-init (merge-pathnames "missing.lisp" directory))
              :to-be nil)))

  (it
    "resolves explicit and conventional init paths"
    (let ((conventional
            (loom/feature/user-init::%configured-user-init-path
             (lambda (name)
               (declare (ignore name))
               nil)))
          (explicit
            (loom/feature/user-init::%configured-user-init-path
             (lambda (name)
               (declare (ignore name))
               "loom-user-init.lisp")))
          (empty
            (loom/feature/user-init::%configured-user-init-path
             (lambda (name)
               (declare (ignore name))
               ""))))
      (expect (pathname-name conventional) :to-equal "init")
      (expect (first (last (pathname-directory conventional))) :to-equal ".loom")
      (expect (namestring explicit) :to-equal "loom-user-init.lisp")
      (expect (pathname-name empty) :to-equal "init")))

  (it
    "rejects invalid names, commands, and duplicate registry entries"
    (let ((*editor-state* nil)
          (loom/application:*command-specs* (copy-tree loom/application:*command-specs*)))
      (signals error (define-command "" #'loom::forward-char))
      (signals error (define-command "new-user-command" 42))
      (signals error (define-command "SAVE-BUFFER" #'loom::forward-char))
      (signals error
               (loom/feature/user-init::%resolve-user-command
                "missing-user-command"))
      (expect (loom/feature/user-init::%resolve-user-command
               #'loom::forward-char)
              :to-be-truthy)
      (expect (loom/feature/user-init::%resolve-user-command
               'loom::forward-char)
              :to-be-truthy)
      (signals error
               (loom/feature/user-init::%resolve-user-command
                'loom/application:with-prompts))
      (signals error
               (loom/feature/user-init::%normalize-user-command-keys 42))
      (signals error
               (loom/feature/user-init::%normalize-user-command-keys '(nil)))
      (signals error
               (loom/feature/user-init::%normalize-user-command-keys
                '((:control #\x :extra))))
      (signals error (define-command 42 #'loom::forward-char))
      (signals error (bind-key '((:control #\x)) #'loom::forward-char)))))
