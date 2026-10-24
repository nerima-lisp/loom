(in-package #:loom/core/editor-session)

(defun make-editor-state (&rest initargs)
  "Construct an EDITOR-STATE with a required session.

The session must contain the feature slices used by omitted state values. A
NIL :WORKSPACES value uses the session :FEATURE/WORKSPACE slice; an omitted
:KEYBOARD-MACRO value uses :FEATURE/KEYBOARD-MACRO. The :WINDOW-TREE argument
must match the session :CORE/WINDOW-TREE slice."
  (let ((state (apply #'%make-editor-state initargs)))
    (unless (editor-session-p (editor-state-session state))
      (error "EDITOR-STATE requires an editor session"))
    (unless (editor-state-workspaces state)
      (setf (editor-state-workspaces state)
            (editor-session-slice (editor-state-session state)
                                  :feature/workspace)))
    (unless (member :keyboard-macro initargs)
      (setf (editor-state-keyboard-macro state)
            (editor-session-slice (editor-state-session state)
                                  :feature/keyboard-macro)))
    state))
