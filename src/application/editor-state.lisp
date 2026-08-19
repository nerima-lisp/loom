;;;; src/application/editor-state.lisp
;;;;
;;;; Application layer: constructor logic for the top-level EDITOR-STATE.
(in-package #:loom)

(defun make-editor-state (&rest initargs)
  "Construct an EDITOR-STATE with a workspace manager for WINDOW-TREE.

The workspace manager is part of the state invariant, including for small
programmatic states used by tests and extensions.  Callers may provide an
explicit manager when restoring a session or preparing multiple views; when
they omit it, the initial window tree becomes the main workspace."
  (let ((state (apply #'%make-editor-state initargs)))
    (unless (editor-state-workspaces state)
      (setf (editor-state-workspaces state)
            (loom/feature/workspace:make-workspace-manager
             (editor-state-window-tree state)
             :name "main")))
    state))
