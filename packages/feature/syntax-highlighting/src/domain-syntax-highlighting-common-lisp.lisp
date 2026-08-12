;;;; packages/feature/syntax-highlighting/src/domain-syntax-highlighting-common-lisp.lisp
;;;;
;;;; Common Lisp-specific lexical classification built on the shared
;;;; line-token utilities from domain-syntax-highlighting.lisp.

(in-package #:loom/feature/syntax-highlighting)

(defun %syntax-delimiter-p (character)
  (or (find character '(#\( #\) #\[ #\] #\{ #\} #\' #\, #\#)
            :test #'char=)
      (char= character (code-char 96))))

(defun %syntax-atom-end (line start)
  (let ((position start))
    (loop while (and (< position (length line))
                     (not (%syntax-whitespace-p (char line position)))
                     (not (char= (char line position) #\;))
                     (not (%syntax-delimiter-p (char line position))))
          do (incf position))
    position))

(defun %syntax-block-comment-end (line start)
  (let ((end (search "|#" line :start2 (+ start 2))))
    (if end
        (+ end 2)
        (length line))))

(defun %syntax-character-literal-end (line start)
  (let ((literal-start (+ start 2)))
    (if (>= literal-start (length line))
        (length line)
        (let ((character (char line literal-start)))
          (if (or (char= character #\;)
                  (%syntax-delimiter-p character))
              (1+ literal-start)
              (%syntax-atom-end line literal-start))))))

(defun %syntax-keyword-token-p (text)
  (or (and (plusp (length text))
           (char= (char text 0) #\:))
      (member text +syntax-lisp-keywords+ :test #'string-equal)))

(defun %syntax-token-kind (text)
  (cond ((%syntax-number-token-p text) :number)
        ((%syntax-keyword-token-p text) :keyword)
        (t :plain)))

(defun syntax-highlight-line (line)
  "Return semantic tokens for LINE without changing its source text.

The tokenizer is deliberately line-local.  Reader state spanning multiple
lines, nested block comments, and reader evaluation are outside this
function's contract."
  (check-type line string)
  (let ((tokens '())
        (position 0)
        (length (length line)))
    (loop while (< position length)
          do (let ((character (char line position)))
               (multiple-value-bind
                     (kind end)
                   (cond ((%syntax-whitespace-p character)
                          (values :whitespace
                                  (%syntax-whitespace-end line position)))
                         ((char= character #\;)
                          (values :comment length))
                         ((char= character #\")
                          (values :string
                                  (%syntax-string-end line position)))
                         ((and (char= character #\#)
                               (< (1+ position) length)
                               (char= (char line (1+ position)) #\|))
                          (values :comment
                                  (%syntax-block-comment-end line position)))
                         ((and (char= character #\#)
                               (< (1+ position) length)
                               (char= (char line (1+ position)) #\\))
                          (values :character
                                  (%syntax-character-literal-end line position)))
                         ((%syntax-delimiter-p character)
                          (values :delimiter (1+ position)))
                         (t
                          (let ((end (%syntax-atom-end line position)))
                            (values (%syntax-token-kind
                                     (subseq line position end))
                                    end))))
                 (push (%make-syntax-token kind
                                           (subseq line position end))
                       tokens)
                 (setf position end))))
    (nreverse tokens)))
