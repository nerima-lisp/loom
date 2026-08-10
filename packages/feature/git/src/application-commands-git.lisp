(in-package #:loom/feature/git)

(defparameter *git-status-buffer-name* "*Loom-Git-Status*")
(defparameter *git-diff-buffer-name* "*Loom-Git-Diff*")

(defun %git-status-directory ()
  (let* ((buffer (%selected-buffer))
         (path (and buffer (buffer-path buffer)))
         (start (or path (truename "."))))
    (or (project-find-root start)
        (project-directory-path start))))

(defun %git-result-buffer (name)
  (or (find name (%editor-buffers)
           :key #'buffer-name :test #'string=)
      (%register-buffer
       (make-buffer :name name))))

(defun %replace-git-result-buffer (buffer text)
  (unwind-protect
       (progn
         (buffer-set-read-only buffer nil)
         (unless (zerop (length (buffer-text buffer)))
           (let* ((end (buffer-offset-position
                        buffer
                        (length (buffer-text buffer))))
                  (end-line (buffer-position-line end))
                  (end-column (buffer-position-column end)))
             (buffer-delete-region buffer 0 0 end-line end-column)))
         (buffer-insert-string buffer text)
         (buffer-mark-saved buffer)
         buffer)
    (buffer-set-read-only buffer t)))

(defun git-status ()
  "Display concise Git status for the current project."
  (handler-case
      (let* ((directory (%git-status-directory))
             (result (run-git-status :directory directory))
             (buffer (%replace-git-result-buffer
                      (%git-result-buffer *git-status-buffer-name*)
                      (shell-command-result-text result))))
        (window-set-buffer (%selected-window) buffer)
        (minibuffer-message
         (editor-state-minibuffer *editor-state*)
         (if (shell-command-result-success-p result)
             "Git status refreshed"
             (format nil "Git status exited with status ~D"
                     (shell-command-result-exit-code result))))
        result)
    (error (condition)
      (minibuffer-message
       (editor-state-minibuffer *editor-state*)
       (format nil "Git status error: ~A" condition))
      nil)))

(defun %display-git-diff (staged)
  "Display the working-tree or staged diff in a read-only result buffer."
  (handler-case
      (let* ((directory (%git-status-directory))
             (result (run-git-diff :directory directory :staged staged))
             (buffer (%replace-git-result-buffer
                      (%git-result-buffer *git-diff-buffer-name*)
                      (shell-command-result-text result))))
        (window-set-buffer (%selected-window) buffer)
        (minibuffer-message
         (editor-state-minibuffer *editor-state*)
         (if (shell-command-result-success-p result)
             (if staged
                 "Git staged diff refreshed"
                 "Git diff refreshed")
             (format nil "Git diff exited with status ~D"
                     (shell-command-result-exit-code result))))
        result)
    (error (condition)
      (minibuffer-message
       (editor-state-minibuffer *editor-state*)
       (format nil "Git diff error: ~A" condition))
      nil)))

(defun git-diff ()
  "Display the current working-tree diff for the current project."
  (%display-git-diff nil))

(defun git-diff-staged ()
  "Display the staged index diff for the current project."
  (%display-git-diff t))

(defun %git-path-present-p (path)
  "Return true when PATH contains a non-whitespace character."
  (and (stringp path)
       (plusp (length (string-trim '(#\Space #\Tab #\Newline #\Return)
                                   path)))))

(defun %git-file-operation (operation path minibuffer)
  "Run OPERATION for PATH and report its result in MINIBUFFER."
  (let* ((path (string-trim '(#\Space #\Tab #\Newline #\Return) path))
         (verb (ecase operation
                 (:stage "stage")
                 (:unstage "unstage")))
         (past-tense (ecase operation
                       (:stage "staged")
                       (:unstage "unstaged"))))
    (if (not (%git-path-present-p path))
        (minibuffer-message minibuffer
                             (format nil "Git ~A cancelled" verb))
        (handler-case
            (let* ((directory (%git-status-directory))
                   (result (ecase operation
                             (:stage (run-git-stage path :directory directory))
                             (:unstage
                              (run-git-unstage path :directory directory)))))
              (minibuffer-message
               minibuffer
               (if (shell-command-result-success-p result)
                   (format nil "Git ~A ~A" past-tense path)
                   (format nil "Git ~A exited with status ~D"
                           verb
                           (shell-command-result-exit-code result))))
              result)
          (error (condition)
            (minibuffer-message
             minibuffer
             (format nil "Git ~A error: ~A" verb condition))
            nil)))))

(defun git-stage-file ()
  "Prompt for a repository path and stage it in Git's index."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((path "Git stage file: "))
    (%git-file-operation :stage path minibuffer)))

(defun git-unstage-file ()
  "Prompt for a repository path and remove it from Git's index."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((path "Git unstage file: "))
    (%git-file-operation :unstage path minibuffer)))
