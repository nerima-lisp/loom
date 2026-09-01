;;;; src/application/startup-cli.lisp
;;;;
;;;; Declarative command-line application data. Runtime startup orchestration
;;;; remains in startup.lisp so the executable boundary is easy to inspect.
(in-package #:loom)

(defun %make-loom-app ()
  "Build the CL-CLI application specification for the loom binary."
  (cl-cli:make-app
   :name "loom"
   :version (loom-version)
   :summary "Terminal text editor with Emacs-like keybindings"
   :positionals (list (cl-cli:make-positional
                       :key :path
                       :required-p nil
                       :description "A file to open, or a directory to browse (defaults to \".\")"))
   :handler (function %run-loom)))

(defparameter *loom-app* (%make-loom-app)
  "CL-CLI application spec for the loom binary: a single positional path
argument and no subcommands (the \"root positional\" shape CL-CLI's own
getting-started guide documents for script-style tools), which gets
--help/--version/-h/-V for free instead of main.lisp hand-parsing argv.")
