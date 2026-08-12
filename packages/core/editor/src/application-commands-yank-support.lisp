;;;; packages/core/editor/src/application-commands-yank-support.lisp
;;;;
;;;; Application layer: yank command helpers shared by yank/yank-pop.
(in-package #:loom)

(defun %repeat-kill-text (text count)
  (with-output-to-string (stream)
    (loop repeat count
          do (write-string text stream))))

(defun %record-last-yank (buffer ranges &key (ring-index 0) repeat-count)
  (let ((primary-range (first ranges)))
    (setf (editor-state-last-yank-buffer *editor-state*) buffer
          (editor-state-last-yank-start-offset *editor-state*) (car primary-range)
          (editor-state-last-yank-end-offset *editor-state*) (cdr primary-range)
          (editor-state-last-yank-ranges *editor-state*) ranges
          (editor-state-last-yank-ring-index *editor-state*) ring-index
          (editor-state-last-yank-repeat-count *editor-state*) repeat-count
          (editor-state-last-command-kill-p *editor-state*) nil)))

(defun %yank-insert-ranges (buffer inserted)
  (multiple-value-bind (handled ranges primary-start primary-end)
      (loom/feature/multiple-cursors:multiple-cursors-apply-insert
       buffer inserted)
    (declare (ignore primary-start primary-end))
    (if handled
        ranges
        (let ((start (buffer-point-offset buffer))
              (inserted-length (length inserted)))
          (buffer-insert-string buffer inserted)
          (list (cons start (+ start inserted-length)))))))

(defun %perform-yank (buffer text count)
  (let ((ranges (%yank-insert-ranges buffer (%repeat-kill-text text count))))
    (%record-last-yank buffer ranges :repeat-count count)))
