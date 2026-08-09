;;;; packages/feature/syntax-highlighting/src/domain-syntax-highlighting.lisp
;;;;
;;;; Line-local Common Lisp lexical classification.  This module returns
;;;; semantic tokens without depending on terminal or rendering packages.

(in-package #:loom/feature/syntax-highlighting)

(defstruct (syntax-token
            (:constructor %make-syntax-token (kind text))
            (:copier nil))
  "A semantic token from a single source line."
  kind
  text)

(defparameter +syntax-lisp-keywords+
  '("and" "block" "case" "catch" "cond" "declare" "defclass" "defconstant"
    "defgeneric" "define-condition" "defmacro" "defmethod" "defpackage"
    "defparameter" "defsetf" "defstruct" "deftype" "defun" "defvar" "do"
    "dolist" "dotimes" "ecase" "etypecase" "eval-when" "flet" "function"
    "handler-bind" "handler-case" "if" "labels" "lambda" "let" "let*"
    "loop" "macrolet" "multiple-value-bind" "multiple-value-call"
    "multiple-value-prog1" "multiple-value-setq" "nil" "or" "otherwise"
    "prog" "prog1" "progn" "progv" "quote" "return" "return-from" "setf"
    "tagbody" "the" "throw" "typecase" "unless" "unwind-protect" "when"
    "with-open-file" "with-output-to-string" "with-slots"
    "with-standard-io-syntax" "write" "t")
  "Common Lisp forms that receive the keyword token category.")

(defun %syntax-whitespace-p (character)
  (member character '(#\Space #\Tab #\Page #\Return #\Newline) :test #'char=))

(defun %syntax-delimiter-p (character)
  (or (find character '(#\( #\) #\[ #\] #\{ #\} #\' #\, #\#)
            :test #'char=)
      (char= character (code-char 96))))

(defun %syntax-whitespace-end (line start)
  (let ((position start))
    (loop while (and (< position (length line))
                     (%syntax-whitespace-p (char line position)))
          do (incf position))
    position))

(defun %syntax-atom-end (line start)
  (let ((position start))
    (loop while (and (< position (length line))
                     (not (%syntax-whitespace-p (char line position)))
                     (not (char= (char line position) #\;))
                     (not (%syntax-delimiter-p (char line position))))
          do (incf position))
    position))

(defun %syntax-string-end (line start)
  (let ((escaped nil))
    (loop for position from (1+ start) below (length line)
          for character = (char line position)
          do (cond (escaped
                    (setf escaped nil))
                   ((char= character #\\)
                    (setf escaped t))
                   ((char= character #\")
                    (return (1+ position))))
          finally (return (length line)))))

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

(defun %syntax-number-token-p (text)
  (let* ((length (length text))
         (position (if (and (> length 1)
                            (find (char text 0) '(#\+ #\-) :test #'char=))
                       1
                       0))
         (digits 0)
         (dot-seen nil))
    (loop while (< position length)
          for character = (char text position)
          do (cond ((digit-char-p character 10)
                    (incf digits)
                    (incf position))
                   ((and (not dot-seen) (char= character #\.))
                    (setf dot-seen t)
                    (incf position))
                   (t (return))))
    (and (plusp digits)
         (= position length))))

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

(defun %syntax-generic-delimiter-p (character)
  (find character '(#\( #\) #\[ #\] #\{ #\} #\' #\, #\: #\; #\#)
        :test #'char=))

(defun %syntax-generic-comment-start-p (line position comment-prefix)
  (and comment-prefix
       (let ((end (+ position (length comment-prefix))))
         (and (<= end (length line))
              (string= comment-prefix line
                      :start2 position
                      :end2 end)))))

(defun %syntax-generic-atom-end (line start comment-prefix)
  (let ((position start))
    (loop while (and (< position (length line))
                     (not (%syntax-whitespace-p (char line position)))
                     (not (%syntax-generic-delimiter-p (char line position)))
                     (not (%syntax-generic-comment-start-p
                           line position comment-prefix)))
          do (incf position))
    position))

(defun %syntax-generic-token-kind (text mode)
  (cond
    ((%syntax-number-token-p text) :number)
    ((and (plusp (length text))
          (char= (char text 0) #\:)) :keyword)
    ((member text (major-mode-keywords mode) :test #'string-equal) :keyword)
    (t :plain)))

(defun %syntax-highlight-generic-line (line mode)
  (let* ((comment-prefix (major-mode-comment-prefix mode))
         (tokens '())
         (position 0)
         (length (length line)))
    (loop while (< position length)
          do (let ((character (char line position)))
               (multiple-value-bind (kind end)
                   (cond
                     ((%syntax-whitespace-p character)
                      (values :whitespace
                              (%syntax-whitespace-end line position)))
                     ((%syntax-generic-comment-start-p
                       line position comment-prefix)
                      (values :comment length))
                     ((char= character #\")
                      (values :string (%syntax-string-end line position)))
                     ((%syntax-generic-delimiter-p character)
                      (values :delimiter (1+ position)))
                     (t
                      (let ((end (%syntax-generic-atom-end
                                  line position comment-prefix)))
                        (values (%syntax-generic-token-kind
                                 (subseq line position end)
                                 mode)
                                end))))
                 (push (%make-syntax-token kind
                                           (subseq line position end))
                       tokens)
                 (setf position end))))
    (nreverse tokens)))

(defun syntax-highlight-line-for-mode (line mode)
  "Tokenize LINE using MODE's syntax rules.

Common Lisp retains the original reader-aware line tokenizer; other built-in
modes use the shared lightweight tokenizer and their mode metadata."
  (check-type line string)
  (let ((resolved-mode (or (major-mode-from-name mode) :fundamental)))
    (if (eq resolved-mode :common-lisp)
        (syntax-highlight-line line)
        (%syntax-highlight-generic-line line resolved-mode))))
