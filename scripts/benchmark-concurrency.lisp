;;;; Compare synchronous and cl-concurrent-kit-backed directory listing.
;;;;
;;;; Usage: nix develop -c sbcl --script scripts/benchmark-concurrency.lisp

(require :asdf)

(let* ((root (truename #P"./"))
       (parent (uiop:pathname-parent-directory-pathname root)))
  (asdf:initialize-source-registry
   `(:source-registry
     (:directory ,root)
     (:tree ,parent)
     :inherit-configuration)))

(asdf:load-system "loom")

(defun %benchmark-milliseconds (start end)
  (* 1000.0
     (/ (- end start)
        internal-time-units-per-second)))

(let* ((paths (loop for index from 0 below 8
                    collect (format nil "/loom-benchmark/~2,'0D/" index)))
       (directory-lister
         (lambda (path)
           ;; Model the latency that makes independent directory reads worth
           ;; scheduling without depending on a particular filesystem.
           (sleep 0.01)
           (list (cons (format nil "~Afile" path) :file))))
       (sync-start (get-internal-real-time))
       (sync-results (mapcar directory-lister paths))
       (sync-ms (%benchmark-milliseconds
                 sync-start
                 (get-internal-real-time)))
       (runtime (loom:make-loom-concurrent-runtime
                 :directory-lister directory-lister
                 :parallelism 4
                 :queue-capacity 8))
       (async-submit-ms 0.0)
       (async-total-ms 0.0)
       (accepted 0))
  (declare (ignore sync-results))
  (unwind-protect
       (let ((async-start (get-internal-real-time)))
         (multiple-value-bind (promises accepted-count)
             (let ((submit-start (get-internal-real-time)))
               (multiple-value-bind (submitted count)
                   (loom:loom-concurrent-runtime-prefetch runtime paths)
                 (setf async-submit-ms
                       (%benchmark-milliseconds
                        submit-start
                        (get-internal-real-time)))
                 (values submitted count)))
           (setf accepted accepted-count)
           (dolist (promise promises)
             (cl-concurrent-kit:await
              promise
              :timeout (cl-date-kit:duration-of-seconds 5)))
           (loom:loom-concurrent-runtime-drain runtime)
           (setf async-total-ms
                 (%benchmark-milliseconds
                  async-start
                  (get-internal-real-time))))
         (format t
                 "~&paths=~D~%sync-ms=~,2F~%async-submit-ms=~,2F~%async-total-ms=~,2F~%accepted=~D~%speedup=~,2Fx~%"
                 (length paths)
                 sync-ms
                 async-submit-ms
                 async-total-ms
                 accepted
                 (if (plusp async-total-ms)
                     (/ sync-ms async-total-ms)
                     0.0)))
    (loom:loom-concurrent-runtime-shutdown runtime)))
