(in-package #:loom/feature/terminal)

(defun %terminal-screen-csi-cursor (screen final parameters)
  (let ((first (%terminal-screen-parameter parameters 0 1)))
    (case final
      (#\A
       (decf (terminal-screen-cursor-row screen)
             (%terminal-screen-parameter parameters 0 1)))
      (#\B
       (incf (terminal-screen-cursor-row screen)
             (%terminal-screen-parameter parameters 0 1)))
      (#\C
       (incf (terminal-screen-cursor-column screen)
             (%terminal-screen-parameter parameters 0 1)))
      (#\D
       (decf (terminal-screen-cursor-column screen)
             (%terminal-screen-parameter parameters 0 1)))
      (#\E
       (incf (terminal-screen-cursor-row screen)
             (%terminal-screen-parameter parameters 0 1))
       (setf (terminal-screen-cursor-column screen) 0))
      (#\F
       (decf (terminal-screen-cursor-row screen)
             (%terminal-screen-parameter parameters 0 1))
       (setf (terminal-screen-cursor-column screen) 0))
      ((#\G #\`)
       (setf (terminal-screen-cursor-column screen) (1- first)))
      ((#\H #\f)
       (setf (terminal-screen-cursor-row screen)
             (1- (%terminal-screen-parameter parameters 0 1))
             (terminal-screen-cursor-column screen)
             (1- (%terminal-screen-parameter parameters 1 1))))
      (#\d
       (setf (terminal-screen-cursor-row screen)
             (1- (%terminal-screen-parameter parameters 0 1))))
      (#\a
       (incf (terminal-screen-cursor-column screen)
             (%terminal-screen-parameter parameters 0 1)))
      (#\e
       (incf (terminal-screen-cursor-row screen)
             (%terminal-screen-parameter parameters 0 1)))
      (otherwise nil)))
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
