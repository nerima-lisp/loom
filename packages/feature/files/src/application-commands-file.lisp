(in-package #:loom/feature/files)

(defun %file-buffer-name (path)
  "Return a unique display name for PATH among the session buffers."
  (let* ((filename (file-namestring path))
         (existing (loom/feature/buffers:find-buffer-by-name *editor-session* filename)))
    (if existing
        (let ((directory (or (car (last (pathname-directory path))) "root")))
          (loop for suffix from 1
                for name = (if (= suffix 1)
                               (format nil "~A<~A>" filename directory)
                               (format nil "~A<~A-~D>" filename directory suffix))
                unless (loom/feature/buffers:find-buffer-by-name *editor-session* name)
                  return name))
        filename)))

(defun %make-file-buffer (path &key name initial-content)
  "Create a buffer for PATH and infer its major mode from the path."
  (let ((buffer
         (make-buffer :name
                      (or name (%file-buffer-name path))
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

(defun %find-file-candidates (input)
  "Return path candidates from INPUT's existing parent directory."
  (let* ((separator (position #\/ input :from-end t))
         (directory-text (if separator (subseq input 0 (1+ separator)) ""))
         (directory (if (string= directory-text "")
                        #p"./"
                        (pathname directory-text)))
         (resolved-directory (probe-file directory))
         (entries nil))
    (when (and resolved-directory
               (host-kit:directory-pathname-p resolved-directory))
      (host-kit:call-with-directory-entries
       (lambda (child-path metadata)
         (let* ((kind (host-kit:file-metadata-kind metadata))
                (name (if (eq kind :directory)
                          (file-namestring child-path)
                          (file-namestring child-path))))
           (when (member kind '(:directory :regular-file))
             (push (cons (concatenate 'string
                                      directory-text
                                      name
                                      (if (eq kind :directory) "/" ""))
                         kind)
                   entries))))
       resolved-directory))
    (mapcar #'car
            (sort entries
                  (lambda (first second)
                    (or (and (eq (cdr first) :directory)
                             (eq (cdr second) :regular-file))
                        (and (eq (cdr first) (cdr second))
                             (string< (car first) (car second)))))))))
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
  (let ((buffer
         (or (find-buffer-by-path *editor-session* path)
             (%load-file-buffer path :name (%file-buffer-name path)))))
    (%show-buffer-in-selected-window buffer)
    (%record-recent-file path)
    buffer))

(defun visit-file (path)
  "Show the buffer for an existing PATH in the selected window.

The public form of what FIND-FILE does once it has a path, for callers that
already know which file to open -- a definition jump, for one -- and have no
prompt to run. Returns the buffer, or NIL when PATH does not exist."
  (let ((existing (probe-file path)))
    (when existing
      (%visit-existing-file existing))))

(defun find-file ()
  "Prompt for a path and show its buffer in the selected window.

Existing files are loaded from disk. A path that does not yet exist opens as
an empty buffer associated with that path, so a later save creates the file."
  (with-prompts
   (minibuffer (editor-state-minibuffer *editor-state*)
               :on-cancel
               (minibuffer-message minibuffer "Quit"))
   ((path "Find file: " :completion-function #'%find-file-candidates))
   (let* ((existing-path (probe-file path))
          (directory-p
            (and existing-path (host-kit:directory-pathname-p existing-path)))
          (existing-buffer
            (unless directory-p
              (find-buffer-by-path *editor-session* (or existing-path path)))))
     (cond
       (directory-p
        (minibuffer-message (editor-state-minibuffer *editor-state*)
                            (format nil "Cannot open directory: ~A" path)))
       (existing-buffer (%visit-existing-file (or existing-path path)))
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
