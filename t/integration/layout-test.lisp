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
  "minibuffer drawing"
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
  "mode line construction"
  (it
    "lists buffer state, name, major mode, point, and display mode"
    (let* ((renderer (make-loom-renderer 80 1))
           (buffer (make-buffer :name "notes.lisp" :initial-content "abc")))
      (buffer-set-major-mode buffer :common-lisp)
      (buffer-set-point buffer 0 1)
      (expect (loom::%layout-mode-line-text renderer buffer)
              :to-equal "-- notes.lisp  Common Lisp  Ln 1, Col 2  Truncate")))

  (it
    "shows modified and read-only markers and wrap mode"
    (let* ((renderer (make-loom-renderer 80 1))
           (buffer (make-buffer :name "README.md" :initial-content "text")))
      (buffer-set-major-mode buffer :markdown)
      (buffer-mark-modified buffer)
      (buffer-set-read-only buffer t)
      (expect (loom::%layout-mode-line-text renderer buffer)
              :to-equal "*% README.md  Markdown  Ln 1, Col 1  Wrap")))

  (it
    "keeps full-width buffer names and point columns in screen cells"
    (let* ((renderer (make-loom-renderer 80 1))
           (buffer (make-buffer :name "日本語" :initial-content "あいう")))
      (buffer-set-point buffer 0 2)
      (expect (loom::%layout-mode-line-text renderer buffer)
              :to-equal "-- 日本語  Fundamental  Ln 1, Col 5  Truncate")))

  (it
    "clips a long mode line from the right at a cell boundary"
    (let* ((renderer (make-loom-renderer 14 1))
           (buffer (make-buffer :name "very-long-buffer-name")))
      (expect (loom::%layout-mode-line renderer buffer)
              :to-equal "-- very-long-b")
      (expect (loom-renderer-string-width
               renderer (loom::%layout-mode-line renderer buffer))
              :to-equal 14)))

  (it
    "distinguishes selected and unselected leaf mode lines"
    (let* ((state (%fresh-layout-state :width 40 :height 6))
           (tree (editor-state-window-tree state))
           (left (window-tree-selected-window tree))
           (right (window-split tree left :vertical)))
      (window-set-buffer left (make-buffer :name "left"))
      (window-set-buffer right (make-buffer :name "right"))
      (loom::compose-frame state)
      (let ((screen (%layout-screen state)))
        (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 0 4))
                :to-equal '((:fg 8)))
        (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 20 4))
                :to-equal '(:reverse))))))

(describe
  "mode line frame height accounting"
  (it
    "leaves the only row for the minibuffer"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "body"
                                       :height 1))
           (minibuffer (editor-state-minibuffer state)))
      (minibuffer-message minibuffer "status")
      (loom::compose-frame state)
      (expect (search "*scratch*"
                      (cl-tty-kit:screen-row-string (%layout-screen state) 0))
              :to-be nil)
      (expect (cl-tty-kit:screen-row-string (%layout-screen state) 0)
              :to-equal (cl-tty-kit:pad-string "status" 40))))

  (it
    "uses the first row for a mode line at terminal height two"
    (let ((state (%fresh-layout-state :name "*scratch*" :content "body"
                                      :height 2)))
      (loom::compose-frame state)
      (expect (search "*scratch*"
                      (cl-tty-kit:screen-row-string (%layout-screen state) 0))
              :to-be-truthy)
      (expect (window-height (%layout-window state)) :to-equal 1)
      (expect (cl-tty-kit:screen-row-string (%layout-screen state) 1)
              :to-equal (cl-tty-kit:pad-string "" 40))))

  (it
    "keeps buffer content, mode line, and minibuffer rows separate"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "body"
                                       :height 6))
           (minibuffer (editor-state-minibuffer state)))
      (minibuffer-message minibuffer "status")
      (loom::compose-frame state)
      (expect (cl-tty-kit:screen-row-string (%layout-screen state) 0
                                             :start 0 :end 4)
              :to-equal "body")
      (expect (search "*scratch*"
                      (cl-tty-kit:screen-row-string (%layout-screen state) 4))
              :to-be-truthy)
      (expect (cl-tty-kit:screen-row-string (%layout-screen state) 5
                                             :start 0 :end 6)
              :to-equal "status"))))
