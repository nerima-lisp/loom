;;;; src/domain/keymap.lisp
;;;;
;;;; Domain layer: the keymap protocol. A pure key-sequence -> command
;;;; lookup/dispatch state machine; it consumes key-event descriptors already
;;;; decoded by cl-tty-kit (in infrastructure) but performs no I/O itself.
;;;;
;;;; A keymap maps key sequences (lists of key-event descriptors) to commands,
;;;; supporting Emacs-style prefix keys (e.g. C-x C-s) via an explicit
;;;; incremental dispatch state that accumulates key events across calls.
;;;;
;;;; Key descriptor representation: since this file has no dependency on
;;;; cl-tty-kit, it does not know that library's KEY-EVENT class's slots. It
;;;; instead defines its own canonical, lighter descriptor and normalizes
;;;; anything handed to KEYMAP-DEFINE-KEY / KEYMAP-STATE-DISPATCH into that
;;;; shape:
;;;;
;;;;   (MODIFIERS . CODE)
;;;;
;;;; where MODIFIERS is a list of keyword symbols such as :CONTROL, :META,
;;;; :SHIFT (order-independent -- NORMALIZE-KEY-DESCRIPTOR sorts it), and CODE
;;;; is either a character (for printable keys, e.g. #\x) or a keyword naming
;;;; a special key (e.g. :UP, :TAB, :ENTER, :ESCAPE). A bare character or
;;;; keyword is also accepted directly, as shorthand for (NIL . CODE), i.e. an
;;;; unmodified key. Infrastructure code that decodes real CL-TTY-KIT
;;;; key-event objects is responsible for converting them into one of these
;;;; two accepted shapes before calling into this protocol.
(in-package #:loom)

(defun normalize-key-descriptor (descriptor)
  "Normalize DESCRIPTOR -- either a (MODIFIERS . CODE) cons or a bare
character/keyword CODE -- into the canonical (SORTED-MODIFIERS . CODE) cons
used as this keymap implementation's trie key. See the file header for the
accepted descriptor shapes."
  (if (and (consp descriptor) (listp (car descriptor)))
      (cons (sort (copy-list (car descriptor)) #'string< :key #'symbol-name)
            (cdr descriptor))
      (cons nil descriptor)))

;;; A keymap is a trie: KEYMAP-TABLE maps one normalized key descriptor to
;;; either a bound command (a function designator) or another hash-table
;;; (making that prefix a :PREFIX node, per KEYMAP-LOOKUP). MAKE-KEYMAP's
;;; default constructor name is overridden (%MAKE-KEYMAP) since it would
;;; otherwise clash with the MAKE-KEYMAP generic function below; likewise for
;;; KEYMAP-STATE and MAKE-KEYMAP-STATE.

(defstruct (keymap (:constructor %make-keymap))
  (table (make-hash-table :test #'equal)))

(defstruct (keymap-state (:constructor %make-keymap-state))
  keymap
  (sequence nil))

(defgeneric make-keymap ()
  (:documentation "Create and return a new, empty keymap.")
  (:method ()
    (%make-keymap)))

(defgeneric keymap-define-key (keymap key-sequence command)
  (:documentation
   "Bind KEY-SEQUENCE -- a list of key-event descriptors, each shaped like a
CL-TTY-KIT key-event (or a lighter descriptor an implementation chooses to
accept, e.g. a (TYPE CODE MODIFIERS) list) -- to COMMAND, a function
designator of zero arguments that operates on *EDITOR-STATE* when invoked. A
KEY-SEQUENCE that is a strict prefix of another bound sequence implicitly
becomes a prefix key (see KEYMAP-LOOKUP). Returns KEYMAP.")
  (:method (keymap key-sequence command)
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
      keymap)))

(defgeneric keymap-lookup (keymap key-sequence)
  (:documentation
   "Look up KEY-SEQUENCE (a list of key-event descriptors, as in
KEYMAP-DEFINE-KEY) in KEYMAP. Returns the bound command function designator
if KEY-SEQUENCE names a complete binding, the keyword :PREFIX if KEY-SEQUENCE
is a strict prefix of one or more bindings, or NIL if KEY-SEQUENCE is bound
to nothing.")
  (:method (keymap key-sequence)
    (let ((normalized (mapcar #'normalize-key-descriptor key-sequence))
          (table (keymap-table keymap)))
      (loop for (key . rest) on normalized
            do (let ((value (gethash key table)))
                 (cond
                   ((null value) (return-from keymap-lookup nil))
                   (rest
                    (if (hash-table-p value)
                        (setf table value)
                        (return-from keymap-lookup nil)))
                   (t
                    (return-from keymap-lookup (if (hash-table-p value) :prefix value)))))
            finally (return nil)))))

(defgeneric make-keymap-state (keymap)
  (:documentation
   "Create and return a new dispatch state for KEYMAP that tracks
in-progress prefix-key accumulation across successive KEYMAP-STATE-DISPATCH
calls, starting with no keys accumulated.")
  (:method (keymap)
    (%make-keymap-state :keymap keymap :sequence nil)))

(defgeneric keymap-state-dispatch (state key-event)
  (:documentation
   "Feed one KEY-EVENT (as returned by CL-TTY-KIT:DECODE-INPUT-CHUNK) into
STATE. Appends KEY-EVENT to the sequence accumulated so far and looks it up
in STATE's keymap:

- If the accumulated sequence is a prefix (KEYMAP-LOOKUP returns :PREFIX),
  returns the keyword :PENDING and keeps the accumulated sequence for the
  next call.
- If the accumulated sequence resolves to a bound command, invokes that
  command (a function of zero arguments) and returns its return value,
  resetting STATE's accumulated sequence to empty.
- If the accumulated sequence is bound to nothing, resets STATE's
  accumulated sequence to empty and returns NIL.")
  (:method (state key-event)
    (setf (keymap-state-sequence state)
          (append (keymap-state-sequence state) (list key-event)))
    (let ((result (keymap-lookup (keymap-state-keymap state) (keymap-state-sequence state))))
      (cond
        ((eq result :prefix)
         :pending)
        ((null result)
         (setf (keymap-state-sequence state) nil)
         nil)
        (t
         (setf (keymap-state-sequence state) nil)
         (funcall result))))))
