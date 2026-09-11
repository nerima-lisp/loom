(in-package #:loom)

(defun %active-region-bounds (buffer)
  "Return region bounds and coalescing direction for BUFFER, or NIL values."
  (let ((span (buffer-active-region-span buffer)))
    (if span
        (let* ((start (buffer-offset-position buffer
                                              (buffer-span-start span)))
               (end (buffer-offset-position buffer
                                            (buffer-span-end span)))
               (point-offset (buffer-point-offset buffer)))
          (values (buffer-position-line start)
                  (buffer-position-column start)
                  (buffer-position-line end)
                  (buffer-position-column end)
                  (> point-offset (buffer-span-start span))))
        (values nil nil nil nil nil))))

(defun %message-no-active-region ()
  (minibuffer-message
   (editor-state-minibuffer *editor-state*)
   "The mark is not set now, so no region is active")
  nil)

(defun %kill-active-region-or-message (buffer)
  (%clear-last-yank)
  (multiple-value-bind (start-line start-column end-line end-column prepend)
      (%active-region-bounds buffer)
    (if start-line
        (progn
          (%kill-ring-push
           (buffer-delete-region buffer start-line start-column end-line end-column)
           :prepend prepend
           :coalesce (editor-state-last-command-kill-p *editor-state*))
          (setf (editor-state-last-command-kill-p *editor-state*) t)
          t)
        (%message-no-active-region))))

(defun %copy-active-region-or-message (buffer)
  (%clear-last-yank)
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (multiple-value-bind (start-line start-column end-line end-column)
      (%active-region-bounds buffer)
    (if start-line
        (progn
          (%kill-ring-push
           (buffer-region-string
            buffer start-line start-column end-line end-column))
          t)
        (%message-no-active-region))))
