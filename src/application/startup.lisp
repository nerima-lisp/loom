;;;; src/application/startup.lisp
;;;;
;;;; Startup is the composition root for the executable. The detailed state
;;;; assembly and service lifecycle live in startup-state.lisp and
;;;; startup-services.lisp; this file keeps the CLI boundary and orchestration.
(in-package #:loom)

(defun loom-version ()
  "Return LOOM's version string from its own ASDF system definition -- the
single source of truth loom.asd's header comment and flake.nix's ASDVERSIONOF
both already rely on -- so CL-CLI's generated --version output cannot drift
from it."
  (let ((system (asdf:find-system "loom" nil)))
    (or (and system (asdf:component-version system)) "unknown")))

(defun %call-with-started-editor-state (path thunk)
  "Initialize *EDITOR-STATE*, start startup services, call THUNK, then stop services."
  (%initialize-editor-state path)
  (%enable-concurrent-file-tree *editor-state*)
  (unwind-protect
       (funcall thunk *editor-state*)
    (%shutdown-editor-services *editor-state*)))

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
  (%call-with-started-editor-state
   (cl-cli:positional-value invocation :path)
   (lambda (state)
     (declare (ignore state))
     (%run-loom-session fd))))
