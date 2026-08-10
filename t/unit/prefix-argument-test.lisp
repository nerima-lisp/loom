;;;; t/unit/prefix-argument-test.lisp
;;;;
;;;; The prefix value object is deliberately independent from key dispatch:
;;;; these examples pin down its state transitions before integration tests
;;;; exercise the terminal event path.
(in-package #:loom/test)

(describe
  "prefix argument"
  (it
    "starts inactive with a neutral count"
    (let ((argument (make-prefix-argument)))
      (expect (prefix-argument-value argument) :to-equal 1)
      (expect (prefix-argument-active-p argument) :to-be nil)
      (expect (prefix-argument-explicit-p argument) :to-be nil)))

  (it
    "multiplies repeated universal arguments"
    (let ((argument (make-prefix-argument)))
      (prefix-argument-universal argument)
      (expect (prefix-argument-value argument) :to-equal 4)
      (prefix-argument-universal argument)
      (expect (prefix-argument-value argument) :to-equal 16)
      (expect (prefix-argument-active-p argument) :to-be t)))

  (it
    "builds an explicit decimal signed value and resets on consume"
    (let ((argument (make-prefix-argument)))
      (prefix-argument-universal argument)
      (prefix-argument-digit argument 2)
      (prefix-argument-digit argument 3)
      (prefix-argument-negative argument)
      (expect (prefix-argument-value argument) :to-equal -23)
      (expect (prefix-argument-consume argument) :to-equal -23)
      (expect (prefix-argument-value argument) :to-equal 1)
      (expect (prefix-argument-active-p argument) :to-be nil)
      (expect (prefix-argument-explicit-p argument) :to-be nil)))

  (it
    "supports zero as an explicit repeat count"
    (let ((argument (make-prefix-argument)))
      (prefix-argument-digit argument 0)
      (expect (prefix-argument-value argument) :to-equal 0)
      (expect (prefix-argument-explicit-p argument) :to-be t)
      (expect (prefix-argument-active-p argument) :to-be t)))

  (it
    "starts and toggles a negative argument while inactive"
    (let ((argument (make-prefix-argument)))
      (prefix-argument-negative argument)
      (expect (prefix-argument-value argument) :to-equal -1)
      (expect (prefix-argument-active-p argument) :to-be t)
      (expect (prefix-argument-explicit-p argument) :to-be nil)
      (prefix-argument-negative argument)
      (expect (prefix-argument-value argument) :to-equal 1)))

  (it-each
      (((( :control) . #\u) nil (:universal))
       (((:alt) . #\3) nil (:digit . 3))
       (((:alt) . #\-) nil (:negative))
       ((nil . #\3) t (:digit . 3))
       ((nil . #\3) nil nil)
       ((nil . #\-) t (:negative))
       (((:control) . #\-) nil nil)
       ((nil . #\a) t nil))
      "classifies prefix descriptor ~S"
      (descriptor active expected)
    (let ((argument (make-prefix-argument)))
      (when active
        (prefix-argument-universal argument))
      (expect (prefix-argument-action descriptor argument)
              :to-equal expected))))
