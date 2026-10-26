(in-package #:loom/feature/evaluation)

(defparameter *evaluation-buffer-name*
  "*Loom-Eval*")

(defun %evaluation-buffer ()
  (or
   (find *evaluation-buffer-name*
         (registered-buffers *editor-session*)
         :key
         #'buffer-name
         :test
         #'string=)
   (register-buffer *editor-session*
                    (make-buffer :name *evaluation-buffer-name*))))

(defun %move-buffer-point-to-end (buffer)
  (let ((line (1- (buffer-line-count buffer))))
    (buffer-set-point buffer line (length (buffer-line buffer line)))))

(defun %evaluation-status-message (result)
  (if (evaluation-result-success-p result)
      (let ((count (evaluation-result-form-count result)))
        (format nil
                "Evaluated ~D ~A"
                count
                (if (= count 1)
                    "form"
                    "forms")))
      (format nil
              "Evaluation error: ~A"
              (evaluation-result-error-message result))))

(defun %evaluation-entry (source result buffer)
  (format nil
          "~Aloom-eval> ~A~%~A~%"
          (if (string= (buffer-text buffer) "")
              ""
              (format nil "~%"))
          source
          (evaluation-result-text result)))

(defun %display-evaluation-result (buffer result)
  (buffer-mark-saved buffer)
  (loom/core/window-tree:window-set-buffer
   (loom/core/window-tree:window-tree-selected-window
    (editor-state-window-tree *editor-state*))
   buffer)
  (let ((minibuffer (editor-state-minibuffer *editor-state*)))
    (when minibuffer
      (minibuffer-message minibuffer (%evaluation-status-message result)))))

(defun %append-evaluation-result (source result)
  (let ((buffer (%evaluation-buffer)))
    (%move-buffer-point-to-end buffer)
    (buffer-insert-string buffer (%evaluation-entry source result buffer))
    (%display-evaluation-result buffer result)
    result))

(defun %evaluate-and-display (source &key last-expression-only)
  (multiple-value-bind (result evaluation-source)
      (evaluate-lisp-source source :last-expression-only last-expression-only)
    (when evaluation-source
      (%append-evaluation-result evaluation-source result))))

(defun eval-expression ()
  "Prompt for Lisp forms and evaluate them in LOOM-USER."
  (with-prompts
   (minibuffer (editor-state-minibuffer *editor-state*)
               :on-cancel
               (lambda ()
                 nil))
   ((source "Eval: "))
   (if (string/= (string-trim '(#\Space #\Tab #\Newline #\Return) source) "")
       (%evaluate-and-display source)
       (minibuffer-message minibuffer "Evaluation source cannot be empty"))))

(defun eval-buffer ()
  "Evaluate the selected buffer's complete contents in LOOM-USER."
  (%evaluate-and-display
   (buffer-text
    (loom/core/window-tree:window-buffer
     (loom/core/window-tree:window-tree-selected-window
      (editor-state-window-tree *editor-state*))))))

(defun eval-last-sexp ()
  "Evaluate the last Lisp expression before point in the LOOM-USER package."
  (let* ((buffer
           (loom/core/window-tree:window-buffer
            (loom/core/window-tree:window-tree-selected-window
             (editor-state-window-tree *editor-state*))))
         (source (subseq (buffer-text buffer) 0 (buffer-point-offset buffer)))
         (minibuffer (editor-state-minibuffer *editor-state*)))
    (unless (%evaluate-and-display source :last-expression-only t)
      (when minibuffer
        (minibuffer-message minibuffer "No Lisp expression before point")))))
