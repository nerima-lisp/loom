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

(defun %layout-minibuffer-row (height)
  "Return the screen row the minibuffer occupies in a HEIGHT-row terminal.
EDITOR-CURSOR and %LAYOUT-COMPUTE-REGIONS must agree on it."
  (max 0 (1- height)))

(defun %minibuffer-cursor (renderer minibuffer)
  "Return the terminal cursor for an active MINIBUFFER, or NIL when it is not
accepting input.

The minibuffer has no point of its own -- MINIBUFFER-HANDLE-KEY only appends
and backspaces -- so the cursor belongs after the whole prompt-plus-input line
that %LAYOUT-DRAW-MINIBUFFER draws."
  (when (minibuffer-active-p minibuffer)
    (let* ((width (loom-renderer-width renderer))
           (text (%layout-minibuffer-line minibuffer))
           (column (%layout-screen-column renderer text (length text))))
      (loom-renderer-make-cursor
       renderer
       :x (min column (max 0 (1- width)))
       :y (%layout-minibuffer-row (loom-renderer-height renderer))))))

(defun editor-cursor (editor-state)
  "Return the terminal cursor for EDITOR-STATE: the active minibuffer's input
position when a prompt is up, otherwise point in the selected window."
  (let* ((renderer (editor-state-renderer editor-state))
         (minibuffer (editor-state-minibuffer editor-state))
         (file-tree (editor-state-file-tree editor-state))
         (x-offset (%layout-file-tree-width
                    (and file-tree
                         (loom/feature/file-tree:file-tree-visible-p file-tree))
                    (loom-renderer-width renderer)))
         (window (loom/feature/window:window-tree-selected-window
                  (editor-state-window-tree editor-state)))
         (width (loom/feature/window:window-width window))
         (height (loom/feature/window:window-height window)))
    (or (and minibuffer (%minibuffer-cursor renderer minibuffer))
        (if (or (zerop width) (zerop height))
            (loom-renderer-make-cursor renderer :visible nil)
            (let ((buffer (loom/feature/window:window-buffer window)))
              (loom-renderer-make-cursor
               renderer
               :x (+ x-offset (loom/feature/window:window-x window)
                     (min (%layout-buffer-point-screen-column renderer buffer)
                          (1- width)))
               :y (+ (loom/feature/window:window-y window)
                     (- (buffer-visible-point-line buffer)
                        (loom/feature/window:window-scroll-line window)))))))))
