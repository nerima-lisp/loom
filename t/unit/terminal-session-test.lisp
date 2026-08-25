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

  (it "replaces a terminal transcript while preserving buffer invariants"
    (let ((buffer (make-buffer :name "*Loom-Terminal*")))
      (buffer-insert-string buffer "stale transcript")
      (loom/feature/terminal::%replace-terminal-buffer
       buffer
       "fresh\ntranscript")
      (expect (buffer-text buffer) :to-equal "fresh\ntranscript")
      (expect (buffer-read-only-p buffer) :to-be-truthy)
      (expect (buffer-modified-p buffer) :to-be nil)))

  (it "accepts only live terminal input events"
    (let* ((state (%fresh-editor-state ""))
           (buffer (window-buffer
                    (window-tree-selected-window
                     (editor-state-window-tree state))))
           (session
             (loom/feature/terminal::%make-terminal-session
              "*Loom-Terminal*" "/bin/sh" nil (uiop:getcwd) buffer :pty)))
      (setf (editor-state-terminal-sessions state) (list session))
      (let ((*editor-state* state))
        (expect
         (terminal-input-event-p
          (cl-tty-kit:make-key-event :type :character :code #\a
                                     :kind :press))
         :to-be-truthy)
        (expect
         (terminal-input-event-p
          (cl-tty-kit:make-key-event :type :paste :code "x"
                                     :kind :repeat))
         :to-be-truthy)
        (expect
         (terminal-input-event-p
          (cl-tty-kit:make-key-event :type :special :code :control-space
                                     :kind :release))
         :to-be nil)
        (setf (terminal-session-alive-p session) nil)
        (expect
         (terminal-input-event-p
          (cl-tty-kit:make-key-event :type :character :code #\a))
         :to-be nil))))

  (it "sends accepted terminal events and reports whether they were handled"
    (let* ((state (%fresh-editor-state ""))
           (buffer (window-buffer
                    (window-tree-selected-window
                     (editor-state-window-tree state))))
           (session
             (loom/feature/terminal::%make-terminal-session
              "*Loom-Terminal*" "/bin/sh" nil (uiop:getcwd) buffer :pty))
           sent)
      (setf (editor-state-terminal-sessions state) (list session))
      (let ((*editor-state* state))
        (with-replaced-function
            (terminal-session-send
             (lambda (candidate-session text)
               (setf sent (list candidate-session text))))
          (expect
           (terminal-handle-key-event
            (cl-tty-kit:make-key-event :type :character :code #\a))
           :to-be-truthy)
          (expect (second sent) :to-equal "a")
          (expect
           (terminal-handle-key-event
            (cl-tty-kit:make-key-event :type :special :code :unknown))
           :to-be nil)))))

  (it "reports terminal command failures through the minibuffer"
    (%with-minibuffer-state (minibuffer "")
      (with-replaced-function
          (start-terminal-session
           (lambda ()
             (error "PTY unavailable")))
        (expect (terminal) :to-be nil))
      (expect (minibuffer-message-string minibuffer)
              :to-contain
              "Terminal failed: PTY unavailable")))

  (it "registers and selects a started terminal session"
    (%with-minibuffer-state (minibuffer "")
      (let* ((buffer (make-buffer :name "*Loom-Terminal*"))
             (session
               (loom/feature/terminal::%make-terminal-session
                "*Loom-Terminal*" "/bin/sh" nil (uiop:getcwd) buffer nil)))
        (setf (terminal-session-alive-p session) t)
        (with-replaced-function
            (start-terminal-session (lambda () session))
          (%with-stubbed-terminal-size (100 40)
            (with-replaced-function
                (terminal-session-poll (lambda (candidate) candidate))
              (expect (terminal) :to-be session)))
          (expect (find buffer (editor-state-buffers *editor-state*) :test #'eq)
                  :to-be-truthy)
          (expect (window-buffer (%selected-window)) :to-be buffer)
          (expect (minibuffer-message-string minibuffer)
                  :to-equal
                  "Terminal started")))))

  (it "stops the terminal session selected by the current buffer"
    (%with-minibuffer-state (minibuffer "")
      (let* ((buffer (make-buffer :name "*Loom-Terminal*"))
             (session
               (loom/feature/terminal::%make-terminal-session
                "*Loom-Terminal*" "/bin/sh" nil (uiop:getcwd) buffer nil)))
        (setf (terminal-session-alive-p session) t
              (editor-state-terminal-sessions *editor-state*) (list session))
        (%register-buffer buffer)
        (window-set-buffer (%selected-window) buffer)
        (with-replaced-function
            (stop-terminal-session
             (lambda (candidate)
               (setf (terminal-session-alive-p candidate) nil)
               candidate))
          (expect (terminal-stop) :to-be session))
        (expect (minibuffer-message-string minibuffer)
                :to-equal
                  "Terminal stopped"))))

  (it "reports when a terminal exits immediately"
    (%with-minibuffer-state (minibuffer "")
      (let* ((buffer (make-buffer :name "*Loom-Terminal*"))
             (session
             (loom/feature/terminal::%make-terminal-session
                "*Loom-Terminal*" "/bin/sh" nil (uiop:getcwd) buffer nil)))
        (setf (terminal-session-alive-p session) nil)
        (with-replaced-function
            (start-terminal-session (lambda () session))
          (%with-stubbed-terminal-size (100 40)
            (with-replaced-function
                (terminal-session-poll (lambda (candidate) candidate))
              (expect (terminal) :to-be session)))
          (expect (minibuffer-message-string minibuffer)
                  :to-equal
                  "Terminal exited immediately")))))

  (it "reports when stopping a non-terminal buffer"
    (%with-minibuffer-state (minibuffer "")
      (terminal-stop)
      (expect (minibuffer-message-string minibuffer)
              :to-equal
              "The selected buffer is not a terminal")))

  (it "closes a live session whose PTY has disappeared"
    (let* ((state (%fresh-editor-state ""))
           (buffer
             (window-buffer
              (window-tree-selected-window
               (editor-state-window-tree state))))
           (session
             (loom/feature/terminal::%make-terminal-session
              "*Loom-Terminal*" "/bin/sh" nil (uiop:getcwd) buffer nil)))
      (setf (terminal-session-alive-p session) t)
      (setf (editor-state-terminal-sessions state) (list session))
      (expect (terminal-session-poll session) :to-be session)
      (expect (terminal-session-alive-p session) :to-be nil)
      (expect (terminal-session-for-buffer buffer state) :to-be session)))

  (it "polls PTY output into the screen before closing an exited PTY"
    (let* ((buffer (make-buffer :name "*Loom-Terminal*"))
           (session
             (loom/feature/terminal::%make-terminal-session
              "*Loom-Terminal*" "/bin/sh" nil (uiop:getcwd) buffer :pty))
           (chunks (list "hello" "")))
      (with-replaced-function
          (cl-tty-kit:pty-read
           (lambda (pty)
             (declare (ignore pty))
             (pop chunks)))
        (with-replaced-function
            (cl-tty-kit:pty-alive-p
             (lambda (pty)
               (declare (ignore pty))
               nil))
          (with-replaced-function
              (cl-tty-kit:pty-exit-code
               (lambda (pty)
                 (declare (ignore pty))
                 7))
            (with-replaced-function
                (cl-tty-kit:close-pty
                 (lambda (pty)
                   (declare (ignore pty))
                   t))
              (expect (terminal-session-poll session) :to-be session)))))
      (expect (terminal-session-output session) :to-contain "hello")
      (expect (terminal-session-raw-output session) :to-equal "hello")
      (expect (terminal-session-exit-code session) :to-be 7)
      (expect (terminal-session-alive-p session) :to-be nil)
      (expect (terminal-session-pty session) :to-be nil)
      (expect (buffer-text buffer) :to-contain "hello")
      (expect (buffer-read-only-p buffer) :to-be-truthy)))

  (it "keeps invalid resize requests out of the screen and PTY"
    (let ((session
            (loom/feature/terminal::%make-terminal-session
             "*Loom-Terminal*" "/bin/sh" nil (uiop:getcwd)
             (make-buffer :name "*Loom-Terminal*") nil)))
      (expect (terminal-session-resize session 0 24) :to-be session)
      (expect (terminal-screen-width (terminal-session-screen session))
              :to-be 80)
      (expect (terminal-screen-height (terminal-session-screen session))
              :to-be 24)))

  (it "ignores sends from inactive sessions"
    (let ((session
            (loom/feature/terminal::%make-terminal-session
             "*Loom-Terminal*" "/bin/sh" nil (uiop:getcwd)
             (make-buffer :name "*Loom-Terminal*") nil)))
      (expect (terminal-session-send session "ignored") :to-be nil)))

  (it "resizes a live session screen without requiring a PTY"
    (let ((session
            (loom/feature/terminal::%make-terminal-session
             "*Loom-Terminal*" "/bin/sh" nil (uiop:getcwd)
             (make-buffer :name "*Loom-Terminal*") nil)))
      (setf (terminal-session-alive-p session) t)
      (expect (terminal-session-resize session 100 40) :to-be session)
      (expect (terminal-screen-width (terminal-session-screen session))
              :to-be 100)
      (expect (terminal-screen-height (terminal-session-screen session))
              :to-be 40)))

  (it "handles empty terminal registries without a state"
    (expect (poll-terminal-sessions nil) :to-be nil)
    (expect (resize-terminal-sessions 80 24 nil) :to-be nil)
    (expect (terminal-session-for-buffer nil nil) :to-be nil))

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
