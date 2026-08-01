;;;; src/domain/buffer.lisp
;;;;
;;;; Domain layer: the buffer protocol. Pure text-storage/point-mark/undo
;;;; state and logic with no dependency on cl-tty-kit, cl-host-kit, or
;;;; cl-history-kit -- BUFFER-LOAD/BUFFER-SAVE describe file I/O in their
;;;; contract but only their DEFGENERIC (name, docstring, argument list) is
;;;; declared here; their real, disk-touching :METHOD bodies live in
;;;; infrastructure/filesystem.lisp instead, since they are I/O rather than
;;;; pure buffer state -- see that file's header comment.
;;;;
;;;; A buffer owns text content, point, mark, modification/undo state, and an
;;;; optional backing file path. Nothing here prescribes the representation
;;;; (rope, gap buffer, line vector, ...); callers only ever see the operations
;;;; below.
;;;;
;;;; Indexing convention, fixed for the whole protocol: line and column
;;;; numbers are zero-based. Line 0 is the first line of a buffer; column 0 is
;;;; the character before the first character of a line. A (line . column)
;;;; pair denotes a position *between* characters, exactly like Emacs point,
;;;; so END values in a region are exclusive.
(in-package #:loom)

;;; ---------------------------------------------------------------------
;;; Representation
;;;
;;; A plain adjustable vector of line-strings (no rope/gap-buffer -- buffers
;;; here are small enough that splice-by-list-conversion is fast enough, and
;;; a plain vector is much easier to get right). :CONC-NAME and :CONSTRUCTOR
;;; are both overridden so the struct's auto-generated accessor/constructor
;;; names (BUFFER-NAME, MAKE-BUFFER, ...) don't collide with the protocol's
;;; exported generic functions of the same names above.
;;; ---------------------------------------------------------------------

(defstruct (buffer (:constructor %make-buffer) (:conc-name %buffer-))
  "Internal representation of a loom buffer: a line vector plus point, mark,
modified-p, and undo-list state."
  (name "*scratch*" :type string)
  (path nil)
  (lines (make-array 1 :adjustable t :fill-pointer 1 :initial-contents '("")))
  (point-line 0 :type integer)
  (point-column 0 :type integer)
  (mark-line nil :type (or null integer))
  (mark-column nil :type (or null integer))
  (modified-p nil)
  (undo-list nil :type list))

;;; ---------------------------------------------------------------------
;;; Internal helpers
;;;
;;; These are defined before the generics below so nothing here forward-
;;; references a not-yet-defined function; each helper only calls struct
;;; accessors and earlier helpers, never the exported generics themselves.
;;; ---------------------------------------------------------------------

(defun %split-newlines (string)
  "Split STRING on #\\Newline into a list of line-strings. A STRING with no
newline yields a single-element list; a leading, trailing, or doubled
newline yields empty-string elements, matching how buffer lines represent
an empty line. Always returns at least one element, even for \"\"."
  (let ((result nil)
        (start 0))
    (loop
      (let ((pos (position #\Newline string :start start)))
        (if pos
            (progn (push (subseq string start pos) result)
                   (setf start (1+ pos)))
            (progn (push (subseq string start) result)
                   (return)))))
    (nreverse result)))

(defun %advance-position (line column text)
  "Return (values end-line end-column), the position immediately after
inserting TEXT at (LINE, COLUMN) -- without performing any insertion. Used
to recover the end of a span from just its start and its text, e.g. to
compute the end of a previously-inserted span (its start plus its text)
when undoing that insertion by deleting the span back out. Must agree with
how %RAW-INSERT-AT itself computes its returned end position, since
%APPLY-UNDO-ENTRY relies on that agreement to reconstruct spans it never
directly observed."
  (let ((segments (%split-newlines text)))
    (if (= (length segments) 1)
        (values line (+ column (length (first segments))))
        (values (+ line (1- (length segments))) (length (car (last segments)))))))

(defun %lines-list (buffer)
  (coerce (%buffer-lines buffer) 'list))

(defun %set-lines-from-list (buffer list)
  (setf (%buffer-lines buffer)
        (make-array (length list)
                     :adjustable t
                     :fill-pointer (length list)
                     :initial-contents list)))

(defun %raw-insert-at (buffer line column text)
  "Physically splice TEXT into BUFFER's line vector at (LINE, COLUMN), with
no undo bookkeeping or modified-flag update -- callers needing those use
%DO-INSERT. Returns (values end-line end-column), the position immediately
after the inserted text."
  (let* ((segments (%split-newlines text)))
    (if (= (length segments) 1)
        ;; Fast path: TEXT contains no newline, so the edit is confined to a
        ;; single line and the line count doesn't change. Mutate the existing
        ;; adjustable vector in place via AREF instead of paying the O(N)
        ;; %LINES-LIST/%SET-LINES-FROM-LIST list round-trip for what is the
        ;; single hottest path in the editor (every self-insert-command).
        (let* ((old-line (aref (%buffer-lines buffer) line))
               (before (subseq old-line 0 column))
               (after (subseq old-line column))
               (seg (first segments)))
          (setf (aref (%buffer-lines buffer) line) (concatenate 'string before seg after)))
        (let* ((lines-list (%lines-list buffer))
               (old-line (nth line lines-list))
               (before (subseq old-line 0 column))
               (after (subseq old-line column))
               (first-seg (first segments))
               (last-seg (car (last segments)))
               (middle-segs (butlast (rest segments)))
               (new-first (concatenate 'string before first-seg))
               (new-last (concatenate 'string last-seg after))
               (insert-lines (append middle-segs (list new-last))))
          (setf (nth line lines-list) new-first)
          (setf lines-list (append (subseq lines-list 0 (1+ line))
                                    insert-lines
                                    (subseq lines-list (1+ line))))
          (%set-lines-from-list buffer lines-list)))
    (%advance-position line column text)))

(defun %raw-delete-region (buffer start-line start-column end-line end-column)
  "Physically remove the text between the two positions from BUFFER's line
vector, with no undo bookkeeping or modified-flag update -- callers needing
those use %DO-DELETE."
  (if (= start-line end-line)
      ;; Fast path: the region is confined to a single line, so the line
      ;; count doesn't change. Mutate the existing adjustable vector in place
      ;; via AREF instead of paying the O(N) %LINES-LIST/%SET-LINES-FROM-LIST
      ;; list round-trip -- see %RAW-INSERT-AT's matching fast path.
      (let* ((old-line (aref (%buffer-lines buffer) start-line))
             (new-line (concatenate 'string
                                     (subseq old-line 0 start-column)
                                     (subseq old-line end-column))))
        (setf (aref (%buffer-lines buffer) start-line) new-line))
      (let* ((lines-list (%lines-list buffer))
             (prefix (subseq (nth start-line lines-list) 0 start-column))
             (suffix (subseq (nth end-line lines-list) end-column))
             (merged (concatenate 'string prefix suffix)))
        (setf lines-list (append (subseq lines-list 0 start-line)
                                  (list merged)
                                  (subseq lines-list (1+ end-line))))
        (%set-lines-from-list buffer lines-list))))

(defun %extract-region (buffer start-line start-column end-line end-column)
  "Return, without mutating BUFFER, the text between the two positions."
  (if (= start-line end-line)
      (subseq (aref (%buffer-lines buffer) start-line) start-column end-column)
      (let ((parts nil))
        (push (subseq (aref (%buffer-lines buffer) start-line) start-column) parts)
        (loop for l from (1+ start-line) below end-line
              do (push (aref (%buffer-lines buffer) l) parts))
        (push (subseq (aref (%buffer-lines buffer) end-line) 0 end-column) parts)
        (format nil "~{~A~^~%~}" (nreverse parts)))))

(defun %do-insert (buffer line column text)
  "Insert TEXT at (LINE, COLUMN), mark BUFFER modified, and push an undo
entry describing the inverse of this exact edit (a delete of the same
span). Returns (values end-line end-column), the position just after the
inserted text."
  (multiple-value-bind (end-line end-column) (%raw-insert-at buffer line column text)
    (setf (%buffer-modified-p buffer) t)
    (push (list :delete line column text) (%buffer-undo-list buffer))
    (values end-line end-column)))

(defun %do-delete (buffer start-line start-column end-line end-column)
  "Delete the region between the two positions, mark BUFFER modified, and
push an undo entry describing the inverse of this exact edit (a
re-insertion of the deleted text). Returns the deleted text."
  (let ((text (%extract-region buffer start-line start-column end-line end-column)))
    (%raw-delete-region buffer start-line start-column end-line end-column)
    (setf (%buffer-modified-p buffer) t)
    (push (list :insert start-line start-column text) (%buffer-undo-list buffer))
    text))

(defun %apply-undo-entry (buffer entry)
  "Apply ENTRY (as recorded by %DO-INSERT/%DO-DELETE) to BUFFER via those
same low-level primitives, then leave point at the natural post-edit
position (end of inserted text, or start of a deleted span). Because
%DO-INSERT/%DO-DELETE always push a fresh undo entry describing whatever
they just did, applying ENTRY here automatically records its own inverse on
the very same undo list -- see BUFFER-UNDO for why that is exactly what
makes the ring model work."
  (destructuring-bind (kind line column text) entry
    (ecase kind
      (:insert
       (multiple-value-bind (end-line end-column) (%do-insert buffer line column text)
         (setf (%buffer-point-line buffer) end-line
               (%buffer-point-column buffer) end-column)))
      (:delete
       (multiple-value-bind (end-line end-column) (%advance-position line column text)
         (%do-delete buffer line column end-line end-column)
         (setf (%buffer-point-line buffer) line
               (%buffer-point-column buffer) column))))))

(defun %clamp-position (buffer line column)
  "Clamp (LINE, COLUMN) into BUFFER's valid range: LINE into
[0, line-count), COLUMN into [0, (length of that line)]. Returns (values
clamped-line clamped-column)."
  (let* ((line-count (length (%buffer-lines buffer)))
         (clamped-line (max 0 (min line (1- line-count))))
         (line-len (length (aref (%buffer-lines buffer) clamped-line)))
         (clamped-column (max 0 (min column line-len))))
    (values clamped-line clamped-column)))

(defgeneric make-buffer (&key name path initial-content)
  (:documentation
   "Create and return a new, empty-undo-history buffer.

NAME is the buffer's display name (a string); when not supplied an
implementation-chosen default (e.g. \"*scratch*\") is used. PATH, when
supplied, is the pathname/namestring the buffer is associated with for
BUFFER-SAVE and is returned by BUFFER-PATH; it does not by itself cause any
file I/O -- use BUFFER-LOAD to read a file's contents into a new buffer.
INITIAL-CONTENT, when supplied, is a string that becomes the buffer's initial
text; the buffer is otherwise empty. Point and mark both start at line 0,
column 0, and BUFFER-MODIFIED-P is false immediately after creation.

Returns the new buffer object.")
  (:method (&key name path initial-content)
    (let* ((lines-list (if initial-content (%split-newlines initial-content) (list "")))
           (lines-vec (make-array (length lines-list)
                                   :adjustable t
                                   :fill-pointer (length lines-list)
                                   :initial-contents lines-list)))
      (%make-buffer :name (or name "*scratch*")
                    :path path
                    :lines lines-vec
                    :point-line 0
                    :point-column 0
                    :mark-line nil
                    :mark-column nil
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

(defgeneric buffer-text (buffer)
  (:documentation
   "Return BUFFER's entire contents as a single string, including internal
newlines between lines.")
  (:method (buffer)
    (format nil "~{~A~^~%~}" (%lines-list buffer))))

(defgeneric buffer-line-count (buffer)
  (:documentation
   "Return the number of lines in BUFFER as a non-negative integer. An empty
buffer has exactly one (empty) line, so this is always at least 1.")
  (:method (buffer)
    (length (%buffer-lines buffer))))

(defgeneric buffer-line (buffer line-number)
  (:documentation
   "Return the text of the line at zero-based LINE-NUMBER in BUFFER, as a
string with no trailing newline. Signals an error if LINE-NUMBER is out of
range, i.e. not in [0, (BUFFER-LINE-COUNT BUFFER)).")
  (:method (buffer line-number)
    (unless (and (>= line-number 0) (< line-number (buffer-line-count buffer)))
      (error "buffer-line: line-number ~D out of range [0,~D)"
             line-number (buffer-line-count buffer)))
    (aref (%buffer-lines buffer) line-number)))

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

(defgeneric buffer-delete-char (buffer &key backward)
  (:documentation
   "Delete a single character adjacent to BUFFER's point. When BACKWARD is
true, deletes the character immediately before point (Backspace semantics)
and moves point back by one; otherwise deletes the character immediately
after/at point (Delete semantics) and leaves point where it is. A no-op at
a buffer boundary (start of buffer for BACKWARD, end of buffer otherwise).
Marks BUFFER as modified and records undo information when a character was
actually deleted. Returns BUFFER.")
  (:method (buffer &key backward)
    (let ((line (%buffer-point-line buffer))
          (column (%buffer-point-column buffer)))
      (if backward
          (cond
            ((and (= line 0) (= column 0))
             nil) ; no-op: start of buffer
            ((> column 0)
             (%do-delete buffer line (1- column) line column)
             (setf (%buffer-point-line buffer) line
                   (%buffer-point-column buffer) (1- column)))
            (t ;; column = 0, line > 0: join with previous line
             (let* ((prev-line (1- line))
                    (prev-len (length (aref (%buffer-lines buffer) prev-line))))
               (%do-delete buffer prev-line prev-len line 0)
               (setf (%buffer-point-line buffer) prev-line
                     (%buffer-point-column buffer) prev-len))))
          (let ((line-count (length (%buffer-lines buffer)))
                (line-len (length (aref (%buffer-lines buffer) line))))
            (cond
              ((and (= line (1- line-count)) (= column line-len))
               nil) ; no-op: end of buffer
              ((< column line-len)
               (%do-delete buffer line column line (1+ column)))
              (t ;; column = line-len, line < line-count - 1: join with next line
               (%do-delete buffer line column (1+ line) 0))))))
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
