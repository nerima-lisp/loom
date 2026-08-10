;;;; packages/core/editor/src/domain-buffer.lisp
;;;;
;;;; Domain layer: the public buffer protocol and position/span values. Pure
;;;; text-storage/point-mark/undo state and logic with no dependency on
;;;; cl-tty-kit, cl-host-kit, or
;;;; cl-history-kit -- BUFFER-LOAD/BUFFER-SAVE describe file I/O in their
;;;; contract but only their DEFGENERIC (name, docstring, argument list) is
;;;; declared here; their real, disk-touching :METHOD bodies live in
;;;; infrastructure/filesystem.lisp instead, since they are I/O rather than
;;;; pure buffer state -- see that file's header comment.
;;;;
;;;; A buffer owns text content, point, mark, modification/undo/redo state, and an
;;;; optional backing file path. Piece-table representation and mutation
;;;; helpers live in buffer-storage.lisp; callers only ever see the operations
;;;; below.
;;;;
;;;; Indexing convention, fixed for the whole protocol: line and column
;;;; numbers are zero-based. Line 0 is the first line of a buffer; column 0 is
;;;; the character before the first character of a line. A (line . column)
;;;; pair denotes a position *between* characters, exactly like Emacs point,
;;;; so END values in a region are exclusive.
(in-package #:loom)

(defgeneric make-buffer (&key name path initial-content)
  (:documentation
   "Create and return a new buffer with empty undo and redo history.")
  (:method (&key name path initial-content)
    (let ((original (or initial-content "")))
      (%make-buffer :name (or name "*scratch*")
                    :path path
                    :original original
                    :add-buffer (make-array 0 :element-type (quote character) :adjustable t :fill-pointer 0)
                    :pieces (if (plusp (length original))
                                (list (%make-piece :source :original :start 0 :length (length original)))
                                nil)
                    :narrow-start-offset 0
                    :narrow-end-offset (length original)
                    :point-line 0
                    :point-column 0
                    :mark-line nil
                    :mark-column nil
                    :major-mode :fundamental
                    :read-only-p nil
                    :modified-p nil
                    :undo-list nil
                    :redo-list nil))))

(defgeneric buffer-name (buffer)
  (:documentation "Return BUFFER's display name, as a string.")
  (:method (buffer)
    (%buffer-name buffer)))

(defgeneric buffer-path (buffer)
  (:documentation
   "Return the pathname/namestring BUFFER is associated with, or NIL if the
buffer has never been loaded from or saved to a file.")
  (:method (buffer)
    (%buffer-path buffer)))

(defgeneric buffer-major-mode (buffer)
  (:documentation
   "Return BUFFER's opaque major-mode identity.  The core buffer does not
interpret the identity; feature packages provide its semantics.")
  (:method (buffer)
    (%buffer-major-mode buffer)))

(defgeneric buffer-set-major-mode (buffer mode)
  (:documentation
   "Set BUFFER's opaque major-mode identity to MODE and return BUFFER." )
  (:method (buffer mode)
    (setf (%buffer-major-mode buffer) mode)
    buffer))

(defgeneric buffer-text (buffer)
  (:documentation "Return BUFFER entire contents as a single string.")
  (:method (buffer)
    (%pieces-text buffer)))

(defgeneric buffer-narrow-start-offset (buffer)
  (:documentation
   "Return the absolute, inclusive start offset of BUFFER's visible region." )
  (:method (buffer)
    (%buffer-narrow-start-offset buffer)))

(defgeneric buffer-narrow-end-offset (buffer)
  (:documentation
   "Return the absolute, exclusive end offset of BUFFER's visible region." )
  (:method (buffer)
    (%buffer-narrow-end-offset buffer)))

(defgeneric buffer-narrowed-p (buffer)
  (:documentation "Return true when BUFFER is displaying a narrowed region.")
  (:method (buffer)
    (%buffer-narrowed-p buffer)))

(defgeneric buffer-visible-text (buffer)
  (:documentation
   "Return the text in BUFFER's current visible region, excluding hidden text.")
  (:method (buffer)
    (subseq (buffer-text buffer)
            (%buffer-narrow-start-offset buffer)
            (%buffer-narrow-end-offset buffer))))

(defun %text-offset-to-position-values (text offset)
  "Return LINE and COLUMN for OFFSET in TEXT, clamped to TEXT's bounds."
  (let ((bounded-offset (max 0 (min offset (length text))))
        (line 0)
        (line-start 0))
    (loop for newline = (position #\Newline text :start line-start)
          do (cond
               ((null newline)
                (return (values line (- bounded-offset line-start))))
               ((<= bounded-offset newline)
                (return (values line (- bounded-offset line-start))))
               (t
                (incf line)
                (setf line-start (1+ newline)))))))

(defun %visible-lines (buffer)
  "Return BUFFER's visible text split into lines without trailing newlines."
  (let ((text (buffer-visible-text buffer))
        (start 0)
        (lines nil))
    (loop for newline = (position #\Newline text :start start)
          do (if newline
                 (progn
                   (push (subseq text start newline) lines)
                   (setf start (1+ newline)))
                 (progn
                   (push (subseq text start) lines)
                   (return (nreverse lines)))))))

(defgeneric buffer-visible-line-count (buffer)
  (:documentation "Return the number of lines in BUFFER's visible region.")
  (:method (buffer)
    (length (%visible-lines buffer))))

(defgeneric buffer-visible-line (buffer line-number)
  (:documentation
   "Return the zero-based LINE-NUMBER text in BUFFER's visible region.")
  (:method (buffer line-number)
    (let ((lines (%visible-lines buffer)))
      (unless (and (>= line-number 0) (< line-number (length lines)))
        (error "buffer-visible-line: line-number ~D out of range [0,~D)"
               line-number (length lines)))
      (nth line-number lines))))

(defgeneric buffer-visible-point-line (buffer)
  (:documentation "Return point's zero-based line within BUFFER's visible region.")
  (:method (buffer)
    (multiple-value-bind (line column)
        (%text-offset-to-position-values
         (buffer-visible-text buffer)
         (- (buffer-point-offset buffer) (%buffer-narrow-start-offset buffer)))
      (declare (ignore column))
      line)))

(defgeneric buffer-visible-point-column (buffer)
  (:documentation "Return point's zero-based column within BUFFER's visible region.")
  (:method (buffer)
    (multiple-value-bind (line column)
        (%text-offset-to-position-values
         (buffer-visible-text buffer)
         (- (buffer-point-offset buffer) (%buffer-narrow-start-offset buffer)))
      (declare (ignore line))
      column)))

(defun %clamp-offset-to-narrowing (buffer offset)
  (max (%buffer-narrow-start-offset buffer)
       (min offset (%buffer-narrow-end-offset buffer))))

(defun %region-offsets-within-narrowing
    (buffer start-line start-column end-line end-column)
  (values
   (%clamp-offset-to-narrowing
    buffer
    (%position-to-offset buffer start-line start-column))
   (%clamp-offset-to-narrowing
    buffer
    (%position-to-offset buffer end-line end-column))))

(defun %set-buffer-point-from-offset (buffer offset)
  (multiple-value-bind (line column)
      (%offset-to-position-values buffer offset)
    (setf (%buffer-point-line buffer) line
          (%buffer-point-column buffer) column)))

(defun %set-buffer-mark-from-offset (buffer offset)
  (multiple-value-bind (line column)
      (%offset-to-position-values buffer offset)
    (setf (%buffer-mark-line buffer) line
          (%buffer-mark-column buffer) column)))

(defgeneric buffer-narrow-to-region
    (buffer start-line start-column end-line end-column)
  (:documentation
   "Limit BUFFER's visible and editable region to the half-open region
between the two zero-based positions. Point and mark are clamped into the
new region. Returns BUFFER.")
  (:method (buffer start-line start-column end-line end-column)
    (when (or (< end-line start-line)
              (and (= end-line start-line) (< end-column start-column)))
      (error "buffer-narrow-to-region: end position (~D,~D) precedes start position (~D,~D)"
             end-line end-column start-line start-column))
    (multiple-value-bind (normalized-start-line normalized-start-column)
        (%clamp-position buffer start-line start-column)
      (multiple-value-bind (normalized-end-line normalized-end-column)
          (%clamp-position buffer end-line end-column)
        (let* ((start-offset
                 (%position-to-offset buffer normalized-start-line normalized-start-column))
               (end-offset
                 (%position-to-offset buffer normalized-end-line normalized-end-column))
               ;; A nested narrowing may only make the visible region
               ;; smaller.  Clamp both endpoints before replacing the
               ;; restriction so a caller cannot widen hidden text by
               ;; passing a full-buffer position.
               (visible-start (%buffer-narrow-start-offset buffer))
               (visible-end (%buffer-narrow-end-offset buffer))
               (start-offset (max visible-start
                                   (min start-offset visible-end)))
               (end-offset (max visible-start
                                 (min end-offset visible-end)))
               (point-offset
                 (%position-to-offset buffer
                                      (%buffer-point-line buffer)
                                      (%buffer-point-column buffer)))
               (mark-offset
                 (and (%buffer-mark-line buffer)
                      (%position-to-offset buffer
                                           (%buffer-mark-line buffer)
                                           (%buffer-mark-column buffer)))))
          (setf (%buffer-narrow-start-offset buffer) start-offset
                (%buffer-narrow-end-offset buffer) end-offset)
          (%set-buffer-point-from-offset
           buffer
           (max start-offset (min point-offset end-offset)))
          (when mark-offset
            (%set-buffer-mark-from-offset
             buffer
             (max start-offset (min mark-offset end-offset)))))))
    buffer))

(defgeneric buffer-widen (buffer)
  (:documentation "Make all of BUFFER's full text visible and editable. Returns BUFFER.")
  (:method (buffer)
    (setf (%buffer-narrow-start-offset buffer) 0
          (%buffer-narrow-end-offset buffer) (%buffer-full-length buffer))
    buffer))

(defgeneric buffer-line-count (buffer)
  (:documentation "Return the number of lines in BUFFER; an empty buffer has one line.")
  (:method (buffer)
    (%line-count buffer)))

(defgeneric buffer-line (buffer line-number)
  (:documentation "Return the zero-based LINE-NUMBER text without its trailing newline.")
  (:method (buffer line-number)
    (unless (and (>= line-number 0) (< line-number (%line-count buffer)))
      (error "buffer-line: line-number ~D out of range [0,~D)" line-number (%line-count buffer)))
    (%line-at buffer line-number)))

(defgeneric buffer-point-line (buffer)
  (:documentation "Return the zero-based line number of BUFFER's point.")
  (:method (buffer)
    (%buffer-point-line buffer)))

(defgeneric buffer-point-column (buffer)
  (:documentation
   "Return the zero-based column (in characters, not display width) of
BUFFER's point on its current line.")
  (:method (buffer)
    (%buffer-point-column buffer)))

(defgeneric buffer-set-point (buffer line column)
  (:documentation
   "Move BUFFER's point to the zero-based (LINE, COLUMN) position, clamping
or signalling an error on an out-of-range position at the implementation's
discretion. Returns BUFFER.")
  (:method (buffer line column)
    (multiple-value-bind (clamped-line clamped-column) (%clamp-position buffer line column)
      (let ((offset
              (%clamp-offset-to-narrowing
               buffer
               (%position-to-offset buffer clamped-line clamped-column))))
        (%set-buffer-point-from-offset buffer offset)))
    buffer))

(defgeneric buffer-mark (buffer)
  (:documentation
   "Return the position of BUFFER's mark as (VALUES LINE COLUMN), both
zero-based, or (VALUES NIL NIL) if no mark is currently set.")
  (:method (buffer)
    (values (%buffer-mark-line buffer) (%buffer-mark-column buffer))))

(defgeneric buffer-set-mark (buffer line column)
  (:documentation
   "Set BUFFER's mark to the zero-based (LINE, COLUMN) position. Returns
BUFFER.")
  (:method (buffer line column)
    (multiple-value-bind (clamped-line clamped-column) (%clamp-position buffer line column)
      (let ((offset
              (%clamp-offset-to-narrowing
               buffer
               (%position-to-offset buffer clamped-line clamped-column))))
        (%set-buffer-mark-from-offset buffer offset)))
    buffer))

(defgeneric buffer-insert-string (buffer string)
  (:documentation
   "Insert STRING into BUFFER at point, moving point to just after the
inserted text. Marks BUFFER as modified and records undo information.
Returns BUFFER.")
  (:method (buffer string)
    (%ensure-buffer-writable buffer)
    (unless (zerop (length string))
      (multiple-value-bind (end-line end-column)
          (%do-insert buffer (%buffer-point-line buffer) (%buffer-point-column buffer) string)
        (setf (%buffer-point-line buffer) end-line
              (%buffer-point-column buffer) end-column)))
    buffer))

(defun %delete-char-backward (buffer)
  "Delete the character before point, joining with the previous line at
column 0. A no-op at the very start of the buffer."
  (let ((line (%buffer-point-line buffer))
        (column (%buffer-point-column buffer)))
    (cond
      ((and (= line 0) (= column 0)) nil)
      ((> column 0)
       (%do-delete buffer line (1- column) line column)
       (setf (%buffer-point-line buffer) line
             (%buffer-point-column buffer) (1- column)))
      (t
       (let* ((prev-line (1- line))
              (prev-len (length (%line-at buffer prev-line))))
         (%do-delete buffer prev-line prev-len line 0)
         (setf (%buffer-point-line buffer) prev-line
               (%buffer-point-column buffer) prev-len))))))

(defun %delete-char-forward (buffer)
  "Delete the character at point, joining with the next line at
end-of-line. A no-op at the very end of the buffer."
  (let* ((line (%buffer-point-line buffer))
         (column (%buffer-point-column buffer))
         (line-count (%line-count buffer))
         (line-len (length (%line-at buffer line))))
    (cond
      ((and (= line (1- line-count)) (= column line-len)) nil)
      ((< column line-len) (%do-delete buffer line column line (1+ column)))
      (t (%do-delete buffer line column (1+ line) 0)))))

(defgeneric buffer-delete-char (buffer &key backward)
  (:documentation "Delete one character next to point, returning BUFFER.")
  (:method (buffer &key backward)
    (%ensure-buffer-writable buffer)
    (let ((point-offset (buffer-point-offset buffer)))
      (if backward
          (unless (<= point-offset (%buffer-narrow-start-offset buffer))
            (%delete-char-backward buffer))
          (unless (>= point-offset (%buffer-narrow-end-offset buffer))
            (%delete-char-forward buffer))))
    buffer))

(defgeneric buffer-delete-region (buffer start-line start-column end-line end-column)
  (:documentation
   "Delete the text between the zero-based (START-LINE, START-COLUMN) and
(END-LINE, END-COLUMN) positions (end exclusive). The end position must not
precede the start position. Moves point to the start position. Marks BUFFER
as modified and records undo information. Returns the deleted text as a
string.")
  (:method (buffer start-line start-column end-line end-column)
    (when (or (< end-line start-line)
              (and (= end-line start-line) (< end-column start-column)))
      (error "buffer-delete-region: end position (~D,~D) precedes start position (~D,~D)"
             end-line end-column start-line start-column))
    (%ensure-buffer-writable buffer)
    (multiple-value-bind (start-offset end-offset)
        (%region-offsets-within-narrowing
         buffer start-line start-column end-line end-column)
      (if (= start-offset end-offset)
          ""
          (multiple-value-bind (normalized-start-line normalized-start-column)
              (%offset-to-position-values buffer start-offset)
            (multiple-value-bind (normalized-end-line normalized-end-column)
                (%offset-to-position-values buffer end-offset)
              (let ((text
                      (%do-delete buffer
                                  normalized-start-line normalized-start-column
                                  normalized-end-line normalized-end-column)))
                (%set-buffer-point-from-offset buffer start-offset)
                text)))))))

(defgeneric buffer-region-string (buffer start-line start-column end-line end-column)
  (:documentation
   "Return, without modifying BUFFER, the text between the zero-based
(START-LINE, START-COLUMN) and (END-LINE, END-COLUMN) positions (end
exclusive), as a string.")
  (:method (buffer start-line start-column end-line end-column)
    (when (or (< end-line start-line)
              (and (= end-line start-line) (< end-column start-column)))
      (error "buffer-region-string: end position (~D,~D) precedes start position (~D,~D)"
             end-line end-column start-line start-column))
    (multiple-value-bind (start-offset end-offset)
        (%region-offsets-within-narrowing
         buffer start-line start-column end-line end-column)
      (%piece-table-range-text buffer start-offset end-offset))))

(defgeneric buffer-modified-p (buffer)
  (:documentation
   "Return true if BUFFER has unsaved changes since it was created, loaded,
or last saved.")
  (:method (buffer)
    (%buffer-modified-p buffer)))

(defgeneric buffer-read-only-p (buffer)
  (:documentation "Return true when BUFFER rejects text mutations.")
  (:method (buffer)
    (%buffer-read-only-p buffer)))

(defgeneric buffer-set-read-only (buffer read-only-p)
  (:documentation
   "Set whether BUFFER rejects text mutations and return BUFFER.")
  (:method (buffer read-only-p)
    (setf (%buffer-read-only-p buffer) (not (null read-only-p)))
    buffer))

(defgeneric buffer-mark-saved (buffer)
  (:documentation
   "Mark BUFFER as having no unsaved changes and return BUFFER.")
  (:method (buffer)
    (setf (%buffer-modified-p buffer) nil)
    buffer))

(defgeneric buffer-mark-modified (buffer)
  (:documentation
   "Mark BUFFER as having unsaved changes and return BUFFER.

This is intentionally separate from BUFFER-INSERT-STRING and the other edit
operations: session restoration must be able to restore the saved/modified
invariant without manufacturing an undo entry or changing point.")
  (:method (buffer)
    (setf (%buffer-modified-p buffer) t)
    buffer))

(defgeneric buffer-undo (buffer)
  (:documentation
   "Undo the most recent change group in BUFFER, Emacs ring-style: repeated
calls to BUFFER-UNDO keep walking through the inverse history. The inverse
group is also made available to BUFFER-REDO. Once the history is exhausted,
further calls are a no-op (or signal, at the implementation's discretion).
Returns BUFFER.")
  ;; BUFFER-UNDO keeps the existing ring behavior: its undo-list is a flat,
  ;; most-recent-first sequence of edit entries and :BOUNDARY markers. The
  ;; popped group's inverses are applied through the same mutation primitives
  ;; as ordinary edits, so the inverse-of-the-inverse remains on the undo ring
  ;; and the next BUFFER-UNDO call continues the ring-style walk. In parallel,
  ;; the returned inverse actions are copied to the explicit redo-list. Replay
  ;; passes CLEAR-REDO false, while ordinary edits clear redo history and start
  ;; a new branch.
  (:method (buffer)
    (%ensure-buffer-writable buffer)
    (let ((group (loop for entry = (pop (%buffer-undo-list buffer))
                        until (or (null entry) (eq entry :boundary))
                        collect entry)))
      (when group
        ;; Put the boundary below this group's entries.  Since GROUP is
        ;; consumed newest-first, pushing each inverse reverses it back into
        ;; the original edit order for BUFFER-REDO.
        (push :boundary (%buffer-redo-list buffer))
        (dolist (entry group)
          (push (%apply-undo-entry buffer entry)
                (%buffer-redo-list buffer)))))
    buffer))

(defgeneric buffer-redo (buffer)
  (:documentation
  "Redo the most recently undone change group in BUFFER.

Redo is a no-op when no explicit redo history remains. A subsequent normal
edit clears the redo history. Returns BUFFER.")
  (:method (buffer)
    (%ensure-buffer-writable buffer)
    (let ((group (loop for entry = (pop (%buffer-redo-list buffer))
                       until (or (null entry) (eq entry :boundary))
                       collect entry)))
      (dolist (entry group)
        (%apply-undo-entry buffer entry)))
    buffer))

(defgeneric buffer-record-undo-boundary (buffer)
  (:documentation
   "Record an undo boundary in BUFFER, so edits made before this call and
edits made after it belong to distinct undo groups that BUFFER-UNDO steps
between independently. Returns BUFFER.")
  (:method (buffer)
    (unless (eq (car (%buffer-undo-list buffer)) :boundary)
      (push :boundary (%buffer-undo-list buffer)))
    buffer))

(defgeneric buffer-load (path)
  (:documentation
   "Read the file at PATH via CL-HOST-KIT:READ-FILE-STRING and return a new
buffer (as if by MAKE-BUFFER) whose BUFFER-PATH is PATH, whose initial text
is the file's contents, and whose BUFFER-NAME is derived from PATH's
filename. BUFFER-MODIFIED-P is false on the returned buffer.

Declared here (name, docstring, argument list) only; the real, disk-touching
:METHOD lives in infrastructure/filesystem.lisp, matching how the
disk-touching FILE-TREE-* generics are split from domain/file-tree.lisp
into that same file."))

(defgeneric buffer-save (buffer)
  (:documentation
   "Write BUFFER's contents (as returned by BUFFER-TEXT) to BUFFER-PATH via
CL-HOST-KIT:WRITE-FILE-STRING. Signals an error if BUFFER has no associated
path. On success, clears BUFFER-MODIFIED-P. Returns BUFFER.

Declared here (name, docstring, argument list) only; the real, disk-touching
:METHOD lives in infrastructure/filesystem.lisp, matching how the
disk-touching FILE-TREE-* generics are split from domain/file-tree.lisp
into that same file."))

(deftype buffer-offset ()
  "A non-negative character offset in BUFFER-TEXT."
  '(integer 0 *))

(defstruct (buffer-position
            (:constructor %make-buffer-position (line column)))
  "A zero-based line and column position in a buffer."
  (line 0 :type buffer-offset)
  (column 0 :type buffer-offset))

(defstruct (buffer-span
            (:constructor make-buffer-span (start end)))
  "A half-open character-offset span in a buffer."
  (start 0 :type buffer-offset)
  (end 0 :type buffer-offset))

(defgeneric buffer-visible-offset-position (buffer offset)
  (:documentation
   "Return the visible-region BUFFER-POSITION for absolute OFFSET, or NIL
when OFFSET is outside BUFFER's current visible region. The region end is
accepted as the position just after its last visible character.")
  (:method (buffer offset)
    (when (and (<= (%buffer-narrow-start-offset buffer) offset)
               (<= offset (%buffer-narrow-end-offset buffer)))
      (multiple-value-bind (line column)
          (%text-offset-to-position-values
           (buffer-visible-text buffer)
           (- offset (%buffer-narrow-start-offset buffer)))
        (%make-buffer-position line column)))))

(defun buffer-point-offset (buffer)
  "Return BUFFER's point as an offset in BUFFER-TEXT."
  (let ((offset (buffer-point-column buffer)))
    (loop for line below (buffer-point-line buffer)
          do (incf offset (1+ (length (buffer-line buffer line)))))
    offset))

(defun buffer-offset-position (buffer offset)
  "Return the BUFFER-POSITION corresponding to OFFSET in BUFFER-TEXT."
  (declare (type buffer-offset offset))
  (multiple-value-bind (line column)
      (%offset-to-position-values buffer offset)
    (%make-buffer-position line column)))
