(in-package #:loom/feature/file-tree)

(defun %file-tree-entry-kind (metadata)
  (case (host-kit:file-metadata-kind metadata)
    (:directory :directory)
    (:regular-file :file)
    (t nil)))

(defun %file-tree-entry< (first second)
  (let ((first-kind (cdr first))
        (second-kind (cdr second)))
    (or (and (eq first-kind :directory)
             (eq second-kind :file))
        (and (eq first-kind second-kind)
             (string< (namestring (car first))
                      (namestring (car second)))))))

(defun %collect-file-tree-entries (path)
  (let ((entries '()))
    (host-kit:call-with-directory-entries
     (lambda (child-path metadata)
       (let ((kind (%file-tree-entry-kind metadata)))
         (when kind
           (push (cons child-path kind) entries))))
     path)
    (nreverse entries)))

(defun loom-fs-list-directory (path)
  "Return the direct children of the directory at PATH as a list of
(CHILD-PATH . KIND) conses, where CHILD-PATH is an absolute pathname (as
yielded by CL-HOST-KIT:CALL-WITH-DIRECTORY-ENTRIES) and KIND is :DIRECTORY or
:FILE. Directories sort before files; within each group, entries sort
alphabetically by their namestrings. Symbolic links and other special entries
are omitted."
  (sort (%collect-file-tree-entries path) #'%file-tree-entry<))
