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
;;;; A buffer owns text content, point, mark, modification/undo state, and an
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
   "Create and return a new, empty-undo-history buffer.")
  (:method (&key name path initial-content)
    (let ((original (or initial-content "")))
      (%make-buffer :name (or name "*scratch*")
                    :path path
                    :original original
                    :add-buffer (make-array 0 :element-type (quote character) :adjustable t :fill-pointer 0)
                    :pieces (if (plusp (length original))
                                (list (%make-piece :source :original :start 0 :length (length original)))
                                nil)
                    :point-line 0
                    :point-column 0
                    :mark-line nil
                    :mark-column nil
                    :major-mode :fundamental
                    :modified-p nil
                    :undo-list nil))))

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
      (setf (%buffer-point-line buffer) clamped-line
            (%buffer-point-column buffer) clamped-column))
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
      (setf (%buffer-mark-line buffer) clamped-line
            (%buffer-mark-column buffer) clamped-column))
    buffer))

(defgeneric buffer-insert-string (buffer string)
  (:documentation
   "Insert STRING into BUFFER at point, moving point to just after the
inserted text. Marks BUFFER as modified and records undo information.
Returns BUFFER.")
  (:method (buffer string)
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
    (if backward
        (%delete-char-backward buffer)
        (%delete-char-forward buffer))
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
    (let ((text (%do-delete buffer start-line start-column end-line end-column)))
      (setf (%buffer-point-line buffer) start-line
            (%buffer-point-column buffer) start-column)
      text)))

(defgeneric buffer-region-string (buffer start-line start-column end-line end-column)
  (:documentation
   "Return, without modifying BUFFER, the text between the zero-based
(START-LINE, START-COLUMN) and (END-LINE, END-COLUMN) positions (end
exclusive), as a string.")
  (:method (buffer start-line start-column end-line end-column)
    (%extract-region buffer start-line start-column end-line end-column)))

(defgeneric buffer-modified-p (buffer)
  (:documentation
   "Return true if BUFFER has unsaved changes since it was created, loaded,
or last saved.")
  (:method (buffer)
    (%buffer-modified-p buffer)))

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
   "Undo the most recent change group in BUFFER, Emacs ring-style: there is
no separate redo command, and repeated calls to BUFFER-UNDO keep walking
further back through history. Once the history is exhausted, further calls
are a no-op (or signal, at the implementation's discretion). Returns BUFFER.")
  ;; Ring model, not a stack with a separate redo: BUFFER's undo-list is a
  ;; single flat list of entries with :BOUNDARY markers spliced in by
  ;; BUFFER-RECORD-UNDO-BOUNDARY, most-recent edit first (each edit is
  ;; pushed onto the front by %DO-INSERT/%DO-DELETE). One BUFFER-UNDO call
  ;; pops entries off the front -- most-recent-first, which is exactly the
  ;; order needed to unwind them correctly -- until it hits a :BOUNDARY (or
  ;; the list ends), consuming that terminating marker too, and applies each
  ;; popped entry's inverse via %APPLY-UNDO-ENTRY. Applying an inverse edit
  ;; goes through %DO-INSERT/%DO-DELETE, the very same primitives ordinary
  ;; edits use, so it *also* pushes a fresh undo entry -- the inverse of the
  ;; inverse, i.e. a redo of the original edit -- onto the front of the same
  ;; list, right where the just-undone group used to be. Crucially, no new
  ;; :BOUNDARY is pushed after that: the list is left exactly as if the
  ;; freshly-pushed redo entries had always been there, so the very next
  ;; BUFFER-UNDO call pops them first and undoes them, i.e. replays the
  ;; original edits forward. That "undo of an undo" toggle is what lets
  ;; repeated calls keep making progress -- forward, then back, then forward
  ;; again -- without ever branching into a separate redo structure; it is
  ;; all just one list, mutated by the same two primitives every edit uses.
  (:method (buffer)
    (let ((group (loop for entry = (pop (%buffer-undo-list buffer))
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
            (:constructor %make-buffer-span (start end)))
  "A half-open character-offset span in a buffer."
  (start 0 :type buffer-offset)
  (end 0 :type buffer-offset))

(defun buffer-point-offset (buffer)
  "Return BUFFER's point as an offset in BUFFER-TEXT."
  (let ((offset (buffer-point-column buffer)))
    (loop for line below (buffer-point-line buffer)
          do (incf offset (1+ (length (buffer-line buffer line)))))
    offset))

(defun buffer-offset-position (buffer offset)
  "Return the BUFFER-POSITION corresponding to OFFSET in BUFFER-TEXT."
  (declare (type buffer-offset offset))
  (loop for line below (buffer-line-count buffer)
        for line-length = (length (buffer-line buffer line))
        if (<= offset line-length)
          do (return (%make-buffer-position line offset))
        do (decf offset (1+ line-length))
        finally (let ((last-line (1- (buffer-line-count buffer))))
                  (return
                    (%make-buffer-position
                     last-line
                     (length (buffer-line buffer last-line)))))))
