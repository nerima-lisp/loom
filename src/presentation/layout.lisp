;;;; src/presentation/layout.lisp
;;;;
;;;; Presentation layer: screen composition. Given the current EDITOR-STATE,
;;;; COMPOSE-FRAME decides what rectangle each visible thing occupies (the
;;;; file-tree sidebar, the window-tree's leaf buffers plus a minimal
;;;; separator between adjacent leaves, and the bottom minibuffer line) and
;;;; draws it into the renderer's in-memory screen. This is deliberately a
;;;; plain, sequential draw with no compositing beyond "clear, then draw each
;;;; region once" -- infrastructure/terminal-renderer.lisp already owns the
;;;; renderer plumbing and this file owns the layout decisions plus
;;;; presentation styling on top of it.
(in-package #:loom)

;;; ---------------------------------------------------------------------
;;; File-tree sidebar
;;; ---------------------------------------------------------------------

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

(defun %layout-truncate-to-width (text width)
  "Return TEXT clipped to its leading WIDTH characters, or TEXT itself when it
already fits. Every draw helper in this file writes a single row into a
fixed-width region, so each of them clips through here rather than repeating
the SUBSEQ."
  (if (> (length text) width) (subseq text 0 width) text))

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
            do (let* ((indent (make-string (* 2 depth) :initial-element #\Space))
                      (text (concatenate 'string indent (%layout-path-label path)))
                      (visible (%layout-truncate-to-width text width))
                      (style (when (equal path selected) '(:reverse))))
                 (loom-renderer-write-string renderer 0 row visible :style style))))))

;;; ---------------------------------------------------------------------
;;; Window-tree area
;;; ---------------------------------------------------------------------

(defun %layout-draw-multiple-cursors
    (renderer buffer x y width height scroll-line)
  "Draw BUFFER's non-primary transient cursors inside one window rectangle.

The cursor set stores buffer offsets, while the renderer needs a screen cell;
the line text is therefore measured again for each visible cursor.  A reverse
video glyph makes an extra cursor visible without changing the buffer text."
  (when (and (plusp width) (plusp height))
    (dolist (offset
              (loom/feature/multiple-cursors:multiple-cursor-offsets-for-buffer
               buffer))
      (let ((position (buffer-visible-offset-position buffer offset)))
        (when position
          (let* ((line (buffer-position-line position))
                 (column (buffer-position-column position))
                 (row (- line scroll-line)))
            (when (and (>= row 0)
                       (< row height)
                       (< line (buffer-visible-line-count buffer)))
              (let* ((line-text (buffer-visible-line buffer line))
                     (safe-column (min column (length line-text)))
                     (prefix (subseq line-text 0 safe-column))
                     (screen-column (loom-renderer-string-width renderer prefix))
                     (glyph (if (< safe-column (length line-text))
                                (string (char line-text safe-column))
                                " ")))
                (when (and (< screen-column width)
                           (<= (+ screen-column
                                  (loom-renderer-string-width renderer glyph))
                               width))
                  (loom-renderer-write-string
                   renderer (+ x screen-column) (+ y row) glyph
                   :style '(:reverse)))))))))))

(defun %layout-draw-windows (renderer window-tree x-offset)
  "Draw every leaf window in WINDOW-TREE (already laid out by
WINDOW-TREE-RESIZE against the window area's own width/height) via
%LAYOUT-DRAW-BUFFER, each leaf's rect offset horizontally by X-OFFSET
columns -- the width consumed by a visible file-tree sidebar, so a leaf's own
WINDOW-X/WINDOW-Y (relative to the window tree's own origin) land in the
right place on the shared screen. When a split produced more than one leaf, a
 minimal 1-cell separator line is drawn along the shared edge between any two
horizontally- or vertically-adjacent leaves, so a user can tell the panes
apart. Returns RENDERER."
  (let ((leaves (loom/feature/window:window-tree-windows window-tree)))
    (dolist (leaf leaves)
      (loom/feature/syntax-highlighting:syntax-draw-buffer
       renderer (loom/feature/window:window-buffer leaf)
       (+ x-offset (loom/feature/window:window-x leaf))
       (loom/feature/window:window-y leaf)
       (loom/feature/window:window-width leaf)
       (loom/feature/window:window-height leaf)
       :start-line (loom/feature/window:window-scroll-line leaf))
      (%layout-draw-multiple-cursors
       renderer (loom/feature/window:window-buffer leaf)
       (+ x-offset (loom/feature/window:window-x leaf))
       (loom/feature/window:window-y leaf)
       (loom/feature/window:window-width leaf)
       (loom/feature/window:window-height leaf)
       (loom/feature/window:window-scroll-line leaf)))
    (dolist (leaf leaves)
      ;; A leaf whose X is not 0 (relative to the window-tree's own origin)
      ;; has a neighbor immediately to its left from a :VERTICAL split; draw
      ;; a vertical rule just left of this leaf's own left edge.
      (when (and (plusp (loom/feature/window:window-x leaf))
                 (plusp (loom/feature/window:window-height leaf)))
        (loom-renderer-draw-vertical-line
         renderer (1- (+ x-offset (loom/feature/window:window-x leaf)))
         (loom/feature/window:window-y leaf)
         (loom/feature/window:window-height leaf)))
      ;; Likewise, a leaf whose Y is not 0 has a neighbor immediately above it
      ;; from a :HORIZONTAL split; draw a horizontal rule just above it.
      (when (and (plusp (loom/feature/window:window-y leaf))
                 (plusp (loom/feature/window:window-width leaf)))
        (loom-renderer-draw-horizontal-line
         renderer (+ x-offset (loom/feature/window:window-x leaf))
         (1- (loom/feature/window:window-y leaf))
         (loom/feature/window:window-width leaf))))
  renderer))

;;; ---------------------------------------------------------------------
;;; Minibuffer line
;;; ---------------------------------------------------------------------

;;; ---------------------------------------------------------------------
;;; Frame composition
;;; ---------------------------------------------------------------------
(defparameter +layout-shortcut-line+ "C-h Help  C-x C-s Save  C-s Find  C-x C-c Exit")
(defun %layout-draw-shortcuts (renderer width row buffer &optional workspace-name)
  "Draw the persistent command reminder immediately above the minibuffer."
  (when (plusp width)
    (let* ((text (format nil "Ln ~D, Col ~D  ~A"
                         (1+ (buffer-visible-point-line buffer))
                         (1+ (buffer-visible-point-column buffer))
                         (if workspace-name
                             (format nil "Workspace: ~A  ~A"
                                     workspace-name
                                     +layout-shortcut-line+)
                             +layout-shortcut-line+)))
           (visible (%layout-truncate-to-width text width)))
      (loom-renderer-write-string renderer 0 row visible :style '(:reverse)))))
(defun %layout-minibuffer-line (minibuffer)
  "Return the single line of text MINIBUFFER should currently show at the
bottom of the screen: prompt+input while MINIBUFFER-ACTIVE-P, else the last
transient status message set via MINIBUFFER-MESSAGE, else the empty string."
  (cond
    ((minibuffer-active-p minibuffer)
     (concatenate 'string (or (minibuffer-prompt-string minibuffer) "")
                  (minibuffer-input-string minibuffer)))
    ((minibuffer-message-string minibuffer))
    (t "")))
(defun %layout-draw-minibuffer (renderer minibuffer width row)
  "Draw MINIBUFFER's current line (see %LAYOUT-MINIBUFFER-LINE) into RENDERER's
ROW, truncated to WIDTH columns."
  (when (plusp width)
    (let* ((text (%layout-minibuffer-line minibuffer))
           (visible (%layout-truncate-to-width text width)))
      (loom-renderer-write-string renderer 0 row visible))))
(defun %layout-keep-point-visible (window)
  "Adjust WINDOW's viewport so its buffer point remains in its rectangle."
  (let ((height (loom/feature/window:window-height window)))
    (when (plusp height)
      (let ((point-line (buffer-visible-point-line
                         (loom/feature/window:window-buffer window)))
            (scroll-line (loom/feature/window:window-scroll-line window)))
        (cond
          ((< point-line scroll-line)
           (setf (loom/feature/window:window-scroll-line window) point-line))
          ((>= point-line (+ scroll-line height))
           (setf (loom/feature/window:window-scroll-line window)
                 (- point-line (1- height)))))))))
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
(defun %layout-compute-regions (width height file-tree-visible-p)
  "Compute the row/column geometry COMPOSE-FRAME draws into, given the
renderer's WIDTH/HEIGHT and whether the file-tree sidebar is visible.
Returns (VALUES CONTENT-HEIGHT MINIBUFFER-ROW SHORTCUTS-ROW
SHORTCUTS-VISIBLE-P FILE-TREE-WIDTH WINDOW-AREA-WIDTH), leaving COMPOSE-FRAME
itself to only sequence the draw calls against them."
  (let* ((shortcuts-visible-p (> height 1))
         (content-height (max 0 (- height (if shortcuts-visible-p 2 1))))
         (minibuffer-row (max 0 (1- height)))
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
        (%layout-keep-point-visible window))
      (%layout-draw-windows renderer window-tree file-tree-width)
      (when shortcuts-visible-p
        (%layout-draw-shortcuts renderer width shortcuts-row
                                (loom/feature/window:window-buffer
                                 (loom/feature/window:window-tree-selected-window
                                  window-tree))
                                workspace-name))
      (%layout-draw-minibuffer renderer (editor-state-minibuffer editor-state) width minibuffer-row)
      editor-state)))
