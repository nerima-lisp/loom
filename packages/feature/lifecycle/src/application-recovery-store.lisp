(in-package #:loom/feature/lifecycle)

(defvar *loom-state-directory* nil
  "Directory holding loom's per-user state (recovery/ and locks/), or NIL.
NIL disables every recovery and lock read or write. The executable sets it to
~/.loom/ at startup; tests bind it to a temporary directory.")

(defconstant +recovery-meta-version+ 1)
(defconstant +recovery-meta-size-limit+ 4096)

(defun %state-subdirectory (name)
  "Return the pathname of state subdirectory NAME (recovery/ or locks/) without
creating it, or NIL when no state directory is set. Every recovery and lock
path is derived from *LOOM-STATE-DIRECTORY* here."
  (when *loom-state-directory*
    (merge-pathnames name (uiop:ensure-directory-pathname *loom-state-directory*))))

(defun %private-state-directory (name)
  "Return state subdirectory NAME, creating it with mode 0700 when missing.
An existing directory keeps its mode. Return NIL when no state directory is set."
  (let ((directory (%state-subdirectory name)))
    (when directory
      (ensure-directories-exist (uiop:ensure-directory-pathname *loom-state-directory*))
      (host-kit:create-directory directory :mode #o700 :if-exists :ignore))))

(defun %fnv-1a-64 (octets)
  (let ((hash 14695981039346656037))
    (loop for octet across octets
          do (setf hash (ldb (byte 64 0)
                             (* (logxor hash octet) 1099511628211))))
    hash))

(defun file-path-hash (native-path)
  "Return the FNV-1a 64-bit hash of NATIVE-PATH's UTF-8 octets as 16 lowercase
hex digits. Lock file names and recovery file names carry it."
  (format nil "~(~16,'0X~)"
          (%fnv-1a-64 (sb-ext:string-to-octets native-path :external-format :utf-8))))

(defun %recovery-entry-paths (directory reason index hash)
  "Return a fresh body pathname and its metadata pathname in DIRECTORY.
HASH, the FILE-PATH-HASH of the buffer's truename, follows the reason so that
opening a file reads only the metadata written for it; pathless buffers have
no HASH."
  (loop for attempt from 0
        for stem = (format nil "buffer-~(~A~)-~@[~A-~]~D-~D-~D-~D"
                           reason
                           hash
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

(defun buffer-file-truename (buffer)
  "Return the native truename string of BUFFER's file, or NIL without a path.
A missing file resolves through its nearest existing directory."
  (let ((path (buffer-path buffer)))
    (when path
      (%character-string
       (native-path-namestring (host-kit:truenamize (literal-file-path path)))))))

(defun %recovery-meta-text (buffer reason truename)
  "Return the printed metadata form for BUFFER saved because of REASON.
TRUENAME is recorded as the path so that a later open compares paths without
resolving each recorded one."
  (with-standard-io-syntax
    (let ((*package* (find-package :keyword)))
      (format nil "~S~%"
              (list :version +recovery-meta-version+
                    :path truename
                    :buffer-name (%character-string (buffer-name buffer))
                    :reason reason
                    :time (get-universal-time))))))

(defun %recovery-path (buffer)
  "Return the native truename of BUFFER's file, or the native name of its path
when the truename cannot be resolved, so that the body is still written."
  (handler-case (buffer-file-truename buffer)
    (error ()
      (%character-string (native-path-namestring (literal-file-path (buffer-path buffer)))))))

(defun %save-recovery-buffer (buffer reason index)
  "Write BUFFER's text and then its metadata as new 0600 files.
Return the body pathname, or NIL when no state directory is set."
  (let ((directory (%private-state-directory "recovery/")))
    (when directory
      (let ((truename (and (buffer-path buffer) (%recovery-path buffer))))
        (multiple-value-bind (body meta)
            (%recovery-entry-paths directory reason index
                                   (and truename (file-path-hash truename)))
          (host-kit:write-file-string (buffer-text buffer) body
                                      :mode #o600 :if-exists :error)
          (host-kit:write-file-string (%recovery-meta-text buffer reason truename) meta
                                      :mode #o600 :if-exists :error)
          body)))))

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
  (let ((directory (%state-subdirectory "recovery/")))
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

(defun %directory-entry-names (directory)
  "Return the entry names in DIRECTORY, read by name only without a status
call per entry, or NIL when DIRECTORY does not exist."
  (let ((stream (handler-case (sb-posix:opendir (native-path-namestring directory))
                  (sb-posix:syscall-error (condition)
                    (if (= (sb-posix:syscall-errno condition) sb-posix:enoent)
                        (return-from %directory-entry-names nil)
                        (error condition))))))
    (unwind-protect
         (loop with names = nil
               for entry = (sb-posix:readdir stream)
               until (or (null entry) (sb-alien:null-alien entry))
               do (let ((name (sb-posix:dirent-name entry)))
                    (unless (member name '("." "..") :test #'string=)
                      (push name names)))
               finally (return (nreverse names)))
      (sb-posix:closedir stream))))

(defun %name-stem (name type)
  "Return NAME without its .TYPE suffix, or NIL when NAME lacks that suffix."
  (let ((suffix-start (- (length name) (length type) 1)))
    (and (plusp suffix-start)
         (char= (char name suffix-start) #\.)
         (string= type name :start2 (1+ suffix-start))
         (subseq name 0 suffix-start))))

(defun %hashed-body-name-p (name needles)
  "True when NAME is buffer-<reason>-<hash>-....txt and one of NEEDLES, each
-<hash>-, follows the reason. Names are compared in place, without copying."
  (let ((length (length name)))
    (and (> length 11)
         (string= "buffer-" name :end2 7)
         (string= ".txt" name :start2 (- length 4))
         (let ((dash (position #\- name :start 7)))
           (and dash
                (some (lambda (needle)
                        (let ((end (+ dash (length needle))))
                          (and (<= end length)
                               (string= needle name :start2 dash :end2 end))))
                      needles))))))

(defun recovery-entries-with-hashes (hashes)
  "Return the recovery entries whose body names carry one of HASHES and whose
metadata is valid, in body name order. The directory is read by name, and only
the matching bodies and their metadata files are examined, so the cost of an
open grows with the directory's name count but not with unrelated metadata."
  (let ((directory (%state-subdirectory "recovery/")))
    (when directory
      (let* ((needles (mapcar (lambda (hash) (concatenate 'string "-" hash "-")) hashes))
             (bodies (remove-if-not (lambda (name) (%hashed-body-name-p name needles))
                                    (%directory-entry-names directory))))
        (loop for name in (sort bodies #'string<)
              for entry = (%hashed-recovery-entry directory (%name-stem name "txt"))
              when entry
                collect entry)))))

(defun %hashed-recovery-entry (directory stem)
  "Return the entry for STEM's body and valid metadata, or NIL when either is
missing, the body is not a regular file, or the metadata is invalid."
  (let* ((body (make-pathname :name stem :type "txt" :defaults directory))
         (meta-path (make-pathname :name stem :type "sexp" :defaults directory))
         (meta (read-recovery-meta meta-path))
         (metadata (and meta
                        (handler-case (host-kit:file-metadata body)
                          (host-kit:host-operation-failed () nil)))))
    (when (and metadata (eq (host-kit:file-metadata-kind metadata) :regular-file))
      (make-recovery-entry
       :body body
       :meta meta-path
       :path (getf meta :path)
       :buffer-name (getf meta :buffer-name)
       :reason (getf meta :reason)
       :time (getf meta :time)
       :modification-time (host-kit:file-metadata-modification-time metadata)))))

(defun recovery-body-count ()
  "Return how many recovery bodies the state directory holds, counted from
their names alone."
  (let ((directory (%state-subdirectory "recovery/")))
    (if directory
        (count-if (lambda (name) (%name-stem name "txt"))
                  (%directory-entry-names directory))
        0)))
