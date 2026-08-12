;;;; packages/core/editor/src/application-commands-editing-support.lisp
;;;;
;;;; Application layer: editing command helpers shared by public commands.
(in-package #:loom)

(defun %delete-char-forward-once ()
  (let ((buffer (%selected-buffer)))
    (unless (loom/feature/multiple-cursors:multiple-cursors-apply-delete
             buffer)
      (buffer-delete-char buffer))))

(defun %delete-char-backward-once ()
  (let ((buffer (%selected-buffer)))
    (unless (loom/feature/multiple-cursors:multiple-cursors-apply-delete
             buffer
             :backward t)
      (buffer-delete-char buffer :backward t))))

(defun %self-insert-character (char)
  (%clear-last-yank)
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (let ((count (%command-prefix-count)))
    (when (plusp count)
      (let* ((buffer (%selected-buffer))
             (text (make-string count :initial-element char)))
        (unless (loom/feature/multiple-cursors:multiple-cursors-apply-insert
                 buffer text)
          (buffer-insert-string buffer text))))))

(defun %insert-newlines (count)
  (loop repeat count
        do (buffer-insert-string (%selected-buffer) (string #\Newline))))

(defun %open-line-with-newlines (count)
  (loop repeat count
        do (let ((buffer (%selected-buffer)))
             (let ((line (buffer-point-line buffer))
                   (column (buffer-point-column buffer)))
               (buffer-insert-string buffer (string #\Newline))
               (buffer-set-point buffer line column)))))
