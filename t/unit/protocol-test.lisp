;;;; t/unit/protocol-test.lisp
;;;;
;;;; One trivial spec confirming the LOOM package exists -- a canary that
;;;; fails on a broken package/system definition specifically, distinct from
;;;; every other spec file's feature-level failures.
(in-package #:loom/test)

(describe
  "loom package"
  (it
    "is loaded and defines the LOOM package"
    (expect (find-package :loom) :to-be-truthy)))
