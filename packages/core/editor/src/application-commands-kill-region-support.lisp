;;;; packages/core/editor/src/application-commands-kill-region-support.lisp
;;;;
;;;; Application layer: active-region helpers shared by kill/copy commands.
(in-package #:loom)

(defun %active-region-bounds (buffer)
  "Return region bounds and coalescing direction for BUFFER, or NIL values."
  (let ((point-line (buffer-point-line buffer))
        (point-column (buffer-point-column buffer)))
    (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
      (if (null mark-line)
          (values nil nil nil nil nil)
          (multiple-value-bind (start-line start-column end-line end-column)
              (%order-region point-line point-column mark-line mark-column)
            (values start-line start-column end-line end-column
                    (or (> point-line mark-line)
                        (and (= point-line mark-line)
                             (> point-column mark-column)))))))))

(defun %kill-active-region-or-message (buffer)
  (%clear-last-yank)
  (multiple-value-bind (start-line start-column end-line end-column prepend)
      (%active-region-bounds buffer)
    (if (null start-line)
        (progn
          (minibuffer-message (editor-state-minibuffer *editor-state*)
                              "The mark is not set now, so no region is active")
          nil)
        (progn
          (%kill-ring-push
           (buffer-delete-region buffer start-line start-column end-line end-column)
           :prepend prepend
           :coalesce (editor-state-last-command-kill-p *editor-state*))
          (setf (editor-state-last-command-kill-p *editor-state*) t)
          t))))

(defun %copy-active-region-or-message (buffer)
  (%clear-last-yank)
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (multiple-value-bind (start-line start-column end-line end-column)
      (%active-region-bounds buffer)
    (if (null start-line)
        (progn
          (minibuffer-message
           (editor-state-minibuffer *editor-state*)
           "The mark is not set now, so no region is active")
          nil)
        (progn
          (%kill-ring-push
           (buffer-region-string
            buffer start-line start-column end-line end-column))
          t))))
