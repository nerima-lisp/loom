
(require :asdf)

(let* ((script (or *load-truename*
                   (error "*LOAD-TRUENAME* is NIL; run this file as a script")))
       (script-path (truename script))
       (root (make-pathname :name nil
                            :type nil
                            :version nil
                            :defaults script-path))
       (directory (pathname-directory root))
       (parent (make-pathname
                :directory (if (rest directory) (butlast directory) directory)
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

(let ((passed-p
        (handler-case
            (sb-ext:with-timeout 600
                (asdf:load-system "cl-host-kit")
                (setf asdf:*compile-file-warnings-behaviour* :warn
                      asdf:*compile-file-failure-behaviour* :error)
                (asdf:load-system "loom" :force t)
                (asdf:load-system "loom/test" :force t)
                (funcall (symbol-function (find-symbol "RUN-TESTS" :loom/test))))
          (sb-ext:timeout ()
            (format *error-output* "~&loom/test: timed out after 600s~%")
            nil))))
  (sb-ext:exit :code (if passed-p 0 1)))
