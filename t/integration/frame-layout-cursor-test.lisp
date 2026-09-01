;;;; t/integration/frame-layout-cursor-test.lisp

(in-package #:loom/test)

(describe
  "compose-frame"
  (it
    "uses the only terminal row for the minibuffer when shortcuts cannot fit"
    (let* ((state (%fresh-layout-state :name "*scratch*"
                                       :content "hidden"
                                       :width 20
                                       :height 1))
           (minibuffer (editor-state-minibuffer state)))
      (minibuffer-message minibuffer "status")
      (loom::compose-frame state)
      (expect (cl-tty-kit:screen-row-string (%layout-screen state) 0)
              :to-equal "status              ")))

  (it
    "truncates the shortcut line to fit a narrow terminal"
    (let ((state (%fresh-layout-state :name "*scratch*" :content "hi" :width 10)))
      (loom::compose-frame state)
      (expect (cl-tty-kit:screen-row-string (%layout-screen state) 4)
              :to-equal "Ln 1, Col ")))

  (it
    "draws the active minibuffer prompt and input, truncated to a narrow terminal"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "hi" :width 10))
           (minibuffer (editor-state-minibuffer state)))
      (minibuffer-activate minibuffer "Find file: ")
      (loom::compose-frame state)
      (expect (cl-tty-kit:screen-row-string (%layout-screen state) 5)
              :to-equal "Find file:")))

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
  "%layout-keep-point-visible"
  (it
    "does nothing for a zero-height window"
    (let* ((state (%fresh-layout-state :content (format nil "one~%two~%three")
                                       :width 20
                                       :height 4))
           (window (%layout-window state)))
      (buffer-set-point (window-buffer window) 2 0)
      (setf (loom/feature/window::window-leaf-height window) 0)
      (setf (window-scroll-line window) 0)
      (loom::%layout-keep-point-visible (editor-state-renderer state) window)
      (expect (window-scroll-line window) :to-equal 0)))

  (it
    "does nothing for a zero-width window"
    (let* ((state (%fresh-layout-state :content "abcdefghijkl"
                                       :width 20
                                       :height 4))
           (window (%layout-window state)))
      (setf (loom/feature/window::window-leaf-width window) 0
            (window-scroll-column window) 3)
      (buffer-set-point (window-buffer window) 0 10)
      (loom::%layout-keep-point-visible (editor-state-renderer state) window)
      (expect (window-scroll-column window) :to-equal 3)))

  (it
    "does nothing for a zero-width wrapped window"
    (let* ((state (%fresh-layout-state :content "abcdefghijkl"
                                       :width 20
                                       :height 4))
           (window (%layout-window state)))
      (buffer-set-truncate-lines (window-buffer window) nil)
      (setf (loom/feature/window::window-leaf-width window) 0
            (window-scroll-line window) 2
            (window-scroll-sub-row window) 1)
      (buffer-set-point (window-buffer window) 0 10)
      (loom::%layout-keep-point-visible (editor-state-renderer state) window)
      (expect (window-scroll-line window) :to-equal 2)
      (expect (window-scroll-sub-row window) :to-equal 1)))

  (it
    "scrolls a wrapped window upward within the same logical line"
    (let* ((state (%fresh-wrapping-state :content "abcdefghijkl" :width 5 :height 4))
           (window (%layout-window state)))
      (setf (window-scroll-line window) 0
            (window-scroll-sub-row window) 2)
      (buffer-set-point (window-buffer window) 0 1)
      (loom::%layout-keep-point-visible (editor-state-renderer state) window)
      (expect (window-scroll-line window) :to-equal 0)
      (expect (window-scroll-sub-row window) :to-equal 0)))

  (it
    "keeps a wrapped point in place when it is already inside the viewport"
    (let* ((state (%fresh-wrapping-state
                   :content (format nil "abcdefghij~%second")
                   :width 5
                   :height 4))
           (window (%layout-window state)))
      (setf (window-scroll-line window) 0
            (window-scroll-sub-row window) 1)
      (buffer-set-point (window-buffer window) 0 7)
      (loom::%layout-keep-point-visible (editor-state-renderer state) window)
      (expect (window-scroll-line window) :to-equal 0)
      (expect (window-scroll-sub-row window) :to-equal 1)))

  (it-each
      ((0 25 6 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
       (0 19 0 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
       (25 5 5 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
       (6 10 6 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
       (0 12 5 "あああああああああああああああ"))
      "from scroll column ~D, point at character ~D scrolls to ~D"
      (scroll-column column expected content)
    (let* ((state (%fresh-layout-state :content content :width 20 :height 6))
           (window (%layout-window state)))
      (setf (window-scroll-column window) scroll-column)
      (buffer-set-point (window-buffer window) 0 column)
      (loom::%layout-keep-point-visible (editor-state-renderer state) window)
      (expect (window-scroll-column window) :to-equal expected))))

(describe
  "editor-cursor with a horizontally scrolled window"
  (it
    "reports the cursor relative to the window's scroll column"
    (let* ((state (%fresh-layout-state
                   :content "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                   :width 20
                   :height 6))
           (window (%layout-window state)))
      (buffer-set-point (window-buffer window) 0 25)
      (loom::compose-frame state)
      (expect (window-scroll-column window) :to-equal 6)
      (expect (cl-tty-kit:cursor-x (loom::editor-cursor state))
              :to-equal 19)))

  (it
    "brings a point left of the viewport back into view"
    (let* ((state (%fresh-layout-state
                   :content "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                   :width 20
                   :height 6))
           (window (%layout-window state)))
      (setf (window-scroll-column window) 12)
      (buffer-set-point (window-buffer window) 0 3)
      (loom::compose-frame state)
      (expect (window-scroll-column window) :to-equal 3)
      (expect (cl-tty-kit:cursor-x (loom::editor-cursor state))
              :to-equal 0))))

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
      (expect (cl-tty-kit:cursor-visible-p (loom::editor-cursor state))
              :to-be nil)))

  (it-each
      (("あいう" 3 6)
       ("あいう" 1 2)
       ("aあb" 2 3)
       ("hello" 3 3)
       ("" 0 0))
      "places point in ~S at character ~D on screen column ~D"
      (content column expected)
    (let ((state (%fresh-layout-state :content content)))
      (buffer-set-point (window-buffer (%layout-window state)) 0 column)
      (expect (cl-tty-kit:cursor-x (loom::editor-cursor state))
              :to-equal expected))))

(describe
  "editor-cursor with an active minibuffer"
  (it
    "follows full-width minibuffer input instead of staying in the window"
    (let* ((state (%fresh-layout-state :content "hello"))
           (minibuffer (editor-state-minibuffer state)))
      (buffer-set-point (window-buffer (%layout-window state)) 0 1)
      (minibuffer-activate minibuffer "検索: ")
      (dolist (character '(#\あ #\い))
        (minibuffer-handle-key
         minibuffer
         (cl-tty-kit:make-key-event :type :character :code character)))
      (expect (minibuffer-input-string minibuffer) :to-equal "あい")
      (let ((cursor (loom::editor-cursor state)))
        (expect (cl-tty-kit:cursor-x cursor) :to-equal 10)
        (expect (cl-tty-kit:cursor-y cursor) :to-equal 5))))

  (it
    "sits immediately after the prompt before anything is typed"
    (let* ((state (%fresh-layout-state :content "hello"))
           (minibuffer (editor-state-minibuffer state)))
      (minibuffer-activate minibuffer "Find file: ")
      (let ((cursor (loom::editor-cursor state)))
        (expect (cl-tty-kit:cursor-x cursor) :to-equal 11)
        (expect (cl-tty-kit:cursor-y cursor) :to-equal 5)))))

(defun %fresh-wrapping-state (&key content (width 20) (height 6))
  "A layout state whose buffer wraps, so screen rows outnumber logical lines."
  (let ((state (%fresh-layout-state :content content
                                    :width width
                                    :height height)))
    (buffer-set-truncate-lines (window-buffer (%layout-window state)) nil)
    state))

(describe
  "wrapped windows"
  (it
    "draws a long logical line across consecutive rows"
    (let* ((state (%fresh-wrapping-state :content "abcdefghijkl"
                                         :width 5
                                         :height 6))
           (screen (%layout-screen state)))
      (loom::compose-frame state)
      (expect (cl-tty-kit:screen-row-string screen 0 :start 0 :end 5)
              :to-equal "abcde")
      (expect (cl-tty-kit:screen-row-string screen 1 :start 0 :end 5)
              :to-equal "fghij")
      (expect (cl-tty-kit:screen-row-string screen 2 :start 0 :end 5)
              :to-equal "kl   ")))

  (it
    "never splits a full-width character across two rows"
    (let* ((state (%fresh-wrapping-state :content "あいうえお"
                                         :width 5
                                         :height 6))
           (screen (%layout-screen state)))
      (loom::compose-frame state)
      (expect (cl-tty-kit:screen-row-string screen 0 :start 0 :end 5)
              :to-equal "あ い  ")
      (expect (cl-tty-kit:screen-row-string screen 1 :start 0 :end 5)
              :to-equal "う え  ")
      (expect (cl-tty-kit:screen-row-string screen 2 :start 0 :end 5)
              :to-equal "お    ")))

  (it-each
      ((0 0 0)
       (5 0 1)
       (7 2 1)
       (10 0 2)
       (12 2 2))
      "puts point at character ~D on cell ~D of row ~D"
      (column expected-x expected-row)
    (let ((state (%fresh-wrapping-state :content "abcdefghijkl"
                                        :width 5
                                        :height 6)))
      (buffer-set-point (window-buffer (%layout-window state)) 0 column)
      (loom::compose-frame state)
      (let ((cursor (loom::editor-cursor state)))
        (expect (cl-tty-kit:cursor-x cursor) :to-equal expected-x)
        (expect (cl-tty-kit:cursor-y cursor) :to-equal expected-row))))

  (it
    "scrolls into the middle of one long line without dropping its start"
    (let* ((state (%fresh-wrapping-state
                   :content "abcdefghijklmnopqrstuvwxyz"
                   :width 5
                   :height 4))
           (window (%layout-window state))
           (screen (%layout-screen state)))
      (buffer-set-point (window-buffer window) 0 25)
      (loom::compose-frame state)
      (expect (window-scroll-line window) :to-equal 0)
      (expect (window-scroll-sub-row window) :to-equal 4)
      (expect (cl-tty-kit:screen-row-string screen 0 :start 0 :end 5)
              :to-equal "uvwxy")
      (expect (cl-tty-kit:cursor-y (loom::editor-cursor state))
              :to-equal 1)))

  (it
    "keeps goto-line on logical line numbers, not screen rows"
    (let* ((state (%fresh-wrapping-state
                   :content (format nil "abcdefghijkl~%second~%third")
                   :width 5
                   :height 6))
           (*editor-state* state)
           (buffer (window-buffer (%layout-window state))))
      (loom::compose-frame state)
      (loom::%goto-visible-line-input (editor-state-minibuffer state) "3")
      (expect (buffer-point-line buffer) :to-equal 2)
      (expect (buffer-line buffer (buffer-point-line buffer))
              :to-equal "third"))))

(describe
  "next-line and previous-line in a wrapping window"
  (it-each
      ((2 :next 0 7 "abcdefghijkl")
       (7 :next 0 12 "abcdefghijkl")
       (12 :next 0 12 "abcdefghijkl")
       (7 :previous 0 2 "abcdefghijkl")
       (2 :previous 0 2 "abcdefghijkl")
       (1 :next 0 3 "あいうえお")
       (3 :previous 0 1 "あいうえお"))
      "from character ~D, ~A lands on line ~D column ~D"
      (column direction expected-line expected-column content)
    (let* ((state (%fresh-wrapping-state :content content
                                         :width 5
                                         :height 6))
           (*editor-state* state)
           (buffer (window-buffer (%layout-window state))))
      (loom::compose-frame state)
      (buffer-set-point buffer 0 column)
      (if (eq direction :next) (loom::next-line) (loom::previous-line))
      (expect (buffer-point-line buffer) :to-equal expected-line)
      (expect (buffer-point-column buffer) :to-equal expected-column)))

  (it
    "crosses into the next logical line's first row, keeping the goal cell"
    (let* ((state (%fresh-wrapping-state
                   :content (format nil "abcdefghij~%xyz")
                   :width 5
                   :height 6))
           (*editor-state* state)
           (buffer (window-buffer (%layout-window state))))
      (loom::compose-frame state)
      (buffer-set-point buffer 0 7)
      (loom::next-line)
      (expect (buffer-point-line buffer) :to-equal 1)
      (expect (buffer-point-column buffer) :to-equal 2)
      (loom::previous-line)
      (expect (buffer-point-line buffer) :to-equal 0)
      (expect (buffer-point-column buffer) :to-equal 7)))

  (it
    "keeps logical line movement when the buffer truncates instead"
    (let* ((state (%fresh-layout-state
                   :content (format nil "abcdefghijkl~%xy")
                   :width 5
                   :height 6))
           (*editor-state* state)
           (buffer (window-buffer (%layout-window state))))
      (loom::compose-frame state)
      (buffer-set-point buffer 0 7)
      (loom::next-line)
      (expect (buffer-point-line buffer) :to-equal 1)
      (expect (buffer-point-column buffer) :to-equal 2))))

(describe
  "shortcut line column indicator"
  (it
    "reports Col in screen cells rather than characters"
    (let ((state (%fresh-layout-state :name "*scratch*" :content "あいう")))
      (buffer-set-point (window-buffer (%layout-window state)) 0 2)
      (loom::compose-frame state)
      (expect (search "Ln 1, Col 5"
                      (cl-tty-kit:screen-row-string (%layout-screen state) 4))
              :to-be-truthy))))
