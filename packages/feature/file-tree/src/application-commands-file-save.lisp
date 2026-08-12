;;;; packages/feature/file-tree/src/application-commands-file-save.lisp
;;;;
;;;; Application layer: file-save/write commands and helpers.
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

BUFFER-SAVE's real method (infrastructure/filesystem.lisp) writes via
HOST-KIT:WRITE-FILE-STRING with default :IF-EXISTS :SUPERSEDE semantics,
which would silently clobber such a file, so HOST-KIT:FILE-EXISTS-P
(exported by cl-host-kit) guards it: on a hit, warn instead of writing
rather than building a general confirmation-dialog subsystem -- BUFFER is
already installed in its window with PATH attached by the caller, so the
user's very next C-x C-s goes through SAVE-BUFFER's ordinary
already-has-a-path fast path and writes for real, which serves as the
required second, explicit confirmation."
  (if (host-kit:file-exists-p path)
      (minibuffer-message
       (editor-state-minibuffer *editor-state*)
       (format nil "File exists: ~A (press C-x C-s again to overwrite)" path))
      (progn
        (buffer-save buffer)
        (remember-recent-file path))))

(defun %prompt-and-save-new-buffer (window buffer)
  "Prompt for a path and save BUFFER (which has none yet) under it.

The buffer protocol exposes no operation to attach a path to an existing
buffer after the fact (BUFFER-PATH has no SETF method); instead of reaching
into domain/buffer.lisp's internal %BUFFER-PATH slot, this builds a fresh
buffer carrying the same text and the new path via the public
MAKE-BUFFER/BUFFER-TEXT operations, swaps it into WINDOW, and saves it (see
%TRANSFER-POINT-AND-MARK and %SAVE-BUFFER-OR-WARN-OVERWRITE)."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((path "Save file: "))
    (let ((new-buffer (%make-file-buffer path
                                         :name (buffer-name buffer)
                                         :initial-content (buffer-text buffer))))
      (%transfer-point-and-mark buffer new-buffer)
      (%register-buffer new-buffer)
      (loom/feature/window:window-set-buffer window new-buffer)
      (%save-buffer-or-warn-overwrite new-buffer path))))

(defun save-buffer ()
  "Save the selected buffer, prompting for a path first if it has none."
  (let* ((window (%selected-window))
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
buffer, like Emacs's C-x C-w visit behavior."
  (let* ((window (%selected-window))
         (buffer (loom/feature/window:window-buffer window)))
    (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                   :on-cancel (minibuffer-message minibuffer "Quit"))
        ((path "Write file: "))
      (let ((new-buffer (%make-file-buffer path
                                           :initial-content (buffer-text buffer))))
        (%transfer-point-and-mark buffer new-buffer)
        (%register-buffer new-buffer)
        (loom/feature/window:window-set-buffer window new-buffer)
        (%save-buffer-or-warn-overwrite new-buffer path)))))
