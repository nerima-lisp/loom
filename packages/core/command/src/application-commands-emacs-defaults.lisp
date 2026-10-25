(in-package #:loom/core/command)

(progn
  (defvar *recenter-next-position* :top)

  (defun recenter-top-bottom ()
    "Recenter the selected window, cycling through middle, top, and bottom."
    (let* ((window
             (loom/core/window-tree:window-tree-selected-window
              (editor-state-window-tree *editor-state*)))
           (buffer (loom/core/window-tree:window-buffer window))
           (height (max 1 (loom/core/window-tree:window-height window)))
           (point-line (buffer-visible-point-line buffer))
           (position
             (if (equal *previous-command-id* "recenter-top-bottom")
                 *recenter-next-position*
                 :middle))
           (screen-row
             (case position
               (:middle (floor height 2))
               (:top 0)
               (:bottom (1- height))))
           (max-scroll
             (max 0 (- (buffer-visible-line-count buffer) height)))
           (scroll-line
             (max 0 (min max-scroll (- point-line screen-row)))))
      (setf (loom/core/window-tree:window-scroll-line window) scroll-line
            (loom/core/window-tree:window-scroll-sub-row window) 0
            *recenter-next-position*
            (case position
              (:middle :top)
              (:top :bottom)
              (:bottom :middle)))))

  (defun %replace-buffer-offset-range (buffer start end replacement)
    (let ((start-position (buffer-offset-position buffer start))
          (end-position (buffer-offset-position buffer end)))
      (buffer-delete-region
       buffer
       (buffer-position-line start-position)
       (buffer-position-column start-position)
       (buffer-position-line end-position)
       (buffer-position-column end-position))
      (buffer-insert-string buffer replacement)))

  (defun transpose-chars ()
    "Transpose the characters before and at point."
    (let* ((window
             (loom/core/window-tree:window-tree-selected-window
              (editor-state-window-tree *editor-state*)))
           (buffer (loom/core/window-tree:window-buffer window))
           (visible-start (buffer-narrow-start-offset buffer))
           (text (buffer-visible-text buffer))
           (point (- (buffer-point-offset buffer) visible-start))
           (line-end-p
             (= (buffer-point-column buffer)
                (length (buffer-line buffer (buffer-point-line buffer)))))
           (start (if line-end-p (- point 2) (1- point)))
           (end (if line-end-p point (1+ point))))
      (unless (and (>= start 0) (<= end (length text)))
        (error "transpose-chars: point has fewer than two adjacent characters"))
      (%replace-buffer-offset-range
       buffer
       (+ visible-start start)
       (+ visible-start end)
       (concatenate 'string
                    (string (char text (1+ start)))
                    (string (char text start))))))

  (defun %command-word-character-p (character)
    (or (alphanumericp character)
        (char= character #\_)))

  (defun %command-forward-word-offset (text offset)
    (let ((length (length text)))
      (loop while (and (< offset length)
                       (not (%command-word-character-p (char text offset))))
            do (incf offset))
      (loop while (and (< offset length)
                       (%command-word-character-p (char text offset)))
            do (incf offset))
      offset))

  (defun %transform-word-at-point (transform)
    (let* ((window
             (loom/core/window-tree:window-tree-selected-window
              (editor-state-window-tree *editor-state*)))
           (buffer (loom/core/window-tree:window-buffer window))
           (visible-start (buffer-narrow-start-offset buffer))
           (text (buffer-visible-text buffer))
           (point (- (buffer-point-offset buffer) visible-start))
           (word-start
             (or (position-if #'%command-word-character-p text :start point)
                 (length text))))
      (when (< word-start (length text))
        (let* ((word-end (%command-forward-word-offset text word-start))
               (word (subseq text word-start word-end)))
          (%replace-buffer-offset-range
           buffer
           (+ visible-start word-start)
           (+ visible-start word-end)
           (funcall transform word))))))

  (defun upcase-word ()
    "Uppercase the following word and move point to its end."
    (%transform-word-at-point #'string-upcase))

  (defun downcase-word ()
    "Lowercase the following word and move point to its end."
    (%transform-word-at-point #'string-downcase))

  (defun capitalize-word ()
    "Capitalize the following word and move point to its end."
    (%transform-word-at-point
     (lambda (word)
       (concatenate 'string
                    (string-upcase (subseq word 0 1))
                    (string-downcase (subseq word 1)))))))
