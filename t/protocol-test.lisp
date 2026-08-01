;;;; t/protocol-test.lisp
;;;;
;;;; One trivial spec confirming the LOOM package exists, so the test system
;;;; is provably wired and green from commit zero -- before any protocol
;;;; generic function has a real implementation to test.
(in-package #:loom/test)

(describe
  "loom package"
  (it
    "is loaded and defines the LOOM package"
    (expect (find-package :loom) :to-be-truthy)))
