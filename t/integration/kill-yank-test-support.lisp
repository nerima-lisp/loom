;;;; t/integration/kill-yank-test-support.lisp

(in-package #:loom/test)

(defmacro %expect-word-kill ((command initial-content expected-content expected-kill
                              &key point prefix)
                             &body extra-assertions)
  `(let ((*editor-state* (%fresh-editor-state ,initial-content))
         ,@(when prefix `((loom:*current-prefix-argument* ,prefix))))
     (let ((buffer (%selected-test-buffer)))
       ,@(when point `((buffer-set-point buffer ,(first point) ,(second point))))
       (,command)
       (expect (buffer-text buffer) :to-equal ,expected-content)
       (expect (editor-state-kill-ring *editor-state*) :to-equal ,expected-kill)
       ,@extra-assertions)))
