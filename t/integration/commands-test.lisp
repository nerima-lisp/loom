;;;; t/integration/commands-test.lisp
;;;;
;;;; Application layer: the command protocol (src/application/commands-*.lisp).
;;;; A representative sample, not one test per command: movement clamping at
;;;; buffer boundaries, a kill-line/yank round trip, UNDO-COMMAND actually
;;;; undoing, and INSTALL-DEFAULT-KEYBINDINGS's C-x C-s binding. Each test
;;;; binds a fresh *EDITOR-STATE* around real domain objects (MAKE-BUFFER,
;;;; MAKE-WINDOW-TREE, MAKE-KEYMAP) via %FRESH-EDITOR-STATE, or via
;;;; %WITH-MINIBUFFER-STATE where the command under test prompts; FILE-TREE
;;;; and RENDERER stay NIL unless a test installs one. Commands are
;;;; not exported from the LOOM package (see commands-internal.lisp's header
;;;; comment), so tests reach them via LOOM:: qualification, the same
;;;; precedent t/unit/file-tree-test.lisp already set for
;;;; LOOM::FILE-TREE-CHILD-LISTER.
(in-package #:loom/test)
