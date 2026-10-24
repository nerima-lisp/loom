(in-package #:loom)

(defun %enable-concurrent-file-tree (state)
  "Replace STATE's synchronous file-tree lister with a cached runtime."
  (let* ((tree (editor-state-file-tree state))
         (lister (loom/feature/file-tree:file-tree-child-lister tree))
         (root (first (loom/feature/file-tree:file-tree-prefetch-paths tree)))
         (initial-entries (funcall lister root))
         (runtime
          (loom/feature/file-tree:make-loom-concurrent-runtime :directory-lister
                                                               lister)))
    (loom/feature/file-tree:loom-concurrent-runtime-prime-directory runtime
                                                                    root
                                                                    initial-entries)
    (loom/feature/file-tree:file-tree-install-child-lister tree
                                                           (lambda (path)
                                                             (multiple-value-bind (entries
                                                                                   present-p)
                                                                 (loom/feature/file-tree:loom-concurrent-runtime-directory-entries
                                                                  runtime
                                                                  path)
                                                               (when present-p
                                                                 entries))))
    (setf (editor-state-concurrent-runtime state) runtime)
    runtime))

(defun %shutdown-editor-services (state)
  "Stop asynchronous services attached to STATE."
  (let ((runtime (editor-state-concurrent-runtime state)))
    (when runtime
      (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime)))
  (let ((session (editor-state-lsp-session state)))
    (when session
      (loom/feature/lsp:lsp-session-stop session))))

(defun %run-loom-session (startup-context fd)
  (let ((session (editor-state-session *editor-state*))
        (terminal-session nil)
        (signal-handlers-installed-p nil)
        (reason :normal)
        (status 0))
    (unwind-protect
        (handler-case (progn
                        (setf terminal-session (%open-loom-terminal-session fd
                                                                            *standard-output*))
                        (loom/core/editor-session:set-session-wake-function
                         session
                         (lambda (wake-session)
                           (declare (ignore wake-session))
                           (%wake-loom-terminal-session terminal-session 0)))
                        (setf (%loom-terminal-session-modes terminal-session) (%resolve-loom-terminal-modes
                                                                               session))
                        (%install-loom-terminal-signal-handlers
                         terminal-session)
                        (setf signal-handlers-installed-p t)
                        (%enable-loom-terminal-session terminal-session)
                        (loom/core/editor-session:run-session-hooks :startup
                                                                    session
                                                                    startup-context
                                                                    terminal-session)
                        (loom/feature/user-init:load-user-init)
                        (multiple-value-setq (reason status) (%run-event-loop
                                                              (%loom-terminal-session-stream
                                                               terminal-session)
                                                              *standard-input*
                                                              terminal-session)))
          (error (condition)
            (let ((logger
                   (log-kit:make-logger :name
                                        "loom"
                                        :handler
                                        (log-kit:make-text-handler :stream
                                                                   *error-output*)
                                        :level
                                        log-kit:+level-error+)))
              (log-kit:log-error logger
                                 (princ-to-string condition)
                                 :condition-type
                                 (type-of condition)))
            (setf reason :runtime-error
                  status 1)))
      (when terminal-session
        (handler-case (loom/core/editor-session:run-session-hooks :shutdown
                                                                  session
                                                                  reason)
          (error (condition)
            (let ((logger
                   (log-kit:make-logger :name
                                        "loom"
                                        :handler
                                        (log-kit:make-text-handler :stream
                                                                   *error-output*)
                                        :level
                                        log-kit:+level-error+)))
              (log-kit:log-error logger
                                 (princ-to-string condition)
                                 :condition-type
                                 (type-of condition)))
            (setf reason :runtime-error
                  status 1)))
        (handler-case (loom/core/editor-session:cancel-session-background-work
                       session)
          (error (condition)
            (let ((logger
                   (log-kit:make-logger :name
                                        "loom"
                                        :handler
                                        (log-kit:make-text-handler :stream
                                                                   *error-output*)
                                        :level
                                        log-kit:+level-error+)))
              (log-kit:log-error logger
                                 (princ-to-string condition)
                                 :condition-type
                                 (type-of condition)))
            (setf reason :runtime-error
                  status 1)))
        (unwind-protect
            (progn
              (loom/core/editor-session:set-session-wake-function session nil)
              (when signal-handlers-installed-p
                (%uninstall-loom-terminal-signal-handlers)))
          (handler-case (%close-loom-terminal-session terminal-session)
            (error (condition)
              (let ((logger
                     (log-kit:make-logger :name
                                          "loom"
                                          :handler
                                          (log-kit:make-text-handler :stream
                                                                     *error-output*)
                                          :level
                                          log-kit:+level-error+)))
                (log-kit:log-error logger
                                   (princ-to-string condition)
                                   :condition-type
                                   (type-of condition)))
              (setf reason :runtime-error
                    status 1))))))
    (values reason status)))

(defstruct
    (%loom-terminal-session
     (:constructor %make-loom-terminal-session
                   (fd stream wake-read-fd wake-write-fd))
     (:copier nil))
  fd
  stream
  wake-read-fd
  wake-write-fd
  modes
  active-modes
  (raw-mode-p nil)
  (alternate-screen-p nil)
  (suspended-p nil))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require :sb-posix))

(defun %open-loom-terminal-session (fd stream)
  (multiple-value-bind (read-fd write-fd) (sb-posix:pipe)
    (handler-case (progn
                    (dolist (descriptor (list read-fd write-fd))
                      (let ((flags (sb-posix:fcntl descriptor sb-posix:f-getfl)))
                        (sb-posix:fcntl descriptor
                                        sb-posix:f-setfl
                                        (logior flags sb-posix:o-nonblock))))
                    (%make-loom-terminal-session fd stream read-fd write-fd))
      (error (condition)
        (ignore-errors (sb-unix:unix-close read-fd))
        (ignore-errors (sb-unix:unix-close write-fd))
        (error condition)))))

(defun %wake-loom-terminal-session (terminal-session byte)
  (check-type byte (unsigned-byte 8))
  (let ((buffer
         (make-array 1
                     :element-type
                     (quote (unsigned-byte 8))
                     :initial-element
                     byte)))
    (sb-sys:with-pinned-objects (buffer)
                                (multiple-value-bind (count errno)
                                    (sb-unix:unix-write
                                     (%loom-terminal-session-wake-write-fd
                                      terminal-session)
                                     (sb-sys:vector-sap buffer)
                                     0
                                     1)
                                  (unless (or count (eql errno sb-unix:eagain))
                                    (error
                                     "Terminal wake pipe write failed with errno ~S."
                                     errno))
                                  count))))

(defun %drain-loom-terminal-wake (terminal-session)
  (let ((buffer (make-array 4096 :element-type '(unsigned-byte 8)))
        (bytes nil)
        (finished-p nil))
    (loop until finished-p
          do (sb-sys:with-pinned-objects (buffer)
                                         (multiple-value-bind (count errno)
                                             (sb-unix:unix-read
                                              (%loom-terminal-session-wake-read-fd
                                               terminal-session)
                                              (sb-sys:vector-sap buffer)
                                              (length buffer))
                                           (cond
                                             ((null count)
                                              (cond
                                                ((eql errno sb-unix:eagain)
                                                 (setf finished-p t))
                                                ((eql errno sb-unix:eintr) nil)
                                                (t
                                                 (error
                                                  "Terminal wake pipe read failed with errno ~S."
                                                  errno))))
                                             ((zerop count)
                                              (setf finished-p t))
                                             (t
                                              (dotimes (index count)
                                                (push (aref buffer index) bytes)))))))
    (nreverse bytes)))

(defun %loom-terminal-mode-sequence (mode enabled-p)
  (case mode
    (:mouse-sgr
     (if enabled-p
         (cl-tty-kit:ansi-set-mode 1006)
         (cl-tty-kit:ansi-reset-mode 1006)))
    (:mouse-button-event
     (if enabled-p
         (cl-tty-kit:ansi-set-mode 1002)
         (cl-tty-kit:ansi-reset-mode 1002)))
    (:bracketed-paste
     (if enabled-p
         (cl-tty-kit:ansi-enable-bracketed-paste)
         (cl-tty-kit:ansi-disable-bracketed-paste)))
    (otherwise (error "Unknown terminal mode: ~S" mode))))

(defun %enable-loom-terminal-session (terminal-session)
  (unless (%loom-terminal-session-raw-mode-p terminal-session)
    (cl-tty-kit:enable-raw-mode (%loom-terminal-session-fd terminal-session))
    (setf (%loom-terminal-session-raw-mode-p terminal-session) t))
  (unless (%loom-terminal-session-alternate-screen-p terminal-session)
    (setf (%loom-terminal-session-alternate-screen-p terminal-session) t)
    (write-string (cl-tty-kit:ansi-enter-alternate-screen)
                  (%loom-terminal-session-stream terminal-session))
    (finish-output (%loom-terminal-session-stream terminal-session)))
  (dolist (mode (%loom-terminal-session-modes terminal-session))
    (unless
        (member mode
                (%loom-terminal-session-active-modes terminal-session)
                :test
                (function eq))
      (setf (%loom-terminal-session-active-modes terminal-session) (append
                                                                    (%loom-terminal-session-active-modes
                                                                     terminal-session)
                                                                    (list mode)))
      (write-string (%loom-terminal-mode-sequence mode t)
                    (%loom-terminal-session-stream terminal-session))
      (finish-output (%loom-terminal-session-stream terminal-session))))
  terminal-session)

(defun %disable-loom-terminal-session (terminal-session)
  (unwind-protect
      (dolist
          (mode
           (reverse
            (copy-list (%loom-terminal-session-active-modes terminal-session))))
        (write-string (%loom-terminal-mode-sequence mode nil)
                      (%loom-terminal-session-stream terminal-session))
        (finish-output (%loom-terminal-session-stream terminal-session))
        (setf (%loom-terminal-session-active-modes terminal-session) (remove
                                                                      mode
                                                                      (%loom-terminal-session-active-modes
                                                                       terminal-session)
                                                                      :test
                                                                      (function
                                                                       eq))))
    (unwind-protect
        (when (%loom-terminal-session-alternate-screen-p terminal-session)
          (write-string (cl-tty-kit:ansi-exit-alternate-screen)
                        (%loom-terminal-session-stream terminal-session))
          (finish-output (%loom-terminal-session-stream terminal-session))
          (setf (%loom-terminal-session-alternate-screen-p terminal-session) nil))
      (when (%loom-terminal-session-raw-mode-p terminal-session)
        (cl-tty-kit:disable-raw-mode
         (%loom-terminal-session-fd terminal-session))
        (setf (%loom-terminal-session-raw-mode-p terminal-session) nil))))
  terminal-session)

(defun %resolve-loom-terminal-modes (session)
  (remove-duplicates
   (loop for modes in (loom/core/editor-session:run-session-hooks
                       :terminal-modes
                       session)
         append (copy-list modes))
   :test
   (function eq)
   :from-end
   t))

(defun %install-loom-terminal-signal-handlers (terminal-session)
  (dolist
      (entry
       (list (cons sb-unix:sigterm 1)
             (cons sb-unix:sighup 2)
             (cons sb-unix:sigtstp 3)
             (cons sb-unix:sigcont 4)))
    (let ((signal (car entry))
          (byte (cdr entry)))
      (sb-sys:enable-interrupt signal
                               (lambda (&rest arguments)
                                 (declare (ignore arguments))
                                 (unless
                                     (and (= byte 4)
                                          (%loom-terminal-session-suspended-p
                                           terminal-session))
                                   (%wake-loom-terminal-session terminal-session
                                                                byte))))))
  terminal-session)

(defun %uninstall-loom-terminal-signal-handlers ()
  (dolist
      (signal
       (list sb-unix:sigterm sb-unix:sighup sb-unix:sigtstp sb-unix:sigcont))
    (sb-sys:enable-interrupt signal :default))
  nil)

(defun %close-loom-terminal-session (terminal-session)
  (unwind-protect (%disable-loom-terminal-session terminal-session)
    (ignore-errors
     (sb-unix:unix-close (%loom-terminal-session-wake-read-fd terminal-session)))
    (ignore-errors
     (sb-unix:unix-close
      (%loom-terminal-session-wake-write-fd terminal-session))))
  terminal-session)

(sb-alien:define-alien-type %loom-pollfd
                            (sb-alien:struct %loom-pollfd
                                             (fd sb-alien:int)
                                             (events sb-alien:short)
                                             (revents sb-alien:short)))

(sb-alien:define-alien-routine ("poll" %loom-poll)
                               sb-alien:int
                               (descriptors (* %loom-pollfd))
                               (count sb-alien:unsigned-int)
                               (timeout-ms sb-alien:int))

(defun %poll-loom-terminal-session (terminal-session input-fd timeout-ms)
  (sb-alien:with-alien ((descriptors (array %loom-pollfd 2)))
                       (setf (sb-alien:slot (sb-alien:deref descriptors 0) 'fd) input-fd
                             (sb-alien:slot (sb-alien:deref descriptors 0)
                                            'events) #x0001
                             (sb-alien:slot (sb-alien:deref descriptors 0)
                                            'revents) 0
                             (sb-alien:slot (sb-alien:deref descriptors 1) 'fd) (%loom-terminal-session-wake-read-fd
                                                                                 terminal-session)
                             (sb-alien:slot (sb-alien:deref descriptors 1)
                                            'events) #x0001
                             (sb-alien:slot (sb-alien:deref descriptors 1)
                                            'revents) 0)
                       (loop for result = (%loom-poll
                                           (sb-alien:cast
                                            (sb-alien:addr descriptors)
                                            (* %loom-pollfd))
                                           2
                                           (or timeout-ms -1))
                             when (minusp result)
                               do (let ((errno (sb-alien:get-errno)))
                                    (unless (eql errno sb-unix:eintr)
                                      (error
                                       "Polling terminal input and wake pipe failed: ~S"
                                       errno)))
                             when (not (minusp result))
                               do (let ((input-events
                                         (sb-alien:slot
                                          (sb-alien:deref descriptors 0)
                                          'revents))
                                        (wake-events
                                         (sb-alien:slot
                                          (sb-alien:deref descriptors 1)
                                          'revents)))
                                    (when
                                        (or (logtest #x0020 input-events)
                                            (logtest #x0020 wake-events))
                                      (error
                                       "Polling terminal input or wake pipe found an invalid descriptor."))
                                    (return
                                     (values (logtest #x0019 input-events)
                                             (logtest #x0019 wake-events)))))))

(defun %suspend-loom-terminal-session (session terminal-session)
  (loom/core/editor-session:run-session-hooks :suspend session)
  (%disable-loom-terminal-session terminal-session)
  (setf (%loom-terminal-session-suspended-p terminal-session) t)
  (sb-sys:enable-interrupt sb-unix:sigtstp :default)
  (sb-sys:enable-interrupt sb-unix:sigcont :default)
  (unwind-protect (sb-posix:kill (sb-posix:getpid) sb-unix:sigtstp)
    (%install-loom-terminal-signal-handlers terminal-session))
  (let ((terminate-p
         (member :terminate
                 (loom/core/editor-session:run-session-hooks :signal
                                                             session
                                                             :cont)
                 :test
                 (function eq))))
    (unless terminate-p
      (setf (%loom-terminal-session-suspended-p terminal-session) nil)
      (%enable-loom-terminal-session terminal-session)
      (loom/core/editor-session:run-session-hooks :resume
                                                  session
                                                  terminal-session))
    (and terminate-p :terminate)))
