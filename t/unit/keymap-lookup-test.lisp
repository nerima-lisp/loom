(in-package #:loom/test)

(describe
  "keymap-define-key and keymap-lookup"
  (it "resolves a single-key binding to a stable command ID"
    (let ((keymap (make-keymap)))
      (keymap-define-key keymap (list *ctrl-x*) "forward-char")
      (expect (keymap-lookup keymap (list *ctrl-x*))
              :to-equal "forward-char")))
  (it "treats a strict prefix of a longer binding as :PREFIX"
    (let ((keymap (make-keymap)))
      (keymap-define-key keymap (list *ctrl-x* *ctrl-s*) "save-buffer")
      (expect (keymap-lookup keymap (list *ctrl-x*)) :to-equal :prefix)
      (expect (keymap-lookup keymap (list *ctrl-x* *ctrl-s*))
              :to-equal "save-buffer")))
  (it "returns NIL for a sequence bound to nothing"
    (let ((keymap (make-keymap)))
      (keymap-define-key keymap (list *ctrl-x*) "forward-char")
      (expect (keymap-lookup keymap (list (cons nil #\z))) :to-be-falsy)))
  (it "normalizes modifier order, so definition and lookup order need not match"
    (let ((keymap (make-keymap)))
      (keymap-define-key keymap (list (cons '(:control :meta) #\a))
                         "backward-char")
      (expect (keymap-lookup keymap (list (cons '(:meta :control) #\a)))
              :to-equal "backward-char")))
  (it "returns NIL when looking up a sequence longer than a direct binding"
    (let ((keymap (make-keymap)))
      (keymap-define-key keymap (list *ctrl-x*) "forward-char")
      (expect (keymap-lookup keymap (list *ctrl-x* *ctrl-s*)) :to-be-falsy)))
  (it "returns NIL for an empty key sequence"
    (let ((keymap (make-keymap)))
      (expect (keymap-lookup keymap nil) :to-be-falsy)))
  (it "accepts a bare character descriptor as shorthand for an unmodified key"
    (let ((keymap (make-keymap)))
      (keymap-define-key keymap (list #\q) "keyboard-quit")
      (expect (keymap-lookup keymap (list (cons nil #\q)))
              :to-equal "keyboard-quit")
      (expect (keymap-lookup keymap (list #\q)) :to-equal "keyboard-quit")))
  (it
  "resolves callable bindings to their registered command IDs"
  (let* ((loom/core/command::*registered-command-specs* nil)
         (command (lambda () :ok))
         (keymap (make-keymap)))
    (loom/core/command:register-command-spec
     :test "test/keymap-closure" nil command
     :keys nil :keymap :global
     :mutates nil :prompts nil :needs-region nil :external nil :modes nil)
    (keymap-define-key keymap (list *ctrl-x*) command)
    (expect (keymap-lookup keymap (list *ctrl-x*))
            :to-equal "test/keymap-closure")
    (expect (loom/core/command:command-id-for-function command)
            :to-equal "test/keymap-closure")))
  (it "rejects an unregistered command ID"
    (let ((keymap (make-keymap)))
      (signals error
        (keymap-define-key keymap (list *ctrl-x*) "missing-command-id"))))
  (it "falls back to a parent when the first chord is not local"
    (let* ((parent (make-keymap))
           (child (make-keymap :parent parent)))
      (keymap-define-key parent (list *ctrl-s*) "save-buffer")
      (expect (keymap-lookup child (list *ctrl-s*))
              :to-equal "save-buffer")))
  (it "lets a local binding shadow the same parent chord"
    (let* ((parent (make-keymap))
           (child (make-keymap :parent parent)))
      (keymap-define-key parent (list *ctrl-s*) "save-buffer")
      (keymap-define-key child (list *ctrl-s*) "forward-char")
      (expect (keymap-lookup child (list *ctrl-s*))
              :to-equal "forward-char")))
  (it
  "lets a local prefix shadow the matching parent subtree"
  (let* ((parent (make-keymap))
         (child (make-keymap :parent parent)))
    (keymap-define-key parent (list *ctrl-x* *ctrl-s*) "save-buffer")
    (keymap-define-key child
                       (list *ctrl-x* (cons nil #\q))
                       "forward-char")
    (expect (keymap-lookup child (list *ctrl-x*)) :to-equal :prefix)
    (expect (keymap-lookup child (list *ctrl-x* *ctrl-s*)) :to-be nil)
    (expect (keymap-lookup child (list *ctrl-x* (cons nil #\q)))
            :to-equal "forward-char"))))
