;;;; t/integration/layout-test.lisp
;;;;
;;;; Presentation layer: COMPOSE-FRAME against a small (40x6) real renderer
;;;; and real MAKE-BUFFER/MAKE-WINDOW-TREE/MAKE-MINIBUFFER/MAKE-FILE-TREE
;;;; objects -- every layer COMPOSE-FRAME composes is already real by the
;;;; time this file was written, so there is no need for a test double here
;;;; the way t/unit/terminal-renderer-test.lisp once needed FAKE-BUFFER.
;;;;
;;;; COMPOSE-FRAME itself is not exported from the LOOM package (see
;;;; src/presentation/layout.lisp), so it is reached here via LOOM::
;;;; qualification for private layout orchestration helpers.
(in-package #:loom/test)

(defun %fresh-layout-state (&key name (content "") (width 40) (height 6)
                                 (renderer-width width) (renderer-height height))
  "Build the EDITOR-STATE every test in this file draws through: one window
of WIDTH x HEIGHT over a buffer named NAME (defaulting to MAKE-BUFFER's own
\"*scratch*\") holding CONTENT, a fresh minibuffer, a file-tree rooted at
\"/root/\", and a renderer of RENDERER-WIDTH x RENDERER-HEIGHT. The renderer
dimensions default to the window's, which is what every drawing test wants;
the degenerate-window tests are the ones that need them to differ."
  (make-editor-state :window-tree (make-window-tree
                                   (make-buffer :name name :initial-content content)
                                   width
                                   height)
                     :minibuffer (make-minibuffer)
                     :keymap (make-keymap)
                     :file-tree (make-file-tree "/root/")
                     :renderer (make-loom-renderer renderer-width renderer-height)
                     :kill-ring nil))

(defun %layout-screen (state)
  "The cl-tty-kit screen STATE's renderer draws into."
  (cl-tty-kit:renderer-screen
   (loom::%loom-renderer-cl-tty-renderer (editor-state-renderer state))))

(defun %layout-window (state)
  "STATE's sole (or currently selected) window."
  (window-tree-selected-window (editor-state-window-tree state)))

(describe
  "compose-frame"
  (it
    "draws the selected window's buffer and the minibuffer's status line when the file-tree is hidden"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "abc"))
           (minibuffer (editor-state-minibuffer state)))
      (minibuffer-message minibuffer "status message")
      (loom::compose-frame state)
      (let ((screen (%layout-screen state)))
        (expect (cl-tty-kit:screen-to-string screen)
                :to-equal
                (format nil "~A~%~A~%~A~%~A~%~A~%~A"
                        (cl-tty-kit:pad-string "abc" 40)
                        (cl-tty-kit:pad-string "" 40)
                        (cl-tty-kit:pad-string "" 40)
                        (cl-tty-kit:pad-string "" 40)
                        (cl-tty-kit:pad-string
                         "Ln 1, Col 1  C-h Help  C-x C-s Save  C-s"
                         40)
                        (cl-tty-kit:pad-string "status message" 40))))))

  (it
    "draws non-primary multiple cursors as reverse-video cells"
    (let* ((state (%fresh-layout-state
                   :content (format nil "one~%two")
                   :width 20
                   :height 6))
           (*editor-state* state)
           (buffer (window-buffer (%layout-window state))))
      (buffer-set-point buffer 0 1)
      (expect (loom/feature/multiple-cursors:multiple-cursors-add-next-line)
              :to-be t)
      (loom::compose-frame state)
      (let ((screen (%layout-screen state)))
        (expect (cl-tty-kit:screen-row-string screen 1 :start 0 :end 3)
                :to-equal "two")
        (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 1 1))
                :to-equal '(:reverse)))))

  (it
    "shows the active workspace in the shortcut line"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "abc"))
           (tree (editor-state-window-tree state)))
      (setf (editor-state-workspaces state)
            (make-workspace-manager tree :name "notes"))
      (loom::compose-frame state)
      (expect (search "Workspace: notes"
                      (cl-tty-kit:screen-row-string
                       (%layout-screen state)
                       4))
              :to-be-truthy)))

  (it
    "scrolls a selected window so its point remains visible"
    (let* ((state (%fresh-layout-state :content (format nil "one~%two~%three~%four~%five")
                                       :width 20
                                       :height 4))
           (buffer (window-buffer (%layout-window state))))
      (buffer-set-point buffer 4 0)
      (loom::compose-frame state)
      (expect (window-scroll-line (%layout-window state)) :to-equal 3)
      (let ((screen (%layout-screen state)))
        (expect (cl-tty-kit:screen-row-string screen 0 :start 0 :end 4)
                :to-equal "four"))))

  (it
    "draws the file-tree sidebar to the left of the buffer, offsetting the window area by its width"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "hi"))
           (file-tree (editor-state-file-tree state)))
      (loom/feature/file-tree:file-tree-install-child-lister
       file-tree
       (lambda (path)
         (declare (ignore path))
         '(("/root/a.txt" . :file) ("/root/b.txt" . :file))))
      (file-tree-toggle file-tree)
      (loom::compose-frame state)
      (let ((screen (%layout-screen state)))
        ;; File-tree entries at the left edge, one per row.
        (expect (cl-tty-kit:screen-row-string screen 0 :start 0 :end 5) :to-equal "a.txt")
        (expect (cl-tty-kit:screen-row-string screen 1 :start 0 :end 5) :to-equal "b.txt")
        ;; The window area starts right after the 24-column file-tree strip.
        (expect (cl-tty-kit:screen-row-string screen 0 :start 24 :end 26) :to-equal "hi"))))

  (it
    "draws separator lines between two horizontally split windows"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "hi"))
           (window-tree (editor-state-window-tree state)))
      (window-split window-tree (window-tree-selected-window window-tree) :vertical)
      (loom::compose-frame state)
      (let ((screen (%layout-screen state)))
        ;; A vertical split draws a single-line-border rule (U+2502) down the
        ;; shared edge between the two side-by-side panes.
        (expect (cl-tty-kit:screen-row-string screen 0 :start 19 :end 20)
                :to-equal (string (code-char #x2502))))))

  (it
    "draws a separator line between two horizontally (top/bottom) split windows"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "hi"))
           (window-tree (editor-state-window-tree state)))
      (window-split window-tree (window-tree-selected-window window-tree) :horizontal)
      (loom::compose-frame state)
      (let ((screen (%layout-screen state)))
        ;; A horizontal split draws a single-line-border rule (U+2500) along
        ;; the shared edge between the top and bottom panes.
        (expect (cl-tty-kit:screen-row-string screen 1 :start 0 :end 1)
                :to-equal (string (code-char #x2500))))))

  (it
    "truncates the shortcut line to fit a narrow terminal"
    (let ((state (%fresh-layout-state :name "*scratch*" :content "hi" :width 10)))
      (loom::compose-frame state)
      (let ((screen (%layout-screen state)))
        ;; "Ln 1, Col 1  C-h Help  ..." truncated to the 10-column terminal
        ;; width, proving %LAYOUT-DRAW-SHORTCUTS's truncation branch ran
        ;; instead of writing the (much longer) full shortcut line.
        (expect (cl-tty-kit:screen-row-string screen 4) :to-equal "Ln 1, Col "))))

  (it
    "draws the active minibuffer prompt and input, truncated to a narrow terminal"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "hi" :width 10))
           (minibuffer (editor-state-minibuffer state)))
      (minibuffer-activate minibuffer "Find file: ")
      (loom::compose-frame state)
      (let ((screen (%layout-screen state)))
        ;; "Find file: " (11 chars) truncated to the 10-column terminal width
        ;; proves both %LAYOUT-MINIBUFFER-LINE's active-prompt concatenation
        ;; branch and %LAYOUT-DRAW-MINIBUFFER's own truncation ran.
        (expect (cl-tty-kit:screen-row-string screen 5) :to-equal "Find file:"))))

  (it
    "highlights the selected file-tree entry and truncates a name past the sidebar width"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "hi"))
           (file-tree (editor-state-file-tree state)))
      (loom/feature/file-tree:file-tree-install-child-lister
       file-tree
       (lambda (path)
         (declare (ignore path))
         (list (cons "/root/a-very-long-file-name-indeed.txt" :file))))
      (file-tree-toggle file-tree)
      (file-tree-move-selection file-tree :down)
      (loom::compose-frame state)
      (let ((screen (%layout-screen state)))
        (expect (cl-tty-kit:screen-row-string screen 0 :start 0 :end 24)
                :to-equal "a-very-long-file-name-in")
        (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 0 0))
                :to-equal '(:reverse)))))

  (it
    "scrolls a selected window backward when point moves above the viewport"
    (let* ((state (%fresh-layout-state :content (format nil "one~%two~%three~%four~%five")
                                       :width 20
                                       :height 4))
           (window (%layout-window state)))
      (setf (window-scroll-line window) 3)
      (buffer-set-point (window-buffer window) 0 0)
      (loom::compose-frame state)
      (expect (window-scroll-line window) :to-equal 0))))

(describe
  "syntax-highlighted layout drawing"
  (it
    "maps semantic tokens to styles while clipping at screen-cell boundaries"
    (let* ((renderer (make-loom-renderer 12 1))
           (line "(defun f あ)"))
      (loom/feature/syntax-highlighting:syntax-draw-highlighted-line
       renderer line 0 0 12)
      (let ((screen (cl-tty-kit:renderer-screen
                     (loom::%loom-renderer-cl-tty-renderer renderer))))
        (expect (cl-tty-kit:screen-row-string screen 0 :start 0 :end 12)
                :to-equal "(defun f あ )")
        (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 1 0))
                :to-equal '(:bold (:fg 6)))
        (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 0 0))
                :to-equal '((:fg 4)))))))

(describe
  "zero-width and zero-height draw regions"
  ;; COMPOSE-FRAME never derives a zero WIDTH/HEIGHT for these from a real
  ;; terminal in current tests, so each drawing helper is reached directly
  ;; (LOOM:: qualification, same precedent as COMPOSE-FRAME itself) to lock
  ;; in that a degenerate region is a no-op rather than an error.
  (it
    "%layout-draw-file-tree does nothing for a zero-width sidebar"
    (let* ((state (%fresh-layout-state))
           (screen (%layout-screen state))
           (before (cl-tty-kit:screen-row-string screen 0)))
      (loom::%layout-draw-file-tree screen (editor-state-file-tree state) 0 6)
      (expect (cl-tty-kit:screen-row-string screen 0) :to-equal before)))

  (it
    "%layout-draw-shortcuts does nothing for a zero-width terminal"
    (let* ((state (%fresh-layout-state :content "text"))
           (screen (%layout-screen state))
           (before (cl-tty-kit:screen-row-string screen 0)))
      (loom::%layout-draw-shortcuts screen 0 0 (window-buffer (%layout-window state)))
      (expect (cl-tty-kit:screen-row-string screen 0) :to-equal before)))

  (it
    "%layout-draw-minibuffer does nothing for a zero-width terminal"
    (let* ((state (%fresh-layout-state))
           (screen (%layout-screen state))
           (minibuffer (editor-state-minibuffer state))
           (before (cl-tty-kit:screen-row-string screen 0)))
      (minibuffer-message minibuffer "status")
      (loom::%layout-draw-minibuffer screen minibuffer 0 0)
      (expect (cl-tty-kit:screen-row-string screen 0) :to-equal before)))

  (it
    "%layout-keep-point-visible does nothing for a zero-height window"
    (let* ((state (%fresh-layout-state :content (format nil "one~%two~%three")
                                       :width 20
                                       :height 4))
           (window (%layout-window state)))
      (buffer-set-point (window-buffer window) 2 0)
      (setf (loom/feature/window::window-leaf-height window) 0)
      (setf (window-scroll-line window) 0)
      (loom::%layout-keep-point-visible window)
      (expect (window-scroll-line window) :to-equal 0))))

(describe
  "editor-cursor"
  (it
    "positions the cursor at point's column and line within the selected window"
    (let ((state (%fresh-layout-state :content (format nil "hello~%world"))))
      (buffer-set-point (window-buffer (%layout-window state)) 1 3)
      (let ((cursor (loom::editor-cursor state)))
        (expect (cl-tty-kit:cursor-x cursor) :to-equal 3)
        (expect (cl-tty-kit:cursor-y cursor) :to-equal 1))))

  (it
    "offsets the cursor by the file-tree sidebar's width when visible"
    (let ((state (%fresh-layout-state :content "hi")))
      (file-tree-toggle (editor-state-file-tree state))
      (let ((cursor (loom::editor-cursor state)))
        (expect (cl-tty-kit:cursor-x cursor) :to-equal 24))))

  (it
    "hides the cursor when the selected window has zero width or height"
    (let ((state (%fresh-layout-state :content "hi"
                                      :width 0
                                      :height 0
                                      :renderer-width 40
                                      :renderer-height 6)))
      (let ((cursor (loom::editor-cursor state)))
        (expect (cl-tty-kit:cursor-visible-p cursor) :to-be nil)))))

(describe
  "%layout-path-label"
  (it
    "returns a pathname's last path component"
    (expect (loom::%layout-path-label #P"/root/sub/a.txt") :to-equal "a.txt"))
  (it
    "returns a directory pathname's last component without a trailing slash"
    (expect (loom::%layout-path-label #P"/root/sub/") :to-equal "sub")))
