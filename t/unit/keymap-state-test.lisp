;;;; t/unit/keymap-state-test.lisp
;;;;
;;;; Domain layer: incremental dispatch state in src/domain/keymap-state.lisp.
(in-package #:loom/test)

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
      (keymap-define-key keymap (list (cons nil #\q)) (lambda () :ok))
      (expect (keymap-state-dispatch state (cons nil #\q)) :to-equal :ok))))
