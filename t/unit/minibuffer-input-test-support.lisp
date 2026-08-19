;;;; t/unit/minibuffer-input-test-support.lisp
;;;;
;;;; Shared helpers for minibuffer input handling tests.
(in-package #:loom/test)

(defun %char-key (character)
  (cl-tty-kit:make-key-event :type :character :code character))

(defun %special-key (code)
  (cl-tty-kit:make-key-event :type :special :code code))

(defun %type-string (minibuffer string)
  (loop for character across string
        do (minibuffer-handle-key minibuffer (%char-key character))))
