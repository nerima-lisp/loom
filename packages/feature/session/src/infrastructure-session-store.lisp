;;;; packages/feature/session/src/infrastructure-session-store.lisp
;;;;
;;;; Infrastructure adapter for the domain session snapshot. The on-disk form
;;;; is deliberately plain, versioned s-expressions. Reading disables #. and
;;;; accepts only the exact keyword/plist shapes emitted by this file; writing
;;;; uses a temporary sibling followed by cl-host-kit's overwrite-safe move.
(in-package #:loom/feature/session)

(defparameter *loom-session-version* 5)

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
  '(:loom-session :buffers :recent-files :bookmarks :command-history
    :workspaces :current-workspace-index))

(defmacro define-session-plist-codec (name constructor &body fields)
  "Define a fixed-shape plist serializer and reader for a session value.

FIELDS is a sequence of (:KEY ACCESSOR) declarations. Keeping the shape in
one macro invocation makes the serialized data contract visible and prevents
the writer and reader from drifting apart as fields are added."
  (unless (and (symbolp name)
               (symbolp constructor)
               (every (lambda (field)
                       (and (listp field)
                            (= (length field) 2)
                            (keywordp (first field))
                            (symbolp (second field))))
                      fields))
    (error "Invalid session plist codec declaration: ~S ~S ~S"
           name constructor fields))
  (let* ((stem (string-upcase (symbol-name name)))
         (keys (intern (format nil "*LOOM-SESSION-~A-KEYS*" stem)
                       *package*))
         (serializer (intern (format nil "%SESSION-SEXP-~A" stem)
                             *package*))
         (reader (intern (format nil "%SESSION-~A-FROM-SEXP" stem)
                         *package*))
         (key-list (mapcar #'first fields)))
    `(progn
       (defparameter ,keys ',key-list)
       (defun ,serializer (object)
         (list
          ,@(mapcan (lambda (field)
                      (list (first field)
                            `(,(second field) object)))
                    fields)))
       (defun ,reader (value)
         (%validate-session-plist value ,keys
                                  ,(format nil "session ~A" name))
         (,constructor
          ,@(mapcan (lambda (field)
                      (list (first field)
                            `(%session-plist-value value ,(first field))))
                    fields))))))

(define-session-plist-codec buffer make-session-buffer-snapshot
  (:name session-buffer-snapshot-name)
  (:path session-buffer-snapshot-path)
  (:text session-buffer-snapshot-text)
  (:point-line session-buffer-snapshot-point-line)
  (:point-column session-buffer-snapshot-point-column)
  (:mark-line session-buffer-snapshot-mark-line)
  (:mark-column session-buffer-snapshot-mark-column)
  (:modified-p session-buffer-snapshot-modified-p))

(define-session-plist-codec bookmark make-session-bookmark-snapshot
  (:name session-bookmark-snapshot-name)
  (:path session-bookmark-snapshot-path)
  (:buffer-name session-bookmark-snapshot-buffer-name)
  (:line session-bookmark-snapshot-line)
  (:column session-bookmark-snapshot-column))

(define-session-plist-codec workspace make-session-workspace-snapshot
  (:name session-workspace-snapshot-name)
  (:layout session-workspace-snapshot-layout)
  (:selected-window-index session-workspace-snapshot-selected-window-index))

(defun %session-sexp (snapshot)
  (validate-session-snapshot snapshot)
  (list :loom-session *loom-session-version*
        :buffers (mapcar #'%session-sexp-buffer
                         (session-snapshot-buffers snapshot))
        :recent-files (session-snapshot-recent-files snapshot)
        :bookmarks (mapcar #'%session-sexp-bookmark
                           (session-snapshot-bookmarks snapshot))
        :command-history (session-snapshot-command-history snapshot)
        :workspaces (mapcar #'%session-sexp-workspace
                            (session-snapshot-workspaces snapshot))
        :current-workspace-index
        (session-snapshot-current-workspace-index snapshot)))

(defun %session-from-sexp (value)
  (%validate-session-plist value *loom-session-top-level-keys* "session")
  (let ((version (%session-plist-value value :loom-session)))
    (unless (eql version *loom-session-version*)
      (error "session: unsupported version ~S" version))
    (let ((serialized-buffers (%session-plist-value value :buffers))
          (recent-files (%session-plist-value value :recent-files))
          (serialized-bookmarks (%session-plist-value value :bookmarks))
          (command-history (%session-plist-value value :command-history))
          (serialized-workspaces (%session-plist-value value :workspaces))
          (current-index
            (%session-plist-value value :current-workspace-index)))
      (unless (listp serialized-buffers)
        (error "session: :buffers must be a proper list"))
      (unless (and (listp recent-files)
                   (every #'stringp recent-files))
        (error "session: :recent-files must be a list of strings"))
      (unless (listp serialized-bookmarks)
        (error "session: :bookmarks must be a proper list"))
      (unless (and (listp command-history)
                   (every #'stringp command-history))
        (error "session: :command-history must be a list of strings"))
      (unless (listp serialized-workspaces)
        (error "session: :workspaces must be a proper list"))
      (validate-session-snapshot
       (make-session-snapshot
        :buffers (mapcar #'%session-buffer-from-sexp serialized-buffers)
        :recent-files recent-files
        :bookmarks (mapcar #'%session-bookmark-from-sexp
                           serialized-bookmarks)
        :command-history command-history
        :workspaces (mapcar #'%session-workspace-from-sexp
                            serialized-workspaces)
        :current-workspace-index current-index)))))

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
