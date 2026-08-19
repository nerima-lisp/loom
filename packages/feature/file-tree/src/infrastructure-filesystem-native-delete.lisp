;;;; packages/feature/file-tree/src/infrastructure-filesystem-native-delete.lisp
;;;;
;;;; Native SBCL recursive deletion for file-tree paths, including symlink-safe
;;;; directory traversal.
(in-package #:loom/feature/file-tree)

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
