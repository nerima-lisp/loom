;;;; src/presentation/layout-isearch.lisp

(in-package #:loom)

;;; ---------------------------------------------------------------------
;;; Incremental-search highlighting
;;; ---------------------------------------------------------------------

(defparameter +layout-isearch-match-style+ '((:bg 3) (:fg 0))
  "Style for a search match that is not the one point sits on.")

(defparameter +layout-isearch-current-style+ '((:bg 6) (:fg 0))
  "Style for the match point currently sits on, so it reads apart from the rest.")

(defun %layout-truncated-line-position (renderer window text line start)
  (let* ((scroll-column (loom/feature/window:window-scroll-column window))
         (visible-start
           (loom-renderer-segment-column renderer text (cons 0 (length text))
                                         scroll-column))
         (draw-start (max start visible-start))
         (column (max 0 (- (%layout-screen-column renderer text draw-start)
                          scroll-column))))
    (values draw-start column
            (- line (loom/feature/window:window-scroll-line window)))))

(defun %layout-truncated-line-visible-p (row height draw-start end column width)
  (and (<= 0 row)
       (< row height)
       (< draw-start end)
       (< column width)))

(defun %layout-draw-truncated-line-run (renderer window x y text line start end style)
  (let ((width (loom/feature/window:window-width window))
        (height (loom/feature/window:window-height window)))
    (multiple-value-bind (draw-start column row)
        (%layout-truncated-line-position renderer window text line start)
      (when (%layout-truncated-line-visible-p row height draw-start end column width)
        (loom-renderer-write-string
         renderer (+ x column) (+ y row)
         (loom-renderer-truncate-string
          renderer (subseq text draw-start end) (- width column))
         :style style)))))

(defun %layout-wrapped-segment-position
    (renderer window width height line segments segment start end text)
  (let ((from (max start (car segment)))
        (to (min end (cdr segment))))
    (when (> to from)
      (let ((row (%layout-rows-between
                  renderer
                  (loom/feature/window:window-buffer window)
                  width
                  (loom/feature/window:window-scroll-line window)
                  (loom/feature/window:window-scroll-sub-row window)
                  line
                  (%loom-segment-index segments from)
                  (1- height)))
            (column (loom-renderer-segment-cells renderer text segment from)))
        (when row
          (values from to row column))))))

(defun %layout-draw-wrapped-segment
    (renderer window x y text width height line segments segment start end style)
  (multiple-value-bind (from to row column)
      (%layout-wrapped-segment-position renderer window width height line segments
                                        segment start end text)
    (when row
      (loom-renderer-write-string
       renderer (+ x column) (+ y row)
       (loom-renderer-truncate-string
        renderer (subseq text from to) (- width column))
       :style style))))

(defun %layout-draw-wrapped-line-run
    (renderer window x y text width height line start end style)
  (let ((segments (loom-renderer-wrap-segments renderer text width)))
    (dolist (segment segments)
      (%layout-draw-wrapped-segment
       renderer window x y text width height line segments segment start end style))))

(defun %layout-line-run-geometry (window x-offset line start end)
  (let* ((buffer (loom/feature/window:window-buffer window))
         (text (%layout-visible-line buffer line))
         (width (loom/feature/window:window-width window))
         (height (loom/feature/window:window-height window))
         (y (loom/feature/window:window-y window))
         (x (+ x-offset (loom/feature/window:window-x window)))
         (start (max 0 (min start (length text))))
         (end (max start (min end (length text)))))
    (when (and (plusp width) (plusp height) (> end start))
      (values buffer text width height x y start end))))

(defun %layout-draw-line-run (renderer window x-offset line start end style)
  "Redraw characters [START, END) of WINDOW's buffer LINE in STYLE.

The run is placed with the same geometry the buffer text was drawn with, which
means splitting it per wrapped segment when the window wraps and shifting it by
the scroll column when it truncates. A run scrolled or wrapped off the window
draws nothing rather than clipping to the wrong row."
  (multiple-value-bind (buffer text width height x y start end)
      (%layout-line-run-geometry window x-offset line start end)
    (when buffer
      (if (loom/feature/mode:buffer-truncate-lines-p buffer)
          (%layout-draw-truncated-line-run
           renderer window x y text line start end style)
          (%layout-draw-wrapped-line-run
           renderer window x y text width height line start end style)))))

(defun %layout-span-line-bounds (buffer span)
  (let ((start (buffer-visible-offset-position buffer
                                                (buffer-span-start span)))
        (end (buffer-visible-offset-position buffer
                                              (buffer-span-end span))))
    (when (and start end)
      (values (buffer-position-line start)
              (buffer-position-column start)
              (buffer-position-line end)
              (buffer-position-column end)))))

(defun %layout-span-line-run-bounds (buffer line first-line first-column last-line last-column)
  (values (if (= line first-line) first-column 0)
          (if (= line last-line)
              last-column
              (length (%layout-visible-line buffer line)))))

(defun %layout-draw-span (renderer window x-offset span style)
  "Redraw the buffer text SPAN covers in STYLE, one logical line at a time."
  (let ((buffer (loom/feature/window:window-buffer window)))
    (multiple-value-bind (first-line first-column last-line last-column)
        (%layout-span-line-bounds buffer span)
      (when first-line
        (loop for line from first-line to last-line
              do (multiple-value-bind (start end)
                     (%layout-span-line-run-bounds
                      buffer line first-line first-column last-line last-column)
                   (%layout-draw-line-run
                    renderer window x-offset line start end style)))))))

(defun %layout-isearch-session-for-window (window)
  (let ((session (and *editor-state* (editor-state-isearch *editor-state*))))
    (when (and session
               (eq (loom/feature/search:isearch-session-buffer session)
                   (loom/feature/window:window-buffer window)))
      session)))

(defun %layout-isearch-span-style (span current)
  (if (and current
           (= (buffer-span-start span)
              (buffer-span-start current)))
      +layout-isearch-current-style+
      +layout-isearch-match-style+))

(defun %layout-draw-isearch (renderer window x-offset)
  "Highlight the active incremental search's matches inside WINDOW.

Only the window's own buffer is highlighted: a session belongs to the buffer it
started in, and painting its offsets onto a different buffer would mark text
that never matched."
  (let ((session (%layout-isearch-session-for-window window)))
    (when session
      (let ((current (loom/feature/search:isearch-session-match session)))
        (dolist (span (loom/feature/search:isearch-session-matches session))
          (%layout-draw-span renderer window x-offset span
                             (%layout-isearch-span-style span current)))))))
