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

(defmacro with-layout-state ((name &rest initargs) &body body)
  "Run BODY with NAME bound to a fresh state suitable for layout tests."
  `(let ((,name (%fresh-layout-state ,@initargs)))
     ,@body))

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
        (expect (cl-tty-kit:screen-row-string screen 0) :to-equal before)))))

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
    "highlights a search match spanning two logical lines"
    (let* ((state (%fresh-layout-state :content "one two\nthree" :width 20 :height 2))
           (window (%layout-window state))
           (buffer (window-buffer window))
           (session (make-isearch-session buffer 0)))
       (setf (loom/feature/search::%isearch-matches session)
             (list (make-buffer-span 4 9)))
      (setf (editor-state-isearch state) session)
      (let ((*editor-state* state))
        (loom::%layout-draw-isearch
         (editor-state-renderer state) window 0))
      (let ((screen (%layout-screen state)))
        (expect (loop for row below 2
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

(describe
  "matching-parenthesis layout drawing"
  (it
    "marks both the adjacent parenthesis and its matching partner"
    (let* ((state (%fresh-layout-state :content "(abc)" :width 8 :height 1))
           (window (%layout-window state))
           (buffer (window-buffer window)))
      (buffer-set-point buffer 0 0)
      (loom::%layout-draw-matching-paren
       (editor-state-renderer state) window 0)
      (let ((screen (%layout-screen state)))
        (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 0 0))
                :to-equal '(:bold (:fg 0) (:bg 5)))
        (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 4 0))
                :to-equal '(:bold (:fg 0) (:bg 5)))))))

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

(describe
  "completion popup row preparation"
  (it
    "keeps the selected item centered when the candidate list is taller than the popup"
    (let ((completion
            (loom::make-editor-completion
             (make-buffer) 0 0
             (loop for index below 10 collect (cons (format nil "item-~D" index)
                                                    (format nil "text-~D" index))))) )
      (setf (loom::%editor-completion-index completion) 6)
      (multiple-value-bind (rows selected)
          (loom::%layout-completion-rows (make-loom-renderer 80 10) completion)
        (expect rows :to-equal '("item-2" "item-3" "item-4" "item-5"
                                 "item-6" "item-7" "item-8" "item-9"))
        (expect selected :to-equal 4))))
  (it
    "limits short labels to the popup width and reports their local selection"
    (let ((completion
            (loom::make-editor-completion
             (make-buffer) 0 0
             (list (cons "short" "short")
                   (cons "a-very-long-completion-label" "text")))))
      (setf (loom::%editor-completion-index completion) 1)
      (multiple-value-bind (rows selected)
          (loom::%layout-completion-rows (make-loom-renderer 80 10) completion)
        (expect rows :to-equal '("short" "a-very-long-completion-label"))
        (expect selected :to-equal 1))))
  (it
    "places the completion popup below the anchor when there is room"
    (let* ((state (%fresh-layout-state :height 12 :renderer-height 12))
           (window (%layout-window state))
           (completion (loom::make-editor-completion
                        (window-buffer window) 0 0
                        (list (cons "one" "one")))))
      (multiple-value-bind (column row)
          (loom::%layout-completion-origin
           (editor-state-renderer state) window completion 12)
        (expect (list column row) :to-equal '(0 1)))))
  (it
    "places the completion popup above the anchor when below is full"
    (let* ((state (%fresh-layout-state :height 12 :renderer-height 12))
           (window (%layout-window state))
           (completion (loom::make-editor-completion
                        (window-buffer window) 11 0
                        (list (cons "one" "one")))))
      (multiple-value-bind (column row)
          (loom::%layout-completion-origin
           (editor-state-renderer state) window completion 12)
        (expect (list column row) :to-equal '(0 10)))))
  (it
    "returns no origin when the popup fits neither above nor below"
    (let* ((state (%fresh-layout-state :height 6 :renderer-height 6))
           (window (%layout-window state))
           (completion (loom::make-editor-completion
                        (window-buffer window) 3 0
                        (loop for index below 8
                              collect (cons (format nil "item-~D" index)
                                            "text")))))
      (expect (loom::%layout-completion-origin
               (editor-state-renderer state) window completion 6)
              :to-be nil)))
  (it
    "ignores completion items belonging to another buffer"
    (let* ((state (%fresh-layout-state))
           (window (%layout-window state))
           (completion (loom::make-editor-completion
                        (make-buffer) 0 0
                        (list (cons "one" "one")))))
      (let ((*editor-state* state))
        (setf (editor-state-completion state) completion)
        (expect (loom::%layout-active-completion window)
                :to-be nil))))
  (it
    "ignores completion objects with no candidates"
    (let* ((state (%fresh-layout-state))
           (window (%layout-window state))
           (completion (loom::make-editor-completion
                        (window-buffer window) 0 0 nil)))
      (let ((*editor-state* state))
        (setf (editor-state-completion state) completion)
        (expect (loom::%layout-active-completion window)
                :to-be nil))))
  (it
    "does not draw completion popups into a zero-width renderer"
    (let* ((state (%fresh-layout-state :width 0 :height 6
                                       :renderer-width 0 :renderer-height 6))
           (window (%layout-window state))
           (completion (loom::make-editor-completion
                        (window-buffer window) 0 0
                        (list (cons "one" "one")))))
      (setf (editor-state-completion state) completion)
      (let ((*editor-state* state))
        (loom::%layout-draw-completion
         (editor-state-renderer state) window 0))
      (expect (cl-tty-kit:screen-row-string (%layout-screen state) 0)
              :to-equal ""))))
