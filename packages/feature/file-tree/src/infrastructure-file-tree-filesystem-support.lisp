
(in-package #:loom/feature/file-tree)

(defun %file-tree-canonical-pathname (path)
  (let ((pathname (pathname path)))
    (host-kit:truenamize
     #+sbcl (if (wild-pathname-p pathname)
                (sb-ext:parse-native-namestring (namestring pathname))
                pathname)
     #-sbcl pathname)))

(defun %file-tree-pathname-within-root-p (root path)
  (let ((root-directory (pathname-directory root))
        (path-directory (pathname-directory path)))
    (and (equal (pathname-host root) (pathname-host path))
         (equal (pathname-device root) (pathname-device path))
         (<= (length root-directory) (length path-directory))
         (loop for root-part in root-directory
               for path-part in path-directory
               always (equal root-part path-part)))))

(defun %file-tree-assert-native-path-within-root (tree path &key allow-root)
  (when (and (eq *loom-filesystem* *loom-real-filesystem*)
             (typep tree 'file-tree))
    (let* ((root (%file-tree-canonical-pathname
                  (host-kit:ensure-directory-pathname
                   (file-tree-root-path tree))))
           (target (%file-tree-canonical-pathname path)))
      (unless (and (%file-tree-pathname-within-root-p root target)
                   (or allow-root (not (equal root target))))
        (error "File-tree path escapes root ~A: ~A"
               (file-tree-root-path tree) path)))))

(defmacro %dispatch-native-path-operation ((&rest paths)
                                           native-form
                                           boundary-form)
  `(if (%native-path-operation-p ,@paths)
       ,native-form
       ,boundary-form))
