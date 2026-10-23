(in-package #:loom/feature/file-tree)

(defun %transfer-point-and-mark (old-buffer new-buffer)
  "Carry OLD-BUFFER's point and mark (when set) onto NEW-BUFFER.

MAKE-BUFFER always starts point/mark at (0,0); without this, a path-less
first save (see SAVE-BUFFER) would silently relocate the user's cursor to
the top of the buffer. Undo history has no public transfer mechanism
anywhere in the buffer protocol (MAKE-BUFFER/BUFFER-TEXT do not expose
one), so that part of OLD-BUFFER's state is a known, documented loss."
  (buffer-set-point new-buffer (buffer-point-line old-buffer) (buffer-point-column old-buffer))
  (multiple-value-bind (mark-line mark-column) (buffer-mark old-buffer)
    (when (and mark-line mark-column)
      (buffer-set-mark new-buffer mark-line mark-column))))

(defun %save-buffer-or-warn-overwrite (buffer path)
  "Save BUFFER to PATH via BUFFER-SAVE, unless PATH already names an
existing, unrelated file.

HOST-KIT:FILE-EXISTS-P guards the first save because BUFFER-SAVE can overwrite
an existing file. BUFFER is already installed in its window with PATH attached,
so a second C-x C-s takes SAVE-BUFFER's existing-path branch and overwrites it."
  (if (host-kit:file-exists-p path)
      (minibuffer-message
       (editor-state-minibuffer *editor-state*)
       (format nil "File exists: ~A (press C-x C-s again to overwrite)" path))
      (progn
        (buffer-save buffer)
        (remember-recent-file path))))

(defun %install-file-buffer (window source path &key (name nil name-supplied-p))
  (let ((buffer (if name-supplied-p
                   (%make-file-buffer path
                                      :name name
                                      :initial-content (buffer-text source))
                   (%make-file-buffer path
                                      :initial-content (buffer-text source)))))
    (%transfer-point-and-mark source buffer)
    (%register-buffer buffer)
    (loom/feature/window:window-set-buffer window buffer)
    buffer))

(defun %prompt-and-save-new-buffer (window buffer)
  "Prompt for a path, replace BUFFER in WINDOW with a file buffer, and save it.
The replacement retains text, point, and mark, but not undo history."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((path "Save file: "))
    (let ((new-buffer (%install-file-buffer window buffer path
                                           :name (buffer-name buffer))))
      (%save-buffer-or-warn-overwrite new-buffer path))))

(defun save-buffer ()
  "Save the selected buffer, prompting for a path first if it has none."
  (let* ((window (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))
         (buffer (loom/feature/window:window-buffer window)))
    (if (buffer-path buffer)
        (progn
          (buffer-save buffer)
          (remember-recent-file (buffer-path buffer)))
        (%prompt-and-save-new-buffer window buffer))))

(defun write-file ()
  "Write the selected buffer to a new prompted path.

The selected window visits a fresh buffer carrying the original text and
point/mark, leaving the previous buffer in the session registry as a separate
buffer. Undo history is not transferred."
  (let* ((window (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))
         (buffer (loom/feature/window:window-buffer window)))
    (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                   :on-cancel (minibuffer-message minibuffer "Quit"))
        ((path "Write file: "))
      (let ((new-buffer (%install-file-buffer window buffer path)))
        (%save-buffer-or-warn-overwrite new-buffer path)))))
