;;;; packages/core/editor/src/application-sexp-motion.lisp
;;;;
;;;; Application-layer S-expression boundary helpers, the structural sibling of
;;;; application-word-motion.lisp: both turn a text plus an offset into another
;;;; offset, so the command entrypoints and the presentation layer can share one
;;;; unit without depending on each other.
;;;;
(in-package #:loom)

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
               (return-from %down-list-offset))
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
