(in-package #:loom/test)

(describe "buffer registry"
  (it "deduplicates by EQ, keeps newest buffers first, and unregisters buffers"
    (let* ((session (loom/core/editor-session:make-editor-session (list :feature/buffers)))
           (older (make-buffer :name "older"))
           (newer (make-buffer :name "newer")))
      (loom/feature/buffers:register-buffer session older)
      (loom/feature/buffers:register-buffer session newer)
      (loom/feature/buffers:register-buffer session older)
      (let ((registered (loom/feature/buffers:registered-buffers session)))
        (expect (length registered) :to-equal 2)
        (expect (first registered) :to-be newer)
        (expect (second registered) :to-be older)
        (setf (cdr registered) nil)
        (expect (loom/feature/buffers:registered-buffers session)
                :to-equal
                (list newer older)))
      (expect (loom/feature/buffers:unregister-buffer session older)
              :to-be
              older)
      (expect (loom/feature/buffers:registered-buffers session)
              :to-equal
              (list newer))))
  (it "exports documented registry functions"
    (dolist (function
             (list loom/feature/buffers:register-buffer
                   loom/feature/buffers:unregister-buffer
                   loom/feature/buffers:registered-buffers
                   loom/feature/buffers:find-buffer-by-name
                   loom/feature/buffers:find-buffer-by-path
                   loom/feature/buffers:ensure-result-buffer))
      (expect (documentation function (find-symbol "FUNCTION" "COMMON-LISP"))
              :to-be-truthy)))
  (it "finds the newest matching name and resolves file aliases by truename"
    (host-kit:with-temporary-directory (directory)
      (let* ((path (merge-pathnames "source.txt" directory))
             (alias (merge-pathnames "alias.txt" directory))
             (session (loom/core/editor-session:make-editor-session (list :feature/buffers)))
             (older (make-buffer :name "duplicate"))
             (newer (make-buffer :name "duplicate"))
             (file-buffer (make-buffer :name "source.txt" :path path)))
        (host-kit:write-file-string "content" path)
        (sb-posix:symlink (namestring path) (namestring alias))
        (loom/feature/buffers:register-buffer session older)
        (loom/feature/buffers:register-buffer session newer)
        (loom/feature/buffers:register-buffer session file-buffer)
        (expect (loom/feature/buffers:find-buffer-by-name session "duplicate")
                :to-be
                newer)
        (expect (loom/feature/buffers:find-buffer-by-name session "missing")
                :to-be
                nil)
        (expect (loom/feature/buffers:find-buffer-by-path session alias)
                :to-be
                file-buffer)
        (expect (loom/feature/buffers:find-buffer-by-path session (merge-pathnames "missing.txt" directory))
                :to-be
                nil))))
  (it "reuses or creates and registers a named result buffer"
    (let* ((session (loom/core/editor-session:make-editor-session (list :feature/buffers)))
           (existing (make-buffer :name "*Messages*")))
      (loom/feature/buffers:register-buffer session existing)
      (expect (loom/feature/buffers:ensure-result-buffer session "*Messages*")
              :to-be
              existing)
      (let ((created (loom/feature/buffers:ensure-result-buffer session "*Help*")))
        (expect (buffer-name created) :to-equal "*Help*")
        (expect (member created (loom/feature/buffers:registered-buffers session)
                        :test (function eq))
                :to-be-truthy)
        (expect (loom/feature/buffers:ensure-result-buffer session "*Help*")
                :to-be
                created)
        (expect (length (loom/feature/buffers:registered-buffers session))
                :to-equal
                2))))
  (it "runs the close hook once before removal and records hook errors"
    (let* ((loom/core/editor-session::*session-hooks* (make-hash-table :test (function eq)))
           (session (loom/core/editor-session:make-editor-session (list :feature/buffers)))
           (buffer (make-buffer :name "closing"))
           (hook-count 0)
           (hook-reason nil)
           (was-registered-p nil))
      (loom/core/editor-session:register-session-hook
       :buffer-close
       :feature/buffers
       (lambda (hook-session hook-buffer reason)
         (incf hook-count)
         (setf hook-reason reason)
         (setf was-registered-p
               (member hook-buffer
                       (loom/feature/buffers:registered-buffers hook-session)
                       :test (function eq)))
         (error "close notification failed")))
      (loom/feature/buffers:register-buffer session buffer)
      (expect (loom/feature/buffers:unregister-buffer session buffer :reason :session-restore)
              :to-be
              buffer)
      (expect was-registered-p :to-be-truthy)
      (expect hook-reason :to-equal :session-restore)
      (expect hook-count :to-equal 1)
      (expect (loom/feature/buffers:registered-buffers session) :to-equal nil)
      (let ((record (first (loom/feature/buffers::%buffer-registry-close-hook-errors
                            (loom/core/editor-session:editor-session-slice session :feature/buffers)))))
        (expect (length record) :to-equal 3)
        (expect (first record) :to-be buffer)
        (expect (second record) :to-equal :session-restore)
        (expect (third record) :to-be-truthy))
      (loom/feature/buffers:unregister-buffer session buffer)
      (expect hook-count :to-equal 1))))