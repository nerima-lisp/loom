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

(defmacro %define-file-tree-selection-command (name docstring direction)
  "Define NAME as a zero-argument file-tree selection command."
  `(defun ,name ()
     ,docstring
     (file-tree-move-selection (editor-state-file-tree *editor-state*) ,direction)))

(defmacro %define-file-tree-prompted-mutation-command
    (name docstring prompt mutation-operator)
  "Define NAME as a prompted file-tree mutation command for PROMPT."
  (let ((tree-var (gensym "TREE-")))
    `(defun ,name ()
     ,docstring
     (let ((,tree-var (editor-state-file-tree *editor-state*)))
       (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                      :on-cancel (minibuffer-message minibuffer "Quit"))
           ((path ,prompt))
         (,mutation-operator ,tree-var path)
         (%invalidate-file-tree-path path))))))

(defmacro %define-file-tree-selected-path-command
    (name docstring path-binding &body body)
  "Define NAME as a zero-argument file-tree command over the selected path."
  (let ((tree-var (gensym "TREE-")))
    `(defun ,name ()
     ,docstring
     (let* ((,tree-var (editor-state-file-tree *editor-state*))
            (,path-binding (file-tree-selected-path ,tree-var)))
       (when ,path-binding
           (symbol-macrolet ((tree ,tree-var))
           ,@body))))))

(%define-file-tree-selection-command
 file-tree-select-next
 "Move the file-tree selection to the next visible entry."
 :down)

(%define-file-tree-selection-command
 file-tree-select-previous
 "Move the file-tree selection to the previous visible entry."
 :up)

(defun file-tree-open-selected ()
  "Open the selected entry as a buffer, or toggle it if it is a directory."
  (let* ((tree (editor-state-file-tree *editor-state*))
         (path (file-tree-selected-path tree)))
    (when path
      (case (file-tree-entry-kind tree path)
        (:directory (file-tree-toggle-expand tree path))
        (:file (%visit-existing-file path))
        (otherwise (error "selected file-tree entry disappeared: ~S" path))))))

(%define-file-tree-prompted-mutation-command
 file-tree-create-file-command
 "Prompt for a path and create a new empty file there."
 "Create file: "
 file-tree-create-file)

(%define-file-tree-prompted-mutation-command
 file-tree-create-directory-command
 "Prompt for a path and create a new empty directory there."
 "Create directory: "
 file-tree-create-directory)

(%define-file-tree-selected-path-command
 file-tree-rename-command
 "Prompt for a new path and rename the selected entry to it."
 old-path
 (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                :on-cancel (minibuffer-message minibuffer "Quit"))
     ((new-path (format nil "Rename ~A to: " old-path)))
   (file-tree-rename tree old-path new-path)
   (%invalidate-file-tree-path old-path)
   (%invalidate-file-tree-path new-path)))

;; No confirmation prompt: unlike create/rename, delete needs no typed input,
;; only a yes/no confirmation, and the minibuffer protocol as it stands
;; (application/minibuffer.lisp) only offers a free-text ON-CONFIRM/ON-CANCEL
;; prompt, not a dedicated y-or-n-p; a free-text "type anything to confirm"
;; prompt would not actually reduce accidental deletes over just deleting
;; directly, so this deletes the selection immediately.
(%define-file-tree-selected-path-command
 file-tree-delete-command
 "Delete the selected file-tree entry from disk."
 path
 (file-tree-delete tree path)
 (%invalidate-file-tree-path path))
