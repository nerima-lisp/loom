(in-package #:loom/feature/kill-ring)

(progn
  (defun %word-character-p (character)
    (or (alphanumericp character) (char= character (char "_" 0))))
  (defun %forward-word-offset (text offset)
    (let ((length (length text)))
      (loop while (and (< offset length)
                       (not (%word-character-p (char text offset))))
            do (incf offset))
      (loop while (and (< offset length) (%word-character-p (char text offset)))
            do (incf offset))
      offset))
  (defun %backward-word-offset (text offset)
    (loop while (and (plusp offset)
                     (not (%word-character-p (char text (1- offset)))))
          do (decf offset))
    (loop while (and (plusp offset) (%word-character-p (char text (1- offset))))
          do (decf offset))
    offset)
  (defun %walk-word-offset (text point count stepper)
    (loop with offset = point
          repeat
          count
          do (setf offset (funcall stepper text offset))
          finally (return offset))))

(defun %ordered-kill-range (point target prepend)
  (if (< target point)
      (values target point prepend)
      (values point target prepend)))

(defun %apply-word-kill (buffer start-offset start end prepend)
  (when start
    (kill-between-offsets buffer
                           (+ start-offset start)
                           (+ start-offset end)
                           :prepend
                           prepend
                           :coalesce
                           (editor-state-last-command-kill-p *editor-state*))))

(defun %kill-word-range (text point
                              count
                              positive-step
                              negative-step
                              &key
                              prepend-when-positive)
  "Translate COUNT at POINT into visible-text offsets and coalescing direction.

POSITIVE-STEP and NEGATIVE-STEP walk the offset for positive and negative
prefix arguments respectively. Returns START, END, and whether the deleted
text should be prepended when coalescing into the newest kill-ring entry."
  (cond
    ((plusp count)
     (%ordered-kill-range point
                          (%walk-word-offset text point count positive-step)
                          prepend-when-positive))
    ((minusp count)
     (%ordered-kill-range point
                          (%walk-word-offset text point (- count) negative-step)
                          (not prepend-when-positive)))
    (t (values nil nil nil))))

(defun %execute-word-kill (positive-step negative-step
                                         &key
                                         prepend-when-positive)
  (let* ((buffer (%selected-kill-ring-buffer))
         (count (%kill-ring-command-prefix-count))
         (start-offset (buffer-narrow-start-offset buffer))
         (point (- (buffer-point-offset buffer) start-offset))
         (text (buffer-visible-text buffer)))
    (multiple-value-bind (start end prepend)
        (%kill-word-range text
                          point
                          count
                          positive-step
                          negative-step
                          :prepend-when-positive
                          prepend-when-positive)
      (%apply-word-kill buffer start-offset start end prepend))))

(defmacro define-word-kill-command (name docstring
                                         positive-step
                                         negative-step
                                         &key
                                         prepend-when-positive)
  `(defun ,name ()
     ,docstring
     (%clear-last-yank)
     (%execute-word-kill ,positive-step
                         ,negative-step
                         :prepend-when-positive
                         ,prepend-when-positive)
     (setf (editor-state-last-command-kill-p *editor-state*) t)))
