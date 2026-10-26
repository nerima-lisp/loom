(in-package #:loom)

(defun %cli-control-request-p (arguments &optional (options-ended-p nil))
  (when arguments
    (let ((argument (first arguments)))
      (cond
        ((and (not options-ended-p) (string= argument "--"))
         (%cli-control-request-p (rest arguments) t))
        ((and (not options-ended-p)
              (member argument
                      (list "--dump-catalog" "--help" "-h" "--version" "-V")
                      :test
                      (function string=))) t)
        ((and (not options-ended-p)
              (>= (length argument) 2)
              (string= argument "--" :end1 2)
              (not (position #\= argument))
              (eq (loom/core/editor-session:cli-option-value-kind argument)
                  :value))
         (%cli-control-request-p (cddr arguments) options-ended-p))
        (t (%cli-control-request-p (rest arguments) options-ended-p))))))

(defun %apply-render-session-hooks (session snapshot glyph-layout-function)
  "Apply immutable render-hook operations to SNAPSHOT for direct callers."
  (let* ((operations
           (loop for result in (loom/core/editor-session:run-session-hooks :render
                                                                           session
                                                                           snapshot)
                 append result))
         (tabbed-operations
           (loop for operation in operations
                 append (when (loom/core/editor-session:render-operation-p
                               operation)
                          (let ((text
                                  (loom/core/editor-session:render-operation-text
                                   operation)))
                            (when (and text (find (code-char 9) text))
                              (list
                               (cons
                                text
                                (loom/core/editor-session:render-operation-x
                                 operation)))))))))
    (loom/core/editor-session:apply-render-operations
     snapshot
     operations
     (lambda (text)
       (let ((tabbed-operation (first tabbed-operations)))
         (if (and tabbed-operation
                  (string= text (car tabbed-operation)))
             (progn
               (pop tabbed-operations)
               (funcall
                glyph-layout-function
                (nth-value
                 0
                 (%loom-renderer-expand-tabs
                  text :start-column (cdr tabbed-operation)))))
             (funcall glyph-layout-function text)))))))

(defun %render-root-frame (stream)
  (let* ((editor-state *editor-state*)
         (session (editor-state-session editor-state))
         (renderer (editor-state-renderer editor-state))
         (snapshot
          (%apply-render-session-hooks
           session
           (compose-frame editor-state)
           (function %loom-renderer-frame-glyph-layout)))
         (width
          (loom/core/editor-session:frame-snapshot-width snapshot))
         (height
          (loom/core/editor-session:frame-snapshot-height snapshot))
         (cells
          (let ((cells (make-array (* width height))))
            (dotimes (y height cells)
              (dotimes (x width)
                (setf (aref cells (+ (* y width) x))
                      (multiple-value-list
                       (loom/core/editor-session:frame-snapshot-cell
                        snapshot x y))))))))
    (multiple-value-bind (cursor-x cursor-y cursor-visible-p)
        (loom/core/editor-session:frame-snapshot-cursor snapshot)
      (let ((cursor
             (when cursor-x
               (cl-tty-kit:make-cursor :x cursor-x :y cursor-y
                                       :visible cursor-visible-p))))
        (loom-renderer-load-frame-cells renderer width height cells)
        (loom-renderer-present renderer :stream stream :cursor cursor)))))

(defun %main-exit-code (&optional (argv (uiop:raw-command-line-arguments)))
  "Return the CLI exit code for ARGV without terminating the current process."
  (let ((*event-loop-render-function* (function %render-root-frame))
        (arguments (rest argv)))
    (cond
      ((equal arguments (list "--dump-catalog"))
       (write-line (loom/core/command:command-catalog-json))
       0)
      ((%cli-control-request-p arguments)
       (cl-cli:run-app *loom-app* :argv argv))
      (t (handler-case
             (%run-loom (%parse-startup-context arguments)
                        :render-frame-function *event-loop-render-function*)
           (cl-cli:cli-usage-error (condition)
             (format *error-output* "~&~A~%~%"
                     (cl-cli:cli-error-message condition))
             (cl-cli:print-app-help *loom-app* *error-output*)
             64))))))

(defun main ()
  "Dispatch UIOP's raw command-line arguments through the startup CLI boundary."
  (uiop:quit (%main-exit-code)))
