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
  (let ((start (%sexp-skip-forward-filler text classes offset)))
    (unless (>= start (length text))
      (%forward-sexp-token-end text classes start))))

(defun %backward-sexp-offset (text offset &optional (classes
                                                     (%sexp-syntax-classes text)))
  "Return the offset where the S-expression before OFFSET begins, or NIL."
  (let ((end (%sexp-skip-backward-filler text classes offset)))
    (unless (zerop end)
      (%backward-sexp-token-start text classes end))))

(defun %backward-up-list-step (text classes position depth)
  (cond
    ((%sexp-close-p text classes position)
     (values (1- position) (1+ depth) nil))
    ((%sexp-open-p text classes position)
     (if (zerop depth)
         (values position depth position)
         (values (1- position) (1- depth) nil)))
    (t (values (1- position) depth nil))))

(defun %backward-up-list-offset (text offset &optional
                                             (classes
                                              (%sexp-syntax-classes text)))
  "Return the offset of the opening parenthesis enclosing OFFSET, or NIL."
  (loop with depth = 0
        with position = (1- offset)
        while (>= position 0)
        do (multiple-value-bind (next-position next-depth found)
               (%backward-up-list-step text classes position depth)
             (when found (return found))
             (setf position next-position
                   depth next-depth))
        finally (return)))

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
  (cond
    ((and (< offset (length text))
          (%sexp-open-p text classes offset))
     (%matching-open-paren-offset text classes offset))
    ((and (plusp offset)
          (%sexp-close-p text classes (1- offset)))
     (%matching-close-paren-offset text classes offset))
    (t (values nil nil))))

(defun %matching-open-paren-offset (text classes offset)
  "Return the opening parenthesis and its match when OFFSET is on one."
  (when (and (< offset (length text))
             (%sexp-open-p text classes offset))
    (let ((end (%sexp-forward-list-end text classes offset)))
      (values offset (and end (1- end))))))

(defun %matching-close-paren-offset (text classes offset)
  "Return the closing parenthesis and its match when OFFSET follows one."
  (when (and (plusp offset)
             (%sexp-close-p text classes (1- offset)))
    (values (1- offset)
            (%sexp-backward-list-start text classes offset))))
