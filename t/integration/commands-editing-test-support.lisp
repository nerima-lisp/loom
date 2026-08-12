;;;; t/integration/commands-editing-test-support.lisp
;;;;
;;;; Shared helpers for editing command integration tests.
(in-package #:loom/test)

(defmacro %with-selected-minibuffer-buffer ((minibuffer buffer initial-content
                                                        &rest extra-bindings)
                                            &body body)
  `(%with-minibuffer-state (,minibuffer ,initial-content ,@extra-bindings)
     (let ((,buffer (%selected-test-buffer)))
       ,@body)))

(defmacro %with-modified-selected-minibuffer-buffer ((minibuffer buffer initial-content
                                                                 &rest extra-bindings)
                                                     &body body)
  `(%with-selected-minibuffer-buffer (,minibuffer ,buffer ,initial-content
                                                 ,@extra-bindings)
     (buffer-insert-string ,buffer "!")
     ,@body))
