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

(defun %layout-completion-origin (renderer window completion height)
  "Return the popup origin, or NIL when its anchor is off screen."
  (multiple-value-bind (column row)
      (%layout-buffer-cell renderer window
                           (loom/feature/window:window-buffer window)
                           (editor-completion-line completion)
                           (editor-completion-column completion))
    (let* ((items (min (length (editor-completion-items completion))
                       +layout-completion-rows+))
           (below (1+ row))
           (above (- row items)))
      (when (and (<= 0 row) (< row height) (<= 0 column))
        (cond ((<= (+ below items) height) (values column below))
              ((<= 0 above) (values column above)))))))

(defun %layout-draw-completion (renderer window x-offset)
  "Draw the active completion popup when it belongs to WINDOW's buffer."
  (let ((completion (and *editor-state*
                         (editor-state-completion *editor-state*))))
    (when (and completion
               (eq (editor-completion-buffer completion)
                   (loom/feature/window:window-buffer window))
               (editor-completion-items completion))
      (let ((width (loom/feature/window:window-width window))
            (height (loom/feature/window:window-height window)))
        (when (and (plusp width) (plusp height))
          (multiple-value-bind (rows selected)
              (%layout-completion-rows renderer completion)
            (multiple-value-bind (column row)
                (%layout-completion-origin renderer window completion height)
              (when column
                (let* ((x (+ x-offset (loom/feature/window:window-x window)
                             (min column (1- width))))
                       (y (loom/feature/window:window-y window))
                       (cells (min (- width (min column (1- width)))
                                   (loop for text in rows
                                         maximize (loom-renderer-string-width
                                                   renderer text)))))
                  (loop for text in rows
                        for offset from 0
                        do (loom-renderer-write-string
                            renderer x (+ y row offset)
                            (cl-tty-kit:pad-string
                             (loom-renderer-truncate-string renderer text cells)
                             cells)
                            :style (if (= offset selected)
                                       +layout-completion-selected-style+
                                       +layout-completion-style+))))))))))))
