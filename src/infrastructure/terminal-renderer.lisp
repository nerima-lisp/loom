(in-package #:loom)

(defstruct (%loom-renderer-glyph
              (:constructor %make-loom-renderer-glyph (x y text width style))
              (:copier nil))
    (x 0 :type fixnum :read-only t)
    (y 0 :type fixnum :read-only t)
    (text "" :type string :read-only t)
    (width 1 :type fixnum :read-only t)
    (style "" :type string :read-only t))

  (defstruct (loom-renderer
              (:conc-name %loom-renderer-)
              (:constructor %make-loom-renderer (cl-tty-renderer))
              (:copier nil))
    "A loom renderer backed by a single CL-TTY-KIT renderer object."
    cl-tty-renderer
    (glyphs (make-hash-table :test #'eql) :type hash-table)
    (presented-glyphs (make-hash-table :test #'eql) :type hash-table))

  (defun %loom-renderer-glyph-key (renderer x y)
    (+ x (* y (cl-tty-kit:renderer-width
               (%loom-renderer-cl-tty-renderer renderer)))))

  (defun %loom-renderer-clear-glyphs-in-region (renderer x y width height)
    (when (and (plusp width) (plusp height))
      (let ((glyphs (%loom-renderer-glyphs renderer))
            (right (+ x width))
            (bottom (+ y height)))
        (maphash
         (lambda (key glyph)
           (when (and (<= y (%loom-renderer-glyph-y glyph))
                      (< (%loom-renderer-glyph-y glyph) bottom)
                      (< (%loom-renderer-glyph-x glyph) right)
                      (< x (+ (%loom-renderer-glyph-x glyph)
                              (%loom-renderer-glyph-width glyph))))
             (remhash key glyphs)))
         glyphs)))
    renderer)

  (defun %loom-renderer-style-sequence (style)
    (apply #'cl-tty-kit:style-ansi
           (cl-tty-kit:cell-style (cl-tty-kit:make-cell :style style))))

  (defun %loom-renderer-screen-compatible-prefix (text available-cells tab-width)
    (loop with source-index = 0
          with screen-column = 0
          for grapheme in (cl-tty-kit:string-graphemes text)
          for advance =
            (max 1 (%loom-renderer-grapheme-advance
                    grapheme screen-column tab-width))
          do (when (> (+ screen-column advance) available-cells)
               (return (subseq text 0 source-index)))
             (incf source-index (length grapheme))
             (incf screen-column advance)
          finally (return text)))

  (defun %loom-renderer-screen-text-and-glyphs (text x y tab-width style-sequence)
    (let ((cell-column 0)
          (glyphs nil))
      (values
       (with-output-to-string (output)
         (dolist (grapheme (cl-tty-kit:string-graphemes text))
           (let* ((advance
                    (max 1 (%loom-renderer-grapheme-advance
                            grapheme cell-column tab-width)))
                  (grapheme-width (length grapheme)))
             (if (> grapheme-width 1)
                 (progn
                   (write-string
                    (make-string advance :initial-element #\Space)
                    output)
                   (push (%make-loom-renderer-glyph
                          (+ x cell-column) y grapheme advance style-sequence)
                         glyphs))
                 (write-string grapheme output))
             (incf cell-column advance))))
       (nreverse glyphs)
       cell-column)))

  (defun loom-renderer-write-string (renderer x y string &key style (tab-width 8))
    "Write STRING at (X, Y), expanding tabs and clipping to screen-safe graphemes.
Returns RENDERER."
    (let* ((expanded
             (if (find #\Tab string)
                 (nth-value 0
                            (%loom-renderer-expand-tabs
                             string :tab-width tab-width :start-column x))
                 string))
           (screen-width (loom-renderer-width renderer))
           (visible
             (if (and (integerp x) (<= 0 x screen-width))
                 (%loom-renderer-screen-compatible-prefix
                  expanded (- screen-width x) tab-width)
                 expanded))
           (style-sequence (%loom-renderer-style-sequence style)))
      (multiple-value-bind (screen-text glyphs cell-width)
          (%loom-renderer-screen-text-and-glyphs
           visible x y tab-width style-sequence)
        (cl-tty-kit:screen-write-string
         (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer))
         x y screen-text :style style)
        (%loom-renderer-clear-glyphs-in-region renderer x y cell-width 1)
        (dolist (glyph glyphs)
          (setf (gethash (%loom-renderer-glyph-key
                          renderer
                          (%loom-renderer-glyph-x glyph)
                          (%loom-renderer-glyph-y glyph))
                         (%loom-renderer-glyphs renderer))
                glyph)))
      renderer))

(defun make-loom-renderer (width height)
  "Create and return a new loom renderer backed by a CL-TTY-KIT screen and
double-buffered diff renderer (as if by CL-TTY-KIT:MAKE-SCREEN and
CL-TTY-KIT:MAKE-RENDERER) of the given WIDTH and HEIGHT, in terminal columns
and rows respectively."
  (%make-loom-renderer (cl-tty-kit:make-renderer width height)))

(defun loom-renderer-width (renderer)
  "Return RENDERER's width in terminal columns."
  (cl-tty-kit:renderer-width (%loom-renderer-cl-tty-renderer renderer)))

(defun loom-renderer-height (renderer)
  "Return RENDERER's height in terminal rows."
  (cl-tty-kit:renderer-height (%loom-renderer-cl-tty-renderer renderer)))



(defun loom-renderer-draw-horizontal-line (renderer x y length)
  "Draw a horizontal line of LENGTH cells at (X, Y) on RENDERER's screen.
Returns RENDERER."
  (cl-tty-kit:screen-draw-horizontal-line
   (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer))
   x y length)
  (%loom-renderer-clear-glyphs-in-region renderer x y length 1)
  renderer)

(defun loom-renderer-draw-vertical-line (renderer x y length)
  "Draw a vertical line of LENGTH cells at (X, Y) on RENDERER's screen.
Returns RENDERER."
  (cl-tty-kit:screen-draw-vertical-line
   (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer))
   x y length)
  (%loom-renderer-clear-glyphs-in-region renderer x y 1 length)
  renderer)

(defun loom-renderer-clear (renderer)
  "Clear RENDERER's screen. Returns RENDERER."
  (cl-tty-kit:screen-clear
   (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer)))
  (clrhash (%loom-renderer-glyphs renderer))
  renderer)

(defun %loom-renderer-draw-buffer-row (renderer buffer x y width line-number line-count)
  (when (< line-number line-count)
    (let* ((mode (buffer-major-mode buffer))
           (tab-width
             (max 1 (loom/feature/mode:major-mode-tab-width mode)))
           (text (nth-value 0
                            (%loom-renderer-expand-tabs
                             (buffer-visible-line buffer line-number)
                             :tab-width tab-width)))
           (visible (loom-renderer-truncate-string renderer text width)))
      (loom-renderer-write-string renderer x y visible)))
  renderer)

(defun loom-renderer-draw-buffer (renderer buffer x y width height &key (start-line 0))
  "Draw BUFFER's currently visible region into RENDERER's screen, occupying
the rectangle whose top-left corner is (X, Y) and which is WIDTH columns by
HEIGHT rows, all in screen-cell coordinates. Does not itself flush anything
to a terminal -- see LOOM-RENDERER-PRESENT. Returns RENDERER."
  (let ((line-count (buffer-visible-line-count buffer)))
    (dotimes (row height)
      (%loom-renderer-draw-buffer-row renderer buffer x (+ y row) width
                                      (+ start-line row) line-count))
    renderer))

(defun %loom-renderer-glyph-same-p (left right)
    (and left right
         (= (%loom-renderer-glyph-x left) (%loom-renderer-glyph-x right))
         (= (%loom-renderer-glyph-y left) (%loom-renderer-glyph-y right))
         (= (%loom-renderer-glyph-width left) (%loom-renderer-glyph-width right))
         (string= (%loom-renderer-glyph-text left)
                  (%loom-renderer-glyph-text right))
         (string= (%loom-renderer-glyph-style left)
                  (%loom-renderer-glyph-style right))))

  (defun %loom-renderer-clear-presented-glyphs (renderer stream)
    (let ((presented (%loom-renderer-presented-glyphs renderer))
          (current (%loom-renderer-glyphs renderer))
          (screen
            (cl-tty-kit:renderer-screen (%loom-renderer-cl-tty-renderer renderer)))
          (stale nil))
      (maphash
       (lambda (key glyph)
         (unless (%loom-renderer-glyph-same-p glyph (gethash key current))
           (push (cons key glyph) stale)))
       presented)
      (when stale
        (write-string (cl-tty-kit:ansi-save-cursor) stream)
        (dolist (entry (sort stale #'< :key #'car))
          (let ((glyph (cdr entry)))
            (write-string
             (cl-tty-kit:ansi-move-cursor
              (1+ (%loom-renderer-glyph-y glyph))
              (1+ (%loom-renderer-glyph-x glyph)))
             stream)
            (loop for column from (%loom-renderer-glyph-x glyph)
                  below (+ (%loom-renderer-glyph-x glyph)
                           (%loom-renderer-glyph-width glyph))
                  for cell = (cl-tty-kit:screen-cell
                              screen column (%loom-renderer-glyph-y glyph))
                  for style-sequence =
                    (apply #'cl-tty-kit:style-ansi
                           (cl-tty-kit:cell-style cell))
                  do (write-string style-sequence stream)
                     (write-char #\Space stream)
                     (unless (zerop (length style-sequence))
                       (write-string (cl-tty-kit:ansi-reset-style) stream))))
        (write-string (cl-tty-kit:ansi-reset-style) stream)
        (write-string (cl-tty-kit:ansi-restore-cursor) stream))))) (defun %loom-renderer-overlay-glyphs (renderer stream)
    (let ((glyphs (%loom-renderer-glyphs renderer))
          (entries nil))
      (maphash (lambda (key glyph)
                 (push (cons key glyph) entries))
               glyphs)
      (when entries
        (write-string (cl-tty-kit:ansi-save-cursor) stream)
        (dolist (entry (sort entries #'< :key #'car))
          (let ((glyph (cdr entry)))
            (write-string
             (cl-tty-kit:ansi-move-cursor
              (1+ (%loom-renderer-glyph-y glyph))
              (1+ (%loom-renderer-glyph-x glyph)))
             stream)
            (write-string (%loom-renderer-glyph-style glyph) stream)
            (write-string (%loom-renderer-glyph-text glyph) stream)
            (write-string (cl-tty-kit:ansi-reset-style) stream)))
        (write-string (cl-tty-kit:ansi-restore-cursor) stream)))) (defun %loom-renderer-snapshot-glyphs (renderer)
    (let ((presented (%loom-renderer-presented-glyphs renderer)))
      (clrhash presented)
      (maphash (lambda (key glyph)
                 (setf (gethash key presented) glyph))
               (%loom-renderer-glyphs renderer)))
    renderer) (defun loom-renderer-present (renderer &key stream cursor)
    "Flush RENDERER's pending screen diff to STREAM and position the terminal
cursor at CURSOR when supplied. Returns RENDERER."
    (let ((output-stream (or stream *standard-output*)))
      (%loom-renderer-clear-presented-glyphs renderer output-stream)
      (write-string
       (cl-tty-kit:renderer-render
        (%loom-renderer-cl-tty-renderer renderer)
        :cursor cursor)
       output-stream)
      (%loom-renderer-overlay-glyphs renderer output-stream)
      (%loom-renderer-snapshot-glyphs renderer)
      (finish-output output-stream))
    renderer)

(defun %loom-renderer-frame-cells (renderer)
  (let* ((width (loom-renderer-width renderer))
         (height (loom-renderer-height renderer))
         (screen (cl-tty-kit:renderer-screen
                  (%loom-renderer-cl-tty-renderer renderer)))
         (glyphs (%loom-renderer-glyphs renderer))
         (cells (make-array (* width height))))
    (dotimes (y height cells)
      (let ((x 0))
        (loop while (< x width)
              for screen-cell = (cl-tty-kit:screen-cell screen x y)
              for overlay = (gethash (%loom-renderer-glyph-key renderer x y)
                                     glyphs)
              for glyph = (if overlay
                              (%loom-renderer-glyph-text overlay)
                              (string (cl-tty-kit:cell-char screen-cell)))
              for style = (cl-tty-kit:cell-style screen-cell)
              for advance = (if overlay
                                (%loom-renderer-glyph-width overlay)
                                (max 1 (%loom-renderer-grapheme-advance
                                        glyph x 8)))
              do (if (> (+ x advance) width)
                     (setf (aref cells (+ (* y width) x))
                           (list " " style))
                     (progn
                       (setf (aref cells (+ (* y width) x))
                             (list glyph style))
                       (loop for offset from 1 below advance
                             for continuation-cell =
                               (cl-tty-kit:screen-cell screen (+ x offset) y)
                             do (setf (aref cells (+ (* y width) x offset))
                                      (list nil
                                            (cl-tty-kit:cell-style
                                             continuation-cell))))))
              do (incf x (if (> (+ x advance) width) 1 advance)))))))

(defun %loom-renderer-frame-glyph-layout (text)
  (let* ((display-text
           (if (find (code-char 9) text)
               (nth-value 0 (%loom-renderer-expand-tabs text))
               text))
         (column 0)
         (glyphs nil)
         (widths nil))
    (dolist (grapheme (cl-tty-kit:string-graphemes display-text))
      (let ((advance
              (max 1 (%loom-renderer-grapheme-advance grapheme column 8))))
        (push grapheme glyphs)
        (push advance widths)
        (incf column advance)))
    (values (coerce (nreverse glyphs) 'vector)
            (coerce (nreverse widths) 'vector))))

(defun loom-renderer-load-frame-snapshot (renderer snapshot)
  (unless (and (= (loom-renderer-width renderer)
                  (loom/core/editor-session:frame-snapshot-width snapshot))
               (= (loom-renderer-height renderer)
                  (loom/core/editor-session:frame-snapshot-height snapshot)))
    (error "Frame snapshot dimensions do not match the renderer."))
  (loom-renderer-clear renderer)
  (let ((screen (cl-tty-kit:renderer-screen
                 (%loom-renderer-cl-tty-renderer renderer))))
    (dotimes (y (loom-renderer-height renderer))
      (dotimes (x (loom-renderer-width renderer))
        (multiple-value-bind (glyph style)
            (loom/core/editor-session:frame-snapshot-cell snapshot x y)
          (let* ((single-character-p
                   (and (stringp glyph) (= (length glyph) 1)))
                 (character (if single-character-p
                                (char glyph 0)
                                #\Space)))
            (if single-character-p
                (cl-tty-kit:screen-write-string screen x y glyph :style style)
                (cl-tty-kit:screen-put-cell
                 screen x y
                 (cl-tty-kit:make-cell :char character :style style)))
            (when (and (stringp glyph) (not single-character-p))
              (let ((width
                      (max 1 (%loom-renderer-grapheme-advance glyph x 8))))
                (when (<= (+ x width) (loom-renderer-width renderer))
                  (setf (gethash (%loom-renderer-glyph-key renderer x y)
                                 (%loom-renderer-glyphs renderer))
                        (%make-loom-renderer-glyph
                         x y glyph width
                         (%loom-renderer-style-sequence style))))))))))
  renderer))
