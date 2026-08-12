;;;; packages/feature/session/src/infrastructure-session-store.lisp
;;;;
;;;; Infrastructure adapter for the domain session snapshot. The store keeps
;;;; filesystem concerns separate from the codec that defines the versioned
;;;; on-disk s-expression format.
(in-package #:loom/feature/session)

(defun %session-temporary-path (target)
  (make-pathname
   :name (format nil ".~A.loom-session-~D-~D"
                 (or (pathname-name target) "session")
                 (get-universal-time)
                 (get-internal-real-time))
   :type (pathname-type target)
   :defaults target))

(defun %session-rename (old-path new-path)
  (host-kit:move-path old-path new-path :if-exists :supersede))

(defgeneric session-store-write (path snapshot)
  (:documentation
   "Validate and atomically write SNAPSHOT to native PATH, returning SNAPSHOT.

The target is replaced only after the complete s-expression has been flushed
to a temporary sibling file. A failed write removes that temporary file and
leaves the previous target untouched.")
  (:method (path snapshot)
    (validate-session-snapshot snapshot)
    (let* ((target (pathname path))
           (temporary (%session-temporary-path target)))
      (unwind-protect
           (progn
             (with-open-file (stream temporary
                                     :direction :output
                                     :if-exists :error
                                     :if-does-not-exist :create
                                     :external-format :utf-8)
               (let ((*print-readably* t)
                     (*print-circle* nil))
                 (write (%session-sexp snapshot) :stream stream)
                 (terpri stream)
                 (finish-output stream)))
             (%session-rename temporary target)
             snapshot)
        (when (probe-file temporary)
          (ignore-errors (delete-file temporary)))))))

(defgeneric session-store-read (path)
  (:documentation
   "Read, safely parse, validate, and return the session snapshot at PATH.

Only one form is accepted, and reader evaluation is disabled. Any malformed
or unsupported input is reported as a session-store-read error.")
  (:method (path)
    (let ((pathname (pathname path)))
      (handler-case
          (with-open-file (stream pathname
                                  :direction :input
                                  :external-format :utf-8)
            (let ((*read-eval* nil)
                  (eof (gensym "EOF")))
              (let ((value (read stream nil eof)))
                (when (eq value eof)
                  (error "session is empty"))
                (let ((trailing (read stream nil eof)))
                  (unless (eq trailing eof)
                    (error "session contains more than one form")))
                (%session-from-sexp value))))
        (error (condition)
          (error "session-store-read: cannot read ~A: ~A" pathname condition))))))
