(in-package #:loom/core/editor-session)

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

(defun editor-state-clear-last-yank (editor-state)
  "Clear the transient state used by yank-pop."
  (setf (editor-state-last-yank-buffer editor-state) nil
        (editor-state-last-yank-start-offset editor-state) nil
        (editor-state-last-yank-end-offset editor-state) nil
        (editor-state-last-yank-ranges editor-state) nil
        (editor-state-last-yank-ring-index editor-state) nil
        (editor-state-last-yank-repeat-count editor-state) nil))
