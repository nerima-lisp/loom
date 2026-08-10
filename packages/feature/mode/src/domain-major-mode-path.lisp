;;;; packages/feature/mode/src/domain-major-mode-path.lisp
;;;;
;;;; Pure path-to-major-mode inference.  The mode registry and metadata stay
;;;; in DOMAIN-MAJOR-MODE; this file contains only the path normalization and
;;;; extension/filename matching used by file-opening features.
(in-package #:loom/feature/mode)

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

(defun major-mode-for-path (path)
  "Infer a major mode from PATH without accessing the file system."
  (let* ((basename (string-downcase (%major-mode-basename path)))
         (extension (%major-mode-extension basename)))
    (cond
      ((loop for key in *registered-major-mode-order*
             for definition = (%dynamic-major-mode-definition key)
             when (or (member basename (getf definition :filenames)
                              :test #'string=)
                      (and extension
                           (member extension (getf definition :extensions)
                                   :test #'string=)))
               return key))
      ((and extension
            (member extension '("lisp" "lsp" "cl") :test #'string=))
       :common-lisp)
      ((and extension (string= extension "py")) :python)
      ((and extension (string= extension "rs")) :rust)
      ((and extension
            (member extension '("sh" "bash" "zsh") :test #'string=))
       :shell)
      ((and extension
            (member extension '("md" "markdown") :test #'string=))
       :markdown)
      ((and extension (string= extension "json")) :json)
      ((and extension (string= extension "txt")) :text)
      ((member basename '("dockerfile" "makefile") :test #'string=) :shell)
      ((member basename '("readme" "license" "copying") :test #'string=)
       :text)
      (t :fundamental))))
