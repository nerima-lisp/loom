(in-package #:loom/test)

(defun %make-test-editor-session (&optional buffers &key window-tree)
  (let ((session
          (loom/core/editor-session:make-editor-session
           (quote (:core/window-tree :feature/buffers
                    :feature/workspace :feature/keyboard-macro))
           :initial-slices (list (cons :core/window-tree window-tree)))))
    (dolist (buffer (reverse buffers))
      (loom/feature/buffers:register-buffer session buffer))
    session))

(defun %test-registered-buffers (state)
  (loom/feature/buffers:registered-buffers
   (loom/core/editor-session:editor-state-session state)))

(defun %register-test-buffer (state buffer)
  (loom/feature/buffers:register-buffer
   (loom/core/editor-session:editor-state-session state)
   buffer))

(defun %replace-test-registered-buffers (state buffers)
  (let ((session (loom/core/editor-session:editor-state-session state)))
    (dolist (buffer (loom/feature/buffers:registered-buffers session))
      (loom/feature/buffers:unregister-buffer session buffer))
    (dolist (buffer (reverse buffers))
      (loom/feature/buffers:register-buffer session buffer))
    (loom/feature/buffers:registered-buffers session)))

(defun %fresh-editor-state (initial-content &key with-minibuffer)
  "Build a minimal *EDITOR-STATE* around a single window over a buffer
containing INITIAL-CONTENT -- enough for movement, editing, and undo
commands, which never touch the minibuffer/file-tree/renderer slots.
WITH-MINIBUFFER installs a live MAKE-MINIBUFFER for the prompting commands,
which do; see %WITH-MINIBUFFER-STATE."
  (let* ((buffer (make-buffer :initial-content initial-content))
         (tree (make-window-tree buffer 80 24))
         (session (%make-test-editor-session (list buffer) :window-tree tree)))
    (make-editor-state :session session
                       :window-tree tree
                       :minibuffer (and with-minibuffer (make-minibuffer))
                       :keymap (make-keymap)
                       :file-tree nil
                       :renderer nil
                       :kill-ring nil)))

(defmacro %with-minibuffer-state ((minibuffer initial-content &rest extra-bindings)
                                  &body body)
  "Run BODY with *EDITOR-STATE* dynamically bound to a fresh state over
INITIAL-CONTENT carrying a live minibuffer, and MINIBUFFER bound to that
minibuffer. EXTRA-BINDINGS are appended to the same LET*, so they may refer
to *EDITOR-STATE* and to MINIBUFFER."
  `(let* ((*editor-state* (%fresh-editor-state ,initial-content :with-minibuffer t))
          (loom/core/editor-session:*editor-session*
            (loom/core/editor-session:editor-state-session *editor-state*))
          (,minibuffer (editor-state-minibuffer *editor-state*))
          ,@extra-bindings)
     ,@body))

(defmacro %with-selected-buffer-state ((buffer initial-content &rest extra-bindings)
                                       &body body)
  "Run BODY with *EDITOR-STATE* bound to a fresh state over INITIAL-CONTENT,
and BUFFER bound to that state's selected buffer. EXTRA-BINDINGS are appended
to the same LET*, so they may refer to *EDITOR-STATE* and BUFFER."
  `(let* ((*editor-state* (%fresh-editor-state ,initial-content))
          (loom/core/editor-session:*editor-session*
            (loom/core/editor-session:editor-state-session *editor-state*))
          (,buffer (%selected-test-buffer))
          ,@extra-bindings)
     ,@body))

(defmacro %with-buffer-at ((buffer initial-content line column) &body body)
  "Bind BUFFER to a fresh buffer with point at LINE and COLUMN.

This keeps property-based editing examples focused on the operation under
test instead of repeating buffer construction and point setup."
  `(let ((,buffer (make-buffer :initial-content ,initial-content)))
     (buffer-set-point ,buffer ,line ,column)
     ,@body))

(defun %selected-test-buffer ()
  "Return the buffer displayed in the fresh editor state's sole window."
  (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))))

(defun %sandboxed-check-p ()
  "Detect the sandbox-check flag set by flake.nix for test and coverage builds.
The three real-process tests using this predicate skip when the flag is set;
it does not detect the operating system or whether a PTY is available."
  (uiop:getenvp "LOOM_SANDBOXED_CHECK"))

(defun %fresh-file-tree (root)
  "Install the disk-backed child-lister used by %MAKE-STARTUP-EDITOR-STATE.
File-tree command tests can then operate on a real temporary directory."
  (let ((tree (make-file-tree root)))
    (loom/feature/file-tree:file-tree-install-child-lister
     tree
     (function loom/feature/file-tree:loom-fs-list-directory))
    tree))

(defun %confirm-minibuffer (minibuffer input)
  "Invoke the current confirmation callback after deactivating the MINIBUFFER prompt."
  (let ((on-confirm (loom/core/minibuffer::%minibuffer-on-confirm minibuffer)))
    (loom/core/minibuffer:minibuffer-deactivate minibuffer)
    (funcall on-confirm input)))

(defmacro %capturing-loom-quit ((quit-var) &body body)
  "Run BODY and set QUIT-VAR when it signals LOOM-QUIT."
  `(handler-bind ((loom/feature/lifecycle:loom-quit
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
(progn
  (defvar *test-command-sequence* 0)
  (defun %register-test-command (command)
    (let ((id (format nil "test/command/~D"
                      (incf *test-command-sequence*))))
      (loom/core/command::register-internal-command
       :test id command :keys nil :keymap :global
       :mutates nil :prompts nil :needs-region nil :external nil
       :modes (quote (:all)))
      id)))
