(in-package #:loom/test)

(defun %detection-test-times (path file-time &rest candidates-and-times)
  (host-kit:set-file-times path :modification-time file-time)
  (loop for (candidate time) on candidates-and-times by #'cddr
        do (host-kit:set-file-times candidate :modification-time time)))

(defun %detection-test-hashed-stem (stem path)
  "Insert PATH's hash after the reason in STEM, buffer-<reason>-<rest>, as
loom names the recovery files of a buffer that visits PATH."
  (let ((split (position #\- stem :start (1+ (position #\- stem)))))
    (format nil "~A-~A~A" (subseq stem 0 split)
            (loom/feature/lifecycle:file-path-hash path) (subseq stem split))))

(defun %detection-test-entry (state stem text path)
  "Write a recovery body and, when PATH is given, its metadata, both named with
PATH's hash. Return both."
  (let* ((stem (if path (%detection-test-hashed-stem stem path) stem))
         (directory (merge-pathnames "recovery/" state))
         (body (make-pathname :name stem :type "txt" :defaults directory))
         (meta (make-pathname :name stem :type "sexp" :defaults directory)))
    (ensure-directories-exist directory)
    (host-kit:write-file-string text body)
    (when path
      (host-kit:write-file-string
       (format nil "(:version 1 :path ~S :buffer-name \"b\" :reason :sigterm :time 1)~%"
               path)
       meta))
    (if path (list body meta) (list body))))

(defun %detection-test-buffer (path)
  (buffer-load path))

(describe "recovery candidates"
  (it "finds a newer sidecar whose text differs and measures how much newer"
    (cl-weave:expect-assertions 5)
    (%with-lock-test-state (state)
      (let* ((path (%lock-test-file state "draft.txt" "saved
"))
             (sidecar (loom/feature/auto-save:auto-save-path path)))
        (host-kit:write-file-string "unsaved
" sidecar)
        (%detection-test-times path 3900000000 sidecar 3900000125)
        (let ((candidate (loom/feature/lifecycle:find-recovery-candidate
                          (%detection-test-buffer path))))
          (expect (loom/feature/lifecycle:recovery-candidate-kind candidate) :to-be :auto-save)
          (expect (loom/feature/lifecycle:recovery-candidate-text candidate)
                  :to-equal "unsaved
")
          (expect (loom/feature/lifecycle:recovery-candidate-age candidate) :to-equal 125)
          (expect (loom/feature/lifecycle:recovery-candidate-notice candidate)
                  :to-equal
                  "Unsaved work found (auto-save, 2 min newer); M-x recover-file to restore")
          (expect (sb-ext:native-namestring
                   (loom/feature/lifecycle:recovery-candidate-pathname candidate))
                  :to-equal (sb-ext:native-namestring sidecar))))))

  (it "ignores candidates that are not newer than the file or match the buffer"
    (cl-weave:expect-assertions 3)
    (%with-lock-test-state (state)
      (let* ((path (%lock-test-file state "draft.txt" (format nil "same~%text~%")))
             (sidecar (loom/feature/auto-save:auto-save-path path)))
        (host-kit:write-file-string "older
" sidecar)
        (%detection-test-times path 3900000000 sidecar 3899999999)
        (expect (loom/feature/lifecycle:find-recovery-candidate
                 (%detection-test-buffer path))
                :to-be nil)
        (%detection-test-times path 3900000000 sidecar 3900000000)
        (expect (loom/feature/lifecycle:find-recovery-candidate
                 (%detection-test-buffer path))
                :to-be nil)
        (host-kit:write-file-string
         (format nil "same~C~%text~C~%" #\Return #\Return) sidecar)
        (%detection-test-times path 3900000000 sidecar 3900000500)
        (expect (loom/feature/lifecycle:find-recovery-candidate
                 (%detection-test-buffer path))
                :to-be nil))))

  (it "takes the newest recovery entry whose path resolves to the file"
    (cl-weave:expect-assertions 4)
    (%with-lock-test-state (state)
      (let* ((real (merge-pathnames "real/" state))
             (link (merge-pathnames "link" state))
             (path (progn (ensure-directories-exist real)
                          (%lock-test-file real "notes.txt" "saved
")))
             (linked-path (progn
                            (host-kit:create-symbolic-link (sb-ext:native-namestring real)
                                                           link)
                            (concatenate 'string (sb-ext:native-namestring link)
                                         "/notes.txt")))
             (older (%detection-test-entry state "buffer-sigterm-1-0-0-0" "older
" linked-path))
             (newer (%detection-test-entry state "buffer-sigterm-2-0-0-0" "newer
" (%lock-test-truename path)))
             (other (%detection-test-entry state "buffer-sigterm-3-0-0-0" "other
" "/elsewhere/notes.txt"))
             (legacy (%detection-test-entry state "buffer-sigterm-4-0-0-0" "legacy
" nil)))
        (%detection-test-times path 3900000000
                               (first older) 3900000100
                               (first newer) 3900003700
                               (first other) 3900009000
                               (first legacy) 3900009000)
        ;; Opened through the link, so the entry recorded under the linked
        ;; path is found by that path's hash and then resolved to the file.
        (let* ((buffer (%detection-test-buffer linked-path))
               (candidate (loom/feature/lifecycle:find-recovery-candidate buffer)))
          (expect (length (loom/feature/lifecycle:recovery-entries-for-buffer buffer))
                  :to-equal 2)
          (expect (loom/feature/lifecycle:recovery-candidate-kind candidate) :to-be :recovery)
          (expect (loom/feature/lifecycle:recovery-candidate-text candidate) :to-equal "newer
")
          (expect (loom/feature/lifecycle:recovery-candidate-notice candidate)
                  :to-equal
                  "Unsaved work found (recovery, 1 h newer); M-x recover-file to restore")))))

  (it "prefers the newer of the sidecar and the recovery entry"
    (cl-weave:expect-assertions 2)
    (%with-lock-test-state (state)
      (let* ((path (%lock-test-file state "draft.txt" "saved
"))
             (sidecar (loom/feature/auto-save:auto-save-path path))
             (entry (%detection-test-entry state "buffer-sigterm-1-0-0-0" "entry
" (%lock-test-truename path))))
        (host-kit:write-file-string "sidecar
" sidecar)
        (%detection-test-times path 3900000000 sidecar 3900000200 (first entry) 3900000100)
        (expect (loom/feature/lifecycle:recovery-candidate-kind
                 (loom/feature/lifecycle:find-recovery-candidate
                  (%detection-test-buffer path)))
                :to-be :auto-save)
        (%detection-test-times path 3900000000 sidecar 3900000100 (first entry) 3900000200)
        (expect (loom/feature/lifecycle:recovery-candidate-kind
                 (loom/feature/lifecycle:find-recovery-candidate
                  (%detection-test-buffer path)))
                :to-be :recovery))))

  (it "counts a missing file as older than any candidate"
    (cl-weave:expect-assertions 2)
    (%with-lock-test-state (state)
      (let* ((path (merge-pathnames "gone.txt" state))
             (sidecar (loom/feature/auto-save:auto-save-path path)))
        (host-kit:write-file-string "kept
" sidecar)
        (let ((candidate (loom/feature/lifecycle:find-recovery-candidate
                          (make-buffer :name "gone.txt" :path path))))
          (expect (loom/feature/lifecycle:recovery-candidate-kind candidate) :to-be :auto-save)
          (expect (<= 0 (loom/feature/lifecycle:recovery-candidate-age candidate) 60)
                  :to-be t)))))

  (it "formats ages as <1 min, whole minutes, or whole hours"
    (cl-weave:expect-assertions 6)
    (loop for (seconds text) in '((0 "<1 min") (59 "<1 min") (60 "1 min")
                                  (3599 "59 min") (3600 "1 h") (7300 "2 h"))
          do (expect (loom/feature/lifecycle:format-recovery-age seconds)
                     :to-equal text))))

(describe "stale auto-save staging files"
  (it "deletes only names with the exact sidecar prefix, six characters, and .tmp"
    (cl-weave:expect-assertions 1)
    (%with-lock-test-state (state)
      (let ((path (%lock-test-file state "a*b[1].txt")))
        (dolist (name '("#a*b[1].txt#.Ab12Z9.tmp" "#a*b[1].txt#.abc.tmp"
                        "#a*b[1].txt#.ABCDEF.tmpx" "#a*b[1].txt#.AB-DEF.tmp"
                        "#a*b[1].txt#x.ABCDEF.tmp" "#other.txt#.ABCDEF.tmp"
                        "#a*b[1].txt#"))
          (%lock-test-file state name))
        (loom/feature/lifecycle:delete-stale-auto-save-temporaries path)
        (expect (sort (remove-if-not
                       (lambda (name) (char= (char name 0) #\#))
                       (mapcar #'loom/core/editor-session:native-path-basename
                               (host-kit:directory-files state)))
                      #'string<)
                :to-equal
                (sort (list "#a*b[1].txt#.abc.tmp" "#a*b[1].txt#.ABCDEF.tmpx"
                            "#a*b[1].txt#.AB-DEF.tmp" "#a*b[1].txt#x.ABCDEF.tmp"
                            "#other.txt#.ABCDEF.tmp" "#a*b[1].txt#")
                      #'string<))))))

(describe "recovery hooks"
  (it "locks and reports unsaved work when a file opens"
    (cl-weave:expect-assertions 5)
    (%with-lock-test-state (state)
      (let* ((path (%lock-test-file state "open.txt" "saved
"))
             (sidecar (loom/feature/auto-save:auto-save-path path))
             (stale (%lock-test-file state "#open.txt#.QWErty.tmp")))
        (host-kit:write-file-string "unsaved
" sidecar)
        (%detection-test-times path (- (get-universal-time) 30) sidecar (get-universal-time))
        (%with-minibuffer-state (minibuffer "")
          (let ((session (editor-state-session *editor-state*)))
            (expect (loom/feature/lifecycle:file-open-notice-shown-p session) :to-be nil)
            (loom/feature/files:visit-file path)
            (expect (loom/core/minibuffer:minibuffer-message-string minibuffer)
                    :to-equal
                    "Unsaved work found (auto-save, <1 min newer); M-x recover-file to restore")
            (expect (loom/feature/lifecycle:file-open-notice-shown-p session) :to-be t)
            (expect (%lock-test-hold-count path) :to-equal 1)
            (expect (host-kit:path-exists-p stale) :to-be nil))))))

  (it "names the other loom and leaves its staging files when it holds the lock"
    (cl-weave:expect-assertions 2)
    (%with-lock-test-state (state)
      (let* ((path (%lock-test-file state "busy.txt" "saved
"))
             (stale (%lock-test-file state "#busy.txt#.QWErty.tmp"))
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
                        (sb-ext:process-pid process) (%lock-test-truename path)))
               (%with-minibuffer-state (minibuffer "")
                 (loom/feature/files:visit-file path)
                 (expect (loom/core/minibuffer:minibuffer-message-string minibuffer)
                         :to-equal
                         (format nil "~A is open in another loom (pid ~D)"
                                 (sb-ext:native-namestring path)
                                 (sb-ext:process-pid process)))
                 (expect (host-kit:path-exists-p stale) :to-be t)))
          (when process (%stop-lock-holder-process process))))))

  (it "does no recovery or lock I/O without a state directory"
    (cl-weave:expect-assertions 2)
    (%with-lock-test-state (state)
      (let ((path (%lock-test-file state "plain.txt"))
            (loom/feature/lifecycle:*loom-state-directory* nil))
        (host-kit:write-file-string "unsaved" (loom/feature/auto-save:auto-save-path path))
        (%with-minibuffer-state (minibuffer "")
          (loom/feature/files:visit-file path)
          (expect (loom/core/minibuffer:minibuffer-message-string minibuffer) :to-be nil)
          (expect (host-kit:path-exists-p (merge-pathnames "locks/" state)) :to-be nil)))))

  (it "deletes the file's recovery entries and staging files after a save"
    (cl-weave:expect-assertions 3)
    (%with-lock-test-state (state)
      (let* ((path (%lock-test-file state "save.txt" "saved
"))
             (matching (%detection-test-entry state "buffer-sigterm-1-0-0-0" "m
" (%lock-test-truename path)))
             (unrelated (%detection-test-entry state "buffer-sigterm-2-0-0-0" "u
" "/elsewhere/save.txt"))
             (legacy (%detection-test-entry state "buffer-sigterm-3-0-0-0" "l
" nil))
             (stale (%lock-test-file state "#save.txt#.QWErty.tmp")))
        (%with-minibuffer-state (minibuffer "")
          (let ((buffer (loom/feature/files:visit-file path)))
            (host-kit:write-file-string "again" stale)
            (buffer-insert-string buffer "X")
            (buffer-save buffer)
            (expect (mapcar #'host-kit:path-exists-p matching) :to-equal '(nil nil))
            (expect (mapcar #'host-kit:path-exists-p (append unrelated legacy))
                    :to-equal '(t t t))
            (expect (host-kit:path-exists-p stale) :to-be nil))))))

  (it "delivers queued lifecycle messages to *Messages* sinks on the next tick"
    (cl-weave:expect-assertions 2)
    (let ((loom/feature/lifecycle::*pending-lifecycle-messages* nil)
          (loom/core/minibuffer::*message-sinks* nil)
          (seen nil))
      (loom/core/minibuffer:register-message-sink :test (lambda (text) (push text seen)))
      (loom/feature/lifecycle::%log-lifecycle-message "first")
      (loom/feature/lifecycle::%log-lifecycle-message "second")
      (loom/feature/lifecycle::%recovery-tick nil 0)
      (expect (reverse seen) :to-equal '("first" "second"))
      (expect loom/feature/lifecycle::*pending-lifecycle-messages* :to-be nil))))
