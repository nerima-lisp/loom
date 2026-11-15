(in-package #:loom/test)

(defun %recover-test-key (minibuffer character)
  (loom/core/minibuffer:minibuffer-handle-key
   minibuffer (cl-tty-kit:make-key-event :type :character :code character)))

(defun %recover-test-cancel (minibuffer)
  (loom/core/minibuffer:minibuffer-handle-key
   minibuffer (cl-tty-kit:make-key-event :type :special :code :control-g)))

(defun %recover-test-selected-buffer ()
  (loom/core/window-tree:window-buffer
   (loom/core/window-tree:window-tree-selected-window
    (editor-state-window-tree *editor-state*))))

(defun %recover-test-sidecar-file (state name saved unsaved)
  "Write NAME holding SAVED and a sidecar holding UNSAVED two minutes newer."
  (let* ((path (%lock-test-file state name saved))
         (sidecar (loom/feature/auto-save:auto-save-path path)))
    (host-kit:write-file-string unsaved sidecar)
    (%detection-test-times path 3900000000 sidecar 3900000125)
    (values path sidecar)))

(defun %recover-test-prompt (kind age)
  (format nil "Recover from ~A (~A newer)? (r, d, i, C-g) " kind age))

(defun %recover-test-meta (entry path time)
  "Rewrite ENTRY's metadata so that it records PATH written at TIME."
  (host-kit:write-file-string
   (format nil "(:version 1 :path ~S :buffer-name \"b\" :reason :sigterm :time ~D)~%"
           path time)
   (second entry)))

(defun %recover-test-local-time (universal-time)
  (multiple-value-bind (second minute hour day month year)
      (decode-universal-time universal-time)
    (format nil "~D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0D"
            year month day hour minute second)))

(describe "recover-file"
  (it "restores the newer sidecar as one undo step and leaves the file and sidecar"
    (cl-weave:expect-assertions 10)
    (%with-lock-test-state (state)
      (multiple-value-bind (path sidecar)
          (%recover-test-sidecar-file state "draft.txt" (format nil "saved~%")
                                      (format nil "line one~C~%line two~C~%"
                                              #\Return #\Return))
        (%with-minibuffer-state (minibuffer "")
          (let ((buffer (loom/feature/files:visit-file path)))
            (buffer-set-point buffer 0 3)
            (loom/feature/lifecycle:recover-file)
            (expect (loom/core/minibuffer:minibuffer-prompt-string minibuffer)
                    :to-equal (%recover-test-prompt "auto-save" "2 min"))
            (%recover-test-key minibuffer #\r)
            (expect (buffer-text buffer) :to-equal (format nil "line one~%line two~%"))
            (expect (buffer-modified-p buffer) :to-be-truthy)
            (expect (list (buffer-point-line buffer) (buffer-point-column buffer))
                    :to-equal '(0 0))
            (expect (loom/core/minibuffer:minibuffer-message-string minibuffer)
                    :to-equal "Recovered from auto-save; save to keep")
            (expect (host-kit:read-file-string path) :to-equal (format nil "saved~%"))
            (expect (host-kit:path-exists-p sidecar) :to-be t)
            (expect (loom/core/minibuffer:minibuffer-active-p minibuffer) :to-be-falsy)
            (buffer-undo buffer)
            (expect (buffer-text buffer) :to-equal (format nil "saved~%"))
            (expect (host-kit:path-exists-p sidecar) :to-be t))))))

  (it "shows the diff, asks again, and names a diff too large to display"
    (cl-weave:expect-assertions 7)
    (%with-lock-test-state (state)
      (multiple-value-bind (path sidecar)
          (%recover-test-sidecar-file state "diff.txt" (format nil "same~%saved~%")
                                      (format nil "same~%unsaved~%"))
        (%with-minibuffer-state (minibuffer "")
          (let ((buffer (loom/feature/files:visit-file path)))
            (loom/feature/lifecycle:recover-file)
            (%recover-test-key minibuffer #\d)
            (let ((diff (loom/feature/buffers:find-buffer-by-name
                         (editor-state-session *editor-state*) "*Loom-Recover-Diff*")))
              (expect (buffer-text diff)
                      :to-equal
                      (format nil "--- ~A~%+++ ~A~%@@ -1,2 +1,2 @@~% same~%-saved~%+unsaved~%"
                              (sb-ext:native-namestring path)
                              (sb-ext:native-namestring sidecar)))
              (expect (buffer-read-only-p diff) :to-be-truthy)
              (expect (eq (%recover-test-selected-buffer) buffer) :to-be-truthy))
            (expect (loom/core/minibuffer:minibuffer-prompt-string minibuffer)
                    :to-equal (%recover-test-prompt "auto-save" "2 min"))
            (%recover-test-key minibuffer #\i)
            (expect (buffer-text buffer) :to-equal (format nil "same~%saved~%"))
            (host-kit:write-file-string
             (format nil "~{~D~%~}" (loop for line from 0 below 600 collect line))
             sidecar)
            (%detection-test-times path 3900000000 sidecar 3900000125)
            (loom/feature/lifecycle:recover-file)
            (%recover-test-key minibuffer #\d)
            (expect (loom/core/minibuffer:minibuffer-prompt-string minibuffer)
                    :to-equal (concatenate 'string "Diff too large to display; "
                                           (%recover-test-prompt "auto-save" "2 min")))
            (%recover-test-cancel minibuffer)
            (expect (loom/core/minibuffer:minibuffer-message-string minibuffer)
                    :to-equal "Quit"))))))

  (it "rejects pathless, read-only, and narrowed buffers and reports no candidate"
    (cl-weave:expect-assertions 6)
    (%with-lock-test-state (state)
      (%with-minibuffer-state (minibuffer "scratch")
        (loom/feature/lifecycle:recover-file)
        (expect (loom/core/minibuffer:minibuffer-message-string minibuffer)
                :to-equal "Buffer is not visiting a file")
        (let* ((path (%recover-test-sidecar-file state "guard.txt" (format nil "saved~%")
                                                 (format nil "unsaved~%")))
               (buffer (loom/feature/files:visit-file path)))
          (buffer-set-read-only buffer t)
          (signals buffer-read-only-error (loom/feature/lifecycle:recover-file))
          (buffer-set-read-only buffer nil)
          (buffer-narrow-to-region buffer 0 0 0 2)
          (loom/feature/lifecycle:recover-file)
          (expect (loom/core/minibuffer:minibuffer-message-string minibuffer)
                  :to-equal "Widen before recovering")
          (expect (loom/core/minibuffer:minibuffer-active-p minibuffer) :to-be-falsy))
        (let ((plain (%lock-test-file state "plain.txt")))
          (loom/feature/files:visit-file plain)
          (loom/feature/lifecycle:recover-file)
          (expect (loom/core/minibuffer:minibuffer-message-string minibuffer)
                  :to-equal (format nil "No unsaved work for ~A"
                                    (sb-ext:native-namestring plain)))
          (expect (loom/core/minibuffer:minibuffer-active-p minibuffer) :to-be-falsy)))))

  (it "puts the other loom's notice before the prompt"
    (cl-weave:expect-assertions 1)
    (%with-lock-test-state (state)
      (let ((path (%recover-test-sidecar-file state "shared.txt" (format nil "saved~%")
                                              (format nil "unsaved~%"))))
        (%with-minibuffer-state (minibuffer "")
          (with-replaced-function (loom/feature/lifecycle:lock-buffer-file
                                   (lambda (buffer)
                                     (declare (ignore buffer))
                                     (values :other 4242)))
            (loom/feature/files:visit-file path)
            (loom/feature/lifecycle:recover-file)
            (expect (loom/core/minibuffer:minibuffer-prompt-string minibuffer)
                    :to-equal
                    (format nil "~A is open in another loom (pid 4242); ~A"
                            (sb-ext:native-namestring path)
                            (%recover-test-prompt "auto-save" "2 min")))))))))

(describe "list-recoverable-files"
  (it "lists entries newest first with path, kind, and local time"
    (cl-weave:expect-assertions 4)
    (%with-lock-test-state (state)
      (let ((entry (%detection-test-entry state "buffer-sigterm-1-0-0-0" "kept"
                                          "/work/notes.txt"))
            (legacy (%detection-test-entry state "buffer-sighup-3-0-0-0" "legacy" nil)))
        (host-kit:write-file-string
         "(:version 1 :path \"/work/notes.txt\" :buffer-name \"notes.txt\" :reason :sigterm :time 3900000000)"
         (second entry))
        (host-kit:set-file-times (first legacy) :modification-time 3900000100)
        (%with-minibuffer-state (minibuffer "")
          (let ((list-buffer (loom/feature/lifecycle:list-recoverable-files)))
            (expect (eq (%recover-test-selected-buffer) list-buffer) :to-be-truthy)
            (expect (buffer-read-only-p list-buffer) :to-be-truthy)
            (expect (buffer-major-mode list-buffer) :to-be :recover-list)
            (expect (buffer-text list-buffer)
                    :to-equal
                    (format nil "~40A  recovery  ~A~%~40A  recovery  ~A"
                            "(unknown path) buffer-sighup-3-0-0-0.txt"
                            (%recover-test-local-time 3900000100)
                            "/work/notes.txt"
                            (%recover-test-local-time 3900000000))))))))

  (it "reports when there is nothing to list"
    (cl-weave:expect-assertions 1)
    (%with-lock-test-state (state)
      (%with-minibuffer-state (minibuffer "")
        (loom/feature/lifecycle:list-recoverable-files)
        (expect (loom/core/minibuffer:minibuffer-message-string minibuffer)
                :to-equal "No recoverable files"))))

  (it "opens a file row's file, including a missing one, and offers its unsaved work"
    (cl-weave:expect-assertions 5)
    (%with-lock-test-state (state)
      (let* ((path (%lock-test-file state "kept.txt" (format nil "saved~%")))
             (entry (%detection-test-entry state "buffer-sigterm-1-0-0-0"
                                           (format nil "recovered~%")
                                           (%lock-test-truename path)))
             (missing (merge-pathnames "never-saved.txt" state))
             (missing-truename (%lock-test-truename missing))
             (missing-entry (%detection-test-entry state "buffer-sigterm-2-0-0-0"
                                                   (format nil "new~%") missing-truename)))
        (%recover-test-meta entry (%lock-test-truename path) 3900000125)
        (%recover-test-meta missing-entry missing-truename 3900000200)
        (%detection-test-times path 3900000000 (first entry) 3900000125)
        (%with-minibuffer-state (minibuffer "")
          (let ((list-buffer (loom/feature/lifecycle:list-recoverable-files)))
            ;; Newest first: the missing file's entry is on line 0.
            (buffer-set-point list-buffer 1 0)
            (loom/feature/lifecycle:recover-list-visit)
            (expect (sb-ext:native-namestring
                     (host-kit:truenamize (buffer-path (%recover-test-selected-buffer))))
                    :to-equal (%lock-test-truename path))
            (expect (loom/core/minibuffer:minibuffer-prompt-string minibuffer)
                    :to-equal (%recover-test-prompt "recovery" "2 min"))
            (%recover-test-key minibuffer #\r)
            (expect (buffer-text (%recover-test-selected-buffer))
                    :to-equal (format nil "recovered~%"))
            (loom/feature/lifecycle:list-recoverable-files)
            (buffer-set-point list-buffer 0 0)
            (loom/feature/lifecycle:recover-list-visit)
            (expect (namestring (buffer-path (%recover-test-selected-buffer)))
                    :to-equal (namestring missing))
            (expect (loom/core/minibuffer:minibuffer-prompt-string minibuffer)
                    :to-equal (%recover-test-prompt "recovery" "<1 min")))))))

  (it "shows a legacy row's text read-only in a buffer without a path"
    (cl-weave:expect-assertions 4)
    (%with-lock-test-state (state)
      (%detection-test-entry state "buffer-sighup-3-0-0-0" (format nil "legacy~C~%" #\Return)
                             nil)
      (%with-minibuffer-state (minibuffer "")
        (loom/feature/lifecycle:list-recoverable-files)
        (loom/feature/lifecycle:recover-list-visit)
        (let ((buffer (%recover-test-selected-buffer)))
          (expect (buffer-name buffer) :to-equal "*Loom-Recover: buffer-sighup-3-0-0-0.txt*")
          (expect (buffer-path buffer) :to-be nil)
          (expect (buffer-read-only-p buffer) :to-be-truthy)
          (expect (buffer-text buffer) :to-equal (format nil "legacy~%"))))))

  (it "keeps the edits of a buffer visiting the legacy body and of an edited legacy view"
    (cl-weave:expect-assertions 9)
    (%with-lock-test-state (state)
      (let ((legacy (%detection-test-entry state "buffer-sighup-3-0-0-0"
                                           (format nil "legacy~%") nil)))
        (%with-minibuffer-state (minibuffer "")
          (let ((visited (loom/feature/files:find-file-path
                          (sb-ext:native-namestring (first legacy)))))
            (buffer-insert-string visited "edit ")
            (loom/feature/lifecycle:list-recoverable-files)
            (loom/feature/lifecycle:recover-list-visit)
            (let ((shown (%recover-test-selected-buffer)))
              (expect (eq shown visited) :to-be nil)
              (expect (buffer-text visited) :to-equal (format nil "edit legacy~%"))
              (expect (buffer-modified-p visited) :to-be-truthy)
              (expect (buffer-read-only-p visited) :to-be-falsy)
              (expect (buffer-path shown) :to-be nil)
              (expect (buffer-text shown) :to-equal (format nil "legacy~%"))
              (buffer-set-read-only shown nil)
              (buffer-insert-string shown "mine ")
              (loom/feature/lifecycle:list-recoverable-files)
              (loom/feature/lifecycle:recover-list-visit)
              (expect (eq (%recover-test-selected-buffer) shown) :to-be nil)
              (expect (buffer-text shown) :to-equal (format nil "mine legacy~%"))
              (expect (buffer-text (%recover-test-selected-buffer))
                      :to-equal (format nil "legacy~%"))))))))

  (it "offers the unsaved work once the external-change question shows the file"
    (cl-weave:expect-assertions 8)
    (%with-lock-test-state (state)
      (let* ((path (%lock-test-file state "changed.txt" (format nil "saved~%")))
             (entry (%detection-test-entry state "buffer-sigterm-1-0-0-0"
                                           (format nil "recovered~%")
                                           (%lock-test-truename path))))
        (%with-minibuffer-state (minibuffer "")
          (let* ((buffer (loom/feature/files:visit-file path))
                 (change-prompt
                   (format nil "File changed on disk. [r]eload (discard local edits), [k]eep, [c]ancel: ~A"
                           (sb-ext:native-namestring (buffer-path buffer)))))
            (host-kit:write-file-string (format nil "external~%") path)
            (%detection-test-times path 3900000000 (first entry) 3900000125)
            (let ((list-buffer (loom/feature/lifecycle:list-recoverable-files)))
              (loom/feature/lifecycle:recover-list-visit)
              (expect (loom/core/minibuffer:minibuffer-prompt-string minibuffer)
                      :to-equal change-prompt)
              (%confirm-minibuffer minibuffer "k")
              (expect (eq (%recover-test-selected-buffer) buffer) :to-be-truthy)
              (expect (loom/core/minibuffer:minibuffer-prompt-string minibuffer)
                      :to-equal (%recover-test-prompt "recovery" "2 min"))
              (%recover-test-key minibuffer #\i)
              ;; c and C-g leave the list shown and offer nothing.
              (host-kit:write-file-string (format nil "again~%") path)
              (%detection-test-times path 3900000000 (first entry) 3900000125)
              (loom/feature/lifecycle:list-recoverable-files)
              (loom/feature/lifecycle:recover-list-visit)
              (%confirm-minibuffer minibuffer "c")
              (expect (loom/core/minibuffer:minibuffer-message-string minibuffer)
                      :to-equal "Switch cancelled")
              (expect (loom/core/minibuffer:minibuffer-active-p minibuffer) :to-be-falsy)
              (expect (eq (%recover-test-selected-buffer) list-buffer) :to-be-truthy)
              (loom/feature/lifecycle:recover-list-visit)
              (expect (loom/core/minibuffer:minibuffer-prompt-string minibuffer)
                      :to-equal change-prompt)
              (%recover-test-cancel minibuffer)
              (expect (loom/core/minibuffer:minibuffer-active-p minibuffer)
                      :to-be-falsy))))))))

(describe "recovery names and counts"
  (it "names a file's entries with its path hash and reads only those metadata files"
    (cl-weave:expect-assertions 4)
    (%with-lock-test-state (state)
      (let* ((path (%lock-test-file state "named.txt"))
             (hash (loom/feature/lifecycle:file-path-hash (%lock-test-truename path)))
             (buffer (make-buffer :name "named.txt" :path path :initial-content "x"))
             (body (loom/feature/lifecycle::%save-recovery-buffer buffer :sigterm 0))
             (pathless (loom/feature/lifecycle::%save-recovery-buffer
                        (make-buffer :name "*scratch*" :initial-content "y") :sighup 1))
             (reads 0))
        (dotimes (index 50)
          (%detection-test-entry state (format nil "buffer-sigterm-~D-0-0-0" index) "other"
                                 (format nil "/elsewhere/file~D.txt" index)))
        (expect (search (format nil "buffer-sigterm-~A-" hash) (pathname-name body))
                :to-equal 0)
        (expect (length (uiop:split-string (pathname-name pathless) :separator "-"))
                :to-equal 6)
        (let ((original (fdefinition 'loom/feature/lifecycle:read-recovery-meta)))
          (with-replaced-function (loom/feature/lifecycle:read-recovery-meta
                                   (lambda (pathname)
                                     (incf reads)
                                     (funcall original pathname)))
            (expect (mapcar #'loom/feature/lifecycle:recovery-entry-body
                            (loom/feature/lifecycle:recovery-entries-for-buffer
                             (buffer-load path)))
                    :to-equal (list body))))
        (expect reads :to-equal 1))))

  (it "counts recovery bodies by name"
    (cl-weave:expect-assertions 2)
    (%with-lock-test-state (state)
      (expect (loom/feature/lifecycle:recovery-body-count) :to-equal 0)
      (%detection-test-entry state "buffer-sigterm-1-0-0-0" "a" "/work/a.txt")
      (%detection-test-entry state "buffer-sighup-2-0-0-0" "b" nil)
      (expect (loom/feature/lifecycle:recovery-body-count) :to-equal 2))))

(describe "startup recovery notice"
  (it "echoes the count, or logs it when a file-open notice holds the echo area"
    (cl-weave:expect-assertions 4)
    (%with-lock-test-state (state)
      (%with-minibuffer-state (minibuffer "")
        (let ((session (editor-state-session *editor-state*))
              (text "2 recoverable file(s); M-x list-recoverable-files"))
          (loom/feature/lifecycle::%recovery-startup-notice session nil nil)
          (expect (loom/core/minibuffer:minibuffer-message-string minibuffer) :to-be nil)
          (%detection-test-entry state "buffer-sigterm-1-0-0-0" "a" "/work/a.txt")
          (%detection-test-entry state "buffer-sighup-2-0-0-0" "b" nil)
          (loom/feature/lifecycle::%recovery-startup-notice session nil nil)
          (expect (loom/core/minibuffer:minibuffer-message-string minibuffer) :to-equal text)
          (loom/core/minibuffer:minibuffer-message minibuffer "Unsaved work found")
          (setf (gethash session loom/feature/lifecycle::*file-open-notice-sessions*) t)
          (loom/feature/lifecycle::%recovery-startup-notice session nil nil)
          (expect (loom/core/minibuffer:minibuffer-message-string minibuffer)
                  :to-equal "Unsaved work found")
          (expect loom/feature/lifecycle::*pending-lifecycle-messages*
                  :to-equal (list text)))))))
