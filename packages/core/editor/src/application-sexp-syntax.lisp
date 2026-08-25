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

(defun %sexp-syntax-classes (text)
  "Classify every character of TEXT as :CODE, :STRING, :COMMENT, or :ATOM."
  (let* ((length (length text))
         (classes (make-array (max length 1) :initial-element :code))
         (index 0))
    (loop while (< index length)
          do (let ((character (char text index)))
               (cond
                 ((and (char= character #\#)
                       (< (1+ index) length)
                       (char= (char text (1+ index)) #\\))
                  (let ((end (%sexp-character-literal-end text index length)))
                    (loop for position from index below end
                          do (setf (aref classes position) :atom))
                    (setf index end)))
                 ((and (char= character #\#)
                       (< (1+ index) length)
                       (char= (char text (1+ index)) #\|))
                  (let* ((close (search "|#" text :start2 (+ index 2)))
                         (end (if close (+ close 2) length)))
                    (loop for position from index below end
                          do (setf (aref classes position) :comment))
                    (setf index end)))
                 ((char= character #\;)
                  (let ((end (or (position #\Newline text :start index) length)))
                    (loop for position from index below end
                          do (setf (aref classes position) :comment))
                    (setf index end)))
                 ((char= character #\")
                  (let ((end (%sexp-string-end text index length)))
                    (loop for position from index below end
                          do (setf (aref classes position) :string))
                    (setf index end)))
                 (t (incf index)))))
    classes))

(defun %sexp-code-p (classes index)
  (eq (aref classes index) :code))

(defun %sexp-open-p (text classes index)
  (and (%sexp-code-p classes index)
       (member (char text index) +sexp-open-characters+ :test #'char=)))

(defun %sexp-close-p (text classes index)
  (and (%sexp-code-p classes index)
       (member (char text index) +sexp-close-characters+ :test #'char=)))
