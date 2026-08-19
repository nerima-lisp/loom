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
              (window-tree-selected-window
               (editor-state-window-tree *editor-state*))))
        (loom::scroll-up-command)
        (expect (window-scroll-line window) :to-equal 23)
        (loom::scroll-up-command)
        (expect (window-scroll-line window) :to-equal 26)
        (loom::scroll-down-command)
        (expect (window-scroll-line window) :to-equal 3)
        (loom::scroll-down-command)
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
        (expect (buffer-point-column buffer) :to-equal 2)))))
