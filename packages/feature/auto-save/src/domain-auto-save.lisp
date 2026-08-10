(in-package #:loom/feature/auto-save)

(defun auto-save-path (path)
  "Return the sidecar pathname used to auto-save PATH.

The name follows the conventional editor form, wrapping the complete file
  name in hash characters (for example, foo.lisp becomes #foo.lisp#)."
  (when path
    (let* ((pathname (pathname path))
           (directory (make-pathname
                       :directory (pathname-directory pathname)
                       :name nil
                       :type nil
                       :version nil
                       :defaults pathname))
           (file-name (format nil "#~A#" (file-namestring pathname))))
      ;; Parse the complete sidecar name before merging it with the original
      ;; directory.  Supplying the dotted file name as MAKE-PATHNAME's NAME
      ;; component would make implementations escape the dot.
      (merge-pathnames (parse-namestring file-name) directory))))

(defun auto-save-eligible-p (buffer)
  "Return true when BUFFER may be written to an auto-save sidecar."
  (and (buffer-p buffer)
       (buffer-path buffer)
       (buffer-modified-p buffer)
       (not (buffer-read-only-p buffer))))
