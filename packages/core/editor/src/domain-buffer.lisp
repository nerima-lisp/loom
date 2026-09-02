;;;; packages/core/editor/src/domain-buffer.lisp
;;;;
;;;; Domain layer: the core public buffer protocol. Pure
;;;; text-storage/point-mark/undo state and logic with no dependency on
;;;; cl-tty-kit, cl-host-kit, or
;;;; cl-history-kit -- BUFFER-LOAD/BUFFER-SAVE describe file I/O in their
;;;; contract but only their DEFGENERIC (name, docstring, argument list) is
;;;; declared here; their real, disk-touching :METHOD bodies live in
;;;; infrastructure/filesystem.lisp instead, since they are I/O rather than
;;;; pure buffer state -- see that file's header comment.
;;;;
;;;; A buffer owns text content, point, mark, and an optional backing file
;;;; path. Piece-table representation lives in domain-buffer-storage.lisp;
;;;; piece-table mutation and position helpers live in
;;;; domain-buffer-piece-table.lisp; line/point/mark/region accessor APIs live
;;;; in domain-buffer-accessors.lisp; text mutation APIs live in
;;;; domain-buffer-editing.lisp; low-level narrowing helpers live in
;;;; domain-buffer-narrowing-support.lisp; visible-region APIs live in
;;;; domain-buffer-narrowing.lisp; offset/position helpers layered on top of
;;;; this protocol live in domain-buffer-positions.lisp;
;;;; modification/read-only state and undo/redo history live in
;;;; domain-buffer-history.lisp.
;;;;
;;;; Indexing convention, fixed for the whole protocol: line and column
;;;; numbers are zero-based. Line 0 is the first line of a buffer; column 0 is
;;;; the character before the first character of a line. A (line . column)
;;;; pair denotes a position *between* characters, exactly like Emacs point,
;;;; so END values in a region are exclusive.
(in-package #:loom)

(defun %buffer-initial-pieces (original)
  (when (string/= original "")
    (list (%make-piece :source :original
                       :start 0
                       :length (length original)))))

(defun %make-initial-buffer (name path original)
  (%make-buffer :name (or name "*scratch*")
                :path path
                :original original
                :add-buffer (make-array 0
                                        :element-type (quote character)
                                        :adjustable t
                                        :fill-pointer 0)
                :pieces (%buffer-initial-pieces original)
                :narrow-start-offset 0
                :narrow-end-offset (length original)
                :point-line 0
                :point-column 0
                :mark-line nil
                :mark-column nil
                :major-mode :fundamental
                :truncate-lines :default
                :read-only-p nil
                :modified-p nil
                :undo-list nil
                :redo-list nil))

(defgeneric make-buffer (&key name path initial-content)
  (:documentation
   "Create and return a new buffer with empty undo and redo history.")
  (:method (&key name path initial-content)
    (%make-initial-buffer name path (or initial-content ""))))

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

(defgeneric buffer-truncate-lines (buffer)
  (:documentation
   "Return BUFFER's line-display preference: T, NIL, or :DEFAULT.

:DEFAULT means the major mode decides. As with BUFFER-MAJOR-MODE the core
buffer stores the value without interpreting it; resolving :DEFAULT to a
boolean needs mode metadata and belongs to a feature package.")
  (:method (buffer)
    (%buffer-truncate-lines buffer)))

(defgeneric buffer-set-truncate-lines (buffer value)
  (:documentation
   "Set BUFFER's line-display preference to T, NIL, or :DEFAULT.")
  (:method (buffer value)
    (check-type value (member t nil :default))
    (setf (%buffer-truncate-lines buffer) value)
    buffer))

(defgeneric buffer-text (buffer)
  (:documentation "Return BUFFER entire contents as a single string.")
  (:method (buffer)
    (%pieces-text buffer)))

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
