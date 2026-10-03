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

(defmacro %with-buffer-at ((buffer initial-content line column) &body body)
  "Bind BUFFER to a fresh buffer with point at LINE and COLUMN.

This keeps property-based editing examples focused on the operation under
test instead of repeating buffer construction and point setup."
  `(let ((,buffer (make-buffer :initial-content ,initial-content)))
     (buffer-set-point ,buffer ,line ,column)
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

(defmacro skip-in-sandbox (reason &body body)
  "Skip BODY only for checks running in the Nix build sandbox."
  `(if (%sandboxed-check-p)
       (skip ,reason)
       (progn ,@body)))

(describe
  "test runner integrity"
  (it
    "rejects a selector that collects no tests"
    (signals error
      (%run-test-suite :name-filter "loom/test/this-test-does-not-exist")))

  (it
    "rejects an empty test body"
    (skip-in-sandbox
     "isolated SBCL is unavailable in the Nix build sandbox"
     (let ((result
             (run-isolated
              '(progn
                 (clear-tests)
                 (before-each (expect-has-assertions))
                 (it "empty body")
                 (unless (run-all :reporter :sexp
                                  :stream (make-broadcast-stream)
                                  :pass-with-no-tests nil)
                   (uiop:quit 0))
                 (uiop:quit 1))
              :systems '("loom/test")
              :package "loom/test"
              :timeout 30)))
       (expect (isolated-result-status result) :to-be :pass)
       (expect (isolated-result-exit-code result) :to-be 0)))))

(defmacro with-test-mock ((name &optional implementation) &body body)
  "Bind NAME to a cl-weave mock and dispose it after BODY."
  `(let ((,name (make-mock-function ,@(when implementation
                                      (list implementation)))))
     (unwind-protect
          (progn ,@body)
       (dispose-mock ,name))))

(defmacro with-test-spy ((name symbol) &body body)
  "Bind NAME to a restored cl-weave spy for SYMBOL around BODY."
  `(let ((,name (spy-on ',symbol)))
     (unwind-protect
          (progn ,@body)
       (mock-restore ,name))))

(defmacro expect-snapshot (actual key)
  "Match ACTUAL against the cl-weave snapshot identified by KEY."
  `(expect ,actual :to-match-snapshot ,key))

(defun assert-frame-text (backend expected)
  "Assert EXPECTED against the last structured frame from BACKEND.

The CL-TUI-KIT testing system is resolved when this helper is used so the
shared test package remains loadable before the UI dependency is present."
  (let ((package (find-package "CL-TUI-KIT/TESTING")))
    (unless package
      (error "CL-TUI-KIT/TESTING is required for frame assertions."))
    (flet ((external-function (name)
             (let ((symbol (find-symbol name package)))
               (unless (and symbol (fboundp symbol))
                 (error "CL-TUI-KIT/TESTING does not export ~A." name))
               symbol)))
      (funcall (external-function "ASSERT-SURFACE-TEXT")
               (funcall (external-function "TEST-BACKEND-LAST-FRAME") backend)
               expected))))

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
