(in-package #:loom)

(defconstant +layout-completion-rows+ 8)
(defconstant +layout-completion-width+ 40)
(defparameter +layout-completion-style+ '((:bg 4) (:fg 7)))
(defvar *layout-buffer-cell-function* nil)
(defparameter +layout-completion-selected-style+ '(:bold (:bg 6) (:fg 0)))

(defun %layout-completion-first-index (index count visible)
  (max 0 (min (- index (floor visible 2)) (- count visible))))

(defun %layout-completion-popup-row (row item-count height)
  (let ((below (1+ row))
        (above (- row item-count)))
    (cond ((<= (+ below item-count) height) below)
          ((<= 0 above) above))))
