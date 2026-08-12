;;;; packages/feature/file-tree/src/infrastructure-filesystem-native-paths.lisp
;;;;
;;;; Native pathname detection and metadata helpers for SBCL-specific file-tree
;;;; filesystem operations.
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
