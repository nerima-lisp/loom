(in-package #:loom/feature/evaluation)

(defun %evaluation-status-message (result)
  (if (evaluation-result-success-p result)
      (let* ((values (evaluation-result-value-lines result))
             (value (car (last values)))
             (number (and value (ignore-errors (parse-integer value)))))
        (cond
          ((null value) "")
          ((and number
                (<= 1 number 26)
                (string= value (format nil "~D" number)))
           (format nil
                   "~D (#o~O, #x~X, ?\\C-~C)"
                   number
                   number
                   number
                   (code-char (+ number 96))))
          ((string= value "NIL") "nil")
          (t value)))
      (evaluation-result-error-message result)))

(defun %evaluate-and-display (source &key last-expression-only insert-value-p silent-success-p)
  (multiple-value-bind (result evaluation-source)
      (evaluate-lisp-source source :last-expression-only last-expression-only)
    (when evaluation-source
      (let ((minibuffer (editor-state-minibuffer *editor-state*)))
        (if (evaluation-result-success-p result)
            (let* ((values (evaluation-result-value-lines result))
                   (value (car (last values))))
              (if insert-value-p
                  (when value
                    (buffer-insert-string
                     (loom/core/window-tree:window-buffer
                      (loom/core/window-tree:window-tree-selected-window
                       (editor-state-window-tree *editor-state*)))
                     value))
                  (when (and minibuffer (not silent-success-p))
                    (minibuffer-message
                     minibuffer
                     (%evaluation-status-message result))))
              result)
            (progn
              (when minibuffer
                (minibuffer-message
                 minibuffer
                 (%evaluation-status-message result)))
              result))))))

(defun eval-expression ()
  "Prompt for Lisp forms and evaluate them in LOOM-USER."
  (let* ((minibuffer (editor-state-minibuffer *editor-state*))
         (prefix (loom/core/command:prefix-argument-for-editor))
         (insert-value-p
           (loom/core/command:prefix-argument-active-p prefix)))
    (when insert-value-p
      (loom/core/command:consume-prefix-argument-for-editor))
    (labels ((prompt ()
               (loom/core/minibuffer:minibuffer-activate
                minibuffer
                "Eval: "
                :on-confirm
                (lambda (source)
                  (if (string=
                       (string-trim
                        (list #\Space #\Tab #\Newline #\Return)
                        source)
                       "")
                      (progn
                        (let ((reader-error "[End of file during parsing]"))
                          (prompt)
                          (loom/core/minibuffer:minibuffer-set-prompt
                           minibuffer
                           (format nil "Eval: ~A" reader-error))
                          (minibuffer-message minibuffer reader-error)))
                      (%evaluate-and-display
                       source
                       :insert-value-p insert-value-p)))
                :on-cancel
                (lambda ()
                  (minibuffer-message minibuffer "Quit")))))
      (prompt))))

(defun eval-buffer ()
  "Evaluate the complete contents of the selected buffer in LOOM-USER."
  (let* ((window
           (loom/core/window-tree:window-tree-selected-window
            (editor-state-window-tree *editor-state*)))
         (buffer (loom/core/window-tree:window-buffer window))
         (minibuffer (editor-state-minibuffer *editor-state*))
         (prefix (loom/core/command:prefix-argument-for-editor)))
    (when (loom/core/command:prefix-argument-active-p prefix)
      (loom/core/command:consume-prefix-argument-for-editor)
      (when minibuffer
        (minibuffer-message minibuffer nil)))
    (%evaluate-and-display (buffer-text buffer) :silent-success-p t)))

(defun eval-last-sexp ()
  "Evaluate the last Lisp expression before point in the LOOM-USER package."
  (let* ((window
           (loom/core/window-tree:window-tree-selected-window
            (editor-state-window-tree *editor-state*)))
         (buffer (loom/core/window-tree:window-buffer window))
         (source (subseq (buffer-text buffer) 0 (buffer-point-offset buffer)))
         (minibuffer (editor-state-minibuffer *editor-state*))
         (prefix (loom/core/command:prefix-argument-for-editor))
         (insert-value-p
           (loom/core/command:prefix-argument-active-p prefix)))
    (when insert-value-p
      (loom/core/command:consume-prefix-argument-for-editor)
      (when minibuffer
        (minibuffer-message minibuffer nil)))
    (unless
        (%evaluate-and-display
         source
         :last-expression-only t
         :insert-value-p insert-value-p)
      (when minibuffer
        (minibuffer-message minibuffer "No Lisp expression before point")))))
