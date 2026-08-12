;;;; src/infrastructure/terminal-renderer-buffer.lisp
;;;;
;;;; Infrastructure layer: buffer-region drawing built on the renderer port
;;;; primitives from terminal-renderer.lisp and text helpers from
;;;; terminal-renderer-text.lisp.
(in-package #:loom)

(defmethod loom-renderer-draw-buffer
    ((renderer loom-renderer) buffer x y width height &key (start-line 0))
  (let ((line-count (buffer-visible-line-count buffer)))
    (dotimes (row height)
      (let ((line-number (+ start-line row)))
        (when (< line-number line-count)
          (let* ((text (buffer-visible-line buffer line-number))
                 (visible (loom-renderer-truncate-string
                           renderer text width)))
            (loom-renderer-write-string renderer x (+ y row) visible)))))
    renderer))
