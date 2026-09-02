;;;; packages/core/editor/src/application-commands-editing-support.lisp
;;;;
;;;; Application layer: editing command helpers shared by public commands.
(in-package #:loom)

(defun %delete-char-forward-once ()
  (buffer-delete-char (%selected-buffer)))

(defun %delete-char-backward-once ()
  (buffer-delete-char (%selected-buffer) :backward t))

(defun %repeated-character (character count)
  (when (plusp count)
    (make-string count :initial-element character)))

(defun %self-insert-character (character)
  (%clear-last-yank)
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (let ((text (%repeated-character character (%command-prefix-count))))
    (when text
      (buffer-insert-string (%selected-buffer) text))))

(defun %insert-newlines (count)
  (loop repeat count
        do (buffer-insert-string (%selected-buffer) (string #\Newline))))

(defun %open-line-once ()
  (let* ((buffer (%selected-buffer))
         (line (buffer-point-line buffer))
         (column (buffer-point-column buffer)))
    (buffer-insert-string buffer (string #\Newline))
    (buffer-set-point buffer line column)))

(defun %open-line-with-newlines (count)
  (loop repeat count do (%open-line-once)))
