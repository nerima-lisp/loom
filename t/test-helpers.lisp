;;;; t/test-helpers.lisp
;;;;
;;;; Shared fixtures for unit and integration tests.  Keeping these helpers
;;;; outside a feature-specific test file makes the test taxonomy independent
;;;; from ASDF load order.
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
                        :workspaces (make-workspace-manager tree :name "main")
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
    (loom/feature/file-tree:file-tree-install-child-lister
     tree
     (function loom/feature/file-tree:loom-fs-list-directory))
    tree))
