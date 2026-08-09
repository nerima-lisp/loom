(in-package #:loom/test)

(describe
  "register bank"
  (it
    "stores text and returns a defensive copy"
    (let ((bank (make-register-bank)))
      (register-bank-put-text bank #\a "hello")
      (let ((copy (register-bank-text bank #\a)))
        (expect copy :to-equal "hello")
        (setf (char copy 0) #\H)
        (expect (register-bank-text bank #\a) :to-equal "hello"))))

  (it
    "replaces text with a position and clears the previous kind"
    (let ((bank (make-register-bank)))
      (register-bank-put-text bank #\a "hello")
      (register-bank-put-position bank #\a 2 7)
      (expect (register-bank-text bank #\a) :to-be nil)
      (multiple-value-bind (line column) (register-bank-position bank #\a)
        (expect line :to-equal 2)
        (expect column :to-equal 7))))

  (it
    "returns no position for an unknown or text register"
    (let ((bank (make-register-bank)))
      (register-bank-put-text bank #\a "hello")
      (multiple-value-bind (text-line text-column)
          (register-bank-position bank #\a)
        (expect text-line :to-be nil)
        (expect text-column :to-be nil))
      (multiple-value-bind (missing-line missing-column)
          (register-bank-position bank #\b)
        (expect missing-line :to-be nil)
        (expect missing-column :to-be nil))))

  (it
    "rejects negative positions"
    (let ((bank (make-register-bank)))
      (signals error (register-bank-put-position bank #\a -1 0))
      (signals error (register-bank-put-position bank #\a 0 -1))))

  (it
    "rejects non-character register names"
    (let ((bank (make-register-bank)))
      (signals error (register-bank-put-text bank "a" "hello"))
      (signals error (register-bank-text bank "a"))
      (signals error (register-bank-put-position bank "a" 0 0))
      (signals error (register-bank-position bank "a")))))
