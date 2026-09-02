;;;; src/application/commands-bookmark-support.lisp
;;;;
;;;; Application layer: bookmark state, lookup helpers, and prompt wrappers.
(in-package #:loom)

(defun %bookmark-table ()
  "Return the current session's named bookmark table, creating it on demand."
  (or (editor-state-bookmarks *editor-state*)
      (setf (editor-state-bookmarks *editor-state*)
            (make-hash-table :test #'equal))))

(defun %bookmark-name (input)
  "Normalize a minibuffer bookmark name without changing its case."
  (string-trim '(#\Space #\Tab) input))

(defun %bookmark-candidates (input)
  "Return bookmark names matching the typed INPUT prefix."
  (let ((prefix (%bookmark-name input)))
    (sort
     (loop for name being the hash-keys of (%bookmark-table)
           when (or (string= prefix "")
                    (and (<= (length prefix) (length name))
                         (string-equal prefix name
                                       :end2 (length prefix))))
             collect name)
     #'string<)))

(defun %live-bookmark-buffer (bookmark)
  "Return BOOKMARK's saved buffer when it is still registered."
  (let ((saved-buffer (editor-bookmark-buffer bookmark)))
    (and saved-buffer
         (find saved-buffer (%editor-buffers) :test #'eq))))

(defun %bookmark-regular-file (path)
  "Return PATH when it names an existing regular file."
  (let ((existing-path (and path (probe-file path))))
    (and existing-path
         (not (host-kit:directory-pathname-p existing-path))
         existing-path)))

(defun %register-bookmark-buffer (path)
  "Load and register the bookmark buffer for PATH."
  (let ((buffer (buffer-load path)))
    (%register-buffer buffer)
    (remember-recent-file path)
    buffer))

(defun %load-bookmark-file (path)
  "Load PATH as a bookmark target when it names an existing regular file."
  (let ((regular-file (%bookmark-regular-file path)))
    (when regular-file
      (%register-bookmark-buffer regular-file))))

(defun %bookmark-target-buffer (bookmark)
  "Resolve BOOKMARK to a live buffer, loading its file when necessary."
  (or (%live-bookmark-buffer bookmark)
      (%load-bookmark-file (editor-bookmark-path bookmark))))

(defmacro define-bookmark-command
    (name (prompt &key completion-function) (bookmark-name minibuffer) &body body)
  "Define a bookmark command that prompts for a normalized bookmark name."
  (let ((raw-name (gensym "RAW-NAME-")))
    `(defun ,name ()
       ,(ecase name
          (set-bookmark
           "Prompt for a name and save the selected buffer position under it.")
          (jump-to-bookmark
           "Prompt for a bookmark name and select its saved buffer position.")
          (delete-bookmark
           "Prompt for a bookmark name and remove it from the current session."))
       (with-prompts (,minibuffer (editor-state-minibuffer *editor-state*)
                      :on-cancel (minibuffer-message ,minibuffer "Quit"))
           ((,raw-name ,prompt
             ,@(when completion-function
                 `(:completion-function ,completion-function))))
         (let ((,bookmark-name (%bookmark-name ,raw-name)))
           ,@body)))))
