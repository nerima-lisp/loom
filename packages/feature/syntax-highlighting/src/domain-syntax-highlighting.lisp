
(in-package #:loom/feature/syntax-highlighting)

(defstruct (syntax-token
            (:constructor %make-syntax-token (kind text))
            (:copier nil))
  "A semantic token from a single source line."
  kind
  text)

(defun %syntax-whitespace-p (character)
  (member character '(#\Space #\Tab #\Page #\Return #\Newline) :test #'char=))

(defun %syntax-whitespace-end (line start)
  (let ((position start))
    (loop while (and (< position (length line))
                     (%syntax-whitespace-p (char line position)))
          do (incf position))
    position))

(defun %syntax-string-end (line start)
  (let ((escaped nil))
    (loop for position from (1+ start) below (length line)
          for character = (char line position)
          do (cond (escaped
                    (setf escaped nil))
                   ((char= character #\\)
                    (setf escaped t))
                   ((char= character #\")
                    (return (1+ position))))
          finally (return (length line)))))

(defun %syntax-number-start-position (text)
  (if (and (> (length text) 1)
           (find (char text 0) '(#\+ #\-) :test #'char=))
      1
      0))

(defun %syntax-number-body-p (text start)
  (let ((position start)
        (digits 0)
        (dot-seen nil))
    (loop while (< position (length text))
          for character = (char text position)
          do (cond ((find character "0123456789" :test #'char=)
                    (incf digits)
                    (incf position))
                   ((and (not dot-seen) (char= character #\.))
                    (setf dot-seen t)
                    (incf position))
                   (t (return))))
    (and (plusp digits)
         (= position (length text)))))

(defun %syntax-number-token-p (text)
  (%syntax-number-body-p text (%syntax-number-start-position text)))
