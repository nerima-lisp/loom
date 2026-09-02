;;;; packages/core/editor/src/application-commands-region-support.lisp
;;;;
;;;; Application layer helpers for mark/region commands.
(in-package #:loom)

(defun %set-mark-at-point (buffer)
  (buffer-set-mark buffer (buffer-point-line buffer) (buffer-point-column buffer)))

(defun %exchange-point-and-mark-or-message (buffer)
  (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
    (if mark-line
        (let ((point-line (buffer-point-line buffer))
              (point-column (buffer-point-column buffer)))
          (buffer-set-point buffer mark-line mark-column)
          (buffer-set-mark buffer point-line point-column)
          t)
        (progn
          (minibuffer-message (editor-state-minibuffer *editor-state*)
                              "The mark is not set")
          nil))))

(defun %mark-whole-buffer-region (buffer)
  (let ((start (buffer-offset-position buffer (buffer-narrow-start-offset buffer)))
        (end (buffer-offset-position buffer (buffer-narrow-end-offset buffer))))
    (buffer-set-mark buffer
                     (buffer-position-line end)
                     (buffer-position-column end))
    (buffer-set-point buffer
                      (buffer-position-line start)
                      (buffer-position-column start))))

(defun %region-mark-position-or-message (buffer)
  (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
    (if mark-line
        (values mark-line mark-column)
        (progn
          (minibuffer-message (editor-state-minibuffer *editor-state*)
                              "The mark is not set now, so no region is active")
          nil))))

(defun %region-active-bounds (buffer mark-line mark-column)
  (let* ((point-offset (buffer-point-offset buffer))
         (mark-offset (%position-to-offset buffer mark-line mark-column))
         (start-offset (min point-offset mark-offset))
         (end-offset (max point-offset mark-offset))
         (start (buffer-offset-position buffer start-offset))
         (end (buffer-offset-position buffer end-offset)))
    (values start end)))

(defun %narrow-to-active-region-or-message (buffer)
  (multiple-value-bind (mark-line mark-column)
      (%region-mark-position-or-message buffer)
    (when mark-line
      (multiple-value-bind (start end)
          (%region-active-bounds buffer mark-line mark-column)
        (buffer-narrow-to-region
         buffer
         (buffer-position-line start)
         (buffer-position-column start)
         (buffer-position-line end)
         (buffer-position-column end))
        (minibuffer-message
         (editor-state-minibuffer *editor-state*)
         "Narrowed to the active region")
        t))))

(defun %widen-buffer-and-message (buffer)
  (buffer-widen buffer)
  (minibuffer-message (editor-state-minibuffer *editor-state*)
                      "Widened buffer"))

(defun %toggle-buffer-read-only (buffer)
  (let ((read-only-p (not (buffer-read-only-p buffer))))
    (buffer-set-read-only buffer read-only-p)
    (minibuffer-message
     (editor-state-minibuffer *editor-state*)
     (if read-only-p "Buffer is read-only" "Buffer is writable"))
    buffer))
