;;;; packages/feature/mode/src/domain-major-mode-path.lisp
;;;;
;;;; Pure path-to-major-mode inference.  The mode registry and metadata stay
;;;; in DOMAIN-MAJOR-MODE; this file contains only the path normalization and
;;;; extension/filename matching used by file-opening features.
(in-package #:loom/feature/mode)

(defparameter *major-mode-path-rules*
  '((:common-lisp :extensions ("lisp" "lsp" "cl"))
    (:emacs-lisp :extensions ("el"))
    (:python :extensions ("py"))
    (:rust :extensions ("rs"))
    (:nix :extensions ("nix"))
    (:typescript-react :extensions ("tsx"))
    (:typescript :extensions ("ts" "mts" "cts"))
    (:shell :extensions ("sh" "bash" "zsh")
             :filenames ("dockerfile" "makefile"))
    (:markdown :extensions ("md" "markdown"))
    (:org :extensions ("org"))
    (:json :extensions ("json"))
    (:text :extensions ("txt")
           :filenames ("readme" "license" "copying")))
  "Built-in path rules, ordered from most specific to least specific.")

(defun %major-mode-path-text (path)
  (typecase path
    (string path)
    (pathname (namestring path))
    (t (princ-to-string path))))

(defun %major-mode-basename (path)
  (let* ((text (string-right-trim '(#\/ #\\) (%major-mode-path-text path)))
         (slash (position #\/ text :from-end t))
         (backslash (position #\\ text :from-end t))
         (separator (cond ((and slash backslash) (max slash backslash))
                          (slash slash)
                          (backslash backslash)
                          (t nil))))
    (if separator
        (subseq text (1+ separator))
        text)))

(defun %major-mode-extension (basename)
  (let ((dot (position #\. basename :from-end t)))
    (and dot
         (< (1+ dot) (length basename))
         (string-downcase (subseq basename (1+ dot))))))

(defun %major-mode-registered-for-path (basename extension)
  (loop for key in *registered-major-mode-order*
        for definition = (%dynamic-major-mode-definition key)
        when (or (member basename (getf definition :filenames)
                         :test #'string=)
                 (and extension
                      (member extension (getf definition :extensions)
                              :test #'string=)))
          return key))

(defun %major-mode-built-in-for-path (basename extension)
  (loop for (mode . options) in *major-mode-path-rules*
        when (or (member basename (getf options :filenames)
                         :test #'string=)
                 (and extension
                      (member extension (getf options :extensions)
                              :test #'string=)))
          return mode))

(defun major-mode-for-path (path)
  "Infer a major mode from PATH without accessing the file system."
  (let* ((basename (string-downcase (%major-mode-basename path)))
         (extension (%major-mode-extension basename)))
    (or (%major-mode-registered-for-path basename extension)
        (%major-mode-built-in-for-path basename extension)
        :fundamental)))
