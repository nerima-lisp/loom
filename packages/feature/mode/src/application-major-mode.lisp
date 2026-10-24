(in-package #:loom/feature/mode)

(defun major-mode-keymap (mode fallback)
  "Return MODE's local keymap layered over FALLBACK.

FALLBACK is normally the editor's user/global keymap.  The returned object is
cached while the mode registry and fallback object remain unchanged, so global
bindings added after mode activation are still visible through the parent.
"
  (let ((key (or (major-mode-from-name mode) :fundamental)))
    (or (gethash (list *major-mode-registry-version* key fallback)
                 *major-mode-keymap-cache*)
        (setf (gethash (list *major-mode-registry-version* key fallback)
                       *major-mode-keymap-cache*)
              (%build-major-mode-keymap key fallback nil)))))

(defun %major-mode-keymap-provider (session buffer fallback-keymap)
  (declare (ignore session))
  (major-mode-keymap (buffer-major-mode buffer) fallback-keymap))

(eval-when (:load-toplevel :execute)
  (register-buffer-keymap-provider
   :feature/mode
   (function %major-mode-keymap-provider)))

(defun current-major-mode ()
  "Return the selected buffer's major mode, defaulting to FUNDAMENTAL."
  (if (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))
      (buffer-major-mode (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))))
      :fundamental))

(defun set-major-mode ()
  "Prompt for and apply a major mode to the selected buffer."
  (with-prompts
      (minibuffer (editor-state-minibuffer
                                    *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((input "Major mode: "
               :completion-function #'%major-mode-completion-candidates))
    (let ((mode (major-mode-from-name input)))
      (if (and mode (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))))
          (progn
            (buffer-set-major-mode
             (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))
             mode)
            (minibuffer-message minibuffer
                                (format nil "Mode: ~A" (major-mode-name mode))))
          (minibuffer-message minibuffer
                              (format nil "Unknown major mode: ~A" input))))))
