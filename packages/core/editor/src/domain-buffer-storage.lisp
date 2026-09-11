(in-package #:loom)


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
  (narrow-start-offset 0 :type integer)
  (narrow-end-offset 0 :type integer)
  (point-line 0 :type integer)
  (point-column 0 :type integer)
  (mark-line nil :type %maybe-line/column)
  (mark-column nil :type %maybe-line/column)
  (major-mode :fundamental)
  (truncate-lines :default)
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


(defun %split-newlines (string)
  "Split STRING on #\\Newline into a list of line-strings. A STRING with no
newline yields a single-element list; a leading, trailing, or doubled
newline yields empty-string elements, matching how buffer lines represent
an empty line. Always returns at least one element, even for \"\"."
  (loop for start = 0 then (1+ newline)
        for newline = (position #\Newline string :start start)
        collect (subseq string start newline)
        while newline))

(defun %advance-position (line column text)
  "Return (values end-line end-column), the position immediately after
inserting TEXT at (LINE, COLUMN) -- without performing any insertion. Used
to recover the end of a span from just its start and its text, e.g. to
compute the end of a previously-inserted span (its start plus its text)
when undoing that insertion by deleting the span back out. Must agree with
how %RAW-INSERT-AT itself computes its returned end position, since
%APPLY-UNDO-ENTRY relies on that agreement to reconstruct spans it never
directly observed."
  (loop with end-line = line
        with end-column = column
        for character across text
        do (if (char= character #\Newline)
               (progn
                 (incf end-line)
                 (setf end-column 0))
               (incf end-column))
        finally (return (values end-line end-column))))

(defun %buffer-full-length (buffer)
  "Return BUFFER's current full-text length without materializing its text."
  (loop for piece in (%buffer-pieces buffer)
        sum (%piece-length piece)))

(defun %buffer-narrowed-p (buffer)
  "Return true when BUFFER's visible region is smaller than its full text."
  (let ((full-length (%buffer-full-length buffer)))
    (or (plusp (%buffer-narrow-start-offset buffer))
        (< (%buffer-narrow-end-offset buffer) full-length))))
