;;;; packages/feature/window/src/application-window-buffer-support.lisp
;;;;
;;;; Application layer: buffer-switching and buffer-kill helpers for window
;;;; commands.
(in-package #:loom/feature/window)

;; SWITCH-TO-BUFFER searches EDITOR-STATE's session-wide registry, so buffers
;; opened through FIND-FILE or the file-tree remain available after they leave
;; a window. The selected window changes only after a matching name is found.
(defun %buffer-name-completion-candidates (input)
  "Return all registered buffer names as candidates for INPUT."
  (declare (ignore input))
  (mapcar #'buffer-name (%editor-buffers)))

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

(defun %kill-buffer-prompt-text (buffer)
  "Return the confirmation prompt for modified BUFFER."
  (if (buffer-path buffer)
      (format nil "Save ~A? (s/d/c): " (buffer-name buffer))
      (format nil "Discard changes to ~A? (d/c): " (buffer-name buffer))))

(defun %prompt-kill-buffer (minibuffer buffer)
  "Ask how to handle modified BUFFER before killing it."
  (let ((has-path-p (not (null (buffer-path buffer)))))
    (minibuffer-activate
     minibuffer
     (%kill-buffer-prompt-text buffer)
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
          (%prompt-kill-buffer minibuffer buffer))))
     :on-cancel
     (lambda ()
       (minibuffer-message minibuffer "Quit")))))
