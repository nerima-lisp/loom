;;;; t/integration/layout-test.lisp
;;;;
;;;; Presentation drawing helpers below COMPOSE-FRAME: layout helper behavior
;;;; that is easiest to lock in either by drawing directly through those
;;;; helpers or by using the syntax-highlighting renderer entry points they
;;;; call.
(in-package #:loom/test)

(describe
  "window buffer layout mode"
  (it
    "draws both truncated and wrapped buffer views through the layout helper"
    (let ((truncated (%fresh-layout-state :content "abcdef" :width 3 :height 2))
          (wrapped (%fresh-layout-state :content "abcdef" :width 3 :height 2)))
      (let ((truncated-buffer (window-buffer (%layout-window truncated))))
        (buffer-set-truncate-lines truncated-buffer t)
        (loom::%layout-draw-window-buffer
         (editor-state-renderer truncated) (%layout-window truncated) 0))
      (let ((wrapped-buffer (window-buffer (%layout-window wrapped))))
        (buffer-set-truncate-lines wrapped-buffer nil)
        (loom::%layout-draw-window-buffer
         (editor-state-renderer wrapped) (%layout-window wrapped) 0))
      (expect (cl-tty-kit:screen-row-string (%layout-screen truncated) 0)
              :to-equal "abc")
      (expect (cl-tty-kit:screen-row-string (%layout-screen truncated) 1)
              :to-equal "   ")
      (expect (cl-tty-kit:screen-row-string (%layout-screen wrapped) 0)
              :to-equal "abc")
      (expect (cl-tty-kit:screen-row-string (%layout-screen wrapped) 1)
              :to-equal "def"))))

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
    (with-layout-state (state)
      (let* ((screen (%layout-screen state))
             (before (cl-tty-kit:screen-row-string screen 0)))
        (loom::%layout-draw-file-tree screen (editor-state-file-tree state) 0 6)
        (expect (cl-tty-kit:screen-row-string screen 0) :to-equal before))))

  (it
    "%layout-draw-shortcuts does nothing for a zero-width terminal"
    (with-layout-state (state :content "text")
      (let* ((screen (%layout-screen state))
             (before (cl-tty-kit:screen-row-string screen 0)))
        (loom::%layout-draw-shortcuts screen 0 0 (window-buffer (%layout-window state)))
        (expect (cl-tty-kit:screen-row-string screen 0) :to-equal before))))

  (it
    "%layout-draw-minibuffer does nothing for a zero-width terminal"
    (with-layout-state (state)
      (let* ((screen (%layout-screen state))
             (minibuffer (editor-state-minibuffer state))
             (before (cl-tty-kit:screen-row-string screen 0)))
        (minibuffer-message minibuffer "status")
        (loom::%layout-draw-minibuffer screen minibuffer 0 0)
        (expect (cl-tty-kit:screen-row-string screen 0) :to-equal before))))

  (it
    "leaves a point viewport unchanged when either dimension is empty"
    (dolist (dimensions '((:width 0 :height 0)))
      (with-layout-state (state :content "abcdef" :width (getf dimensions :width)
                                :height (getf dimensions :height))
        (let ((window (%layout-window state)))
          (setf (window-scroll-line window) 0
                (window-scroll-column window) 3)
          (loom::%layout-keep-point-visible
           (editor-state-renderer state) window)
          (expect (window-scroll-line window) :to-equal 0)
          (expect (window-scroll-column window) :to-equal 3))))))

(describe
  "minibuffer line selection"
  (it "shows an empty line for an inactive minibuffer"
    (expect (loom::%layout-minibuffer-line (make-minibuffer))
            :to-equal ""))
  (it "shows a transient message while inactive"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-message minibuffer "saved")
      (expect (loom::%layout-minibuffer-line minibuffer)
              :to-equal "saved")))
  (it "shows input without a prompt when active"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate minibuffer nil)
      (setf (loom::%minibuffer-input minibuffer) "query")
      (expect (loom::%layout-minibuffer-line minibuffer)
              :to-equal "query")))
  (it "concatenates the prompt and input when active"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate minibuffer "> ")
      (setf (loom::%minibuffer-input minibuffer) "query")
      (expect (loom::%layout-minibuffer-line minibuffer)
              :to-equal "> query"))))

(describe
  "minibuffer and shortcut drawing"
  (it "draws the shortcut line with a workspace name"
    (let* ((state (%fresh-layout-state :content "x" :width 32 :height 2))
           (renderer (editor-state-renderer state))
           (screen (%layout-screen state)))
      (loom::%layout-draw-shortcuts
       renderer 32 0 (window-buffer (%layout-window state)) "main")
      (expect (cl-tty-kit:screen-row-string screen 0)
              :to-equal "Ln 1, Col 1  Workspace: main  C-")))
  (it "truncates the minibuffer line to the drawing width"
    (let* ((state (%fresh-layout-state :width 8 :height 1))
           (renderer (editor-state-renderer state))
           (screen (%layout-screen state))
           (minibuffer (editor-state-minibuffer state)))
      (minibuffer-activate minibuffer "Prompt: ")
      (setf (loom::%minibuffer-input minibuffer) "query")
      (loom::%layout-draw-minibuffer renderer minibuffer 8 0)
      (expect (cl-tty-kit:screen-row-string screen 0)
              :to-equal "Prompt: ")))
  (it "draws a selected completion row at its popup origin"
    (let* ((state (%fresh-layout-state :width 12 :height 8))
           (window (%layout-window state))
           (completion (loom::make-editor-completion
                        (window-buffer window) 0 0
                        (list (cons "one" "one")
                              (cons "two" "two")))))
      (setf (loom::%editor-completion-index completion) 1
            (editor-state-completion state) completion)
      (let ((*editor-state* state))
        (loom::%layout-draw-completion
         (editor-state-renderer state) window 0))
      (let ((screen (%layout-screen state)))
        (expect (cl-tty-kit:screen-row-string screen 1 :start 0 :end 3)
                :to-equal "one")
        (expect (cl-tty-kit:screen-row-string screen 2 :start 0 :end 3)
                :to-equal "two")
        (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 0 2))
                :to-equal '(:bold (:fg 0) (:bg 6)))))))

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

  (it
    "highlights a search match spanning multiple logical lines"
    (let* ((state (%fresh-layout-state :content "one two\nthree\nfour" :width 20 :height 3))
           (window (%layout-window state))
           (buffer (window-buffer window))
           (session (make-isearch-session buffer 0)))
       (setf (loom/feature/search::%isearch-matches session)
             (list (make-buffer-span 4 15)))
      (setf (editor-state-isearch state) session)
      (let ((*editor-state* state))
        (loom::%layout-draw-isearch
         (editor-state-renderer state) window 0))
      (let ((screen (%layout-screen state)))
        (expect (loop for row below 3
                      thereis (loop for column below 20
                                    thereis (cl-tty-kit:cell-style
                                             (cl-tty-kit:screen-cell
                                              screen column row))))
                :to-be-truthy))))

  (it
    "does not draw a match scrolled above the window"
    (let* ((state (%fresh-layout-state :content "one two one" :width 20 :height 1))
           (window (%layout-window state))
           (buffer (window-buffer window))
           (session (make-isearch-session buffer 0)))
      (isearch-apply-pattern session "two")
      (setf (window-scroll-line window) 1
            (editor-state-isearch state) session)
      (let ((*editor-state* state))
        (loom::%layout-draw-isearch
         (editor-state-renderer state) window 0))
      (expect (cl-tty-kit:cell-style
              (cl-tty-kit:screen-cell (%layout-screen state) 4 0))
              :to-be nil)))

  (it
    "draws a match at its horizontally scrolled position"
    (let* ((state (%fresh-layout-state :content "0123456789" :width 5 :height 1))
           (window (%layout-window state))
           (buffer (window-buffer window))
           (session (make-isearch-session buffer 0)))
      (isearch-apply-pattern session "67")
      (setf (window-scroll-column window) 4
            (editor-state-isearch state) session)
      (let ((*editor-state* state))
        (loom::%layout-draw-isearch
         (editor-state-renderer state) window 0))
      (expect (cl-tty-kit:cell-style
               (cl-tty-kit:screen-cell (%layout-screen state) 2 0))
              :to-equal '((:fg 0) (:bg 6)))))

  (it
    "draws the visible tail of a match clipped by horizontal scrolling"
    (let* ((state (%fresh-layout-state :content "0123456789" :width 5 :height 1))
           (window (%layout-window state))
           (buffer (window-buffer window))
           (session (make-isearch-session buffer 0)))
      (isearch-apply-pattern session "2345")
      (setf (window-scroll-column window) 4
            (editor-state-isearch state) session)
      (let ((*editor-state* state))
        (loom::%layout-draw-isearch
         (editor-state-renderer state) window 0))
      (expect (cl-tty-kit:cell-style
               (cl-tty-kit:screen-cell (%layout-screen state) 0 0))
              :to-equal '((:fg 0) (:bg 6)))))

  (it
    "does not draw a truncated match that is fully left of the viewport"
    (let* ((state (%fresh-layout-state :content "0123456789" :width 5 :height 1))
           (window (%layout-window state))
           (buffer (window-buffer window))
           (session (make-isearch-session buffer 0)))
      (isearch-apply-pattern session "01")
      (setf (window-scroll-column window) 6
            (editor-state-isearch state) session)
      (let ((*editor-state* state))
        (loom::%layout-draw-isearch
         (editor-state-renderer state) window 0))
      (expect (cl-tty-kit:cell-style
              (cl-tty-kit:screen-cell (%layout-screen state) 0 0))
              :to-be nil)))

  (it
    "does not draw a truncated match that is fully below the viewport"
    (let* ((state (%fresh-layout-state :content "first\nmatch" :width 20 :height 1))
           (window (%layout-window state))
           (buffer (window-buffer window))
           (session (make-isearch-session buffer 0)))
      (isearch-apply-pattern session "match")
      (setf (editor-state-isearch state) session)
      (let ((*editor-state* state))
        (loom::%layout-draw-isearch
         (editor-state-renderer state) window 0))
      (expect (cl-tty-kit:cell-style
               (cl-tty-kit:screen-cell (%layout-screen state) 0 0))
              :to-be nil)))

  (it
    "does not draw a truncated match that is fully right of the viewport"
    (let* ((state (%fresh-layout-state :content "0123456789" :width 5 :height 1))
           (window (%layout-window state))
           (buffer (window-buffer window))
           (session (make-isearch-session buffer 0)))
      (isearch-apply-pattern session "89")
      (let ((*editor-state* state))
        (setf (editor-state-isearch state) session)
        (loom::%layout-draw-isearch
         (editor-state-renderer state) window 0))
      (expect (cl-tty-kit:cell-style
              (cl-tty-kit:screen-cell (%layout-screen state) 4 0))
              :to-be nil)))

  (it
    "does not draw a match outside the buffer's visible region"
    (let* ((state (%fresh-layout-state :content "0123456789" :width 10 :height 1))
           (window (%layout-window state))
           (buffer (window-buffer window))
           (session (make-isearch-session buffer 0)))
      (buffer-narrow-to-region buffer 0 5 0 10)
      (setf (loom/feature/search::%isearch-matches session)
            (list (make-buffer-span 0 2))
            (editor-state-isearch state) session)
      (let ((*editor-state* state))
        (loom::%layout-draw-isearch
         (editor-state-renderer state) window 0))
      (expect (cl-tty-kit:cell-style
               (cl-tty-kit:screen-cell (%layout-screen state) 0 0))
              :to-be nil)))

  (it
    "does not draw isearch into a zero-sized window"
    (let* ((state (%fresh-layout-state :content "match" :width 0 :height 0
                                       :renderer-width 5 :renderer-height 1))
           (window (%layout-window state))
           (buffer (window-buffer window))
           (session (make-isearch-session buffer 0)))
      (isearch-apply-pattern session "match")
      (setf (editor-state-isearch state) session)
      (let ((*editor-state* state))
        (loom::%layout-draw-isearch
         (editor-state-renderer state) window 0))
      (expect (cl-tty-kit:cell-style
               (cl-tty-kit:screen-cell (%layout-screen state) 0 0))
              :to-be nil)))
