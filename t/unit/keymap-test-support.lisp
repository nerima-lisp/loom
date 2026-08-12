;;;; t/unit/keymap-test-support.lisp
;;;;
;;;; Shared key descriptor fixtures for the keymap unit tests.
(in-package #:loom/test)

(defparameter *ctrl-x* (cons '(:control) #\x))
(defparameter *ctrl-s* (cons '(:control) #\s))
