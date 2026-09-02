;;;; packages/feature/project/src/domain-project.lisp
;;;;
;;;; Pure project boundaries, path rules, and search result shaping.
(in-package #:loom/feature/project)

(defparameter +project-marker-names+
  '(".git" "flake.nix" "Cargo.toml" "package.json" "pyproject.toml"
    "Makefile" ".projectile")
  "Files or directories that identify a project root.")

(defparameter +project-ignored-directory-names+
  '(".git" "node_modules" "target" ".direnv" ".loom")
  "Directories omitted from project file traversal.")

(defun project-marker-names ()
  (copy-list +project-marker-names+))

(defun project-ignored-directory-names ()
  (copy-list +project-ignored-directory-names+))

(defun project-marker-name-p (name)
  "Return true when NAME is one of the configured project markers."
  (member (string-downcase (princ-to-string name))
          +project-marker-names+
          :test #'string=))

(defun project-directory-path (path)
  "Return PATH as a directory pathname, dropping a file component if any."
  (let ((pathname (pathname path)))
    (if (pathname-name pathname)
        (make-pathname :name nil :type nil :version nil :defaults pathname)
        pathname)))

(defun project-parent-directory (directory)
  "Return DIRECTORY's parent, or NIL at a pathname root."
  (let* ((pathname (project-directory-path directory))
         (parts (pathname-directory pathname)))
    (cond
      ((null parts) nil)
      ((and (= (length parts) 1)
            (member (first parts) '(:absolute :relative)))
       nil)
      (t
       (make-pathname :directory (butlast parts)
                      :name nil
                      :type nil
                      :version nil
                      :defaults pathname)))))

(defun project-root-for-path (path marker-p)
  "Walk upward from PATH until MARKER-P accepts a directory."
  (let ((current (project-directory-path path)))
    (loop
      (when (funcall marker-p current)
        (return current))
      (let ((parent (project-parent-directory current)))
        (when (or (null parent) (equal parent current))
          (return))
        (setf current parent)))))

(defun project-relative-path (root path)
  "Return PATH relative to ROOT, with a stable slash-free prefix."
  (let ((relative (enough-namestring (pathname path)
                                    (project-directory-path root))))
    (if (and (>= (length relative) 2)
             (char= (char relative 0) #\.)
             (char= (char relative 1) #\/))
        (subseq relative 2)
        relative)))

(defun project-search-lines (query content)
  "Return plist entries for case-sensitive QUERY matches in CONTENT."
  (when (string/= query "")
    (with-input-from-string (stream content)
      (loop with line-number = 0
            for line = (read-line stream nil nil)
            while line
            do (incf line-number)
            when (search query line)
              collect (list :line line-number :text line)))))
