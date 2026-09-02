;;;; t/integration/commands-editing-quit-test.lisp
;;;;
;;;; Quit flow integration tests for editing commands.
(in-package #:loom/test)

(describe
  "save-buffers-kill-terminal"
  (it
    "quits immediately when no buffer has unsaved changes"
    (%with-minibuffer-state (minibuffer "clean" (quit nil))
      (%capturing-loom-quit (quit)
        (loom::save-buffers-kill-terminal)
        (expect quit :to-be t))
      (expect (minibuffer-active-p minibuffer) :to-be-falsy)))

  (it
    "asks about a modified file buffer shown in a nonselected split"
    (host-kit:with-temporary-directory (dir)
      (%with-minibuffer-state (minibuffer "selected"
                               (tree (editor-state-window-tree *editor-state*))
                               (other (make-buffer :name "other.txt"
                                                   :path (merge-pathnames "other.txt" dir)
                                                   :initial-content "other"))
                               (quit nil))
        (let ((other-window (window-split tree
                                          (window-tree-selected-window tree)
                                          :horizontal)))
          (window-set-buffer other-window other))
        (window-select-next tree)
        (buffer-insert-string other "!")
        (loom::save-buffers-kill-terminal)
        (%expect-minibuffer-prompt minibuffer (%save-buffer-prompt-string other))
        (%capturing-loom-quit (quit)
          (%confirm-minibuffer minibuffer "d"))
        (expect quit :to-be t))))

  (it
    "saves one modified split buffer before prompting for the next"
    (host-kit:with-temporary-directory (dir)
      (%with-minibuffer-state (minibuffer "selected"
                               (tree (editor-state-window-tree *editor-state*))
                               (first (make-buffer :name "first.txt"
                                                   :path (merge-pathnames "first.txt" dir)
                                                   :initial-content "first"))
                               (second (make-buffer :name "second.txt"
                                                    :path (merge-pathnames "second.txt" dir)
                                                    :initial-content "second"))
                               (quit nil))
        (window-set-buffer (window-tree-selected-window tree) first)
        (let ((second-window (window-split tree
                                           (window-tree-selected-window tree)
                                           :horizontal)))
          (window-set-buffer second-window second))
        (buffer-insert-string first "!")
        (buffer-insert-string second "!")
        (loom::save-buffers-kill-terminal)
        (%expect-minibuffer-prompt minibuffer (%save-buffer-prompt-string first))
        (funcall (loom::%minibuffer-on-confirm minibuffer) "s")
        (expect (buffer-modified-p first) :to-be nil)
        (%expect-minibuffer-prompt minibuffer (%save-buffer-prompt-string second))
        (%capturing-loom-quit (quit)
          (%confirm-minibuffer minibuffer "d"))
        (expect quit :to-be t))))

  (it
    "cancels quit without discarding a modified scratch buffer"
    (%with-modified-selected-minibuffer-buffer (minibuffer buffer "draft" (quit nil))
      (loom::save-buffers-kill-terminal)
      (%expect-minibuffer-prompt minibuffer (%discard-buffer-prompt-string buffer))
      (%capturing-loom-quit (quit)
        (%confirm-minibuffer minibuffer "c"))
      (expect quit :to-be nil)
      (expect (buffer-modified-p buffer) :to-be t)))

  (it
    "re-prompts on an unrecognized answer instead of quitting or discarding"
    (%with-modified-selected-minibuffer-buffer (minibuffer buffer "draft" (quit nil))
      (loom::save-buffers-kill-terminal)
      (%capturing-loom-quit (quit)
        (%confirm-minibuffer minibuffer "not-a-valid-answer"))
      (expect quit :to-be nil)
      (expect (buffer-modified-p buffer) :to-be t)
      (%expect-minibuffer-prompt minibuffer (%discard-buffer-prompt-string buffer)))))

(describe
  "quit buffer registry"
  (it
    "prompts for a modified registered buffer that is not displayed"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "hidden.txt" directory)))
        (host-kit:write-file-string "hidden" path)
        (%with-minibuffer-state
            (minibuffer "selected"
                        (hidden (buffer-load path))
                        (quit nil))
          (setf (editor-state-buffers *editor-state*)
                (cons hidden (editor-state-buffers *editor-state*)))
          (buffer-insert-string hidden "!")
          (loom::save-buffers-kill-terminal)
          (%expect-minibuffer-prompt minibuffer (%save-buffer-prompt-string hidden))
          (%capturing-loom-quit (quit)
            (%confirm-minibuffer minibuffer "d"))
          (expect quit :to-be t))))))
