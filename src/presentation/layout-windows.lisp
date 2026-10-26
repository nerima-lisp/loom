(in-package #:loom)

(defparameter +layout-mode-line-selected-style+ '(:reverse)
  "Style for the mode line of the selected leaf window.")

(defparameter +layout-mode-line-unselected-style+ '((:fg 8))
  "Style for the mode line of a leaf window that is not selected.")

(defun %layout-mode-line-text (renderer buffer &optional workspace-name)
  "Return BUFFER's complete mode line text before width clipping."
  (format nil "~{~A~}~@[  Workspace: ~A~]"
          (%layout-mode-line-parts renderer buffer)
          workspace-name))

(defparameter +layout-matching-paren-style+ '(:bold (:bg 5) (:fg 0))
  "Style marking the parenthesis at point and the one it pairs with.")

(defparameter +layout-region-style+ '((:bg 2) (:fg 0))
  "Style marking the active region.")

(defparameter +layout-diagnostic-style+ '((:bg 1) (:fg 7))
  "Style marking text covered by an LSP diagnostic.")

(defvar *layout-trace-last-entry* nil)
(defvar *layout-trace-last-warning-entry* nil)
