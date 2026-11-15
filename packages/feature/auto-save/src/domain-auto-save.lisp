(in-package #:loom/feature/auto-save)

(defun auto-save-path (path)
  "Return the sidecar pathname used to auto-save PATH.

The name follows the conventional editor form, wrapping the complete file
  name in hash characters (for example, foo.lisp becomes #foo.lisp#)."
  (when path
    (let* ((native-pathname (literal-file-path (pathname path)))
           (parent (make-pathname :name nil :type nil :version nil
                                  :defaults native-pathname))
           (parent-namestring (native-path-namestring parent))
           (file-name (subseq (native-path-namestring native-pathname)
                              (length parent-namestring))))
      (pathname
       (literal-file-path (format nil "~A#~A#" parent-namestring file-name))))))

(defun auto-save-eligible-p (buffer)
  "Return true when BUFFER may be written to an auto-save sidecar."
  (and (buffer-p buffer)
       (buffer-path buffer)
       (buffer-modified-p buffer)
       (not (buffer-read-only-p buffer))))
