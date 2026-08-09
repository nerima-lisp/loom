;;;; packages/feature/register/src/domain-register.lisp
;;;;
;;;; Domain layer: named register values.  Registers are deliberately kept
;;;; independent from buffers, minibuffers, and terminal I/O so the same
;;;; value object can be used by commands, session persistence, or a future
;;;; extension API.
(in-package #:loom)

(defstruct (register-value
            (:constructor %make-register-value (kind value)))
  "A value stored in one named register.

KIND is either :TEXT or :POSITION.  TEXT values keep a copied string;
POSITION values keep a (LINE . COLUMN) cons cell."
  kind
  value)

(defstruct (register-bank
            (:constructor %make-register-bank
                (&optional (values (make-hash-table :test #'eql)))))
  "The mutable collection of named register values for one editor session."
  values)

(defun make-register-bank ()
  "Create an empty register bank."
  (%make-register-bank))

(defun %register-name (name)
  (unless (characterp name)
    (error "Register name must be a character, got ~S" name))
  name)

(defun register-bank-put-text (bank name text)
  "Store TEXT under NAME and return BANK."
  (check-type bank register-bank)
  (%register-name name)
  (check-type text string)
  (setf (gethash name (register-bank-values bank))
        (%make-register-value :text (copy-seq text)))
  bank)

(defun register-bank-text (bank name)
  "Return the text stored under NAME, or NIL when it is not a text register."
  (check-type bank register-bank)
  (%register-name name)
  (let ((entry (gethash name (register-bank-values bank))))
    (when (and entry (eq (register-value-kind entry) :text))
      (copy-seq (register-value-value entry)))))

(defun register-bank-put-position (bank name line column)
  "Store the zero-based LINE and COLUMN point position under NAME."
  (check-type bank register-bank)
  (%register-name name)
  (check-type line (integer 0))
  (check-type column (integer 0))
  (setf (gethash name (register-bank-values bank))
        (%make-register-value :position (cons line column)))
  bank)

(defun register-bank-position (bank name)
  "Return (VALUES LINE COLUMN) for a position register, or NIL NIL."
  (check-type bank register-bank)
  (%register-name name)
  (let ((entry (gethash name (register-bank-values bank))))
    (if (and entry (eq (register-value-kind entry) :position))
        (values (car (register-value-value entry))
                (cdr (register-value-value entry)))
        (values nil nil))))
