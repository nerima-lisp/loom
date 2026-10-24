(in-package #:loom/core/command)


(defstruct (keymap (:constructor %make-keymap))
  (name "global")
  (parent nil)
  (table (make-hash-table :test #'equal)))

(defun make-keymap (&key parent (name (if parent (keymap-name parent) "global")))
  "Create an empty keymap with optional PARENT and NAME."
  (%make-keymap :name name :parent parent))

(defun keymap-define-key (keymap key-sequence command)
  "Bind a normalized key sequence to a registered command ID."
  (check-type keymap keymap)
  (let* ((normalized (mapcar #'normalize-key-descriptor key-sequence))
         (command-id
           (if (stringp command)
               (progn
                 (unless (%find-command-spec-by-id command)
                   (error "Command ID is not registered: ~S" command))
                 (copy-seq command))
               (command-id-for-function command))))
    (unless normalized
      (error "A key binding must contain at least one key."))
    (let ((table (keymap-table keymap)))
      (loop for (key . rest) on normalized
            do (multiple-value-bind (existing present-p)
                   (gethash key table)
                 (if rest
                     (cond
                       ((not present-p) (return))
                       ((hash-table-p existing) (setf table existing))
                       (t (error "Key sequence ~S in ~S extends command ~A."
                                 normalized (keymap-name keymap) existing)))
                     (cond
                       ((not present-p) nil)
                       ((hash-table-p existing)
                        (error "Key sequence ~S in ~S is a prefix of another binding."
                               normalized (keymap-name keymap)))
                       ((not (equal existing command-id))
                        (error "Key sequence ~S in ~S is already bound to ~A."
                               normalized (keymap-name keymap) existing)))))))
    (let ((table (keymap-table keymap)))
      (loop for (key . rest) on normalized
            do (if rest
                   (let ((next (gethash key table)))
                     (unless next
                       (setf next (make-hash-table :test #'equal))
                       (setf (gethash key table) next))
                     (setf table next))
                   (setf (gethash key table) command-id)))
      keymap)))

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
  "Look up KEY-SEQUENCE in KEYMAP.
The second value is the keymap that owns the binding, or NIL."
  (multiple-value-bind (value local-p)
      (%keymap-local-lookup keymap key-sequence)
    (cond
      (local-p (values value keymap))
      ((keymap-parent keymap)
       (keymap-lookup (keymap-parent keymap) key-sequence))
      (t (values nil nil)))))
