(in-package #:loom/test)

(defvar *concurrent-probe-ready* nil)
(defvar *concurrent-probe-cleaned* nil)

(describe
  "cl-concurrent-kit interruptible evaluation integration"
  (it "evaluates the public scope API and preserves multiple values"
    (let ((result
            (loom/feature/evaluation:evaluate-lisp-source
             "(cl-concurrent-kit:with-interruptible-scope (scope)
                (declare (ignore scope))
                (values 21 2))")))
      (expect (loom/feature/evaluation:evaluation-result-success-p result)
              :to-be-truthy)
      (expect (loom/feature/evaluation:evaluation-result-value-lines result)
              :to-equal '("21, 2"))))

  (it "escapes the evaluator error handlers and runs evaluated cleanup"
    (let ((*concurrent-probe-ready* (sb-thread:make-semaphore :count 0))
          (*concurrent-probe-cleaned* nil)
          (requester nil)
          (interrupted nil)
          (active-scope nil))
      (unwind-protect
           (handler-case
               (cl-concurrent-kit:with-interruptible-scope (scope)
                 (setf active-scope scope
                       requester
                       (let ((ready *concurrent-probe-ready*))
                         (sb-thread:make-thread
                          (lambda ()
                            (unless (sb-thread:wait-on-semaphore ready :timeout 5)
                              (error "Evaluation did not reach the probe barrier"))
                            (cl-concurrent-kit:request-interruption
                             scope :reason :probe-evaluation))
                          :name "loom-concurrent-kit-probe")))
                 (loom/feature/evaluation:evaluate-lisp-source
                  "(unwind-protect
                       (progn
                         (sb-thread:signal-semaphore
                          loom/test::*concurrent-probe-ready*)
                         (loop repeat 100 do (ignore-errors (sleep 0.01))))
                     (setf loom/test::*concurrent-probe-cleaned* t))"))
             (cl-concurrent-kit:operation-interrupted (condition)
               (setf interrupted condition)))
        (when requester
          (sb-thread:join-thread requester)))
      (expect interrupted :to-be-truthy)
      (expect (cl-concurrent-kit:operation-interrupted-scope interrupted)
              :to-be active-scope)
      (expect (cl-concurrent-kit:operation-interrupted-reason interrupted)
              :to-be :probe-evaluation)
      (expect *concurrent-probe-cleaned* :to-be-truthy)))

  (it "ignores an interruption request after its evaluation scope returns"
    (let ((finished-scope nil))
      (cl-concurrent-kit:with-interruptible-scope (scope)
        (setf finished-scope scope)
        (loom/feature/evaluation:evaluate-lisp-source "(+ 20 22)"))
      (expect (cl-concurrent-kit:request-interruption finished-scope :reason :late-probe)
              :to-be nil)
      (let ((result
              (loom/feature/evaluation:evaluate-lisp-source "(+ 20 22)")))
        (expect (loom/feature/evaluation:evaluation-result-success-p result)
                :to-be-truthy)
        (expect (loom/feature/evaluation:evaluation-result-value-lines result)
                :to-equal '("42"))))))
