(in-package #:loom/feature/lifecycle)

(defvar *loom-state-directory* nil
  "Directory holding loom's per-user state (recovery/ and locks/), or NIL.
NIL disables every recovery and lock read or write. The executable sets it to
~/.loom/ at startup; tests bind it to a temporary directory.")

(defconstant +recovery-meta-version+ 1)
(defconstant +recovery-meta-size-limit+ 4096)

(defun %private-state-directory (name)
  "Return state subdirectory NAME, creating it with mode 0700 when missing.
An existing directory keeps its mode. Return NIL when no state directory is set."
  (when *loom-state-directory*
    (let ((root (uiop:ensure-directory-pathname *loom-state-directory*)))
      (ensure-directories-exist root)
      (host-kit:create-directory (merge-pathnames name root)
                                 :mode #o700
                                 :if-exists :ignore))))

(defun %recovery-directory ()
  "Return the recovery directory pathname without creating it, or NIL."
  (when *loom-state-directory*
    (merge-pathnames "recovery/"
                     (uiop:ensure-directory-pathname *loom-state-directory*))))

(defun %recovery-entry-paths (directory reason index)
  "Return a fresh body pathname and its metadata pathname in DIRECTORY."
  (loop for attempt from 0
        for stem = (format nil "buffer-~(~A~)-~D-~D-~D-~D"
                           reason
                           (get-universal-time)
                           (get-internal-real-time)
                           index
                           attempt)
        for body = (make-pathname :name stem :type "txt" :defaults directory)
        for meta = (make-pathname :name stem :type "sexp" :defaults directory)
        unless (or (host-kit:path-exists-p body) (host-kit:path-exists-p meta))
          return (values body meta)))

(defun %character-string (string)
  ;; *PRINT-READABLY* prints a BASE-STRING as #A(...), which the reader rejects.
  (coerce string '(simple-array character (*))))

(defun %recovery-meta-path-string (buffer)
  (let ((path (buffer-path buffer)))
    (and path
         (%character-string
          (native-path-namestring (host-kit:ensure-absolute-pathname path))))))

(defun %recovery-meta-text (buffer reason)
  "Return the printed metadata form for BUFFER saved because of REASON."
  (with-standard-io-syntax
    (let ((*package* (find-package :keyword)))
      (format nil "~S~%"
              (list :version +recovery-meta-version+
                    :path (%recovery-meta-path-string buffer)
                    :buffer-name (%character-string (buffer-name buffer))
                    :reason reason
                    :time (get-universal-time))))))

(defun %save-recovery-buffer (buffer reason index)
  "Write BUFFER's text and then its metadata as new 0600 files.
Return the body pathname, or NIL when no state directory is set."
  (let ((directory (%private-state-directory "recovery/")))
    (when directory
      (multiple-value-bind (body meta) (%recovery-entry-paths directory reason index)
        (host-kit:write-file-string (buffer-text buffer) body
                                    :mode #o600 :if-exists :error)
        (host-kit:write-file-string (%recovery-meta-text buffer reason) meta
                                    :mode #o600 :if-exists :error)
        body))))

(defun %reject-dispatch-macro (stream character)
  (declare (ignore stream character))
  (error "Recovery metadata does not allow # syntax"))

(defun %read-first-recovery-form (text)
  "Read only the first form of TEXT with evaluation and # syntax disabled."
  (with-standard-io-syntax
    (let ((*read-eval* nil)
          (*package* (find-package :keyword))
          (*readtable* (copy-readtable nil)))
      (set-macro-character #\# #'%reject-dispatch-macro)
      (read-from-string text))))

(defun %valid-recovery-meta-p (form)
  (and (listp form)
       (handler-case (= (length form) 10) (type-error () nil))
       (loop for (key) on form by #'cddr
             always (member key '(:version :path :buffer-name :reason :time)))
       (= (length (remove-duplicates
                   (loop for (key) on form by #'cddr collect key)))
          5)
       (eql (getf form :version) +recovery-meta-version+)
       (let ((path (getf form :path)))
         (or (null path)
             (and (stringp path) (plusp (length path)) (char= (char path 0) #\/))))
       (stringp (getf form :buffer-name))
       (member (getf form :reason) '(:sigterm :sighup))
       (typep (getf form :time) '(integer 0))))

(defun read-recovery-meta (pathname)
  "Return the validated metadata plist stored at PATHNAME, or NIL.
Files over 4 KiB, unreadable files, and malformed forms yield NIL."
  (handler-case
      (let ((metadata (host-kit:file-metadata pathname)))
        (when (and (eq (host-kit:file-metadata-kind metadata) :regular-file)
                   (<= (host-kit:file-metadata-size metadata)
                       +recovery-meta-size-limit+))
          (let ((form (%read-first-recovery-form (host-kit:read-file-string pathname))))
            (and (%valid-recovery-meta-p form) form))))
    (error () nil)))

(defstruct (recovery-entry (:copier nil))
  "One recovery body with its metadata. PATH is NIL for a legacy body or one
whose metadata is missing or invalid."
  body
  meta
  path
  buffer-name
  reason
  time
  modification-time)

(defstruct (%recovery-index (:copier nil))
  directory
  stamp
  scanned-at
  (metas (make-hash-table :test #'equal))
  entries)

(defvar *recovery-index* nil
  "Cache of the last recovery directory listing and its parsed metadata.")

(defun %file-stamp (metadata)
  (list (host-kit:file-metadata-modification-time metadata)
        (host-kit:file-metadata-size metadata)
        (host-kit:file-metadata-inode metadata)))

(defun %stamp-current-p (stamp scanned-at)
  ;; Stamps have whole-second resolution, so a change in the scan's own second
  ;; could leave the stamp unchanged; such entries are read again.
  (< (first stamp) scanned-at))

(defun %cached-recovery-meta (index pathname metadata)
  (let* ((key (native-path-namestring pathname))
         (stamp (%file-stamp metadata))
         (cached (gethash key (%recovery-index-metas index))))
    (if (and cached
             (equal (car cached) stamp)
             (%stamp-current-p stamp (%recovery-index-scanned-at index)))
        (cdr cached)
        (let ((meta (read-recovery-meta pathname)))
          (setf (gethash key (%recovery-index-metas index)) (cons stamp meta))
          meta))))

(defun %scan-recovery-directory (index directory)
  (let ((bodies nil)
        (metas (make-hash-table :test #'equal))
        (live (make-hash-table :test #'equal)))
    (host-kit:call-with-directory-entries
     (lambda (pathname metadata)
       (when (eq (host-kit:file-metadata-kind metadata) :regular-file)
         (let ((type (pathname-type pathname)))
           (cond
             ((equal type "txt") (push (cons pathname metadata) bodies))
             ((equal type "sexp")
              (setf (gethash (native-path-namestring pathname) live) t)
              (setf (gethash (pathname-name pathname) metas)
                    (cons pathname
                          (%cached-recovery-meta index pathname metadata))))))))
     directory)
    (maphash (lambda (key value)
               (declare (ignore value))
               (unless (gethash key live)
                 (remhash key (%recovery-index-metas index))))
             (%recovery-index-metas index))
    (loop for (body . metadata) in (nreverse bodies)
          for (meta-path . meta) = (gethash (pathname-name body) metas)
          collect (make-recovery-entry
                   :body body
                   :meta (and meta meta-path)
                   :path (getf meta :path)
                   :buffer-name (getf meta :buffer-name)
                   :reason (getf meta :reason)
                   :time (getf meta :time)
                   :modification-time
                   (host-kit:file-metadata-modification-time metadata)))))

(defun recovery-entries ()
  "Return the recovery entries in the state directory in body name order.
The directory listing is reused while the directory's modification time, size,
and inode stay unchanged; changed metadata files are read again."
  (let ((directory (%recovery-directory)))
    (when directory
      (let ((metadata (handler-case (host-kit:file-metadata directory)
                        (host-kit:host-operation-failed () nil))))
        (if (not (and metadata
                      (eq (host-kit:file-metadata-kind metadata) :directory)))
            (progn (setf *recovery-index* nil) nil)
            (let ((stamp (%file-stamp metadata))
                  (index *recovery-index*))
              (if (and index
                       (equal (%recovery-index-directory index) directory)
                       (equal (%recovery-index-stamp index) stamp)
                       (%stamp-current-p stamp (%recovery-index-scanned-at index)))
                  (copy-list (%recovery-index-entries index))
                  (let* ((scanned-at (get-universal-time))
                         (index (if (and index
                                         (equal (%recovery-index-directory index)
                                                directory))
                                    index
                                    (make-%recovery-index :directory directory))))
                    (setf (%recovery-index-entries index)
                          (%scan-recovery-directory index directory)
                          (%recovery-index-stamp index) stamp
                          (%recovery-index-scanned-at index) scanned-at
                          *recovery-index* index)
                    (copy-list (%recovery-index-entries index))))))))))
