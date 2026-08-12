;;;; src/presentation/frame-layout-cursor.lisp
;;;;
;;;; Presentation layer: cursor geometry for the composed frame.  The frame
;;;; composition pass in frame-layout.lisp reuses the file-tree width helper
;;;; from here so cursor placement and region sizing share one sidebar-width
;;;; calculation.
(in-package #:loom)

(defun %layout-file-tree-width (file-tree-visible-p width)
  "Return the column width the file-tree sidebar occupies in a WIDTH-column
terminal: a 24-column strip when FILE-TREE-VISIBLE-P, narrowed to WIDTH on a
terminal too narrow for it, and 0 when the sidebar is hidden. EDITOR-CURSOR
and %LAYOUT-COMPUTE-REGIONS both need this number and must agree on it, so
neither re-derives the cap."
  (if file-tree-visible-p (min 24 width) 0))

(defun editor-cursor (editor-state)
  "Return the terminal cursor for EDITOR-STATE's selected window."
  (let* ((renderer (editor-state-renderer editor-state))
         (file-tree (editor-state-file-tree editor-state))
         (x-offset (%layout-file-tree-width
                    (and file-tree
                         (loom/feature/file-tree:file-tree-visible-p file-tree))
                    (loom-renderer-width renderer)))
         (window (loom/feature/window:window-tree-selected-window
                  (editor-state-window-tree editor-state)))
         (width (loom/feature/window:window-width window))
         (height (loom/feature/window:window-height window)))
    (if (or (zerop width) (zerop height))
        (loom-renderer-make-cursor renderer :visible nil)
        (let ((buffer (loom/feature/window:window-buffer window)))
          (loom-renderer-make-cursor
           renderer
           :x (+ x-offset (loom/feature/window:window-x window)
                 (min (buffer-visible-point-column buffer) (1- width)))
           :y (+ (loom/feature/window:window-y window)
                 (- (buffer-visible-point-line buffer)
                    (loom/feature/window:window-scroll-line window))))))))
