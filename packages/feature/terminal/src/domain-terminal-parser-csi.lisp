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

(defun %terminal-screen-csi (screen final)
  (let ((parameters (%terminal-screen-parse-parameters
                     (terminal-screen-csi-parameters screen))))
    (case final
      ((#\A #\B #\C #\D #\E #\F #\G #\` #\H #\f #\d #\a #\e)
       (%terminal-screen-csi-cursor screen final parameters))
      ((#\h #\l)
       (%terminal-screen-csi-private-mode screen final parameters))
      (t
       (%terminal-screen-csi-edit screen final parameters))))
  (%terminal-screen-clamp-cursor screen)
  (setf (terminal-screen-wrap-pending screen) nil)
  screen)
