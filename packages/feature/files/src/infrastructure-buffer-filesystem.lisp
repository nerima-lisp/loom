(in-package #:loom/feature/files)

(progn
  #+(and sbcl darwin 64-bit)
  (sb-alien:define-alien-routine ("stat" %file-metadata-stat) sb-alien:int
    (path sb-alien:c-string)
    (buffer (* t)))
  (defun %file-metadata-stamp (path)
    ;; SBCL drops subsecond fields from its public stat object. Check the
    ;; private generated Darwin layout before reading it; otherwise the switch
    ;; guard compares contents. A same-stamp rewrite can pass this one-shot
    ;; check and is compared by file contents on a later switch.
    #+(and sbcl darwin 64-bit)
    (when (%native-file-octet-io-p)
      (ignore-errors
        (let* ((posix-package (find-package :sb-posix))
               (alien-package (find-package :sb-alien-internals))
               (parse-symbol (and alien-package
                                  (find-symbol "PARSE-ALIEN-TYPE" alien-package)))
               (bits-symbol (and alien-package
                                 (find-symbol "ALIEN-TYPE-BITS" alien-package)))
               (alignment-symbol
                 (and alien-package
                      (find-symbol "ALIEN-TYPE-ALIGNMENT" alien-package))))
          (when (and posix-package
                     parse-symbol
                     (fboundp parse-symbol)
                     bits-symbol
                     (fboundp bits-symbol)
                     alignment-symbol
                     (fboundp alignment-symbol))
            (let ((parse-function (symbol-function parse-symbol))
                  (bits-function (symbol-function bits-symbol))
                  (alignment-function (symbol-function alignment-symbol)))
              (flet ((posix-value (name)
                       (let ((symbol (find-symbol name posix-package)))
                         (and symbol
                              (boundp symbol)
                              (symbol-value symbol))))
                     (posix-type (name)
                       (let ((symbol (find-symbol name posix-package)))
                         (and symbol (funcall parse-function symbol nil))))
                     (type-bits (type)
                       (funcall bits-function type))
                     (type-alignment (type)
                       (funcall alignment-function type)))
                (let* ((dev-offset
                         (posix-value "OFFSET-OF-ALIEN-STAT-DEV"))
                       (ino-offset
                         (posix-value "OFFSET-OF-ALIEN-STAT-INO"))
                       (size-offset
                         (posix-value "OFFSET-OF-ALIEN-STAT-SIZE"))
                       (mtime-offset
                         (posix-value "OFFSET-OF-ALIEN-STAT-MTIME"))
                       (ctime-offset
                         (posix-value "OFFSET-OF-ALIEN-STAT-CTIME"))
                       (stat-type (posix-type "ALIEN-STAT"))
                       (dev-type (posix-type "DEV-T"))
                       (ino-type (posix-type "INO-T"))
                       (off-type (posix-type "OFF-T"))
                       (time-type (posix-type "TIME-T"))
                       (stat-bits (and stat-type (type-bits stat-type)))
                       (stat-size (and stat-bits (/ stat-bits 8))))
                  (when (and (eql dev-offset 0)
                             (eql ino-offset 8)
                             (eql size-offset 96)
                             (eql mtime-offset 48)
                             (eql ctime-offset 64)
                             (= (- ctime-offset mtime-offset) 16)
                             stat-type dev-type ino-type off-type time-type
                             (= stat-bits 1152)
                             (= (type-alignment stat-type) 64)
                             (= (type-bits dev-type) 32)
                             (= (type-alignment dev-type) 32)
                             (= (type-bits ino-type) 64)
                             (= (type-alignment ino-type) 64)
                             (= (type-bits off-type) 64)
                             (= (type-alignment off-type) 64)
                             (= (type-bits time-type) 64)
                             (= (type-alignment time-type) 64)
                             (<= (+ ctime-offset 16) stat-size)
                             (<= (+ size-offset 8) stat-size)
                             (sb-sys:find-foreign-symbol-address "stat"))
                    (let* ((raw (sb-alien:make-alien sb-alien:char stat-size))
                           (sap (sb-alien:alien-sap raw)))
                      (unwind-protect
                           (when (zerop
                                  (%file-metadata-stat
                                   (%native-namestring path)
                                   (sb-alien:cast raw (* t))))
                             (let ((mtime-nanoseconds
                                     (sb-sys:sap-ref-64
                                      sap (+ mtime-offset 8)))
                                   (ctime-nanoseconds
                                     (sb-sys:sap-ref-64
                                      sap (+ ctime-offset 8))))
                               (when (and (<= 0 mtime-nanoseconds 999999999)
                                          (<= 0 ctime-nanoseconds 999999999))
                                 (list (sb-sys:sap-ref-32 sap dev-offset)
                                       (sb-sys:sap-ref-64 sap ino-offset)
                                       (sb-sys:sap-ref-64 sap size-offset)
                                       (sb-sys:sap-ref-64 sap mtime-offset)
                                       mtime-nanoseconds
                                       (sb-sys:sap-ref-64 sap ctime-offset)
                                       ctime-nanoseconds))))
                        (sb-alien:free-alien raw)))))))))))
    #-(and sbcl darwin 64-bit)
    (declare (ignore path))
    #-(and sbcl darwin 64-bit)
    nil)
  (defvar *freshly-loaded-file-buffers* (make-hash-table :test #'eq)))
(defun %load-file-buffer (path &key (name (file-namestring path)))
  (let* ((before-stamp (%file-metadata-stamp path))
         (snapshot (%read-file-snapshot path))
         (after-stamp (%file-metadata-stamp path))
         (buffer
           (make-buffer :name name
                        :path path
                        :initial-content
                        (if snapshot
                            (%file-snapshot-text snapshot)
                            (error "Cannot load missing file ~A" path)))))
    (%remember-file-snapshot buffer snapshot)
    (setf (gethash buffer *freshly-loaded-file-buffers*)
          (and before-stamp
               after-stamp
               (equal before-stamp after-stamp)
               after-stamp))
    (buffer-set-major-mode buffer
                           (loom/feature/mode:major-mode-for-path path))
    (when (and (eq *loom-filesystem* *loom-real-filesystem*)
               (not (if (%native-path-operation-p path)
                        (%native-file-writable-p path)
                        (host-kit:file-writable-p path))))
      (buffer-set-read-only buffer t))
    buffer))

(defmethod buffer-load (path)
  (let ((buffer (%load-file-buffer path)))
    (remhash buffer *freshly-loaded-file-buffers*)
    buffer))

(defvar *loom-backup-directory* nil)
(defun %loom-backup-directory ()
  (uiop:ensure-directory-pathname
   (or *loom-backup-directory*
       (merge-pathnames
        ".loom/backups/"
        (uiop:ensure-directory-pathname
         (or (uiop:getenv "HOME")
             (user-homedir-pathname)))))))
(defun %copy-file-octets (source destination)
  (let ((created nil)
        (complete nil)
        (native-path-p (%native-path-operation-p source destination)))
    (flet ((copy-octets (input output)
             (let ((chunk
                     (make-array 8192
                                 :element-type (quote (unsigned-byte 8)))))
               (loop for count = (read-sequence chunk input)
                     while (plusp count)
                     do (write-sequence chunk output :end count))
               (finish-output output))))
      (unwind-protect
           (progn
             (if native-path-p
                 #+sbcl
                 (%with-native-file-descriptor
                     (output-fd destination
                                (logior sb-posix:o-wronly
                                        sb-posix:o-creat
                                        sb-posix:o-excl)
                                #o666)
                   (setf created t)
                   (%with-native-file-descriptor
                       (input-fd source sb-posix:o-rdonly)
                     (let ((input-stream
                             (sb-sys:make-fd-stream
                              input-fd
                              :input t
                              :element-type (quote (unsigned-byte 8)))))
                       (setf input-fd nil)
                       (unwind-protect
                            (let ((output-stream
                                    (sb-sys:make-fd-stream
                                     output-fd
                                     :output t
                                     :element-type (quote (unsigned-byte 8)))))
                              (setf output-fd nil)
                              (unwind-protect
                                   (copy-octets input-stream output-stream)
                                (close output-stream)))
                         (close input-stream)))))
                 #-sbcl
                 nil
                 (with-open-file (output destination
                                         :direction :output
                                         :element-type
                                         (quote (unsigned-byte 8))
                                         :if-exists :error
                                         :if-does-not-exist :create)
                   (setf created t)
                   (with-open-file (input source
                                          :direction :input
                                          :element-type
                                          (quote (unsigned-byte 8)))
                     (copy-octets input output))))
             (setf complete t)
             destination)
        (when (and created (not complete))
          #+sbcl
          (ignore-errors
            (if native-path-p
                (sb-posix:unlink (%native-namestring destination))
                (delete-file destination)))
          #-sbcl
          (ignore-errors (delete-file destination)))))))
(defun %backup-existing-file (path)
  (let* ((directory (%loom-backup-directory))
         (file-name (file-namestring (pathname path))))
    (ensure-directories-exist directory)
    (loop for index from 1
          for backup-path = (merge-pathnames
                             (format nil "~A.~D~~" file-name index)
                             directory)
          unless (if (%native-path-operation-p backup-path)
                     (%native-path-exists-p backup-path)
                     (probe-file backup-path))
            do (return (%copy-file-octets path backup-path)))))
(progn
  (defstruct (%file-snapshot
               (:constructor %make-file-snapshot (&key raw-octets text format)))
    raw-octets
    text
    format)
  (progn
    (defvar *file-buffer-snapshots* (make-hash-table :test #'eq)))
  (defvar *confirmed-file-overwrite* nil)
  (define-condition %file-changed-on-disk (error)
    ((path :initarg :path :reader %file-changed-path)
     (snapshot :initarg :snapshot :reader %file-changed-snapshot))
    (:report
     (lambda (condition stream)
       (format stream "File changed on disk: ~A"
               (%file-changed-path condition)))))
  (defun %file-path-exists-p (path)
    (if (%native-path-operation-p path)
        (%native-path-exists-p path)
        (cl-boundary-kit:filesystem-path-exists-p *loom-filesystem* path)))
  (defun %copy-file-snapshot (snapshot)
    (when snapshot
      (%make-file-snapshot
       :raw-octets (and (%file-snapshot-raw-octets snapshot)
                        (copy-seq (%file-snapshot-raw-octets snapshot)))
       :text (copy-seq (%file-snapshot-text snapshot))
       :format (%file-snapshot-format snapshot))))
  (defun %read-file-snapshot (path)
    (when (%file-path-exists-p path)
      (if (%native-file-octet-io-p)
          (let ((octets (%native-read-file-octets path)))
            (multiple-value-bind (text format) (%decode-file-octets octets)
              (%make-file-snapshot
               :raw-octets (copy-seq octets)
               :text text
               :format format)))
          (%make-file-snapshot
           :text (cl-boundary-kit:filesystem-read-file *loom-filesystem* path)))))
  (progn
    (setf *file-snapshot-reader* (function %read-file-snapshot))
    (setf *file-metadata-stamp-reader* (function %file-metadata-stamp)))
  (defun %file-snapshot-equal-p (left right)
    (cond
      ((and (null left) (null right)) t)
      ((or (null left) (null right)) nil)
      ((and (%file-snapshot-raw-octets left)
            (%file-snapshot-raw-octets right))
       (equalp (%file-snapshot-raw-octets left)
               (%file-snapshot-raw-octets right)))
      ((or (%file-snapshot-raw-octets left)
           (%file-snapshot-raw-octets right))
       nil)
      (t (string= (%file-snapshot-text left)
                  (%file-snapshot-text right)))))
  (defun %file-buffer-snapshot (buffer)
  (gethash buffer *file-buffer-snapshots*))
  (defun file-format-indicator (buffer)
  "Return a file format indicator for BUFFER, or NIL for an unvisited buffer.
The string contains newline style and encoding, plus BOM when present. New file buffers return LF UTF-8."
  (multiple-value-bind (snapshot tracked-p)
      (%file-buffer-snapshot buffer)
    (when (and tracked-p (buffer-path buffer))
      (let ((file-format
              (or (and snapshot (%file-snapshot-format snapshot))
                  (%make-file-format :encoding :utf-8
                                     :newline :lf
                                     :mixed-newlines-p nil
                                     :bom-p nil))))
        (%file-format-indicator file-format)))))
  (defun %remember-file-snapshot (buffer snapshot)
    (setf (gethash buffer *file-buffer-snapshots*)
          (%copy-file-snapshot snapshot))
    buffer)
  (defun %forget-file-buffer-snapshot (session buffer reason)
    (declare (ignore session reason))
    (remhash buffer *file-buffer-snapshots*)
    (remhash buffer *freshly-loaded-file-buffers*)
    nil)
  (register-session-hook :buffer-close
                         :feature/files
                         #'%forget-file-buffer-snapshot)
  (defun %assert-file-save-current (buffer path)
  (multiple-value-bind (baseline baseline-known-p)
      (%file-buffer-snapshot buffer)
    (let ((current (%read-file-snapshot path)))
      (multiple-value-bind (approved approved-p)
          (if (and *confirmed-file-overwrite*
                   (eq buffer (car *confirmed-file-overwrite*)))
              (values (cdr *confirmed-file-overwrite*) t)
              (values nil nil))
        (cond
          (baseline-known-p
           (unless (or (%file-snapshot-equal-p baseline current)
                       (and approved-p
                            (%file-snapshot-equal-p approved current)))
             (error '%file-changed-on-disk
                    :path path
                    :snapshot current)))
          ((or (and current
                    (string= (buffer-text buffer)
                             (%file-snapshot-text current)))
               (and approved-p
                    (%file-snapshot-equal-p approved current)))
           (%remember-file-snapshot buffer current))
          (t
           (unless (and (not baseline-known-p)
                        (null current)
                        (not (member buffer
                                     (registered-buffers *editor-session*)
                                     :test #'eq)))
             (error '%file-changed-on-disk
                    :path path
                    :snapshot current))))
        current))))
  (defun %buffer-output-octets (buffer baseline)
  (let* ((text (buffer-text buffer))
         (format (and baseline (%file-snapshot-format baseline))))
    (if (and baseline
             (%file-snapshot-raw-octets baseline)
             (string= text (%file-snapshot-text baseline)))
        (copy-seq (%file-snapshot-raw-octets baseline))
        (%encode-file-text
         text
         (or format
             (%make-file-format :encoding :utf-8
                                :newline :lf
                                :mixed-newlines-p nil
                                :bom-p nil))))))
  (defmethod buffer-save (buffer)
    (let ((path (buffer-path buffer)))
      (unless path
        (error "buffer-save: buffer ~A has no associated path"
               (buffer-name buffer)))
      (when (buffer-read-only-p buffer)
        (error 'buffer-read-only-error :buffer buffer))
      (%assert-file-save-current buffer path)
      (run-session-hooks :before-save *editor-session* buffer)
      (%assert-file-save-current buffer path)
      (let* ((baseline (%file-buffer-snapshot buffer))
             (native-p (%native-file-octet-io-p))
             (text (buffer-text buffer))
             (octets (and native-p (%buffer-output-octets buffer baseline)))
             (new-snapshot
               (when native-p
                 (multiple-value-bind (decoded-text format)
                     (%decode-file-octets octets)
                   (declare (ignore decoded-text))
                   (%make-file-snapshot
                    :raw-octets (copy-seq octets)
                    :text (copy-seq text)
                    :format format))))
             (real-existing-p
               (and (eq *loom-filesystem* *loom-real-filesystem*)
                    (%file-path-exists-p path))))
        (when real-existing-p
          (%backup-existing-file path))
        (%assert-file-save-current buffer path)
        (if native-p
            (%native-write-file-octets path octets)
            (cl-boundary-kit:filesystem-store-file *loom-filesystem*
                                                   path
                                                   text))
        (%remember-file-snapshot
         buffer
         (if native-p
             new-snapshot
             (%make-file-snapshot :text (copy-seq text))))
        (buffer-mark-saved buffer)
        (run-session-hooks :after-save *editor-session* buffer)
        (let ((minibuffer
                (and *editor-state*
                     (editor-state-minibuffer *editor-state*))))
          (when minibuffer
            (minibuffer-message minibuffer
                                (format nil "Wrote ~A" path)))))
    buffer)))
(progn
  (defun %file-parent-directory (path)
    (host-kit:pathname-directory-pathname (pathname path)))
  (defun %file-parent-directory-exists-p (path)
    (cl-boundary-kit:filesystem-directory-exists-p
     *loom-filesystem*
     (%file-parent-directory path)))
  (defun %ensure-file-parent-directories (path)
    (labels ((ensure-directory (directory)
               (unless (cl-boundary-kit:filesystem-directory-exists-p
                        *loom-filesystem*
                        directory)
                 (let* ((components (pathname-directory directory))
                        (parent
                          (if (<= (length components) 1)
                              directory
                              (make-pathname :directory (butlast components)
                                             :name nil
                                             :type nil
                                             :defaults directory))))
                   (unless (equal parent directory)
                     (ensure-directory parent))
                   (handler-case
                       (cl-boundary-kit:filesystem-make-directory
                        *loom-filesystem*
                        directory)
                     (error (condition)
                       (unless (cl-boundary-kit:filesystem-directory-exists-p
                                *loom-filesystem*
                                directory)
                         (error condition))))))))
      (ensure-directory (%file-parent-directory path)))
    path))
