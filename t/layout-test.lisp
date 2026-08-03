;;;; t/layout-test.lisp
;;;;
;;;; Presentation layer: COMPOSE-FRAME against a small (40x6) real renderer
;;;; and real MAKE-BUFFER/MAKE-WINDOW-TREE/MAKE-MINIBUFFER/MAKE-FILE-TREE
;;;; objects -- every layer COMPOSE-FRAME composes is already real by the
;;;; time this file was written, so there is no need for a test double here
;;;; the way t/terminal-renderer-test.lisp once needed FAKE-BUFFER.
;;;;
;;;; COMPOSE-FRAME itself is not exported from the LOOM package (see
;;;; src/presentation/layout.lisp), so it is reached here via LOOM::
;;;; qualification, the same precedent t/file-tree-test.lisp already set for
;;;; LOOM::FILE-TREE-CHILD-LISTER.
(in-package #:loom/test)

(describe
  "compose-frame"
  (it
    "draws the selected window's buffer and the minibuffer's status line when the file-tree is hidden"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "abc"))
           (window-tree (make-window-tree buffer 40 6))
           (minibuffer (make-minibuffer))
           (file-tree (make-file-tree "/root/"))
           (renderer (make-loom-renderer 40 6))
           (editor-state (make-editor-state :window-tree window-tree
                                             :minibuffer minibuffer
                                             :keymap (make-keymap)
                                             :file-tree file-tree
                                             :renderer renderer
                                             :kill-ring nil)))
      (minibuffer-message minibuffer "status message")
      (loom::compose-frame editor-state)
      (let ((screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer))))
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
    "scrolls a selected window so its point remains visible"
    (let* ((buffer (make-buffer :initial-content (format nil "one~%two~%three~%four~%five")))
           (window-tree (make-window-tree buffer 20 4))
           (minibuffer (make-minibuffer))
           (file-tree (make-file-tree "/root/"))
           (renderer (make-loom-renderer 20 4))
           (editor-state (make-editor-state :window-tree window-tree
                                             :minibuffer minibuffer
                                             :keymap (make-keymap)
                                             :file-tree file-tree
                                             :renderer renderer
                                             :kill-ring nil)))
      (buffer-set-point buffer 4 0)
      (loom::compose-frame editor-state)
      (expect (window-scroll-line (window-tree-selected-window window-tree)) :to-equal 3)
      (let ((screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer))))
        (expect (cl-tty-kit:screen-row-string screen 0 :start 0 :end 4)
                :to-equal "four"))))

  (it
    "draws the file-tree sidebar to the left of the buffer, offsetting the window area by its width"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "hi"))
           (window-tree (make-window-tree buffer 40 6))
           (minibuffer (make-minibuffer))
           (file-tree (make-file-tree "/root/"))
           (renderer (make-loom-renderer 40 6))
           (editor-state (make-editor-state :window-tree window-tree
                                             :minibuffer minibuffer
                                             :keymap (make-keymap)
                                             :file-tree file-tree
                                             :renderer renderer
                                             :kill-ring nil)))
      (setf (loom::file-tree-child-lister file-tree)
            (lambda (path)
              (declare (ignore path))
              '(("/root/a.txt" . :file) ("/root/b.txt" . :file))))
      (file-tree-toggle file-tree)
      (loom::compose-frame editor-state)
      (let ((screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer))))
        ;; File-tree entries at the left edge, one per row.
        (expect (cl-tty-kit:screen-row-string screen 0 :start 0 :end 5) :to-equal "a.txt")
        (expect (cl-tty-kit:screen-row-string screen 1 :start 0 :end 5) :to-equal "b.txt")
        ;; The window area starts right after the 24-column file-tree strip.
        (expect (cl-tty-kit:screen-row-string screen 0 :start 24 :end 26) :to-equal "hi"))))

  (it
    "draws separator lines between two horizontally split windows"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "hi"))
           (window-tree (make-window-tree buffer 40 6))
           (minibuffer (make-minibuffer))
           (file-tree (make-file-tree "/root/"))
           (renderer (make-loom-renderer 40 6))
           (editor-state (make-editor-state :window-tree window-tree
                                             :minibuffer minibuffer
                                             :keymap (make-keymap)
                                             :file-tree file-tree
                                             :renderer renderer
                                             :kill-ring nil)))
      (window-split window-tree (window-tree-selected-window window-tree) :vertical)
      (loom::compose-frame editor-state)
      (let ((screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer))))
        ;; A vertical split draws a single-line-border rule (U+2502) down the
        ;; shared edge between the two side-by-side panes.
        (expect (cl-tty-kit:screen-row-string screen 0 :start 19 :end 20)
                :to-equal (string (code-char #x2502))))))

  (it
    "draws a separator line between two horizontally (top/bottom) split windows"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "hi"))
           (window-tree (make-window-tree buffer 40 6))
           (minibuffer (make-minibuffer))
           (file-tree (make-file-tree "/root/"))
           (renderer (make-loom-renderer 40 6))
           (editor-state (make-editor-state :window-tree window-tree
                                             :minibuffer minibuffer
                                             :keymap (make-keymap)
                                             :file-tree file-tree
                                             :renderer renderer
                                             :kill-ring nil)))
      (window-split window-tree (window-tree-selected-window window-tree) :horizontal)
      (loom::compose-frame editor-state)
      (let ((screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer))))
        ;; A horizontal split draws a single-line-border rule (U+2500) along
        ;; the shared edge between the top and bottom panes.
        (expect (cl-tty-kit:screen-row-string screen 1 :start 0 :end 1)
                :to-equal (string (code-char #x2500))))))

  (it
    "truncates the shortcut line to fit a narrow terminal"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "hi"))
           (window-tree (make-window-tree buffer 10 6))
           (minibuffer (make-minibuffer))
           (file-tree (make-file-tree "/root/"))
           (renderer (make-loom-renderer 10 6))
           (editor-state (make-editor-state :window-tree window-tree
                                             :minibuffer minibuffer
                                             :keymap (make-keymap)
                                             :file-tree file-tree
                                             :renderer renderer
                                             :kill-ring nil)))
      (loom::compose-frame editor-state)
      (let ((screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer))))
        ;; "Ln 1, Col 1  C-h Help  ..." truncated to the 10-column terminal
        ;; width, proving %LAYOUT-DRAW-SHORTCUTS's truncation branch ran
        ;; instead of writing the (much longer) full shortcut line.
        (expect (cl-tty-kit:screen-row-string screen 4) :to-equal "Ln 1, Col "))))

  (it
    "draws the active minibuffer prompt and input, truncated to a narrow terminal"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "hi"))
           (window-tree (make-window-tree buffer 10 6))
           (minibuffer (make-minibuffer))
           (file-tree (make-file-tree "/root/"))
           (renderer (make-loom-renderer 10 6))
           (editor-state (make-editor-state :window-tree window-tree
                                             :minibuffer minibuffer
                                             :keymap (make-keymap)
                                             :file-tree file-tree
                                             :renderer renderer
                                             :kill-ring nil)))
      (minibuffer-activate minibuffer "Find file: ")
      (loom::compose-frame editor-state)
      (let ((screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer))))
        ;; "Find file: " (11 chars) truncated to the 10-column terminal width
        ;; proves both %LAYOUT-MINIBUFFER-LINE's active-prompt concatenation
        ;; branch and %LAYOUT-DRAW-MINIBUFFER's own truncation ran.
        (expect (cl-tty-kit:screen-row-string screen 5) :to-equal "Find file:"))))

  (it
    "highlights the selected file-tree entry and truncates a name past the sidebar width"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "hi"))
           (window-tree (make-window-tree buffer 40 6))
           (minibuffer (make-minibuffer))
           (file-tree (make-file-tree "/root/"))
           (renderer (make-loom-renderer 40 6))
           (editor-state (make-editor-state :window-tree window-tree
                                             :minibuffer minibuffer
                                             :keymap (make-keymap)
                                             :file-tree file-tree
                                             :renderer renderer
                                             :kill-ring nil)))
      (setf (loom::file-tree-child-lister file-tree)
            (lambda (path)
              (declare (ignore path))
              (list (cons "/root/a-very-long-file-name-indeed.txt" :file))))
      (file-tree-toggle file-tree)
      (file-tree-move-selection file-tree :down)
      (loom::compose-frame editor-state)
      (let ((screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer))))
        (expect (cl-tty-kit:screen-row-string screen 0 :start 0 :end 24)
                :to-equal "a-very-long-file-name-in")
        (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 0 0))
                :to-equal '(:reverse)))))

  (it
    "scrolls a selected window backward when point moves above the viewport"
    (let* ((buffer (make-buffer :initial-content (format nil "one~%two~%three~%four~%five")))
           (window-tree (make-window-tree buffer 20 4))
           (minibuffer (make-minibuffer))
           (file-tree (make-file-tree "/root/"))
           (renderer (make-loom-renderer 20 4))
           (editor-state (make-editor-state :window-tree window-tree
                                             :minibuffer minibuffer
                                             :keymap (make-keymap)
                                             :file-tree file-tree
                                             :renderer renderer
                                             :kill-ring nil)))
      (setf (window-scroll-line (window-tree-selected-window window-tree)) 3)
      (buffer-set-point buffer 0 0)
      (loom::compose-frame editor-state)
      (expect (window-scroll-line (window-tree-selected-window window-tree)) :to-equal 0))))

(describe
  "zero-width and zero-height draw regions"
  ;; COMPOSE-FRAME never derives a zero WIDTH/HEIGHT for these from a real
  ;; terminal in current tests, so each drawing helper is reached directly
  ;; (LOOM:: qualification, same precedent as COMPOSE-FRAME itself) to lock
  ;; in that a degenerate region is a no-op rather than an error.
  (it
    "%layout-draw-file-tree does nothing for a zero-width sidebar"
    (let* ((renderer (make-loom-renderer 40 6))
           (screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer)))
           (file-tree (make-file-tree "/root/"))
           (before (cl-tty-kit:screen-row-string screen 0)))
      (loom::%layout-draw-file-tree screen file-tree 0 6)
      (expect (cl-tty-kit:screen-row-string screen 0) :to-equal before)))

  (it
    "%layout-draw-shortcuts does nothing for a zero-width terminal"
    (let* ((renderer (make-loom-renderer 40 6))
           (screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer)))
           (buffer (make-buffer :initial-content "text"))
           (before (cl-tty-kit:screen-row-string screen 0)))
      (loom::%layout-draw-shortcuts screen 0 0 buffer)
      (expect (cl-tty-kit:screen-row-string screen 0) :to-equal before)))

  (it
    "%layout-draw-minibuffer does nothing for a zero-width terminal"
    (let* ((renderer (make-loom-renderer 40 6))
           (screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer)))
           (minibuffer (make-minibuffer))
           (before (cl-tty-kit:screen-row-string screen 0)))
      (minibuffer-message minibuffer "status")
      (loom::%layout-draw-minibuffer screen minibuffer 0 0)
      (expect (cl-tty-kit:screen-row-string screen 0) :to-equal before)))

  (it
    "%layout-keep-point-visible does nothing for a zero-height window"
    (let* ((buffer (make-buffer :initial-content (format nil "one~%two~%three")))
           (window-tree (make-window-tree buffer 20 4))
           (window (window-tree-selected-window window-tree)))
      (buffer-set-point buffer 2 0)
      (setf (loom::window-leaf-height window) 0)
      (setf (window-scroll-line window) 0)
      (loom::%layout-keep-point-visible window)
      (expect (window-scroll-line window) :to-equal 0))))

(describe
  "editor-cursor"
  (it
    "positions the cursor at point's column and line within the selected window"
    (let* ((buffer (make-buffer :initial-content (format nil "hello~%world")))
           (window-tree (make-window-tree buffer 40 6))
           (editor-state (make-editor-state :window-tree window-tree
                                             :minibuffer (make-minibuffer)
                                             :keymap (make-keymap)
                                             :file-tree (make-file-tree "/root/")
                                             :renderer (make-loom-renderer 40 6)
                                             :kill-ring nil)))
      (buffer-set-point buffer 1 3)
      (let ((cursor (loom::editor-cursor editor-state)))
        (expect (cl-tty-kit:cursor-x cursor) :to-equal 3)
        (expect (cl-tty-kit:cursor-y cursor) :to-equal 1))))

  (it
    "offsets the cursor by the file-tree sidebar's width when visible"
    (let* ((buffer (make-buffer :initial-content "hi"))
           (window-tree (make-window-tree buffer 40 6))
           (file-tree (make-file-tree "/root/"))
           (editor-state (make-editor-state :window-tree window-tree
                                             :minibuffer (make-minibuffer)
                                             :keymap (make-keymap)
                                             :file-tree file-tree
                                             :renderer (make-loom-renderer 40 6)
                                             :kill-ring nil)))
      (file-tree-toggle file-tree)
      (let ((cursor (loom::editor-cursor editor-state)))
        (expect (cl-tty-kit:cursor-x cursor) :to-equal 24))))

  (it
    "hides the cursor when the selected window has zero width or height"
    (let* ((buffer (make-buffer :initial-content "hi"))
           (window-tree (make-window-tree buffer 0 0))
           (editor-state (make-editor-state :window-tree window-tree
                                             :minibuffer (make-minibuffer)
                                             :keymap (make-keymap)
                                             :file-tree (make-file-tree "/root/")
                                             :renderer (make-loom-renderer 40 6)
                                             :kill-ring nil)))
      (let ((cursor (loom::editor-cursor editor-state)))
        (expect (cl-tty-kit:cursor-visible-p cursor) :to-be nil)))))

(describe
  "%layout-path-label"
  (it
    "returns a pathname's last path component"
    (expect (loom::%layout-path-label #P"/root/sub/a.txt") :to-equal "a.txt"))
  (it
    "returns a directory pathname's last component without a trailing slash"
    (expect (loom::%layout-path-label #P"/root/sub/") :to-equal "sub")))
