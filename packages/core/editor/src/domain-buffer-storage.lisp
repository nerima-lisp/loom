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
modified-p, read-only state, and undo/redo state."
  (name "*scratch*" :type string)
  (path nil)
  (original "" :type string)
  (add-buffer (make-array 0 :element-type (quote character) :adjustable t :fill-pointer 0))
  (pieces nil :type list)
  ;; Narrowing is represented as absolute offsets in the full piece-table
  ;; text.  The end is exclusive; a widened buffer always has [0, full
  ;; length], which lets edits keep the invariant without a separate flag.
  (narrow-start-offset 0 :type integer)
  (narrow-end-offset 0 :type integer)
  (point-line 0 :type integer)
  (point-column 0 :type integer)
  (mark-line nil :type %maybe-line/column)
  (mark-column nil :type %maybe-line/column)
  ;; A buffer owns only the opaque mode identity.  Mode-specific behaviour
  ;; belongs to feature packages, keeping the core editor independent of
  ;; language packages.
  (major-mode :fundamental)
  (read-only-p nil :type boolean)
  (modified-p nil)
  (undo-list nil :type list)
  (redo-list nil :type list))

(define-condition buffer-read-only-error (error)
  ((buffer :initarg :buffer :reader buffer-read-only-error-buffer))
  (:report
   (lambda (condition stream)
     (format stream "Buffer ~A is read-only"
             (%buffer-name (buffer-read-only-error-buffer condition))))))

(defun %ensure-buffer-writable (buffer)
  "Signal BUFFER-READ-ONLY-ERROR when BUFFER rejects text mutations."
  (when (%buffer-read-only-p buffer)
    (error 'buffer-read-only-error :buffer buffer)))

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

(defun %buffer-full-length (buffer)
  "Return BUFFER's current full-text length without materializing its text."
  (loop for piece in (%buffer-pieces buffer)
        sum (%piece-length piece)))

(defun %buffer-narrowed-p (buffer)
  "Return true when BUFFER's visible region is smaller than its full text."
  (let ((full-length (%buffer-full-length buffer)))
    (or (plusp (%buffer-narrow-start-offset buffer))
        (< (%buffer-narrow-end-offset buffer) full-length))))

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
system boundary. The scan ends either at the newline closing LINE-NUMBER or,
for BUFFER's last line, at the end of the pieces, since that line has no
closing newline; both leave TEXT holding the answer."
  (let ((current-line 0)
        (text (make-string-output-stream)))
    (block scan
      (dolist (piece (%buffer-pieces buffer))
        (loop for character across (%piece-text buffer piece)
              for newline-p = (char= character #\Newline)
              for on-target-line-p = (= current-line line-number)
              when (and newline-p on-target-line-p) do (return-from scan)
              when newline-p do (incf current-line)
              when on-target-line-p do (write-char character text))))
    (get-output-stream-string text)))

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

(defun %do-insert (buffer line column text &key (clear-redo t))
  "Insert TEXT at (LINE, COLUMN), mark BUFFER modified, and push an undo
entry describing the inverse of this exact edit (a delete of the same
span). Returns (values end-line end-column), the position just after the
inserted text.

When CLEAR-REDO is true, discard explicit redo history because this is a
new edit rather than an undo/redo replay."
  (%ensure-buffer-writable buffer)
  (let* ((was-narrowed (%buffer-narrowed-p buffer))
         (old-length (%buffer-full-length buffer))
         (text-length (length text)))
    (multiple-value-bind (end-line end-column) (%raw-insert-at buffer line column text)
      (if was-narrowed
          (incf (%buffer-narrow-end-offset buffer) text-length)
          (setf (%buffer-narrow-start-offset buffer) 0
                (%buffer-narrow-end-offset buffer) (+ old-length text-length)))
      (setf (%buffer-modified-p buffer) t)
      (when clear-redo
        (setf (%buffer-redo-list buffer) nil))
      (push (list :delete line column text) (%buffer-undo-list buffer))
      (values end-line end-column))))

(defun %do-delete (buffer start-line start-column end-line end-column
                   &key (clear-redo t))
  "Delete the region between the two positions, mark BUFFER modified, and
push an undo entry describing the inverse of this exact edit (a
re-insertion of the deleted text). Returns the deleted text.

When CLEAR-REDO is true, discard explicit redo history because this is a
new edit rather than an undo/redo replay."
  (%ensure-buffer-writable buffer)
  (let* ((start-offset (%position-to-offset buffer start-line start-column))
         (end-offset (%position-to-offset buffer end-line end-column))
         (text (%piece-table-range-text buffer start-offset end-offset))
         (was-narrowed (%buffer-narrowed-p buffer))
         (old-length (%buffer-full-length buffer))
         (deleted-length (- end-offset start-offset)))
    (%raw-delete-region buffer start-line start-column end-line end-column)
    (if was-narrowed
        (decf (%buffer-narrow-end-offset buffer) deleted-length)
        (setf (%buffer-narrow-start-offset buffer) 0
              (%buffer-narrow-end-offset buffer) (- old-length deleted-length)))
    (setf (%buffer-modified-p buffer) t)
    (when clear-redo
      (setf (%buffer-redo-list buffer) nil))
    (push (list :insert start-line start-column text) (%buffer-undo-list buffer))
    text))

(defun %apply-undo-entry (buffer entry)
  "Apply ENTRY to BUFFER and return the inverse action it records.

The inverse is returned so BUFFER-UNDO can place it on the explicit redo
stack. Replay does not clear redo history; ordinary edits still do."
  (destructuring-bind (kind line column text) entry
    (ecase kind
      (:insert
       (multiple-value-bind (end-line end-column)
           (%do-insert buffer line column text :clear-redo nil)
         (setf (%buffer-point-line buffer) end-line
               (%buffer-point-column buffer) end-column))
       (list :delete line column text))
      (:delete
       (multiple-value-bind (end-line end-column) (%advance-position line column text)
         (%do-delete buffer line column end-line end-column
                     :clear-redo nil)
         (setf (%buffer-point-line buffer) line
               (%buffer-point-column buffer) column))
       (list :insert line column text)))))

(defun %clamp-position (buffer line column)
  "Clamp (LINE, COLUMN) into BUFFER valid bounds."
  (let* ((line-count (%line-count buffer))
         (clamped-line (max 0 (min line (1- line-count))))
         (line-len (length (%line-at buffer clamped-line)))
         (clamped-column (max 0 (min column line-len))))
    (values clamped-line clamped-column)))

(defun %offset-to-position-values (buffer offset)
  "Return (VALUES LINE COLUMN) for OFFSET in BUFFER's full text."
  (let ((remaining offset))
    (loop for line below (%line-count buffer)
          for line-length = (length (%line-at buffer line))
          if (<= remaining line-length)
            do (return (values line remaining))
          do (decf remaining (1+ line-length))
          finally (let ((last-line (1- (%line-count buffer))))
                    (return
                      (values last-line
                              (length (%line-at buffer last-line))))))))
