;;;; packages/core/editor/src/application-sexp-syntax.lisp
;;;;
;;;; Reader-aware syntax classification shared by S-expression motion helpers.
(in-package #:loom)

(defparameter +sexp-open-characters+ '(#\( #\[ #\{))
(defparameter +sexp-close-characters+ '(#\) #\] #\}))

(defun %sexp-whitespace-p (character)
  (member character '(#\Space #\Tab #\Newline #\Return #\Page) :test #'char=))

(defun %sexp-character-literal-end (text index length)
  "Return the index just past a `#\\X' literal beginning at INDEX."
  (let ((position (min length (+ index 2))))
    (when (< position length)
      (incf position)
      (loop while (and (< position length) (alpha-char-p (char text position)))
            do (incf position)))
    position))

(defun %sexp-string-end (text index length)
  "Return the index just past the string literal opening at INDEX."
  (let ((position (1+ index)))
    (loop while (< position length)
          do (let ((character (char text position)))
               (incf position)
               (cond ((char= character #\\) (incf position))
                     ((char= character #\") (return)))))
    (min position length)))

(defun %mark-sexp-range (classes start end class)
  (loop for position from start below end
        do (setf (aref classes position) class)))

(defun %sexp-reader-range (text index length)
  (cond
    ((and (< (1+ index) length)
          (char= (char text (1+ index)) #\\))
     (values :atom (%sexp-character-literal-end text index length)))
    ((and (< (1+ index) length)
          (char= (char text (1+ index)) #\|))
     (let ((close (search "|#" text :start2 (+ index 2))))
       (values :comment (if close (+ close 2) length))))
    (t nil)))

(defun %sexp-comment-range (text index length)
  (values :comment (or (position #\Newline text :start index) length)))

(defun %sexp-string-range (text index length)
  (values :string (%sexp-string-end text index length)))

(defun %sexp-syntax-classes (text)
  "Classify every character of TEXT as :CODE, :STRING, :COMMENT, or :ATOM."
  (let* ((length (length text))
         (classes (make-array (max length 1) :initial-element :code))
         (index 0))
    (loop while (< index length)
          do (let ((character (char text index)))
               (multiple-value-bind (class end)
                   (cond ((char= character #\#)
                          (%sexp-reader-range text index length))
                         ((char= character #\;)
                          (%sexp-comment-range text index length))
                         ((char= character #\")
                          (%sexp-string-range text index length))
                         (t nil))
                 (if class
                     (progn
                       (%mark-sexp-range classes index end class)
                       (setf index end))
                     (incf index)))))
    classes))

(defun %sexp-code-p (classes index)
  (eq (aref classes index) :code))

(defun %sexp-open-p (text classes index)
  (and (%sexp-code-p classes index)
       (member (char text index) +sexp-open-characters+ :test #'char=)))

(defun %sexp-close-p (text classes index)
  (and (%sexp-code-p classes index)
       (member (char text index) +sexp-close-characters+ :test #'char=)))
