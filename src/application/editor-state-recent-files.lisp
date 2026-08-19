;;;; src/application/editor-state-recent-files.lisp
;;;;
;;;; Recent-file normalization and list maintenance for EDITOR-STATE.
(in-package #:loom)

(defun editor-path-string (path)
  "Return a stable string representation of PATH when it is available."
  (when path
    (let ((path-object (pathname path)))
      (namestring (or (ignore-errors (truename path-object))
                      path-object)))))

(defun remember-recent-file (path)
  "Put PATH at the front of the editor's recent-file list."
  (let ((path-string (editor-path-string path)))
    (when (and *editor-state*
               path-string
               (plusp (length path-string)))
      (let ((files (cons path-string
                         (remove path-string
                                 (editor-state-recent-files *editor-state*)
                                 :test #'string=))))
        (setf (editor-state-recent-files *editor-state*)
              (subseq files
                      0
                      (min *editor-recent-file-limit*
                           (length files))))))
    path-string))
