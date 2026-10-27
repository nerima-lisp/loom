(in-package #:loom/core/command)

(progn
  (defvar *recenter-next-position* :top)

  (defun recenter-top-bottom ()
    "Recenter the selected window, cycling through middle, top, and bottom."
    (let* ((window
             (loom/core/window-tree:window-tree-selected-window
              (editor-state-window-tree *editor-state*)))
           (buffer (loom/core/window-tree:window-buffer window))
           (height (max 1 (1- (loom/core/window-tree:window-height window))))
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

  (defun %replace-buffer-offset-range
      (buffer start end replacement &key minimal-change-p undo-replacement-p)
    (if minimal-change-p
        (let* ((visible-start (buffer-narrow-start-offset buffer))
               (text (buffer-visible-text buffer))
               (original (subseq text
                                 (- start visible-start)
                                 (- end visible-start)))
               (prefix 0)
               (suffix 0))
          (loop while (and (< prefix (length original))
                           (< prefix (length replacement))
                           (char= (char original prefix)
                                  (char replacement prefix)))
                do (incf prefix))
          (loop while (and (< suffix (- (length original) prefix))
                           (< suffix (- (length replacement) prefix))
                           (char= (char original (- (length original) suffix 1))
                                  (char replacement
                                        (- (length replacement) suffix 1))))
                do (incf suffix))
          (let ((changed-start (+ start prefix))
                (changed-end (- end suffix))
                (changed-text
                 (subseq replacement prefix (- (length replacement) suffix))))
            (if (or (< changed-start changed-end)
                    (plusp (length changed-text)))
                (progn
                  (if (< changed-start changed-end)
                      (let ((start-position
                             (buffer-offset-position buffer changed-start))
                            (end-position
                             (buffer-offset-position buffer changed-end)))
                        (buffer-delete-region
                         buffer
                         (buffer-position-line start-position)
                         (buffer-position-column start-position)
                         (buffer-position-line end-position)
                         (buffer-position-column end-position)
                         :undo-replacement-p undo-replacement-p))
                    (let ((position
                           (buffer-offset-position buffer changed-start)))
                      (loom/core/buffer:buffer-set-point
                       buffer
                       (buffer-position-line position)
                       (buffer-position-column position))))
                  (unless (string= changed-text "")
                    (buffer-insert-string buffer changed-text)))
              (unless (and (= start end)
                           (string= replacement ""))
                (let ((position
                       (buffer-offset-position
                        buffer (+ start (length replacement)))))
                  (loom/core/buffer:buffer-set-point
                   buffer
                   (buffer-position-line position)
                   (buffer-position-column position)))))))
      (let ((start-position (buffer-offset-position buffer start))
            (end-position (buffer-offset-position buffer end)))
        (buffer-delete-region
         buffer
         (buffer-position-line start-position)
         (buffer-position-column start-position)
         (buffer-position-line end-position)
         (buffer-position-column end-position)
         :undo-replacement-p undo-replacement-p)
        (buffer-insert-string buffer replacement))))


  (defun transpose-chars ()
  "Transpose the characters before and at point."
  (let* ((window
          (loom/core/window-tree:window-tree-selected-window
           (editor-state-window-tree *editor-state*)))
         (buffer (loom/core/window-tree:window-buffer window))
         (visible-start (buffer-narrow-start-offset buffer))
         (text (buffer-visible-text buffer))
         (point (- (buffer-point-offset buffer) visible-start))
         (prefix-count (or loom/core/command:*current-prefix-argument* 1))
         (line-end-p
          (= (buffer-point-column buffer)
             (length (buffer-line buffer (buffer-point-line buffer)))))
         (start
          (if line-end-p
              (- point prefix-count 1)
              (1- point)))
         (end
          (if line-end-p
              point
              (+ point prefix-count))))
    (unless
        (and (plusp prefix-count)
             (>= start 0)
             (< start end)
             (<= end (length text)))
      (error "transpose-chars: point has fewer than two adjacent characters"))
    (let* ((replacement
            (concatenate (quote string)
                         (subseq text (1+ start) end)
                         (subseq text start (1+ start)))))
      (%replace-buffer-offset-range buffer
                                    (+ visible-start start)
                                    (+ visible-start end)
                                    replacement
                                    :undo-replacement-p
                                    t)
      (%command-set-point-at-offset buffer (+ visible-start end)))))

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
  (defun %command-transform-word-range (text start end transform)
  (with-output-to-string (output)
    (loop with offset = start
          while (< offset end)
          do (let ((word-start
                     (position-if (function %command-word-character-p)
                                  text
                                  :start offset
                                  :end end)))
               (write-string (subseq text offset (or word-start end)) output)
               (if word-start
                   (let ((word-end
                           (min end
                                (%command-forward-word-offset
                                 text word-start))))
                     (write-string
                      (funcall transform (subseq text word-start word-end))
                      output)
                     (setf offset word-end))
                   (return))))))

  (defun %transform-word-at-point (transform)
  (let* ((window
          (loom/core/window-tree:window-tree-selected-window
           (editor-state-window-tree *editor-state*)))
         (buffer (loom/core/window-tree:window-buffer window))
         (visible-start (buffer-narrow-start-offset buffer))
         (text (buffer-visible-text buffer))
         (point (- (buffer-point-offset buffer) visible-start))
         (word-start
          (or
           (position-if (function %command-word-character-p) text :start point)
           (length text))))
    (when (< word-start (length text))
      (let* ((word-end
              (loop with offset = word-start
                    repeat (max 0 (or loom/core/command:*current-prefix-argument* 1))
                    do (setf offset (%command-forward-word-offset text offset))
                    finally (return offset))))
        (when (< word-start word-end)
          (%replace-buffer-offset-range
           buffer
           (+ visible-start word-start)
           (+ visible-start word-end)
           (%command-transform-word-range text word-start word-end transform)
           :undo-replacement-p
           t))))))

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
(progn
  (defun %command-horizontal-space-p (character)
    (or (char= character #\Space)
        (char= character #\Tab)))

  (defun %command-set-point-at-offset (buffer offset)
    (let ((position (buffer-offset-position buffer offset)))
      (loom/core/buffer:buffer-set-point
       buffer
       (buffer-position-line position)
       (buffer-position-column position))))

  (defun delete-indentation ()
  "Join the current line to the previous line."
  (let* ((window
          (loom/core/window-tree:window-tree-selected-window
           (editor-state-window-tree *editor-state*)))
         (buffer (loom/core/window-tree:window-buffer window))
         (visible-start (buffer-narrow-start-offset buffer))
         (text (buffer-visible-text buffer))
         (point (- (buffer-point-offset buffer) visible-start))
         (prefix-p (not (null loom/core/command:*current-prefix-argument*)))
         (newline
          (if prefix-p
              (position #\Newline text :start point)
              (position #\Newline text :end point :from-end t))))
    (when newline
      (let ((left-end newline)
            (right-start (1+ newline)))
        (loop while (and (> left-end 0)
                         (%command-horizontal-space-p (char text (1- left-end))))
              do (decf left-end))
        (loop while (and (< right-start (length text))
                         (%command-horizontal-space-p (char text right-start)))
              do (incf right-start))
        (let* ((left-character
                (when (> left-end 0)
                  (char text (1- left-end))))
               (right-character
                (when (< right-start (length text))
                  (char text right-start)))
               (separator
                (if (and left-character
                         right-character
                         (not (char= left-character #\Newline))
                         (not
                          (and (char= left-character #\()
                               (char= right-character #\)))))
                    " "
                    "")))
          (%replace-buffer-offset-range buffer
                                        (+ visible-start left-end)
                                        (+ visible-start right-start)
                                        separator
                                        :undo-replacement-p
                                        t)
          (%command-set-point-at-offset buffer (+ visible-start left-end)))))))

  (defun %command-line-ranges (text)
    (loop with start = 0
          for newline = (position #\Newline text :start start)
          for end = (or newline (length text))
          collect (cons start end)
          while newline
          do (setf start (1+ newline))))

  (defun %command-blank-line-p (text range)
    (every #'%command-horizontal-space-p
           (subseq text (car range) (cdr range))))

  (defun %command-paragraph-words (text start end)
    (let ((words nil)
          (word-start nil))
      (loop for offset from start below end
            for character = (char text offset)
            do (if (or (char= character #\Space)
                       (char= character #\Tab)
                       (char= character #\Newline))
                   (when word-start
                     (push (subseq text word-start offset) words)
                     (setf word-start nil))
                   (unless word-start
                     (setf word-start offset)))
            finally (when word-start
                      (push (subseq text word-start end) words)))
      (nreverse words)))

  (defun %command-wrap-words (words width &optional justify-p)
  (let ((lines nil)
        (current-line nil)
        (current-width 0))
    (dolist (word words)
      (when (and current-line (> (+ current-width 1 (length word)) width))
        (push (nreverse current-line) lines)
        (setf current-line nil
              current-width 0))
      (when current-line
        (incf current-width))
      (push word current-line)
      (incf current-width (length word)))
    (when current-line
      (push (nreverse current-line) lines))
    (setf lines (nreverse lines))
    (with-output-to-string (output)
      (loop for line in lines
            for line-index from 0
            for last-line-p = (= line-index (1- (length lines)))
            do (let* ((gap-count (1- (length line)))
                      (word-width
                       (loop for word in line
                             sum (length word)))
                      (space-count
                       (if (and justify-p (not last-line-p) (plusp gap-count))
                           (max gap-count (- width word-width))
                           gap-count))
                      (spaces-per-gap
                       (if (plusp gap-count)
                           (floor space-count gap-count)
                           0))
                      (extra-count
                       (if (plusp gap-count)
                           (mod space-count gap-count)
                           0))
                      (gap-order
                       (stable-sort
                        (loop for index below gap-count
                              collect index)
                        (function <)
                        :key
                        (lambda (index)
                          (abs (- (* 2 index) (1- gap-count))))))
                      (extra-gaps
                       (loop for gap in gap-order
                             repeat extra-count
                             collect gap)))
                 (loop for word in line
                       for word-index from 0
                       do (when (plusp word-index)
                            (let ((spaces
                                   (+ spaces-per-gap
                                      (if (member (1- word-index) extra-gaps)
                                          1
                                          0))))
                              (dotimes (space spaces)
                                (write-char #\Space output)))) (write-string
                                                                word
                                                                output))
                 (unless last-line-p
                   (write-char #\Newline output)))))))

  (defun fill-paragraph ()
  "Fill the paragraph containing point to the default fill column."
  (let* ((window
          (loom/core/window-tree:window-tree-selected-window
           (editor-state-window-tree *editor-state*)))
         (buffer (loom/core/window-tree:window-buffer window))
         (visible-start (buffer-narrow-start-offset buffer))
         (text (buffer-visible-text buffer))
         (point (- (buffer-point-offset buffer) visible-start))
         (lines (%command-line-ranges text))
         (line-index
          (or
           (position-if
            (lambda (range)
              (<= (car range) point (cdr range)))
            lines)
           (1- (length lines)))))
    (when (%command-blank-line-p text (nth line-index lines))
      (setf line-index (or
                        (position-if
                         (lambda (range)
                           (not (%command-blank-line-p text range)))
                         lines
                         :start
                         (1+ line-index))
                        (position-if
                         (lambda (range)
                           (not (%command-blank-line-p text range)))
                         lines
                         :end
                         line-index))))
    (when line-index
      (let ((first-line line-index)
            (last-line line-index))
        (loop while (and (> first-line 0)
                         (not
                          (%command-blank-line-p text
                                                 (nth (1- first-line) lines))))
              do (decf first-line))
        (loop while (and (< last-line (1- (length lines)))
                         (not
                          (%command-blank-line-p text
                                                 (nth (1+ last-line) lines))))
              do (incf last-line))
        (let* ((start (car (nth first-line lines)))
               (end (cdr (nth last-line lines)))
               (words (%command-paragraph-words text start end))
               (replacement
                (%command-wrap-words words
                                     70
                                     (not
                                      (null
                                       loom/core/command:*current-prefix-argument*))))
               (point-offset (buffer-point-offset buffer)))
          (when words
            (%replace-buffer-offset-range buffer
                                          (+ visible-start start)
                                          (+ visible-start end)
                                          replacement
                                          :minimal-change-p
                                          t
                                          :undo-replacement-p
                                          t)
            (%command-set-point-at-offset buffer
                                          (min point-offset
                                               (+ visible-start
                                                  (length
                                                   (buffer-visible-text buffer))))))))))))
