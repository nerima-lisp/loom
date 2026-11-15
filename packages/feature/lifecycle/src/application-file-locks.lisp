(in-package #:loom/feature/lifecycle)

;; Every function here may run on the evaluation watchdog thread during
;; shutdown, so state lives in global variables guarded by one mutex and no
;; function depends on the main thread's dynamic bindings or on the minibuffer.

(defconstant +lock-owner-size-limit+ 4096)

(defvar *file-locks-mutex* (sb-thread:make-mutex :name "loom file locks"))

(defstruct (%held-file-lock (:copier nil))
  truename
  lock
  (count 1))

(defvar *held-file-locks* (make-hash-table :test #'equal)
  "Lock file name to the %HELD-FILE-LOCK this process holds for one truename.")

(defvar *buffer-file-locks* (make-hash-table :test #'eq :weakness :key)
  "Buffer to (TRUENAME . HELD-P) for the file it last tried to lock.")

(defvar *lifecycle-messages-mutex*
  (sb-thread:make-mutex :name "loom lifecycle messages"))

(defvar *pending-lifecycle-messages* nil
  "*Messages* lines not yet delivered, newest first.")

(defvar *lock-directory-failure-logged-p* nil)

(defun %log-lifecycle-message (text)
  ;; Files opened at startup run before the *Messages* sink is installed, so
  ;; lines wait here until the next tick delivers them.
  (sb-thread:with-mutex (*lifecycle-messages-mutex*)
    (push text *pending-lifecycle-messages*))
  text)

(defun flush-lifecycle-messages ()
  "Deliver pending lifecycle lines to the message sinks in order."
  (when *pending-lifecycle-messages*
    (let ((messages (sb-thread:with-mutex (*lifecycle-messages-mutex*)
                      (shiftf *pending-lifecycle-messages* nil))))
      (dolist (text (reverse messages))
        (minibuffer-log-message text)))))

(defun file-lock-name (truename)
  "Return the lock file name for native TRUENAME: the FNV-1a 64-bit hash of
its UTF-8 octets as 16 lowercase hex digits, with type lock."
  (concatenate 'string (file-path-hash truename) ".lock"))

(defun %lock-directory-unusable (condition)
  "Log the first failure to create or write the lock directory and return NIL."
  (unless *lock-directory-failure-logged-p*
    (setf *lock-directory-failure-logged-p* t)
    (%log-lifecycle-message
     (format nil "Opening files without locks: cannot write ~A (~A)"
             (native-path-namestring
              (merge-pathnames "locks/"
                               (uiop:ensure-directory-pathname
                                *loom-state-directory*)))
             condition)))
  nil)

(defun %lock-directory ()
  "Return the lock directory, creating it as 0700, or NIL when it is unusable."
  (handler-case (%private-state-directory "locks/")
    (error (condition) (%lock-directory-unusable condition))))

(defun %lock-owner-text (truename)
  (with-standard-io-syntax
    (let ((*package* (find-package :keyword)))
      (format nil "~S~%"
              (list :pid (sb-posix:getpid)
                    :host (%character-string (host-kit:hostname))
                    :path truename)))))

(defun %write-lock-owner (lock truename)
  ;; Release keeps the file and its old text, so readers take the first form.
  (let ((stream (host-kit:file-lock-stream lock)))
    (file-position stream 0)
    (write-string (%lock-owner-text truename) stream)
    (finish-output stream)))

(defun %valid-lock-owner-p (form)
  (and (listp form)
       (handler-case (= (length form) 6) (type-error () nil))
       (typep (getf form :pid) '(integer 1))
       (stringp (getf form :host))
       (stringp (getf form :path))))

(defun read-lock-owner (pathname)
  "Return the (:pid :host :path) plist recorded in lock file PATHNAME, or NIL.
Only the first form is read, with evaluation and # syntax disabled; files over
4 KiB, unreadable files, and malformed forms yield NIL."
  (handler-case
      (let ((metadata (host-kit:file-metadata pathname)))
        (when (and (eq (host-kit:file-metadata-kind metadata) :regular-file)
                   (<= (host-kit:file-metadata-size metadata)
                       +lock-owner-size-limit+))
          (let ((form (%read-first-recovery-form
                       (host-kit:read-file-string pathname))))
            (and (%valid-lock-owner-p form) form))))
    (error () nil)))

(defun %acquire-file-lock (truename)
  "Lock TRUENAME for this process. Return :HELD, :OTHER and the owner's pid
(NIL when unreadable), :COLLISION, or :UNAVAILABLE. Call with the mutex held."
  (let* ((name (file-lock-name truename))
         (held (gethash name *held-file-locks*)))
    (cond
      (held
       (if (string= (%held-file-lock-truename held) truename)
           (progn (incf (%held-file-lock-count held)) :held)
           (%lock-collision truename name (%held-file-lock-truename held))))
      (t
       (let ((directory (%lock-directory)))
         (if (null directory)
             :unavailable
             (let* ((pathname (merge-pathnames name directory))
                    (lock (handler-case
                              (host-kit:try-acquire-file-lock pathname :mode #o600)
                            (error (condition)
                              (%lock-directory-unusable condition)
                              (return-from %acquire-file-lock :unavailable)))))
               (if lock
                   (progn
                     (handler-case (%write-lock-owner lock truename)
                       (error (condition)
                         (%log-lifecycle-message
                          (format nil "Cannot record the owner of ~A: ~A"
                                  truename condition))))
                     (setf (gethash name *held-file-locks*)
                           (make-%held-file-lock :truename truename :lock lock))
                     :held)
                   (let ((owner (read-lock-owner pathname)))
                     (cond
                       ((or (null owner) (string= (getf owner :path) truename))
                        (values :other (getf owner :pid)))
                       (t (%lock-collision truename name (getf owner :path)))))))))))))

(defun %lock-collision (truename name other)
  (%log-lifecycle-message
   (format nil "Opened ~A without a lock: ~A is the lock of ~A" truename name other))
  :collision)

(defun %release-file-lock (truename)
  "Drop one hold on TRUENAME and release the lock after the last. Mutex held."
  (let* ((name (file-lock-name truename))
         (held (gethash name *held-file-locks*)))
    (when (and held (string= (%held-file-lock-truename held) truename))
      (when (zerop (decf (%held-file-lock-count held)))
        (remhash name *held-file-locks*)
        (handler-case (host-kit:release-file-lock (%held-file-lock-lock held))
          (error (condition)
            (%log-lifecycle-message
             (format nil "Cannot release the lock of ~A: ~A" truename condition))))))))

(defun lock-buffer-file (buffer)
  "Hold the file lock of BUFFER's file and return its status: :HELD, :OTHER
with the other loom's pid, :COLLISION, or :UNAVAILABLE. A buffer already
holding the lock for its current file keeps its single hold."
  (if (null *loom-state-directory*)
      :unavailable
      (let ((truename (buffer-file-truename buffer)))
        (if (null truename)
            :unavailable
            (sb-thread:with-mutex (*file-locks-mutex*)
              (let ((record (gethash buffer *buffer-file-locks*)))
                (if (and record (cdr record) (string= (car record) truename))
                    :held
                    (progn
                      (when (and record (cdr record))
                        (%release-file-lock (car record)))
                      (multiple-value-bind (status pid) (%acquire-file-lock truename)
                        (setf (gethash buffer *buffer-file-locks*)
                              (cons truename (eq status :held)))
                        (values status pid))))))))))

(defun unlock-buffer-file (buffer)
  "Drop BUFFER's hold on its file lock, if any."
  (sb-thread:with-mutex (*file-locks-mutex*)
    (let ((record (gethash buffer *buffer-file-locks*)))
      (when record
        (remhash buffer *buffer-file-locks*)
        (when (cdr record)
          (%release-file-lock (car record)))))))

(defun relock-moved-buffer-file (buffer)
  "Lock BUFFER's file again when its truename differs from the one it last
tried to lock, as after write-file or the first save of a new buffer."
  (let ((record (sb-thread:with-mutex (*file-locks-mutex*)
                  (gethash buffer *buffer-file-locks*))))
    (unless (and record (equal (car record) (buffer-file-truename buffer)))
      (lock-buffer-file buffer))))

(defun release-all-file-locks ()
  "Release every file lock this process holds. Safe on any thread."
  (sb-thread:with-mutex (*file-locks-mutex*)
    (let ((held (loop for entry being the hash-values of *held-file-locks*
                      collect entry)))
      (clrhash *held-file-locks*)
      (clrhash *buffer-file-locks*)
      (dolist (entry held)
        (handler-case (host-kit:release-file-lock (%held-file-lock-lock entry))
          (error (condition)
            (%log-lifecycle-message
             (format nil "Cannot release the lock of ~A: ~A"
                     (%held-file-lock-truename entry) condition))))))))
