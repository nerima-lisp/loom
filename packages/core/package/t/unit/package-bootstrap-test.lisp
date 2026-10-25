(in-package #:loom/test)

(describe
  "core package bootstrap"
  (it "loads the root and command packages"
    (expect (find-package "LOOM") :to-be-truthy)
    (expect (find-package "LOOM/CORE/COMMAND") :to-be-truthy)))
