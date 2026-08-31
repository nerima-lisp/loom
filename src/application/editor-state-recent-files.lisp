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

(defun %bounded-recent-files (path-string files limit)
  "Return PATH-STRING followed by unique FILES, bounded by LIMIT."
  (let ((unique-files (cons path-string
                            (remove path-string files :test #'string=))))
    (subseq unique-files
            0
            (min limit (length unique-files)))))

(defun remember-recent-file (path)
  "Put PATH at the front of the editor's recent-file list."
  (let ((path-string (editor-path-string path)))
    (when (and *editor-state*
               path-string
               (plusp (length path-string)))
      (setf (editor-state-recent-files *editor-state*)
            (%bounded-recent-files
             path-string
             (editor-state-recent-files *editor-state*)
             *editor-recent-file-limit*)))
    path-string))
