(in-package #:loom)

(defstruct (editor-state
            (:constructor %make-editor-state
                (&key window-tree workspaces minibuffer keymap file-tree
                      concurrent-runtime renderer buffers
                      (recent-files nil) (bookmarks nil) kill-ring
                      (last-yank-buffer nil) (last-yank-start-offset nil)
                      (last-yank-end-offset nil) (last-yank-ranges nil)
                      (last-yank-ring-index nil) (last-yank-repeat-count nil)
                      (last-command-kill-p nil)
                      (last-command-self-insert-p nil) (lsp-session nil)
                      (registers nil)
                      (keyboard-macro
                       (loom/feature/keyboard-macro:make-keyboard-macro))
                      (isearch nil)
                      (jump-origins nil)
                      (completion nil) (auto-save-mode-p nil)
                      (auto-save-buffers nil) (auto-save-last-run-at nil)
                      (format-on-save-p nil) (format-command nil)
                      (before-save-hooks nil) (after-save-hooks nil)
                      (terminal-sessions nil) (prefix-argument nil))))
  "The top-level, mutable state of a running loom editor session: the window
layout, the minibuffer, the top-level keymap, the file-tree sidebar, the
active renderer, and the shared kill ring, all in one place so a command can
reach any of them through *EDITOR-STATE* alone."
  window-tree
  workspaces
  minibuffer
  keymap
  file-tree
  concurrent-runtime
  renderer
  buffers
  (recent-files nil)
  (bookmarks nil)
  kill-ring
  (last-yank-buffer nil)
  (last-yank-start-offset nil)
  (last-yank-end-offset nil)
  (last-yank-ranges nil)
  (last-yank-ring-index nil)
  (last-yank-repeat-count nil)
  (last-command-kill-p nil)
  (last-command-self-insert-p nil)
  (lsp-session nil)
  (registers nil)
  keyboard-macro
  (isearch nil)
  (completion nil)
  (jump-origins nil)
  (auto-save-mode-p nil)
  (auto-save-buffers nil)
  (auto-save-last-run-at nil)
  (format-on-save-p nil)
  (format-command nil)
  (before-save-hooks nil)
  (after-save-hooks nil)
  (terminal-sessions nil)
  (prefix-argument nil))
