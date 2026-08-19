;;;; packages/feature/multiple-cursors/src/application-commands-multiple-cursor.lisp
;;;;
;;;; Application layer: line-oriented multiple-cursor commands.  A command
;;;; that is not part of the multiple-cursor edit protocol clears the
;;;; transient cursor set in input-dispatch.
(in-package #:loom/feature/multiple-cursors)

(defun multiple-cursors-add-next-line ()
  "Add a cursor on the next line at the current column.

The first invocation pairs point with the following line.  Later invocations
extend the set below its furthest existing cursor, which makes the command
useful as a repeated line-selection gesture."
  (let* ((buffer (%selected-buffer))
         (set (%multiple-cursor-set-for-buffer buffer)))
    (multiple-value-bind (line column)
        (if set
            (%cursor-set-last-line-and-column buffer set)
            (values (buffer-point-line buffer)
                    (buffer-point-column buffer)))
      (let ((next-line (1+ line)))
        (if (>= next-line (buffer-line-count buffer))
            (progn
              (%multiple-cursor-message "No next line")
              nil)
            (let* ((point-offset (buffer-point-offset buffer))
                   (next-offset
                     (%clamp-offset-to-visible-region
                      buffer
                      (%line-column-offset-at-column buffer next-line column)))
                   (offsets (remove-duplicates
                             (if set
                                 (cons next-offset
                                       (multiple-cursor-set-offsets set))
                                 (list point-offset next-offset))
                             :test #'=)))
              (if (= next-offset point-offset)
                  (progn
                    (%multiple-cursor-message "No next visible line")
                    nil)
                  (progn
                    (%set-multiple-cursors buffer offsets point-offset)
                    t))))))))

(defun multiple-cursors-edit-lines ()
  "Create cursors on every line between point and mark, inclusive."
  (let ((buffer (%selected-buffer)))
    (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
      (declare (ignore mark-column))
      (if (null mark-line)
          (progn
            (%multiple-cursor-message "The mark is not set")
            nil)
          (let* ((point-line (buffer-point-line buffer))
                 (point-column (buffer-point-column buffer))
                 (start-line (min point-line mark-line))
                 (end-line (max point-line mark-line))
                 (offsets
                   (remove-duplicates
                    (loop for line from start-line to end-line
                          collect
                          (%clamp-offset-to-visible-region
                           buffer
                           (%line-column-offset-at-column
                            buffer line point-column)))
                    :test #'=))
                 (point-offset (buffer-point-offset buffer)))
            (%set-multiple-cursors buffer offsets point-offset)
            t)))))

(defun multiple-cursors-clear ()
  "Clear the active multiple-cursor set."
  (multiple-cursors-reset)
  (%multiple-cursor-message "Multiple cursors cleared")
  t)
