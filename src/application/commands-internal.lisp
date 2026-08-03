;;;; src/application/commands-internal.lisp
;;;;
;;;; Application layer: commands are the use-case entry points a keymap
;;;; binding invokes, split by concern (movement, editing, search, file,
;;;; window, misc, keybindings) into the sibling application/commands-*.lisp
;;;; files this one is loaded ahead of.
;;;;
;;;; Commands are NOT declared as generic functions: each editable command is
;;;; a plain, ordinary function of zero arguments that reads and mutates
;;;; *EDITOR-STATE* (see application/editor-state.lisp) and the protocol
;;;; operations declared in domain/, infrastructure/, and application/ when
;;;; invoked, e.g.:
;;;;
;;;;   (defun forward-char ()
;;;;     "Move point forward one character in the selected window's buffer."
;;;;     (let ((window (window-tree-selected-window
;;;;                    (editor-state-window-tree *editor-state*))))
;;;;       (buffer-set-point (window-buffer window) ...)))
;;;;
;;;; A keymap binds a key sequence directly to such a function (see
;;;; KEYMAP-DEFINE-KEY), so command names are the vocabulary keymap bindings
;;;; are written against. Commands are named after their Emacs equivalents
;;;; where one exists (FORWARD-CHAR, KILL-LINE, SAVE-BUFFER, ...) so the
;;;; mapping from a keybinding to its behavior stays obvious from
;;;; domain/keymap.lisp alone.
;;;;
;;;; None of the commands in this file or its siblings are exported from the
;;;; LOOM package (see src/package.lisp's header comment describing its
;;;; export list as "the fixed contract, only the file layout moved" --
;;;; adding a whole new export section here is out of scope);
;;;; INSTALL-DEFAULT-KEYBINDINGS and MAIN (same package) refer to them
;;;; unqualified, and tests reach them via LOOM:: qualification, the same
;;;; precedent t/file-tree-test.lisp already set for
;;;; LOOM::FILE-TREE-CHILD-LISTER.
;;;;
;;;; %SELECTED-WINDOW/%SELECTED-BUFFER below are the one piece of state every
;;;; other commands-*.lisp file depends on, which is why this file loads
;;;; first among them.
(in-package #:loom)

(defun %selected-window ()
  "Return *EDITOR-STATE*'s currently selected window."
  (window-tree-selected-window (editor-state-window-tree *editor-state*)))

(defun %selected-buffer ()
  "Return the buffer displayed in *EDITOR-STATE*'s currently selected window."
  (window-buffer (%selected-window)))
