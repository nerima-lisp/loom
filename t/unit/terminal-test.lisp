;;;; t/unit/terminal-test.lisp
;;;;
;;;; PTY-backed terminal behavior: screen decoding, key translation, and one
;;;; real child process.  The screen model intentionally covers a common
;;;; baseline rather than claiming complete VT compatibility.
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

  (it "applies cursor addressing, erasure, and alternate-screen output"
    (let ((screen (make-terminal-screen :width 12 :height 4)))
      (terminal-screen-feed
       screen
       (format nil "one~C~Ctwo" (code-char 13) (code-char 10)))
      (expect (terminal-screen-text screen) :to-equal (format nil "one~%two"))
      (terminal-screen-feed
       screen
       (format nil "~C[1;1HTOP~C[2K~C[2;1Hbottom"
               (code-char 27) (code-char 27) (code-char 27)))
      (expect (terminal-screen-text screen) :to-equal (format nil "~%bottom"))
      (terminal-screen-feed
       screen
       (format nil "~C[?1049h~C[1;1HALT~C[?1049l"
               (code-char 27) (code-char 27) (code-char 27)))
      (expect (terminal-screen-text screen) :to-equal (format nil "~%bottom"))
      (let ((default-screen (make-terminal-screen :width 12 :height 2)))
        (terminal-screen-feed default-screen "abcdef")
        (terminal-screen-feed
         default-screen
         (format nil "~C[3G~C[K" (code-char 27) (code-char 27)))
        (expect (terminal-screen-text default-screen) :to-equal "ab"))))

  (it "translates ordinary, control, and special keys into terminal bytes"
    (expect
     (loom/feature/terminal::%terminal-event-payload
      (cl-tty-kit:make-key-event :type :character :code #\a))
     :to-equal
     "a")
    (expect
     (loom/feature/terminal::%terminal-event-payload
      (cl-tty-kit:make-key-event
       :type :character :code #\c :modifiers '(:control)))
     :to-equal
     (string (code-char 3)))
    (expect
     (loom/feature/terminal::%terminal-event-payload
      (cl-tty-kit:make-key-event
       :type :character :code #\x :modifiers '(:alt)))
     :to-equal
     (format nil "~Cx" (code-char 27)))
    (expect
     (loom/feature/terminal::%terminal-event-payload
      (cl-tty-kit:make-key-event :type :special :code :control-x))
     :to-equal
     (string (code-char 24)))
    (expect
     (loom/feature/terminal::%terminal-event-payload
      (cl-tty-kit:make-key-event :type :special :code :up))
     :to-equal
     (format nil "~C[A" (code-char 27)))
    (expect
     (loom/feature/terminal::%terminal-event-payload
      (cl-tty-kit:make-key-event
       :type :special :code :up :modifiers '(:alt)))
     :to-equal
     (format nil "~C~C[A" (code-char 27) (code-char 27))))

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
