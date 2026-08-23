;;;; t/integration/layout-test.lisp
;;;;
;;;; Presentation drawing helpers below COMPOSE-FRAME: layout helper behavior
;;;; that is easiest to lock in either by drawing directly through those
;;;; helpers or by using the syntax-highlighting renderer entry points they
;;;; call.
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
  "syntax-highlighted horizontal scrolling"
  (it-each
      (("あいうえお" 0 "あ い  ")
       ("あいうえお" 2 "い う  ")
       ("あいうえお" 3 " う え ")
       ("abc def" 0 "abc d")
       ("abc def" 2 "c def")
       ("abc def" 7 "     "))
      "draws ~S scrolled ~D cells right as ~S"
      (line start-column expected)
    (let ((renderer (make-loom-renderer 5 1)))
      (loom/feature/syntax-highlighting:syntax-draw-highlighted-line
       renderer line 0 0 5 :common-lisp start-column)
      (expect (cl-tty-kit:screen-row-string
               (cl-tty-kit:renderer-screen
                (loom::%loom-renderer-cl-tty-renderer renderer))
               0 :start 0 :end 5)
              :to-equal expected))))

(describe
  "zero-width and zero-height draw regions"
  ;; COMPOSE-FRAME never derives a zero WIDTH/HEIGHT for these from a real
  ;; terminal in current tests, so each drawing helper is reached directly
  ;; (LOOM:: qualification) to lock in that a degenerate region is a no-op
  ;; rather than an error.
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
      (expect (cl-tty-kit:screen-row-string screen 0) :to-equal before))))

(describe
  "%layout-path-label"
  (it
    "returns a pathname's last path component"
    (expect (loom::%layout-path-label #P"/root/sub/a.txt") :to-equal "a.txt"))
  (it
    "returns a directory pathname's last component without a trailing slash"
    (expect (loom::%layout-path-label #P"/root/sub/") :to-equal "sub")))
