(in-package #:loom/test)

(describe
  "movement commands scrolling and line editing"
  (it
    "scrolls by pages and clamps at both viewport boundaries"
    (let ((*editor-state*
            (%fresh-editor-state
             (with-output-to-string (stream)
               (dotimes (line 50)
                 (when (plusp line)
                   (terpri stream))
                 (format stream "line~D" line))))))
      (let ((window
              (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))))
        (loom/feature/window:scroll-up-command)
        (expect (window-scroll-line window) :to-equal 23)
        (loom/feature/window:scroll-up-command)
        (expect (window-scroll-line window) :to-equal 26)
        (loom/feature/window:scroll-down-command)
        (expect (window-scroll-line window) :to-equal 3)
        (loom/feature/window:scroll-down-command)
        (expect (window-scroll-line window) :to-equal 0))))

  (it
    "inserts a newline and advances point"
    (let ((*editor-state* (%fresh-editor-state "hello")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom::newline-command)
        (expect (buffer-text buffer) :to-equal (format nil "he~%llo"))
        (expect (buffer-point-line buffer) :to-equal 1)
        (expect (buffer-point-column buffer) :to-equal 0))))

  (it
    "opens a line without moving point"
    (let ((*editor-state* (%fresh-editor-state "hello")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom::open-line)
        (expect (buffer-text buffer) :to-equal (format nil "he~%llo"))
        (expect (buffer-point-line buffer) :to-equal 0)
        (expect (buffer-point-column buffer) :to-equal 2))))

  (it
    "falls back to logical movement when visual layout is unavailable"
    (let ((*editor-state* (%fresh-editor-state (format nil "first~%second")))
          (loom::*visual-row-layout-function* nil))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 1)
        (next-visual-line-once)
        (expect (buffer-point-line buffer) :to-equal 1)
        (expect (buffer-point-column buffer) :to-equal 1)))))
