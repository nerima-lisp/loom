;;;; src/application/editor-state.lisp
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

(defstruct editor-state
  "The top-level, mutable state of a running loom editor session: the window
layout, the minibuffer, the top-level keymap, the file-tree sidebar, the
active renderer, and the shared kill ring, all in one place so a command can
reach any of them through *EDITOR-STATE* alone."
  ;; The WINDOW-TREE-* protocol object (domain/window.lisp) laying out every
  ;; visible buffer.
  window-tree
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
  ;; The Emacs-style kill ring: a list of killed (cut/copied) strings, most
  ;; recent first, that yank (C-y) and yank-pop (M-y) commands consume.
  kill-ring
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
  ;; The pending Emacs-style universal or numeric prefix argument.
  (prefix-argument nil))

(defvar *editor-state* nil
  "The single, dynamically-bound EDITOR-STATE struct that every command
function (see application/commands-*.lisp) reads and mutates. Bound to a
freshly created EDITOR-STATE by loom's entry point (see MAIN in src/main.lisp)
before any command runs, and NIL otherwise.")
