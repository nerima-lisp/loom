;;;; packages/core/editor/src/application-structural-editing.lisp
;;;;
;;;; Application layer: the offset arithmetic behind the structural editing
;;;; commands, kept separate from the command entrypoints the way
;;;; application-word-motion.lisp is kept separate from the motion commands.
;;;;
;;;; Every operation here is expressed as a list of edits against the visible
;;;; text rather than as a rewritten string. Two reasons: a whole-region
;;;; replacement would move every mark and point in the buffer, and moving one
;;;; delimiter is what keeps the parentheses balanced by construction -- an
;;;; operation that never writes an unmatched delimiter cannot produce one.
(in-package #:loom)

(defun %structural-list-bounds (text classes offset)
  "Return (VALUES OPEN CLOSE) for the list enclosing OFFSET.

CLOSE is the index of the closing character, not one past it. Returns NIL when
point is not inside a list, or when the list it is inside never closes."
  (let ((open (%backward-up-list-offset text offset classes)))
    (when open
      (let ((end (%sexp-forward-list-end text classes open)))
        (when end
          (values open (1- end)))))))

(defun %structural-separator-needed-p (text offset)
  "True when inserting a delimiter at OFFSET would abut a token.

A barfed expression that ends up written against the delimiter it was just
expelled from is still balanced, but `()a' is not what the user meant to read."
  (and (< offset (length text))
       (let ((character (char text offset)))
         (not (or (%sexp-whitespace-p character)
                  (member character +sexp-close-characters+ :test #'char=))))))

(defun %forward-slurp-edits (text classes offset)
  "Move the enclosing list's closing delimiter past the expression after it."
  (multiple-value-bind (open close) (%structural-list-bounds text classes offset)
    (declare (ignore open))
    (when close
      (let ((target (%forward-sexp-offset text (1+ close) classes)))
        (when target
          (list (list :insert target (string (char text close)))
                (list :delete close 1)))))))

(defun %forward-barf-edits (text classes offset)
  "Move the enclosing list's closing delimiter in past its last expression."
  (multiple-value-bind (open close) (%structural-list-bounds text classes offset)
    (when close
      (let ((last-start (%backward-sexp-offset text close classes)))
        (when (and last-start (> last-start open))
          (let* ((target (%sexp-skip-backward-filler text classes last-start))
                 (delimiter (string (char text close))))
            (list (list :delete close 1)
                  (list :insert target
                        (if (%structural-separator-needed-p text target)
                            (concatenate 'string delimiter " ")
                            delimiter)))))))))

(defun %backward-slurp-edits (text classes offset)
  "Move the enclosing list's opening delimiter back past the expression before it."
  (multiple-value-bind (open close) (%structural-list-bounds text classes offset)
    (declare (ignore close))
    (when open
      (let ((target (%backward-sexp-offset text open classes)))
        (when target
          (list (list :delete open 1)
                (list :insert target (string (char text open)))))))))

(defun %backward-barf-delimiter (text target delimiter)
  "Return DELIMITER positioned before the expression at TARGET."
  (if (and (plusp target)
           (not (%sexp-whitespace-p (char text (1- target)))))
      (concatenate 'string " " delimiter)
      delimiter))

(defun %backward-barf-edits (text classes offset)
  "Move the enclosing list's opening delimiter in past its first expression."
  (multiple-value-bind (open close) (%structural-list-bounds text classes offset)
    (when open
      (let ((first-end (%forward-sexp-offset text (1+ open) classes)))
        (when (and first-end (<= first-end close))
        (let* ((target (%sexp-skip-forward-filler text classes first-end))
               (delimiter (string (char text open)))
                 (moved-delimiter (%backward-barf-delimiter
                                   text target delimiter)))
            (list (list :insert target
                        moved-delimiter)
                  (list :delete open 1))))))))

(defun %wrap-round-edits (text classes offset)
  "Wrap the expression after OFFSET in a new pair of parentheses.

With nothing to wrap -- at the end of the text, or before a closing delimiter
-- an empty pair is inserted instead, which is what makes this usable as a
plain `insert a balanced pair' command."
  (let* ((start (%sexp-skip-forward-filler text classes offset))
         (end (%forward-sexp-offset text offset classes)))
    (if end
        (list (list :insert end ")")
              (list :insert start "("))
        (list (list :insert start "()")))))

(defun %splice-edits (text classes offset)
  "Remove the enclosing list's delimiters, keeping its contents in place."
  (multiple-value-bind (open close) (%structural-list-bounds text classes offset)
    (when close
      (list (list :delete close 1)
            (list :delete open 1)))))

(defun %raise-edits (text classes offset)
  "Replace the enclosing list with the expression at OFFSET.

The expression has to lie strictly inside the list, otherwise there is nothing
to raise it out of and the operation would delete rather than promote."
  (multiple-value-bind (open close) (%structural-list-bounds text classes offset)
    (when close
      (let ((start (%sexp-skip-forward-filler text classes offset))
            (end (%forward-sexp-offset text offset classes)))
        (when (and end (> start open) (<= end close))
          (list (list :delete end (- (1+ close) end))
                (list :delete open (- start open))))))))

(defun %structural-adjusted-offset (edits offset)
  "Return where OFFSET ends up once EDITS have been applied."
  (let ((result offset))
    (dolist (edit edits result)
      (ecase (first edit)
        (:insert
         (let ((position (second edit))
               (length (length (third edit))))
           (when (<= position result)
             (incf result length))))
        (:delete
         (let* ((position (second edit))
                (length (third edit))
                (end (+ position length)))
           (cond ((<= end result) (decf result length))
                 ((< position result) (setf result position)))))))))
