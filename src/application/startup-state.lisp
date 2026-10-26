(in-package #:loom)

(defun %startup-file-and-root (argument)
  "Return an existing or creatable startup file and its file-tree root.

An existing regular file opens in the selected window while its containing
directory becomes the file-tree root. A missing file is accepted below the
nearest existing parent directory, which becomes the file-tree root. A
directory (or no argument) retains the scratch buffer and is itself the root."
  (let* ((root (or argument "."))
         (resolved (probe-file root)))
    (labels ((nearest-existing-directory (directory missing-components)
               (let ((existing (probe-file directory)))
                 (if (and existing (host-kit:directory-pathname-p existing))
                     (values existing missing-components)
                     (let ((components (pathname-directory directory)))
                       (when (> (length components) 1)
                         (nearest-existing-directory
                          (make-pathname :directory (butlast components)
                                         :name nil
                                         :type nil
                                         :defaults directory)
                          (cons (car (last components))
                                missing-components)))))))
      (cond
        ((and argument (null resolved))
         (let* ((target-path
                  (merge-pathnames (pathname argument)
                                   *default-pathname-defaults*))
                (parent-path
                  (host-kit:pathname-directory-pathname target-path)))
           (multiple-value-bind (parent missing-components)
               (nearest-existing-directory parent-path nil)
             (if parent
                 (values
                  (make-pathname :directory
                                 (append (pathname-directory parent)
                                         missing-components)
                                 :name (pathname-name target-path)
                                 :type (pathname-type target-path)
                                 :version (pathname-version target-path)
                                 :defaults parent)
                  parent)
                 (error (quote cl-cli:cli-invalid-positional-value)
                        :message
                        (format nil "PATH does not exist: ~A" argument)
                        :name
                        "PATH"
                        :value
                        argument
                        :cause
                        nil)))))
        ((and resolved (not (host-kit:directory-pathname-p resolved)))
         (values resolved (make-pathname :name nil :type nil :defaults resolved)))
        (t (values nil root)))))))

(defun %make-startup-buffer (startup-file)
  "Build the initial buffer for STARTUP-FILE or the default scratch buffer.

New files use the files feature constructor to initialize save metadata."
  (if startup-file
      (if (probe-file startup-file)
          (buffer-load startup-file)
          (loom/feature/files::%make-file-buffer
           startup-file
           :name
           (file-namestring startup-file)))
      (make-buffer :name "*scratch*")))

(defun %make-startup-window-tree (initial-buffer width height)
  "Build the single-window layout for INITIAL-BUFFER."
  (loom/core/window-tree:make-window-tree initial-buffer
                                          width
                                          (max 1 (1- height))))

(defun %make-startup-editor-state (startup-file file-tree-root width height)
  "Construct the initial editor-state object for startup inputs."
  (let* ((initial-buffer (%make-startup-buffer startup-file))
         (window-tree (%make-startup-window-tree initial-buffer width height))
         (keymap (install-default-keybindings (make-keymap)))
         (minibuffer (make-minibuffer :history (history-kit:make-history)))
         (file-tree (loom/feature/file-tree:make-file-tree file-tree-root))
         (renderer (make-loom-renderer width height))
         (session
          (make-editor-session
           '(:core/window-tree :feature/buffers
                               :feature/workspace
                               :feature/keyboard-macro
                               :feature/search
                               :feature/project)
           :initial-slices
           (list (cons :core/window-tree window-tree)))))
    (loom/feature/buffers:register-buffer session initial-buffer)
    (loom/feature/file-tree:file-tree-install-child-lister file-tree
                                                           (function
                                                            loom/feature/file-tree:loom-fs-list-directory))
    (make-editor-state :session
                       session
                       :window-tree
                       window-tree
                       :minibuffer
                       minibuffer
                       :keymap
                       keymap
                       :file-tree
                       file-tree
                       :renderer
                       renderer
                       :kill-ring
                       nil
                       :registers
                       (loom/feature/register:make-register-bank)
                       :auto-save-mode-p
                       nil
                       :auto-save-buffers
                       nil
                       :auto-save-last-run-at
                       nil
                       :format-on-save-p
                       nil
                       :format-command
                       nil
                       :terminal-sessions
                       nil)))

(eval-when (:load-toplevel :execute)
  (loom/feature/files:register-recent-file-recorder :loom (function loom/feature/files:remember-recent-file)))

(eval-when (:load-toplevel :execute)
  (loom/feature/evaluation:register-evaluation-package-provider :loom
                                                                (lambda ()
                                                                  (find-package
                                                                   '#:loom-user)))
  (loom/feature/user-init:register-user-init-package-provider :loom
                                                              (lambda ()
                                                                (find-package
                                                                 '#:loom-user)))
  (loom/feature/syntax-highlighting:register-renderer-operation-provider :loom
                                                                         (lambda
                                                                             (renderer
                                                                              operation
                                                                              &rest
                                                                              arguments)
                                                                           (ecase operation
                                                                             (:clip-index
                                                                              (apply
                                                                               #'loom-renderer-clip-index
                                                                               renderer
                                                                               arguments))
                                                                             (:truncate-string
                                                                              (apply
                                                                               #'loom-renderer-truncate-string
                                                                               renderer
                                                                               arguments))
                                                                             (:string-width
                                                                              (apply
                                                                               #'loom-renderer-string-width
                                                                               renderer
                                                                               arguments))
                                                                             (:write-string
                                                                              (apply
                                                                               #'loom-renderer-write-string
                                                                               renderer
                                                                               arguments))))))

(eval-when (:load-toplevel :execute)
  (loom/feature/lsp:register-completion-popup-provider :loom
                                                       (function
                                                        make-editor-completion)))

(defun %initialize-editor-state (path-argument &optional additional-file-paths)
  "Build a fresh *EDITOR-STATE* around the startup files and supporting objects."
  (multiple-value-bind (width height) (%initial-terminal-size)
    (multiple-value-bind (startup-file file-tree-root)
        (%startup-file-and-root path-argument)
      (setf *editor-state* (%make-startup-editor-state startup-file
                                                       file-tree-root
                                                       width
                                                       height))
      (when startup-file
        (remember-recent-file startup-file))
      (let ((session (editor-state-session *editor-state*)))
        (dolist (path additional-file-paths)
          (multiple-value-bind (file root) (%startup-file-and-root path)
            (declare (ignore root))
            (unless file
              (error 'cl-cli:cli-invalid-positional-value
                     :message
                     (format nil
                             "Additional startup path must be a file: ~A"
                             path)
                     :name
                     "PATH"
                     :value
                     path
                     :cause
                     nil))
            (let ((path-string (editor-path-string file)))
              (unless
                  (some
                   (lambda (buffer)
                     (let ((buffer-file (buffer-path buffer)))
                       (and buffer-file
                            (equal path-string (editor-path-string buffer-file)))))
                   (loom/feature/buffers:registered-buffers session))
                (loom/feature/buffers:register-buffer session
                                                      (%make-startup-buffer file))
                (remember-recent-file file)))))))))
