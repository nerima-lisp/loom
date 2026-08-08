;;;; t/commands-test.lisp
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
;;;; precedent t/file-tree-test.lisp already set for
;;;; LOOM::FILE-TREE-CHILD-LISTER.
(in-package #:loom/test)

(defun %fresh-editor-state (initial-content &key with-minibuffer)
  "Build a minimal *EDITOR-STATE* around a single window over a buffer
containing INITIAL-CONTENT -- enough for movement, editing, and undo
commands, which never touch the minibuffer/file-tree/renderer slots.
WITH-MINIBUFFER installs a live MAKE-MINIBUFFER for the prompting commands,
which do; see %WITH-MINIBUFFER-STATE."
  (let* ((buffer (make-buffer :initial-content initial-content))
         (tree (make-window-tree buffer 80 24)))
    (make-editor-state :window-tree tree
                        :minibuffer (and with-minibuffer (make-minibuffer))
                        :keymap (make-keymap)
                        :file-tree nil
                        :renderer nil
                        :buffers (list buffer)
                        :kill-ring nil)))

(defmacro %with-minibuffer-state ((minibuffer initial-content &rest extra-bindings)
                                  &body body)
  "Run BODY with *EDITOR-STATE* dynamically bound to a fresh state over
INITIAL-CONTENT carrying a live minibuffer, and MINIBUFFER bound to that
minibuffer. EXTRA-BINDINGS are appended to the same LET*, so they may refer
to *EDITOR-STATE* and to MINIBUFFER."
  `(let* ((*editor-state* (%fresh-editor-state ,initial-content :with-minibuffer t))
          (,minibuffer (editor-state-minibuffer *editor-state*))
          ,@extra-bindings)
     ,@body))

(defun %selected-test-buffer ()
  "Return the buffer displayed in the fresh editor state's sole window."
  (window-buffer (window-tree-selected-window (editor-state-window-tree *editor-state*))))

(defun %fresh-file-tree (root)
  "Build a FILE-TREE rooted at ROOT with a real, disk-backed child-lister
\(LOOM-FS-LIST-DIRECTORY, the same one MAIN wires up in
%INITIALIZE-EDITOR-STATE\), for exercising the file-tree application
commands \(commands-window.lisp\) against a real temporary directory."
  (let ((tree (make-file-tree root)))
    (setf (loom::file-tree-child-lister tree) (function loom-fs-list-directory))
    tree))
