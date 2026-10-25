(in-package #:loom/feature/files)

(defun %make-file-buffer (path &key name initial-content)
  "Create a buffer for PATH and infer its major mode from the path."
  (let ((buffer
         (make-buffer :name
                      (or name (file-namestring path))
                      :path
                      path
                      :initial-content
                      initial-content)))
    (buffer-set-major-mode buffer (loom/feature/mode:major-mode-for-path path))
    buffer))

(defvar *recent-file-recorder*
  nil)

(defun register-recent-file-recorder (owner function)
  "Register OWNER's callback for recording paths visited or written by this
feature.

FUNCTION receives a path. Registering again as OWNER replaces its callback; a
different owner is rejected."
  (unless (functionp function)
    (error "Recent-file recorder must be a function"))
  (when
      (and *recent-file-recorder*
           (not (equal (car *recent-file-recorder*) owner)))
    (error "Recent-file recorder is already registered by ~S"
           (car *recent-file-recorder*)))
  (setf *recent-file-recorder* (cons owner function))
  function)

(defun %record-recent-file (path)
  (unless *recent-file-recorder*
    (error "Recent-file recorder is not registered"))
  (funcall (cdr *recent-file-recorder*) path))

(defun %recent-file-candidates (input)
  "Return recent file paths suitable for minibuffer completion."
  (declare (ignore input))
  (copy-list (editor-state-recent-files *editor-state*)))

(defun %show-buffer-in-selected-window (buffer)
  "Register BUFFER and display it in the selected window."
  (register-buffer *editor-session* buffer)
  (loom/core/window-tree:window-set-buffer
   (loom/core/window-tree:window-tree-selected-window
    (editor-state-window-tree *editor-state*))
   buffer))

(defun %visit-existing-file (path)
  "Load PATH, display it in the selected window, and refresh recency."
  (%show-buffer-in-selected-window (buffer-load path))
  (%record-recent-file path))

(defun visit-file (path)
  "Show the buffer for an existing PATH in the selected window.

The public form of what FIND-FILE does once it has a path, for callers that
already know which file to open -- a definition jump, for one -- and have no
prompt to run. Returns the buffer, or NIL when PATH does not exist."
  (let ((existing (probe-file path)))
    (when existing
      (%visit-existing-file existing)
      (loom/core/window-tree:window-buffer
       (loom/core/window-tree:window-tree-selected-window
        (editor-state-window-tree *editor-state*))))))

(defun find-file ()
  "Prompt for a path and show its buffer in the selected window.

Existing files are loaded from disk. A path that does not yet exist opens as
an empty buffer associated with that path, so a later save creates the file."
  (with-prompts
   (minibuffer (editor-state-minibuffer *editor-state*)
               :on-cancel
               (minibuffer-message minibuffer "Quit"))
   ((path "Find file: "))
   (let ((existing-path (probe-file path)))
     (cond
       ((and existing-path (host-kit:directory-pathname-p existing-path))
        (minibuffer-message (editor-state-minibuffer *editor-state*)
                            (format nil "Cannot open directory: ~A" path)))
       (existing-path (%visit-existing-file existing-path))
       (t (%show-buffer-in-selected-window (%make-file-buffer path)))))))

(defun recent-file ()
  "Prompt from the recent-file list and visit the selected path."
  (with-prompts
   (minibuffer (editor-state-minibuffer *editor-state*)
               :on-cancel
               (minibuffer-message minibuffer "Quit"))
   ((path "Recent file: " :completion-function #'%recent-file-candidates))
   (let ((existing-path (probe-file path)))
     (if (and existing-path (not (host-kit:directory-pathname-p existing-path)))
         (%visit-existing-file existing-path)
         (minibuffer-message (editor-state-minibuffer *editor-state*)
                             (format nil "Recent file is unavailable: ~A" path))))))
