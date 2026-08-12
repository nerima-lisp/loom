;;;; packages/core/editor/src/application-commands-movement-support.lisp
;;;;
;;;; Application layer: internal point-movement helpers shared by movement
;;;; commands without exposing another public command surface.
(in-package #:loom)

(defun %move-point-to-position (buffer position)
  (buffer-set-point buffer
                    (buffer-position-line position)
                    (buffer-position-column position)))

(defun %move-point-to-offset (buffer offset)
  (%move-point-to-position buffer
                           (buffer-offset-position buffer offset)))

(defmacro define-current-line-boundary-command (name column-form documentation)
  `(defun ,name ()
     ,documentation
     (let ((buffer (%selected-buffer)))
       (buffer-set-point buffer
                         (buffer-point-line buffer)
                         ,column-form))))

(defmacro define-buffer-boundary-command (name offset-form documentation)
  `(defun ,name ()
     ,documentation
     (let ((buffer (%selected-buffer)))
       (%move-point-to-offset buffer ,offset-form))))

(defun %forward-char-once ()
  (let* ((buffer (%selected-buffer))
         (point (buffer-point-offset buffer))
         (end (buffer-narrow-end-offset buffer)))
    (when (< point end)
      (%move-point-to-offset buffer (1+ point)))))

(defun %backward-char-once ()
  (let* ((buffer (%selected-buffer))
         (point (buffer-point-offset buffer))
         (start (buffer-narrow-start-offset buffer)))
    (when (> point start)
      (%move-point-to-offset buffer (1- point)))))

(defun %next-line-once ()
  (let ((buffer (%selected-buffer)))
    (buffer-set-point buffer (1+ (buffer-point-line buffer)) (buffer-point-column buffer))))

(defun %previous-line-once ()
  (let ((buffer (%selected-buffer)))
    (buffer-set-point buffer (1- (buffer-point-line buffer)) (buffer-point-column buffer))))

(defun %forward-word-once ()
  (let* ((buffer (%selected-buffer))
         (start (buffer-narrow-start-offset buffer))
         (offset (%forward-word-offset
                  (buffer-visible-text buffer)
                  (- (buffer-point-offset buffer) start))))
    (%move-point-to-offset buffer (+ start offset))))

(defun %backward-word-once ()
  (let* ((buffer (%selected-buffer))
         (start (buffer-narrow-start-offset buffer))
         (offset (%backward-word-offset
                  (buffer-visible-text buffer)
                  (- (buffer-point-offset buffer) start))))
    (%move-point-to-offset buffer (+ start offset))))
