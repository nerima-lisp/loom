(in-package #:loom/test)

(defun %recovery-test-mode (path)
  (logand #o777 (host-kit:file-metadata-mode (host-kit:file-metadata path))))

(defun %recovery-test-files (directory type)
  (remove-if-not (lambda (path) (equal (pathname-type path) type))
                 (host-kit:directory-files directory)))

(defun %write-recovery-test-meta (directory stem text)
  (let ((path (make-pathname :name stem :type "sexp" :defaults directory)))
    (host-kit:write-file-string text path)
    path))

(defun %write-recovery-test-body (directory stem text)
  (let ((path (make-pathname :name stem :type "txt" :defaults directory)))
    (host-kit:write-file-string text path)
    path))

(defparameter *recovery-test-meta*
  "(:version 1 :path \"/work/notes.txt\" :buffer-name \"notes.txt\" :reason :sigterm :time 3970000000)")

(describe "recovery body and metadata writes"
  (it "writes the body and then its metadata as 0600 files in a 0700 directory"
    (host-kit:with-temporary-directory (state)
      (let* ((loom/feature/lifecycle:*loom-state-directory* state)
             (path (merge-pathnames "notes.txt" state))
             (buffer (make-buffer :name "notes.txt" :path path :initial-content "draft"))
             (written nil))
        (buffer-mark-modified buffer)
        (let ((body
                (with-replaced-function
                    (host-kit:write-file-string
                     (let ((original (fdefinition 'host-kit:write-file-string)))
                       (lambda (string pathspec &rest options)
                         (push (pathname-type pathspec) written)
                         (apply original string pathspec options))))
                  (loom/feature/lifecycle::%save-recovery-buffer buffer :sigterm 0)))
              (directory (merge-pathnames "recovery/" state)))
          (expect (reverse written) :to-equal (list "txt" "sexp"))
          (expect (host-kit:read-file-string body) :to-equal "draft")
          (expect (%recovery-test-mode directory) :to-equal #o700)
          (expect (mapcar #'%recovery-test-mode
                          (append (%recovery-test-files directory "txt")
                                  (%recovery-test-files directory "sexp")))
                  :to-equal (list #o600 #o600))
          (let ((meta (loom/feature/lifecycle:read-recovery-meta
                       (make-pathname :type "sexp" :defaults body))))
            (expect (getf meta :version) :to-equal 1)
            (expect (getf meta :path)
                    :to-equal (loom/core/editor-session:native-path-namestring
                               (host-kit:truenamize path)))
            (expect (getf meta :buffer-name) :to-equal "notes.txt")
            (expect (getf meta :reason) :to-be :sigterm)
            (expect (integerp (getf meta :time)) :to-be-truthy))))))

  (it "records a NIL path for a buffer that visits no file"
    (host-kit:with-temporary-directory (state)
      (let* ((loom/feature/lifecycle:*loom-state-directory* state)
             (buffer (make-buffer :name "*scratch*" :initial-content "notes"))
             (body (loom/feature/lifecycle::%save-recovery-buffer buffer :sighup 1))
             (meta (loom/feature/lifecycle:read-recovery-meta
                    (make-pathname :type "sexp" :defaults body))))
        (expect (getf meta :path) :to-be nil)
        (expect (getf meta :reason) :to-be :sighup)
        (expect (getf meta :buffer-name) :to-equal "*scratch*"))))

  (it "writes nothing when no state directory is set"
    (let ((loom/feature/lifecycle:*loom-state-directory* nil))
      (expect (loom/feature/lifecycle::%save-recovery-buffer
               (make-buffer :name "x" :initial-content "x") :sigterm 0)
              :to-be nil)
      (expect (loom/feature/lifecycle:recovery-entries) :to-be nil)))

  (it "keeps the mode of an existing recovery directory"
    (host-kit:with-temporary-directory (state)
      (let ((loom/feature/lifecycle:*loom-state-directory* state)
            (directory (merge-pathnames "recovery/" state)))
        (ensure-directories-exist directory)
        (host-kit:set-file-mode directory #o755)
        (loom/feature/lifecycle::%save-recovery-buffer
         (make-buffer :name "x" :initial-content "x") :sigterm 0)
        (expect (%recovery-test-mode directory) :to-equal #o755))))

  (it "writes a body and metadata for each modified buffer from the shutdown hook"
    (host-kit:with-temporary-directory (state)
      (%with-minibuffer-state (minibuffer "unsaved")
        (let ((loom/feature/lifecycle:*loom-state-directory* state))
          (buffer-mark-modified (%selected-test-buffer))
          (loom/feature/lifecycle::%lifecycle-shutdown-hook
           (editor-state-session *editor-state*) :sigterm)
          (let ((directory (merge-pathnames "recovery/" state)))
            (expect (mapcar #'host-kit:read-file-string
                            (%recovery-test-files directory "txt"))
                    :to-equal (list "unsaved"))
            (expect (length (%recovery-test-files directory "sexp")) :to-equal 1)))))))

(describe "recovery writes from another thread"
  (it "writes the body and metadata without the main thread's session binding"
    (host-kit:with-temporary-directory (state)
      (%with-minibuffer-state (minibuffer "unsaved")
        (let ((state-object *editor-state*)
              (session (editor-state-session *editor-state*))
              (hidden (make-buffer :name "hidden" :initial-content "hidden")))
          (loom/feature/buffers:register-buffer session hidden)
          (buffer-mark-modified hidden)
          (buffer-mark-modified (%selected-test-buffer))
          (expect
           (sb-thread:join-thread
            (sb-thread:make-thread
             (lambda ()
               ;; Only global values cross threads: the state and state
               ;; directory are set globally at startup, the session is not.
               (let ((*editor-state* state-object)
                     (loom/feature/lifecycle:*loom-state-directory* state))
                 (handler-case
                     (progn
                       (loom/feature/lifecycle::%lifecycle-shutdown-hook
                        session :sigterm)
                       nil)
                   (error (condition) (princ-to-string condition)))))
             :name "recovery-watchdog-test"))
           :to-be nil)
          (let ((directory (merge-pathnames "recovery/" state)))
            (expect (sort (mapcar #'host-kit:read-file-string
                                  (%recovery-test-files directory "txt"))
                          #'string<)
                    :to-equal (list "hidden" "unsaved"))
            (expect (length (%recovery-test-files directory "sexp")) :to-equal 2)))))))

(describe "recovery metadata reader"
  (it "accepts the version 1 shape and reads only the first form"
    (host-kit:with-temporary-directory (directory)
      (let ((meta (loom/feature/lifecycle:read-recovery-meta
                   (%write-recovery-test-meta
                    directory "first-form"
                    (concatenate 'string *recovery-test-meta* " (trailing")))))
        (expect (getf meta :path) :to-equal "/work/notes.txt")
        (expect (getf meta :time) :to-equal 3970000000))))

  (it-each
      (("not a list" "42")
       ("odd length" "(:version 1 :path)")
       ("dotted" "(:version 1 :path nil :buffer-name \"b\" :reason :sigterm . :time)")
       ("wrong version" "(:version 2 :path nil :buffer-name \"b\" :reason :sigterm :time 1)")
       ("relative path" "(:version 1 :path \"notes.txt\" :buffer-name \"b\" :reason :sigterm :time 1)")
       ("unknown reason" "(:version 1 :path nil :buffer-name \"b\" :reason :sigkill :time 1)")
       ("missing key" "(:version 1 :path nil :buffer-name \"b\" :reason :sigterm)")
       ("duplicate key" "(:version 1 :path nil :path nil :reason :sigterm :time 1)")
       ("extra key" "(:version 1 :path nil :buffer-name \"b\" :reason :sigterm :time 1 :format :utf-8)")
       ("negative time" "(:version 1 :path nil :buffer-name \"b\" :reason :sigterm :time -1)")
       ("read-time evaluation" "(:version 1 :path nil :buffer-name #.(princ-to-string 1) :reason :sigterm :time 1)")
       ("structure syntax" "(:version 1 :path nil :buffer-name \"b\" :reason :sigterm :time #S(pathname))")
       ("unterminated" "(:version 1 :path \"")
       ("empty" ""))
      "ignores metadata that is ~A" (label text)
    (declare (ignore label))
    (host-kit:with-temporary-directory (directory)
      (expect (loom/feature/lifecycle:read-recovery-meta
               (%write-recovery-test-meta directory "bad" text))
              :to-be nil)))

  (it "ignores metadata larger than 4 KiB"
    (host-kit:with-temporary-directory (directory)
      (let ((padded (concatenate 'string *recovery-test-meta*
                                 (make-string 4096 :initial-element #\Space))))
        (expect (loom/feature/lifecycle:read-recovery-meta
                 (%write-recovery-test-meta directory "large" padded))
                :to-be nil)))))

(describe "recovery entry index"
  (it "pairs bodies with metadata and treats missing or invalid metadata as legacy"
    (host-kit:with-temporary-directory (state)
      (let ((loom/feature/lifecycle:*loom-state-directory* state)
            (loom/feature/lifecycle::*recovery-index* nil)
            (directory (merge-pathnames "recovery/" state)))
        (ensure-directories-exist directory)
        (%write-recovery-test-body directory "a-with-meta" "one")
        (%write-recovery-test-meta directory "a-with-meta" *recovery-test-meta*)
        (%write-recovery-test-body directory "b-legacy" "two")
        (%write-recovery-test-body directory "c-broken" "three")
        (%write-recovery-test-meta directory "c-broken" "(:version")
        (%write-recovery-test-meta directory "d-orphan" *recovery-test-meta*)
        (let ((entries (loom/feature/lifecycle:recovery-entries)))
          (expect (mapcar (lambda (entry)
                            (pathname-name (loom/feature/lifecycle:recovery-entry-body entry)))
                          entries)
                  :to-equal (list "a-with-meta" "b-legacy" "c-broken"))
          (expect (mapcar #'loom/feature/lifecycle:recovery-entry-path entries)
                  :to-equal (list "/work/notes.txt" nil nil))
          (expect (loom/feature/lifecycle:recovery-entry-reason (first entries))
                  :to-be :sigterm)))))

  (it "reuses an unchanged listing and rereads only changed metadata"
    (host-kit:with-temporary-directory (state)
      (let* ((loom/feature/lifecycle:*loom-state-directory* state)
             (loom/feature/lifecycle::*recovery-index* nil)
             (directory (merge-pathnames "recovery/" state))
             (past (- (get-universal-time) 120))
             (reads 0))
        (ensure-directories-exist directory)
        (%write-recovery-test-body directory "one" "one")
        (let ((meta-one (%write-recovery-test-meta directory "one" *recovery-test-meta*)))
          (%write-recovery-test-body directory "two" "two")
          (let ((meta-two (%write-recovery-test-meta directory "two" *recovery-test-meta*)))
            (dolist (path (list meta-one meta-two directory))
              (host-kit:set-file-times path :modification-time past))
            (let ((original (fdefinition 'loom/feature/lifecycle:read-recovery-meta)))
              (with-replaced-function
                  (loom/feature/lifecycle:read-recovery-meta
                   (lambda (pathname)
                     (incf reads)
                     (funcall original pathname)))
                (loom/feature/lifecycle:recovery-entries)
                (expect reads :to-equal 2)
                (loom/feature/lifecycle:recovery-entries)
                (expect reads :to-equal 2)
                (host-kit:write-file-string
                 "(:version 1 :path \"/work/other.txt\" :buffer-name \"other.txt\" :reason :sighup :time 1)"
                 meta-two)
                (host-kit:set-file-times directory :modification-time (+ past 1))
                (let ((entries (loom/feature/lifecycle:recovery-entries)))
                  (expect reads :to-equal 3)
                  (expect (mapcar #'loom/feature/lifecycle:recovery-entry-path entries)
                          :to-equal (list "/work/notes.txt" "/work/other.txt")))))))))))
