;;;; packages/core/editor/src/application-sexp-motion.lisp
;;;;
;;;; Application-layer S-expression boundary helpers, the structural sibling of
;;;; application-word-motion.lisp: both turn a text plus an offset into another
;;;; offset, so the command entrypoints and the presentation layer can share one
;;;; unit without depending on each other.
;;;;
;;;; A parenthesis only counts as structure when it is code. Inside a string,
;;;; inside a `;' or `#| |#' comment, or as the payload of a `#\' character
;;;; literal it is just a character, and treating it as structure is how a
;;;; matching-paren display ends up pointing at the wrong place. Every helper
;;;; here therefore works against a syntax classification of the whole text
;;;; rather than looking at one character in isolation.
(in-package #:loom)

(defparameter +sexp-open-characters+ '(#\( #\[ #\{))
(defparameter +sexp-close-characters+ '(#\) #\] #\}))

(defun %sexp-whitespace-p (character)
  (member character '(#\Space #\Tab #\Newline #\Return #\Page) :test #'char=))

(defun %sexp-character-literal-end (text index length)
  "Return the index just past a `#\\X' literal beginning at INDEX.

The payload is at least one character -- `#\\(' is a literal left parenthesis --
and continues while the text is alphabetic, so named literals like `#\\Space'
are consumed whole rather than leaving `pace' behind as an atom."
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
  "Classify every character of TEXT as :CODE, :STRING, :COMMENT, or :ATOM.

:ATOM covers the characters of a character literal, which are neither code nor
comment but must not be read as structure. The scan is left to right and
single pass: reader state is what decides these classes, and there is no way to
know a character's class without knowing what preceded it."
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

(defun %sexp-skip-forward-filler (text classes offset)
  "Return the first index at or after OFFSET that begins something readable."
  (let ((length (length text)))
    (loop while (and (< offset length)
                     (or (eq (aref classes offset) :comment)
                         (and (%sexp-code-p classes offset)
                              (%sexp-whitespace-p (char text offset)))))
          do (incf offset))
    offset))

(defun %sexp-skip-backward-filler (text classes offset)
  "Return the first index at or before OFFSET that ends something readable."
  (loop while (and (plusp offset)
                   (or (eq (aref classes (1- offset)) :comment)
                       (and (%sexp-code-p classes (1- offset))
                            (%sexp-whitespace-p (char text (1- offset))))))
        do (decf offset))
  offset)

(defun %sexp-forward-list-end (text classes offset)
  "Return the index just past the list opening at OFFSET, or NIL if unbalanced."
  (let ((length (length text))
        (depth 0)
        (position offset))
    (loop while (< position length)
          do (cond ((%sexp-open-p text classes position) (incf depth))
                   ((%sexp-close-p text classes position)
                    (decf depth)
                    (when (zerop depth)
                      (return-from %sexp-forward-list-end (1+ position)))))
             (incf position))
    nil))

(defun %sexp-backward-list-start (text classes offset)
  "Return the index of the list whose closing character ends at OFFSET.

OFFSET is exclusive, as a backward motion's starting point always is. Returns
NIL when the parentheses do not balance."
  (let ((depth 0)
        (position (1- offset)))
    (loop while (>= position 0)
          do (cond ((%sexp-close-p text classes position) (incf depth))
                   ((%sexp-open-p text classes position)
                    (decf depth)
                    (when (zerop depth)
                      (return-from %sexp-backward-list-start position))))
             (decf position))
    nil))

(defun %sexp-atom-end (text classes offset)
  (let ((length (length text)))
    (loop while (and (< offset length)
                     (%sexp-code-p classes offset)
                     (not (%sexp-whitespace-p (char text offset)))
                     (not (%sexp-open-p text classes offset))
                     (not (%sexp-close-p text classes offset))
                     (not (char= (char text offset) #\")))
          do (incf offset))
    ;; A `#\X' literal is one atom even though its characters are :ATOM rather
    ;; than :CODE, so an atom that stopped right at one keeps going.
    (loop while (and (< offset length) (eq (aref classes offset) :atom))
          do (incf offset))
    offset))

(defun %sexp-atom-start (text classes offset)
  (loop while (and (plusp offset)
                   (or (eq (aref classes (1- offset)) :atom)
                       (and (%sexp-code-p classes (1- offset))
                            (not (%sexp-whitespace-p (char text (1- offset))))
                            (not (%sexp-open-p text classes (1- offset)))
                            (not (%sexp-close-p text classes (1- offset)))
                            (not (char= (char text (1- offset)) #\")))))
        do (decf offset))
  offset)

(defun %forward-sexp-offset (text offset &optional (classes
                                                    (%sexp-syntax-classes text)))
  "Return the offset just past the S-expression after OFFSET, or NIL.

NIL means there is nothing to move over: the end of the text, a closing
parenthesis that belongs to an enclosing list, or an unbalanced opening one."
  (let* ((length (length text))
         (start (%sexp-skip-forward-filler text classes offset)))
    (cond
      ((>= start length) nil)
      ((%sexp-close-p text classes start) nil)
      ((%sexp-open-p text classes start)
       (%sexp-forward-list-end text classes start))
      ;; A string literal's own quotes are classified :STRING along with its
      ;; contents, so this cannot ask whether the quote is :CODE.
      ((eq (aref classes start) :string)
       (let ((end start))
         (loop while (and (< end length) (eq (aref classes end) :string))
               do (incf end))
         end))
      (t (let ((end (%sexp-atom-end text classes start)))
           (and (> end start) end))))))

(defun %backward-sexp-offset (text offset &optional (classes
                                                     (%sexp-syntax-classes text)))
  "Return the offset where the S-expression before OFFSET begins, or NIL."
  (let ((end (%sexp-skip-backward-filler text classes offset)))
    (cond
      ((zerop end) nil)
      ((%sexp-open-p text classes (1- end)) nil)
      ((%sexp-close-p text classes (1- end))
       (%sexp-backward-list-start text classes end))
      ((eq (aref classes (1- end)) :string)
       (let ((start (1- end)))
         (loop while (and (plusp start)
                          (eq (aref classes (1- start)) :string))
               do (decf start))
         start))
      (t (let ((start (%sexp-atom-start text classes end)))
           (and (< start end) start))))))

(defun %backward-up-list-offset (text offset &optional
                                             (classes
                                              (%sexp-syntax-classes text)))
  "Return the offset of the opening parenthesis enclosing OFFSET, or NIL."
  (let ((depth 0)
        (position (1- offset)))
    (loop while (>= position 0)
          do (cond ((%sexp-close-p text classes position) (incf depth))
                   ((%sexp-open-p text classes position)
                    (if (zerop depth)
                        (return-from %backward-up-list-offset position)
                        (decf depth))))
             (decf position))
    nil))

(defun %down-list-offset (text offset &optional (classes
                                                 (%sexp-syntax-classes text)))
  "Return the offset just inside the next opening parenthesis, or NIL."
  (let ((length (length text))
        (position offset))
    (loop while (< position length)
          do (when (%sexp-open-p text classes position)
               (return-from %down-list-offset (1+ position)))
             (when (%sexp-close-p text classes position)
               (return-from %down-list-offset nil))
             (incf position))
    nil))

(defun %matching-paren-offset (text offset &optional
                                           (classes
                                            (%sexp-syntax-classes text)))
  "Return (VALUES PAREN MATCH) for the parenthesis point at OFFSET is next to.

Point is adjacent to a parenthesis either by sitting on an opening one or by
sitting just after a closing one, which is how Emacs decides. Returns NIL when
point is next to no parenthesis, and NIL for MATCH when the parentheses do not
balance -- an unbalanced list must not be shown a match it does not have."
  (let ((length (length text)))
    (cond
      ((and (< offset length) (%sexp-open-p text classes offset))
       (let ((end (%sexp-forward-list-end text classes offset)))
         (values offset (and end (1- end)))))
      ((and (plusp offset) (%sexp-close-p text classes (1- offset)))
       (values (1- offset)
               (%sexp-backward-list-start text classes offset)))
      (t (values nil nil)))))
