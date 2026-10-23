(in-package #:loom/core/command)

(defun %command-trace-key-descriptor (descriptor)
  (let* ((normalized (normalize-key-descriptor descriptor))
         (code (cdr normalized)))
    (json-kit:make-json-object
     (list
      (cons "key"
            (typecase code
              (character (string code))
              (keyword (string-downcase (symbol-name code)))
              (t (error "Unsupported command trace key: ~S" code))))
      (cons "modifiers"
            (mapcar (lambda (modifier)
                      (string-downcase (symbol-name modifier)))
                    (car normalized)))))))

(defun %command-trace-key-entry (key-sequence keymap-name)
  (when keymap-name
    (format nil
            "key:~A"
            (json-kit:stringify
             (json-kit:make-json-object
              (list
               (cons "keymap" keymap-name)
               (cons "sequence"
                     (mapcar #'%command-trace-key-descriptor key-sequence))))))))

(defun invoke-command (command route &optional key-sequence keymap-name)
  "Trace COMMAND through ROUTE with optional key-entry data, then execute it."
  (let ((trace-error
          (record-command-trace
           command route (%command-trace-key-entry key-sequence keymap-name)))
        (minibuffer (editor-state-minibuffer *editor-state*)))
    (when (and trace-error minibuffer)
      (minibuffer-message minibuffer trace-error)))
  (funcall command))
