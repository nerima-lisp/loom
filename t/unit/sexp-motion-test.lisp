;;;; t/unit/sexp-motion-test.lisp
;;;;
;;;; S-expression boundary arithmetic: what counts as structure, what is only
;;;; text that looks like structure, and what an unbalanced form reports.
(in-package #:loom/test)

(describe
  "%forward-sexp-offset"
  (it-each
      (("(a b) c" 0 5)
       ("  (a b) c" 0 7)
       ("(a b) c" 5 7)
       ("(a (b c) d)" 3 8)
       ("foo bar" 0 3)
       ("foo bar" 3 7)
       ("\"a b\" c" 0 5)
       ("(a b" 0 nil)
       ("(a b) " 6 nil)
       ("(a) )" 3 nil))
      "moves forward in ~S from ~D to ~S"
      (text offset expected)
    (expect (loom::%forward-sexp-offset text offset) :to-equal expected))

  (it-each
      (("(a \"(\" b)" 0 9)
       ("(a ; ) not structure~%   b)" 0 26)
       ("(a #\\( b)" 0 9)
       ("#\\( foo" 0 3)
       ("#\\Space foo" 0 7)
       ("(a #| ) |# b)" 0 13))
      "treats the parenthesis in ~S as text, moving from ~D to ~S"
      (text offset expected)
    (expect (loom::%forward-sexp-offset (format nil text) offset)
            :to-equal expected)))

(describe
  "%backward-sexp-offset"
  (it-each
      (("(a b) c" 5 0)
       ("(a b) c" 7 6)
       ("(a (b c) d)" 8 3)
       ("foo bar" 7 4)
       ("foo bar" 3 0)
       ("\"a b\" c" 5 0)
       ("a b)" 3 2)
       ("(a b" 1 nil)
       ("  " 2 nil)
       ("a b (" 5 nil))
      "moves backward in ~S from ~D to ~S"
      (text offset expected)
    (expect (loom::%backward-sexp-offset text offset) :to-equal expected)))

(describe
  "%backward-up-list-offset and %down-list-offset"
  (it-each
      (("(a (b c) d)" 5 3)
       ("(a (b c) d)" 3 0)
       ("(a (b c) d)" 10 0)
       ("a b c" 3 nil)
       ("(a \"(\" b)" 7 0))
      "finds the list enclosing ~D in ~S at ~S"
      (text offset expected)
    (expect (loom::%backward-up-list-offset text offset) :to-equal expected))

  (it-each
      (("(a b)" 0 1)
       ("  (a b)" 0 3)
       ("(a (b))" 2 4)
       ("a b" 0 nil)
       ("a) (b)" 0 nil))
      "descends from ~D in ~S to ~S"
      (text offset expected)
    (expect (loom::%down-list-offset text offset) :to-equal expected)))

(describe
  "%matching-paren-offset"
  (it-each
      (("(a b)" 0 0 4)
       ("(a b)" 5 4 0)
       ("(a (b) c)" 3 3 5)
       ("(a (b) c)" 6 5 3)
       ("[a b]" 0 0 4))
      "pairs the parenthesis at ~D in ~S as ~S and ~S"
      (text offset expected-paren expected-match)
    (multiple-value-bind (paren match)
        (loom::%matching-paren-offset text offset)
      (expect paren :to-equal expected-paren)
      (expect match :to-equal expected-match)))

  (it-each
      (("(a b" 0)
       ("a b)" 4))
      "reports no partner for ~S at ~D"
      (text offset)
    (multiple-value-bind (paren match)
        (loom::%matching-paren-offset text offset)
      (declare (ignore paren))
      (expect match :to-be nil)))

  (it-each
      (("a b c" 2)
       ("(a b)" 2)
       ("(a \"(\" b)" 4)
       ("" 0))
      "reports no parenthesis beside ~D in ~S"
      (text offset)
    (expect (loom::%matching-paren-offset text offset) :to-be nil)))
