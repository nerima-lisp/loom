(in-package #:loom/test)
(describe
  "movement commands"
  (it
    "clamps forward-char at the end of the buffer"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom::forward-char)
        (expect (buffer-point-line buffer) :to-equal 0)
        (expect (buffer-point-column buffer) :to-equal 2))))

  (it
    "forward-char crosses onto the next line at end-of-line"
    (let ((*editor-state* (%fresh-editor-state (format nil "hi~%there"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom::forward-char)
        (expect (buffer-point-line buffer) :to-equal 1)
        (expect (buffer-point-column buffer) :to-equal 0))))

  (it
    "clamps backward-char at the start of the buffer"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((buffer (%selected-test-buffer)))
        (loom::backward-char)
        (expect (buffer-point-line buffer) :to-equal 0)
        (expect (buffer-point-column buffer) :to-equal 0))))

  (it
    "backward-char moves back one column within a line"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom::backward-char)
        (expect buffer :to-have-point (cons 0 1)))))

  (it
    "backward-char wraps onto the end of the previous line at column 0"
    (let ((*editor-state* (%fresh-editor-state (format nil "hi~%there"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 1 0)
        (loom::backward-char)
        (expect buffer :to-have-point (cons 0 2)))))

  (it
    "next-line moves point down one line, clamping column to its length"
    (let ((*editor-state* (%fresh-editor-state (format nil "hello~%hi"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 4)
        (loom::next-line)
        (expect buffer :to-have-point (cons 1 2)))))

  (it
    "previous-line moves point up one line, clamping column to its length"
    (let ((*editor-state* (%fresh-editor-state (format nil "hi~%hello"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 1 4)
        (loom::previous-line)
        (expect buffer :to-have-point (cons 0 2)))))

  (it
    "move-end-of-line then move-beginning-of-line round-trips point"
    (let ((*editor-state* (%fresh-editor-state "hello")))
      (let ((buffer (%selected-test-buffer)))
        (loom::move-end-of-line)
        (expect (buffer-point-column buffer) :to-equal 5)
        (loom::move-beginning-of-line)
        (expect (buffer-point-column buffer) :to-equal 0))))

  (it
    "moves by words and reaches both buffer boundaries"
    (let ((*editor-state* (%fresh-editor-state "one two")))
      (let ((buffer (%selected-test-buffer)))
        (loom::forward-word)
        (expect buffer :to-have-point (cons 0 3))
        (loom::forward-word)
        (expect buffer :to-have-point (cons 0 7))
        (loom::beginning-of-buffer)
        (expect buffer :to-have-point (cons 0 0))
        (loom::end-of-buffer)
        (expect buffer :to-have-point (cons 0 7)))))

  (it
    "moves backward by words to the beginning of each previous word"
    (let ((*editor-state* (%fresh-editor-state "one, two")))
      (let ((buffer (%selected-test-buffer)))
        (loom::end-of-buffer)
        (loom::backward-word)
        (expect buffer :to-have-point (cons 0 5))
        (loom::backward-word)
        (expect buffer :to-have-point (cons 0 0)))))

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
(describe
  "window commands"
  (it
    "split-window-below adds a second window stacked below the first"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((tree (editor-state-window-tree *editor-state*)))
        (expect (length (window-tree-windows tree)) :to-equal 1)
        (loom::split-window-below)
        (expect (length (window-tree-windows tree)) :to-equal 2))))

  (it
    "split-window-right adds a second window beside the first"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((tree (editor-state-window-tree *editor-state*)))
        (loom::split-window-right)
        (expect (length (window-tree-windows tree)) :to-equal 2))))

  (it
    "other-window cycles back to the original window after a split"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let* ((tree (editor-state-window-tree *editor-state*))
             (original (window-tree-selected-window tree)))
        (loom::split-window-below)
        (expect (eq (window-tree-selected-window tree) original) :to-be nil)
        (loom::other-window)
        (expect (window-tree-selected-window tree) :to-be original))))

  (it
    "delete-window removes the selected split and restores the full layout"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let* ((tree (editor-state-window-tree *editor-state*))
             (original (window-tree-selected-window tree)))
        (loom::split-window-below)
        (loom::delete-window)
        (expect (window-tree-windows tree) :to-have-length 1)
        (expect (window-tree-selected-window tree) :to-be original)
        (expect (window-width original) :to-equal 80)
        (expect (window-height original) :to-equal 24))))

  (it
    "delete-other-windows keeps the selected pane and restores the full layout"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let* ((tree (editor-state-window-tree *editor-state*)))
        (loom::split-window-right)
        (loom::split-window-below)
        (let ((selected (window-tree-selected-window tree)))
          (loom::delete-other-windows)
          (expect (window-tree-windows tree) :to-have-length 1)
          (expect (window-tree-selected-window tree) :to-be selected)
          (expect (window-x selected) :to-equal 0)
          (expect (window-y selected) :to-equal 0)
          (expect (window-width selected) :to-equal 80)
          (expect (window-height selected) :to-equal 24)))))

  (it
    "switch-to-buffer displays a buffer already shown in another window"
    (%with-minibuffer-state (minibuffer "selected"
                             (tree (editor-state-window-tree *editor-state*))
                             (other (make-buffer :name "other.txt" :initial-content "other")))
      (setf (editor-state-buffers *editor-state*)
            (cons other (editor-state-buffers *editor-state*)))
      (window-set-buffer (window-split tree (window-tree-selected-window tree) :horizontal) other)
      (window-select-next tree)
      (loom::switch-to-buffer)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "other.txt")
      (expect (buffer-name (window-buffer (window-tree-selected-window tree)))
              :to-equal "other.txt")))

  (it
    "switch-to-buffer reports an unknown buffer name"
    (%with-minibuffer-state (minibuffer "selected")
      (loom::switch-to-buffer)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "nope.txt")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "No such buffer: nope.txt"))))
