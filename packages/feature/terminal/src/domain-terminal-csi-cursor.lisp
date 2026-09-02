(in-package #:loom/feature/terminal)

(defun %terminal-screen-csi-relative-cursor (screen final parameters)
  (let ((amount (%terminal-screen-parameter parameters 0 1)))
    (case final
      (#\A (decf (terminal-screen-cursor-row screen) amount))
      (#\B (incf (terminal-screen-cursor-row screen) amount))
      (#\C (incf (terminal-screen-cursor-column screen) amount))
      (#\D (decf (terminal-screen-cursor-column screen) amount))
      (#\E
       (incf (terminal-screen-cursor-row screen) amount)
       (setf (terminal-screen-cursor-column screen) 0))
      (#\F
       (decf (terminal-screen-cursor-row screen) amount)
       (setf (terminal-screen-cursor-column screen) 0))
      (#\a (incf (terminal-screen-cursor-column screen) amount))
      (#\e (incf (terminal-screen-cursor-row screen) amount))
      (otherwise (return-from %terminal-screen-csi-relative-cursor)))
    t))

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
