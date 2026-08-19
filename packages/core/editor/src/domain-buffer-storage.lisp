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

(defun %buffer-full-length (buffer)
  "Return BUFFER's current full-text length without materializing its text."
  (loop for piece in (%buffer-pieces buffer)
        sum (%piece-length piece)))

(defun %buffer-narrowed-p (buffer)
  "Return true when BUFFER's visible region is smaller than its full text."
  (let ((full-length (%buffer-full-length buffer)))
    (or (plusp (%buffer-narrow-start-offset buffer))
        (< (%buffer-narrow-end-offset buffer) full-length))))
