(in-package #:loom)

(defparameter *editor-recent-file-limit* 50
  "Maximum number of file paths retained by the in-memory recent-file list.")

(defvar *editor-state* nil
  "The editor state used by commands, initialized by %INITIALIZE-EDITOR-STATE.")

(defvar *buffer-truncate-policy-owner*
  nil)

(defvar *buffer-truncate-policy-function*
  nil)

(defun register-buffer-truncate-policy (owner function)
  (unless (functionp function)
    (error "Buffer truncate policy must be a function"))
  (when
      (and *buffer-truncate-policy-owner*
           (not (equal *buffer-truncate-policy-owner* owner)))
    (error "Buffer truncate policy is already registered by ~S"
           *buffer-truncate-policy-owner*))
  (setf *buffer-truncate-policy-owner* owner
        *buffer-truncate-policy-function* function)
  function)

(defvar *visual-row-layout-function*
  nil)

(defvar *visual-row-layout-owner*
  nil)
