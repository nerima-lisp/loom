;;;; t/package.lisp
;;;
;;; Imports the cl-weave DSL explicitly (no blanket :USE), so a future
;;; cl-weave export never silently shadows a loom symbol. CL:DESCRIBE is
;;; shadowed in favor of CL-WEAVE:DESCRIBE, per the cl-weave installation
;;; contract (see e.g. cl-host-kit/t/package.lisp, nshell/t/package.lisp).
(defpackage #:loom/test
  (:use #:cl #:loom)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-weave
   #:it
   #:it-each
   #:expect
   #:signals
   #:run-all
   #:defmatcher
   #:with-soft-assertions
   #:with-replaced-function)
  (:export #:run-tests))

(in-package #:loom/test)

(defun run-tests ()
  "Run every registered spec, signalling on any failure so ASDF's TEST-OP fails."
  (unless (run-all :reporter :spec :timeout-ms 40000)
    (error "loom test suite failed"))
  (format t "~&loom/test: successful completion with 0 failures~%")
  t)
