;;;; t/unit/sexp-motion-test.lisp
;;;;
;;;; S-expression boundary arithmetic: what counts as structure, what is only
;;;; text that looks like structure, and what an unbalanced form reports.
(in-package #:loom/test)

(describe
  "%sexp-syntax-classes"
  (it-each
      (("#\\(" (:atom :atom :atom))
       ("(; )" (:code :comment :comment :comment))
       ("\"(\"" (:string :string :string))
       ("#|)|#" (:comment :comment :comment :comment :comment))
       ("#\\Space" (:atom :atom :atom :atom :atom :atom :atom)))
      "classifies reader syntax in ~S"
      (text expected)
    (expect (coerce (loom::%sexp-syntax-classes text) 'list)
            :to-equal
            expected)))

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
            :to-equal expected))

  (it-each
      (("" 0 nil)
       ("; comment" 0 nil)
       ("#| unfinished comment" 0 nil)
       ("#\\" 0 2)
       ("\"unfinished" 0 11))
      "handles empty, comment-only, and unterminated syntax at ~D in ~S"
      (text offset expected)
      (expect (loom::%forward-sexp-offset text offset)
            :to-equal expected)))

(describe
  "S-expression boundary helpers"
  (it-each
      (("  foo" 0 2 0)
       ("foo  " 5 5 3)
       ("  ; comment" 0 11 0)
       ("foo ; comment" 13 13 3))
      "skips filler in ~S from ~D forward to ~D and backward to ~D"
      (text offset forward backward)
    (let ((classes (loom::%sexp-syntax-classes (format nil text))))
      (expect (loom::%sexp-skip-forward-filler text classes offset)
              :to-equal forward)
      (expect (loom::%sexp-skip-backward-filler text classes offset)
              :to-equal backward)))

  (it-each
      (("(a (b))" 0 7)
       ("(a (b))" 3 6)
       ("(a b" 0 nil)
       ("a b)" 3 nil))
      "finds balanced list boundaries in ~S from ~D"
      (text offset expected)
    (let ((classes (loom::%sexp-syntax-classes text)))
      (expect (loom::%sexp-forward-list-end text classes offset)
              :to-equal expected)
      (when expected
        (expect (loom::%sexp-backward-list-start text classes expected)
                :to-equal offset))))

  (it-each
      (("foo bar" 0 3 0)
       ("foo bar" 4 7 4)
       ("#\\(" 0 3 0)
       ("#\\Space" 0 7 0)
       ("(foo)" 1 4 1))
      "finds atom boundaries in ~S"
      (text offset end start)
    (let ((classes (loom::%sexp-syntax-classes text)))
      (expect (loom::%sexp-atom-end text classes offset) :to-equal end)
      (expect (loom::%sexp-atom-start text classes end) :to-equal start))))

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
       ("a b (" 5 nil)
       ("; comment" 9 nil)
       ("#| unfinished comment" 20 nil))
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
