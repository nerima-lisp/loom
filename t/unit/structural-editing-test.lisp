;;;; t/unit/structural-editing-test.lisp
;;;;
;;;; The edit lists behind the structural editing commands, checked by applying
;;;; them to a string. Working on text rather than on a buffer keeps each case
;;;; readable as a before/after pair.
(in-package #:loom/test)

(defun %apply-edits-to-string (text edits)
  "Apply EDITS to TEXT the way %APPLY-STRUCTURAL-EDITS applies them to a buffer."
  (let ((result text))
    (dolist (edit (sort (copy-list edits) #'> :key #'second) result)
      (let ((position (second edit)))
        (setf result
              (ecase (first edit)
                (:insert (concatenate 'string
                                      (subseq result 0 position)
                                      (third edit)
                                      (subseq result position)))
                (:delete (concatenate 'string
                                      (subseq result 0 position)
                                      (subseq result (+ position (third edit)))))))))))

(defun %structural-result (function text offset)
  "Return the text FUNCTION's edits produce, or NIL when it declines to act."
  (let* ((classes (loom::%sexp-syntax-classes text))
         (edits (funcall function text classes offset)))
    (and edits (%apply-edits-to-string text edits))))

(defun %balanced-p (text)
  "True when TEXT's structural parentheses pair up."
  (let ((classes (loom::%sexp-syntax-classes text))
        (depth 0))
    (dotimes (index (length text) (zerop depth))
      (cond ((loom::%sexp-open-p text classes index) (incf depth))
            ((loom::%sexp-close-p text classes index)
             (decf depth)
             (when (minusp depth) (return nil)))))))

(describe
  "structural editing edits"
  (it-each
      ((loom::%forward-slurp-edits "(a) b" 1 "(a b)")
       (loom::%forward-slurp-edits "(a) (b c)" 1 "(a (b c))")
       (loom::%forward-slurp-edits "(a)" 1 nil)
       (loom::%forward-barf-edits "(a b)" 1 "(a) b")
       (loom::%forward-barf-edits "(a)" 1 "() a")
       (loom::%forward-barf-edits "()" 1 nil)
       (loom::%backward-slurp-edits "a (b)" 3 "(a b)")
       (loom::%backward-slurp-edits "(b)" 1 nil)
       (loom::%backward-barf-edits "(a b)" 1 "a (b)")
       (loom::%backward-barf-edits "(a)" 1 "a ()")
       (loom::%backward-barf-edits "(ab)" 1 "ab ()")
       (loom::%wrap-round-edits "a b" 0 "(a) b")
       (loom::%wrap-round-edits "" 0 "()")
       (loom::%splice-edits "(a (b c) d)" 4 "(a b c d)")
       (loom::%splice-edits "((a b) c)" 2 "(a b c)")
       (loom::%splice-edits "a b" 0 nil)
       (loom::%raise-edits "(a (b c) d)" 3 "(b c)")
       (loom::%raise-edits "(a b)" 4 nil)
       (loom::%raise-edits "a b" 0 nil))
      "~S rewrites ~S at ~D as ~S"
      (function text offset expected)
    (expect (%structural-result function text offset) :to-equal expected))

  (it-each
      ((loom::%forward-slurp-edits "(a) b" 1)
       (loom::%forward-barf-edits "(a b)" 1)
       (loom::%backward-slurp-edits "a (b)" 3)
       (loom::%backward-barf-edits "(a b)" 1)
       (loom::%wrap-round-edits "a b" 0)
       (loom::%splice-edits "(a (b c) d)" 4)
       (loom::%raise-edits "(a (b c) d)" 3))
      "~S keeps ~S balanced at ~D"
      (function text offset)
    (expect (%balanced-p text) :to-be-truthy)
    (expect (%balanced-p (%structural-result function text offset))
            :to-be-truthy))

  (it
    "declines to act on an unbalanced form rather than closing it"
    (expect (%structural-result #'loom::%forward-slurp-edits "(a b" 1)
            :to-be nil)
    (expect (%structural-result #'loom::%splice-edits "(a b" 1) :to-be nil)
    (expect (%structural-result #'loom::%raise-edits "(a b" 1) :to-be nil)))

(describe
  "structural editing boundary predicates"
  (it
    "returns the enclosing list bounds"
    (multiple-value-bind (open close)
        (loom::%structural-list-bounds "(a)"
                                        (loom::%sexp-syntax-classes "(a)")
                                        1)
      (expect open :to-equal 0)
      (expect close :to-equal 2)))

  (it
    "declines bounds outside a closed list"
    (multiple-value-bind (open close)
        (loom::%structural-list-bounds "(a"
                                        (loom::%sexp-syntax-classes "(a")
                                        1)
      (expect open :to-be nil)
      (expect close :to-be nil)))

  (it-each
      (("a b" 0 t)
       (" a" 0 nil)
       ("a)" 1 nil)
       ("a" 1 nil))
      "requires a separator for ~S at ~D"
      (text offset expected)
    (expect (loom::%structural-separator-needed-p text offset)
            :to-equal expected)))

(describe
  "%structural-adjusted-offset"
  (it
    "moves an offset past an insertion before it and not past one after it"
    (expect (loom::%structural-adjusted-offset '((:insert 2 "xy")) 5)
            :to-equal 7)
    (expect (loom::%structural-adjusted-offset '((:insert 8 "xy")) 5)
            :to-equal 5))

  (it
    "pulls an offset back over a deletion, clamping inside a deleted range"
    (expect (loom::%structural-adjusted-offset '((:delete 1 2)) 5) :to-equal 3)
    (expect (loom::%structural-adjusted-offset '((:delete 8 2)) 5) :to-equal 5)
    (expect (loom::%structural-adjusted-offset '((:delete 3 4)) 5) :to-equal 3)))
