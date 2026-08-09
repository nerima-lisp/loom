;;;; packages/feature/project/src/infrastructure-project-filesystem.lisp
;;;;
;;;; File-system adapters for the pure project domain.
(in-package #:loom/feature/project)

(defun project-find-root (path)
  "Find PATH's nearest ancestor containing a project marker."
  (project-root-for-path
   path
   (lambda (directory)
     (some (lambda (marker)
             (probe-file (merge-pathnames marker directory)))
           (project-marker-names)))))

(defun %project-last-path-component (path)
  (let* ((text (string-right-trim '(#\/ #\\) (namestring path)))
         (slash (position #\/ text :from-end t))
         (backslash (position #\\ text :from-end t))
         (separator (cond ((and slash backslash) (max slash backslash))
                          (slash slash)
                          (backslash backslash)
                          (t nil))))
    (string-downcase (if separator
                        (subseq text (1+ separator))
                        text))))

(defun %project-ignored-directory-p (path)
  (member (%project-last-path-component path)
          (project-ignored-directory-names)
          :test #'string=))

(defun project-list-files (root)
  "Return regular files below ROOT, excluding generated/vendor directories."
  (labels ((walk (directory)
             (loop for entry in
                   (loom/feature/file-tree:loom-fs-list-directory directory)
                   for path = (car entry)
                   for kind = (cdr entry)
                   append (cond
                            ((eq kind :file) (list path))
                            ((and (eq kind :directory)
                                  (not (%project-ignored-directory-p path)))
                             (walk path))
                            (t nil)))))
    (sort (walk (project-directory-path root)) #'string< :key #'namestring)))

(defun project-search-files (root query)
  "Search text files below ROOT and return path/match plist entries."
  (loop for path in (project-list-files root)
        for matches = (ignore-errors
                        (project-search-lines query
                                              (buffer-text (buffer-load path))))
        when matches
          collect (list :path path :matches matches)))
