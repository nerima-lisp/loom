;;;; src/presentation/layout.lisp
;;;;
;;;; Presentation layer: screen composition. Given the current EDITOR-STATE,
;;;; COMPOSE-FRAME decides what rectangle each visible thing occupies (the
;;;; file-tree sidebar, the window-tree's leaf buffers plus a minimal
;;;; separator between adjacent leaves, and the bottom minibuffer line) and
;;;; draws it into the renderer's in-memory screen. This is deliberately a
;;;; plain, sequential draw with no compositing beyond "clear, then draw each
;;;; region once" -- infrastructure/terminal-renderer.lisp already owns the
;;;; raw CL-TTY-KIT screen/renderer plumbing (LOOM-RENDERER-DRAW-BUFFER,
;;;; LOOM-RENDERER-PRESENT); this file only owns the layout decisions on top
;;;; of it, per the convention this file's header previously described.
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

(defun %layout-draw-file-tree (screen file-tree width height)
  "Draw FILE-TREE's currently visible entries (FILE-TREE-ENTRIES) into the
left WIDTH-column, HEIGHT-row strip of SCREEN starting at (0,0), one entry
per row, each indented two columns per depth level and truncated to WIDTH
columns. The row whose path is FILE-TREE-SELECTED-PATH is drawn in reverse
video so the current selection is visible. Entries beyond HEIGHT rows are
simply not drawn -- no scrolling is attempted here, matching this file's
\"plain sequential draw\" scope."
  (when (plusp width)
    (let ((entries (file-tree-entries file-tree))
          (selected (file-tree-selected-path file-tree)))
      (loop for (path . depth) in entries
            for row from 0 below height
            do (let* ((indent (make-string (* 2 depth) :initial-element #\Space))
                      (text (concatenate 'string indent (%layout-path-label path)))
                      (visible (if (> (length text) width) (subseq text 0 width) text))
                      (style (when (equal path selected) '(:reverse))))
                 (cl-tty-kit:screen-write-string screen 0 row visible :style style))))))

;;; ---------------------------------------------------------------------
;;; Window-tree area
;;; ---------------------------------------------------------------------

(defun %layout-draw-windows (renderer screen window-tree x-offset)
  "Draw every leaf window in WINDOW-TREE (already laid out by
WINDOW-TREE-RESIZE against the window area's own width/height) via
LOOM-RENDERER-DRAW-BUFFER, each leaf's rect offset horizontally by X-OFFSET
columns -- the width consumed by a visible file-tree sidebar, so a leaf's own
WINDOW-X/WINDOW-Y (relative to the window tree's own origin) land in the
right place on the shared screen. When a split produced more than one leaf, a
minimal 1-cell separator line (CL-TTY-KIT:SCREEN-DRAW-VERTICAL-LINE /
SCREEN-DRAW-HORIZONTAL-LINE) is drawn along the shared edge between any two
horizontally- or vertically-adjacent leaves, so a user can tell the panes
apart. Returns RENDERER."
  (let ((leaves (window-tree-windows window-tree)))
    (dolist (leaf leaves)
      (loom-renderer-draw-buffer renderer (window-buffer leaf)
                                  (+ x-offset (window-x leaf)) (window-y leaf)
                                  (window-width leaf) (window-height leaf)))
    (dolist (leaf leaves)
      ;; A leaf whose X is not 0 (relative to the window-tree's own origin)
      ;; has a neighbor immediately to its left from a :VERTICAL split; draw
      ;; a vertical rule just left of this leaf's own left edge.
      (when (and (plusp (window-x leaf)) (plusp (window-height leaf)))
        (cl-tty-kit:screen-draw-vertical-line
         screen (1- (+ x-offset (window-x leaf))) (window-y leaf) (window-height leaf)))
      ;; Likewise, a leaf whose Y is not 0 has a neighbor immediately above it
      ;; from a :HORIZONTAL split; draw a horizontal rule just above it.
      (when (and (plusp (window-y leaf)) (plusp (window-width leaf)))
        (cl-tty-kit:screen-draw-horizontal-line
         screen (+ x-offset (window-x leaf)) (1- (window-y leaf)) (window-width leaf)))))
  renderer)

;;; ---------------------------------------------------------------------
;;; Minibuffer line
;;; ---------------------------------------------------------------------

(defun %layout-minibuffer-line (minibuffer)
  "Return the single line of text MINIBUFFER should currently show at the
bottom of the screen: prompt+input while MINIBUFFER-ACTIVE-P, else the last
transient status message set via MINIBUFFER-MESSAGE (read through the
internal %MINIBUFFER-MESSAGE accessor -- the minibuffer protocol exposes a
generic to *set* that message but none to read it back, so this file reaches
past the exported protocol the same way t/file-tree-test.lisp reaches
LOOM::FILE-TREE-CHILD-LISTER), else the empty string."
  (cond
    ((minibuffer-active-p minibuffer)
     (concatenate 'string (or (minibuffer-prompt-string minibuffer) "")
                  (minibuffer-input-string minibuffer)))
    ((%minibuffer-message minibuffer))
    (t "")))

(defun %layout-draw-minibuffer (screen minibuffer width row)
  "Draw MINIBUFFER's current line (see %LAYOUT-MINIBUFFER-LINE) into SCREEN's
ROW, truncated to WIDTH columns."
  (when (plusp width)
    (let* ((text (%layout-minibuffer-line minibuffer))
           (visible (if (> (length text) width) (subseq text 0 width) text)))
      (cl-tty-kit:screen-write-string screen 0 row visible))))

;;; ---------------------------------------------------------------------
;;; Frame composition
;;; ---------------------------------------------------------------------

(defun compose-frame (editor-state)
  "Compose one full editor frame into EDITOR-STATE's renderer's in-memory
screen: clear it; draw the file-tree sidebar (when FILE-TREE-VISIBLE-P) into
a left, up-to-24-column strip spanning every row above the minibuffer;
resize EDITOR-STATE's window tree (WINDOW-TREE-RESIZE) to whatever screen
area remains after that strip and the bottom minibuffer row -- this is the
one place that resize is driven from, so a file-tree visibility toggle or a
terminal resize (see MAIN's polling loop, which only needs to keep the
renderer itself in sync via LOOM-RENDERER-RESIZE) is always reflected by the
very next frame -- draw every leaf window's buffer plus separators between
adjacent leaves into that area; and finally draw the minibuffer's current
prompt/input or status line into the bottom row. Performs no I/O beyond
mutating the renderer's screen; LOOM-RENDERER-PRESENT is the caller's job to
actually flush that screen to a terminal. Returns EDITOR-STATE."
  (let* ((renderer (editor-state-renderer editor-state))
         (cl-tty-renderer (loom-renderer-cl-tty-renderer renderer))
         (screen (cl-tty-kit:renderer-screen cl-tty-renderer))
         (width (cl-tty-kit:renderer-width cl-tty-renderer))
         (height (cl-tty-kit:renderer-height cl-tty-renderer))
         (content-height (max 0 (1- height)))
         (minibuffer-row (max 0 (1- height)))
         (file-tree (editor-state-file-tree editor-state))
         (file-tree-visible (file-tree-visible-p file-tree))
         (file-tree-width (if file-tree-visible (min 24 width) 0))
         (window-tree (editor-state-window-tree editor-state))
         (window-area-width (max 0 (- width file-tree-width))))
    (cl-tty-kit:screen-clear screen)
    (when file-tree-visible
      (%layout-draw-file-tree screen file-tree file-tree-width content-height))
    (window-tree-resize window-tree window-area-width content-height)
    (%layout-draw-windows renderer screen window-tree file-tree-width)
    (%layout-draw-minibuffer screen (editor-state-minibuffer editor-state) width minibuffer-row)
    editor-state))
