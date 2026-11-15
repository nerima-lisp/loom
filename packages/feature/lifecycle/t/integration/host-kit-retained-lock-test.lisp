(in-package #:loom/test)

(defun %host-kit-lock-holder-environment (directory)
  ;; The holder reads SBCL and ASDF configuration from HOME and XDG paths;
  ;; point them at the test's temporary directory.
  (let ((overrides '("HOME" "XDG_CONFIG_HOME" "XDG_DATA_HOME" "XDG_CACHE_HOME"))
        (home (sb-ext:native-namestring directory)))
    (append (mapcar (lambda (name) (format nil "~A=~A" name home)) overrides)
            (remove-if (lambda (entry)
                         (some (lambda (name)
                                 (uiop:string-prefix-p
                                  (concatenate 'string name "=") entry))
                               overrides))
                       (sb-ext:posix-environ)))))

(defun %start-host-kit-lock-holder (target ready &key expect-conflict)
  (let ((form
          (format nil
                  "(let ((lock (host-kit:try-acquire-file-lock ~S)))
                     (assert (eq (null lock) ~S))
                     (when lock
                       (format (host-kit:file-lock-stream lock) \"pid ~~D~~%\" (sb-posix:getpid))
                       (finish-output (host-kit:file-lock-stream lock)))
                     (host-kit:write-file-string \"ready\" ~S :mode #o600)
                     (read-line *standard-input* nil nil))"
                  (namestring target)
                  expect-conflict
                  (namestring ready))))
    (sb-ext:run-program
     (namestring sb-ext:*runtime-pathname*)
     (list "--noinform" "--non-interactive" "--no-sysinit" "--no-userinit"
           "--eval" "(require :asdf)"
           "--eval" (format nil
                            "(asdf:initialize-output-translations '(:output-translations (t ~S) :ignore-inherited-configuration))"
                            (namestring
                             (merge-pathnames
                              "fasl/" (make-pathname :name nil :type nil :defaults ready))))
           "--eval" (format nil "(asdf:load-asd ~S)"
                            (namestring (asdf:system-source-file "cl-host-kit")))
           "--eval" "(asdf:load-system \"cl-host-kit\")"
           "--eval" form)
     :wait nil :input :stream :output nil :error *error-output*
     :environment (%host-kit-lock-holder-environment
                   (make-pathname :name nil :type nil :defaults ready)))))

(defun %wait-for-host-kit-lock-holder (process ready)
  (let ((deadline (+ (get-internal-real-time)
                     (* 10 internal-time-units-per-second))))
    (loop
      (when (probe-file ready)
        (return))
      (unless (sb-ext:process-alive-p process)
        (error "Host-kit lock holder exited before acquiring its lock."))
      (when (>= (get-internal-real-time) deadline)
        (error "Host-kit lock holder did not become ready."))
      (sleep 0.01d0))))

(describe "host-kit retained locks and atomic writes"
  (it "detects a live foreign holder and acquires after that process exits"
    (cl-weave:expect-assertions 9)
    (host-kit:with-temporary-directory (directory)
      (let* ((target (merge-pathnames (sb-ext:parse-native-namestring "b*c.lock") directory))
             (ready (merge-pathnames "ready" directory))
             (process (%start-host-kit-lock-holder target ready)))
        (unwind-protect
             (progn
               (%wait-for-host-kit-lock-holder process ready)
               (expect (host-kit:file-lock-held-by-other-process-p target) :to-be t)
               (expect (host-kit:try-acquire-file-lock target) :to-be nil)
               (expect (host-kit:file-metadata-mode (host-kit:file-metadata target))
                       :to-equal #o600)
               (write-line "exit" (sb-ext:process-input process))
               (finish-output (sb-ext:process-input process))
               (sb-ext:process-wait process)
               (expect (sb-ext:process-exit-code process) :to-equal 0)
               (expect (host-kit:file-lock-held-by-other-process-p target) :to-be nil)
               (let ((lock (host-kit:try-acquire-file-lock target)))
                 (unwind-protect
                      (progn
                        (expect (typep lock 'host-kit:file-lock) :to-be t)
                        (expect (host-kit:file-lock-held-by-other-process-p target)
                                :to-be nil))
                   (when lock
                     (expect (host-kit:release-file-lock lock) :to-be t)
                     (expect (host-kit:release-file-lock lock) :to-be nil)))))
          (when (sb-ext:process-alive-p process)
            (sb-ext:process-kill process 15))
          (sb-ext:process-wait process)
          (close (sb-ext:process-input process))))))

  (it "writes private recovery files through caller-named atomic staging files"
    (cl-weave:expect-assertions 5)
    (host-kit:with-temporary-directory (directory)
      (let ((target (merge-pathnames "recovery.txt" directory))
            (prefix "#recovery.txt#."))
        (host-kit:with-atomic-output-file (stream target :mode #o600 :prefix prefix)
          (expect (search prefix (file-namestring (pathname stream))) :to-equal 0)
          (write-string "unsaved work" stream))
        (expect (host-kit:read-file-string target) :to-equal "unsaved work")
        (expect (host-kit:file-metadata-mode (host-kit:file-metadata target))
                :to-equal #o600)
        (host-kit:set-file-mode target #o640)
        (host-kit:write-file-string "updated work" target :mode #o600 :prefix prefix)
        (expect (host-kit:read-file-string target) :to-equal "updated work")
        (expect (host-kit:file-metadata-mode (host-kit:file-metadata target))
                :to-equal #o640))))

  (it "copies backups with a supplied prefix while retaining source permissions"
    (cl-weave:expect-assertions 4)
    (host-kit:with-temporary-directory (directory)
      (let ((source (merge-pathnames "note.txt" directory))
            (backup (merge-pathnames "note.txt~" directory)))
        (host-kit:write-file-string "saved work" source :mode #o640)
        (host-kit:copy-file source backup :if-exists :error :prefix "#note.txt#.")
        (expect (host-kit:read-file-string backup) :to-equal "saved work")
        (expect (host-kit:file-metadata-mode (host-kit:file-metadata backup))
                :to-equal #o640)
        (signals host-kit:host-operation-failed
          (host-kit:copy-file source backup :if-exists :error :prefix "#note.txt#."))
        (expect (host-kit:read-file-string backup) :to-equal "saved work"))))
  (it "synchronizes a new recovery file with no read permission"
    (cl-weave:expect-assertions 2)
    (host-kit:with-temporary-directory (directory)
      (let ((target (merge-pathnames "restricted.txt" directory)))
        (host-kit:write-file-string "private recovery" target
                                    :mode #o000 :synchronize t :prefix "#restricted#.")
        (expect (host-kit:file-metadata-mode (host-kit:file-metadata target))
                :to-equal #o000)
        (host-kit:set-file-mode target #o600)
        (expect (host-kit:read-file-string target) :to-equal "private recovery"))))

  (it "keeps a retained lock after a scoped pathname acquisition is rejected"
    (cl-weave:expect-assertions 5)
    (host-kit:with-temporary-directory (directory)
      (let* ((target (merge-pathnames "visited.lock" directory))
             (ready (merge-pathnames "contender-ready" directory))
             (lock (host-kit:try-acquire-file-lock target)))
        (unwind-protect
             (progn
               (expect (typep lock 'host-kit:file-lock) :to-be t)
               (signals error
                 (host-kit:call-with-file-lock
                  (lambda (stream) (declare (ignore stream)) nil)
                  target :wait nil))
               (let ((process (%start-host-kit-lock-holder target ready :expect-conflict t)))
                 (unwind-protect
                      (progn
                        (%wait-for-host-kit-lock-holder process ready)
                        (expect (sb-ext:process-alive-p process) :to-be t)
                        (write-line "exit" (sb-ext:process-input process))
                        (finish-output (sb-ext:process-input process))
                        (sb-ext:process-wait process)
                        (expect (sb-ext:process-exit-code process) :to-equal 0))
                   (when (sb-ext:process-alive-p process)
                     (sb-ext:process-kill process 15))
                   (sb-ext:process-wait process)
                   (close (sb-ext:process-input process))))
               (expect (host-kit:release-file-lock lock) :to-be t))
          (when lock (host-kit:release-file-lock lock))))))

  (it "saves and backs up literal native filenames containing wildcard characters"
    (cl-weave:expect-assertions 9)
    (host-kit:with-temporary-directory (directory)
      (let ((target (merge-pathnames
                     (sb-ext:parse-native-namestring "b*c?[x]\\y.txt") directory))
            (backup (merge-pathnames
                     (sb-ext:parse-native-namestring "b*c?[x]\\y.txt~") directory)))
        (host-kit:write-file-string "draft" target :mode #o600 :prefix "native-save-")
        (expect (host-kit:read-file-string target) :to-equal "draft")
        (expect (host-kit:file-metadata-size (host-kit:file-metadata target)) :to-equal 5)
        (expect (host-kit:file-metadata-mode (host-kit:file-metadata target)) :to-equal #o600)
        (host-kit:write-file-string "saved work" target :mode #o640 :prefix "native-save-")
        (expect (host-kit:read-file-string target) :to-equal "saved work")
        (expect (host-kit:file-metadata-size (host-kit:file-metadata target)) :to-equal 10)
        (expect (host-kit:file-metadata-mode (host-kit:file-metadata target)) :to-equal #o600)
        (host-kit:copy-file target backup :if-exists :error :prefix "native-backup-")
        (expect (host-kit:read-file-string backup) :to-equal "saved work")
        (expect (host-kit:file-metadata-size (host-kit:file-metadata backup)) :to-equal 10)
        (expect (host-kit:file-metadata-mode (host-kit:file-metadata backup)) :to-equal #o600)))))
