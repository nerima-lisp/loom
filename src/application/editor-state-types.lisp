;;;; src/application/editor-state-types.lisp
;;;;
;;;; Application layer: the top-level EDITOR-STATE struct and *EDITOR-STATE*
;;;; special variable that orchestrate domain and infrastructure objects
;;;; together -- this is the one mutable object every command function reads
;;;; and mutates.
;;;;
;;;; Every command (see application/commands-*.lisp) is a plain function of
;;;; zero arguments that reads and mutates the single special variable
;;;; *EDITOR-STATE*, rather than taking the editor state as an explicit
;;;; argument -- this is what lets a keymap binding be a bare function
;;;; designator (see KEYMAP-DEFINE-KEY/KEYMAP-STATE-DISPATCH in
;;;; domain/keymap.lisp).
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
                      (registers nil) (keyboard-macro nil)
                      (auto-save-mode-p nil)
                      (auto-save-buffers nil) (auto-save-last-run-at nil)
                      (format-on-save-p nil) (format-command nil)
                      (before-save-hooks nil) (after-save-hooks nil)
                      (terminal-sessions nil) (prefix-argument nil))))
  "The top-level, mutable state of a running loom editor session: the window
layout, the minibuffer, the top-level keymap, the file-tree sidebar, the
active renderer, and the shared kill ring, all in one place so a command can
reach any of them through *EDITOR-STATE* alone."
  ;; The WINDOW-TREE-* protocol object (domain/window.lisp) laying out every
  ;; visible buffer.
  window-tree
  ;; The WORKSPACE-MANAGER object owns the window tree for each named editor
  ;; view. Buffers remain shared through the session-wide registry below.
  workspaces
  ;; The MINIBUFFER-* protocol object (application/minibuffer.lisp) for
  ;; prompts and status messages.
  minibuffer
  ;; The top-level KEYMAP-* protocol object (domain/keymap.lisp) that global
  ;; key bindings are defined in.
  keymap
  ;; The FILE-TREE-* protocol object (domain/file-tree.lisp,
  ;; infrastructure/filesystem.lisp) for the sidebar file browser.
  file-tree
  ;; The main-lane-owned CCK runtime that refreshes file-tree listings.
  concurrent-runtime
  ;; The LOOM-RENDERER-* protocol object (infrastructure/terminal-renderer.lisp)
  ;; used to draw the current frame.
  renderer
  ;; Every buffer known to this editor session, including buffers not currently
  ;; displayed in a window. C-x b and quit confirmation use this registry.
  buffers
  ;; Canonical file paths in most-recent-first order. Commands update this
  ;; list after successful file visits and saves.
  (recent-files nil)
  ;; Named EDITOR-BOOKMARK objects keyed by their user-facing name. This is
  ;; initialized lazily so small test states need not know about the feature.
  (bookmarks nil)
  ;; The Emacs-style kill ring: a list of killed (cut/copied) strings, most
  ;; recent first, that yank (C-y) and yank-pop (M-y) commands consume.
  kill-ring
  ;; The range(s) inserted by the most recent YANK command.  YANK-POP replaces
  ;; these ranges in place and rotates LAST-YANK-RING-INDEX through the kill
  ;; ring, so ordinary commands clear these slots before the next command.
  (last-yank-buffer nil)
  (last-yank-start-offset nil)
  (last-yank-end-offset nil)
  (last-yank-ranges nil)
  (last-yank-ring-index nil)
  (last-yank-repeat-count nil)
  ;; Whether the preceding top-level command was a kill command.  Consecutive
  ;; kills use this to coalesce into one kill-ring entry, including kills made
  ;; through a repeated prefix argument.
  (last-command-kill-p nil)
  ;; Whether the most recently dispatched command (see src/main.lisp's
  ;; %DISPATCH-KEY-EVENT) was SELF-INSERT-COMMAND, used to decide when to
  ;; call BUFFER-RECORD-UNDO-BOUNDARY: consecutive self-insertions (ordinary
  ;; typing) stay grouped into one undo step, matching Emacs's usual feel,
  ;; while switching to or from any other command starts a new undo group.
  ;; Starts NIL for a new editor session.
  (last-command-self-insert-p nil)
  ;; The optional application-owned language-server session drained by the
  ;; render loop.
  (lsp-session nil)
  ;; The Emacs-style named registers.  This is initialized by MAIN rather than
  ;; by the struct definition so tests and extensions may provide their own
  ;; register bank when constructing EDITOR-STATE.
  (registers nil)
  ;; The currently defined keyboard macro and its recording/replay state.
  (keyboard-macro nil)
  ;; Global and per-buffer automatic-save state.  The event loop checks this
  ;; state after input dispatch without changing a buffer's normal modified
  ;; status.
  (auto-save-mode-p nil)
  (auto-save-buffers nil)
  (auto-save-last-run-at nil)
  ;; Optional external formatter used by the format feature.  A NIL command
  ;; keeps format-on-save inert until the user configures it explicitly.
  (format-on-save-p nil)
  (format-command nil)
  ;; Functions called before the bytes of an ordinary buffer save are
  ;; written.  The list is kept in registration order by
  ;; ADD-BEFORE-SAVE-HOOK and copied before dispatch so a hook may safely
  ;; register or remove another hook.
  (before-save-hooks nil)
  ;; Functions called after a successful ordinary buffer save.  The list is
  ;; kept in registration order by ADD-AFTER-SAVE-HOOK and is copied before
  ;; dispatch so a hook may safely register or remove another hook.
  (after-save-hooks nil)
  ;; Running PTY-backed terminal sessions and the pending prefix argument.
  (terminal-sessions nil)
  (prefix-argument nil))
