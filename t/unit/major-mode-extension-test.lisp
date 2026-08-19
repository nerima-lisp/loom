;;;; t/unit/major-mode-extension-test.lisp
;;;;
;;;; Extension-defined major-mode registration and validation.
(in-package #:loom/test)

(describe
  "extension-defined major modes"
  (it
    "registers aliases, metadata, path rules, and parent modes"
    (unwind-protect
         (progn
           (expect
            (register-major-mode
             :loom-test-mode
             :name "Loom Test"
             :aliases '("lt")
             :parent :python
             :extensions '(".loomtest")
             :filenames '("SpecialLoomFile")
             :comment-prefix "!"
             :indentation-width 3
             :language-id "loom-test"
             :keywords '("widget")
             :keybindings
             (list (cons '(:control #\x)
                         #'%loom-test-extension-command)))
            :to-be
            :loom-test-mode)
           (expect (major-mode-from-name "lt") :to-be :loom-test-mode)
           (expect (major-mode-from-name "Loom Test") :to-be :loom-test-mode)
           (expect (major-mode-parent :loom-test-mode) :to-be :python)
           (expect (major-mode-for-path "src/main.loomtest")
                   :to-be
                   :loom-test-mode)
           (expect (major-mode-for-path "/tmp/SpecialLoomFile")
                   :to-be
                   :loom-test-mode)
           (expect (major-mode-comment-prefix :loom-test-mode)
                   :to-equal
                   "!")
           (expect (major-mode-indentation-width :loom-test-mode)
                   :to-equal
                   3)
           (expect (major-mode-language-id :loom-test-mode)
                   :to-equal
                   "loom-test")
           (expect (major-mode-keywords :loom-test-mode)
                   :to-equal
                   '("widget"))
           (expect (major-mode-keybindings :loom-test-mode)
                   :to-equal
                   (list (cons '(:control #\x)
                               #'%loom-test-extension-command)))
           (expect (major-mode-names) :to-contain "Loom Test")
           (expect (unregister-major-mode :loom-test-mode)
                   :to-be
                   :loom-test-mode)
           (expect (major-mode-known-p :loom-test-mode) :to-be-falsy))
      (unregister-major-mode :loom-test-mode)))

  (it
    "rejects malformed extension metadata before registration"
    (expect
     (signals error
       (register-major-mode :loom-invalid-name :name 42))
     :to-be-truthy)
    (expect
     (signals error
       (register-major-mode :loom-invalid-keywords :keywords '(42)))
     :to-be-truthy)
    (expect
     (signals error
       (register-major-mode :loom-invalid-aliases :aliases '("dup" "DUP")))
     :to-be-truthy)))
