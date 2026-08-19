(in-package #:loom/test)
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
        (loom/feature/window:kill-buffer)
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
        (loom/feature/window:kill-buffer)
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
          (loom/feature/window:kill-buffer)
          (funcall (loom::%minibuffer-on-confirm minibuffer) "draft.txt")
          (%expect-minibuffer-prompt minibuffer (%save-buffer-prompt-string buffer))
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
        (loom/feature/window:kill-buffer)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "*scratch*")
        (%expect-minibuffer-prompt minibuffer (%discard-buffer-prompt-string buffer))
        (funcall (loom::%minibuffer-on-confirm minibuffer) "c")
        (expect (find buffer (editor-state-buffers *editor-state*) :test #'eq)
                :to-be buffer)
        (expect (buffer-modified-p buffer) :to-be t)
        (loom/feature/window:kill-buffer)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "*scratch*")
        (funcall (loom::%minibuffer-on-confirm minibuffer) "d")
        (expect (find buffer (editor-state-buffers *editor-state*) :test #'eq)
                :to-be nil)))))

  (it
    "reports an unknown buffer and can cancel the kill prompt"
    (%with-minibuffer-state (minibuffer "selected")
      (loom/feature/window:kill-buffer)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "missing")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "No such buffer: missing")
      (loom/feature/window:kill-buffer)
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")))

  (it
    "re-prompts on an invalid modified-buffer answer and cancels the nested prompt"
    (%with-minibuffer-state (minibuffer "draft")
      (let ((buffer (%selected-test-buffer)))
        (buffer-insert-string buffer "!")
        (loom/feature/window:kill-buffer)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "*scratch*")
        (funcall (loom::%minibuffer-on-confirm minibuffer) "x")
        (%expect-minibuffer-prompt minibuffer (%discard-buffer-prompt-string buffer))
        (minibuffer-handle-key minibuffer (%special-key :control-g))
        (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")
        (expect (find buffer (editor-state-buffers *editor-state*) :test #'eq)
                :to-be buffer))))
