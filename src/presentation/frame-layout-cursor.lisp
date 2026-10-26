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
      (cl-tty-kit:make-cursor
       :x (min column (max 0 (1- width)))
       :y (%layout-minibuffer-row (loom-renderer-height renderer))))))

(defun %truncated-cell (renderer window buffer line column)
  "Return LINE/COLUMN's cell and row inside a one-row-per-line window."
  (multiple-value-bind (text mapping)
      (%layout-buffer-line-display buffer line)
    (values (- (%layout-screen-column
                renderer text
                (aref mapping (min (max column 0) (1- (length mapping)))))
               (loom/core/window-tree:window-scroll-column window))
            (- line (loom/core/window-tree:window-scroll-line window)))))

(defun %wrapped-cell (renderer window buffer width line column)
  "Return LINE/COLUMN's (COLUMN ROW) inside a window that wraps long lines.

The row is counted from the window's own (line, segment) origin, which
%LAYOUT-KEEP-WRAPPED-POINT-VISIBLE has already moved to keep point on screen;
the walk is therefore bounded by the window height."
  (multiple-value-bind (text mapping)
      (%layout-buffer-line-display buffer line)
    (let* ((display-column
             (aref mapping (min (max column 0) (1- (length mapping)))))
           (segments (loom-renderer-wrap-segments renderer text width))
           (index (%loom-segment-index segments display-column))
           (segment (nth index segments)))
      (values (loom-renderer-segment-cells
               renderer text segment display-column)
              (or (%layout-rows-between
                   renderer buffer width
                   (loom/core/window-tree:window-scroll-line window)
                   (loom/core/window-tree:window-scroll-sub-row window)
                   line index
                   (%layout-window-content-height window))
                  0)))))

(defun %layout-buffer-cell (renderer window buffer line column)
  "Return LINE/COLUMN's (COLUMN, ROW) within WINDOW's text body.

The completion popup and cursor both use this geometry so they stay anchored to
the same body cells."
  (let* ((window-width (loom/core/window-tree:window-width window))
         (gutter-width (%layout-window-gutter-width buffer window-width))
         (body-width (- window-width gutter-width)))
    (multiple-value-bind (column row)
        (if (loom/core/editor-session:buffer-truncate-lines-p *editor-state* buffer)
            (%truncated-cell renderer window buffer line column)
            (%wrapped-cell renderer window buffer body-width line column))
      (values column row gutter-width))))

(defun %window-cursor-position (renderer window x-offset)
  (let* ((buffer (loom/core/window-tree:window-buffer window))
         (line (buffer-visible-point-line buffer))
         (column (buffer-visible-point-column buffer))
         (window-x (loom/core/window-tree:window-x window)))
    (multiple-value-bind (screen-column screen-row gutter-width)
        (%layout-buffer-cell renderer window buffer line column)
      (values (min (+ x-offset window-x gutter-width screen-column)
                   (+ x-offset window-x
                      (1- (loom/core/window-tree:window-width window))))
              (+ (loom/core/window-tree:window-y window) screen-row)))))

(defun %selected-window-cursor-geometry (renderer window x-offset)
  "Return the selected window cursor position, or NIL when it has no area."
  (let ((width (loom/core/window-tree:window-width window))
        (height (%layout-window-content-height window)))
    (unless (or (zerop width) (zerop height))
      (%window-cursor-position renderer window x-offset))))

(defun %selected-window-cursor (renderer window x-offset)
  "Return the cursor for WINDOW, offset by the file-tree width X-OFFSET."
  (multiple-value-bind (x y)
      (%selected-window-cursor-geometry renderer window x-offset)
    (if (and x y)
        (cl-tty-kit:make-cursor :x x :y y)
        (cl-tty-kit:make-cursor :visible nil))))

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
         (window (loom/core/window-tree:window-tree-selected-window
                  (editor-state-window-tree editor-state))))
    (or (and minibuffer (%minibuffer-cursor renderer minibuffer))
        (%selected-window-cursor renderer window x-offset))))
