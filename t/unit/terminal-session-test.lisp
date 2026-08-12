;;;; t/unit/terminal-session-test.lisp
;;;;
;;;; PTY-backed terminal session lifecycle and transcript handling.
(in-package #:loom/test)

(describe
  "terminal sessions"
  (it "removes ANSI styling from the stored terminal transcript"
    (let ((session
            (loom/feature/terminal::%make-terminal-session
             "*Loom-Terminal*"
             "/bin/sh"
             nil
             (uiop:getcwd)
             (make-buffer :name "*Loom-Terminal*")
             nil)))
      (terminal-session-feed-output
       session
       (format nil "plain ~C[31mcolored~C[0m" (code-char 27) (code-char 27)))
      (expect (terminal-session-output session)
              :to-equal
              "plain colored")))

  (it "captures output from a real child process attached to a PTY"
    (when (%sandboxed-check-p)
      (skip "no PTY/TTY inside the Nix sandbox; see checks.default's LOOM_SANDBOXED_CHECK in flake.nix"))
    (let* ((state (%fresh-editor-state ""))
           (session
             (start-terminal-session
              :program "/bin/sh"
              :args '("-c" "printf terminal-ready")
              :state state)))
      (unwind-protect
           (progn
             (loop repeat 100
                   while (and (not (search "terminal-ready"
                                           (terminal-session-raw-output session)))
                              (terminal-session-alive-p session))
                   do (terminal-session-poll session)
                      (sleep 0.01))
             (expect (terminal-session-raw-output session)
                     :to-contain
                     "terminal-ready")
             (expect (buffer-text (terminal-session-buffer session))
                     :to-contain
                     "terminal-ready")
             (expect (buffer-read-only-p (terminal-session-buffer session))
                     :to-be-truthy))
        (stop-terminal-session session)
        (expect (terminal-session-pty session) :to-be nil))))

  (it "releases a live PTY when a terminal is stopped"
    (let* ((state (%fresh-editor-state ""))
           (session
             (start-terminal-session
              :program "/bin/sh"
              :args nil
              :state state)))
      (expect (terminal-session-pty session) :not :to-be nil)
      (stop-terminal-session session)
      (expect (terminal-session-pty session) :to-be nil)
      (expect (terminal-session-alive-p session) :to-be nil))))
