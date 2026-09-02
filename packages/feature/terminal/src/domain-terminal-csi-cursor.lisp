(in-package #:loom/feature/terminal)

(defun %terminal-screen-csi-move-row (screen amount direction)
  (incf (terminal-screen-cursor-row screen) (* direction amount)))

(defun %terminal-screen-csi-move-column (screen amount direction)
  (incf (terminal-screen-cursor-column screen) (* direction amount)))

(defun %terminal-screen-csi-next-line (screen amount)
  (%terminal-screen-csi-move-row screen amount 1)
  (setf (terminal-screen-cursor-column screen) 0))

(defun %terminal-screen-csi-previous-line (screen amount)
  (%terminal-screen-csi-move-row screen amount -1)
  (setf (terminal-screen-cursor-column screen) 0))

(defun %terminal-screen-csi-up (screen amount)
  (%terminal-screen-csi-move-row screen amount -1))

(defun %terminal-screen-csi-down (screen amount)
  (%terminal-screen-csi-move-row screen amount 1))

(defun %terminal-screen-csi-right (screen amount)
  (%terminal-screen-csi-move-column screen amount 1))

(defun %terminal-screen-csi-left (screen amount)
  (%terminal-screen-csi-move-column screen amount -1))

(defparameter +terminal-screen-csi-relative-cursor-handlers+
  '((#\A . %terminal-screen-csi-up)
    (#\B . %terminal-screen-csi-down)
    (#\C . %terminal-screen-csi-right)
    (#\D . %terminal-screen-csi-left)
    (#\E . %terminal-screen-csi-next-line)
    (#\F . %terminal-screen-csi-previous-line)
    (#\a . %terminal-screen-csi-right)
    (#\e . %terminal-screen-csi-down)))

(defun %terminal-screen-csi-relative-cursor-handler (final)
  (cdr (assoc final +terminal-screen-csi-relative-cursor-handlers+)))

(defun %terminal-screen-csi-relative-cursor (screen final parameters)
  (let ((handler (%terminal-screen-csi-relative-cursor-handler final)))
    (when handler
      (funcall handler
               screen
               (%terminal-screen-parameter parameters 0 1))
      t)))

(defun %terminal-screen-csi-absolute-cursor (screen final parameters)
  (case final
    ((#\G #\`)
     (setf (terminal-screen-cursor-column screen)
           (1- (%terminal-screen-parameter parameters 0 1))))
    ((#\H #\f)
     (setf (terminal-screen-cursor-row screen)
           (1- (%terminal-screen-parameter parameters 0 1))
           (terminal-screen-cursor-column screen)
           (1- (%terminal-screen-parameter parameters 1 1))))
    (#\d
     (setf (terminal-screen-cursor-row screen)
           (1- (%terminal-screen-parameter parameters 0 1))))
    (otherwise (return-from %terminal-screen-csi-absolute-cursor)))
  t)

(defun %terminal-screen-csi-cursor (screen final parameters)
  (or (%terminal-screen-csi-relative-cursor screen final parameters)
      (%terminal-screen-csi-absolute-cursor screen final parameters))
  screen)

(defun %terminal-screen-csi-private-mode (screen final parameters)
  (when (terminal-screen-csi-private screen)
    (dolist (parameter parameters)
      (case parameter
        ((47 1047 1049)
         (if (char= final #\h)
             (%terminal-screen-enter-alternate screen)
             (%terminal-screen-leave-alternate screen))))))
  screen)
