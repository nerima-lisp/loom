;;;; src/presentation/frame-layout.lisp
;;;;
;;;; Presentation layer: high-level frame composition.  Cursor geometry lives
;;;; in frame-layout-cursor.lisp; layout.lisp owns the lower-level draw
;;;; helpers; this file sequences them against the current editor state and
;;;; renderer dimensions.
(in-package #:loom)

;;; ---------------------------------------------------------------------
;;; Frame composition
;;; ---------------------------------------------------------------------

(defun %layout-follow-truncated-line (window buffer height)
  (when (plusp height)
    (let ((point-line (buffer-visible-point-line buffer))
          (scroll-line (loom/feature/window:window-scroll-line window)))
      (cond
        ((< point-line scroll-line)
         (setf (loom/feature/window:window-scroll-line window) point-line))
        ((>= point-line (+ scroll-line height))
         (setf (loom/feature/window:window-scroll-line window)
               (- point-line (1- height))))))))

(defun %layout-follow-truncated-column (renderer window buffer width)
  (when (plusp width)
    (let ((point-column (%layout-buffer-point-screen-column renderer buffer))
          (scroll-column (loom/feature/window:window-scroll-column window)))
      (cond
        ((< point-column scroll-column)
         (setf (loom/feature/window:window-scroll-column window) point-column))
        ((>= point-column (+ scroll-column width))
         (setf (loom/feature/window:window-scroll-column window)
               (- point-column (1- width))))))))

(defun %layout-keep-truncated-point-visible (renderer window)
  "Follow point in a window that draws one screen row per logical line."
  (let ((height (loom/feature/window:window-height window))
        (width (loom/feature/window:window-width window))
        (buffer (loom/feature/window:window-buffer window)))
    (%layout-follow-truncated-line window buffer height)
    (%layout-follow-truncated-column renderer window buffer width)))

(defun %layout-keep-wrapped-point-visible (renderer window)
  "Follow point in a window that wraps a logical line across several rows.

The viewport is a (line, segment) pair rather than a line. When point is above
it the pair simply becomes point's own; when point is below, the pair is walked
back HEIGHT-1 rows from point instead of forward from the old position, so a
jump to a distant line costs the window's height rather than the jump."
  (let* ((height (loom/feature/window:window-height window))
         (width (loom/feature/window:window-width window))
         (buffer (loom/feature/window:window-buffer window)))
    (when (and (plusp height) (plusp width))
      (setf (loom/feature/window:window-scroll-column window) 0)
      (multiple-value-bind (point-line point-row)
          (%layout-wrapped-point-location renderer buffer width)
        (%layout-follow-wrapped-point
         renderer window buffer width height point-line point-row)))))

(defun %layout-wrapped-point-location (renderer buffer width)
  (let ((line (buffer-visible-point-line buffer)))
    (values line
            (%loom-segment-index
             (%layout-line-segments renderer buffer line width)
             (buffer-visible-point-column buffer)))))

(defun %layout-point-before-viewport-p
    (point-line point-row scroll-line scroll-row)
  (or (< point-line scroll-line)
      (and (= point-line scroll-line) (< point-row scroll-row))))

(defun %layout-point-fits-viewport-p
    (renderer buffer width scroll-line scroll-row point-line point-row height)
  (%layout-rows-between renderer buffer width
                         scroll-line scroll-row point-line point-row
                         (1- height)))

(defun %layout-follow-wrapped-point
    (renderer window buffer width height point-line point-row)
  (let ((scroll-line (loom/feature/window:window-scroll-line window))
        (scroll-row (loom/feature/window:window-scroll-sub-row window)))
    (cond
      ((%layout-point-before-viewport-p
        point-line point-row scroll-line scroll-row)
       (setf (loom/feature/window:window-scroll-line window) point-line
             (loom/feature/window:window-scroll-sub-row window) point-row))
      ((not (%layout-point-fits-viewport-p
             renderer buffer width scroll-line scroll-row
             point-line point-row height))
       (multiple-value-bind (new-line new-row)
           (%layout-row-back renderer buffer width point-line point-row
                             (1- height))
         (setf (loom/feature/window:window-scroll-line window) new-line
               (loom/feature/window:window-scroll-sub-row window) new-row))))))

(defun %layout-keep-point-visible (renderer window)
  "Adjust WINDOW's viewport so its buffer point remains in its rectangle.

Which of the two followers applies is the buffer's own line-display setting,
not the window's: the same buffer in two windows must agree with itself."
  (if (loom/feature/mode:buffer-truncate-lines-p
       (loom/feature/window:window-buffer window))
      (%layout-keep-truncated-point-visible renderer window)
      (%layout-keep-wrapped-point-visible renderer window)))

(defun %layout-compute-regions (width height file-tree-visible-p)
  "Compute the row/column geometry COMPOSE-FRAME draws into, given the
renderer's WIDTH/HEIGHT and whether the file-tree sidebar is visible.
Returns (VALUES CONTENT-HEIGHT MINIBUFFER-ROW SHORTCUTS-ROW
SHORTCUTS-VISIBLE-P FILE-TREE-WIDTH WINDOW-AREA-WIDTH), leaving COMPOSE-FRAME
itself to only sequence the draw calls against them."
  (let* ((shortcuts-visible-p (> height 1))
         (content-height (max 0 (- height (if shortcuts-visible-p 2 1))))
         (minibuffer-row (%layout-minibuffer-row height))
         (shortcuts-row (max 0 (1- minibuffer-row)))
         (file-tree-width (%layout-file-tree-width file-tree-visible-p width))
         (window-area-width (max 0 (- width file-tree-width))))
    (values content-height minibuffer-row shortcuts-row shortcuts-visible-p
            file-tree-width window-area-width)))

(defun compose-frame (editor-state)
  "Compose one full editor frame into EDITOR-STATE's renderer's in-memory
screen: clear it; draw the file-tree sidebar (when FILE-TREE-VISIBLE-P) into
a left, up-to-24-column strip spanning every row above the shortcut and
minibuffer lines;
resize EDITOR-STATE's window tree (WINDOW-TREE-RESIZE) to whatever screen
area remains after that strip and the bottom minibuffer row -- this is the
one place that resize is driven from, so a file-tree visibility toggle or a
terminal resize (see MAIN's polling loop, which only needs to keep the
renderer itself in sync via LOOM-RENDERER-RESIZE) is always reflected by the
very next frame -- draw every leaf window's buffer plus separators between
adjacent leaves into that area; and finally draw the minibuffer's current
prompt/input or status line into the bottom row. A persistent shortcut line
is shown above it whenever the terminal is at least two rows tall. Performs
no I/O beyond mutating the renderer's screen; LOOM-RENDERER-PRESENT is the
caller's job to actually flush that screen to a terminal. Returns
EDITOR-STATE."
  (let* ((renderer (editor-state-renderer editor-state))
         (width (loom-renderer-width renderer))
         (height (loom-renderer-height renderer))
         (file-tree (editor-state-file-tree editor-state))
         (file-tree-visible
           (loom/feature/file-tree:file-tree-visible-p file-tree))
         (window-tree (editor-state-window-tree editor-state))
         (workspace-manager (editor-state-workspaces editor-state))
         (workspace-name
           (and workspace-manager
                (loom/feature/workspace:workspace-manager-current-name
                 workspace-manager))))
    (multiple-value-bind (content-height minibuffer-row shortcuts-row shortcuts-visible-p
                           file-tree-width window-area-width)
        (%layout-compute-regions width height file-tree-visible)
      (loom-renderer-clear renderer)
      (when file-tree-visible
        (%layout-draw-file-tree renderer file-tree file-tree-width content-height))
      (loom/feature/window:window-tree-resize
       window-tree window-area-width content-height)
      (dolist (window (loom/feature/window:window-tree-windows window-tree))
        (%layout-keep-point-visible renderer window))
      (%layout-draw-windows renderer window-tree file-tree-width)
      (when shortcuts-visible-p
        (%layout-draw-shortcuts renderer width shortcuts-row
                                (loom/feature/window:window-buffer
                                 (loom/feature/window:window-tree-selected-window
                                  window-tree))
                                workspace-name))
      (%layout-draw-minibuffer renderer (editor-state-minibuffer editor-state) width minibuffer-row)
      editor-state)))
