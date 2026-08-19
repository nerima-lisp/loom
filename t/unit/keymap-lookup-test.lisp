;;;; t/unit/keymap-lookup-test.lisp
;;;;
;;;; Domain layer: trie lookup and parent-shadowing behavior in
;;;; src/domain/keymap.lisp.
(in-package #:loom/test)

(describe
  "keymap-define-key and keymap-lookup"
  (it
    "resolves a single-key binding to its command"
    (let ((keymap (make-keymap)))
      (keymap-define-key keymap (list *ctrl-x*) 'dummy-command)
      (expect (keymap-lookup keymap (list *ctrl-x*)) :to-be 'dummy-command)))

  (it
    "treats a strict prefix of a longer binding as :PREFIX"
    (let ((keymap (make-keymap)))
      (keymap-define-key keymap (list *ctrl-x* *ctrl-s*) 'save-command)
      (expect (keymap-lookup keymap (list *ctrl-x*)) :to-equal :prefix)
      (expect (keymap-lookup keymap (list *ctrl-x* *ctrl-s*)) :to-be 'save-command)))

  (it
    "returns NIL for a sequence bound to nothing"
    (let ((keymap (make-keymap)))
      (keymap-define-key keymap (list *ctrl-x*) 'dummy-command)
      (expect (keymap-lookup keymap (list (cons nil #\z))) :to-be-falsy)))

  (it
    "normalizes modifier order, so definition and lookup order need not match"
    (let ((keymap (make-keymap)))
      (keymap-define-key keymap (list (cons '(:control :meta) #\a)) 'combo-command)
      (expect (keymap-lookup keymap (list (cons '(:meta :control) #\a)))
              :to-be 'combo-command)))

  (it
    "returns NIL when looking up a sequence longer than a direct binding"
    (let ((keymap (make-keymap)))
      (keymap-define-key keymap (list *ctrl-x*) 'dummy-command)
      (expect (keymap-lookup keymap (list *ctrl-x* *ctrl-s*)) :to-be-falsy)))

  (it
    "returns NIL for an empty key sequence"
    (let ((keymap (make-keymap)))
      (expect (keymap-lookup keymap nil) :to-be-falsy)))

  (it
    "accepts a bare character/keyword descriptor as shorthand for an unmodified key"
    (let ((keymap (make-keymap)))
      (keymap-define-key keymap (list #\q) 'quit-command)
      (expect (keymap-lookup keymap (list (cons nil #\q))) :to-be 'quit-command)
      (expect (keymap-lookup keymap (list #\q)) :to-be 'quit-command)))

  (it
    "falls back to a parent when the first chord is not local"
    (let* ((parent (make-keymap))
           (child (make-keymap :parent parent)))
      (keymap-define-key parent (list *ctrl-s*) 'parent-save-command)
      (expect (keymap-lookup child (list *ctrl-s*))
              :to-be 'parent-save-command)))

  (it
    "lets a local binding shadow the same parent chord"
    (let* ((parent (make-keymap))
           (child (make-keymap :parent parent)))
      (keymap-define-key parent (list *ctrl-s*) 'parent-save-command)
      (keymap-define-key child (list *ctrl-s*) 'local-save-command)
      (expect (keymap-lookup child (list *ctrl-s*))
              :to-be 'local-save-command)))

  (it
    "lets a local prefix shadow the matching parent subtree"
    (let* ((parent (make-keymap))
           (child (make-keymap :parent parent)))
      (keymap-define-key parent (list *ctrl-x*) 'parent-direct-command)
      (keymap-define-key parent (list *ctrl-x* *ctrl-s*)
                         'parent-save-command)
      (keymap-define-key child (list *ctrl-x* *ctrl-s*)
                         'local-save-command)
      (expect (keymap-lookup child (list *ctrl-x*)) :to-equal :prefix)
      (expect (keymap-lookup child (list *ctrl-x* *ctrl-s*))
              :to-be 'local-save-command)
      (expect (keymap-lookup child (list *ctrl-x* (cons nil #\q)))
              :to-be nil))))
