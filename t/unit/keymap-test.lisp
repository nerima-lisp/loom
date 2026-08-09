;;;; t/unit/keymap-test.lisp
;;;;
;;;; Domain layer: the keymap protocol (src/domain/keymap.lisp). Exercises
;;;; KEYMAP-DEFINE-KEY / KEYMAP-LOOKUP's trie behavior (bound, :PREFIX,
;;;; unbound) and KEYMAP-STATE-DISPATCH's :PENDING / invoke-and-reset /
;;;; unbound-and-reset state machine, using this implementation's canonical
;;;; (MODIFIERS . CODE) key descriptors (see the file header comment in
;;;; src/domain/keymap.lisp).
(in-package #:loom/test)

(defparameter *ctrl-x* (cons '(:control) #\x))
(defparameter *ctrl-s* (cons '(:control) #\s))

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
      (expect (keymap-lookup keymap (list #\q)) :to-be 'quit-command))))

(describe
  "keymap-state-dispatch"
  (it
    "returns :PENDING on a prefix and invokes the command once the sequence completes"
    (let* ((invoked nil)
           (keymap (make-keymap)))
      (keymap-define-key keymap (list *ctrl-x* *ctrl-s*)
                          (lambda () (setf invoked t) :saved))
      (let ((state (make-keymap-state keymap)))
        (expect (keymap-state-dispatch state *ctrl-x*) :to-equal :pending)
        (expect (keymap-state-dispatch state *ctrl-s*) :to-equal :saved)
        (expect invoked :to-be-truthy))))

  (it
    "resets accumulated sequence to empty on an unbound key"
    (let* ((keymap (make-keymap))
           (state (make-keymap-state keymap)))
      (expect (keymap-state-dispatch state (cons nil #\q)) :to-be-falsy)
      ;; a fresh, unrelated binding on the same key dispatches cleanly,
      ;; proving the previous unbound lookup did not leave stale state behind
      (keymap-define-key keymap (list (cons nil #\q)) (lambda () :ok))
      (expect (keymap-state-dispatch state (cons nil #\q)) :to-equal :ok))))
