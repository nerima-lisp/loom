(in-package #:loom)

(defmacro define-command-name-set (name names documentation)
  "Declare a command-name set consumed by routing-state decisions."
  `(defparameter ,name ',names ,documentation))

(define-command-name-set +yank-command-names+
  (yank yank-pop)
  "Commands that may consume or rotate the last-yank transient state.")

(define-command-name-set +yank-preserving-command-names+
  (delete-char delete-backward-char)
  "Commands that leave the last-yank transient state intact.

A forward delete after a yank leaves point at the yank's end offset, which is
the whole of %VALID-YANK-POP-CONTEXT-P's freshness test, so YANK-POP still has
a live range to rotate through. Emacs would instead require the immediately
preceding command to be a yank; keeping these two listed preserves loom's
existing behavior rather than tightening it as a side effect of an unrelated
change.")

(define-command-name-set +kill-command-names+
  (kill-line kill-word backward-kill-word kill-region kill-sexp)
  "Commands whose adjacent invocations may coalesce in the kill ring.")

(defun %refresh-active-keymap (keymap-state)
  "Layer the selected buffer keymap over the session root map."
  (when *editor-state*
    (let* ((root (editor-state-keymap *editor-state*))
           (window-tree (editor-state-window-tree *editor-state*))
           (window (loom/core/window-tree:window-tree-selected-window
                    window-tree))
           (buffer (loom/core/window-tree:window-buffer window))
           (active (keymap-for-buffer
                    (editor-state-session *editor-state*)
                    buffer
                    root)))
      (keymap-state-use-keymap keymap-state active)
      active)))
