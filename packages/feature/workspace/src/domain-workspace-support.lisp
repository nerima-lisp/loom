;;;; packages/feature/workspace/src/domain-workspace-support.lisp
;;;;
;;;; Internal workspace structures and validation helpers shared by the public
;;;; workspace domain API.
(in-package #:loom/feature/workspace)

(defstruct (workspace
            (:constructor make-workspace (&key name window-tree)))
  "One named editor view over a WINDOW-TREE."
  name
  window-tree)

(defstruct (workspace-manager
            (:constructor %make-workspace-manager))
  "Ordered workspaces and the index of the active one."
  workspaces
  current-index)

(defun %workspace-name-valid-p (name)
  (and (stringp name)
       (plusp (length (string-trim '(#\Space #\Tab #\Newline #\Return)
                                   name)))))

(defun %workspace-index-valid-p (workspaces index)
  (and (integerp index)
       (<= 0 index)
       (< index (length workspaces))))

(defun %workspace-name-conflict-p (workspaces name)
  (find name workspaces :key #'workspace-name :test #'string-equal))

(defun %validate-workspace (workspace)
  (unless (and (typep workspace 'workspace)
               (%workspace-name-valid-p (workspace-name workspace)))
    (error "Invalid workspace: ~S" workspace))
  workspace)

(defun %validate-workspaces (workspaces current-index)
  (unless (and (listp workspaces) (plusp (length workspaces)))
    (error "A workspace manager needs one or more workspaces"))
  (dolist (workspace workspaces)
    (%validate-workspace workspace))
  (let ((names (mapcar #'workspace-name workspaces)))
    (unless (= (length names)
               (length (remove-duplicates names :test #'string-equal)))
      (error "Workspace names must be unique: ~S" names)))
  (unless (%workspace-index-valid-p workspaces current-index)
    (error "Workspace index is out of range: ~S" current-index))
  workspaces)

(defun %workspace-generated-name (manager)
  (loop for number from 2
        for candidate = (format nil "workspace-~D" number)
        unless (%workspace-name-conflict-p
                (workspace-manager-workspaces manager)
                candidate)
          do (return candidate)))
