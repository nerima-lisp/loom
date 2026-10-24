(in-package #:loom/test)

(defmacro %editor-state-accessor-contract-test ()
  (let ((state (gensym "STATE-"))
        (slot (gensym "SLOT-"))
        (accessor (gensym "ACCESSOR-")))
    `(it "exposes every public editor-state slot accessor"
         (let ((,state (make-editor-state :session (%make-test-editor-session))))
           (dolist
               (,slot
                '(window-tree workspaces
                              minibuffer
                              keymap
                              file-tree
                              concurrent-runtime
                              renderer
                              recent-files
                              bookmarks
                              kill-ring
                              last-yank-ranges
                              lsp-session
                              last-yank-buffer
                              last-yank-start-offset
                              last-yank-end-offset
                              last-yank-ring-index
                              last-yank-repeat-count
                              last-command-kill-p
                              last-command-self-insert-p
                              registers
                              keyboard-macro
                              isearch
                              completion
                              jump-origins
                              auto-save-mode-p
                              auto-save-buffers
                              auto-save-last-run-at
                              format-on-save-p
                              format-command
                              terminal-sessions
                              prefix-argument))
             (let ((,accessor
                    (intern (format nil "EDITOR-STATE-~A" ,slot)
                            (find-package :loom))))
               (expect (fboundp ,accessor) :to-be-truthy)
               (funcall ,accessor ,state)))))))

(%editor-state-accessor-contract-test)

(describe "editor-state default data" (it "creates the default workspace and keyboard macro state" (let* ((buffer (make-buffer :name "*scratch*")) (tree (make-window-tree buffer 80 24)) (state (make-editor-state :window-tree tree :session (%make-test-editor-session (list buffer) :window-tree tree)))) (expect (editor-state-workspaces state) :to-be-truthy) (expect (editor-state-keyboard-macro state) :to-be-truthy)))
          (it "preserves an explicitly supplied workspace manager" (let* ((buffer (make-buffer :name "*scratch*")) (tree (make-window-tree buffer 80 24)) (workspaces (loom/feature/workspace:make-workspace-manager tree :name "writing")) (state (make-editor-state :window-tree tree :workspaces workspaces :session (%make-test-editor-session (list buffer) :window-tree tree)))) (expect (editor-state-workspaces state) :to-be workspaces))) (it "rejects a window tree that differs from the session slice" (let* ((buffer (make-buffer :name "*scratch*")) (state-tree (make-window-tree buffer 80 24)) (session-tree (make-window-tree buffer 80 24))) (expect state-tree :not :to-be session-tree) (signals error (make-editor-state :window-tree state-tree :session (%make-test-editor-session (list buffer) :window-tree session-tree))))))
