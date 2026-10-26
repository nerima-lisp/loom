(in-package #:loom)

(defun %layout-file-tree-width (file-tree-visible-p width)
  "Return the column width the file-tree sidebar occupies in a WIDTH-column
terminal: a 24-column strip when FILE-TREE-VISIBLE-P, narrowed to WIDTH on a
terminal too narrow for it, and 0 when the sidebar is hidden. EDITOR-CURSOR
and %LAYOUT-COMPUTE-REGIONS both need this number and must agree on it, so
neither re-derives the cap."
  (if file-tree-visible-p (min 24 width) 0))

(defun %layout-minibuffer-row (height)
  "Return the screen row the minibuffer occupies in a HEIGHT-row terminal.
EDITOR-CURSOR and %LAYOUT-COMPUTE-REGIONS must agree on it."
  (max 0 (1- height)))
