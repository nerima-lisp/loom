(in-package #:loom/test)

(describe
  "prefix argument direct actions"
  (it
    "applies direct actions and reports the resulting prefix"
    (%with-minibuffer-state (minibuffer "")
      (loom/core/command:apply-prefix-argument-action :universal nil)
      (loom/core/command:apply-prefix-argument-action :digit 2)
      (loom/core/command:apply-prefix-argument-action :negative nil)
      (expect (loom/core/command:prefix-argument-value-for-editor) :to-equal -2)
      (loom::universal-argument)
      (expect (loom/core/command:prefix-argument-value-for-editor) :to-equal -8)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Prefix argument: -8")
      (signals error
        (loom/core/command:apply-prefix-argument-action :unknown nil)))))
