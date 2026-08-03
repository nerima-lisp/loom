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
;;; A piece table stores immutable initial text plus an append-only add buffer.
;;; Edits split and join compact piece metadata instead of copying unaffected text.
;;; :CONC-NAME and :CONSTRUCTOR are both overridden so the struct's auto-generated accessor/constructor
;;; names (BUFFER-NAME, MAKE-BUFFER, ...) don't collide with the protocol's
;;; exported generic functions of the same names above.
;;; ---------------------------------------------------------------------

(defstruct (piece (:constructor %make-piece) (:conc-name %piece-))
  "A contiguous slice of a piece table source."
  (source :original :type symbol)
  (start 0 :type integer)
  (length 0 :type integer))

(deftype %maybe-line/column ()
  "A buffer's mark line/column: unset (NIL) until BUFFER-SET-MARK's first
call, an INTEGER (see %CLAMP-POSITION) from then on. Named so BUFFER's two
mark slots below state the same union once instead of repeating it."
  '(or null integer))

(defstruct (buffer (:constructor %make-buffer) (:conc-name %buffer-))
  "Internal representation of a loom buffer: a piece table plus point, mark,
modified-p, and undo-list state."
  (name "*scratch*" :type string)
  (path nil)
  (original "" :type string)
  (add-buffer (make-array 0 :element-type (quote character) :adjustable t :fill-pointer 0))
  (pieces nil :type list)
  (point-line 0 :type integer)
  (point-column 0 :type integer)
  (mark-line nil :type %maybe-line/column)
  (mark-column nil :type %maybe-line/column)
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

(defun %piece-source-text (buffer piece)
  (ecase (%piece-source piece)
    (:original (%buffer-original buffer))
    (:add (%buffer-add-buffer buffer))))

(defun %piece-text (buffer piece)
  (let ((source (%piece-source-text buffer piece)))
    (subseq source
            (%piece-start piece)
            (+ (%piece-start piece) (%piece-length piece)))))

(defun %pieces-text (buffer)
  (with-output-to-string (stream)
    (dolist (piece (%buffer-pieces buffer))
      (write-string (%piece-text buffer piece) stream))))

(defun %coalesce-pieces (pieces)
  "Merge adjacent slices from the same source, keeping metadata compact."
  (let ((result nil))
    (dolist (piece pieces (nreverse result))
      (let ((previous (first result)))
        (if (and previous
                 (eq (%piece-source previous) (%piece-source piece))
                 (= (+ (%piece-start previous) (%piece-length previous))
                    (%piece-start piece)))
            (incf (%piece-length previous) (%piece-length piece))
            (push piece result))))))

(defun %append-add-text (buffer text)
  "Append TEXT once and return its start offset and length in the add source."
  (let ((start (length (%buffer-add-buffer buffer))))
    (loop for character across text
          do (vector-push-extend character (%buffer-add-buffer buffer)))
    (values start (length text))))

(defun %splice-insert-piece (buffer offset new-piece)
  (let ((result nil) (cursor 0) (inserted nil))
    (dolist (piece (%buffer-pieces buffer))
      (let ((next (+ cursor (%piece-length piece))))
        (if (and (not inserted) (<= cursor offset) (<= offset next))
            (let ((left-length (- offset cursor))
                  (right-length (- next offset)))
              (when (plusp left-length)
                (push (%make-piece :source (%piece-source piece) :start (%piece-start piece) :length left-length) result))
              (push new-piece result)
              (when (plusp right-length)
                (push (%make-piece :source (%piece-source piece) :start (+ (%piece-start piece) left-length) :length right-length) result))
              (setf inserted t))
            (push piece result))
        (setf cursor next)))
    (unless inserted (push new-piece result))
    (setf (%buffer-pieces buffer) (%coalesce-pieces (nreverse result)))))

(defun %splice-delete-range (buffer start end)
  (let ((result nil) (cursor 0))
    (dolist (piece (%buffer-pieces buffer))
      (let* ((piece-length (%piece-length piece)) (next (+ cursor piece-length)))
        (cond
          ((or (<= next start) (>= cursor end)) (push piece result))
          (t
           (let ((prefix-length (max 0 (- start cursor)))
                 (suffix-offset (max 0 (- end cursor))))
             (when (plusp prefix-length)
               (push (%make-piece :source (%piece-source piece) :start (%piece-start piece) :length prefix-length) result))
             (when (< suffix-offset piece-length)
               (push (%make-piece :source (%piece-source piece) :start (+ (%piece-start piece) suffix-offset) :length (- piece-length suffix-offset)) result)))))
        (setf cursor next)))
    (setf (%buffer-pieces buffer) (%coalesce-pieces (nreverse result)))))

(defun %position-to-offset (buffer line column)
  (let ((current-line 0) (current-column 0) (offset 0))
    (dolist (piece (%buffer-pieces buffer))
      (loop for character across (%piece-text buffer piece)
            do (when (and (= current-line line) (= current-column column))
                 (return-from %position-to-offset offset))
               (incf offset)
               (if (char= character #\Newline)
                   (progn (incf current-line) (setf current-column 0))
                   (incf current-column))))
    (if (and (= current-line line) (= current-column column))
        offset
        (error "buffer position (~D, ~D) out of range" line column))))

(defun %line-count (buffer)
  (let ((count 1))
    (dolist (piece (%buffer-pieces buffer) count)
      (loop for character across (%piece-text buffer piece)
            when (char= character #\Newline)
              do (incf count)))))

(defun %line-at (buffer line-number)
  "Return the text of LINE-NUMBER, not including its trailing newline.
Trusts its callers -- %CLAMP-POSITION, BUFFER-LINE (which validates
LINE-NUMBER itself before calling this), and BUFFER-DELETE-CHAR's
backward/forward helpers (which derive it from BUFFER's own point) -- to
never pass an out-of-range LINE-NUMBER; this is an internal helper, not a
system boundary. WITH-OUTPUT-TO-STRING's own return value (the stream
accumulated so far) is what's returned once the target line -- necessarily
BUFFER's last, since it has no trailing newline -- is reached without one."
  (block result
    (let ((current-line 0))
      (with-output-to-string (stream)
        (dolist (piece (%buffer-pieces buffer))
          (loop for character across (%piece-text buffer piece)
                do (cond
                     ((= current-line line-number)
                      (if (char= character #\Newline)
                          (return-from result (get-output-stream-string stream))
                          (write-char character stream)))
                     ((char= character #\Newline)
                      (incf current-line)))))))))

(defun %piece-table-range-text (buffer start end)
  (with-output-to-string (stream)
    (let ((cursor 0))
      (dolist (piece (%buffer-pieces buffer))
        (let ((next (+ cursor (%piece-length piece))))
          (when (and (< cursor end) (> next start))
            (let ((slice-start (max start cursor)) (slice-end (min end next)))
              (write-string (subseq (%piece-text buffer piece) (- slice-start cursor) (- slice-end cursor)) stream)))
          (setf cursor next))))))

(defun %raw-insert-at (buffer line column text)
  "Splice TEXT into the piece table at (LINE, COLUMN), without undo bookkeeping."
  (multiple-value-bind (start length) (%append-add-text buffer text)
    (when (plusp length)
      (%splice-insert-piece buffer (%position-to-offset buffer line column)
                            (%make-piece :source :add :start start :length length))))
  (%advance-position line column text))

(defun %raw-delete-region (buffer start-line start-column end-line end-column)
  "Remove text between two positions from the piece table without undo bookkeeping."
  (let ((start (%position-to-offset buffer start-line start-column))
        (end (%position-to-offset buffer end-line end-column)))
    (when (< start end)
      (%splice-delete-range buffer start end))))

(defun %extract-region (buffer start-line start-column end-line end-column)
  "Return, without mutating BUFFER, the text between the two positions."
  (%piece-table-range-text buffer
                           (%position-to-offset buffer start-line start-column)
                           (%position-to-offset buffer end-line end-column)))

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
  "Clamp (LINE, COLUMN) into BUFFER valid bounds."
  (let* ((line-count (%line-count buffer))
         (clamped-line (max 0 (min line (1- line-count))))
         (line-len (length (%line-at buffer clamped-line)))
         (clamped-column (max 0 (min column line-len))))
    (values clamped-line clamped-column)))

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

(defun %buffer-point-offset (buffer)
  "Return BUFFER's point as an offset in BUFFER-TEXT."
  (let ((offset (buffer-point-column buffer)))
    (loop for line below (buffer-point-line buffer)
          do (incf offset (1+ (length (buffer-line buffer line)))))
    offset))

(defun %buffer-offset-position (buffer offset)
  "Return the line and column corresponding to OFFSET in BUFFER-TEXT."
  (loop for line below (buffer-line-count buffer)
        for line-length = (length (buffer-line buffer line))
        if (<= offset line-length)
          do (return (values line offset))
        do (decf offset (1+ line-length))
        finally (let ((last-line (1- (buffer-line-count buffer))))
                  (return (values last-line
                                  (length (buffer-line buffer last-line)))))))

(defun %replacement-occurrences (text old start)
  "Return OLD offsets in one non-overlapping cycle beginning at START."
  (labels ((collect-occurrences (from to)
             (loop for offset = (search old text :start2 from :end2 to)
                   while offset
                   collect offset
                   do (setf from (+ offset (length old))))))
    (append (collect-occurrences start (length text))
            (collect-occurrences 0 start))))

(defun %find-next-occurrence (buffer string)
  "Return the next case-sensitive occurrence of STRING at or after point.
Searches the text before point once when the first search reaches the end."
  (unless (zerop (length string))
    (let* ((text (buffer-text buffer))
           (start (%buffer-point-offset buffer)))
      (or (search string text :start2 start)
          (and (plusp start) (search string text :end2 start))))))
