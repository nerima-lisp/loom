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
         (unless (string= (buffer-text buffer) "")
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

(defun %git-path-present-p (path)
  "Return true when PATH contains a non-whitespace character."
  (and (stringp path)
       (not (string= (string-trim '(#\Space #\Tab #\Newline #\Return)
                                  path)
                    ""))))

(defun %git-operation-labels (operation)
  (ecase operation
    (:stage (values "stage" "staged"))
    (:unstage (values "unstage" "unstaged"))))

(defun %run-git-file-operation (operation path directory)
  (ecase operation
    (:stage (run-git-stage path :directory directory))
    (:unstage (run-git-unstage path :directory directory))))

(defun %git-file-operation (operation path minibuffer)
  "Run OPERATION for PATH and report its result in MINIBUFFER."
  (let ((path (string-trim '(#\Space #\Tab #\Newline #\Return) path)))
    (if (%git-path-present-p path)
        (handler-case
            (multiple-value-bind (verb past-tense)
                (%git-operation-labels operation)
              (let ((result
                      (%run-git-file-operation
                       operation path (%git-status-directory))))
                (minibuffer-message
                 minibuffer
                 (if (vcs-kit:process-success-p result)
                     (format nil "Git ~A ~A" past-tense path)
                     (format nil "Git ~A exited with status ~D"
                             verb
                             (vcs-kit:process-result-exit-code result))))
                result))
          (error (condition)
            (multiple-value-bind (verb)
                (%git-operation-labels operation)
              (minibuffer-message
               minibuffer
               (format nil "Git ~A error: ~A" verb condition)))
            nil))
        (multiple-value-bind (verb)
            (%git-operation-labels operation)
          (minibuffer-message
           minibuffer
           (format nil "Git ~A cancelled" verb))))))
