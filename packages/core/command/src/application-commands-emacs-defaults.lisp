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
(progn
  (defun %command-selected-buffer ()
    (loom/core/window-tree:window-buffer
     (loom/core/window-tree:window-tree-selected-window
      (editor-state-window-tree *editor-state*))))

  (defun back-to-indentation ()
    (let* ((buffer (%command-selected-buffer))
           (visible-start (buffer-narrow-start-offset buffer))
           (text (buffer-visible-text buffer))
           (point (- (buffer-point-offset buffer) visible-start))
           (start (1+ (or (position #\Newline text :end point :from-end t) -1))))
      (loop while (and (< start (length text))
                       (%command-horizontal-space-p (char text start)))
            do (incf start))
      (%command-set-point-at-offset buffer (+ visible-start start))))

  (defun %command-whitespace-span (text point include-newlines-p)
    (flet ((space-p (character)
             (or (%command-horizontal-space-p character)
                 (and include-newlines-p (char= character #\Newline)))))
      (let ((start point)
            (end point))
        (loop while (and (plusp start) (space-p (char text (1- start))))
              do (decf start))
        (loop while (and (< end (length text)) (space-p (char text end)))
              do (incf end))
        (values start end))))

  (defun delete-horizontal-space ()
    (let* ((buffer (%command-selected-buffer))
           (visible-start (buffer-narrow-start-offset buffer))
           (text (buffer-visible-text buffer))
           (point (- (buffer-point-offset buffer) visible-start)))
      (when (loom/core/buffer:buffer-read-only-p buffer)
        (error 'loom/core/buffer:buffer-read-only-error :buffer buffer))
      (multiple-value-bind (start end) (%command-whitespace-span text point nil)
        (when *current-prefix-argument* (setf end point))
        (when (< start end)
          (buffer-record-undo-boundary buffer)
          (%replace-buffer-offset-range buffer (+ visible-start start)
                                        (+ visible-start end) ""
                                        :undo-replacement-p t)
          (buffer-record-undo-boundary buffer)))))

  (defun just-one-space ()
    (let* ((buffer (%command-selected-buffer))
           (visible-start (buffer-narrow-start-offset buffer))
           (text (buffer-visible-text buffer))
           (point (- (buffer-point-offset buffer) visible-start))
           (count (or *current-prefix-argument* 1))
           (replacement (make-string (abs count) :initial-element #\Space)))
      (when (loom/core/buffer:buffer-read-only-p buffer)
        (error 'loom/core/buffer:buffer-read-only-error :buffer buffer))
      (multiple-value-bind (start end)
          (%command-whitespace-span text point (minusp count))
        (unless (string= text replacement :start1 start :end1 end)
          (buffer-record-undo-boundary buffer)
          (%replace-buffer-offset-range buffer (+ visible-start start)
                                        (+ visible-start end) replacement
                                        :undo-replacement-p t)
          (buffer-record-undo-boundary buffer))
        (%command-set-point-at-offset buffer (+ visible-start start (abs count))))))

  (defun %command-backward-word-offset (text offset)
    (loop while (and (plusp offset)
                     (not (%command-word-character-p (char text (1- offset)))))
          do (decf offset))
    (loop while (and (plusp offset)
                     (%command-word-character-p (char text (1- offset))))
          do (decf offset))
    offset)

  (defun %command-move-word-offset (text offset count)
    (loop with mover = (if (minusp count)
                          #'%command-backward-word-offset
                          #'%command-forward-word-offset)
          repeat (abs count)
          for next = (funcall mover text offset)
          when (= next offset) do (return offset)
          do (setf offset next)
          finally (return offset)))

  (defun %command-word-span (text point count)
    (let* ((end (%command-move-word-offset text point count))
           (start (%command-move-word-offset text end (- count))))
      (cons (min start end) (max start end))))

  (defun %command-transposed-marker-offset (offset left right)
    ;; Match Emacs's insertion/deletion order at word boundaries for M-0 M-t.
    (let* ((left-length (- (cdr left) (car left)))
           (right-length (- (cdr right) (car right)))
           (boundary (+ (car right) right-length (- left-length))))
      (when (>= offset (cdr left)) (incf offset right-length))
      (when (> offset (car left))
        (setf offset (max (car left) (- offset left-length))))
      (when (> offset boundary) (incf offset left-length))
      (when (> offset (+ boundary left-length))
        (setf offset (max (+ boundary left-length) (- offset right-length))))
      offset))

  (defun transpose-words ()
    (let* ((buffer (%command-selected-buffer))
           (visible-start (buffer-narrow-start-offset buffer))
           (text (buffer-visible-text buffer))
           (point (- (buffer-point-offset buffer) visible-start))
           (count (or *current-prefix-argument* 1)))
      (when (loom/core/buffer:buffer-read-only-p buffer)
        (error 'loom/core/buffer:buffer-read-only-error :buffer buffer))
      (multiple-value-bind (mark-line mark-column) (loom/core/buffer:buffer-mark buffer)
        (when (and (zerop count) (null mark-line))
          (minibuffer-message (editor-state-minibuffer *editor-state*)
                              "The mark is not set")
          (return-from transpose-words nil))
        (let* ((mark (when (zerop count)
                       (max 0 (min (length text) (- (loom/core/buffer:buffer-clamped-position-offset buffer mark-line mark-column) visible-start)))))
               (first (%command-word-span text point (if (zerop count) 1 -1)))
               (second (%command-word-span
                        text
                        (cond ((zerop count) mark)
                              ((plusp count) (cdr first))
                              (t (car first)))
                        (if (zerop count) 1 count))))
          (when (> (car first) (car second)) (rotatef first second))
          (unless (and (< (car first) (cdr first))
                       (<= (cdr first) (car second))
                       (< (car second) (cdr second)))
            (error "Don't have two things to transpose"))
          (let* ((replacement (concatenate 'string
                                           (subseq text (car second) (cdr second))
                                           (subseq text (cdr first) (car second))
                                           (subseq text (car first) (cdr first))))
                 (new-point
                  (cond ((zerop count)
                         (%command-transposed-marker-offset mark first second))
                        ((plusp count) (cdr second))
                        (t (+ (car first) (- (cdr second) (car second))))))
                 (new-mark (when (zerop count)
                             (%command-transposed-marker-offset point first second))))
            (buffer-record-undo-boundary buffer)
            (%replace-buffer-offset-range buffer (+ visible-start (car first))
                                          (+ visible-start (cdr second)) replacement
                                          :undo-replacement-p t)
            (%command-set-point-at-offset buffer (+ visible-start new-point))
            (when new-mark
              (let ((position (buffer-offset-position buffer (+ visible-start new-mark))))
                (loom/core/buffer:buffer-set-mark buffer
                                                 (buffer-position-line position)
                                                 (buffer-position-column position))))
            (buffer-record-undo-boundary buffer))))))

  (defun count-words-region ()
    (let* ((buffer (%command-selected-buffer))
           (visible-start (buffer-narrow-start-offset buffer))
           (text (buffer-visible-text buffer))
           (start 0)
           (end (length text))
           (region-p nil))
      (multiple-value-bind (mark-line mark-column) (loom/core/buffer:buffer-mark buffer)
        (when (and mark-line (loom/core/buffer:buffer-mark-active-p buffer))
          (let ((mark (max 0 (min end
                                 (- (loom/core/buffer:buffer-clamped-position-offset
                                     buffer mark-line mark-column)
                                    visible-start))))
                (point (- (buffer-point-offset buffer) visible-start)))
            (setf start (min point mark) end (max point mark) region-p t))))
      (let ((lines 0) (words 0) (in-word-p nil))
        (loop for offset from start below end
              for character = (char text offset)
              for word-p = (%command-word-character-p character)
              do (when (char= character #\Newline) (incf lines))
                 (when (and word-p (not in-word-p)) (incf words))
                 (setf in-word-p word-p))
        (when (and (< start end) (not (char= (char text (1- end)) #\Newline)))
          (incf lines))
        (minibuffer-message
         (editor-state-minibuffer *editor-state*)
         (format nil "~A has ~D lines, ~D words, and ~D characters."
                 (if region-p "Region" "Buffer") lines words (- end start)))))))
