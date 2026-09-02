;;;; t/unit/terminal-session-test.lisp
;;;;
;;;; PTY-backed terminal session lifecycle and transcript handling.
(in-package #:loom/test)

(describe
  "terminal sessions"
  (it-each
      ((nil "*Loom-Terminal*")
       (("*Loom-Terminal*") "*Loom-Terminal<2>*")
       (("*Loom-Terminal*" "*Loom-Terminal<2>*") "*Loom-Terminal<3>*"))
      "selects the first available terminal name from ~S"
      (buffer-names expected)
    (let ((state (%fresh-editor-state "")))
      (setf (editor-state-buffers state)
            (mapcar (lambda (name) (make-buffer :name name)) buffer-names))
      (expect (loom/feature/terminal::%terminal-buffer-name state)
              :to-equal
              expected)))

  (it "uses the current directory when no buffer path is available"
    (expect (loom/feature/terminal::%terminal-directory-for-buffer nil)
            :to-equal
            (uiop:getcwd)))

  (it-each
      (("/tmp/loom/example.txt" "/tmp/loom/"))
      "resolves a terminal directory from ~S"
      (path expected)
    (expect (loom/feature/terminal::%terminal-directory-for-buffer
             (make-buffer :path path))
            :to-equal
            expected))

  (it "returns the selected buffer only when an editor window tree exists"
    (expect (loom/feature/terminal::%terminal-selected-buffer nil)
            :to-be
            nil)
    (let ((state (%fresh-editor-state "")))
      (expect (loom/feature/terminal::%terminal-selected-buffer state)
              :to-be
              (window-buffer
               (window-tree-selected-window
                (editor-state-window-tree state))))))

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

)
