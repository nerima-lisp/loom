(in-package #:loom)


(defstruct (keymap (:constructor %make-keymap))
  (parent nil)
  (table (make-hash-table :test #'equal)))

(defun make-keymap (&key parent)
  "Create and return a new, empty keymap with optional PARENT."
  (%make-keymap :parent parent))

(defun keymap-define-key (keymap key-sequence command)
  "Bind KEY-SEQUENCE -- a list of key-event descriptors, each shaped like a
CL-TTY-KIT key-event (or a lighter descriptor an implementation chooses to
accept, e.g. a (TYPE CODE MODIFIERS) list) -- to COMMAND, a function
designator of zero arguments that operates on *EDITOR-STATE* when invoked. A
KEY-SEQUENCE that is a strict prefix of another bound sequence implicitly
becomes a prefix key (see KEYMAP-LOOKUP). Returns KEYMAP."
  (let ((normalized (mapcar #'normalize-key-descriptor key-sequence))
        (table (keymap-table keymap)))
    (loop for (key . rest) on normalized
          do (if rest
                 (let ((next (gethash key table)))
                   (unless (hash-table-p next)
                     (setf next (make-hash-table :test #'equal))
                     (setf (gethash key table) next))
                   (setf table next))
                 (setf (gethash key table) command)))
    keymap))

(defun %keymap-lookup-step (table key rest)
  (multiple-value-bind (value present-p) (gethash key table)
    (cond
      ((not present-p) (values nil nil nil))
      ((null rest) (values (if (hash-table-p value) :prefix value) t nil))
      ((hash-table-p value) (values nil t value))
      (t (values nil t nil)))))

(defun %keymap-lookup-table (table key-sequence)
  (let ((local-p nil))
    (loop for (key . rest) on key-sequence
          do (multiple-value-bind (value present-p next-table)
                 (%keymap-lookup-step table key rest)
               (unless present-p
                 (return (values nil local-p)))
               (setf local-p t)
               (when (null rest)
                 (return (values value t)))
               (unless next-table
                 (return (values nil t)))
               (setf table next-table))
          finally (return (values nil local-p)))))

(defun %keymap-local-lookup (keymap key-sequence)
  "Look up KEY-SEQUENCE locally, returning VALUE and a presence flag.

The presence flag is true when the first chord exists locally, even when a
later chord does not.  This makes a local prefix shadow the entire matching
parent subtree, which is how mode-local prefix maps avoid surprising global
fallbacks."
  (let ((normalized (mapcar #'normalize-key-descriptor key-sequence)))
    (%keymap-lookup-table (keymap-table keymap) normalized)))

(defun keymap-lookup (keymap key-sequence)
  "Look up KEY-SEQUENCE (a list of key-event descriptors, as in
KEYMAP-DEFINE-KEY) in KEYMAP. Returns the bound command function designator
if KEY-SEQUENCE names a complete binding, the keyword :PREFIX if KEY-SEQUENCE
is a strict prefix of one or more bindings, or NIL if KEY-SEQUENCE is bound
to nothing."
  (multiple-value-bind (value local-p)
      (%keymap-local-lookup keymap key-sequence)
    (if local-p
        value
        (and (keymap-parent keymap)
             (keymap-lookup (keymap-parent keymap) key-sequence)))))
