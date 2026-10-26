(in-package #:loom/feature/files)

(defun %load-file-buffer (path &key (name (file-namestring path)))
  (let ((content
         (if (%native-path-operation-p path)
             (%native-read-file path)
             (cl-boundary-kit:filesystem-read-file *loom-filesystem* path))))
    (let ((buffer
           (make-buffer :name
                        name
                        :path
                        path
                        :initial-content
                        content)))
      (buffer-set-major-mode buffer
                             (loom/feature/mode:major-mode-for-path path))
      (when
          (and (eq *loom-filesystem* *loom-real-filesystem*)
               (not
                (if (%native-path-operation-p path)
                    (%native-file-writable-p path)
                    (host-kit:file-writable-p path))))
        (buffer-set-read-only buffer t))
      buffer)))

(defmethod buffer-load (path)
  (%load-file-buffer path))

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
(defmethod buffer-save (buffer)
  (let ((path (buffer-path buffer)))
    (unless path
      (error "buffer-save: buffer ~A has no associated path"
             (buffer-name buffer)))
    (when (buffer-read-only-p buffer)
      (error 'buffer-read-only-error :buffer buffer))
    (run-session-hooks :before-save *editor-session* buffer)
    (when (and (eq *loom-filesystem* *loom-real-filesystem*)
               (if (%native-path-operation-p path)
                   (%native-path-exists-p path)
                   (probe-file path)))
      (%backup-existing-file path))
    (if (%native-path-operation-p path)
        (%native-write-file path (buffer-text buffer))
        (cl-boundary-kit:filesystem-store-file *loom-filesystem*
                                               path
                                               (buffer-text buffer)))
    (buffer-mark-saved buffer)
    (run-session-hooks :after-save *editor-session* buffer)
    (let ((minibuffer
            (and *editor-state*
                 (editor-state-minibuffer *editor-state*))))
      (when minibuffer
        (minibuffer-message minibuffer
                            (format nil "Wrote ~A" path)))))
  buffer)
