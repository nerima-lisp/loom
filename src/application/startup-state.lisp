;;;; src/application/startup-state.lisp
;;;;
;;;; Startup-state assembly: path resolution, initial buffer selection, and
;;;; the first *EDITOR-STATE* shape before async services are attached.
(in-package #:loom)

(defun %startup-file-and-root (argument)
  "Return the existing startup file, if ARGUMENT names one, and the file-tree root.

An existing regular file opens in the selected window while its containing
directory becomes the file-tree root. A directory (or no argument) retains
the scratch buffer and is itself the root."
  (let* ((root (or argument "."))
         (resolved (probe-file root)))
    (cond
      ((and argument (null resolved))
       (error 'cl-cli:cli-invalid-positional-value
              :message (format nil "PATH does not exist: ~A" argument)
              :name "PATH"
              :value argument
              :cause nil))
      ((and resolved (not (host-kit:directory-pathname-p resolved)))
       (values resolved (make-pathname :name nil :type nil :defaults resolved)))
      (t
       (values nil root)))))

(defun %make-startup-buffer (startup-file)
  "Build the initial buffer for STARTUP-FILE, or the default scratch buffer."
  (if startup-file
      (buffer-load startup-file)
      (make-buffer :name "*scratch*")))

(defun %make-startup-window-tree (initial-buffer width height)
  "Build the single-window layout for INITIAL-BUFFER."
  (loom/feature/window:make-window-tree initial-buffer width (max 1 (1- height))))

(defun %make-startup-hooks ()
  "Return the editor-state save hook lists used at startup."
  (values (list #'loom/feature/format:format-before-save)
          (list #'loom/feature/auto-save:delete-auto-save-file)))

(defun %make-startup-editor-state (startup-file file-tree-root width height)
  "Construct the initial editor-state object for startup inputs."
  (let* ((initial-buffer (%make-startup-buffer startup-file))
         (window-tree (%make-startup-window-tree initial-buffer width height))
         (keymap (install-default-keybindings (make-keymap)))
         (minibuffer (make-minibuffer :history (history-kit:make-history)))
         (file-tree (loom/feature/file-tree:make-file-tree file-tree-root))
         (renderer (make-loom-renderer width height)))
    (multiple-value-bind (before-save-hooks after-save-hooks)
        (%make-startup-hooks)
      (loom/feature/file-tree:file-tree-install-child-lister
       file-tree
       (function loom/feature/file-tree:loom-fs-list-directory))
      (make-editor-state :window-tree window-tree
                         :workspaces
                         (loom/feature/workspace:make-workspace-manager
                          window-tree :name "main")
                         :minibuffer minibuffer
                         :keymap keymap
                         :file-tree file-tree
                         :renderer renderer
                         :buffers (list initial-buffer)
                         :kill-ring nil
                         :registers (loom/feature/register:make-register-bank)
                         :keyboard-macro
                         (loom/feature/keyboard-macro:make-keyboard-macro)
                         :auto-save-mode-p nil
                         :auto-save-buffers nil
                         :auto-save-last-run-at nil
                         :format-on-save-p nil
                         :format-command nil
                         :before-save-hooks before-save-hooks
                         :after-save-hooks after-save-hooks
                         :terminal-sessions nil))))

(defun %initialize-editor-state (path-argument)
  "Build a fresh *EDITOR-STATE* around the startup buffer and supporting
objects. PATH-ARGUMENT is the file or directory CL-CLI:POSITIONAL-VALUE
parsed from argv, or NIL when none was given."
  (multiple-value-bind (width height) (%initial-terminal-size)
    (multiple-value-bind (startup-file file-tree-root)
        (%startup-file-and-root path-argument)
      (setf *editor-state*
            (%make-startup-editor-state startup-file file-tree-root width height))
      (when startup-file
        (remember-recent-file startup-file)))))
