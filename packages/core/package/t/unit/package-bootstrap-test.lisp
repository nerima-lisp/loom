(in-package #:loom/test)

(describe "core package bootstrap"
  (it "loads the root and feature packages"
    (expect (find-package "LOOM") :to-be-truthy)
    (expect (find-package "LOOM/CORE/COMMAND") :to-be-truthy)
    (expect (find-package "LOOM/FEATURE/FILES") :to-be-truthy)
    (expect (find-package "LOOM/FEATURE/BOOKMARK") :to-be-truthy)))
