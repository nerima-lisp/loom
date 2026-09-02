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
