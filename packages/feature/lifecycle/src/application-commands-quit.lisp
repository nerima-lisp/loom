(in-package #:loom/feature/lifecycle)

(define-condition loom-quit (condition) ()
  (:documentation
   "Signaled by SAVE-BUFFERS-KILL-TERMINAL to ask the main event loop in
src/application/event-loop.lisp to exit cleanly."))
(define-condition loom-quit-abort (condition) ()
  (:documentation
   "Signaled by KILL-LOOM-ABORT to request exit status 1 after modified buffers have been resolved."))

(progn
  (cl-prolog-kit:define-rulebase *quit-answer-rulebase*
    ((quit-action ?answer ?has-path :save-and-continue)
     (:when (and ?has-path (string-equal ?answer "s"))))
    ((quit-action ?answer ?has-path :discard-and-continue)
     (:when (string-equal ?answer "d")))
    ((quit-action ?answer ?has-path :cancel)
     (:when (string-equal ?answer "c"))))

  (defun %quit-answer-action (answer has-path-p)
    "Return the action ANSWER selects for the quit prompt %CONTINUE-QUIT
shows for one modified buffer: :SAVE-AND-CONTINUE, :DISCARD-AND-CONTINUE,
:CANCEL, or :RETRY (an unrecognized answer). HAS-PATH-P is false for a
buffer with no path, whose prompt (\"Discard changes... (d/c)\") never
offers \"s\" in the first place, so an \"s\" answer there falls through to
:RETRY exactly as a genuinely unrecognized answer would."
    (or (cl-prolog-kit:with-prolog-query (?action)
            (*quit-answer-rulebase* `(quit-action ,answer ,has-path-p ?action))
          ?action)
        :retry))

  (defun %quit-prompt-text (buffer)
    "Return the confirmation prompt for modified BUFFER."
    (if (buffer-path buffer)
        (format nil "Save ~A? (s/d/c): " (buffer-name buffer))
        (format nil "Discard changes to ~A? (d/c): " (buffer-name buffer))))

  (defun %continue-quit-prompt (buffers buffer next)
    "Activate the quit prompt for BUFFER and continue with NEXT.
NEXT receives the remaining buffer list after a save or discard, or the
original list when the answer is invalid."
    (let* ((has-path-p (and (buffer-path buffer) t))
           (minibuffer (editor-state-minibuffer *editor-state*)))
      (minibuffer-activate
       minibuffer
       (%quit-prompt-text buffer)
       :on-confirm
       (lambda (answer)
         (ecase (%quit-answer-action answer has-path-p)
           (:save-and-continue
            (buffer-save buffer)
            (funcall next (remove buffer buffers :count 1 :test (function eq))))
           (:discard-and-continue
            (funcall next (remove buffer buffers :count 1 :test (function eq))))
           (:cancel nil)
           (:retry (funcall next buffers))))
       :on-cancel
       (lambda () (minibuffer-message minibuffer "Quit")))))

  (defun %continue-quit (buffers &optional (quit-condition (quote loom-quit)))
    "Prompt for the next modified buffer in BUFFERS, or signal QUIT-CONDITION."
    (let ((buffer (find-if (function buffer-modified-p) buffers)))
      (if buffer
          (%continue-quit-prompt
           buffers
           buffer
           (lambda (next-buffers)
             (%continue-quit next-buffers quit-condition)))
          (signal quit-condition))))

  (defun save-buffers-kill-terminal ()
    "Exit after resolving all modified buffers in the session."
    (%continue-quit (loom/feature/buffers:quit-buffer-list)))
  (progn
    (defun kill-loom-abort ()
      "Abort with exit status 1 after resolving modified buffers."
      (%continue-quit
       (loom/feature/buffers:quit-buffer-list)
       (quote loom-quit-abort)))

    (defun suspend-frame ()
      "Request suspension of the current text terminal frame."
      (loom/core/editor-session:request-terminal-suspend
       (loom/core/editor-session:editor-state-session *editor-state*)))

    (defun %recovery-directory ()
      (merge-pathnames #P".loom/recovery/" (user-homedir-pathname)))

    (defun %recovery-file-path (directory reason index)
      (loop for attempt from 0
            for pathname =
              (merge-pathnames
               (format nil
                       "buffer-~(~A~)-~D-~D-~D-~D.txt"
                       reason
                       (get-universal-time)
                       (get-internal-real-time)
                       index
                       attempt)
               directory)
            unless (probe-file pathname)
              return pathname))

    (defun %save-recovery-buffer (buffer reason index)
      (let ((pathname
              (%recovery-file-path (%recovery-directory) reason index)))
        (ensure-directories-exist pathname)
        (with-open-file
            (stream pathname
                    :direction :output
                    :if-exists :error
                    :if-does-not-exist :create
                    :external-format :utf-8)
          (write-string (buffer-text buffer) stream)
          (finish-output stream))
        pathname))

    (defun %lifecycle-signal-hook (session signal-name)
      (declare (ignore session))
      (if (member signal-name (quote (:term :hup)) :test (function eq))
          :terminate
          :continue))

    (defun %lifecycle-shutdown-hook (session reason)
      (when
          (and
           *editor-state*
           (eq session
               (loom/core/editor-session:editor-state-session *editor-state*))
           (member reason (quote (:sigterm :sighup)) :test (function eq)))
        (loop for buffer in (loom/feature/buffers:quit-buffer-list)
              for index from 0
              when (buffer-modified-p buffer)
                do (%save-recovery-buffer buffer reason index)))
      nil)

    (eval-when (:load-toplevel :execute)
      (loom/core/editor-session:register-session-hook
       :signal
       :feature/lifecycle
       (function %lifecycle-signal-hook))
      (loom/core/editor-session:register-session-hook
       :shutdown
       :feature/lifecycle
       (function %lifecycle-shutdown-hook)))))
