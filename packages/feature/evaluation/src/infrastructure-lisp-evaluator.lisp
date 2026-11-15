(in-package #:loom/feature/evaluation)

(defvar *evaluation-package-provider* nil)
(defun register-evaluation-package-provider (owner function)
  "Register OWNER's provider for the Lisp package used during evaluation.

FUNCTION is called without arguments and must return a package. Registering
again as OWNER replaces its provider; a different owner is rejected."
  (unless (functionp function)
    (error "Evaluation package provider must be a function"))
  (when (and *evaluation-package-provider*
             (not (equal (car *evaluation-package-provider*) owner)))
    (error "Evaluation package provider is already registered by ~S"
           (car *evaluation-package-provider*)))
  (setf *evaluation-package-provider* (cons owner function))
  function)
(defun %loom-evaluation-package ()
  (unless *evaluation-package-provider*
    (error "Evaluation package provider is not registered"))
  (let ((package (funcall (cdr *evaluation-package-provider*))))
    (unless (packagep package)
      (error "Evaluation package provider returned ~S, not a package"
             package))
    package))

(defun %evaluation-values-line (values)
  (if values (with-output-to-string (stream)
        (loop with first-p = t
              for value in values
              do (unless first-p
                   (write-string ", " stream))
                 (setf first-p nil)
                 (write value :stream stream :escape t))) "<no values>"))

(defun %evaluate-form (form)
  (%evaluation-values-line (multiple-value-list (eval form))))

(defun %evaluate-forms (source eof)
  (let ((form-count 0)
        (value-lines nil)
        (error-message nil))
    (handler-case
        (let ((*read-eval* nil))
          (with-input-from-string (input source)
            (loop for form = (read input nil eof)
                  until (eq form eof)
                  do (incf form-count)
                     (push (%evaluate-form form) value-lines))))
      (error (condition)
        (setf error-message (princ-to-string condition))))
    (values form-count (nreverse value-lines) error-message)))

(defun %evaluate-lisp-forms (source output-stream package)
  "Return the number of forms read, formatted value lines, and NIL or error text."
  (let ((form-count 0)
        (value-lines nil)
        (error-message nil))
    (handler-case
        (let ((*package* package)
              (*read-eval* nil)
              (*standard-output* output-stream)
              (eof (gensym "EOF")))
          (multiple-value-setq (form-count value-lines error-message)
            (%evaluate-forms source eof)))
      (error (condition)
        (setf error-message (princ-to-string condition))))
    (values form-count value-lines error-message)))

(defun %call-without-interruption (thunk &key on-interrupt)
  (declare (ignore on-interrupt))
  (values :completed (multiple-value-list (funcall thunk))))

(defun %evaluate-interruptibly (call-with-interruption source output-stream package
                                on-interrupt)
  "Return form count, value lines, error text, and whether evaluation was interrupted."
  (multiple-value-bind (status forms-values)
      (funcall call-with-interruption
               (lambda ()
                 (%evaluate-lisp-forms source output-stream package))
               :on-interrupt on-interrupt)
    (ecase status
      (:completed (values-list (append forms-values (list nil))))
      (:interrupted (values 0 nil nil t)))))

(defun evaluate-lisp-source (source &key last-expression-only
                                         (call-with-interruption
                                          (function %call-without-interruption)))
  "Read and evaluate SOURCE forms in LOOM-USER until EOF or the first error.

When LAST-EXPRESSION-ONLY is true, evaluate the last complete form before EOF.
If reading fails, evaluate the unread tail to report the reader error. Return
the evaluation result and selected source as a second value.

CALL-WITH-INTERRUPTION receives the evaluation thunk and an :ON-INTERRUPT
function, and returns :COMPLETED with the thunk's values as a list, or
:INTERRUPTED. It is called outside the evaluator's error handlers, so an
interruption is not reported as an error. An interrupted result keeps the
standard output and the error output written before the interruption was
delivered; error output written while the interruption unwinds, such as SBCL's
report of a compilation it cut short, is dropped.

Reader evaluation syntax such as #. is disabled, while the evaluated forms
otherwise run with the same trusted access as user initialization code."
  (check-type source string)
  (labels ((last-expression-source (text package)
             (let* ((eof (gensym "EOF"))
                    (position 0)
                    (last-start nil)
                    (last-end nil))
               (let ((*package* package)
                     (*read-eval* nil))
                 (loop
                   (handler-case
                       (multiple-value-bind (form next-position)
                           (read-from-string text nil eof :start position)
                         (if (eq form eof)
                             (return
                               (when last-start
                                 (string-left-trim
                                  (list #\Space #\Tab #\Newline #\Return)
                                  (subseq text last-start last-end))))
                             (setf last-start position
                                   last-end next-position
                                   position next-position)))
                     (error ()
                       (return
                         (string-left-trim
                          (list #\Space #\Tab #\Newline #\Return)
                          (subseq text position))))))))))
    (let* ((package (%loom-evaluation-package))
           (evaluation-source
             (if last-expression-only
                 (last-expression-source source package)
                 source))
           (input-source (or evaluation-source ""))
           (output-stream (make-string-output-stream))
           (error-stream (make-string-output-stream))
           (error-length-at-interrupt nil))
      (multiple-value-bind (form-count value-lines error-message interrupted-p)
          (let ((*error-output* error-stream))
            (%evaluate-interruptibly
             call-with-interruption
             input-source
             output-stream
             package
             ;; Runs on this thread when the first interruption is delivered,
             ;; before its unwind runs any cleanup that can write here.
             ;; Error output the evaluated code writes between this marker and
             ;; the kit's transfer is also cut; that gap stays open because no
             ;; UI shows Error output and closing it would need kit changes.
             (lambda ()
               (unless error-length-at-interrupt
                 (setf error-length-at-interrupt
                       (file-position error-stream))))))
        (values
         (make-evaluation-result
          :form-count form-count
          :value-lines value-lines
          :output (get-output-stream-string output-stream)
          :error-output (let ((text (get-output-stream-string error-stream)))
                          (if (and interrupted-p error-length-at-interrupt)
                              (subseq text 0 (min error-length-at-interrupt
                                                  (length text)))
                              text))
          :error-message error-message
          :interrupted-p interrupted-p)
         evaluation-source)))))
