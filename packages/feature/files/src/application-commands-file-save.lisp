(in-package #:loom/feature/files)
(defun read-file-snapshot (path)
  "Return the opaque on-disk snapshot for PATH, or NIL when absent.
The snapshot supports safe save and reload checks."
  (funcall *file-snapshot-reader* path))

(defun %transfer-point-and-mark (old-buffer new-buffer)
  "Carry OLD-BUFFER's point and mark (when set) onto NEW-BUFFER.

MAKE-BUFFER always starts point/mark at (0,0); without this, a path-less
first save (see SAVE-BUFFER) would silently relocate the user's cursor to
the top of the buffer. Undo history has no public transfer mechanism
anywhere in the buffer protocol (MAKE-BUFFER/BUFFER-TEXT do not expose
one), so that part of OLD-BUFFER's state is a known, documented loss."
  (buffer-set-point new-buffer
                    (buffer-point-line old-buffer)
                    (buffer-point-column old-buffer))
  (multiple-value-bind (mark-line mark-column) (buffer-mark old-buffer)
    (when (and mark-line mark-column)
      (buffer-set-mark new-buffer mark-line mark-column))))

(progn
  ;; ON-OUTCOME is NIL for SAVE-BUFFER, whose errors propagate to the top-level
  ;; handler. CONFIRM-SAVE-BUFFER passes a function that receives :SKIPPED or
  ;; :CANCELLED, so every path that does not write the file reports once.
  (defun %finish-save (on-outcome outcome text)
    "Show TEXT, then pass OUTCOME to ON-OUTCOME when there is one.
The callback runs even if showing TEXT fails, and a message from whatever
it continues with stays on screen."
    (unwind-protect
         (minibuffer-message (editor-state-minibuffer *editor-state*) text)
      (when on-outcome
        (funcall on-outcome outcome))))

  (defun %call-save-step (on-outcome function)
    "Return FUNCTION's value and NIL. With ON-OUTCOME, an error finishes the
save as :CANCELLED with its text, and the values are NIL and T."
    (if on-outcome
        (handler-case (values (funcall function) nil)
          (error (condition)
            (%finish-save on-outcome :cancelled (princ-to-string condition))
            (values nil t)))
        (values (funcall function) nil)))

  (defun %save-buffer-and-continue (buffer confirmed-overwrite on-saved on-outcome)
    "Write BUFFER and call ON-SAVED, or ask before overwriting a changed file.
CONFIRMED-OVERWRITE is NIL or the (BUFFER . SNAPSHOT) the user approved."
    (multiple-value-bind (result failed)
        (%call-save-step
         on-outcome
         (lambda ()
           (handler-case
               (progn
                 (if confirmed-overwrite
                     (let ((*confirmed-file-overwrite* confirmed-overwrite))
                       (buffer-save buffer))
                     (buffer-save buffer))
                 :saved)
             (%file-changed-on-disk (condition)
               (cons :changed (%file-changed-snapshot condition))))))
      (cond
        (failed nil)
        ((eq result :saved) (funcall on-saved))
        (t
         (%prompt-save-buffer-overwrite buffer (cdr result) on-saved on-outcome)))))

  (defun %prompt-save-buffer-overwrite (buffer snapshot on-saved &optional on-outcome)
    (let* ((path (buffer-path buffer))
           (minibuffer (editor-state-minibuffer *editor-state*)))
      (minibuffer-activate
       minibuffer
       (format nil "File changed on disk. Overwrite? (y/n): ~A" path)
       :on-confirm
       (lambda (answer)
         (cond
           ((string-equal answer "y")
            (multiple-value-bind (current failed)
                (%call-save-step on-outcome
                                 (lambda () (read-file-snapshot path)))
              (cond
                (failed nil)
                ((%file-snapshot-equal-p snapshot current)
                 (%save-buffer-and-continue
                  buffer (cons buffer current) on-saved on-outcome))
                (t
                 (%prompt-save-buffer-overwrite
                  buffer current on-saved on-outcome)))))
           ((string-equal answer "n")
            (%finish-save on-outcome :skipped "Save cancelled"))
           ((string-equal answer "c")
            (%finish-save on-outcome :cancelled "Save cancelled"))
           (t
            (%prompt-save-buffer-overwrite buffer snapshot on-saved on-outcome))))
       :on-cancel
       (lambda ()
         (%finish-save on-outcome :cancelled "Quit")))))

  (progn
  (defun %prompt-create-file-parent-directory (buffer on-saved &optional on-outcome)
    (let* ((path (buffer-path buffer))
           (parent (%file-parent-directory path))
           (minibuffer (editor-state-minibuffer *editor-state*)))
      (minibuffer-activate
       minibuffer
       (format nil
               "Parent directory does not exist. Create it? (y/n): ~A"
               parent)
       :on-confirm
       (lambda (answer)
         (cond
           ((string-equal answer "y")
            (unless (nth-value
                     1
                     (%call-save-step
                      on-outcome
                      (lambda () (%ensure-file-parent-directories path))))
              (%save-buffer-with-confirmation buffer on-saved on-outcome)))
           ((string-equal answer "n")
            (%finish-save on-outcome :skipped "Save cancelled"))
           ((string-equal answer "c")
            (%finish-save on-outcome :cancelled "Save cancelled"))
           (t
            (%prompt-create-file-parent-directory buffer on-saved on-outcome))))
       :on-cancel
       (lambda ()
         (%finish-save on-outcome :cancelled "Quit")))))
  (defun %save-buffer-with-confirmation (buffer on-saved &optional on-outcome)
    (let ((path (buffer-path buffer)))
      (multiple-value-bind (save-now-p failed)
          (%call-save-step on-outcome
                           (lambda ()
                             (or (%file-parent-directory-exists-p path)
                                 (buffer-read-only-p buffer))))
        (cond
          (failed nil)
          (save-now-p
           (%save-buffer-and-continue buffer nil on-saved on-outcome))
          (t
           (%prompt-create-file-parent-directory buffer on-saved on-outcome)))))))

  (defun %save-buffer-or-warn-overwrite (buffer path)
    "Save BUFFER to PATH via BUFFER-SAVE, unless PATH already names an
existing, unrelated file.

HOST-KIT:FILE-EXISTS-P guards the first save because BUFFER-SAVE can overwrite
an existing file. BUFFER is already installed in its window with PATH attached,
so a second C-x C-s takes SAVE-BUFFER's existing-path branch and overwrites it."
    (if (%file-path-exists-p path)
        (progn
          (%remember-file-snapshot buffer (read-file-snapshot path))
          (minibuffer-message (editor-state-minibuffer *editor-state*)
                              (format nil
                                      "File exists: ~A (press C-x C-s again to overwrite)"
                                      path)))
        (%save-buffer-with-confirmation
         buffer
         (lambda () (%record-recent-file path))))))

(defun %install-file-buffer (window source path &key (name nil name-supplied-p))
  (let ((buffer
         (if name-supplied-p
             (%make-file-buffer path
                                :name
                                name
                                :initial-content
                                (buffer-text source))
             (%make-file-buffer path :initial-content (buffer-text source)))))
    (%transfer-point-and-mark source buffer)
    (register-buffer *editor-session* buffer)
    (loom/core/window-tree:window-set-buffer window buffer)
    buffer))

(defun %prompt-and-save-new-buffer (window buffer)
  "Prompt for a path, replace BUFFER in WINDOW with a file buffer, and save it.
The replacement retains text, point, and mark, but not undo history."
  (with-prompts
   (minibuffer (editor-state-minibuffer *editor-state*)
               :on-cancel
               (minibuffer-message minibuffer "Quit"))
   ((path "Save file: "))
   (if (and (stringp path) (zerop (length path)))
       (minibuffer-message minibuffer "File name cannot be empty")
       (let ((new-buffer
              (%install-file-buffer window buffer path :name (buffer-name buffer))))
         (%save-buffer-or-warn-overwrite new-buffer path)))))

(defun save-buffer ()
  "Save the selected buffer, prompting for a path first if it has none."
  (let* ((window
          (loom/core/window-tree:window-tree-selected-window
           (editor-state-window-tree *editor-state*)))
         (buffer (loom/core/window-tree:window-buffer window)))
    (if (buffer-path buffer)
        (%save-buffer-with-confirmation
         buffer
         (lambda () (%record-recent-file (buffer-path buffer))))
        (%prompt-and-save-new-buffer window buffer))))

(defun confirm-save-buffer (buffer &key (on-saved (lambda ()))
                                        (on-skipped (lambda ()))
                                        (on-cancelled (lambda ())))
  "Save BUFFER through SAVE-BUFFER's checks and report exactly one outcome.

The missing-parent prompt, the external-change check and its overwrite prompt,
backups, and format preservation are those of SAVE-BUFFER, which also records
the file as recent. Exactly one zero-argument callback runs, once: ON-SAVED
after the file is written; ON-SKIPPED when the user answers n or BUFFER visits
no file; ON-CANCELLED when the user answers c or presses C-g, or when saving
signals an error, whose text is shown in the minibuffer. ON-CANCELLED may run
inside the minibuffer's on-cancel callback, which deactivates the minibuffer
afterwards, so it must not open a new prompt."
  (let ((reported nil))
    (flet ((report (callback)
             (unless reported
               (setf reported t)
               (funcall callback))))
      (let ((path (buffer-path buffer))
            (on-outcome (lambda (outcome)
                          (ecase outcome
                            (:skipped (report on-skipped))
                            (:cancelled (report on-cancelled))))))
        (if path
            (%save-buffer-with-confirmation
             buffer
             (lambda ()
               (%record-recent-file path)
               (report on-saved))
             on-outcome)
            (%finish-save on-outcome :skipped
                          "Buffer is not visiting a file"))))))

(progn
  (defun write-file ()
    "Write the selected buffer to a new prompted path.

The selected window visits a fresh buffer carrying the original text and
point/mark, leaving the previous buffer in the session registry as a separate
buffer. Undo history is not transferred."
    (let* ((window
            (loom/core/window-tree:window-tree-selected-window
             (editor-state-window-tree *editor-state*)))
           (buffer (loom/core/window-tree:window-buffer window)))
      (with-prompts
       (minibuffer (editor-state-minibuffer *editor-state*)
                   :on-cancel
                   (minibuffer-message minibuffer "Quit"))
       ((path "Write file: "))
       (if (and (stringp path) (zerop (length path)))
           (minibuffer-message minibuffer "File name cannot be empty")
           (let ((new-buffer (%install-file-buffer window buffer path)))
             (%save-buffer-or-warn-overwrite new-buffer path))))))
  (defun %text-end-position (text)
  (let ((last-newline (position #\Newline text :from-end t)))
    (if last-newline
        (values (count #\Newline text)
                (- (length text) last-newline 1))
        (values 0 (length text)))))
  (defun %replace-buffer-with-file-snapshot (buffer snapshot)
    (let ((old-text (buffer-text buffer))
          (point-line (buffer-point-line buffer))
          (point-column (buffer-point-column buffer))
          (read-only-p (buffer-read-only-p buffer)))
      (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
        (buffer-widen buffer)
        (unwind-protect
             (progn
               (buffer-set-read-only buffer nil)
               (unless (string= old-text (%file-snapshot-text snapshot))
                 (loom/core/buffer:buffer-record-undo-boundary buffer)
                 (multiple-value-bind (end-line end-column)
                     (%text-end-position old-text)
                   (buffer-delete-region buffer 0 0 end-line end-column))
                 (unless (string= (%file-snapshot-text snapshot) "")
                   (buffer-insert-string buffer
                                         (%file-snapshot-text snapshot))))
               (buffer-set-point buffer point-line point-column)
               (when (and mark-line mark-column)
                 (buffer-set-mark buffer mark-line mark-column))
               (%remember-file-snapshot buffer snapshot)
               (buffer-mark-saved buffer))
          (buffer-set-read-only buffer read-only-p)))
    buffer))
  (defun %show-reverted-buffer (buffer snapshot)
    (%replace-buffer-with-file-snapshot buffer snapshot)
    (minibuffer-message
     (editor-state-minibuffer *editor-state*)
     (format nil "Reverted ~A" (buffer-path buffer)))
    buffer)
  (defun %prompt-revert-buffer (buffer snapshot)
    (let* ((path (buffer-path buffer))
           (minibuffer (editor-state-minibuffer *editor-state*)))
      (minibuffer-activate
       minibuffer
       (format nil "Discard local changes and revert ~A? (y/n): " path)
       :on-confirm
       (lambda (answer)
         (cond
           ((string-equal answer "y")
            (let ((current (read-file-snapshot path)))
              (cond
                ((null current)
                 (minibuffer-message
                  minibuffer
                  (format nil "File no longer exists: ~A" path)))
                ((%file-snapshot-equal-p snapshot current)
                 (%show-reverted-buffer buffer current))
                (t (%prompt-revert-buffer buffer current)))))
           ((or (string-equal answer "n")
                (string-equal answer "c"))
            (minibuffer-message minibuffer "Revert cancelled"))
           (t (%prompt-revert-buffer buffer snapshot))))
       :on-cancel
       (lambda () (minibuffer-message minibuffer "Quit")))))
  (defun revert-buffer ()
    "Replace the selected file buffer with the latest contents from disk."
    (let* ((window
            (loom/core/window-tree:window-tree-selected-window
             (editor-state-window-tree *editor-state*)))
           (buffer (loom/core/window-tree:window-buffer window))
           (path (buffer-path buffer)))
      (if path
          (let ((snapshot (read-file-snapshot path))
                (minibuffer (editor-state-minibuffer *editor-state*)))
            (cond
              ((null snapshot)
               (minibuffer-message
                minibuffer
                (format nil "File is unavailable: ~A" path)))
              ((buffer-modified-p buffer)
               (%prompt-revert-buffer buffer snapshot))
              (t (%show-reverted-buffer buffer snapshot))))
          (minibuffer-message
           (editor-state-minibuffer *editor-state*)
           "Buffer is not visiting a file"))))
  (defun %prompt-buffer-switch (buffer snapshot continuation)
    (let* ((path (buffer-path buffer))
           (minibuffer (editor-state-minibuffer *editor-state*)))
      (minibuffer-activate
       minibuffer
       (format nil
               "File changed on disk. [r]eload (discard local edits), [k]eep, [c]ancel: ~A"
               path)
       :on-confirm
       (lambda (answer)
         (cond
           ((string-equal answer "r")
            (let ((current (read-file-snapshot path)))
              (cond
                ((null current)
                 (minibuffer-message
                  minibuffer
                  (format nil "File is unavailable: ~A" path)))
                ((%file-snapshot-equal-p snapshot current)
                 (%replace-buffer-with-file-snapshot buffer current)
                 (funcall continuation))
                (t (%prompt-buffer-switch buffer current continuation)))))
           ((string-equal answer "k")
            (%remember-file-snapshot buffer snapshot)
            (funcall continuation))
           ((string-equal answer "c")
            (minibuffer-message minibuffer "Switch cancelled"))
           (t (%prompt-buffer-switch buffer snapshot continuation))))
       :on-cancel
       (lambda () (minibuffer-message minibuffer "Quit")))))
  (defun %guard-file-buffer-switch (buffer continuation)
    (let ((path (buffer-path buffer)))
      (if path
          (let ((fresh-stamp
                  (prog1 (gethash buffer *freshly-loaded-file-buffers*)
                    (remhash buffer *freshly-loaded-file-buffers*))))
            (multiple-value-bind (baseline baseline-known-p)
                (%file-buffer-snapshot buffer)
              (if (and fresh-stamp
                       baseline-known-p
                       *file-metadata-stamp-reader*
                       (equal fresh-stamp
                              (funcall *file-metadata-stamp-reader* path)))
                  (funcall continuation)
                  (let ((current (read-file-snapshot path)))
                    (cond
                      ((and baseline-known-p
                            (%file-snapshot-equal-p baseline current))
                       (funcall continuation))
                      ((and (not baseline-known-p)
                            current
                            (string= (buffer-text buffer)
                                     (%file-snapshot-text current)))
                       (%remember-file-snapshot buffer current)
                       (funcall continuation))
                      (t
                       (%prompt-buffer-switch buffer current continuation)))))))
          (funcall continuation))))
  (register-buffer-switch-guard :feature/files #'%guard-file-buffer-switch))
