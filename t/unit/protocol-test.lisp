(in-package #:loom/test)

(describe
  "loom package"
  (it
    "is loaded and defines the LOOM package"
    (expect (find-package :loom) :to-be-truthy)))
