;;;; packages/core/editor/src/application-commands-movement-view-support.lisp
;;;;
;;;; Application layer: movement helpers that depend on window scrolling or
;;;; minibuffer-driven navigation.
(in-package #:loom)

(defmacro define-scroll-command (name delta documentation)
  `(defun ,name ()
     ,documentation
     (%repeat-command (%command-prefix-count)
                      (lambda () (%scroll-window ,delta))
                      (lambda () (%scroll-window ,(- delta))))))

(defun %goto-visible-line-input (minibuffer input)
  (handler-case
      (let ((line (parse-integer input)))
        (if (plusp line)
            (let ((buffer (%selected-buffer)))
              (if (<= line (buffer-visible-line-count buffer))
                  (let* ((start (buffer-narrow-start-offset buffer))
                         (start-position (buffer-offset-position buffer start))
                         (target-line (+ (buffer-position-line start-position)
                                         (1- line))))
                    (buffer-set-point buffer target-line (buffer-point-column buffer))
                    (minibuffer-message minibuffer "Moved"))
                  (minibuffer-message minibuffer
                                      "Line is outside the narrowed buffer")))
            (minibuffer-message minibuffer "Line number must be positive")))
    (parse-error ()
      (minibuffer-message minibuffer "Enter a line number"))))

(defun %scroll-window (delta)
  (let* ((window (%selected-window))
         (buffer (loom/feature/window:window-buffer window))
         (page (max 1 (1- (loom/feature/window:window-height window))))
         (max-scroll (max 0 (- (buffer-visible-line-count buffer)
                               (max 1 (loom/feature/window:window-height window))))))
    (setf (loom/feature/window:window-scroll-line window)
          (max 0 (min max-scroll
                      (+ (loom/feature/window:window-scroll-line window)
                         (* delta page)))))))
