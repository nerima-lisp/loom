;;;; packages/core/editor/src/application-commands-structural-editing.lisp
;;;;
;;;; Application layer: paredit-style structural editing commands. The offset
;;;; arithmetic lives in application-structural-editing.lisp; this file only
;;;; drives it against the selected buffer and decides where point lands.
;;;;
;;;; Each command performs several edits, and all of them land in one undo
;;;; group: the dispatcher records an undo boundary before a command runs and
;;;; nothing here records another, so BUFFER-UNDO walks back over the whole
;;;; operation rather than half of it.
(in-package #:loom)

(defmacro define-structural-command (name edit-function documentation)
  "Define a zero-argument structural editing command.

EDIT-FUNCTION returns the edits to apply, or NIL when the operation has nothing
to act on -- no enclosing list, nothing left to slurp, an unbalanced form. NIL
leaves the buffer untouched rather than guessing, because a structural command
that half-applies is exactly the failure these commands exist to avoid."
  `(defun ,name ()
     ,documentation
     (multiple-value-bind (buffer text offset start) (%sexp-motion-context)
       (let* ((classes (%sexp-syntax-classes text))
              (edits (,edit-function text classes offset)))
         (when edits
           (%apply-structural-edits buffer start edits)
           (%move-point-to-offset
            buffer (+ start (%structural-adjusted-offset edits offset))))))
     nil))

(define-structural-command forward-slurp-sexp %forward-slurp-edits
  "Move the enclosing list's closing delimiter past the next expression (C-<right>).

`(a) b' becomes `(a b)'. The delimiter moves rather than being deleted and
retyped, so the parentheses cannot come out unbalanced.")

(define-structural-command forward-barf-sexp %forward-barf-edits
  "Move the enclosing list's closing delimiter in past its last expression (C-<left>).

`(a b)' becomes `(a) b'.")

(define-structural-command backward-slurp-sexp %backward-slurp-edits
  "Move the enclosing list's opening delimiter back past the previous expression (C-M-<left>).

`a (b)' becomes `(a b)'.")

(define-structural-command backward-barf-sexp %backward-barf-edits
  "Move the enclosing list's opening delimiter in past its first expression (C-M-<right>).

`(a b)' becomes `a (b)'.")

(define-structural-command splice-sexp %splice-edits
  "Remove the enclosing list's delimiters, keeping its contents (M-s).

`(a (b c) d)' with point inside the inner list becomes `(a b c d)'.")

(define-structural-command raise-sexp %raise-edits
  "Replace the enclosing list with the expression at point (M-r).

`(a (b c) d)' with point at the inner list becomes `(b c)'.")

(defun wrap-round ()
  "Wrap the expression after point in a new pair of parentheses (M-().

With nothing to wrap -- at the end of the buffer, or immediately before a
closing delimiter -- an empty pair is inserted instead. Point ends up just
inside the new opening delimiter either way, which is where the next thing
typed belongs."
  (multiple-value-bind (buffer text offset start) (%sexp-motion-context)
    (let* ((classes (%sexp-syntax-classes text))
           (edits (%wrap-round-edits text classes offset))
           (opening (%sexp-skip-forward-filler text classes offset)))
      (when edits
        (%apply-structural-edits buffer start edits)
        ;; Both shapes %WRAP-ROUND-EDITS returns put the opening delimiter at
        ;; OPENING, so point goes one past it without inspecting the edits.
        (%move-point-to-offset buffer (+ start opening 1)))))
  nil)
