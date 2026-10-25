(in-package #:loom/test)

(describe
  "user init"
  (it
    "loads a user command into the registry and active keymap by stable ID"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "init.lisp" directory)))
        (host-kit:write-file-string
         (format nil
                 "(defun init-test-command () :loaded)~%~
(define-command \"init-test-command\" #'init-test-command
  :keys '(((:control #\\x) #\\i)))~%")
         path)
        (let ((*editor-state* (%fresh-editor-state ""))
              (loom/core/command::*registered-command-specs*
                (loom/core/command:command-specs)))
          (expect (load-user-init path) :to-equal (probe-file path))
          (expect (fboundp 'loom-user::init-test-command) :to-be-truthy)
          (let* ((spec
                   (loom/core/command:find-extended-command-spec
                    "INIT-TEST-COMMAND"))
                 (id (loom/core/command:command-spec-id spec))
                 (catalog
                   (json-kit:parse
                    (loom/core/command:command-catalog-json)
                    :array-type :list
                    :object-type :hash-table))
                 (entry
                   (find id catalog
                         :key (lambda (candidate) (gethash "id" candidate))
                         :test #'equal))
                 (sequence
                   (loom/core/command:defkeys-key-sequence
                    '((:control #\x) #\i))))
            (expect (loom/core/command:command-spec-name spec)
                    :to-equal
                    "init-test-command")
            (expect id :to-equal "user-init/init-test-command")
            (expect (gethash "owner" entry) :to-equal "feature/user-init")
            (expect (loom/core/command:invoke-command id :mx)
                    :to-equal
                    :loaded)
            (expect (loom/core/command:keymap-lookup
                     (editor-state-keymap *editor-state*)
                     sequence)
                    :to-equal
                    id)
            (expect (loom/core/command:invoke-key-command
                     id :key sequence "global")
                    :to-equal
                    :loaded))))))

  (it
    "registers a key-only callable with a stable owner and ID"
    (let* ((*editor-state* (%fresh-editor-state ""))
           (loom/core/command::*registered-command-specs*
             (loom/core/command:command-specs))
           (before-count (length (loom/core/command:command-specs)))
           (called-with nil)
           (command (lambda (value) (setf called-with value)))
           (key-form '((:control #\x) (:control #\i)))
           (sequence (loom/core/command:defkeys-key-sequence key-form)))
      (loom/feature/user-init:bind-key key-form command)
      (let* ((id (loom/core/command:keymap-lookup
                  (editor-state-keymap *editor-state*)
                  sequence))
             (spec (loom/core/command:find-command-spec id))
             (catalog
               (json-kit:parse
                (loom/core/command:command-catalog-json)
                :array-type :list
                :object-type :hash-table))
             (entry
               (find id catalog
                     :key (lambda (candidate) (gethash "id" candidate))
                     :test #'equal)))
        (loom/feature/user-init:bind-key key-form command)
        (expect (search "user-init/key/" id) :to-equal 0)
        (expect (loom/core/command:keymap-lookup
                 (editor-state-keymap *editor-state*)
                 sequence)
                :to-equal
                id)
        (expect (length (loom/core/command:command-specs))
                :to-equal
                (1+ before-count))
        (expect (loom/core/command:command-spec-name spec) :to-be nil)
        (expect (gethash "owner" entry) :to-equal "feature/user-init")
        (expect (eq (gethash "name" entry) json-kit:+json-null+)
                :to-be
                t)
        (expect (json-kit:json-false-p (gethash "mx-eligible" entry))
                :to-be
                t)
        (dolist (field '("mutates" "prompts" "needs-region" "external" "modes"))
          (expect (nth-value 1 (gethash field entry)) :to-be t))
        (expect (loom/core/command:invoke-command id :key :bound-argument)
                :to-equal
                :bound-argument)
        (expect called-with :to-equal :bound-argument))))

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
    "rejects invalid names, commands, and duplicate command names"
    (let ((*editor-state* nil)
          (loom/core/command::*registered-command-specs*
            (loom/core/command:command-specs)))
      (signals error
        (loom/feature/user-init:define-command "" #'loom::forward-char))
      (signals error
        (loom/feature/user-init:define-command "new-user-command" 42))
      (signals error
        (loom/feature/user-init:define-command "SAVE-BUFFER" #'loom::forward-char))
      (signals error
        (loom/feature/user-init::%resolve-user-command "missing-user-command"))
      (expect (loom/feature/user-init::%resolve-user-command #'loom::forward-char)
              :to-be-truthy)
      (expect (loom/feature/user-init::%resolve-user-command 'loom::forward-char)
              :to-be-truthy)
      (signals error
        (loom/feature/user-init::%resolve-user-command 'loom/application:with-prompts))
      (signals error
        (loom/feature/user-init::%normalize-user-command-keys 42))
      (signals error
        (loom/feature/user-init::%normalize-user-command-keys '(nil)))
      (signals error
        (loom/feature/user-init::%normalize-user-command-keys
         '((:control #\x :extra))))
      (signals error
        (loom/feature/user-init:define-command 42 #'loom::forward-char))
      (signals error
        (loom/feature/user-init:bind-key '((:control #\x)) #'loom::forward-char)))))
