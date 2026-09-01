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
