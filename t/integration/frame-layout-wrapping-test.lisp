(in-package #:loom/test)

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
