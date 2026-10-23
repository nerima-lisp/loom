(in-package #:loom)

(defun %delete-char-forward-once ()
  (buffer-delete-char (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))))

(defun %delete-char-backward-once ()
  (buffer-delete-char (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))) :backward t))

(defun %repeated-character (character count)
  (when (plusp count)
    (make-string count :initial-element character)))

(defun %self-insert-character (character)
  (%clear-last-yank)
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (let ((text (%repeated-character character (%command-prefix-count))))
    (when text
      (buffer-insert-string (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))) text))))

(defun %insert-newlines (count)
  (loop repeat count
        do (buffer-insert-string (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))) (string #\Newline))))

(defun %open-line-once ()
  (let* ((buffer (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))))
         (line (buffer-point-line buffer))
         (column (buffer-point-column buffer)))
    (buffer-insert-string buffer (string #\Newline))
    (buffer-set-point buffer line column)))

(defun %open-line-with-newlines (count)
  (loop repeat count do (%open-line-once)))
