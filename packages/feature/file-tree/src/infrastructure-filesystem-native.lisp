;;;; packages/feature/file-tree/src/infrastructure-filesystem-native.lisp
;;;;
;;;; Infrastructure adapter for literal SBCL pathnames. The normal filesystem
;;;; path is CL-BOUNDARY-KIT; these helpers are only used when SBCL would parse
;;;; a literal namestring as a wildcard, or when recursive deletion must be
;;;; symlink-safe.
(in-package #:loom/feature/file-tree)

(defparameter *loom-real-filesystem* (cl-boundary-kit:make-filesystem))

(defparameter *loom-filesystem* *loom-real-filesystem*
  "The CL-BOUNDARY-KIT filesystem boundary used by disk-touching operations.
Tests rebind this to CL-BOUNDARY-KIT:MAKE-TEST-FILESYSTEM's in-memory fake.")

(defun %native-path-operation-p (&rest paths)
  #+sbcl
  (and (eq *loom-filesystem* *loom-real-filesystem*)
       (some (lambda (path)
               (wild-pathname-p (pathname path)))
             paths))
  #-sbcl
  nil)

(defun %native-namestring (path)
  #+sbcl
  (sb-ext:native-namestring
   (sb-ext:parse-native-namestring (namestring (pathname path))))
  #-sbcl
  (namestring (pathname path)))

(defun %native-path-exists-p (path)
  #+sbcl
  (not (null (ignore-errors (sb-posix:lstat (%native-namestring path)))))
  #-sbcl
  nil)

(defun %native-file-writable-p (path)
  #+sbcl
  (not (null
        (ignore-errors
          (zerop (sb-posix:access (%native-namestring path) sb-posix:w-ok)))))
  #-sbcl
  nil)

#+sbcl
(defun %native-create-file (path)
  (let ((fd (sb-posix:open (%native-namestring path)
                           (logior sb-posix:o-wronly
                                   sb-posix:o-creat
                                   sb-posix:o-excl)
                           #o666)))
    (unwind-protect
         (progn
           (sb-posix:close fd)
           (setf fd nil)
           path)
      (when fd
        (ignore-errors (sb-posix:close fd))))))

#+sbcl
(defun %native-directory-prefixes (native-path)
  (let ((prefixes nil)
        (start 0)
        (size (length native-path)))
    (loop
      for separator = (position #\/ native-path :start start)
      for end = (or separator size)
      do (when (> end start)
           (push (subseq native-path 0 (if separator (1+ end) end))
                 prefixes))
         (if separator
             (setf start (1+ separator))
             (return (nreverse prefixes))))))

#+sbcl
(defun %native-directory-p (native-path)
  (let ((stat (ignore-errors (sb-posix:stat native-path))))
    (and stat
         (sb-posix:s-isdir (sb-posix:stat-mode stat)))))

#+sbcl
(defun %native-mkdir (native-path)
  (sb-posix:mkdir native-path #o777))

#+sbcl
(defun %native-make-directory (path)
  (let* ((prefixes (%native-directory-prefixes (%native-namestring path)))
         (target (car (last prefixes))))
    (dolist (prefix (butlast prefixes))
      (unless (%native-directory-p prefix)
        (handler-case
            (%native-mkdir prefix)
          (error (condition)
            (unless (%native-directory-p prefix)
              (error condition))))))
    (when target
      (%native-mkdir target)))
  path)

#+sbcl
(defun %native-rename (old-path new-path)
  (sb-posix:rename (%native-namestring old-path)
                   (%native-namestring new-path))
  new-path)

#+sbcl
(defun %native-read-file (path)
  (let ((fd (sb-posix:open (%native-namestring path) sb-posix:o-rdonly)))
    (unwind-protect
         (let ((stream (sb-sys:make-fd-stream fd
                                              :input t
                                              :element-type 'character
                                              :external-format :utf-8)))
           (setf fd nil)
           (unwind-protect
                (let ((chunk (make-string 4096))
                      (output (make-string-output-stream)))
                  (loop for count = (read-sequence chunk stream)
                        while (plusp count)
                        do (write-string chunk output :end count))
                  (get-output-stream-string output))
             (close stream)))
      (when fd
        (ignore-errors (sb-posix:close fd))))))

#+sbcl
(defun %native-write-file (path content)
  (let ((fd (sb-posix:open (%native-namestring path)
                           (logior sb-posix:o-wronly
                                   sb-posix:o-creat
                                   sb-posix:o-trunc)
                           #o666)))
    (unwind-protect
         (let ((stream (sb-sys:make-fd-stream fd
                                              :output t
                                              :element-type 'character
                                              :external-format :utf-8)))
           (setf fd nil)
           (unwind-protect
                (progn
                  (write-string content stream)
                  (finish-output stream))
             (close stream)))
      (when fd
        (ignore-errors (sb-posix:close fd))))))

#+sbcl
(defun %native-child-namestring (directory name)
  (cond
    ((zerop (length directory))
     name)
    ((char= (char directory (1- (length directory))) #\/)
     (concatenate 'string directory name))
    (t
     (format nil "~A/~A" directory name))))

#+sbcl
(defun %native-delete-path (path)
  ;; An explicit stack keeps deletion safe for deep trees without depending on
  ;; the Lisp call stack, while LSTAT makes symlinks leaf entries.
  (let ((stack (list (cons (%native-namestring path) nil))))
    (loop while stack
          for item = (pop stack)
          for native = (car item)
          do (if (cdr item)
                 (sb-posix:rmdir native)
                 (let ((mode (sb-posix:stat-mode (sb-posix:lstat native))))
                   (if (sb-posix:s-isdir mode)
                       (progn
                         (push (cons native t) stack)
                         (let ((directory (sb-posix:opendir native)))
                           (unwind-protect
                                (loop for entry = (sb-posix:readdir directory)
                                      until (or (null entry)
                                                (sb-alien:null-alien entry))
                                      for name = (sb-posix:dirent-name entry)
                                      unless (member name '("." "..")
                                                     :test #'string=)
                                        do (push (cons
                                                  (%native-child-namestring
                                                   native name)
                                                  nil)
                                                  stack))
                             (sb-posix:closedir directory))))
                       (sb-posix:unlink native)))))
  path))
