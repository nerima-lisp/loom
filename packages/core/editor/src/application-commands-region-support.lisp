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

(defun buffer-active-region-span (buffer)
  "Return BUFFER's active region as an absolute half-open span, or NIL when
the mark is unset."
  (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
    (when mark-line
      (let* ((point-offset (buffer-point-offset buffer))
             (mark-offset (%position-to-offset buffer mark-line mark-column)))
        (make-buffer-span (min point-offset mark-offset)
                          (max point-offset mark-offset))))))

(defun %narrow-to-active-region-or-message (buffer)
  (let ((span (buffer-active-region-span buffer)))
    (if span
        (let ((start (buffer-offset-position buffer
                                             (buffer-span-start span)))
              (end (buffer-offset-position buffer
                                           (buffer-span-end span))))
        (buffer-narrow-to-region
         buffer
         (buffer-position-line start)
         (buffer-position-column start)
         (buffer-position-line end)
         (buffer-position-column end))
        (minibuffer-message
         (editor-state-minibuffer *editor-state*)
         "Narrowed to the active region")
        t)
        (progn
          (minibuffer-message
           (editor-state-minibuffer *editor-state*)
           "The mark is not set now, so no region is active")
          nil))))

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
