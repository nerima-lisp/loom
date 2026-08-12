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
           when (or (zerop (length prefix))
                    (and (<= (length prefix) (length name))
                         (string-equal prefix name
                                       :end2 (length prefix))))
             collect name)
     #'string<)))

(defun %bookmark-target-buffer (bookmark)
  "Resolve BOOKMARK to a live buffer, loading its file when necessary."
  (let ((saved-buffer (editor-bookmark-buffer bookmark)))
    (or (and saved-buffer
             (find saved-buffer (%editor-buffers) :test #'eq))
        (let ((path (editor-bookmark-path bookmark)))
          (when path
            (let ((existing-path (probe-file path)))
              (when (and existing-path
                         (not (host-kit:directory-pathname-p existing-path)))
                (let ((buffer (buffer-load existing-path)))
                  (%register-buffer buffer)
                  (remember-recent-file existing-path)
                  buffer))))))))

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
