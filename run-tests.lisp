
(require :asdf)

(defconstant +test-timeout-seconds+ 1200)

(defvar *run-tests-slice-system-names* nil)

(defun %run-tests-discover-slice-systems (packages-directory)
  (labels ((collect-asd-files (directory)
             (append (remove-if-not
                      (lambda (pathname)
                        (string-equal (pathname-type pathname) "asd"))
                      (uiop:directory-files directory))
                     (mapcan #'collect-asd-files
                             (uiop:subdirectories directory))))
           (asd-directory (asd-file)
             (make-pathname :name nil
                            :type nil
                            :version nil
                            :defaults asd-file))
           (slice-asd-file-p (asd-file)
             (let ((name (pathname-name asd-file)))
               (and (>= (length name) 5)
                    (string= "loom-" name :end2 5)))))
    (let* ((asd-files (sort (collect-asd-files packages-directory)
                            #'string< :key #'namestring))
           (system-names (mapcar #'pathname-name asd-files))
           (slice-directories
             (mapcar #'pathname
                     (remove-duplicates
                      (mapcar (lambda (asd-file)
                                (namestring (asd-directory asd-file)))
                              asd-files)
                      :test #'string=
                      :from-end t)))
           (unique-system-names
             (remove-duplicates system-names :test #'string=))
           (invalid-asd-file (find-if-not #'slice-asd-file-p asd-files)))
      (unless asd-files
        (error "No slice ASDF systems found under ~A." packages-directory))
      (when invalid-asd-file
        (error "Invalid slice ASDF file ~A; expected a loom-*.asd filename."
               (file-namestring invalid-asd-file)))
      (unless (= (length system-names) (length unique-system-names))
        (error "Duplicate slice ASDF system names found under ~A."
               packages-directory))
      (values system-names slice-directories))))

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
       (packages-directory (merge-pathnames #P"packages/" root))
       (slice-directories nil)
       (sibling-names '("cl-tty-kit"
                        "cl-host-kit"
                        "cl-history-kit"
                        "cl-prolog-kit"
                        "cl-cli"
                        "cl-regex-kit"
                        "cl-boundary-kit"
                        "cl-concurrent-kit"
                        "cl-json-kit"
                        "cl-log-kit"
                        "cl-process-kit"
                        "cl-vcs-kit"
                        "cl-resilience-kit"
                        "cl-weave"
                        "cl-date-kit"
                        "cl-codec-kit"
                        "cl-parser-kit"
                        "cl-markdown-kit"
                        "cl-org-kit"))
       (sibling-directories
         (mapcar (lambda (name)
                   (merge-pathnames
                    (format nil "~A/" name)
                    parent))
                 sibling-names))
       (source-registry (sb-ext:posix-getenv "CL_SOURCE_REGISTRY")))
  (multiple-value-setq (*run-tests-slice-system-names* slice-directories)
    (%run-tests-discover-slice-systems packages-directory))
  (asdf:initialize-source-registry
   `(:source-registry
     (:directory ,root)
     ,@(mapcar (lambda (directory)
                 `(:directory ,directory))
               slice-directories)
     ,@(unless (and source-registry (plusp (length source-registry)))
         (mapcar (lambda (directory)
                   `(:directory ,directory))
                 sibling-directories))
     :inherit-configuration)))

(let ((passed-p
        (handler-case
            (sb-ext:with-timeout +test-timeout-seconds+
                (asdf:load-system "cl-host-kit")
                (setf asdf:*compile-file-warnings-behaviour* :warn
                      asdf:*compile-file-failure-behaviour* :error)
                (asdf:load-system "loom" :force t)
                (asdf:load-system "loom/test" :force t)
                (dolist (system-name *run-tests-slice-system-names*)
                  (asdf:load-system (format nil "~A/test" system-name)))
                (funcall (symbol-function (find-symbol "RUN-TESTS" :loom/test))))
          (sb-ext:timeout ()
            (format *error-output* "~&loom/test: timed out after ~Ds~%"
                    +test-timeout-seconds+)
            nil))))
  (sb-ext:exit :code (if passed-p 0 1)))
