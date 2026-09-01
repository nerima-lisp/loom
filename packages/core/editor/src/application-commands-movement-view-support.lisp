;;;; packages/core/editor/src/application-commands-movement-view-support.lisp
;;;;
;;;; Application layer: movement helpers that depend on window scrolling or
;;;; minibuffer-driven navigation.
(in-package #:loom)

(defmacro define-scroll-command (name documentation delta)
  `(defun ,name ()
     ,documentation
     (%repeat-command (%command-prefix-count)
                      (lambda () (%scroll-window ,delta))
                      (lambda () (%scroll-window ,(- delta))))))

(defun %parse-goto-line-number (input)
  (handler-case
      (let ((line (parse-integer input)))
        (if (plusp line)
            (values line nil)
            (values nil "Line number must be positive")))
    (parse-error ()
      (values nil "Enter a line number"))))

(defun %goto-line-target-line (buffer line)
  (let* ((start (buffer-narrow-start-offset buffer))
         (start-position (buffer-offset-position buffer start)))
    (+ (buffer-position-line start-position) (1- line))))

(defun %goto-line-target (buffer input)
  (multiple-value-bind (line error-message)
      (%parse-goto-line-number input)
    (cond
      (error-message
       (values nil error-message))
      ((> line (buffer-visible-line-count buffer))
       (values nil "Line is outside the narrowed buffer"))
      (t
       (values (%goto-line-target-line buffer line) nil)))))

(defun %goto-visible-line-input (minibuffer input)
  (let ((buffer (%selected-buffer)))
    (multiple-value-bind (target-line error-message)
        (%goto-line-target buffer input)
      (if target-line
          (progn
            (buffer-set-point buffer target-line (buffer-point-column buffer))
            (minibuffer-message minibuffer "Moved"))
          (minibuffer-message minibuffer error-message)))))

(defun %scroll-page-size (height)
  (max 1 (1- height)))

(defun %scroll-max-line (line-count height)
  (max 0 (- line-count (max 1 height))))

(defun %scroll-window-target-line (window buffer delta)
  (let* ((height (loom/feature/window:window-height window))
         (page (%scroll-page-size height))
         (max-scroll (%scroll-max-line
                      (buffer-visible-line-count buffer)
                      height)))
    (max 0 (min max-scroll
                (+ (loom/feature/window:window-scroll-line window)
                   (* delta page))))))

(defun %scroll-window (delta)
  (let* ((window (%selected-window))
         (buffer (loom/feature/window:window-buffer window)))
    (setf (loom/feature/window:window-scroll-line window)
          (%scroll-window-target-line window buffer delta))
    ;; The scroll line just moved, so whichever segment of the old line was on
    ;; the first row means nothing now. A wrapping window's own point-following
    ;; pass re-derives the pair on the next frame.
    (setf (loom/feature/window:window-scroll-sub-row window) 0)))

(defun %visual-line-segments (renderer buffer line width)
  (loom-renderer-wrap-segments renderer (buffer-line buffer line) width))

(defun %visual-line-move-context ()
  "Return (VALUES RENDERER BUFFER WINDOW WIDTH) when the selected window wraps.

Returns NIL when the buffer truncates instead, or when there is no measurable
window: the caller then falls back to logical line movement, which is what
truncation makes screen rows and logical lines mean anyway."
  (let* ((window (and *editor-state* (%selected-window)))
         (buffer (and window (loom/feature/window:window-buffer window)))
         (renderer (and *editor-state* (editor-state-renderer *editor-state*)))
         (width (and window (loom/feature/window:window-width window))))
    (when (and window buffer renderer (plusp width)
               (not (loom/feature/mode:buffer-truncate-lines-p buffer)))
      (values renderer buffer window width))))

(defun %move-point-into-segment (renderer buffer line segment goal)
  "Put point on LINE at the character GOAL cells into SEGMENT."
  (buffer-set-point buffer line
                    (loom-renderer-segment-column
                     renderer (buffer-line buffer line) segment goal)))

(defun %visual-line-edge-segment (renderer buffer line width edge)
  (let ((segments (%visual-line-segments renderer buffer line width)))
    (if (eq edge :first)
        (first segments)
        (car (last segments)))))

(defun %visual-line-move-state (renderer buffer width)
  (let* ((line (buffer-point-line buffer))
         (text (buffer-line buffer line))
         (column (buffer-point-column buffer))
         (segments (loom-renderer-wrap-segments renderer text width))
         (index (%loom-segment-index segments column)))
    (values line text segments index
            (loom-renderer-segment-cells
             renderer text (nth index segments) column))))

(defun %visual-line-move-next (renderer buffer width line text segments index goal)
  (if (< (1+ index) (length segments))
      (%move-point-into-segment renderer buffer line
                                (nth (1+ index) segments) goal)
      (let ((next-line (1+ line)))
        (if (< next-line (buffer-line-count buffer))
            (%move-point-into-segment
             renderer buffer next-line
             (%visual-line-edge-segment renderer buffer next-line width :first)
             goal)
            (buffer-set-point buffer line (length text))))))

(defun %visual-line-move-previous (renderer buffer width line segments index goal)
  (if (plusp index)
      (%move-point-into-segment renderer buffer line
                                (nth (1- index) segments) goal)
      (let ((previous-line (1- line)))
        (when (>= previous-line 0)
          (%move-point-into-segment
           renderer buffer previous-line
           (%visual-line-edge-segment
            renderer buffer previous-line width :last)
           goal)))))

(defun %visual-line-move (direction)
  "Move point one screen row DIRECTION -- :NEXT or :PREVIOUS -- and return true.

Returns NIL when the buffer is not wrapping, so the ordinary logical movement
runs instead. Within a wrapped logical line the move stays on that line and
changes segment; at either end of it the move crosses to the neighbouring
logical line's first or last segment. The goal column is carried in cells so a
full-width character does not shift the column under a vertical move."
  (multiple-value-bind (renderer buffer window width) (%visual-line-move-context)
    (declare (ignore window))
    (when renderer
      (multiple-value-bind (line text segments index goal)
          (%visual-line-move-state renderer buffer width)
        (ecase direction
          (:next (%visual-line-move-next renderer buffer width line text
                                          segments index goal))
          (:previous (%visual-line-move-previous renderer buffer width line
                                                  segments index goal)))
        t))))

(defun %next-visual-line-once ()
  (or (%visual-line-move :next) (%next-line-once)))

(defun %previous-visual-line-once ()
  (or (%visual-line-move :previous) (%previous-line-once)))
