;;;; packages/feature/session/src/domain-session.lisp
;;;;
;;;; Domain layer: validated, side-effect-free session snapshots. The snapshot
;;;; contains enough editor state to rebuild buffers and a window tree, but it
;;;; deliberately contains no pathname objects, streams, or terminal handles.
;;;; Serialization and filesystem policy live in infrastructure/session-store.lisp;
;;;; conversion to and from EDITOR-STATE lives in application/commands-session.lisp.
(in-package #:loom/feature/session)

(defstruct session-buffer-snapshot
  "Serializable state for one registered editor buffer."
  name
  path
  text
  point-line
  point-column
  mark-line
  mark-column
  modified-p)

(defstruct session-snapshot
  "Validated, serializable state for one Loom editing session.

LAYOUT is a nested (:LEAF BUFFER-INDEX SCROLL-LINE) /
(:SPLIT DIRECTION CHILD-1 CHILD-2) description. Buffer indexes refer to the
order of SESSION-SNAPSHOT-BUFFERS, and SELECTED-WINDOW-INDEX refers to the
depth-first order of leaves in LAYOUT."
  buffers
  layout
  selected-window-index)

(defun %session-nonnegative-integer-p (value)
  (and (integerp value) (<= 0 value)))

(defun %session-mark-valid-p (line column)
  (or (and (null line) (null column))
      (and (%session-nonnegative-integer-p line)
           (%session-nonnegative-integer-p column))))

(defun %validate-session-buffer (buffer)
  (unless (typep buffer 'session-buffer-snapshot)
    (error "validate-session-snapshot: invalid buffer snapshot ~S" buffer))
  (unless (and (stringp (session-buffer-snapshot-name buffer))
               (or (null (session-buffer-snapshot-path buffer))
                   (stringp (session-buffer-snapshot-path buffer)))
               (stringp (session-buffer-snapshot-text buffer))
               (%session-nonnegative-integer-p
                (session-buffer-snapshot-point-line buffer))
               (%session-nonnegative-integer-p
                (session-buffer-snapshot-point-column buffer))
               (%session-mark-valid-p
                (session-buffer-snapshot-mark-line buffer)
                (session-buffer-snapshot-mark-column buffer))
               (member (session-buffer-snapshot-modified-p buffer)
                       '(nil t)
                       :test #'eq))
    (error "validate-session-snapshot: malformed buffer snapshot ~S" buffer))
  buffer)

(defun %validate-session-layout (layout buffer-count)
  "Validate indexed LAYOUT and return its number of leaf windows."
  (labels ((visit (node)
             (unless (listp node)
               (error "validate-session-snapshot: malformed layout node ~S" node))
             (case (first node)
               (:leaf
                (unless (and (= (length node) 3)
                             (%session-nonnegative-integer-p (second node))
                             (< (second node) buffer-count)
                             (%session-nonnegative-integer-p (third node)))
                  (error "validate-session-snapshot: malformed leaf ~S" node))
                1)
               (:split
                (unless (and (= (length node) 4)
                             (member (second node) '(:horizontal :vertical)))
                  (error "validate-session-snapshot: malformed split ~S" node))
                (+ (visit (third node))
                   (visit (fourth node))))
               (otherwise
                (error "validate-session-snapshot: unknown layout node ~S"
                       (first node))))))
    (visit layout)))

(defgeneric validate-session-snapshot (snapshot)
  (:documentation
   "Validate SNAPSHOT's shape and cross-references, returning SNAPSHOT.

This is the single domain gate used both before writing a session and after
reading one. It rejects malformed or out-of-range state before any editor
state is replaced.")
  (:method (snapshot)
    (unless (typep snapshot 'session-snapshot)
      (error "validate-session-snapshot: not a session snapshot: ~S" snapshot))
    (let ((buffers (session-snapshot-buffers snapshot)))
      (unless (and (listp buffers) (plusp (length buffers)))
        (error "validate-session-snapshot: a session needs one or more buffers"))
      (dolist (buffer buffers)
        (%validate-session-buffer buffer))
      (unless (listp (session-snapshot-layout snapshot))
        (error "validate-session-snapshot: layout is not a proper list"))
      (let ((window-count
              (%validate-session-layout (session-snapshot-layout snapshot)
                                        (length buffers)))
            (selected-index (session-snapshot-selected-window-index snapshot)))
        (unless (and (%session-nonnegative-integer-p selected-index)
                     (< selected-index window-count))
          (error "validate-session-snapshot: selected window index ~S is out of range"
                 selected-index)))
      snapshot)))
