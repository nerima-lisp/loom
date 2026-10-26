(in-package #:loom)

(defun %run-structural-command
    (edit-function buffer text offset start &optional undo-anchor)
  (multiple-value-bind (edits application-order reindent-offset point-offset)
      (funcall edit-function text (%sexp-syntax-classes text) offset)
    (when edits
      (when (loom/core/buffer:buffer-read-only-p buffer)
        (error "Buffer is read-only: #<buffer ~A>"
               (loom/core/buffer:buffer-name buffer)))
      (when undo-anchor
        (%record-structural-undo-anchor
         buffer (ecase undo-anchor
                  (:start start)
                  (:end (+ start (length text))))))
      (%apply-structural-edits buffer start edits application-order)
      (let* ((adjusted-offset
               (or point-offset (%structural-adjusted-offset edits offset)))
             (absolute-offset (+ start adjusted-offset)))
        (%move-point-to-offset buffer absolute-offset)
        (when reindent-offset
          (let* ((point-position (buffer-offset-position buffer absolute-offset))
                 (indent-position
                   (buffer-offset-position buffer (+ start reindent-offset)))
                 (point-line (buffer-position-line point-position))
                 (point-column (buffer-position-column point-position))
                 (indent-line (buffer-position-line indent-position))
                 (line-before (buffer-line buffer indent-line))
                 (old-indentation
                   (loop for character across line-before
                         while (or (char= character #\Space)
                                   (char= character #\Tab))
                         count 1)))
            (%move-point-to-offset buffer (+ start reindent-offset))
            (loom/feature/mode:indent-for-tab-command)
            (let* ((line-after (buffer-line buffer point-line))
                   (new-indentation
                     (loop for character across line-after
                           while (or (char= character #\Space)
                                     (char= character #\Tab))
                           count 1))
                   (restored-column
                     (if (= point-line indent-line)
                         (if (< point-column old-indentation)
                             (min point-column new-indentation)
                             (+ new-indentation
                                (- point-column old-indentation)))
                         point-column)))
              (loom/core/buffer:buffer-set-point
               buffer point-line restored-column))))))))
(defun %record-structural-undo-anchor (buffer offset)
  (let* ((position (buffer-offset-position buffer offset))
         (line (buffer-position-line position))
         (column (buffer-position-column position)))
    ;; Emacs restores this point after undoing the structural edit group.
    (loom/core/buffer:buffer-set-point buffer line column)
    (loom/core/buffer:buffer-insert-string buffer " ")
    (loom/core/buffer:buffer-delete-region
     buffer line column line (1+ column))))

(defmacro define-structural-command
    (name documentation edit-function &optional (undo-anchor :end))
  "Define a zero-argument structural editing command.

EDIT-FUNCTION returns the edits to apply, or NIL when the operation has nothing
to act on -- no enclosing list, nothing left to slurp, or no closing delimiter
found by the depth scanner. NIL leaves the buffer untouched."
  `(defun ,name ()
     ,documentation
     (multiple-value-call #'%run-structural-command #',edit-function
       (%sexp-motion-context)
       ,undo-anchor)
     nil))

(define-structural-command forward-slurp-sexp
  "Move the enclosing list's closing delimiter past the next expression (C-<right>).

`(a) b' becomes `(a b)' by inserting the closing delimiter at the new position
and deleting it at the old position."
  %forward-slurp-edits)

(define-structural-command forward-barf-sexp
  "Move the enclosing list's closing delimiter in past its last expression (C-<left>).

`(a b)' becomes `(a) b'."
  %forward-barf-edits)

(define-structural-command backward-slurp-sexp
  "Move the enclosing list's opening delimiter back past the previous expression (C-M-<left>).

`a (b)' becomes `(a b)'."
  %backward-slurp-edits)

(define-structural-command backward-barf-sexp
  "Move the enclosing list's opening delimiter in past its first expression (C-M-<right>).

`(a b)' becomes `a (b)'."
  %backward-barf-edits
  :start)

(define-structural-command splice-sexp
  "Remove the enclosing list's delimiters, keeping its contents (M-s).

`(a (b c) d)' with point inside the inner list becomes `(a b c d)'."
  %splice-edits)

(define-structural-command raise-sexp
  "Replace the enclosing list with the expression at point (M-r).

`(a (b c) d)' with point at the inner list becomes `(b c)'."
  %raise-edits)

(defun wrap-round ()
  "Wrap the expression after point in a new pair of parentheses (M-().

With nothing to wrap -- at the end of the buffer, or immediately before a
closing delimiter -- an empty pair is inserted instead. Point ends up just
inside the new opening delimiter either way, which is where the next thing
typed belongs."
  (multiple-value-bind (buffer text offset start) (%sexp-motion-context)
    (let* ((classes (%sexp-syntax-classes text))
           (opening (%sexp-skip-forward-filler text classes offset)))
      (multiple-value-bind (edits application-order)
          (%wrap-round-edits text classes offset)
        (when edits
          (when (loom/core/buffer:buffer-read-only-p buffer)
            (error "Buffer is read-only: #<buffer ~A>"
                   (loom/core/buffer:buffer-name buffer)))
          (%record-structural-undo-anchor
           buffer (+ start (length text)))
          (%apply-structural-edits buffer start edits application-order)
          (%move-point-to-offset buffer (+ start opening 1))))))
  nil)
