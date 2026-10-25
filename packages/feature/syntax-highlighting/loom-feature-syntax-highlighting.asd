(asdf:defsystem "loom-feature-syntax-highlighting"
  :depends-on ("loom-core-buffer"
               "loom-feature-mode")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "domain-syntax-highlighting")
     (:file "domain-syntax-highlighting-common-lisp")
     (:file "domain-syntax-highlighting-generic")
     (:file "presentation-syntax-highlighting")))))

(asdf:defsystem "loom-feature-syntax-highlighting/test"
  :depends-on ("loom-feature-syntax-highlighting"
               "loom/test-support"
               "cl-weave")
  :serial t
  :components
  ((:file "t/unit/syntax-highlighting-test")
   (:file "t/unit/major-mode-syntax-highlighting-test")))
