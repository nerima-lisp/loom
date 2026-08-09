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
      (%type-string minibuffer "other.t")
      (minibuffer-handle-key minibuffer (%special-key :tab))
      (expect (minibuffer-input-string minibuffer) :to-equal "other.txt")
      (minibuffer-handle-key minibuffer (%special-key :enter))
      (expect (buffer-name (window-buffer (window-tree-selected-window tree)))
              :to-equal "other.txt")))

  (it
    "switch-to-buffer reports an unknown buffer name"
    (%with-minibuffer-state (minibuffer "selected")
      (loom::switch-to-buffer)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "nope.txt")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "No such buffer: nope.txt"))))

(describe
  "buffer lifecycle commands"
  (it
    "kills a buffer from the registry and replaces every window displaying it"
    (%with-minibuffer-state
        (minibuffer "selected"
                    (tree (editor-state-window-tree *editor-state*))
                    (selected-buffer (%selected-test-buffer))
                    (other (make-buffer :name "other.txt"
                                        :initial-content "other")))
      (let ((selected (window-tree-selected-window tree)))
        (setf (editor-state-buffers *editor-state*)
              (cons other (editor-state-buffers *editor-state*)))
        (window-set-buffer selected other)
        (window-set-buffer (window-split tree selected :horizontal) other)
        (loom::kill-buffer)
        (%type-string minibuffer "other.t")
        (minibuffer-handle-key minibuffer (%special-key :tab))
        (expect (minibuffer-input-string minibuffer) :to-equal "other.txt")
        (minibuffer-handle-key minibuffer (%special-key :enter))
        (expect (find other (editor-state-buffers *editor-state*) :test #'eq)
                :to-be nil)
        (expect (every (lambda (window)
                         (eq (window-buffer window) selected-buffer))
                       (window-tree-windows tree))
                :to-be t))))

  (it
    "creates and registers a scratch replacement when killing the last buffer"
    (%with-minibuffer-state (minibuffer "draft")
      (let ((original (%selected-test-buffer)))
        (loom::kill-buffer)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "*scratch*")
        (expect (find original (editor-state-buffers *editor-state*) :test #'eq)
                :to-be nil)
        (expect (editor-state-buffers *editor-state*) :to-have-length 1)
        (expect (buffer-name (%selected-test-buffer)) :to-equal "*scratch*")
        (expect (%selected-test-buffer) :not :to-be original))))

  (it
    "saves a modified file buffer before killing it"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "draft.txt" directory)))
        (host-kit:write-file-string "draft" path)
        (%with-minibuffer-state
            (minibuffer "selected" (buffer (buffer-load path)))
          (setf (editor-state-buffers *editor-state*) (list buffer))
          (window-set-buffer
           (window-tree-selected-window (editor-state-window-tree *editor-state*))
           buffer)
          (buffer-insert-string buffer "!")
          (loom::kill-buffer)
          (funcall (loom::%minibuffer-on-confirm minibuffer) "draft.txt")
          (expect (minibuffer-prompt-string minibuffer)
                  :to-equal "Save draft.txt? (s/d/c): ")
          (funcall (loom::%minibuffer-on-confirm minibuffer) "s")
          (expect (host-kit:read-file-string path) :to-equal "!draft")
          (expect (find buffer (editor-state-buffers *editor-state*) :test #'eq)
                  :to-be nil)
          (expect (buffer-modified-p buffer) :to-be nil)))))

  (it
    "cancels and then discards a modified scratch buffer"
    (%with-minibuffer-state (minibuffer "draft")
      (let ((buffer (%selected-test-buffer)))
        (buffer-insert-string buffer "!")
        (loom::kill-buffer)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "*scratch*")
        (expect (minibuffer-prompt-string minibuffer)
                :to-equal "Discard changes to *scratch*? (d/c): ")
        (funcall (loom::%minibuffer-on-confirm minibuffer) "c")
        (expect (find buffer (editor-state-buffers *editor-state*) :test #'eq)
                :to-be buffer)
        (expect (buffer-modified-p buffer) :to-be t)
        (loom::kill-buffer)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "*scratch*")
        (funcall (loom::%minibuffer-on-confirm minibuffer) "d")
        (expect (find buffer (editor-state-buffers *editor-state*) :test #'eq)
                :to-be nil)))))
