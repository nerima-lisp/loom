(in-package #:loom/test)

(progn
  (defvar *run-loom-test-init-loaded*
    nil)
  (defun %with-isolated-run-loom-home (thunk)
    (host-kit:with-temporary-directory (home)
                                       (let* ((init-path
                                               (merge-pathnames
                                                ".loom/init.lisp"
                                                home))
                                              (original-getenv
                                               (function host-kit:getenv))
                                              (*run-loom-test-init-loaded* nil)
                                              (override-looked-up nil)
                                              (*standard-output*
                                               (make-string-output-stream)))
                                         (ensure-directories-exist init-path)
                                         (host-kit:write-file-string
                                          "(setf loom/test::*run-loom-test-init-loaded* t)"
                                          init-path)
                                         (with-replaced-function
                                          (host-kit:getenv
                                           (lambda (name)
                                             (cond
                                               ((string= name "HOME")
                                                (namestring home))
                                               ((string= name "LOOM_INIT_FILE")
                                                 (setf override-looked-up t)
                                                 (namestring init-path))
                                               (t
                                                (funcall original-getenv name)))))
                                          (funcall thunk))
                                         (expect *run-loom-test-init-loaded*
                                                 :to-be
                                                 t)
                                         (expect override-looked-up
                                                 :to-be-truthy)
                                         (expect
                                          (get-output-stream-string
                                           *standard-output*)
                                          :to-contain
                                          (format nil
                                                  "~C[?1049h"
                                                  (code-char 27))))))
  (defun %call-with-run-loom-init-file (contents thunk)
  (host-kit:with-temporary-directory (home)
    (let* ((init-path (merge-pathnames ".loom/init.lisp" home))
           (original-host-getenv (function host-kit:getenv)))
      (ensure-directories-exist init-path)
      (host-kit:write-file-string contents init-path)
      (flet ((test-getenv (name)
               (cond
                 ((string= name "HOME") (namestring home))
                 ((string= name "LOOM_INIT_FILE") (namestring init-path))
                 (t (funcall original-host-getenv name)))))
        (with-replaced-function
         (host-kit:getenv (function test-getenv))
         (with-replaced-function
          (uiop:getenv (function test-getenv))
          (funcall thunk home init-path)))))))
  (defun %call-with-test-run-loom-session (startup-context event-loop-function)
  (let* ((session (%make-test-editor-session))
         (state (make-editor-state :session session
                                   :minibuffer (loom/core/minibuffer:make-minibuffer)))
         (terminal-session nil)
         (*editor-state* state)
         (loom/core/editor-session::*session-hooks* (make-hash-table :test (function eq)))
         (*standard-output* (make-string-output-stream)))
    (setf terminal-session
          (loom::%make-loom-terminal-session 0 *standard-output* 10 11))
    (with-replaced-function
     (loom::%open-loom-terminal-session
      (lambda (fd stream)
        (declare (ignore fd stream))
        terminal-session))
     (with-replaced-function
      (loom::%install-loom-terminal-signal-handlers
       (lambda (received-terminal-session)
         (declare (ignore received-terminal-session))))
      (with-replaced-function
       (loom::%enable-loom-terminal-session
        (lambda (received-terminal-session)
          (declare (ignore received-terminal-session))))
       (with-replaced-function
        (loom::%run-event-loop event-loop-function)
        (with-replaced-function
         (loom/core/editor-session:cancel-session-background-work
          (lambda (received-session)
            (declare (ignore received-session))))
         (with-replaced-function
          (loom::%uninstall-loom-terminal-signal-handlers (lambda ()))
          (with-replaced-function
           (loom::%close-loom-terminal-session
            (lambda (received-terminal-session)
              (declare (ignore received-terminal-session))))
           (multiple-value-list
            (loom::%run-loom-session startup-context 0 (constantly nil))))))))))))
  (describe "%run-loom"
            (it
             "enables and restores raw mode against a real terminal descriptor, then returns 0"
             (let ((pty (cl-tty-kit:make-pty :program "/bin/sh")))
               (unwind-protect
                   (let ((fd (sb-sys:fd-stream-fd (cl-tty-kit:pty-stream pty)))
                         (startup-context (loom::%parse-startup-context nil)))
                     (%with-isolated-run-loom-home
                      (lambda ()
                        (with-replaced-function
                         (loom::%run-event-loop
                          (lambda (output-stream input-stream terminal-session render-frame-function)
                            (declare (ignore output-stream input-stream render-frame-function))
                            (expect terminal-session :to-be-truthy)
                            (values :normal 0)))
                         (let ((*error-output* (make-string-output-stream)))
                           (let ((status
                                  (loom::%run-loom startup-context :fd fd)))
                             (unless (eql status 0)
                               (error
                                "Expected %run-loom to return 0, got ~D:~%~A"
                                status
                                (get-output-stream-string *error-output*)))
                             (expect status :to-equal 0)))))))
                 (cl-tty-kit:close-pty pty))))
            (it "reports an event-loop failure and returns 1"
                (let ((pty (cl-tty-kit:make-pty :program "/bin/sh")))
                  (unwind-protect
                      (let ((fd
                             (sb-sys:fd-stream-fd (cl-tty-kit:pty-stream pty)))
                            (startup-context (loom::%parse-startup-context nil)))
                        (with-open-file
                            (*standard-input* "/dev/null"
                                              :direction
                                              :input
                                              :element-type
                                              '(unsigned-byte 8))
                          (%with-isolated-run-loom-home
                           (lambda ()
                             (let ((*error-output* (make-string-output-stream)))
                               (with-replaced-function
                                (loom::%run-event-loop
                                 (lambda (output-stream input-stream terminal-session render-frame-function)
                                   (declare (ignore output-stream input-stream terminal-session render-frame-function))
                                   (error "event loop failed")))
                                (expect (loom::%run-loom startup-context :fd fd)
                                        :to-equal
                                        1))
                               (expect (get-output-stream-string *error-output*)
                                       :to-contain
                                       "event loop failed"))))))
                    (cl-tty-kit:close-pty pty))))
            (it
             "runs startup after terminal setup and before user init and the first frame"
             (let* ((events nil)
                    (session (%make-test-editor-session))
                    (state (make-editor-state :session session))
                    (startup-context
                     (loom/core/editor-session:make-startup-context nil
                                                                    (make-hash-table
                                                                     :test
                                                                     (function
                                                                      equal))
                                                                    nil))
                    (*editor-state* state)
                    (loom/core/editor-session::*session-hooks*
                     (make-hash-table :test (function eq)))
                    (terminal-session
                     (loom::%make-loom-terminal-session 0
                                                        (make-string-output-stream)
                                                        10
                                                        11)))
               (flet ((record (event)
                        (push event events)))
                 (loom/core/editor-session:register-session-hook :terminal-modes
                                                                 :feature/terminal
                                                                 (lambda
                                                                     (received-session)
                                                                   (expect
                                                                    received-session
                                                                    :to-be
                                                                    session)
                                                                   (record
                                                                    :terminal-modes)
                                                                   (list
                                                                    :bracketed-paste)))
                 (loom/core/editor-session:register-session-hook :startup
                                                                 :feature/lifecycle
                                                                 (lambda
                                                                     (received-session
                                                                      context
                                                                      received-terminal-session)
                                                                   (expect
                                                                    received-session
                                                                    :to-be
                                                                    session)
                                                                   (expect
                                                                    context
                                                                    :to-be
                                                                    startup-context)
                                                                   (expect
                                                                    received-terminal-session
                                                                    :to-be
                                                                    terminal-session)
                                                                   (record
                                                                    :startup)))
                 (loom/core/editor-session:register-session-hook :shutdown
                                                                 :feature/lifecycle
                                                                 (lambda
                                                                     (received-session
                                                                      reason)
                                                                   (expect
                                                                    received-session
                                                                    :to-be
                                                                    session)
                                                                   (expect
                                                                    reason
                                                                    :to-be
                                                                    :normal)
                                                                   (record
                                                                    :shutdown)))
                 (with-replaced-function
                  (loom::%open-loom-terminal-session
                   (lambda (fd stream)
                     (expect fd :to-be 7)
                     (expect stream :to-be *standard-output*)
                     (record :terminal-open)
                     terminal-session))
                  (with-replaced-function
                   (loom/core/editor-session:set-session-wake-function
                    (lambda (received-session function)
                      (expect received-session :to-be session)
                      (record
                       (if function
                           :wake-install
                           :wake-clear))))
                   (with-replaced-function
                    (loom::%install-loom-terminal-signal-handlers
                     (lambda (received-terminal-session)
                       (expect received-terminal-session
                               :to-be
                               terminal-session)
                       (record :signal-install)))
                    (with-replaced-function
                     (loom::%enable-loom-terminal-session
                      (lambda (received-terminal-session)
                        (expect received-terminal-session
                                :to-be
                                terminal-session)
                        (record :terminal-enable)))
                     (with-replaced-function
                      (loom/feature/user-init:load-user-init
                       (lambda ()
                         (record :user-init)))
                      (with-replaced-function
                       (loom::%run-event-loop
                        (lambda (output-stream input-stream received-terminal-session render-frame-function)
                          (declare (ignore output-stream input-stream render-frame-function))
                          (expect received-terminal-session
                                  :to-be
                                  terminal-session)
                          (record :first-frame)
                          (values :normal 0)))
                       (with-replaced-function
                        (loom/core/editor-session:cancel-session-background-work
                         (lambda (received-session)
                           (expect received-session :to-be session)
                           (record :cancel-background-work)))
                        (with-replaced-function
                         (loom::%uninstall-loom-terminal-signal-handlers
                          (lambda ()
                            (record :signal-uninstall)))
                         (with-replaced-function
                          (loom::%close-loom-terminal-session
                           (lambda (received-terminal-session)
                             (expect received-terminal-session
                                     :to-be
                                     terminal-session)
                             (record :terminal-close)))
                          (expect
                           (multiple-value-list
                            (loom::%run-loom-session startup-context 7 (constantly nil)))
                           :to-equal
                           (list :normal 0))))))))))
                  (expect (reverse events)
                          :to-equal
                          (list :terminal-open
                                :wake-install
                                :terminal-modes
                                :signal-install
                                :terminal-enable
                                :startup
                                :user-init
                                :first-frame
                                :shutdown
                                :cancel-background-work
                                :wake-clear
                                :signal-uninstall
                                :terminal-close))))))
            (it-each
  (("TERM=dumb" "dumb") ("unset TERM" nil))
  "rejects startup with ~A when standard streams are not terminals"
  (term-description term-value)
  (let* ((startup-context (loom::%parse-startup-context nil))
         (event-loop-called nil)
         (original-host-getenv (function host-kit:getenv))
         (*standard-output* (make-string-output-stream))
         (*error-output* (make-string-output-stream)))
    (flet ((test-getenv (name)
             (if (string= name "TERM")
                 term-value
                 (funcall original-host-getenv name))))
      (with-open-file (*standard-input* "/dev/null"
                                       :direction :input
                                       :element-type (quote (unsigned-byte 8)))
        (with-replaced-function
         (host-kit:getenv (function test-getenv))
         (with-replaced-function
          (uiop:getenv (function test-getenv))
          (with-replaced-function
           (loom::%run-event-loop
            (lambda (output-stream input-stream terminal-session render-frame-function)
              (declare (ignore output-stream input-stream terminal-session render-frame-function))
              (setf event-loop-called t)
              (values :normal 0)))
           (expect (loom::%run-loom startup-context) :to-equal 1)
           (expect event-loop-called :to-be-falsy)
           (expect (get-output-stream-string *error-output*)
                   :to-contain
                   "TERM"))))))))
            (it
  "reports a bad init through the minibuffer message sink and continues editing"
  (let* ((loom/core/minibuffer::*message-sinks* nil)
         (message-texts nil)
         (event-loop-called nil)
         (startup-context (loom::%parse-startup-context nil)))
    (loom/core/minibuffer:register-message-sink
     :loom-startup-integration
     (lambda (text)
       (push text message-texts)))
    (%call-with-run-loom-init-file
     "(error \"startup integration init failure\")"
     (lambda (home init-path)
       (declare (ignore home init-path))
       (expect
        (%call-with-test-run-loom-session
         startup-context
         (lambda (output-stream input-stream terminal-session render-frame-function)
           (declare (ignore output-stream input-stream terminal-session render-frame-function))
           (setf event-loop-called t)
           (expect
            (loom/core/minibuffer:minibuffer-message-string
             (editor-state-minibuffer *editor-state*))
            :to-contain
            "startup integration init failure")
           (progn
             (expect
               (some
                 (lambda (text)
                   (search "startup integration init failure" text))
                 message-texts)
               :to-be-truthy)
             (let ((messages-buffer
                     (loom/feature/buffers:find-buffer-by-name
                      (loom/core/editor-session:editor-state-session *editor-state*)
                      "*Messages*")))
               (expect
                 (and messages-buffer
                      (search "startup integration init failure"
                              (loom/core/buffer:buffer-text messages-buffer)))
                 :to-be-truthy)))
           (values :normal 0)))
        :to-equal
        (list :normal 0))
       (expect event-loop-called :to-be-truthy)))))
            (it
  "reloads startup and skips a failing init with --no-init"
  (let* ((loom/core/minibuffer::*message-sinks* nil)
         (message-texts nil)
         (event-loop-called nil)
         (startup-context (loom::%parse-startup-context (list "--no-init"))))
    (progn
      (load (asdf:system-relative-pathname :loom "src/application/startup.lisp"))
      (expect (loom/core/editor-session:cli-option-value-kind "--no-init")
              :to-equal
              :switch)
      (loom/core/minibuffer:register-message-sink
       :loom-startup-integration
       (lambda (text)
         (push text message-texts))))
    (%call-with-run-loom-init-file
     "(error \"startup integration init failure\")"
     (lambda (home init-path)
       (declare (ignore home init-path))
       (expect
        (%call-with-test-run-loom-session
         startup-context
         (lambda (output-stream input-stream terminal-session render-frame-function)
           (declare (ignore output-stream input-stream terminal-session render-frame-function))
           (setf event-loop-called t)
           (expect
            (loom/core/minibuffer:minibuffer-message-string
             (editor-state-minibuffer *editor-state*))
            :to-be
            nil)
           (expect message-texts :to-be nil)
           (values :normal 0)))
        :to-equal
        (list :normal 0))
       (expect event-loop-called :to-be-truthy)
       (expect message-texts :to-be nil))))))
  (describe "Loom child signal handling"
            (it-each
             (("SIGTERM" 143 ("term")) ("SIGHUP" 129 ("hup"))
              ("SIGTSTP" 143 ("tstp" "term")))
             "restores terminal state for ~A and exits with status ~D"
             (signal-name expected-status expected-events)
             (progn
               (when (%sandboxed-check-p)
                 (skip "no PTY/TTY inside the Nix sandbox; see the LOOM_SANDBOXED_CHECK flag in flake.nix"))
               (let* ((root
                     (namestring
                      (asdf:system-source-directory (asdf:find-system "loom"))))
                    (parent
                     (host-kit:parent-directory-pathname (pathname root)))
                    (sbcl
                     (namestring
                      (or (host-kit:find-program "sbcl")
                          (error "SBCL is required for the PTY signal test"))))
                    (sibling-names
                     (list "cl-tty-kit"
                           "cl-host-kit"
                           "cl-history-kit"
                           "cl-prolog-kit"
                           "cl-cli"
                           "cl-regex-kit"
                           "cl-boundary-kit"
                           "cl-concurrent-kit"
                           "cl-json-kit"
                           "cl-log-kit"
                           "cl-process-kit"
                           "cl-vcs-kit"
                           "cl-resilience-kit"
                           "cl-weave"
                           "cl-date-kit"
                           "cl-codec-kit"
                           "cl-parser-kit"))
                    (sibling-directories
                     (mapcar
                      (lambda (name)
                        (namestring
                         (merge-pathnames (format nil "~A/" name) parent)))
                      sibling-names))
                    (source-registry (host-kit:getenv "CL_SOURCE_REGISTRY"))
                    (registry-directives
                     (if (and source-registry (plusp (length source-registry)))
                         (format nil "(list :directory ~S)" root)
                         (format nil
                                 "(list :directory ~S)~{ (list :directory ~S)~}"
                                 root
                                 sibling-directories))))
               (host-kit:with-temporary-directory (home)
                                                  (let* ((event-path (namestring (merge-pathnames "signal-events.txt" home)))
       (resume-path
        (let ((path (merge-pathnames "resume.txt" home)))
          (host-kit:write-file-string "LOOM-RESUME-MARKER" path)
          (namestring path)))
       (loom-form
        (list
         (format nil
                 "(asdf:initialize-source-registry
             (list :source-registry ~A :inherit-configuration))"
                 registry-directives)
         (format nil
                 "(progn
  (loom/core/editor-session:register-session-hook
   :signal :feature/lifecycle
   (lambda (session signal-name)
     (declare (ignore session))
     (with-open-file
         (events ~S
           :direction :output
           :if-exists :append
           :if-does-not-exist :create)
       (write-line
        (string-downcase (symbol-name signal-name))
        events))
     (if (member signal-name (list :term :hup)
                 :test (function eq))
         :terminate
         :continue)))
  (setf sb-ext:*posix-argv* (list \"loom\" ~S))
  (funcall
   (symbol-function (find-symbol \"MAIN\" \"LOOM\"))))"
                 event-path
                 resume-path)))
       (result
        (let* ((output "")
               (alternate-screen-enter
                (concatenate 'string (string (code-char 27)) "[?1049h"))
               (alternate-screen-leave
                (concatenate 'string (string (code-char 27)) "[?1049l"))
               (environment
                (append
                 (remove-if
                  (lambda (entry)
                    (let ((separator (search "=" entry)))
                      (and separator
                           (member (subseq entry 0 separator)
                                   '("HOME" "TERM" "LOOM_INIT_FILE")
                                   :test
                                   #'string=))))
                  (sb-ext:posix-environ))
                 (list
 (format nil "HOME=~A"
         (or (host-kit:getenv "HOME")
             (namestring home)))
 "TERM=xterm-256color"
 (format nil "LOOM_INIT_FILE=~A"
         (namestring
          (merge-pathnames ".loom-init-missing.lisp" home))))))
               (pty
                (cl-tty-kit:make-pty :program
                                     sbcl
                                     :args
                                     (list "--noinform"
                                           "--non-interactive"
                                           "--eval"
                                           "(require :asdf)"
                                           "--eval"
                                           (first loom-form)
                                           "--eval"
                                           (format nil "(asdf:load-system ~S)" "loom")
                                           "--eval"
                                           (second loom-form))
                                     :environment
                                     environment))
               (process (cl-tty-kit:pty-process pty)))
          (unwind-protect
              (labels ((read-available ()
                         (handler-case (let ((chunk (cl-tty-kit:pty-read pty)))
                                         (when chunk
                                           (setf output (concatenate 'string
                                                                     output
                                                                     chunk))))
                           (cl-tty-kit:pty-operation-failed (condition)
                             (if (cl-tty-kit:pty-alive-p pty)
                                 (error condition)
                                 nil))))
                       (wait-until (predicate seconds)
                         (loop with deadline = (+ (get-internal-real-time)
                                                  (* seconds
                                                     internal-time-units-per-second))
                               do (read-available)
                               when (funcall predicate)
                                 return t
                               when (not (cl-tty-kit:pty-alive-p pty))
                                 return nil
                               when (> (get-internal-real-time) deadline)
                                 return nil
                               do (sleep 0.05)))
                       (send-signal (signal-number)
                         (sb-ext:process-kill process signal-number :pid)))
                (cl-tty-kit:pty-resize pty 80 24)
                (unless
                    (wait-until
                     (lambda ()
                       (search alternate-screen-enter output))
                     90)
                  (error "Loom did not enter the alternate screen: ~S" output))
                (unless
                    (wait-until
                     (lambda ()
                       (search "LOOM-RESUME-MARKER" output))
                     15)
                  (error "Loom did not render the resume marker: ~S" output))
                (if (string= signal-name "SIGTSTP")
                    (let ((suspend-start (length output)))
                      (send-signal sb-unix:sigtstp)
                      (unless
                          (wait-until
                           (lambda ()
                             (search alternate-screen-leave
                                     output
                                     :start2
                                     suspend-start))
                           15)
                        (error
                         "Loom did not leave the alternate screen before stopping"))
                      (unless
                          (wait-until
                           (lambda ()
                             (eq (sb-ext:process-status process) :stopped))
                           15)
                        (error "Loom did not stop after SIGTSTP"))
                      (let ((resume-start (length output)))
                        (send-signal sb-unix:sigcont)
                        (unless
                            (wait-until
                             (lambda ()
                               (search alternate-screen-enter
                                       output
                                       :start2
                                       resume-start))
                             15)
                          (error "Loom did not restore the terminal after SIGCONT"))
                      (unless
                          (wait-until
                           (lambda ()
                             (search "LOOM-RESUME-MARKER"
                                     output
                                     :start2
                                     resume-start))
                           15)
                        (error "Loom did not redraw the buffer after SIGCONT")))
                      (let ((terminate-start (length output)))
                        (send-signal sb-unix:sigterm)
                        (unless
                            (wait-until
                             (lambda ()
                               (search alternate-screen-leave
                                       output
                                       :start2
                                       terminate-start))
                             15)
                          (error
                           "Loom did not leave the alternate screen after SIGTERM"))))
                    (let ((terminate-start (length output)))
                      (send-signal
                       (if (string= signal-name "SIGTERM")
                           sb-unix:sigterm
                           sb-unix:sighup))
                      (unless
                          (wait-until
                           (lambda ()
                             (search alternate-screen-leave
                                     output
                                     :start2
                                     terminate-start))
                           15)
                        (error "Loom did not leave the alternate screen after ~A"
                               signal-name))))
                (unless
                    (wait-until
                     (lambda ()
                       (not (sb-ext:process-alive-p process)))
                     15)
                  (error "Loom did not exit after ~A" signal-name))
                (read-available)
                (list :exit-code (cl-tty-kit:pty-exit-code pty) :output output))
            (cl-tty-kit:close-pty pty)))))
  (expect (getf result :exit-code) :to-be expected-status)
  (expect (getf result :output)
          :to-contain
          (concatenate 'string (string (code-char 27)) "[?1049h"))
  (expect (getf result :output)
          :to-contain
          (concatenate 'string (string (code-char 27)) "[?1049l"))
  (with-open-file (events event-path)
    (expect
     (loop for event = (read-line events nil nil)
           while event
           collect event)
     :to-equal
     expected-events)))
))))))
