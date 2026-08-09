;;;; packages/feature/project/src/package.lisp
;;;;
;;;; Project discovery and project-scoped file operations share this boundary.
(defpackage #:loom/feature/project
  (:use #:cl #:loom #:loom/application)
  (:export
   ;; Domain API
   #:project-marker-names
   #:project-ignored-directory-names
   #:project-marker-name-p
   #:project-directory-path
   #:project-parent-directory
   #:project-root-for-path
   #:project-relative-path
   #:project-search-lines
   ;; Infrastructure and application API
   #:project-find-root
   #:project-list-files
   #:project-search-files
   #:project-find-file
   #:project-search
   #:project-root))
