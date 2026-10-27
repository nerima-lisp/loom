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
  (defun %prompt-save-buffer-overwrite (buffer snapshot on-saved)
    (let* ((path (buffer-path buffer))
           (minibuffer (editor-state-minibuffer *editor-state*)))
      (minibuffer-activate
       minibuffer
       (format nil "File changed on disk. Overwrite? (y/n): ~A" path)
       :on-confirm
       (lambda (answer)
         (cond
           ((string-equal answer "y")
            (let ((current (read-file-snapshot path)))
              (if (%file-snapshot-equal-p snapshot current)
                  (handler-case
                      (let ((*confirmed-file-overwrite*
                              (cons buffer current)))
                        (buffer-save buffer)
                        (funcall on-saved))
                    (%file-changed-on-disk (condition)
                      (%prompt-save-buffer-overwrite
                       buffer
                       (%file-changed-snapshot condition)
                       on-saved)))
                  (%prompt-save-buffer-overwrite
                   buffer current on-saved))))
           ((or (string-equal answer "n")
                (string-equal answer "c"))
            (minibuffer-message minibuffer "Save cancelled"))
           (t
            (%prompt-save-buffer-overwrite buffer snapshot on-saved))))
       :on-cancel
       (lambda () (minibuffer-message minibuffer "Quit")))))

  (progn
  (defun %prompt-create-file-parent-directory (buffer on-saved)
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
            (%ensure-file-parent-directories path)
            (%save-buffer-with-confirmation buffer on-saved))
           ((or (string-equal answer "n")
                (string-equal answer "c"))
            (minibuffer-message minibuffer "Save cancelled"))
           (t
            (%prompt-create-file-parent-directory buffer on-saved))))
       :on-cancel
       (lambda () (minibuffer-message minibuffer "Quit")))))
  (defun %save-buffer-with-confirmation (buffer on-saved)
    (let ((path (buffer-path buffer)))
      (if (or (%file-parent-directory-exists-p path)
              (buffer-read-only-p buffer))
          (handler-case
              (progn
                (buffer-save buffer)
                (funcall on-saved))
            (%file-changed-on-disk (condition)
              (%prompt-save-buffer-overwrite
               buffer
               (%file-changed-snapshot condition)
               on-saved)))
          (%prompt-create-file-parent-directory buffer on-saved)))))

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
          (let ((current (read-file-snapshot path)))
            (multiple-value-bind (baseline baseline-known-p)
                (%file-buffer-snapshot buffer)
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
                 (%prompt-buffer-switch buffer current continuation)))))
          (funcall continuation))))
  (register-buffer-switch-guard :feature/files #'%guard-file-buffer-switch))
