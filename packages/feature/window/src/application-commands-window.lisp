;;;; packages/feature/window/src/application-commands-window.lisp
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

(defun delete-window ()
  "Delete the selected window, keeping at least one window (C-x 0)."
  (let ((tree (editor-state-window-tree *editor-state*)))
    (window-delete tree (window-tree-selected-window tree))))

(defun delete-other-windows ()
  "Delete every window except the selected one (C-x 1)."
  (let ((tree (editor-state-window-tree *editor-state*)))
    (window-delete-other-windows tree (window-tree-selected-window tree))))

;; SWITCH-TO-BUFFER searches EDITOR-STATE's session-wide registry, so buffers
;; opened through FIND-FILE or the file-tree remain available after they leave
;; a window. The selected window changes only after a matching name is found.
(defun %buffer-name-completion-candidates (input)
  "Return all registered buffer names as candidates for INPUT."
  (declare (ignore input))
  (mapcar #'buffer-name (%editor-buffers)))

(defun switch-to-buffer ()
  "Prompt for a buffer name and display it in the selected window."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((name "Switch to buffer: "
             :completion-function #'%buffer-name-completion-candidates))
    (let* ((tree (editor-state-window-tree *editor-state*))
           (match (find name (%editor-buffers)
                        :key #'buffer-name
                        :test #'string=)))
      (if match
          (window-set-buffer (window-tree-selected-window tree) match)
          (minibuffer-message minibuffer (format nil "No such buffer: ~A" name))))))

(defun %replace-buffer-in-windows (buffer replacement)
  "Replace BUFFER with REPLACEMENT in every window that displays it."
  (dolist (window (window-tree-windows (editor-state-window-tree *editor-state*))
                  replacement)
    (when (eq (window-buffer window) buffer)
      (window-set-buffer window replacement))))

(defun %kill-buffer-now (buffer)
  "Remove BUFFER and preserve the window and registry invariants."
  (let* ((survivors (remove buffer (%editor-buffers) :test #'eq))
         (replacement (or (first survivors)
                          (make-buffer :name "*scratch*"))))
    (unless survivors
      (%register-buffer replacement))
    (%replace-buffer-in-windows buffer replacement)
    (%unregister-buffer buffer)
    (minibuffer-message (editor-state-minibuffer *editor-state*)
                         (format nil "Killed ~A" (buffer-name buffer)))))

(defun %prompt-kill-buffer (minibuffer buffer)
  "Ask how to handle modified BUFFER before killing it."
  (let ((has-path-p (not (null (buffer-path buffer)))))
    (labels ((prompt ()
               (minibuffer-activate
                minibuffer
                (if has-path-p
                    (format nil "Save ~A? (s/d/c): " (buffer-name buffer))
                    (format nil "Discard changes to ~A? (d/c): "
                            (buffer-name buffer)))
                :on-confirm
                (lambda (answer)
                  (cond
                    ((and has-path-p (string-equal answer "s"))
                     (buffer-save buffer)
                     (%kill-buffer-now buffer))
                    ((string-equal answer "d")
                     (%kill-buffer-now buffer))
                    ((string-equal answer "c")
                     nil)
                    (t
                     (prompt))))
                :on-cancel
                (lambda ()
                  (minibuffer-message minibuffer "Quit")))))
      (prompt))))

(defun kill-buffer ()
  "Prompt for a buffer name and remove it from the session registry."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                     :on-cancel (minibuffer-message minibuffer "Quit"))
      ((name "Kill buffer: "
             :completion-function #'%buffer-name-completion-candidates))
    (let ((buffer (find name (%editor-buffers)
                        :key #'buffer-name
                        :test #'string=)))
      (cond
        ((null buffer)
         (minibuffer-message minibuffer
                              (format nil "No such buffer: ~A" name)))
        ((buffer-modified-p buffer)
         (%prompt-kill-buffer minibuffer buffer))
        (t
         (%kill-buffer-now buffer))))))

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
