(in-package #:loom/feature/lifecycle)

(defparameter *recover-diff-buffer-name* "*Loom-Recover-Diff*")

(defparameter *recover-list-buffer-name* "*Loom-Recover*")

(defun %lifecycle-minibuffer ()
  (editor-state-minibuffer *editor-state*))

(defun %selected-window ()
  (window-tree-selected-window (editor-state-window-tree *editor-state*)))

(defun %single-line (text)
  "Return TEXT without CR and LF, which would split a label across lines."
  (remove-if (lambda (character) (member character '(#\Return #\Newline))) text))

(defun %text-end-position (text)
  (let ((last-newline (position #\Newline text :from-end t)))
    (if last-newline
        (values (count #\Newline text) (- (length text) last-newline 1))
        (values 0 (length text)))))

(defun %replace-read-only-text (buffer text)
  "Replace the text of the read-only listing BUFFER with TEXT, point at the start."
  (buffer-set-read-only buffer nil)
  (unwind-protect
       (multiple-value-bind (end-line end-column) (%text-end-position (buffer-text buffer))
         (buffer-delete-region buffer 0 0 end-line end-column)
         (buffer-set-point buffer 0 0)
         (buffer-insert-string buffer text)
         (buffer-set-point buffer 0 0)
         (buffer-mark-saved buffer))
    (buffer-set-read-only buffer t)))

(defun %show-in-other-window (buffer)
  "Show BUFFER in a window other than the selected one, splitting the frame
when it has one window, and keep the selected window."
  (let* ((tree (editor-state-window-tree *editor-state*))
         (origin (window-tree-selected-window tree))
         (windows (window-tree-windows tree))
         (others (remove origin windows :test #'eq))
         (window (cond ((find buffer others :key #'window-buffer :test #'eq))
                       (others (or (second (member origin windows :test #'eq))
                                   (first windows)))
                       (t (window-split tree origin :horizontal)))))
    (window-set-buffer window buffer)
    (window-tree-select-index tree (position origin (window-tree-windows tree)))))

;;; recover-file

(defun %other-loom-pid (buffer)
  "Return true and the other loom's pid (NIL when unreadable) when another
loom holds BUFFER's file lock. Asking again takes the lock when the other loom
has released it since the file was opened."
  (multiple-value-bind (status pid)
      (handler-case (lock-buffer-file buffer)
        (error (condition)
          (%log-lifecycle-message
           (format nil "Lock check for ~A failed: ~A" (%describe-path buffer) condition))
          :unavailable))
    (values (eq status :other) pid)))

(defun %recovery-prompt-text (candidate notice too-large-p)
  (format nil "~:[~;Diff too large to display; ~]~@[~A; ~]Recover from ~(~A~) (~A newer)? (r, d, i, C-g) "
          too-large-p
          notice
          (recovery-candidate-kind candidate)
          (format-recovery-age (recovery-candidate-age candidate))))

(defun %restore-recovery-candidate (buffer candidate)
  "Replace BUFFER's whole text with CANDIDATE's as one undo group. The buffer
stays modified and is not saved, so the recovery files remain until a save."
  (let ((text (recovery-candidate-text candidate)))
    (buffer-record-undo-boundary buffer)
    (multiple-value-bind (end-line end-column) (%text-end-position (buffer-text buffer))
      (buffer-delete-region buffer 0 0 end-line end-column))
    (buffer-set-point buffer 0 0)
    (unless (string= text "")
      (buffer-insert-string buffer text))
    (buffer-set-point buffer 0 0)
    (minibuffer-message (%lifecycle-minibuffer)
                        (format nil "Recovered from ~(~A~); save to keep"
                                (recovery-candidate-kind candidate)))))

(defun %show-recovery-diff (buffer candidate)
  "Show the unified diff from BUFFER's text to CANDIDATE's text in
*Loom-Recover-Diff*. Return NIL without showing anything when the diff is too
large to display."
  (let ((result (vcs-kit:compute-line-diff
                 (buffer-text buffer)
                 (recovery-candidate-text candidate)
                 :old-path (%single-line (%describe-path buffer))
                 :new-path (%single-line
                            (native-path-namestring
                             (recovery-candidate-pathname candidate))))))
    (unless (eq (vcs-kit:line-diff-result-status result) :too-large)
      (let ((diff (ensure-result-buffer (editor-state-session *editor-state*)
                                        *recover-diff-buffer-name*)))
        (%replace-read-only-text diff (vcs-kit:format-unified-diff result))
        (%show-in-other-window diff))
      t)))

(defun %prompt-recovery (buffer candidate notice &optional too-large-p)
  (let ((minibuffer (%lifecycle-minibuffer)))
    (minibuffer-activate
     minibuffer
     ;; Activation clears the echo area, so the too-large notice is part of
     ;; the repeated prompt.
     (%recovery-prompt-text candidate notice too-large-p)
     :input-kind :char
     :allowed-characters "rdi"
     :on-confirm
     (lambda (answer)
       (cond
         ((string= answer "r") (%restore-recovery-candidate buffer candidate))
         ((string= answer "d")
          (%prompt-recovery buffer candidate notice
                            (not (%show-recovery-diff buffer candidate))))))
     :on-cancel
     (lambda () (minibuffer-message minibuffer "Quit")))))

(defun %recover-buffer (buffer)
  "Offer BUFFER's newest unsaved work, or report why there is nothing to offer."
  (let ((minibuffer (%lifecycle-minibuffer)))
    (cond
      ((null (buffer-path buffer))
       (minibuffer-message minibuffer "Buffer is not visiting a file"))
      ((buffer-read-only-p buffer)
       (error 'buffer-read-only-error :buffer buffer))
      ((buffer-narrowed-p buffer)
       (minibuffer-message minibuffer "Widen before recovering"))
      (t
       (let ((candidate (find-recovery-candidate buffer)))
         (if (null candidate)
             (minibuffer-message minibuffer
                                 (format nil "No unsaved work for ~A"
                                         (%describe-path buffer)))
             (multiple-value-bind (other-p pid) (%other-loom-pid buffer)
               (%prompt-recovery buffer candidate
                                 (and other-p (other-loom-notice buffer pid))))))))))

(defun recover-file ()
  "Offer to replace the selected buffer's text with the newest unsaved work for
its file: r restores it, d shows the difference, i ignores it. A prefix
argument is ignored."
  (%recover-buffer (window-buffer (%selected-window))))

;;; list-recoverable-files

(defvar *recover-list-entries* (make-hash-table :test #'eq :weakness :key)
  "Recovery list buffer to the vector of entries shown on its lines.")

(defun %recovery-entry-display-time (entry)
  (or (recovery-entry-time entry) (recovery-entry-modification-time entry)))

(defun %iso-local-time (universal-time)
  (multiple-value-bind (second minute hour day month year)
      (decode-universal-time universal-time)
    (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0D"
            year month day hour minute second)))

(defun %recovery-entry-label (entry)
  (%single-line
   (or (recovery-entry-path entry)
       (format nil "(unknown path) ~A"
               (native-path-basename (recovery-entry-body entry))))))

(defun %recover-list-text (entries)
  "Return one line per entry: path, kind, and local ISO time."
  (let* ((labels (mapcar #'%recovery-entry-label entries))
         (width (reduce #'max labels :key #'length :initial-value 0)))
    (format nil "~{~A~^~%~}"
            (loop for entry in entries
                  for label in labels
                  collect (format nil "~vA  recovery  ~A"
                                  width label
                                  (%iso-local-time
                                   (%recovery-entry-display-time entry)))))))

(defun list-recoverable-files ()
  "Show every entry in the recovery directory, newest first, in the read-only
*Loom-Recover* buffer. RET on a line opens it."
  (let ((entries (stable-sort (copy-list (recovery-entries)) #'>
                              :key #'%recovery-entry-display-time)))
    (if (null entries)
        (minibuffer-message (%lifecycle-minibuffer) "No recoverable files")
        (let ((list-buffer (ensure-result-buffer (editor-state-session *editor-state*)
                                                 *recover-list-buffer-name*)))
          (buffer-set-major-mode list-buffer :recover-list)
          (setf (gethash list-buffer *recover-list-entries*) (coerce entries 'vector))
          (%replace-read-only-text list-buffer (%recover-list-text entries))
          (window-set-buffer (%selected-window) list-buffer)
          list-buffer))))

(defvar *legacy-recovery-buffers* (make-hash-table :test #'eq :weakness :key)
  "Buffer created to show a legacy recovery entry to that entry's body name.")

(defun %unused-buffer-name (session name)
  (if (find-buffer-by-name session name)
      (loop for suffix from 2
            for candidate = (format nil "~A<~D>" name suffix)
            unless (find-buffer-by-name session candidate)
              return candidate)
      name))

(defun %legacy-recovery-buffer (body-name)
  "Return the buffer this file created to show the legacy entry BODY-NAME when
it still visits no file and has no unsaved edits, or register a new one named
*Loom-Recover: BODY-NAME*. Any other buffer keeps its text."
  (let ((session (editor-state-session *editor-state*)))
    (or (find-if (lambda (buffer)
                   (and (equal (gethash buffer *legacy-recovery-buffers*) body-name)
                        (null (buffer-path buffer))
                        (not (buffer-modified-p buffer))))
                 (registered-buffers session))
        (let ((buffer (make-buffer
                       :name (%unused-buffer-name
                              session (format nil "*Loom-Recover: ~A*" body-name)))))
          (setf (gethash buffer *legacy-recovery-buffers*) body-name)
          (register-buffer session buffer)))))

(defun %show-legacy-recovery (entry)
  "Show a legacy entry's text read-only in a buffer that visits no file. A
buffer visiting the body or holding unsaved edits is never reused."
  (let* ((body (recovery-entry-body entry))
         (name (native-path-basename body))
         (text (handler-case (%lf-text (host-kit:read-file-string body))
                 (error (condition)
                   (minibuffer-message (%lifecycle-minibuffer)
                                       (format nil "Cannot read ~A: ~A" name condition))
                   (return-from %show-legacy-recovery nil))))
         (buffer (%legacy-recovery-buffer name)))
    (%replace-read-only-text buffer text)
    (window-set-buffer (%selected-window) buffer)
    buffer))

(defun %visit-recovery-file (path)
  "Open PATH as find-file does, then offer its unsaved work. The offer waits
when the switch to the buffer is itself waiting on a question."
  (let ((buffer (find-file-path path)))
    (when (and buffer (eq (window-buffer (%selected-window)) buffer))
      (%recover-buffer buffer))))

(defun recover-list-visit ()
  "Open the recovery entry on this line of *Loom-Recover*: a file's entry opens
the file and offers its unsaved work; an entry without a path shows its text."
  (let* ((list-buffer (window-buffer (%selected-window)))
         (entries (gethash list-buffer *recover-list-entries*))
         (line (buffer-point-line list-buffer))
         (entry (and entries (< line (length entries)) (aref entries line))))
    (cond
      ((null entries)
       (minibuffer-message (%lifecycle-minibuffer) "Not in a recovery list"))
      ((null entry)
       (minibuffer-message (%lifecycle-minibuffer) "No recovery entry on this line"))
      ((recovery-entry-path entry) (%visit-recovery-file (recovery-entry-path entry)))
      (t (%show-legacy-recovery entry)))))

;;; Startup notice

(defun %recovery-startup-notice (session &rest arguments)
  "Report how many recovery bodies exist. A notice from a file opened at
startup keeps the echo area; the count then goes to *Messages* only."
  (declare (ignore arguments))
  (when *loom-state-directory*
    (handler-case
        (let ((count (recovery-body-count)))
          (when (plusp count)
            (let ((text (format nil "~D recoverable file(s); M-x list-recoverable-files"
                                count)))
              (if (or (file-open-notice-shown-p session)
                      (null *editor-state*)
                      (null (editor-state-minibuffer *editor-state*)))
                  (%log-lifecycle-message text)
                  (minibuffer-message (editor-state-minibuffer *editor-state*) text)))))
      (error (condition)
        (%log-lifecycle-message
         (format nil "Cannot count recovery files: ~A" condition)))))
  nil)

(eval-when (:load-toplevel :execute)
  (register-session-hook :startup :feature/lifecycle #'%recovery-startup-notice))
