;;;; packages/feature/multiple-cursors/src/application-multiple-cursor-edit-protocol.lisp
;;;;
;;;; Application-layer edit protocol for multiple cursors.  Ordinary editing
;;;; commands call into this file so they can share insert/delete/yank-pop
;;;; behavior without depending on the line-oriented command definitions.
(in-package #:loom/feature/multiple-cursors)

(defun multiple-cursors-apply-insert (buffer text)
  "Insert TEXT at every cursor in BUFFER and return true when handled.

The edits run from right to left so the original offsets remain valid.  The
set is then translated to the new text and point is restored to its primary
cursor."
  (let ((set (%multiple-cursor-set-for-buffer buffer)))
    (when set
      (let* ((offsets (copy-list (multiple-cursor-set-offsets set)))
             (primary (multiple-cursor-set-primary-offset set))
             (text-length (length text))
             (translated
               (%translated-offsets-after-insert offsets text-length))
             (translated-primary
               (%translated-primary-after-insert primary offsets text-length)))
        (dolist (offset (sort (copy-list offsets) #'>))
          (let ((position (buffer-offset-position buffer offset)))
            (buffer-set-point buffer
                              (buffer-position-line position)
                              (buffer-position-column position))
            (buffer-insert-string buffer text)))
        (let* ((ranges
                 (%inserted-ranges offsets translated text-length))
               (primary-index (position primary offsets :test #'=))
               (primary-range (nth primary-index ranges))
               (new-set (make-multiple-cursor-set
                         buffer translated
                         :primary-offset translated-primary))
               (primary-position
                 (buffer-offset-position buffer translated-primary)))
          (setf (editor-state-multiple-cursors *editor-state*) new-set)
          (buffer-set-point buffer
                            (buffer-position-line primary-position)
                            (buffer-position-column primary-position))
          (values t
                  ranges
                  (car primary-range)
                  (cdr primary-range)))))))

(defun multiple-cursors-apply-delete (buffer &key backward)
  "Delete one character at every active cursor in BUFFER.

The deletion ranges are calculated before editing and applied right to left,
so each cursor is translated against the same original coordinate system.
Return true when an active cursor set handled the command."
  (let ((set (%multiple-cursor-set-for-buffer buffer)))
    (when set
      (let* ((offsets (copy-list (multiple-cursor-set-offsets set)))
             (primary (multiple-cursor-set-primary-offset set))
             (start (buffer-narrow-start-offset buffer))
             (end (buffer-narrow-end-offset buffer))
             (ranges
               (remove-if
                #'null
                (mapcar
                 (lambda (offset)
                   (if backward
                       (and (> offset start)
                            (cons (1- offset) offset))
                       (and (< offset end)
                            (cons offset (1+ offset)))))
                 offsets)))
             (translated
               (%translated-offsets-after-delete offsets ranges))
             (translated-primary
               (%offset-after-deletions primary ranges)))
        (dolist (range (sort (copy-list ranges) #'> :key #'car))
          (%delete-offset-range buffer range))
        (let ((new-set
                (make-multiple-cursor-set
                 buffer translated
                 :primary-offset translated-primary)))
          (setf (editor-state-multiple-cursors *editor-state*) new-set)
          (let ((position
                  (buffer-offset-position buffer translated-primary)))
            (buffer-set-point buffer
                              (buffer-position-line position)
                              (buffer-position-column position))))
        t))))

(defun multiple-cursors-update-after-yank-pop (buffer old-ranges new-ranges)
  "Translate active yank-end cursors from OLD-RANGES to NEW-RANGES.

YANK-POP changes the length of each inserted range.  The active multiple
cursor set normally points at the ends of those ranges, so preserve those
cursor locations while the ordinary yank bookkeeping replaces the text."
  (let ((set (%multiple-cursor-set-for-buffer buffer)))
    (when (and set (= (length old-ranges) (length new-ranges)))
      (let* ((offsets
               (%translate-endpoint-offsets
                (multiple-cursor-set-offsets set)
                old-ranges
                new-ranges))
             (primary (multiple-cursor-set-primary-offset set))
             (new-primary
               (car (%translate-endpoint-offsets
                     (list primary)
                     old-ranges
                     new-ranges))))
        (setf (editor-state-multiple-cursors *editor-state*)
              (make-multiple-cursor-set buffer offsets
                                        :primary-offset new-primary))
        t))))
