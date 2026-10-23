(in-package #:loom)

(defun record-undo-boundary-for-command (self-insert-p)
  "Record a buffer undo boundary when the command kind changes.

SELF-INSERT-P is true for SELF-INSERT-COMMAND and false for keymap-dispatched
commands. Consecutive self inserts therefore collapse into one undo group,
while switching to any other command starts a new group."
  (unless (eq self-insert-p
              (editor-state-last-command-self-insert-p *editor-state*))
    (buffer-record-undo-boundary (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))))
  (setf (editor-state-last-command-self-insert-p *editor-state*) self-insert-p))

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
  "Layer the selected buffer's major-mode map over the session root map."
  (when *editor-state*
    (let* ((root (editor-state-keymap *editor-state*))
           (window-tree (editor-state-window-tree *editor-state*))
           (window (loom/core/window-tree:window-tree-selected-window
                    window-tree))
           (buffer (loom/core/window-tree:window-buffer window))
           (active (if buffer
                       (loom/feature/mode:major-mode-keymap
                        (buffer-major-mode buffer) root)
                       root)))
      (keymap-state-use-keymap keymap-state active)
      active)))
