;;;; src/presentation/layout-minibuffer.lisp
;;;;
;;;; Presentation layer: minibuffer and shortcut line rendering helpers.
(in-package #:loom)

(defparameter +layout-shortcut-line+ "C-h Help  C-x C-s Save  C-s Find  C-x C-c Exit")

(defun %layout-draw-shortcuts (renderer width row buffer &optional workspace-name)
  "Draw the persistent command reminder immediately above the minibuffer."
  (when (plusp width)
    (let* ((text (format nil "Ln ~D, Col ~D  ~A"
                         (1+ (buffer-visible-point-line buffer))
                         (1+ (%layout-buffer-point-screen-column renderer buffer))
                         (if workspace-name
                             (format nil "Workspace: ~A  ~A"
                                     workspace-name
                                     +layout-shortcut-line+)
                             +layout-shortcut-line+)))
           (visible (%layout-truncate-to-width text width)))
      (loom-renderer-write-string renderer 0 row visible :style '(:reverse)))))

(defun %layout-minibuffer-line (minibuffer)
  "Return the single line of text MINIBUFFER should currently show at the
bottom of the screen: prompt+input while MINIBUFFER-ACTIVE-P, else the last
transient status message set via MINIBUFFER-MESSAGE, else the empty string."
  (cond
    ((minibuffer-active-p minibuffer)
     (concatenate 'string (or (minibuffer-prompt-string minibuffer) "")
                  (minibuffer-input-string minibuffer)))
    ((minibuffer-message-string minibuffer))
    (t "")))

(defun %layout-draw-minibuffer (renderer minibuffer width row)
  "Draw MINIBUFFER's current line (see %LAYOUT-MINIBUFFER-LINE) into RENDERER's
ROW, truncated to WIDTH columns."
  (when (plusp width)
    (let* ((text (%layout-minibuffer-line minibuffer))
           (visible (%layout-truncate-to-width text width)))
      (loom-renderer-write-string renderer 0 row visible))))

(defparameter +layout-completion-rows+ 8)
(defparameter +layout-completion-width+ 40)
(defparameter +layout-completion-style+ '((:bg 4) (:fg 7)))
(defparameter +layout-completion-selected-style+ '(:bold (:bg 6) (:fg 0)))

(defun %layout-completion-rows (renderer completion)
  "Return visible labels and the selected row within them."
  (let* ((items (editor-completion-items completion))
         (count (length items))
         (visible (min count +layout-completion-rows+))
         (index (editor-completion-index completion))
         (first (max 0 (min (- index (floor visible 2)) (- count visible)))))
    (values (loop for offset below visible
                  collect (loom-renderer-truncate-string
                           renderer
                           (editor-completion-item-label
                            (nth (+ first offset) items))
                           +layout-completion-width+))
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
    (and completion
         (eq (editor-completion-buffer completion)
             (loom/feature/window:window-buffer window))
         (editor-completion-items completion)
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

(defun %layout-draw-completion (renderer window x-offset)
  "Draw the active completion popup when it belongs to WINDOW's buffer."
  (let ((completion (%layout-active-completion window)))
    (when completion
      (let ((width (loom/feature/window:window-width window))
            (height (loom/feature/window:window-height window)))
        (when (and (plusp width) (plusp height))
          (multiple-value-bind (rows selected)
              (%layout-completion-rows renderer completion)
            (multiple-value-bind (column row)
              (%layout-completion-origin renderer window completion height)
              (when column
                (%layout-draw-completion-popup
                 renderer window x-offset rows selected column row)))))))))
