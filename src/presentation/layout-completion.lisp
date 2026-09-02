;;;; src/presentation/layout-completion.lisp
;;;;
;;;; Presentation layer: completion popup rendering helpers.
(in-package #:loom)

(defparameter +layout-completion-rows+ 8)
(defparameter +layout-completion-width+ 40)
(defparameter +layout-completion-style+ '((:bg 4) (:fg 7)))
(defparameter +layout-completion-selected-style+ '(:bold (:bg 6) (:fg 0)))

(defun %layout-completion-first-index (index count visible)
  (max 0 (min (- index (floor visible 2)) (- count visible))))

(defun %layout-completion-labels (renderer items first visible)
  (loop for offset below visible
        collect (loom-renderer-truncate-string
                 renderer
                 (editor-completion-item-label
                  (nth (+ first offset) items))
                 +layout-completion-width+)))

(defun %layout-completion-rows (renderer completion)
  "Return visible labels and the selected row within them."
  (let* ((items (editor-completion-items completion))
         (count (length items))
         (visible (min count +layout-completion-rows+))
         (index (editor-completion-index completion))
         (first (%layout-completion-first-index index count visible)))
    (values (%layout-completion-labels renderer items first visible)
            (- index first))))

(defun %layout-completion-popup-item-count (completion)
  (min (length (editor-completion-items completion))
       +layout-completion-rows+))

(defun %layout-completion-popup-row (row item-count height)
  (let ((below (1+ row))
        (above (- row item-count)))
    (cond ((<= (+ below item-count) height) below)
          ((<= 0 above) above))))

(defun %layout-completion-origin (renderer window completion height)
  "Return the popup origin, or NIL when its anchor is off screen."
  (multiple-value-bind (column row)
      (%layout-buffer-cell renderer window
                           (loom/feature/window:window-buffer window)
                           (editor-completion-line completion)
                           (editor-completion-column completion))
    (when (and (<= 0 row) (< row height) (<= 0 column))
      (let ((popup-row (%layout-completion-popup-row
                       row
                       (%layout-completion-popup-item-count completion)
                       height)))
        (when popup-row
          (values column popup-row))))))

(defun %layout-active-completion (window)
  (let ((completion (and *editor-state*
                         (editor-state-completion *editor-state*))))
    (when (and completion
               (eq (editor-completion-buffer completion)
                   (loom/feature/window:window-buffer window))
               (editor-completion-items completion))
      completion)))

(defun %layout-completion-cells (renderer rows width column)
  (min (- width (min column (1- width)))
       (loop for text in rows
             maximize (loom-renderer-string-width renderer text))))

(defun %layout-draw-completion-row (renderer x y offset text selected cells)
  (loom-renderer-write-string
   renderer x (+ y offset)
   (cl-tty-kit:pad-string
    (loom-renderer-truncate-string renderer text cells)
    cells)
   :style (if (= offset selected)
              +layout-completion-selected-style+
              +layout-completion-style+)))

(defun %layout-draw-completion-popup (renderer window x-offset rows selected
                                       column row)
  (let* ((width (loom/feature/window:window-width window))
         (x (+ x-offset (loom/feature/window:window-x window)
               (min column (1- width))))
         (y (+ row (loom/feature/window:window-y window)))
         (cells (%layout-completion-cells renderer rows width column)))
    (loop for text in rows
          for offset from 0
          do (%layout-draw-completion-row
              renderer x y offset text selected cells))))

(defun %layout-draw-completion-content (renderer window x-offset completion)
  (let ((width (loom/feature/window:window-width window))
        (height (loom/feature/window:window-height window)))
    (when (and (plusp width) (plusp height))
      (multiple-value-bind (rows selected)
          (%layout-completion-rows renderer completion)
        (multiple-value-bind (column row)
            (%layout-completion-origin renderer window completion height)
          (when column
            (%layout-draw-completion-popup
             renderer window x-offset rows selected column row)))))))

(defun %layout-draw-completion (renderer window x-offset)
  "Draw the active completion popup when it belongs to WINDOW's buffer."
  (let ((completion (%layout-active-completion window)))
    (when completion
      (%layout-draw-completion-content renderer window x-offset completion))))
