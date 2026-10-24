(in-package #:loom/core/editor-session)

(defstruct (editor-session
            (:constructor %make-editor-session (slice-names))
            (:conc-name %editor-session-))
  (slice-names nil :read-only t)
  (slice-states (make-hash-table :test #'equal) :read-only t))

(defvar *editor-session* nil)

(defvar *slice-state-constructors* (make-hash-table :test #'equal))

(defun register-slice-state (name constructor)
  (check-type name symbol)
  (check-type constructor symbol)
  (unless (fboundp constructor)
    (error "Slice state constructor ~S is not fbound" constructor))
  (multiple-value-bind (registered-constructor registered-p)
      (gethash name *slice-state-constructors*)
    (when (and registered-p (not (eq registered-constructor constructor)))
      (error "Slice state ~S is already registered with another constructor" name))
    (unless registered-p
      (setf (gethash name *slice-state-constructors*) constructor)))
  constructor)

(defun make-editor-session (slice-names &key (initial-slices nil))
  "Create a session with registered state for SLICE-NAMES.

INITIAL-SLICES is a list of (NAME . STATE) entries for requested slices.
Those values are installed before any constructors run. Requested names
without an entry use registered constructors in SLICE-NAMES order, so each
constructor dependency must be supplied initially or named earlier."
  (check-type slice-names list)
  (check-type initial-slices list)
  (let ((names (copy-list slice-names))
        (seen (make-hash-table :test #'equal))
        (initial-state-names (make-hash-table :test #'equal))
        (constructors nil))
    (dolist (entry initial-slices)
      (unless (consp entry)
        (error "Initial slice state must be a cons: ~S" entry))
      (let ((name (car entry)))
        (check-type name symbol)
        (unless (member name names :test #'equal)
          (error "Initial slice state ~S is not requested" name))
        (when (gethash name initial-state-names)
          (error "Initial slice state ~S appears more than once" name))
        (setf (gethash name initial-state-names) t)))
    (dolist (name names)
      (check-type name symbol)
      (when (gethash name seen)
        (error "Slice state ~S appears more than once" name))
      (setf (gethash name seen) t)
      (unless (gethash name initial-state-names)
        (multiple-value-bind (constructor registered-p)
            (gethash name *slice-state-constructors*)
          (unless registered-p
            (error "Slice state ~S is not registered" name))
          (push (cons name constructor) constructors))))
    (let ((session (%make-editor-session names)))
      (dolist (entry initial-slices)
        (setf (gethash (car entry) (%editor-session-slice-states session))
              (cdr entry)))
      (dolist (entry (nreverse constructors))
        (setf (gethash (car entry) (%editor-session-slice-states session))
              (funcall (symbol-function (cdr entry)) session)))
      session)))

(defun editor-session-slice (session name)
  (check-type session editor-session)
  (multiple-value-bind (state registered-p)
      (gethash name (%editor-session-slice-states session))
    (unless registered-p
      (error "Slice state ~S is not part of this editor session" name))
    state))

(defun editor-session-slice-names (session)
  (check-type session editor-session)
  (copy-list (%editor-session-slice-names session)))

(defun call-with-editor-session (session function)
  (check-type session editor-session)
  (check-type function function)
  (let ((*editor-session* session))
    (funcall function)))
