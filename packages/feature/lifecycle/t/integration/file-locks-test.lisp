(in-package #:loom/test)

(defmacro %with-lock-test-state ((state) &body body)
  "Run BODY with a private temporary state directory and empty lock tables."
  `(host-kit:with-temporary-directory (,state)
     (let ((loom/feature/lifecycle:*loom-state-directory* ,state)
           (loom/feature/lifecycle::*held-file-locks* (make-hash-table :test #'equal))
           (loom/feature/lifecycle::*buffer-file-locks*
             (make-hash-table :test #'eq :weakness :key))
           (loom/feature/lifecycle::*pending-lifecycle-messages* nil)
           (loom/feature/lifecycle::*lock-directory-failure-logged-p* nil)
           (loom/feature/files::*loom-backup-directory* (merge-pathnames "backups/" ,state)))
       (unwind-protect (progn ,@body)
         (loom/feature/lifecycle:release-all-file-locks)))))

(defun %lock-test-file (directory name &optional (text "saved
"))
  (let ((path (merge-pathnames (sb-ext:parse-native-namestring name) directory)))
    (host-kit:write-file-string text path)
    path))

(defun %lock-test-truename (path)
  (sb-ext:native-namestring (host-kit:truenamize path)))

(defun %lock-test-lock-path (state path)
  (merge-pathnames (loom/feature/lifecycle:file-lock-name (%lock-test-truename path))
                   (merge-pathnames "locks/" state)))

(defun %lock-test-hold-count (path)
  (let ((held (gethash (loom/feature/lifecycle:file-lock-name (%lock-test-truename path))
                       loom/feature/lifecycle::*held-file-locks*)))
    (and held (loom/feature/lifecycle::%held-file-lock-count held))))

(defun %lock-test-held-owner (path)
  "Return the owner form this process wrote into its held lock for PATH, read
through the lock's own stream. Opening the lock file again and closing that
descriptor would release this process's POSIX lock."
  (let* ((held (gethash (loom/feature/lifecycle:file-lock-name (%lock-test-truename path))
                        loom/feature/lifecycle::*held-file-locks*))
         (stream (host-kit:file-lock-stream (loom/feature/lifecycle::%held-file-lock-lock held))))
    (file-position stream 0)
    (loom/feature/lifecycle::%read-first-recovery-form (read-line stream))))

(defun %start-lock-holder-process (target ready)
  "Start an SBCL process that holds a cl-host-kit lock on TARGET until it reads
a line. READY appears once the lock is held."
  (let ((form
          (format nil
                  "(let ((lock (host-kit:try-acquire-file-lock ~S)))
                     (assert lock)
                     (host-kit:write-file-string \"ready\" ~S :mode #o600)
                     (read-line *standard-input* nil nil))"
                  (namestring target)
                  (namestring ready)))
        (directory (make-pathname :name nil :type nil :defaults ready)))
    (sb-ext:run-program
     (namestring sb-ext:*runtime-pathname*)
     (list "--noinform" "--non-interactive" "--no-sysinit" "--no-userinit"
           "--eval" "(require :asdf)"
           "--eval" (format nil
                            "(asdf:initialize-output-translations '(:output-translations (t ~S) :ignore-inherited-configuration))"
                            (namestring (merge-pathnames "fasl/" directory)))
           "--eval" (format nil "(asdf:load-asd ~S)"
                            (namestring (asdf:system-source-file "cl-host-kit")))
           "--eval" "(asdf:load-system \"cl-host-kit\")"
           "--eval" form)
     :wait nil :input :stream :output nil :error *error-output*
     :environment (%host-kit-lock-holder-environment directory))))

(defun %stop-lock-holder-process (process)
  (ignore-errors
    (write-line "exit" (sb-ext:process-input process))
    (finish-output (sb-ext:process-input process)))
  (sb-ext:process-wait process)
  (close (sb-ext:process-input process)))

(defun %write-lock-test-owner (lock-path text)
  ;; Write in place: replacing the file would move the holder's lock away.
  (with-open-file (stream lock-path :direction :output :if-exists :overwrite)
    (write-string text stream)))

(describe "file lock names"
  (it "hashes the UTF-8 octets of the truename with FNV-1a 64"
    (cl-weave:expect-assertions 4)
    (expect (loom/feature/lifecycle:file-lock-name "") :to-equal "cbf29ce484222325.lock")
    (expect (loom/feature/lifecycle:file-lock-name "a") :to-equal "af63dc4c8601ec8c.lock")
    (expect (loom/feature/lifecycle:file-lock-name "foobar")
            :to-equal "85944171f73967e8.lock")
    (expect (loom/feature/lifecycle:file-lock-name (string (code-char #xE9)))
            :to-equal "0ac21707b7181e01.lock")))

(describe "file locks"
  (it "holds a 0600 lock in a 0700 directory and records pid, host, and truename"
    (cl-weave:expect-assertions 7)
    (%with-lock-test-state (state)
      (let* ((path (%lock-test-file state "notes [1].txt"))
             (buffer (make-buffer :name "notes [1].txt" :path path)))
        (expect (loom/feature/lifecycle:lock-buffer-file buffer) :to-be :held)
        (let* ((lock-path (%lock-test-lock-path state path))
               (owner (%lock-test-held-owner path)))
          (expect (%recovery-test-mode (merge-pathnames "locks/" state)) :to-equal #o700)
          (expect (%recovery-test-mode lock-path) :to-equal #o600)
          (expect (getf owner :pid) :to-equal (sb-posix:getpid))
          (expect (getf owner :path) :to-equal (%lock-test-truename path))
          (expect (stringp (getf owner :host)) :to-be t)
          (expect (host-kit:file-lock-held-by-other-process-p lock-path) :to-be nil)))))

  (it "counts buffers on one file and releases the lock after the last closes"
    (cl-weave:expect-assertions 7)
    (%with-lock-test-state (state)
      (let* ((path (%lock-test-file state "shared.txt"))
             (first (make-buffer :name "shared.txt" :path path))
             (second (make-buffer :name "shared.txt<2>" :path path)))
        (expect (loom/feature/lifecycle:lock-buffer-file first) :to-be :held)
        (expect (loom/feature/lifecycle:lock-buffer-file second) :to-be :held)
        (expect (loom/feature/lifecycle:lock-buffer-file second) :to-be :held)
        (expect (%lock-test-hold-count path) :to-equal 2)
        (loom/feature/lifecycle:unlock-buffer-file first)
        (expect (%lock-test-hold-count path) :to-equal 1)
        (loom/feature/lifecycle:unlock-buffer-file second)
        (expect (%lock-test-hold-count path) :to-be nil)
        (let ((lock (host-kit:try-acquire-file-lock (%lock-test-lock-path state path))))
          (expect (typep lock 'host-kit:file-lock) :to-be t)
          (when lock (host-kit:release-file-lock lock))))))

  (it "reports another process's pid, or a collision when it locks another path"
    (cl-weave:expect-assertions 8)
    (%with-lock-test-state (state)
      (let* ((path (%lock-test-file state "held.txt"))
             (truename (%lock-test-truename path))
             (lock-path (%lock-test-lock-path state path))
             (ready (merge-pathnames "ready" state))
             (process nil))
        (ensure-directories-exist lock-path)
        (unwind-protect
             (progn
               (setf process (%start-lock-holder-process lock-path ready))
               (%wait-for-host-kit-lock-holder process ready)
               (%write-lock-test-owner
                lock-path
                (format nil "(:pid ~D :host \"h\" :path ~S)~%"
                        (sb-ext:process-pid process) truename))
               (multiple-value-bind (status pid)
                   (loom/feature/lifecycle:lock-buffer-file
                    (make-buffer :name "held.txt" :path path))
                 (expect status :to-be :other)
                 (expect pid :to-equal (sb-ext:process-pid process)))
               (expect (%lock-test-hold-count path) :to-be nil)
               (%write-lock-test-owner
                lock-path
                "(:pid 1 :host \"h\" :path \"/elsewhere/other-file-with-a-longer-name.txt\")
")
               (expect (loom/feature/lifecycle:lock-buffer-file
                        (make-buffer :name "held.txt" :path path))
                       :to-be :collision)
               (expect (length loom/feature/lifecycle::*pending-lifecycle-messages*)
                       :to-equal 1)
               (expect (search "without a lock"
                               (first loom/feature/lifecycle::*pending-lifecycle-messages*))
                       :to-be-truthy)
               (%write-lock-test-owner lock-path (make-string 200 :initial-element #\())
               (multiple-value-bind (status pid)
                   (loom/feature/lifecycle:lock-buffer-file
                    (make-buffer :name "held.txt" :path path))
                 (expect status :to-be :other)
                 (expect pid :to-be nil)))
          (when process (%stop-lock-holder-process process))))))

  (it "works without locks and logs once when the lock directory cannot be made"
    (cl-weave:expect-assertions 5)
    (%with-lock-test-state (state)
      (host-kit:write-file-string "not a directory" (merge-pathnames "locks" state))
      (let ((path (%lock-test-file state "a.txt")))
        (expect (loom/feature/lifecycle:lock-buffer-file
                 (make-buffer :name "a.txt" :path path))
                :to-be :unavailable)
        (expect (loom/feature/lifecycle:lock-buffer-file
                 (make-buffer :name "a.txt" :path path))
                :to-be :unavailable)
        (expect (length loom/feature/lifecycle::*pending-lifecycle-messages*) :to-equal 1)
        (expect (search "without locks"
                        (first loom/feature/lifecycle::*pending-lifecycle-messages*))
                :to-be-truthy)
        (expect (%lock-test-hold-count path) :to-be nil))))

  (it "does nothing without a state directory"
    (cl-weave:expect-assertions 2)
    (%with-lock-test-state (state)
      (let ((path (%lock-test-file state "a.txt"))
            (loom/feature/lifecycle:*loom-state-directory* nil))
        (expect (loom/feature/lifecycle:lock-buffer-file
                 (make-buffer :name "a.txt" :path path))
                :to-be :unavailable)
        (expect (host-kit:path-exists-p (merge-pathnames "locks/" state)) :to-be nil))))

  (it "locks the new path when write-file saves the buffer elsewhere"
    (cl-weave:expect-assertions 3)
    (%with-lock-test-state (state)
      (let ((new-path (merge-pathnames "renamed.txt" state)))
        (%with-minibuffer-state (minibuffer "draft")
          (loom/feature/files:write-file)
          (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) new-path)
          (expect (host-kit:read-file-string new-path) :to-equal "draft")
          (expect (%lock-test-hold-count new-path) :to-equal 1)
          (expect (getf (%lock-test-held-owner new-path) :path)
                  :to-equal (%lock-test-truename new-path))))))

  (it "releases every held lock from another thread at shutdown"
    (cl-weave:expect-assertions 4)
    (%with-lock-test-state (state)
      (%with-minibuffer-state (minibuffer "")
        (let* ((left (%lock-test-file state "left.txt"))
               (right (%lock-test-file state "right.txt"))
               (session (editor-state-session *editor-state*))
               (state-object *editor-state*)
               (held loom/feature/lifecycle::*held-file-locks*)
               (buffers loom/feature/lifecycle::*buffer-file-locks*))
          (loom/feature/lifecycle:lock-buffer-file (make-buffer :name "l" :path left))
          (loom/feature/lifecycle:lock-buffer-file (make-buffer :name "r" :path right))
          (expect (sb-thread:join-thread
                   (sb-thread:make-thread
                    (lambda ()
                      ;; Only global values cross threads; these stand in for
                      ;; the tables the running editor keeps globally.
                      (let ((*editor-state* state-object)
                            (loom/feature/lifecycle::*held-file-locks* held)
                            (loom/feature/lifecycle::*buffer-file-locks* buffers))
                        (handler-case
                            (progn
                              (loom/feature/lifecycle::%lifecycle-shutdown-hook
                               session :normal)
                              nil)
                          (error (condition) (princ-to-string condition)))))
                    :name "lock-release-test"))
                  :to-be nil)
          (expect (hash-table-count loom/feature/lifecycle::*held-file-locks*) :to-equal 0)
          (dolist (path (list left right))
            (let ((lock (host-kit:try-acquire-file-lock (%lock-test-lock-path state path))))
              (expect (typep lock 'host-kit:file-lock) :to-be t)
              (when lock (host-kit:release-file-lock lock))))))))

  (it "keeps writing after one buffer fails and releases the locks last"
    (cl-weave:expect-assertions 7)
    (%with-lock-test-state (state)
      (%with-minibuffer-state (minibuffer "")
        (let* ((state-object *editor-state*)
               (session (editor-state-session *editor-state*))
               (locked-path (%lock-test-file state "locked.txt"))
               (locked (loom/feature/files:visit-file locked-path))
               (unresolved-path (merge-pathnames "work/unresolved.txt" state))
               (unresolved (make-buffer :name "unresolved.txt" :path unresolved-path
                                        :initial-content "unresolved"))
               (failing (make-buffer :name "failing" :initial-content "fails"))
               (held-locks loom/feature/lifecycle::*held-file-locks*)
               (buffer-locks loom/feature/lifecycle::*buffer-file-locks*)
               (truenamize (fdefinition 'host-kit:truenamize))
               (write-file-string (fdefinition 'host-kit:write-file-string)))
          (dolist (buffer (list unresolved failing))
            (loom/feature/buffers:register-buffer session buffer)
            (buffer-mark-modified buffer))
          (buffer-insert-string locked "kept ")
          (expect (%lock-test-hold-count locked-path) :to-equal 1)
          (with-replaced-function
              (host-kit:truenamize
               (lambda (path &rest options)
                 (if (search "unresolved" (sb-ext:native-namestring path))
                     (error "Cannot resolve ~A" (sb-ext:native-namestring path))
                     (apply truenamize path options))))
            (with-replaced-function
                (host-kit:write-file-string
                 (lambda (string pathspec &rest options)
                   (if (string= string "fails")
                       (error "Disk full")
                       (apply write-file-string string pathspec options))))
              (destructuring-bind (failure messages)
                  (sb-thread:join-thread
                   (sb-thread:make-thread
                    (lambda ()
                      ;; The test binds these on the main thread; at run time
                      ;; they are global values that every thread sees.
                      (let ((*editor-state* state-object)
                            (loom/feature/lifecycle:*loom-state-directory* state)
                            (loom/feature/lifecycle::*held-file-locks* held-locks)
                            (loom/feature/lifecycle::*buffer-file-locks* buffer-locks)
                            (loom/feature/lifecycle::*pending-lifecycle-messages* nil))
                        (list (handler-case
                                  (progn
                                    (loom/feature/lifecycle::%lifecycle-shutdown-hook
                                     session :sigterm)
                                    nil)
                                (error (condition) (princ-to-string condition)))
                              loom/feature/lifecycle::*pending-lifecycle-messages*)))
                    :name "recovery-isolation-test"))
                (expect failure :to-be nil)
                (expect (count-if (lambda (text) (search "failing" text)) messages)
                        :to-equal 1))))
          (let* ((directory (merge-pathnames "recovery/" state))
                 (bodies (%recovery-test-files directory "txt")))
            (expect (sort (mapcar #'host-kit:read-file-string bodies) #'string<)
                    :to-equal (list (format nil "kept saved~%") "unresolved"))
            (expect (length (%recovery-test-files directory "sexp")) :to-equal 2)
            (expect (getf (loom/feature/lifecycle:read-recovery-meta
                           (make-pathname
                            :type "sexp"
                            :defaults (find "unresolved" bodies
                                            :key #'host-kit:read-file-string
                                            :test #'string=)))
                          :path)
                    :to-equal (sb-ext:native-namestring unresolved-path)))
          (expect (%lock-test-hold-count locked-path) :to-be nil))))))
