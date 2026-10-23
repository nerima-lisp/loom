(in-package #:loom/feature/window)

(defun %scroll-page-size (height)
  (max 1 (1- height)))

(defun %scroll-max-line (line-count height)
  (max 0 (- line-count (max 1 height))))

(defun %scroll-window-target-line (window buffer delta)
  (let* ((height (window-height window))
         (page (%scroll-page-size height))
         (max-scroll
          (%scroll-max-line (buffer-visible-line-count buffer) height)))
    (max 0 (min max-scroll (+ (window-scroll-line window) (* delta page))))))

(defun %scroll-window (delta)
  (let* ((window (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))
         (buffer (window-buffer window)))
    (setf (window-scroll-line window) (%scroll-window-target-line window
                                                                  buffer
                                                                  delta))
    (setf (window-scroll-sub-row window) 0)))

(defun scroll-up-command ()
  "Scroll down by roughly one page, repeating for the active prefix (C-v)."
  (repeat-command
   (lambda ()
     (%scroll-window 1))
   (lambda ()
     (%scroll-window -1))))

(defun scroll-down-command ()
  "Scroll up by roughly one page, repeating for the active prefix (M-v)."
  (repeat-command
   (lambda ()
     (%scroll-window -1))
   (lambda ()
     (%scroll-window 1))))
