(in-package #:loom)

(defun %sexp-motion-context ()
  "Return (VALUES BUFFER TEXT LOCAL-OFFSET START) for the selected buffer.

Motion is computed against the visible text, so a narrowed buffer cannot move
point outside its own region, and the offsets are translated back by START."
  (let* ((buffer (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))))
         (start (buffer-narrow-start-offset buffer))
         (text (buffer-visible-text buffer))
         (offset (%clamp-sexp-motion-offset
                  (- (buffer-point-offset buffer) start)
                  (length text))))
    (values buffer text offset start)))

(defun %clamp-sexp-motion-offset (offset length)
  (max 0 (min length offset)))

(defun %move-point-to-local-offset (buffer start offset)
  (%move-point-to-offset buffer (+ start offset)))

(defmacro define-sexp-motion-command (name documentation offset-function)
  "Define a zero-argument command moving point to OFFSET-FUNCTION's result.

A NIL result means the motion has nowhere to go -- the end of the region, an
enclosing list's own parenthesis, or unbalanced text -- and leaves point alone
rather than guessing."
  (let ((target-var (gensym "TARGET-")))
    `(defun ,name ()
     ,documentation
     (multiple-value-bind (buffer text offset start) (%sexp-motion-context)
       (let ((,target-var (,offset-function text offset)))
         (when ,target-var
           (%move-point-to-local-offset buffer start ,target-var)))))))

(define-sexp-motion-command forward-sexp
  "Move point past the next S-expression (C-M-f).

The scanner ignores delimiters in strings and #\\ character literals and
skips line comments and nested block comments."
  %forward-sexp-offset)

(define-sexp-motion-command backward-sexp
  "Move point to the start of the previous S-expression (C-M-b)."
  %backward-sexp-offset)

(define-sexp-motion-command backward-up-list
  "Move point to the opening parenthesis of the enclosing list (C-M-u)."
  %backward-up-list-offset)

(define-sexp-motion-command down-list
  "Move point just inside the next opening parenthesis (C-M-d)."
  %down-list-offset)

(defun kill-sexp ()
  "Kill S-expressions after point and push them onto the kill ring (C-M-k)."
  (loom/core/editor-session:editor-state-clear-last-yank *editor-state*)
  (multiple-value-bind (buffer text offset start) (%sexp-motion-context)
    (let* ((prefixed-p (%structural-prefix-p))
           (count (if prefixed-p (max 0 (%command-prefix-count)) 1))
           (end
             (loop with position = offset
                   with target = nil
                   with consumed = nil
                   for step from 1 to count
                   for next = (%forward-sexp-offset text position)
                   do (if (and next (> next position))
                          (setf target next
                                position next
                                consumed t)
                          (return (if (and prefixed-p consumed)
                                      (length text)
                                      target)))
                   finally (return target))))
      (when (and end (> end offset))
        (when (loom/core/buffer:buffer-read-only-p buffer)
          (%move-point-to-offset buffer (+ start end))
          (error "Buffer is read-only: #<buffer ~A>"
                 (loom/core/buffer:buffer-name buffer)))
        (%kill-between-offsets buffer (+ start offset) (+ start end)
                               :coalesce (editor-state-last-command-kill-p
                                          *editor-state*))))
    (setf (editor-state-last-command-kill-p *editor-state*) t))
  nil)
