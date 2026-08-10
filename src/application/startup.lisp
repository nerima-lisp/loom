;;;; src/application/startup.lisp
;;;;
;;;; Startup is the composition root for the executable. It translates CLI
;;;; input into the initial editor state, installs infrastructure services,
;;;; owns the terminal-session boundary, and shuts down asynchronous
;;;; resources. The executable entry point itself remains in main.lisp.
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

(defun %initialize-editor-state (path-argument)
  "Build a fresh *EDITOR-STATE* around the startup buffer and supporting
objects. PATH-ARGUMENT is the file or directory CL-CLI:POSITIONAL-VALUE
parsed from argv, or NIL when none was given."
  (multiple-value-bind (width height) (%initial-terminal-size)
    (multiple-value-bind (startup-file file-tree-root)
        (%startup-file-and-root path-argument)
      (let* ((initial-buffer (if startup-file
                                 (buffer-load startup-file)
                                 (make-buffer :name "*scratch*")))
             (window-tree (loom/feature/window:make-window-tree
                           initial-buffer width (max 1 (1- height))))
             (keymap (install-default-keybindings (make-keymap)))
             (minibuffer (make-minibuffer :history (history-kit:make-history)))
             (file-tree (loom/feature/file-tree:make-file-tree file-tree-root))
             (renderer (make-loom-renderer width height)))
        (loom/feature/file-tree:file-tree-install-child-lister
         file-tree
         (function loom/feature/file-tree:loom-fs-list-directory))
        (setf *editor-state*
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
                                 :before-save-hooks
                                 (list #'loom/feature/format:format-before-save)
                                 :after-save-hooks
                                 (list #'loom/feature/auto-save:delete-auto-save-file)
                                 :terminal-sessions nil))
        (when startup-file
          (remember-recent-file startup-file))))))

(defun %enable-concurrent-file-tree (state)
  "Replace STATE's synchronous file-tree lister with a cached runtime."
  (let* ((tree (editor-state-file-tree state))
         (lister (loom/feature/file-tree:file-tree-child-lister tree))
         (root (first (loom/feature/file-tree:file-tree-prefetch-paths tree)))
         (initial-entries (funcall lister root))
         (runtime (loom/feature/file-tree:make-loom-concurrent-runtime
                   :directory-lister lister)))
    (loom/feature/file-tree:loom-concurrent-runtime-prime-directory
     runtime root initial-entries)
    (loom/feature/file-tree:file-tree-install-child-lister
     tree
     (lambda (path)
       (multiple-value-bind (entries present-p)
           (loom/feature/file-tree:loom-concurrent-runtime-directory-entries
            runtime path)
         (if present-p entries nil))))
    (setf (editor-state-concurrent-runtime state) runtime)
    runtime))

(defun %loom-version ()
  "Return LOOM's version string from its own ASDF system definition -- the
single source of truth loom.asd's header comment and flake.nix's ASDVERSIONOF
both already rely on -- so CL-CLI's generated --version output cannot drift
from it."
  (let ((system (asdf:find-system "loom" nil)))
    (or (and system (asdf:component-version system)) "unknown")))

(defun %run-loom (invocation &key (fd 0))
  "CL-CLI handler for *LOOM-APP*: initialize *EDITOR-STATE* around the :PATH
positional, then run the terminal session event loop (see %RUN-EVENT-LOOP)
until the user quits or stdin hits EOF. FD names the controlling terminal's
file descriptor (0, i.e. stdin, in production; overridable so a test can
pass a real CL-TTY-KIT:MAKE-PTY descriptor instead).

CL-TTY-KIT:WITH-TERMINAL-SESSION already wraps its body in an UNWIND-PROTECT
(nested inside WITH-RAW-MODE's own UNWIND-PROTECT) that restores raw mode and
exits the alternate screen on any non-local exit, so an unhandled error inside
the loop still leaves the terminal in a clean state before this function's
own HANDLER-CASE gets a chance to report it -- the terminal is never left in
raw/alternate-screen mode, whether the error is caught here or not."
  (%initialize-editor-state (cl-cli:positional-value invocation :path))
  (%enable-concurrent-file-tree *editor-state*)
  (unwind-protect
       (handler-case
           (progn
             (loom/feature/user-init:load-user-init)
             (cl-tty-kit:with-terminal-session (stream :fd fd
                                                :raw-mode t
                                                :alternate-screen t
                                                :hide-cursor nil)
               (%run-event-loop stream))
             0)
         (error (condition)
           (format *error-output* "~&loom: ~A~%" condition)
           1))
    (let ((runtime (editor-state-concurrent-runtime *editor-state*)))
      (when runtime
        (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime)))
    (let ((session (editor-state-lsp-session *editor-state*)))
      (when session
        (loom/feature/lsp:lsp-session-stop session)))))

(defparameter *loom-app*
  (cl-cli:make-app
   :name "loom"
   :version (%loom-version)
   :summary "Terminal text editor with Emacs-like keybindings"
   :positionals (list (cl-cli:make-positional
                       :key :path
                       :required-p nil
                       :description "A file to open, or a directory to browse (defaults to \".\")"))
   :handler (function %run-loom))
  "CL-CLI application spec for the loom binary: a single positional path
argument and no subcommands (the \"root positional\" shape CL-CLI's own
getting-started guide documents for script-style tools), which gets
--help/--version/-h/-V for free instead of main.lisp hand-parsing argv.")
