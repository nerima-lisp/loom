;;;; packages/feature/file-tree/src/application-commands-file.lisp
;;;;
;;;; Application layer: file-open/recent commands (see
;;;; application/commands-internal.lisp for the shared command-authoring
;;;; convention every commands-*.lisp file follows).
(in-package #:loom/feature/file-tree)

(defun %make-file-buffer (path &key name initial-content)
  "Create a buffer for PATH and infer its major mode from the path."
  (let ((buffer (make-buffer :name (or name (file-namestring path))
                             :path path
                             :initial-content initial-content)))
    (buffer-set-major-mode buffer
                           (loom/feature/mode:major-mode-for-path path))
    buffer))

(defun %recent-file-candidates (input)
  "Return recent file paths suitable for minibuffer completion."
  (declare (ignore input))
  (copy-list (editor-state-recent-files *editor-state*)))

(defun %show-buffer-in-selected-window (buffer)
  "Register BUFFER and display it in the selected window."
  (%register-buffer buffer)
  (loom/feature/window:window-set-buffer (%selected-window) buffer))

(defun %visit-existing-file (path)
  "Load PATH, display it in the selected window, and refresh recency."
  (%show-buffer-in-selected-window (buffer-load path))
  (remember-recent-file path))

(defun visit-file (path)
  "Show the buffer for an existing PATH in the selected window.

The public form of what FIND-FILE does once it has a path, for callers that
already know which file to open -- a definition jump, for one -- and have no
prompt to run. Returns the buffer, or NIL when PATH does not exist."
  (let ((existing (probe-file path)))
    (when existing
      (%visit-existing-file existing)
      (%selected-buffer))))

(defun find-file ()
  "Prompt for a path and show its buffer in the selected window.

Existing files are loaded from disk. A path that does not yet exist opens as
an empty buffer associated with that path, so a later save creates the file."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((path "Find file: "))
    (let ((existing-path (probe-file path)))
      (when (and existing-path
                 (host-kit:directory-pathname-p existing-path))
        (return-from find-file
          (minibuffer-message
           (editor-state-minibuffer *editor-state*)
           (format nil "Cannot open directory: ~A" path))))
      (if existing-path
          (%visit-existing-file existing-path)
          (%show-buffer-in-selected-window (%make-file-buffer path))))))

(defun recent-file ()
  "Prompt from the recent-file list and visit the selected path."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((path "Recent file: " :completion-function #'%recent-file-candidates))
    (let ((existing-path (probe-file path)))
      (if (and existing-path
               (not (host-kit:directory-pathname-p existing-path)))
          (%visit-existing-file existing-path)
          (minibuffer-message
           (editor-state-minibuffer *editor-state*)
           (format nil "Recent file is unavailable: ~A" path))))))
