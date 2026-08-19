;;;; Compare synchronous and cl-concurrent-kit-backed directory listing.
;;;; Usage: nix develop -c sbcl --script scripts/benchmark-concurrency.lisp

(require :asdf)

(let* ((script (or *load-truename*
                   (error "*LOAD-TRUENAME* is NIL; run this file as a script")))
       (script-path (truename script))
       (script-directory (make-pathname :name nil
                                        :type nil
                                        :version nil
                                        :defaults script-path))
       (directory (pathname-directory script-directory))
       (root (make-pathname
              :directory (if (rest directory) (butlast directory) directory)
              :name nil
              :type nil
              :version nil
              :defaults script-directory))
       (root-directory (pathname-directory root))
       (parent (make-pathname
                :directory (if (rest root-directory)
                               (butlast root-directory)
                               root-directory)
                :name nil
                :type nil
                :version nil
                :defaults root))
       (sibling-names '("cl-tty-kit"
                        "cl-host-kit"
                        "cl-history-kit"
                        "cl-prolog-kit"
                        "cl-cli"
                        "cl-regex-kit"
                        "cl-boundary-kit"
                        "cl-concurrent-kit"
                        "cl-weave"
                        "cl-date-kit"
                        "cl-codec-kit"
                        "cl-parser-kit"))
       (sibling-directories
         (mapcar (lambda (name)
                   (merge-pathnames
                    (format nil "~A/" name)
                    parent))
                 sibling-names))
       (source-registry (sb-ext:posix-getenv "CL_SOURCE_REGISTRY")))
  (asdf:initialize-source-registry
   `(:source-registry
     (:directory ,root)
     ,@(unless (and source-registry (plusp (length source-registry)))
         (mapcar (lambda (directory)
                   `(:directory ,directory))
                 sibling-directories))
     :inherit-configuration)))

(asdf:load-system "cl-host-kit")

(setf asdf:*compile-file-warnings-behaviour* :warn
      asdf:*compile-file-failure-behaviour* :error)

(asdf:load-system "loom")

(defun %benchmark-milliseconds (start end)
  (* 1000.0
     (/ (- end start)
        internal-time-units-per-second)))

(let* ((paths (loop for index from 0 below 8
                    collect (format nil "/loom-benchmark/~2,'0D/" index)))
       (directory-lister
         (lambda (path)
          ;; Model the latency that makes independent directory reads worth scheduling.
          (sleep 0.01)
          (list (cons (format nil "~Afile" path) :file))))
       (sync-start (get-internal-real-time))
       (sync-results (mapcar directory-lister paths))
      (sync-ms (%benchmark-milliseconds sync-start (get-internal-real-time)))
       (runtime (loom:make-loom-concurrent-runtime
                 :directory-lister directory-lister
                 :parallelism 4
                 :queue-capacity 8))
       (async-submit-ms 0.0)
       (async-total-ms 0.0)
       (async-results nil)
       (accepted 0))
  (unwind-protect
       (let ((async-start (get-internal-real-time)))
         (multiple-value-bind (promises accepted-count)
             (let ((submit-start (get-internal-real-time)))
               (multiple-value-bind (submitted count)
                   (loom:loom-concurrent-runtime-prefetch runtime paths)
                (setf async-submit-ms
                      (%benchmark-milliseconds submit-start (get-internal-real-time)))
                (values submitted count)))
           (setf accepted accepted-count)
           (dolist (promise promises)
             (cl-concurrent-kit:await
              promise
              :timeout (cl-date-kit:duration-of-seconds 5)))
           (loom:loom-concurrent-runtime-drain runtime)
            (setf async-results
                  (mapcar (lambda (path)
                            (loom:loom-concurrent-runtime-directory-entries runtime path))
                          paths))
            (unless (equal sync-results async-results)
              (error "Synchronous and asynchronous results differ: sync=~S async=~S" sync-results async-results))
            (setf async-total-ms (%benchmark-milliseconds async-start (get-internal-real-time))))
        (format t "~&paths=~D~%sync-ms=~,2F~%async-submit-ms=~,2F~%async-total-ms=~,2F~%accepted=~D~%speedup=~,2Fx~%"
                (length paths) sync-ms async-submit-ms async-total-ms accepted
                (if (plusp async-total-ms) (/ sync-ms async-total-ms) 0.0)))
    (loom:loom-concurrent-runtime-shutdown runtime)))
