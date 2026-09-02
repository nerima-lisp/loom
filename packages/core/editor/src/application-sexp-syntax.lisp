;;;; packages/core/editor/src/application-sexp-syntax.lisp
;;;;
;;;; Reader-aware syntax classification shared by S-expression motion helpers.
(in-package #:loom)

(defmacro define-sexp-character-set (name characters)
  `(defparameter ,name ',characters))

(define-sexp-character-set +sexp-open-characters+ (#\( #\[ #\{))
(define-sexp-character-set +sexp-close-characters+ (#\) #\] #\}))

(defun %sexp-whitespace-p (character)
  (member character '(#\Space #\Tab #\Newline #\Return #\Page) :test #'char=))

(defun %sexp-character-name-end (text position length)
  (loop while (and (< position length) (alpha-char-p (char text position)))
        do (incf position))
  position)

(defun %sexp-character-literal-end (text index length)
  "Return the index just past a `#\\X' literal beginning at INDEX."
  (let ((position (min length (+ index 2))))
    (when (< position length)
      (incf position)
      (setf position (%sexp-character-name-end text position length)))
    position))

(defun %sexp-string-next-position (text position length)
  (case (char text position)
    (#\\ (values (%sexp-string-escaped-position position length) nil))
    (#\" (values (1+ position) t))
    (otherwise (values (1+ position) nil))))

(defun %sexp-string-escaped-position (position length)
  (min length (+ position 2)))

(defun %sexp-string-end (text index length)
  "Return the index just past the string literal opening at INDEX."
  (let ((position (1+ index))
        (closed nil))
    (loop while (and (< position length) (not closed))
          do (multiple-value-setq (position closed)
               (%sexp-string-next-position text position length)))
    position))

(defun %mark-sexp-range (classes start end class)
  (loop for position from start below end
        do (setf (aref classes position) class)))

(defun %sexp-reader-dispatch-character (text index length)
  (when (< (1+ index) length)
    (char text (1+ index))))

(defun %sexp-reader-block-comment-end (text index length)
  (let ((close (search "|#" text :start2 (+ index 2))))
    (if close (+ close 2) length)))

(defun %sexp-reader-range (text index length)
  (case (%sexp-reader-dispatch-character text index length)
    (#\\ (values :atom (%sexp-character-literal-end text index length)))
    (#\| (values :comment (%sexp-reader-block-comment-end text index length)))
    (otherwise nil)))

(defun %sexp-comment-range (text index length)
  (values :comment (or (position #\Newline text :start index) length)))

(defun %sexp-string-range (text index length)
  (values :string (%sexp-string-end text index length)))

(defun %sexp-special-range (text index length character)
  (cond
    ((char= character #\#)
     (%sexp-reader-range text index length))
    ((char= character #\;)
     (%sexp-comment-range text index length))
    ((char= character #\")
     (%sexp-string-range text index length))
    (t nil)))

(defun %mark-sexp-special-range (text classes index length character)
  (multiple-value-bind (class end)
      (%sexp-special-range text index length character)
    (when class
      (%mark-sexp-range classes index end class))
    (values class end)))

(defun %next-sexp-syntax-index (text classes index length)
  (multiple-value-bind (class end)
      (%mark-sexp-special-range text classes index length (char text index))
    (if class end (1+ index))))

(defun %sexp-syntax-classes (text)
  "Classify every character of TEXT as :CODE, :STRING, :COMMENT, or :ATOM."
  (let* ((length (length text))
         (classes (make-array (max length 1) :initial-element :code))
         (index 0))
    (loop while (< index length)
          do (setf index (%next-sexp-syntax-index text classes index length)))
    classes))

(defun %sexp-code-p (classes index)
  (eq (aref classes index) :code))

(defun %sexp-open-p (text classes index)
  (and (%sexp-code-p classes index)
       (member (char text index) +sexp-open-characters+ :test #'char=)))

(defun %sexp-close-p (text classes index)
  (and (%sexp-code-p classes index)
       (member (char text index) +sexp-close-characters+ :test #'char=)))
