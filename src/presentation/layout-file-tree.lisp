;;;; src/presentation/layout-file-tree.lisp
;;;;
;;;; Presentation layer: file-tree sidebar rendering helpers. Shared width
;;;; clipping remains in layout.lisp; this file owns only file-tree-specific
;;;; label and row drawing.
(in-package #:loom)

(defun %layout-path-label (path)
  "Return PATH's last path component (file or directory name) for display in
the file-tree sidebar, e.g. a pathname printing as \"/root/sub/\" becomes
\"sub\" and \"/root/a.txt\" becomes \"a.txt\". Works for both real pathnames
(as LOOM-FS-LIST-DIRECTORY returns) and the plain path strings t/file-tree-
test.lisp's fake child-lister uses, since both print to a slash-delimited
string via NAMESTRING/identity."
  (let* ((full (if (stringp path) path (namestring path)))
         (trimmed (string-right-trim "/" full))
         (slash (position #\/ trimmed :from-end t)))
    (if slash (subseq trimmed (1+ slash)) trimmed)))

(defun %layout-file-tree-row (path depth selected width)
  (let* ((indent (make-string (* 2 depth) :initial-element #\Space))
         (text (concatenate 'string indent (%layout-path-label path))))
    (values (%layout-truncate-to-width text width)
            (when (equal path selected) '(:reverse)))))

(defun %layout-draw-file-tree (renderer file-tree width height)
  "Draw FILE-TREE's currently visible entries (FILE-TREE-ENTRIES) into the
left WIDTH-column, HEIGHT-row strip of RENDERER starting at (0,0), one entry
per row, each indented two columns per depth level and truncated to WIDTH
columns. The row whose path is FILE-TREE-SELECTED-PATH is drawn in reverse
video so the current selection is visible. Entries beyond HEIGHT rows are
simply not drawn -- no scrolling is attempted here, matching this file's
\"plain sequential draw\" scope."
  (when (plusp width)
    (let ((entries (loom/feature/file-tree:file-tree-entries file-tree))
          (selected (loom/feature/file-tree:file-tree-selected-path file-tree)))
      (loop for (path . depth) in entries
            for row from 0 below height
            do (multiple-value-bind (visible style)
                   (%layout-file-tree-row path depth selected width)
                 (loom-renderer-write-string renderer 0 row visible :style style))))))
