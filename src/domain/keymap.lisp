;;;; src/domain/keymap.lisp
;;;;
;;;; Domain layer: key-sequence -> command lookup. This file owns the pure
;;;; keymap trie; descriptor normalization lives in
;;;; src/domain/keymap-descriptor.lisp, and incremental dispatch state lives in
;;;; src/domain/keymap-state.lisp.
;;;;
;;;; A keymap maps key sequences (lists of key-event descriptors) to commands,
;;;; supporting Emacs-style prefix keys (e.g. C-x C-s) via an explicit
;;;; incremental dispatch state that accumulates key events across calls.
(in-package #:loom)

;;; A keymap is a trie: KEYMAP-TABLE maps one normalized key descriptor to
;;; either a bound command (a function designator) or another hash-table
;;; (making that prefix a :PREFIX node, per KEYMAP-LOOKUP). A keymap may also
;;; have a parent; a local first-chord binding shadows the corresponding
;;; parent subtree, while an absent local first chord falls through. MAKE-
;;; KEYMAP's default constructor name is overridden (%MAKE-KEYMAP) since it
;;; would otherwise clash with the MAKE-KEYMAP generic function below.

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

(defun %keymap-lookup-table (table key-sequence)
  (let ((local-p nil))
    (loop for (key . rest) on key-sequence
        do (multiple-value-bind (value present-p) (gethash key table)
             (unless present-p
               (return (values nil local-p)))
             (setf local-p t)
             (if rest
                 (if (hash-table-p value)
                     (setf table value)
                     (return (values nil t)))
                 (return (values (if (hash-table-p value) :prefix value)
                                 t))))
          finally (return (values nil local-p)))))

(defun %keymap-local-lookup (keymap key-sequence)
  "Look up KEY-SEQUENCE locally, returning VALUE and a presence flag.

The presence flag is true when the first chord exists locally, even when a
later chord does not.  This makes a local prefix shadow the entire matching
parent subtree, which is how mode-local prefix maps avoid surprising global
fallbacks."
  (when key-sequence
    (let ((normalized (mapcar #'normalize-key-descriptor key-sequence)))
      (%keymap-lookup-table (keymap-table keymap) normalized))))

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
