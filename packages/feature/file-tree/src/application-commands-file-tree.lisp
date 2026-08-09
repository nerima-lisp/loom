;;;; packages/feature/file-tree/src/application-commands-file-tree.lisp
;;;;
;;;; Application layer: file-tree commands that compose the file-tree domain
;;;; with the editor state and minibuffer protocol.
(in-package #:loom/feature/file-tree)

(defun toggle-file-tree ()
  "Toggle whether the file-tree sidebar is shown."
  (file-tree-toggle (editor-state-file-tree *editor-state*)))

(defun %invalidate-file-tree-path (path)
  "Invalidate PATH and its parent in the running file-tree runtime."
  (let ((runtime (and *editor-state*
                      (editor-state-concurrent-runtime *editor-state*))))
    (when runtime
      (loom-concurrent-runtime-invalidate-path runtime path))))

(defun file-tree-select-next ()
  "Move the file-tree selection to the next visible entry."
  (file-tree-move-selection (editor-state-file-tree *editor-state*) :down))

(defun file-tree-select-previous ()
  "Move the file-tree selection to the previous visible entry."
  (file-tree-move-selection (editor-state-file-tree *editor-state*) :up))

(defun file-tree-open-selected ()
  "Open the selected entry as a buffer, or toggle it if it is a directory."
  (let* ((tree (editor-state-file-tree *editor-state*))
         (path (file-tree-selected-path tree)))
    (when path
      (case (file-tree-entry-kind tree path)
        (:directory (file-tree-toggle-expand tree path))
        (:file (let ((buffer (buffer-load path)))
                 (%register-buffer buffer)
                 (window-set-buffer (%selected-window) buffer)))
        (otherwise (error "selected file-tree entry disappeared: ~S" path))))))

(defun file-tree-create-file-command ()
  "Prompt for a path and create a new empty file there."
  (let ((tree (editor-state-file-tree *editor-state*)))
    (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                   :on-cancel (minibuffer-message minibuffer "Quit"))
        ((path "Create file: "))
      (file-tree-create-file tree path)
      (%invalidate-file-tree-path path))))

(defun file-tree-create-directory-command ()
  "Prompt for a path and create a new empty directory there."
  (let ((tree (editor-state-file-tree *editor-state*)))
    (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                   :on-cancel (minibuffer-message minibuffer "Quit"))
        ((path "Create directory: "))
      (file-tree-create-directory tree path)
      (%invalidate-file-tree-path path))))

(defun file-tree-rename-command ()
  "Prompt for a new path and rename the selected entry to it."
  (let* ((tree (editor-state-file-tree *editor-state*))
         (old-path (file-tree-selected-path tree)))
    (when old-path
      (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                     :on-cancel (minibuffer-message minibuffer "Quit"))
          ((new-path (format nil "Rename ~A to: " old-path)))
        (file-tree-rename tree old-path new-path)
        (%invalidate-file-tree-path old-path)
        (%invalidate-file-tree-path new-path)))))

;; No confirmation prompt: unlike create/rename, delete needs no typed input,
;; only a yes/no confirmation, and the minibuffer protocol as it stands
;; (application/minibuffer.lisp) only offers a free-text ON-CONFIRM/ON-CANCEL
;; prompt, not a dedicated y-or-n-p; a free-text "type anything to confirm"
;; prompt would not actually reduce accidental deletes over just deleting
;; directly, so this deletes the selection immediately.
(defun file-tree-delete-command ()
  "Delete the selected file-tree entry from disk."
  (let* ((tree (editor-state-file-tree *editor-state*))
         (path (file-tree-selected-path tree)))
    (when path
      (file-tree-delete tree path)
      (%invalidate-file-tree-path path))))
