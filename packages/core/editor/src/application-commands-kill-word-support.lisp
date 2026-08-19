;;;; packages/core/editor/src/application-commands-kill-word-support.lisp
;;;;
;;;; Application layer helpers shared by word-oriented kill commands.
(in-package #:loom)

(defun %walk-word-offset (text point count stepper)
  (loop with offset = point
        repeat count
        do (setf offset (funcall stepper text offset))
        finally (return offset)))

(defun %kill-word-range (text point count positive-step negative-step
                         &key prepend-when-positive)
  "Translate COUNT at POINT into visible-text offsets and coalescing direction.

POSITIVE-STEP and NEGATIVE-STEP walk the offset for positive and negative
prefix arguments respectively. Returns START, END, and whether the deleted
text should be prepended when coalescing into the newest kill-ring entry."
  (flet ((ordered-range (target prepend)
           (if (< target point)
               (values target point prepend)
               (values point target prepend))))
    (cond
      ((plusp count)
       (ordered-range
        (%walk-word-offset text point count positive-step)
        prepend-when-positive))
      ((minusp count)
       (ordered-range
        (%walk-word-offset text point (- count) negative-step)
        (not prepend-when-positive)))
      (t
       (values nil nil nil)))))

(defun %execute-word-kill (positive-step negative-step &key prepend-when-positive)
  (let* ((buffer (%selected-buffer))
         (count (%command-prefix-count))
         (start-offset (buffer-narrow-start-offset buffer))
         (point (- (buffer-point-offset buffer) start-offset))
         (text (buffer-visible-text buffer)))
    (multiple-value-bind (start end prepend)
        (%kill-word-range text point count positive-step negative-step
                          :prepend-when-positive prepend-when-positive)
      (when start
        (%kill-between-offsets
         buffer (+ start-offset start) (+ start-offset end)
         :prepend prepend
         :coalesce (editor-state-last-command-kill-p *editor-state*))))))

(defmacro define-word-kill-command (name docstring positive-step negative-step
                                    &key prepend-when-positive)
  `(defun ,name ()
     ,docstring
     (%clear-last-yank)
     (%execute-word-kill ,positive-step ,negative-step
                         :prepend-when-positive ,prepend-when-positive)
     (setf (editor-state-last-command-kill-p *editor-state*) t)))
