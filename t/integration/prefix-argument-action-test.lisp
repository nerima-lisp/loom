;;;; t/integration/prefix-argument-action-test.lisp
;;;;
;;;; Exercise direct prefix-argument actions without key dispatch.
(in-package #:loom/test)

(describe
  "prefix argument direct actions"
  (it
    "applies direct actions and reports the resulting prefix"
    (%with-minibuffer-state (minibuffer "")
      (loom:apply-prefix-argument-action :universal nil)
      (loom:apply-prefix-argument-action :digit 2)
      (loom:apply-prefix-argument-action :negative nil)
      (expect (loom:prefix-argument-value-for-editor) :to-equal -2)
      (loom::universal-argument)
      (expect (loom:prefix-argument-value-for-editor) :to-equal -8)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Prefix argument: -8")
      (signals error
        (loom:apply-prefix-argument-action :unknown nil)))))
