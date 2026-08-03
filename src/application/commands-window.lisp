;;;; src/application/commands-window.lisp
;;;;
;;;; Application layer: window-management and file-tree sidebar commands (see
;;;; application/commands-internal.lisp for the shared command-authoring
;;;; convention every commands-*.lisp file follows).
(in-package #:loom)

(defun split-window-below ()
  "Split the selected window horizontally, stacking top/bottom (C-x 2)."
  (let ((tree (editor-state-window-tree *editor-state*)))
    (window-split tree (window-tree-selected-window tree) :horizontal)))

(defun split-window-right ()
  "Split the selected window vertically, placing panes side by side (C-x 3)."
  (let ((tree (editor-state-window-tree *editor-state*)))
    (window-split tree (window-tree-selected-window tree) :vertical)))

(defun other-window ()
  "Select the next window, cycling back to the first (C-x o)."
  (window-select-next (editor-state-window-tree *editor-state*)))

;; SWITCH-TO-BUFFER is a simplified stand-in: loom has no global buffer-list
;; registry anywhere in the domain/application layers yet (EDITOR-STATE has
;; no such slot -- see application/editor-state.lisp), so rather than
;; building one just for this command, this looks the typed name up among
;; the buffers currently displayed in some window of the window tree, which
;; is the only buffer collection that exists today.
(defun switch-to-buffer ()
  "Prompt for a buffer name and display it in the selected window."
  (minibuffer-activate
   (editor-state-minibuffer *editor-state*)
   "Switch to buffer: "
   :on-confirm
   (lambda (name)
     (let* ((tree (editor-state-window-tree *editor-state*))
            (match (find name (window-tree-windows tree)
                         :key (lambda (window) (buffer-name (window-buffer window)))
                         :test #'string=)))
       (if match
           (window-set-buffer (window-tree-selected-window tree) (window-buffer match))
           (minibuffer-message (editor-state-minibuffer *editor-state*)
                                (format nil "No such buffer: ~A" name)))))))

(defun toggle-file-tree ()
  "Toggle whether the file-tree sidebar is shown."
  (file-tree-toggle (editor-state-file-tree *editor-state*)))

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
      ;; domain/file-tree.lisp exposes no public "what kind of entry is
      ;; this" query (only the internal %FILE-TREE-FIND-KIND helper does,
      ;; and reaching into a %-prefixed domain helper from the application
      ;; layer would cross the same layering line FILE-TREE-TOGGLE-EXPAND
      ;; itself is written to respect). FILE-TREE-TOGGLE-EXPAND's own
      ;; documented contract signals an error for a non-directory PATH, so
      ;; that error is used here as the directory/file discriminator.
      (handler-case (file-tree-toggle-expand tree path)
        (error ()
          (window-set-buffer (%selected-window) (buffer-load path)))))))

(defun file-tree-create-file-command ()
  "Prompt for a path and create a new empty file there."
  (let ((tree (editor-state-file-tree *editor-state*)))
    (minibuffer-activate
     (editor-state-minibuffer *editor-state*)
     "Create file: "
     :on-confirm (lambda (path) (file-tree-create-file tree path)))))

(defun file-tree-create-directory-command ()
  "Prompt for a path and create a new empty directory there."
  (let ((tree (editor-state-file-tree *editor-state*)))
    (minibuffer-activate
     (editor-state-minibuffer *editor-state*)
     "Create directory: "
     :on-confirm (lambda (path) (file-tree-create-directory tree path)))))

(defun file-tree-rename-command ()
  "Prompt for a new path and rename the selected entry to it."
  (let* ((tree (editor-state-file-tree *editor-state*))
         (old-path (file-tree-selected-path tree)))
    (when old-path
      (minibuffer-activate
       (editor-state-minibuffer *editor-state*)
       (format nil "Rename ~A to: " old-path)
       :on-confirm (lambda (new-path) (file-tree-rename tree old-path new-path))))))

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
      (file-tree-delete tree path))))
