;;;; packages/feature/window/src/application-commands-window.lisp
;;;;
;;;; Application layer: window-management and file-tree sidebar commands (see
;;;; application/commands-internal.lisp for the shared command-authoring
;;;; convention every commands-*.lisp file follows).
(in-package #:loom/feature/window)

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
