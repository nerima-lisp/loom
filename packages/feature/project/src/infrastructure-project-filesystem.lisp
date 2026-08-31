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

(defun %project-walk-files-cps (directory on-file on-complete)
  (labels ((walk-entries (entries)
             (if (null entries)
                 (funcall on-complete)
                 (destructuring-bind (path . kind) (first entries)
                   (cond
                     ((eq kind :file)
                      (funcall on-file path)
                      (walk-entries (rest entries)))
                     ((and (eq kind :directory)
                           (not (%project-ignored-directory-p path)))
                      (%project-walk-files-cps
                       path
                       on-file
                       (lambda ()
                         (walk-entries (rest entries)))))
                     (t
                      (walk-entries (rest entries))))))))
    (walk-entries
     (loom/feature/file-tree:loom-fs-list-directory directory))))

(defun project-list-files (root)
  "Return regular files below ROOT, excluding generated/vendor directories."
  (let ((files nil))
    (%project-walk-files-cps
     (project-directory-path root)
     (lambda (path) (push path files))
     (lambda () nil))
    (sort files #'string< :key #'namestring)))

(defun project-search-files (root query)
  "Search text files below ROOT and return path/match plist entries."
  (loop for path in (project-list-files root)
        for matches = (ignore-errors
                        (project-search-lines query
                                              (buffer-text (buffer-load path))))
        when matches
          collect (list :path path :matches matches)))
