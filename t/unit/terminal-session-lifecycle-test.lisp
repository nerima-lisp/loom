(in-package #:loom/test)

(describe
  "terminal session lifecycle"

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

  (it "sends input to a live PTY session"
    (let ((session
            (loom/feature/terminal::%make-terminal-session
             "*Loom-Terminal*" "/bin/sh" nil (uiop:getcwd)
             (make-buffer :name "*Loom-Terminal*") :pty))
          sent)
      (setf (terminal-session-alive-p session) t)
      (with-replaced-function
          (cl-tty-kit:pty-write
           (lambda (pty text)
             (setf sent (list pty text))))
        (expect (terminal-session-send session "input") :to-be session))
      (expect sent :to-equal '(:pty "input"))))

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

  (it "resizes the PTY after resizing the live session screen"
    (let ((session
            (loom/feature/terminal::%make-terminal-session
             "*Loom-Terminal*" "/bin/sh" nil (uiop:getcwd)
             (make-buffer :name "*Loom-Terminal*") :pty))
          resized)
      (setf (terminal-session-alive-p session) t)
      (with-replaced-function
          (cl-tty-kit:pty-resize
           (lambda (pty columns rows)
             (setf resized (list pty columns rows))))
        (expect (terminal-session-resize session 100 40) :to-be session))
      (expect resized :to-equal '(:pty 100 40))
      (expect (terminal-screen-width (terminal-session-screen session))
              :to-be 100)
      (expect (terminal-screen-height (terminal-session-screen session))
              :to-be 40)))

  (it "handles empty terminal registries without a state"
    (expect (poll-terminal-sessions nil) :to-be nil)
    (expect (resize-terminal-sessions 80 24 nil) :to-be nil)
    (expect (terminal-session-for-buffer nil nil) :to-be nil))

  (it "requires editor state when starting a terminal session"
    (signals error
      (start-terminal-session :state nil)))

  (it "polls and resizes every registered terminal session"
    (let* ((state (%fresh-editor-state ""))
           (first-session
             (loom/feature/terminal::%make-terminal-session
              "*Loom-Terminal*" "/bin/sh" nil (uiop:getcwd)
              (make-buffer :name "*Loom-Terminal*") nil))
           (second-session
             (loom/feature/terminal::%make-terminal-session
              "*Loom-Terminal<2>*" "/bin/sh" nil (uiop:getcwd)
              (make-buffer :name "*Loom-Terminal<2>*") nil))
           polled resized)
      (setf (editor-state-terminal-sessions state)
            (list first-session second-session))
      (with-replaced-function
          (terminal-session-poll
           (lambda (session)
             (push session polled)))
        (with-replaced-function
            (terminal-session-resize
             (lambda (session columns rows)
               (push (list session columns rows) resized)))
          (expect (poll-terminal-sessions state) :to-be state)
          (expect (resize-terminal-sessions 100 40 state) :to-be state)))
      (expect polled :to-equal (list second-session first-session))
      (expect resized
              :to-equal
              (list (list second-session 100 40)
                    (list first-session 100 40)))))

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
