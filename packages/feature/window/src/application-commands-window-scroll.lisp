(in-package #:loom/feature/window)

(defun %scroll-page-size (height)
  (max 1 (1- height)))

(defun %scroll-max-line (line-count height)
  (max 0 (- line-count (max 1 height))))

(defun %scroll-window-target-line (window buffer delta)
  (let* ((height (window-height window))
         (page (%scroll-page-size height))
         (current-scroll-line (window-scroll-line window))
         (max-scroll
          (%scroll-max-line (buffer-visible-line-count buffer) height)))
    ;; Do not clamp an EOF-followed viewport backward on C-v.
    (if (and (plusp delta)
             (> current-scroll-line max-scroll))
        current-scroll-line
        (max 0 (min max-scroll (+ current-scroll-line (* delta page)))))))

(defun %scroll-window-target-point-line (window buffer current-scroll-line target-scroll-line delta)
  (let* ((height (window-height window))
         (page (%scroll-page-size height))
         (point-line (loom/core/buffer:buffer-visible-point-line buffer))
         (max-scroll-line
           (%scroll-max-line
            (loom/core/buffer:buffer-visible-line-count buffer)
            height))
         (last-visible-line (+ target-scroll-line (1- page)))
         (point-follow-line (max 0 (- point-line (1- page)))))
    (cond
      ((and (minusp delta)
            (= current-scroll-line max-scroll-line)
            (< point-follow-line current-scroll-line))
       point-line)
      ((< point-line target-scroll-line)
       target-scroll-line)
      ((> point-line last-visible-line)
       last-visible-line)
      (t point-line))))

(defun %scroll-window (delta)
  (let* ((window (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))
         (buffer (window-buffer window))
         (current-scroll-line (window-scroll-line window))
         (target-scroll-line (%scroll-window-target-line window buffer delta))
         (point-line (loom/core/buffer:buffer-point-line buffer))
         (point-column (loom/core/buffer:buffer-point-column buffer))
         (visible-point-line (loom/core/buffer:buffer-visible-point-line buffer))
         (point-line-offset (- point-line visible-point-line))
         (target-point-line
           (%scroll-window-target-point-line window buffer
                                             current-scroll-line
                                             target-scroll-line
                                             delta)))
    (setf (window-scroll-line window) target-scroll-line
          (window-scroll-sub-row window) 0)
    (unless (= visible-point-line target-point-line)
      (loom/core/buffer:buffer-set-point
       buffer
       (+ point-line-offset target-point-line)
       point-column))))

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
