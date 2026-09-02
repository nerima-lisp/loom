;;;; t/integration/layout-secondary-test.lisp
(in-package #:loom/test)

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
    "returns no origin when the completion anchor is below the window"
    (let* ((state (%fresh-layout-state :height 6 :renderer-height 6))
           (window (%layout-window state))
           (completion (loom::make-editor-completion
                        (window-buffer window) 20 0
                        (list (cons "one" "one")))))
      (expect (loom::%layout-completion-origin
               (editor-state-renderer state) window completion 6)
              :to-be nil)))
  (it
    "returns no origin when the completion anchor is above the window"
    (let* ((state (%fresh-layout-state :height 6 :renderer-height 6))
           (window (%layout-window state))
           (completion (loom::make-editor-completion
                        (window-buffer window) 0 0
                        (list (cons "one" "one")))))
      (setf (window-scroll-line window) 1)
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
