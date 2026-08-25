;;;; t/test-helpers-core.lisp
;;;;
;;;; Shared fixtures for unit and integration tests. Keeping these helpers
;;;; outside a feature-specific test file makes the test taxonomy independent
;;;; from ASDF load order.
(in-package #:loom/test)

(defun %fresh-editor-state (initial-content &key with-minibuffer)
  "Build a minimal *EDITOR-STATE* around a single window over a buffer
containing INITIAL-CONTENT -- enough for movement, editing, and undo
commands, which never touch the minibuffer/file-tree/renderer slots.
WITH-MINIBUFFER installs a live MAKE-MINIBUFFER for the prompting commands,
which do; see %WITH-MINIBUFFER-STATE."
  (let* ((buffer (make-buffer :initial-content initial-content))
         (tree (make-window-tree buffer 80 24)))
    (make-editor-state :window-tree tree
                        :workspaces (make-workspace-manager tree :name "main")
                        :minibuffer (and with-minibuffer (make-minibuffer))
                        :keymap (make-keymap)
                        :file-tree nil
                        :renderer nil
                        :buffers (list buffer)
                        :kill-ring nil)))

(defmacro %with-minibuffer-state ((minibuffer initial-content &rest extra-bindings)
                                  &body body)
  "Run BODY with *EDITOR-STATE* dynamically bound to a fresh state over
INITIAL-CONTENT carrying a live minibuffer, and MINIBUFFER bound to that
minibuffer. EXTRA-BINDINGS are appended to the same LET*, so they may refer
to *EDITOR-STATE* and to MINIBUFFER."
  `(let* ((*editor-state* (%fresh-editor-state ,initial-content :with-minibuffer t))
          (,minibuffer (editor-state-minibuffer *editor-state*))
          ,@extra-bindings)
     ,@body))

(defmacro %with-selected-buffer-state ((buffer initial-content &rest extra-bindings)
                                       &body body)
  "Run BODY with *EDITOR-STATE* bound to a fresh state over INITIAL-CONTENT,
and BUFFER bound to that state's selected buffer. EXTRA-BINDINGS are appended
to the same LET*, so they may refer to *EDITOR-STATE* and BUFFER."
  `(let* ((*editor-state* (%fresh-editor-state ,initial-content))
          (,buffer (%selected-test-buffer))
          ,@extra-bindings)
     ,@body))

(defun %selected-test-buffer ()
  "Return the buffer displayed in the fresh editor state's sole window."
  (window-buffer (window-tree-selected-window (editor-state-window-tree *editor-state*))))

(defun %sandboxed-check-p ()
  "True inside `checks.default`'s Nix sandbox, where LOOM_SANDBOXED_CHECK is
set (see flake.nix's `overrideOutputs`).  A test that spawns a real child
process and waits on its output depends on OS-level PTY/pipe delivery that
the Nix Linux build sandbox does not reliably provide -- see
.github/workflows/ci.yml's \"a real PTY/TTY\" note -- so such a test should
SKIP rather than hang or fail there, while still running everywhere else
\(a plain `sbcl --script run-tests.lisp`, `nix develop`'s `test` alias\)."
  (uiop:getenvp "LOOM_SANDBOXED_CHECK"))

(defun %fresh-file-tree (root)
  "Build a FILE-TREE rooted at ROOT with a real, disk-backed child-lister
\(LOOM-FS-LIST-DIRECTORY, the same one MAIN wires up in
%INITIALIZE-EDITOR-STATE\), for exercising the file-tree application
  commands \(commands-window.lisp\) against a real temporary directory."
  (let ((tree (make-file-tree root)))
    (loom/feature/file-tree:file-tree-install-child-lister
     tree
     (function loom/feature/file-tree:loom-fs-list-directory))
    tree))

(defun %confirm-minibuffer (minibuffer input)
  "Submit INPUT to MINIBUFFER's current confirmation callback."
  (funcall (loom::%minibuffer-on-confirm minibuffer) input))

(defmacro %capturing-loom-quit ((quit-var) &body body)
  "Run BODY and set QUIT-VAR when it signals LOOM-QUIT."
  `(handler-bind ((loom::loom-quit
                    (lambda (condition)
                      (declare (ignore condition))
                      (setf ,quit-var t))))
     ,@body))

(defmacro %with-stubbed-terminal-size ((width height) &body body)
  "Run BODY with CL-TTY-KIT:TERMINAL-SIZE replaced by WIDTH and HEIGHT."
  `(with-replaced-function (cl-tty-kit:terminal-size
                            (lambda ()
                              (values ,width ,height)))
     ,@body))

(defmacro %with-registered-major-modes (mode-names &body body)
  "Run BODY and unregister each extension-defined major mode afterward."
  `(unwind-protect
       (progn ,@body)
     ,@(mapcar (lambda (name)
                 `(unregister-major-mode ,name))
               mode-names)))

(defun make-test-git-result (&key (arguments nil) (stdout "") (stderr "")
                                  (status 0))
  (process-kit:make-process-result
   :program "git"
   :arguments arguments
   :status :exited
   :exit-code status
   :stdout stdout
   :stderr stderr))
