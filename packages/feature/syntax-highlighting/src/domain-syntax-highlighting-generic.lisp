;;;; packages/feature/syntax-highlighting/src/domain-syntax-highlighting-generic.lisp
;;;;
;;;; Shared lightweight tokenization for non-Common Lisp major modes.

(in-package #:loom/feature/syntax-highlighting)

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
    ((member text (major-mode-keywords mode) :test #'string-equal) :keyword)
    (t :plain)))

(defun %syntax-generic-token-at-whitespace (line position)
  (values :whitespace (%syntax-whitespace-end line position)))

(defun %syntax-generic-token-at-comment (line)
  (values :comment (length line)))

(defun %syntax-generic-token-at-string (line position)
  (values :string (%syntax-string-end line position)))

(defun %syntax-generic-token-at-delimiter (position)
  (values :delimiter (1+ position)))

(defun %syntax-generic-token-at-atom (line position mode comment-prefix)
  (let ((end (%syntax-generic-atom-end line position comment-prefix)))
    (values (%syntax-generic-token-kind
             (subseq line position end)
             mode)
            end)))

(defun %syntax-generic-token-at (line position mode comment-prefix)
  (let ((character (char line position)))
    (cond
      ((%syntax-whitespace-p character)
       (%syntax-generic-token-at-whitespace line position))
      ((%syntax-generic-comment-start-p line position comment-prefix)
       (%syntax-generic-token-at-comment line))
      ((char= character #\")
       (%syntax-generic-token-at-string line position))
      ((%syntax-generic-delimiter-p character)
       (%syntax-generic-token-at-delimiter position))
      (t
       (%syntax-generic-token-at-atom line position mode comment-prefix)))))

(defun %syntax-highlight-generic-line (line mode)
  (let* ((comment-prefix (major-mode-comment-prefix mode))
         (tokens '())
         (position 0)
         (length (length line)))
    (loop while (< position length) do
      (multiple-value-bind (kind end)
          (%syntax-generic-token-at line position mode comment-prefix)
        (push (%make-syntax-token kind (subseq line position end)) tokens)
        (setf position end)))
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
