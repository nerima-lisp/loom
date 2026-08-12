;;;; t/unit/filesystem-test-support.lisp
;;;;
;;;; Shared fixtures for filesystem boundary tests.
(in-package #:loom/test)

(defun %fake-path (name)
  "Return NAME under the in-memory fake's root.
The fake keys its entries by pathname, so every reference to one file has to
merge against the same root to land on the same entry."
  (merge-pathnames name #P"/loom-fake/"))

(defmacro with-fake-filesystem (&body body)
  "Run BODY with the file-tree filesystem bound to a fresh in-memory filesystem."
  `(let ((loom/feature/file-tree::*loom-filesystem*
           (cl-boundary-kit:make-test-filesystem)))
     ,@body))

(defmacro %with-fake-paths ((&rest bindings) &body body)
  `(let ,(loop for (name relative-path) in bindings
               collect `(,name (%fake-path ,relative-path)))
     ,@body))

(defmacro %with-real-paths ((root &rest bindings) &body body)
  `(let ,(loop for (name relative-path) in bindings
               collect `(,name (merge-pathnames ,relative-path ,root)))
     ,@body))

(defmacro %with-fake-files ((&rest bindings) &body body)
  `(progn
     ,@(loop for (path content) in bindings
             collect `(%fake-write ,path ,content))
     ,@body))

(defmacro %with-real-files ((&rest bindings) &body body)
  `(progn
     ,@(loop for (path content) in bindings
             collect `(host-kit:write-file-string ,content ,path))
     ,@body))

(defun %fake-exists-p (path)
  (cl-boundary-kit:filesystem-path-exists-p
   loom/feature/file-tree::*loom-filesystem* path))

(defun %fake-read (path)
  (cl-boundary-kit:filesystem-read-file
   loom/feature/file-tree::*loom-filesystem* path))

(defun %fake-write (path content)
  (cl-boundary-kit:filesystem-store-file
   loom/feature/file-tree::*loom-filesystem* path content))
