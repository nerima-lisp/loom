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
  "incremental-search layout drawing"
  (it
    "highlights matches and distinguishes the current match"
    (let* ((state (%fresh-layout-state :content "one two one" :width 20 :height 1))
           (window (%layout-window state))
           (buffer (window-buffer window))
           (session (make-isearch-session buffer 0)))
      (isearch-apply-pattern session "o")
      (setf (editor-state-isearch state) session)
      (let ((*editor-state* state))
        (loom::%layout-draw-isearch
         (editor-state-renderer state) window 0))
      (let ((screen (%layout-screen state)))
        (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 0 0))
                :to-equal '((:fg 0) (:bg 6)))
        (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 6 0))
                :to-equal '((:fg 0) (:bg 3)))))))

  (it
    "does not paint a search session onto a different buffer"
    (let* ((state (%fresh-layout-state :content "one two one" :width 20 :height 1))
           (window (%layout-window state))
           (session (make-isearch-session (make-buffer :initial-content "one") 0)))
      (isearch-apply-pattern session "o")
      (setf (editor-state-isearch state) session)
      (let ((*editor-state* state))
        (loom::%layout-draw-isearch
         (editor-state-renderer state) window 0))
      (expect (cl-tty-kit:cell-style
               (cl-tty-kit:screen-cell (%layout-screen state) 0 0))
              :to-be nil)))

  (it
    "leaves the screen unchanged when no search session is active"
    (let* ((state (%fresh-layout-state :content "one two" :width 20 :height 1))
           (screen (%layout-screen state))
           (before (cl-tty-kit:screen-row-string screen 0)))
      (let ((*editor-state* state))
        (loom::%layout-draw-isearch
         (editor-state-renderer state) (%layout-window state) 0))
      (expect (cl-tty-kit:screen-row-string screen 0) :to-equal before)))

  (it
    "highlights a match on the wrapped row where its text is displayed"
    (let* ((state (%fresh-layout-state :content "abcdef" :width 3 :height 2))
           (window (%layout-window state))
           (buffer (window-buffer window))
           (session (make-isearch-session buffer 0)))
      (buffer-set-truncate-lines buffer nil)
      (isearch-apply-pattern session "de")
      (setf (editor-state-isearch state) session)
      (let ((*editor-state* state))
        (loom::%layout-draw-isearch
         (editor-state-renderer state) window 0))
      (let ((screen (%layout-screen state)))
        (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 0 1))
                :to-equal '((:fg 0) (:bg 6)))
        (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 1 1))
                :to-equal '((:fg 0) (:bg 6))))))

(describe
  "%layout-path-label"
  (it
    "returns a pathname's last path component"
    (expect (loom::%layout-path-label #P"/root/sub/a.txt") :to-equal "a.txt"))
  (it
    "returns a directory pathname's last component without a trailing slash"
    (expect (loom::%layout-path-label #P"/root/sub/") :to-equal "sub")))

(describe
  "wrapped layout coordinate helpers"
  (it
    "counts rows across wrapped logical lines and enforces its limit"
    (let* ((renderer (make-loom-renderer 3 4))
           (buffer (make-buffer :initial-content (format nil "abcdef~%xy"))))
      (expect (loom::%layout-segment-count renderer buffer 0 3)
              :to-equal 2)
      (expect (loom::%layout-rows-between renderer buffer 3 0 0 1 0 2)
              :to-equal 2)
      (expect (loom::%layout-rows-between renderer buffer 3 0 0 1 0 1)
              :to-be nil)))
  (it
    "returns no distance when the target precedes the origin"
    (let* ((renderer (make-loom-renderer 3 4))
           (buffer (make-buffer :initial-content "abcdef")))
      (expect (loom::%layout-rows-between renderer buffer 3 1 0 0 0 2)
              :to-be nil)
      (expect (loom::%layout-rows-between renderer buffer 3 0 1 0 0 2)
              :to-be nil)))
  (it
    "moves backward across wrapped segments and stops at buffer origin"
    (let* ((renderer (make-loom-renderer 3 4))
           (buffer (make-buffer :initial-content (format nil "abcdef~%xy"))))
      (multiple-value-bind (line row)
          (loom::%layout-row-back renderer buffer 3 1 0 1)
        (expect (list line row) :to-equal '(0 1)))
      (multiple-value-bind (line row)
          (loom::%layout-row-back renderer buffer 3 0 0 5)
        (expect (list line row) :to-equal '(0 0))))))
