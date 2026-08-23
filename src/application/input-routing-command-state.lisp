;;;; src/application/input-routing-command-state.lisp
;;;;
;;;; Command-routing helpers that mutate editor-local routing state while
;;;; remaining independent from the event-loop byte-reading path.
(in-package #:loom)

(defun record-undo-boundary-for-command (self-insert-p)
  "Record a buffer undo boundary when the command kind changes.

SELF-INSERT-P is true for SELF-INSERT-COMMAND and false for keymap-dispatched
commands. Consecutive self inserts therefore collapse into one undo group,
while switching to any other command starts a new group."
  (unless (eq self-insert-p
              (editor-state-last-command-self-insert-p *editor-state*))
    (buffer-record-undo-boundary (%selected-buffer)))
  (setf (editor-state-last-command-self-insert-p *editor-state*) self-insert-p))

(defparameter +yank-command-names+ '(yank yank-pop)
  "Commands that may consume or rotate the last-yank transient state.")

(defparameter +yank-preserving-command-names+
  '(delete-char delete-backward-char)
  "Commands that leave the last-yank transient state intact.

A forward delete after a yank leaves point at the yank's end offset, which is
the whole of %VALID-YANK-POP-CONTEXT-P's freshness test, so YANK-POP still has
a live range to rotate through. Emacs would instead require the immediately
preceding command to be a yank; keeping these two listed preserves loom's
existing behavior rather than tightening it as a side effect of an unrelated
change.")

(defparameter +kill-command-names+
  '(kill-line kill-word backward-kill-word kill-region)
  "Commands whose adjacent invocations may coalesce in the kill ring.")

(defun %refresh-active-keymap (keymap-state)
  "Layer the selected buffer's major-mode map over the state root map.

The root map remains the user/global map captured when KEYMAP-STATE was
created. Switching buffers or major modes therefore changes only the active
layer and clears a partially entered prefix sequence; global bindings remain
available through the mode map's parent."
  (let* ((root (or (keymap-state-root-keymap keymap-state)
                   (keymap-state-keymap keymap-state)))
         (buffer (and *editor-state* (%selected-buffer)))
         (active (if buffer
                     (loom/feature/mode:major-mode-keymap
                      (buffer-major-mode buffer) root)
                     root)))
    (unless (eq active (keymap-state-keymap keymap-state))
      (setf (keymap-state-sequence keymap-state) nil))
    (setf (keymap-state-keymap keymap-state) active)
    active))
