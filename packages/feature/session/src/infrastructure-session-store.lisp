;;;; packages/feature/session/src/infrastructure-session-store.lisp
;;;;
;;;; Infrastructure adapter for the domain session snapshot. The on-disk form
;;;; is deliberately plain, versioned s-expressions. Reading disables #. and
;;;; accepts only the exact keyword/plist shapes emitted by this file; writing
;;;; uses a temporary sibling followed by UIOP's overwrite-safe rename operation.
(in-package #:loom/feature/session)

(defparameter *loom-session-version* 1)

(defun %session-plist-value (plist key)
  (loop for tail on plist by #'cddr
        when (eq (first tail) key)
          return (second tail)))

(defun %validate-session-plist (value expected-keys context)
  (unless (and (listp value)
               (evenp (length value))
               (loop for tail on value by #'cddr
                     always (keywordp (first tail))))
    (error "~A: expected a keyword plist, got ~S" context value))
  (let ((keys (loop for tail on value by #'cddr collect (first tail))))
    (unless (and (= (length keys) (length expected-keys))
                 (every (lambda (key) (member key expected-keys :test #'eq)) keys)
                 (every (lambda (key) (member key keys :test #'eq)) expected-keys))
      (error "~A: unexpected or duplicate fields in ~S" context value)))
  value)

(defparameter *loom-session-top-level-keys*
  '(:loom-session :buffers :layout :selected-window-index))

(defparameter *loom-session-buffer-keys*
  '(:name :path :text :point-line :point-column :mark-line :mark-column
    :modified-p))

(defun %session-sexp-buffer (buffer)
  (list :name (session-buffer-snapshot-name buffer)
        :path (session-buffer-snapshot-path buffer)
        :text (session-buffer-snapshot-text buffer)
        :point-line (session-buffer-snapshot-point-line buffer)
        :point-column (session-buffer-snapshot-point-column buffer)
        :mark-line (session-buffer-snapshot-mark-line buffer)
        :mark-column (session-buffer-snapshot-mark-column buffer)
        :modified-p (session-buffer-snapshot-modified-p buffer)))

(defun %session-sexp (snapshot)
  (validate-session-snapshot snapshot)
  (list :loom-session *loom-session-version*
        :buffers (mapcar #'%session-sexp-buffer
                         (session-snapshot-buffers snapshot))
        :layout (session-snapshot-layout snapshot)
        :selected-window-index (session-snapshot-selected-window-index snapshot)))

(defun %session-buffer-from-sexp (value)
  (%validate-session-plist value *loom-session-buffer-keys* "session buffer")
  (make-session-buffer-snapshot
   :name (%session-plist-value value :name)
   :path (%session-plist-value value :path)
   :text (%session-plist-value value :text)
   :point-line (%session-plist-value value :point-line)
   :point-column (%session-plist-value value :point-column)
   :mark-line (%session-plist-value value :mark-line)
   :mark-column (%session-plist-value value :mark-column)
   :modified-p (%session-plist-value value :modified-p)))

(defun %session-from-sexp (value)
  (%validate-session-plist value *loom-session-top-level-keys* "session")
  (unless (= (%session-plist-value value :loom-session)
             *loom-session-version*)
    (error "session: unsupported version ~S"
           (%session-plist-value value :loom-session)))
  (let ((buffers (%session-plist-value value :buffers)))
    (unless (listp buffers)
      (error "session: :buffers must be a proper list"))
    (validate-session-snapshot
     (make-session-snapshot
      :buffers (mapcar #'%session-buffer-from-sexp buffers)
      :layout (%session-plist-value value :layout)
      :selected-window-index
      (%session-plist-value value :selected-window-index)))))

(defun %session-temporary-path (target)
  (make-pathname
   :name (format nil ".~A.loom-session-~D-~D"
                 (or (pathname-name target) "session")
                 (get-universal-time)
                 (get-internal-real-time))
   :type (pathname-type target)
   :defaults target))

(defun %session-rename (old-path new-path)
  (uiop:rename-file-overwriting-target old-path new-path))

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
