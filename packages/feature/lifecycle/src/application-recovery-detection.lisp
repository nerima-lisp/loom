(in-package #:loom/feature/lifecycle)

(defstruct (recovery-candidate (:copier nil))
  "Unsaved text for one file. KIND is :AUTO-SAVE (the #name# sidecar) or
:RECOVERY (a signal recovery entry, kept in ENTRY). TEXT has CRLF read as LF.
AGE is how many seconds the candidate is newer than the file, or how old the
candidate is when the file is missing."
  kind
  pathname
  entry
  text
  modification-time
  age)

(defun %file-modification-time (pathname)
  "Return PATHNAME's modification time when it names a regular file, else NIL."
  (let ((metadata (handler-case (host-kit:file-metadata pathname)
                    (host-kit:host-operation-failed () nil))))
    (and metadata
         (eq (host-kit:file-metadata-kind metadata) :regular-file)
         (host-kit:file-metadata-modification-time metadata))))

(defun %lf-text (text)
  (if (search (coerce '(#\Return #\Newline) 'string) text)
      (with-output-to-string (output)
        (loop with end = (length text)
              for index from 0 below end
              for character = (char text index)
              unless (and (char= character #\Return)
                          (< (1+ index) end)
                          (char= (char text (1+ index)) #\Newline))
                do (write-char character output)))
      text))

(defun %path-basename-equal-p (path name)
  (let ((start (1+ (or (position #\/ path :from-end t) -1))))
    (and (= (- (length path) start) (length name))
         (string= path name :start1 start))))

(defun %recovery-entry-for-file-p (entry truename names)
  "True when ENTRY's recorded path resolves to TRUENAME.
Only paths whose last component is one of NAMES are resolved, because a
resolved path keeps its last component unless the file itself is a link."
  (let ((path (recovery-entry-path entry)))
    (and path
         (or (string= path truename)
             (and (some (lambda (name) (%path-basename-equal-p path name)) names)
                  (handler-case
                      (string= (native-path-namestring
                                (host-kit:truenamize
                                 (sb-ext:parse-native-namestring path)))
                               truename)
                    (error () nil)))))))

(defun %buffer-file-names (buffer truename)
  (remove-duplicates
   (list (native-path-basename (sb-ext:parse-native-namestring truename))
         (native-path-basename (literal-file-path (buffer-path buffer))))
   :test #'string=))

(defun recovery-entries-for-buffer (buffer)
  "Return the recovery entries whose :PATH resolves to BUFFER's file.
Only entries whose names carry the hash of the file's truename or of the path
the buffer was opened by are read, which covers a recorded truename that has
since become a symbolic link. Legacy entries, which record no path, never
match."
  (let ((truename (and *loom-state-directory* (buffer-file-truename buffer))))
    (when truename
      (let ((names (%buffer-file-names buffer truename))
            (hashes (remove-duplicates
                     (list (file-path-hash truename)
                           (file-path-hash (%describe-path buffer)))
                     :test #'string=)))
        (remove-if-not (lambda (entry)
                         (%recovery-entry-for-file-p entry truename names))
                       (recovery-entries-with-hashes hashes))))))

(defun %candidate (kind pathname entry modification-time file-time buffer-text)
  "Return a candidate for PATHNAME when it is newer than the file and its text
differs from BUFFER-TEXT. A missing file counts as older than any candidate."
  (when (and modification-time
             (or (null file-time) (> modification-time file-time)))
    (let ((text (handler-case (%lf-text (host-kit:read-file-string pathname))
                  (error () nil))))
      (when (and text (string/= text buffer-text))
        (make-recovery-candidate
         :kind kind
         :pathname pathname
         :entry entry
         :text text
         :modification-time modification-time
         :age (- (if file-time modification-time (get-universal-time))
                 (or file-time modification-time)))))))

(defun find-recovery-candidate (buffer)
  "Return the newest RECOVERY-CANDIDATE for BUFFER's file, or NIL.
Candidates are the auto-save sidecar and the newest recovery entry for the
file; one qualifies only when it is newer than the file and differs from the
buffer text."
  (let ((path (buffer-path buffer)))
    (when path
      (let* ((file (literal-file-path path))
             (file-time (%file-modification-time file))
             (text (buffer-text buffer))
             (sidecar (auto-save-path file))
             (entry (let ((newest nil))
                      (dolist (entry (recovery-entries-for-buffer buffer) newest)
                        (when (or (null newest)
                                  (> (recovery-entry-modification-time entry)
                                     (recovery-entry-modification-time newest)))
                          (setf newest entry)))))
             (candidates
               (remove nil
                       (list (%candidate :auto-save sidecar nil
                                         (%file-modification-time sidecar)
                                         file-time text)
                             (and entry
                                  (%candidate :recovery (recovery-entry-body entry)
                                              entry
                                              (recovery-entry-modification-time entry)
                                              file-time text))))))
        (let ((newest nil))
          (dolist (candidate candidates newest)
            (when (or (null newest)
                      (> (recovery-candidate-modification-time candidate)
                         (recovery-candidate-modification-time newest)))
              (setf newest candidate))))))))

(defun format-recovery-age (seconds)
  "Return SECONDS as <1 min, N min below an hour, or N h."
  (cond ((< seconds 60) "<1 min")
        ((< seconds 3600) (format nil "~D min" (floor seconds 60)))
        (t (format nil "~D h" (floor seconds 3600)))))

(defun recovery-candidate-notice (candidate)
  (format nil "Unsaved work found (~(~A~), ~A newer); M-x recover-file to restore"
          (recovery-candidate-kind candidate)
          (format-recovery-age (recovery-candidate-age candidate))))

(defun other-loom-notice (buffer pid)
  (format nil "~A is open in another loom (pid ~:[unknown~;~:*~D~])"
          (native-path-namestring (literal-file-path (buffer-path buffer)))
          pid))

(defun delete-stale-auto-save-temporaries (path)
  "Delete the staging files cl-host-kit leaves beside PATH's sidecar when an
auto-save stops between creating and renaming them. Only names made of the
exact #<name>#. prefix, six random characters, and .tmp are deleted. The
directory is read by name only, without a status call per entry."
  (let* ((sidecar (auto-save-path (literal-file-path path)))
         (prefix (concatenate 'string (native-path-basename sidecar) "."))
         (directory (host-kit:pathname-directory-pathname sidecar))
         (names (remove-if-not (lambda (name) (%auto-save-temporary-name-p name prefix))
                               (%directory-entry-names directory))))
    (dolist (name names)
      (host-kit:delete-file-if-exists
       (merge-pathnames (sb-ext:parse-native-namestring name) directory)))
    names))

(defun %auto-save-temporary-name-p (name prefix)
  ;; HOST-KIT:WRITE-FILE-STRING stages in <prefix>XXXXXX.tmp, where mkstemp
  ;; fills XXXXXX with ASCII letters and digits.
  (let ((random-start (length prefix)))
    (and (= (length name) (+ random-start 6 4))
         (string= prefix name :end2 random-start)
         (string= ".tmp" name :start2 (+ random-start 6))
         (loop for index from random-start below (+ random-start 6)
               for character = (char name index)
               always (or (char<= #\a character #\z)
                          (char<= #\A character #\Z)
                          (char<= #\0 character #\9))))))

(defun delete-recovery-entries-for-buffer (buffer)
  "Delete the body and then the metadata of each recovery entry for BUFFER's
file. Legacy entries are kept."
  (dolist (entry (recovery-entries-for-buffer buffer))
    (host-kit:delete-file-if-exists (recovery-entry-body entry))
    (when (recovery-entry-meta entry)
      (host-kit:delete-file-if-exists (recovery-entry-meta entry)))))

(defvar *file-open-notice-sessions* (make-hash-table :test #'eq :weakness :key)
  "Sessions in which opening a file has shown a recovery or other-loom notice.")

(defun file-open-notice-shown-p (session)
  "True once opening a file in SESSION has shown a recovery or other-loom
notice. The startup count notice defers to such a notice."
  (values (gethash session *file-open-notice-sessions*)))

(defun %show-file-open-notice (session text)
  (setf (gethash session *file-open-notice-sessions*) t)
  (when (and *editor-state* (editor-state-minibuffer *editor-state*))
    (minibuffer-message (editor-state-minibuffer *editor-state*) text)))

(defun %describe-path (buffer)
  (native-path-namestring (literal-file-path (buffer-path buffer))))

(defun %recovery-after-file-open (session buffer)
  "Lock BUFFER's file, then report another loom holding it, or else clean up
stale auto-save staging files and report unsaved work newer than the file."
  (when (and *loom-state-directory* (buffer-path buffer))
    (handler-case
        (multiple-value-bind (status pid) (lock-buffer-file buffer)
          (if (eq status :other)
              (%show-file-open-notice session (other-loom-notice buffer pid))
              (progn
                (handler-case (delete-stale-auto-save-temporaries (buffer-path buffer))
                  (error (condition)
                    (%log-lifecycle-message
                     (format nil "Cannot delete stale auto-save files for ~A: ~A"
                             (%describe-path buffer) condition))))
                (let ((candidate (find-recovery-candidate buffer)))
                  (when candidate
                    (%show-file-open-notice
                     session (recovery-candidate-notice candidate)))))))
      (error (condition)
        (%log-lifecycle-message
         (format nil "Recovery check for ~A failed: ~A"
                 (%describe-path buffer) condition)))))
  nil)

(defun %recovery-after-save (session buffer)
  "After a successful save, follow a changed path with the lock and delete the
recovery entries for the file. Stale auto-save staging files are deleted only
while the lock file names this process, because another loom holding the lock
may be writing them."
  (declare (ignore session))
  (when (and *loom-state-directory* (buffer-path buffer))
    (handler-case
        (progn
          (relock-moved-buffer-file buffer)
          (delete-recovery-entries-for-buffer buffer)
          (when (%own-file-lock-p buffer)
            (delete-stale-auto-save-temporaries (buffer-path buffer))))
      (error (condition)
        (%log-lifecycle-message
         (format nil "Recovery cleanup after saving ~A failed: ~A"
                 (%describe-path buffer) condition)))))
  nil)

(defun %recovery-buffer-close (session buffer reason)
  (declare (ignore session reason))
  (unlock-buffer-file buffer)
  nil)

(defun %recovery-tick (session time)
  (declare (ignore session time))
  (flush-lifecycle-messages)
  nil)

(eval-when (:load-toplevel :execute)
  (register-session-hook :after-file-open :feature/lifecycle
                         #'%recovery-after-file-open)
  (register-session-hook :after-save :feature/lifecycle #'%recovery-after-save)
  (register-session-hook :buffer-close :feature/lifecycle #'%recovery-buffer-close)
  (register-session-hook :tick :feature/lifecycle #'%recovery-tick))
