;;;; packages/feature/session/src/infrastructure-session-store.lisp
;;;;
;;;; Infrastructure adapter for the domain session snapshot. The on-disk form
;;;; is deliberately plain, versioned s-expressions. Reading disables #. and
;;;; accepts only the exact keyword/plist shapes emitted by this file; writing
;;;; uses a temporary sibling followed by cl-host-kit's overwrite-safe move.
(in-package #:loom/feature/session)

(defparameter *loom-session-version* 4)

(defparameter *loom-session-legacy-version* 1)

(defparameter *loom-session-older-version* 2)

(defparameter *loom-session-previous-version* 3)

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
  '(:loom-session :buffers :layout :selected-window-index :recent-files
    :bookmarks :command-history :workspaces :current-workspace-index))

(defparameter *loom-session-previous-top-level-keys*
  '(:loom-session :buffers :layout :selected-window-index :recent-files
    :bookmarks :command-history))

(defparameter *loom-session-older-top-level-keys*
  '(:loom-session :buffers :layout :selected-window-index :recent-files
    :bookmarks))

(defparameter *loom-session-legacy-top-level-keys*
  '(:loom-session :buffers :layout :selected-window-index))

(defparameter *loom-session-buffer-keys*
  '(:name :path :text :point-line :point-column :mark-line :mark-column
    :modified-p))

(defparameter *loom-session-bookmark-keys*
  '(:name :path :buffer-name :line :column))

(defparameter *loom-session-workspace-keys*
  '(:name :layout :selected-window-index))

(defun %session-sexp-buffer (buffer)
  (list :name (session-buffer-snapshot-name buffer)
        :path (session-buffer-snapshot-path buffer)
        :text (session-buffer-snapshot-text buffer)
        :point-line (session-buffer-snapshot-point-line buffer)
        :point-column (session-buffer-snapshot-point-column buffer)
        :mark-line (session-buffer-snapshot-mark-line buffer)
        :mark-column (session-buffer-snapshot-mark-column buffer)
        :modified-p (session-buffer-snapshot-modified-p buffer)))

(defun %session-sexp-bookmark (bookmark)
  (list :name (session-bookmark-snapshot-name bookmark)
        :path (session-bookmark-snapshot-path bookmark)
        :buffer-name (session-bookmark-snapshot-buffer-name bookmark)
        :line (session-bookmark-snapshot-line bookmark)
        :column (session-bookmark-snapshot-column bookmark)))

(defun %session-sexp-workspace (workspace)
  (list :name (session-workspace-snapshot-name workspace)
        :layout (session-workspace-snapshot-layout workspace)
        :selected-window-index
        (session-workspace-snapshot-selected-window-index workspace)))

(defun %session-effective-workspaces (snapshot)
  "Return SNAPSHOT's workspaces, normalizing the pre-workspace API."
  (or (session-snapshot-workspaces snapshot)
      (list (make-session-workspace-snapshot
             :name "main"
             :layout (session-snapshot-layout snapshot)
             :selected-window-index
             (session-snapshot-selected-window-index snapshot)))))

(defun %session-sexp (snapshot)
  (validate-session-snapshot snapshot)
  (let* ((workspaces (%session-effective-workspaces snapshot))
         (current-index (or (session-snapshot-current-workspace-index snapshot)
                            0))
         (current-workspace (nth current-index workspaces)))
    (list :loom-session *loom-session-version*
          :buffers (mapcar #'%session-sexp-buffer
                           (session-snapshot-buffers snapshot))
          ;; Keep the active layout fields for readers of the v3 shape and
          ;; make the v4 envelope self-describing for older tooling.
          :layout (session-workspace-snapshot-layout current-workspace)
          :selected-window-index
          (session-workspace-snapshot-selected-window-index current-workspace)
          :recent-files (session-snapshot-recent-files snapshot)
          :bookmarks (mapcar #'%session-sexp-bookmark
                             (session-snapshot-bookmarks snapshot))
          :command-history (session-snapshot-command-history snapshot)
          :workspaces (mapcar #'%session-sexp-workspace workspaces)
          :current-workspace-index current-index)))

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

(defun %session-bookmark-from-sexp (value)
  (%validate-session-plist value *loom-session-bookmark-keys* "session bookmark")
  (make-session-bookmark-snapshot
   :name (%session-plist-value value :name)
   :path (%session-plist-value value :path)
   :buffer-name (%session-plist-value value :buffer-name)
   :line (%session-plist-value value :line)
   :column (%session-plist-value value :column)))

(defun %session-workspace-from-sexp (value)
  (%validate-session-plist value *loom-session-workspace-keys*
                           "session workspace")
  (make-session-workspace-snapshot
   :name (%session-plist-value value :name)
   :layout (%session-plist-value value :layout)
   :selected-window-index
   (%session-plist-value value :selected-window-index)))

(defun %session-from-sexp (value)
  (let ((version (%session-plist-value value :loom-session)))
    (unless (member version (list *loom-session-legacy-version*
                                  *loom-session-older-version*
                                  *loom-session-previous-version*
                                  *loom-session-version*)
                    :test #'eql)
      (error "session: unsupported version ~S"
             version))
    (let* ((legacy-p (= version *loom-session-legacy-version*))
           (older-p (= version *loom-session-older-version*))
           (previous-p (= version *loom-session-previous-version*)))
      (%validate-session-plist
       value
       (cond
         (legacy-p *loom-session-legacy-top-level-keys*)
         (older-p *loom-session-older-top-level-keys*)
         (previous-p *loom-session-previous-top-level-keys*)
         (t *loom-session-top-level-keys*))
       "session")
      (let ((serialized-buffers (%session-plist-value value :buffers)))
        (unless (listp serialized-buffers)
          (error "session: :buffers must be a proper list"))
        (let* ((recent-files (if legacy-p
                                 nil
                                 (%session-plist-value value :recent-files)))
               (bookmarks (if legacy-p
                              nil
                              (%session-plist-value value :bookmarks)))
               (command-history
                 (if (or previous-p (= version *loom-session-version*))
                     (%session-plist-value value :command-history)
                     nil))
               (layout (%session-plist-value value :layout))
               (selected-index
                 (%session-plist-value value :selected-window-index)))
          (unless (listp recent-files)
            (error "session: :recent-files must be a proper list"))
          (unless (listp bookmarks)
            (error "session: :bookmarks must be a proper list"))
          (unless (and (listp command-history)
                       (every #'stringp command-history))
            (error "session: :command-history must be a list of strings"))
          (let* ((buffers (mapcar #'%session-buffer-from-sexp
                                  serialized-buffers))
                 (workspaces
                   (if (= version *loom-session-version*)
                       (let ((serialized-workspaces
                               (%session-plist-value value :workspaces)))
                         (unless (listp serialized-workspaces)
                           (error "session: :workspaces must be a proper list"))
                         (mapcar #'%session-workspace-from-sexp
                                 serialized-workspaces))
                       (list (make-session-workspace-snapshot
                              :name "main"
                              :layout layout
                              :selected-window-index selected-index))))
                 (current-index
                   (if (= version *loom-session-version*)
                       (%session-plist-value value :current-workspace-index)
                       0)))
            (validate-session-snapshot
             (make-session-snapshot
              :buffers buffers
              :layout layout
              :selected-window-index selected-index
              :recent-files recent-files
              :bookmarks (mapcar #'%session-bookmark-from-sexp bookmarks)
              :command-history command-history
              :workspaces workspaces
              :current-workspace-index current-index))))))))

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
