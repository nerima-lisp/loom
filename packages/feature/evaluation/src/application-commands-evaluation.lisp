(in-package #:loom/feature/evaluation)

(defparameter *evaluation-buffer-name* "*Loom-Eval*")

(defun %evaluation-buffer ()
  (or (find *evaluation-buffer-name*
            (%editor-buffers)
            :key #'buffer-name
            :test #'string=)
      (%register-buffer (make-buffer :name *evaluation-buffer-name*))))

(defun %move-buffer-point-to-end (buffer)
  (let ((line (1- (buffer-line-count buffer))))
    (buffer-set-point buffer line (length (buffer-line buffer line)))))

(defun %evaluation-status-message (result)
  (if (evaluation-result-success-p result)
      (let ((count (evaluation-result-form-count result)))
        (format nil
                "Evaluated ~D ~A"
                count
                (if (= count 1) "form" "forms")))
      (format nil "Evaluation error: ~A"
              (evaluation-result-error-message result))))

(defun %append-evaluation-result (source result)
  (let* ((buffer (%evaluation-buffer))
         (prefix (if (zerop (length (buffer-text buffer))) "" (format nil "~%"))))
    (%move-buffer-point-to-end buffer)
    (buffer-insert-string
     buffer
     (format nil
             "~Aloom-eval> ~A~%~A~%"
             prefix
             source
             (evaluation-result-text result)))
    (buffer-mark-saved buffer)
    (loom/feature/window:window-set-buffer (%selected-window) buffer)
    (let ((minibuffer (editor-state-minibuffer *editor-state*)))
      (when minibuffer
        (minibuffer-message minibuffer (%evaluation-status-message result))))
    result))

(defun %evaluate-and-display (source)
  (%append-evaluation-result source (evaluate-lisp-source source)))

(defun eval-expression ()
  "Prompt for Lisp forms and evaluate them in LOOM-USER."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                :on-cancel (lambda () nil))
      ((source "Eval: "))
    (if (plusp (length (string-trim '(#\Space #\Tab #\Newline #\Return)
                                    source)))
        (%evaluate-and-display source)
        (minibuffer-message minibuffer "Evaluation source cannot be empty"))))

(defun eval-buffer ()
  "Evaluate the selected buffer's complete contents in LOOM-USER."
  (%evaluate-and-display (buffer-text (%selected-buffer))))
