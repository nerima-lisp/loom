;;;; packages/feature/multiple-cursors/src/application-commands-multiple-cursor.lisp
;;;;
;;;; Application layer: line-oriented multiple-cursor commands and the small
;;;; edit protocol used by ordinary self-insert.  A command that is not part
;;;; of this protocol clears the transient cursor set in input-dispatch.
(in-package #:loom/feature/multiple-cursors)

(defun %multiple-cursor-set-for-buffer (buffer)
  (let ((set (and *editor-state*
                  (editor-state-multiple-cursors *editor-state*))))
    (and set
         (eq buffer (multiple-cursor-set-buffer set))
         set)))

(defun multiple-cursors-active-p (&optional buffer)
  "Return true when a multiple-cursor set exists, optionally for BUFFER."
  (let ((set (and *editor-state*
                  (editor-state-multiple-cursors *editor-state*))))
    (not (null
          (and set
               (or (null buffer)
                   (eq buffer (multiple-cursor-set-buffer set))))))))

(defun multiple-cursors-reset ()
  "Clear the transient multiple-cursor set and return NIL."
  (when *editor-state*
    (setf (editor-state-multiple-cursors *editor-state*) nil))
  nil)

(defun multiple-cursor-offsets-for-buffer (buffer)
  "Return the non-primary cursor offsets belonging to BUFFER."
  (let ((set (%multiple-cursor-set-for-buffer buffer)))
    (if set
        (remove (multiple-cursor-set-primary-offset set)
                (multiple-cursor-set-offsets set)
                :test #'=)
        nil)))

(defun multiple-cursors-preserving-command-p (command)
  "Return true when COMMAND is allowed to keep the cursor set active."
  (not (null
        (member command
                '(multiple-cursors-add-next-line
                  multiple-cursors-edit-lines
                  multiple-cursors-clear
                  delete-char
                  delete-backward-char
                  yank
                  yank-pop)
                :test #'eq))))

(defun %line-column-offset (buffer line column)
  (loop with offset = 0
        for preceding-line below line
        do (incf offset
                 (1+ (length (buffer-line buffer preceding-line))))
        finally (return (+ offset column))))

(defun %line-column-offset-at-column (buffer line column)
  (let ((line-length (length (buffer-line buffer line))))
    (%line-column-offset buffer line (min column line-length))))

(defun %clamp-offset-to-visible-region (buffer offset)
  (max (buffer-narrow-start-offset buffer)
       (min offset (buffer-narrow-end-offset buffer))))

(defun %multiple-cursor-message (text)
  (when (and *editor-state* (editor-state-minibuffer *editor-state*))
    (minibuffer-message (editor-state-minibuffer *editor-state*) text)))

(defun %set-multiple-cursors (buffer offsets primary-offset)
  (setf (editor-state-multiple-cursors *editor-state*)
        (make-multiple-cursor-set buffer offsets
                                  :primary-offset primary-offset)))

(defun %cursor-set-last-line-and-column (buffer set)
  (let* ((last-offset (car (last (multiple-cursor-set-offsets set))))
         (position (buffer-offset-position buffer last-offset)))
    (values (buffer-position-line position)
            (buffer-position-column position))))

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
  (when (and *editor-state* (editor-state-minibuffer *editor-state*))
    (minibuffer-message (editor-state-minibuffer *editor-state*)
                        "Multiple cursors cleared"))
  t)

(defun multiple-cursors-apply-insert (buffer text)
  "Insert TEXT at every cursor in BUFFER and return true when handled.

The edits run from right to left so the original offsets remain valid.  The
set is then translated to the new text and point is restored to its primary
cursor."
  (let ((set (%multiple-cursor-set-for-buffer buffer)))
    (when set
      (let* ((offsets (copy-list (multiple-cursor-set-offsets set)))
             (primary (multiple-cursor-set-primary-offset set))
             (text-length (length text)))
        (dolist (offset (sort (copy-list offsets) #'>))
          (let ((position (buffer-offset-position buffer offset)))
            (buffer-set-point buffer
                              (buffer-position-line position)
                              (buffer-position-column position))
            (buffer-insert-string buffer text)))
        (let* ((translated
                 (mapcar (lambda (offset)
                           (+ offset
                              (* text-length
                                 (count-if (lambda (insert-offset)
                                             (<= insert-offset offset))
                                           offsets))))
                        offsets))
               (translated-primary
                 (+ primary
                    (* text-length
                       (count-if (lambda (insert-offset)
                                   (<= insert-offset primary))
                                 offsets))))
               (ranges
                (mapcar (lambda (_offset translated-offset)
                           (declare (ignore _offset))
                           (cons (- translated-offset text-length)
                                 translated-offset))
                         offsets
                         translated))
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

(defun %offset-after-deletions (offset ranges)
  "Translate OFFSET after deleting the half-open RANGES before it."
  (- offset
     (loop for range in ranges
           when (<= (cdr range) offset)
             sum (- (cdr range) (car range)))))

(defun %delete-offset-range (buffer range)
  (let* ((start (buffer-offset-position buffer (car range)))
         (end (buffer-offset-position buffer (cdr range))))
    (buffer-delete-region buffer
                           (buffer-position-line start)
                           (buffer-position-column start)
                           (buffer-position-line end)
                           (buffer-position-column end))))

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
               (mapcar (lambda (offset)
                         (%offset-after-deletions offset ranges))
                       offsets))
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
      (let* ((old-endpoints (mapcar #'cdr old-ranges))
             (new-endpoints (mapcar #'cdr new-ranges))
             (offsets
               (mapcar
                (lambda (offset)
                  (or (loop for old-end in old-endpoints
                            for new-end in new-endpoints
                            when (= offset old-end)
                              return new-end)
                      offset))
                (multiple-cursor-set-offsets set)))
             (primary (multiple-cursor-set-primary-offset set))
             (new-primary
               (or (loop for old-end in old-endpoints
                         for new-end in new-endpoints
                         when (= primary old-end)
                           return new-end)
                   primary)))
        (setf (editor-state-multiple-cursors *editor-state*)
              (make-multiple-cursor-set buffer offsets
                                         :primary-offset new-primary))
        t))))
