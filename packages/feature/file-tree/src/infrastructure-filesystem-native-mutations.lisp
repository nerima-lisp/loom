;;;; packages/feature/file-tree/src/infrastructure-filesystem-native-mutations.lisp
;;;;
;;;; Native SBCL filesystem mutations for file-tree path creation and rename.
(in-package #:loom/feature/file-tree)

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
