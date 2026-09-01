;;;; src/presentation/frame-layout-viewport.lisp
;;;;
;;;; Presentation layer: keep the selected point inside a window viewport.
(in-package #:loom)

(defun %layout-follow-truncated-line (window buffer height)
  (when (plusp height)
    (let ((point-line (buffer-visible-point-line buffer))
          (scroll-line (loom/feature/window:window-scroll-line window)))
      (cond
        ((< point-line scroll-line)
         (setf (loom/feature/window:window-scroll-line window) point-line))
        ((>= point-line (+ scroll-line height))
         (setf (loom/feature/window:window-scroll-line window)
               (- point-line (1- height))))))))

(defun %layout-follow-truncated-column (renderer window buffer width)
  (when (plusp width)
    (let ((point-column (%layout-buffer-point-screen-column renderer buffer))
          (scroll-column (loom/feature/window:window-scroll-column window)))
      (cond
        ((< point-column scroll-column)
         (setf (loom/feature/window:window-scroll-column window) point-column))
        ((>= point-column (+ scroll-column width))
         (setf (loom/feature/window:window-scroll-column window)
               (- point-column (1- width))))))))

(defun %layout-keep-truncated-point-visible (renderer window)
  (let ((height (loom/feature/window:window-height window))
        (width (loom/feature/window:window-width window))
        (buffer (loom/feature/window:window-buffer window)))
    (%layout-follow-truncated-line window buffer height)
    (%layout-follow-truncated-column renderer window buffer width)))

(defun %layout-keep-wrapped-point-visible (renderer window)
  "Follow point in a window that wraps a logical line across several rows.

The viewport is a (line, segment) pair rather than a line. When point is above
it the pair simply becomes point's own; when point is below, the pair is walked
back HEIGHT-1 rows from point instead of forward from the old position, so a
jump to a distant line costs the window's height rather than the jump."
  (let* ((height (loom/feature/window:window-height window))
         (width (loom/feature/window:window-width window))
         (buffer (loom/feature/window:window-buffer window)))
    (when (and (plusp height) (plusp width))
      (setf (loom/feature/window:window-scroll-column window) 0)
      (multiple-value-bind (point-line point-row)
          (%layout-wrapped-point-location renderer buffer width)
        (%layout-follow-wrapped-point
         renderer window buffer width height point-line point-row)))))

(defun %layout-wrapped-point-location (renderer buffer width)
  (let ((line (buffer-visible-point-line buffer)))
    (values line
            (%loom-segment-index
             (%layout-line-segments renderer buffer line width)
             (buffer-visible-point-column buffer)))))

(defun %layout-point-before-viewport-p
    (point-line point-row scroll-line scroll-row)
  (or (< point-line scroll-line)
      (and (= point-line scroll-line) (< point-row scroll-row))))

(defun %layout-point-fits-viewport-p
    (renderer buffer width scroll-line scroll-row point-line point-row height)
  (%layout-rows-between renderer buffer width
                         scroll-line scroll-row point-line point-row
                         (1- height)))

(defun %layout-follow-wrapped-point
    (renderer window buffer width height point-line point-row)
  (let ((scroll-line (loom/feature/window:window-scroll-line window))
        (scroll-row (loom/feature/window:window-scroll-sub-row window)))
    (cond
      ((%layout-point-before-viewport-p
        point-line point-row scroll-line scroll-row)
       (setf (loom/feature/window:window-scroll-line window) point-line
             (loom/feature/window:window-scroll-sub-row window) point-row))
      ((not (%layout-point-fits-viewport-p
             renderer buffer width scroll-line scroll-row
             point-line point-row height))
       (multiple-value-bind (new-line new-row)
           (%layout-row-back renderer buffer width point-line point-row
                             (1- height))
         (setf (loom/feature/window:window-scroll-line window) new-line
               (loom/feature/window:window-scroll-sub-row window) new-row))))))

(defun %layout-keep-point-visible (renderer window)
  "Adjust WINDOW's viewport so its buffer point remains in its rectangle."
  (if (loom/feature/mode:buffer-truncate-lines-p
       (loom/feature/window:window-buffer window))
      (%layout-keep-truncated-point-visible renderer window)
      (%layout-keep-wrapped-point-visible renderer window)))
