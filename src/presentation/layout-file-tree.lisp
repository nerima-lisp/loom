(in-package #:loom)

(defun %layout-pathname-native-label (pathname)
  ;; Non-wild components hold the literal name; NAMESTRING would escape
  ;; * ? [ and \ in it. Wild (legacy-parsed) components return NIL.
  (let ((name (pathname-name pathname))
        (type (pathname-type pathname))
        (last-directory (car (last (pathname-directory pathname)))))
    (cond ((and (stringp name) (or (null type) (stringp type)))
           (if type (concatenate 'string name "." type) name))
          ((and (null name) (null type) (stringp last-directory))
           last-directory))))

(defun %layout-path-label (path)
  "Return PATH's last path component (file or directory name) for display in
the file-tree sidebar, e.g. a pathname printing as \"/root/sub/\" becomes
\"sub\" and \"/root/a.txt\" becomes \"a.txt\". Works for both real pathnames
(as LOOM-FS-LIST-DIRECTORY returns) and the plain path strings the test
child-lister uses, since both print to a slash-delimited
string via NAMESTRING/identity."
  (or (and (pathnamep path) (%layout-pathname-native-label path))
      (let* ((full (if (stringp path) path (namestring path)))
             (trimmed (string-right-trim "/" full))
             (slash (position #\/ trimmed :from-end t)))
        (if slash (subseq trimmed (1+ slash)) trimmed))))

(defun %layout-file-tree-row (path depth selected width)
  (let* ((indent (make-string (* 2 depth) :initial-element #\Space))
         (text (concatenate 'string indent (%layout-path-label path))))
    (values (%layout-truncate-to-width text width)
            (when (equal path selected) '(:reverse)))))

(defun %layout-draw-file-tree (renderer file-tree width height)
  "Draw the single entry prefix returned by viewport preparation."
  (let ((entries (loom/feature/file-tree:file-tree-prepare-viewport
                  file-tree width height)))
    (when (plusp width)
      (let ((top (loom/feature/file-tree:file-tree-scroll-top file-tree))
            (selected (loom/feature/file-tree:file-tree-selected-path file-tree)))
        (loop for (path . depth) in (nthcdr top entries)
              for row from 0 below height
              do (multiple-value-bind (visible style)
                     (%layout-file-tree-row path depth selected width)
                   (loom-renderer-write-string renderer 0 row visible :style style)))))))
