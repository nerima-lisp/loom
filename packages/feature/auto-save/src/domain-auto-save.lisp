(in-package #:loom/feature/auto-save)

(defun auto-save-path (path)
  "Return the sidecar pathname used to auto-save PATH.

The name follows the conventional editor form, wrapping the complete file
  name in hash characters (for example, foo.lisp becomes #foo.lisp#)."
  (when path
    (let* ((source-pathname (pathname path))
           (native-pathname
            (if (wild-pathname-p source-pathname)
                (uiop:parse-native-namestring (namestring source-pathname))
                source-pathname))
           (directory
            (make-pathname :directory
                           (pathname-directory native-pathname)
                           :name
                           nil
                           :type
                           nil
                           :version
                           nil
                           :defaults
                           native-pathname))
           (native-namestring (uiop:native-namestring native-pathname))
           (directory-namestring (uiop:native-namestring directory))
           (file-name
            (format nil
                    "#~A#"
                    (subseq native-namestring (length directory-namestring)))))
      (uiop:parse-native-namestring
       (format nil "~A~A" directory-namestring file-name)))))

(defun auto-save-eligible-p (buffer)
  "Return true when BUFFER may be written to an auto-save sidecar."
  (and (buffer-p buffer)
       (buffer-path buffer)
       (buffer-modified-p buffer)
       (not (buffer-read-only-p buffer))))
