(in-package #:loom/feature/terminal)

(defun %terminal-screen-parameter (parameters index default)
  (let ((value (nth index parameters)))
    (if (and (integerp value) (plusp value)) value default)))

(defun %terminal-screen-parse-parameter (string)
  (unless (string= string "")
    (multiple-value-bind (number end)
        (parse-integer string :junk-allowed t)
      (when (and number (= end (length string)))
        number))))

(defun %terminal-screen-parse-parameters (string)
  (unless (string= string "") (loop with start = 0
            with parameters = nil
            for separator = (position #\; string :start start)
            for end = (or separator (length string))
            do (push (%terminal-screen-parse-parameter
                      (subseq string start end))
                     parameters)
               (if separator
                   (setf start (1+ separator))
                   (return (nreverse parameters))))))

(defparameter +terminal-screen-csi-handlers+
  '((#\A . %terminal-screen-csi-cursor)
    (#\B . %terminal-screen-csi-cursor)
    (#\C . %terminal-screen-csi-cursor)
    (#\D . %terminal-screen-csi-cursor)
    (#\E . %terminal-screen-csi-cursor)
    (#\F . %terminal-screen-csi-cursor)
    (#\G . %terminal-screen-csi-cursor)
    (#\` . %terminal-screen-csi-cursor)
    (#\H . %terminal-screen-csi-cursor)
    (#\f . %terminal-screen-csi-cursor)
    (#\d . %terminal-screen-csi-cursor)
    (#\a . %terminal-screen-csi-cursor)
    (#\e . %terminal-screen-csi-cursor)
    (#\h . %terminal-screen-csi-private-mode)
    (#\l . %terminal-screen-csi-private-mode)))

(defun %terminal-screen-csi-handler (final)
  (or (cdr (assoc final +terminal-screen-csi-handlers+))
      #'%terminal-screen-csi-edit))

(defun %terminal-screen-csi (screen final)
  (let ((parameters (%terminal-screen-parse-parameters
                     (terminal-screen-csi-parameters screen))))
    (funcall (%terminal-screen-csi-handler final) screen final parameters))
  (%terminal-screen-clamp-cursor screen)
  (setf (terminal-screen-wrap-pending screen) nil)
  screen)
