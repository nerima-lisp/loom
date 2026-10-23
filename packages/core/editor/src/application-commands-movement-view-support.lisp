(in-package #:loom)

(defun %parse-goto-line-number (input)
  (handler-case
      (let ((line (parse-integer input)))
        (if (plusp line)
            (values line nil)
            (values nil "Line number must be positive")))
    (parse-error ()
      (values nil "Enter a line number"))))

(defun %goto-line-target-line (buffer line)
  (let* ((start (buffer-narrow-start-offset buffer))
         (start-position (buffer-offset-position buffer start)))
    (+ (buffer-position-line start-position) (1- line))))

(defun %goto-line-target (buffer input)
  (multiple-value-bind (line error-message)
      (%parse-goto-line-number input)
    (cond
      (error-message
       (values nil error-message))
      ((> line (buffer-visible-line-count buffer))
       (values nil "Line is outside the narrowed buffer"))
      (t
       (values (%goto-line-target-line buffer line) nil)))))

(defun %goto-visible-line-input (minibuffer input)
  (let ((buffer (%selected-buffer)))
    (multiple-value-bind (target-line error-message)
        (%goto-line-target buffer input)
      (if target-line
          (progn
            (buffer-set-point buffer target-line (buffer-point-column buffer))
            (minibuffer-message minibuffer "Moved"))
          (minibuffer-message minibuffer error-message)))))
