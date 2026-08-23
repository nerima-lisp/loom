;;;; packages/core/editor/src/application-commands-sexp.lisp
;;;;
;;;; Application layer: structural motion commands. The offset arithmetic lives
;;;; in application-sexp-motion.lisp; this file only turns it into point and
;;;; kill-ring effects on the selected buffer.
(in-package #:loom)

(defun %sexp-motion-context ()
  "Return (VALUES BUFFER TEXT LOCAL-OFFSET START) for the selected buffer.

Motion is computed against the visible text, so a narrowed buffer cannot move
point outside its own region, and the offsets are translated back by START."
  (let* ((buffer (%selected-buffer))
         (start (buffer-narrow-start-offset buffer))
         (text (buffer-visible-text buffer))
         (offset (max 0 (min (length text)
                             (- (buffer-point-offset buffer) start)))))
    (values buffer text offset start)))

(defun %move-point-to-local-offset (buffer start offset)
  (%move-point-to-offset buffer (+ start offset)))

(defmacro define-sexp-motion-command (name offset-function documentation)
  "Define a zero-argument command moving point to OFFSET-FUNCTION's result.

A NIL result means the motion has nowhere to go -- the end of the region, an
enclosing list's own parenthesis, or unbalanced text -- and leaves point alone
rather than guessing."
  `(defun ,name ()
     ,documentation
     (multiple-value-bind (buffer text offset start) (%sexp-motion-context)
       (let ((target (,offset-function text offset)))
         (when target
           (%move-point-to-local-offset buffer start target))))))

(define-sexp-motion-command forward-sexp %forward-sexp-offset
  "Move point past the next S-expression (C-M-f).

Parentheses inside a string, inside a comment, or in a #\\ character literal
are text rather than structure and are stepped over as part of their atom.")

(define-sexp-motion-command backward-sexp %backward-sexp-offset
  "Move point to the start of the previous S-expression (C-M-b).")

(define-sexp-motion-command backward-up-list %backward-up-list-offset
  "Move point to the opening parenthesis of the enclosing list (C-M-u).")

(define-sexp-motion-command down-list %down-list-offset
  "Move point just inside the next opening parenthesis (C-M-d).")

(defun kill-sexp ()
  "Kill the S-expression after point and push it onto the kill ring (C-M-k).

Adjacent kill commands coalesce into one kill-ring entry, the same way
kill-word and kill-line do, so C-M-k C-M-k yanks back both expressions."
  (%clear-last-yank)
  (multiple-value-bind (buffer text offset start) (%sexp-motion-context)
    (let ((end (%forward-sexp-offset text offset)))
      (when (and end (> end offset))
        (%kill-between-offsets buffer (+ start offset) (+ start end)
                               :coalesce (editor-state-last-command-kill-p
                                          *editor-state*)))))
  (setf (editor-state-last-command-kill-p *editor-state*) t)
  nil)
