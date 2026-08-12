;;;; t/unit/filesystem-directory-test.lisp
;;;;
;;;; Directory creation edge cases and listing tests.
(in-package #:loom/test)

(describe
  "file-tree-create-directory"
  (it
    "recovers when a parent mkdir loses a race to another directory"
    (host-kit:with-temporary-directory (dir)
      (let* ((parent-path (merge-pathnames "race-parent/" dir))
             (target-path (pathname (format nil "~Atarget [race]/"
                                             (namestring parent-path))))
             (native-parent
               (loom/feature/file-tree::%native-namestring parent-path))
             (original-directory-p
               (symbol-function 'loom/feature/file-tree::%native-directory-p))
             (original-mkdir
               (symbol-function 'loom/feature/file-tree::%native-mkdir))
             (parent-checks 0))
        (host-kit:create-directory parent-path)
        (unwind-protect
             (progn
               (with-replaced-function
                   (loom/feature/file-tree::%native-directory-p
                    (lambda (native-path)
                      (if (string= native-path native-parent)
                          (if (= (incf parent-checks) 1)
                              nil
                              (funcall original-directory-p native-path))
                          (funcall original-directory-p native-path))))
                 (with-replaced-function
                     (loom/feature/file-tree::%native-mkdir
                      (lambda (native-path)
                        (if (string= native-path native-parent)
                            (error "simulated parent mkdir race")
                            (funcall original-mkdir native-path))))
                   (expect (file-tree-create-directory nil target-path)
                           :to-equal target-path)))
               (expect parent-checks :to-equal 2)
               (expect (loom/feature/file-tree::%native-directory-p
                        (loom/feature/file-tree::%native-namestring target-path))
                       :to-be-truthy))
          (ignore-errors
            (loom/feature/file-tree::%native-delete-path parent-path))))))

  (it
    "reports a target that appears after its existence check"
    (host-kit:with-temporary-directory (dir)
      (let ((target-path (pathname (format nil "~Atarget [appeared]/"
                                            (namestring dir)))))
        (sb-posix:mkdir
         (loom/feature/file-tree::%native-namestring target-path) #o777)
        (unwind-protect
             (progn
               (with-replaced-function
                   (loom/feature/file-tree::%native-path-exists-p
                    (lambda (path)
                      (declare (ignore path))
                      nil))
                 (signals error
                   (file-tree-create-directory nil target-path)))
               (expect (loom/feature/file-tree::%native-directory-p
                        (loom/feature/file-tree::%native-namestring target-path))
                       :to-be-truthy))
          (ignore-errors
            (loom/feature/file-tree::%native-delete-path target-path))))))

  (it
    "propagates a parent mkdir error when the path is still not a directory"
    (host-kit:with-temporary-directory (dir)
      (let ((target-path (pathname (format nil "~Atarget [error]/"
                                            (namestring dir)))))
        (with-replaced-function
            (loom/feature/file-tree::%native-directory-p
             (lambda (native-path)
               (declare (ignore native-path))
               nil))
          (signals error (file-tree-create-directory nil target-path)))
        (expect (loom/feature/file-tree::%native-path-exists-p target-path)
                :to-be-falsy)))))

#+sbcl
(describe
  "native filesystem path helpers"
  (it
    "joins child names without adding a root slash to an empty directory"
    (expect (loom/feature/file-tree::%native-child-namestring "" "entry.txt")
            :to-equal "entry.txt")
    (expect
     (loom/feature/file-tree::%native-child-namestring "/tmp/" "entry.txt")
     :to-equal "/tmp/entry.txt")
    (expect
     (loom/feature/file-tree::%native-child-namestring "/tmp" "entry.txt")
     :to-equal "/tmp/entry.txt")))
