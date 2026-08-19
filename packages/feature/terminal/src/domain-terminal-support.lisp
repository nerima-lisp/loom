(in-package #:loom/feature/terminal)

(defun %terminal-blank-row (width)
  (make-string width :initial-element #\Space))

(defun %terminal-blank-rows (width height)
  (coerce (loop repeat height collect (%terminal-blank-row width))
          'vector))

(defun %terminal-copy-rows (rows width height)
  (let ((result (%terminal-blank-rows width height)))
    (loop for row below (min height (length rows))
          for source = (aref rows row)
          do (replace (aref result row)
                      source
                      :end1 (min width (length source))))
    result))

(defun %terminal-clamp (value minimum maximum)
  (max minimum (min maximum value)))

(defun %terminal-screen-row-content-p (row)
  (position-if-not (lambda (character) (char= character #\Space)) row))

(defun %terminal-ensure-dimension (value name)
  (unless (and (integerp value) (plusp value))
    (error "Terminal ~A must be a positive integer: ~S" name value)))
