(in-package #:loom)

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
