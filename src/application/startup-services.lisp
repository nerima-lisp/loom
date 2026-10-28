(in-package #:loom)

(defun %enable-concurrent-file-tree (state)
  (loom/feature/file-tree:enable-file-tree-runtime state))

(defun %shutdown-editor-services (state)
  "Stop asynchronous services attached to STATE."
  (loom/feature/file-tree:shutdown-file-tree-runtime state)
  (loom/feature/lsp:lsp-stop-editor-state-lsp-session state))

(defun %log-loom-error (condition)
  (let ((logger
         (log-kit:make-logger :name
                              "loom"
                              :handler
                              (log-kit:make-text-handler :stream *error-output*)
                              :level
                              log-kit:+level-error+)))
    (log-kit:log-error logger
                       (princ-to-string condition)
                       :condition-type
                       (type-of condition))))
(defun %call-with-loom-terminal-streams (fd fd-supplied-p thunk)
  "Call THUNK with the selected terminal descriptor and input/output streams.

Use the inherited standard streams when both are terminals. If either is
redirected, open the controlling terminal so keyboard input and rendering stay
together."
  (if fd-supplied-p
      (funcall thunk fd *standard-input* *standard-output*)
      (labels ((terminal-stream-fd (stream)
                 (multiple-value-bind (stream-fd supported-p)
                     (%stream-fd-if-supported stream)
                   (when (and supported-p (eql 1 (sb-unix:unix-isatty stream-fd)))
                     stream-fd))))
        (let ((input-fd (terminal-stream-fd *standard-input*))
              (output-fd (terminal-stream-fd *standard-output*)))
          (if (and input-fd output-fd)
              (funcall thunk input-fd *standard-input* *standard-output*)
              (let ((terminal-fd
                      (sb-posix:open "/dev/tty" sb-posix:o-rdwr))
                    (input-fd nil)
                    (output-fd nil)
                    (input-stream nil)
                    (output-stream nil))
                (unwind-protect
                     (progn
                       (setf input-fd (sb-posix:dup terminal-fd)
                             output-fd (sb-posix:dup terminal-fd))
                       (setf input-stream
                             (sb-sys:make-fd-stream
                              input-fd
                              :input t
                              :element-type '(unsigned-byte 8))
                             input-fd nil)
                       (setf output-stream
                             (sb-sys:make-fd-stream
                              output-fd
                              :output t
                              :element-type 'character)
                             output-fd nil)
                       (funcall thunk terminal-fd input-stream output-stream))
                  (when output-stream
                    (ignore-errors (close output-stream)))
                  (when input-stream
                    (ignore-errors (close input-stream)))
                  (when output-fd
                    (ignore-errors (sb-unix:unix-close output-fd)))
                  (when input-fd
                    (ignore-errors (sb-unix:unix-close input-fd)))
                  (ignore-errors (sb-unix:unix-close terminal-fd)))))))))
(defun %ensure-loom-messages-buffer ()
  (when *editor-state*
    (let ((session (editor-state-session *editor-state*)))
      (or (loom/feature/buffers:find-buffer-by-name session "*Messages*")
          (loom/feature/buffers:register-buffer
           session
           (loom/core/buffer:make-buffer :name "*Messages*"))))))

(defun %append-loom-message-to-buffer (text)
  (when *editor-state*
    (let* ((buffer (%ensure-loom-messages-buffer))
           (last-line (1- (loom/core/buffer:buffer-line-count buffer))))
      (loom/core/buffer:buffer-set-point
       buffer
       last-line
       (length (loom/core/buffer:buffer-line buffer last-line)))
      (loom/core/buffer:buffer-insert-string buffer (format nil "~A~%" text))
      (loom/core/buffer:buffer-mark-saved buffer))))

(defun %install-loom-message-sink ()
  (loom/core/minibuffer:register-message-sink
   :loom-messages
   (function %append-loom-message-to-buffer))
  (%ensure-loom-messages-buffer))

(defun %run-loom-session (startup-context fd render-frame-function)
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
                        (progn
                          (%install-loom-message-sink)
                          (unless (gethash "--no-init"
                                           (loom/core/editor-session:startup-context-options startup-context))
                            (handler-case
                                (funcall *startup-load-user-init-function*)
                              (error (condition)
                                     (%log-loom-error condition)
                                     (loom/core/minibuffer:minibuffer-message
                                      (loom/core/editor-session:editor-state-minibuffer *editor-state*)
                                      (format nil "Error loading user init: ~A" condition))))))
                        (multiple-value-setq (reason status) (%run-event-loop
                                                              (%loom-terminal-session-stream
                                                               terminal-session)
                                                              *standard-input*
                                                              terminal-session
                                                              render-frame-function)))
          (error (condition)
                 (%log-loom-error condition)
                 (setf reason :runtime-error
                       status 1)))
      (when terminal-session
        (handler-case (loom/core/editor-session:run-session-hooks :shutdown
                                                                  session
                                                                  reason)
          (error (condition)
                 (%log-loom-error condition)
                 (setf reason :runtime-error
                       status 1)))
        (handler-case (loom/core/editor-session:cancel-session-background-work
                       session)
          (error (condition)
                 (%log-loom-error condition)
                 (setf reason :runtime-error
                       status 1)))
        (unwind-protect
            (progn
              (loom/core/editor-session:set-session-wake-function session nil)
              (when signal-handlers-installed-p
                (%uninstall-loom-terminal-signal-handlers)))
          (handler-case (%close-loom-terminal-session terminal-session)
            (error (condition)
                   (%log-loom-error condition)
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
  ;; Wake bytes 1-4 carry lifecycle signals; byte 5 requests a resize redraw.
  (dolist
      (entry
       (list (cons sb-unix:sigterm 1)
             (cons sb-unix:sighup 2)
             (cons sb-unix:sigtstp 3)
             (cons sb-unix:sigcont 4)
             (cons sb-unix:sigwinch 5)))
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
       (list sb-unix:sigterm
             sb-unix:sighup
             sb-unix:sigtstp
             sb-unix:sigcont
             sb-unix:sigwinch))
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
#+darwin
(sb-alien:define-alien-type %loom-select-fd-set
  (sb-alien:struct %loom-select-fd-set
    (bits (array sb-alien:unsigned-int 32))))
#+darwin
(sb-alien:define-alien-type %loom-select-timeval
  (sb-alien:struct %loom-select-timeval
    (seconds sb-alien:long)
    (microseconds sb-alien:int)))

(sb-alien:define-alien-routine ("poll" %loom-poll)
                               sb-alien:int
                               (descriptors (* %loom-pollfd))
                               (count sb-alien:unsigned-int)
                               (timeout-ms sb-alien:int))
#+darwin
(sb-alien:define-alien-routine ("select" %loom-select)
  sb-alien:int
  (nfds sb-alien:int)
  (readfds (* %loom-select-fd-set))
  (writefds (* %loom-select-fd-set))
  (exceptfds (* %loom-select-fd-set))
  (timeout (* %loom-select-timeval)))

#+darwin
(defun %select-loom-terminal-session (terminal-session input-fd timeout-ms)
  (let ((wake-fd (%loom-terminal-session-wake-read-fd terminal-session)))
    (dolist (fd (list input-fd wake-fd))
      (unless (and (integerp fd) (<= 0 fd) (< fd 1024))
        (error "Selecting terminal input or wake pipe found an invalid descriptor: ~S."
               fd)))
    (loop
      (sb-alien:with-alien ((read-fds %loom-select-fd-set)
                            (write-fds %loom-select-fd-set)
                            (except-fds %loom-select-fd-set)
                            (timeout %loom-select-timeval))
        (dolist (fd-set (list read-fds write-fds except-fds))
          (dotimes (word 32)
            (setf (sb-alien:deref (sb-alien:slot fd-set 'bits) word) 0)))
        (flet ((add-fd (fd)
                 (let* ((word (floor fd 32))
                        (mask (ash 1 (mod fd 32)))
                        (bits (sb-alien:slot read-fds 'bits)))
                   (setf (sb-alien:deref bits word)
                         (logior (sb-alien:deref bits word) mask))))
               (fd-ready-p (fd)
                 (let* ((word (floor fd 32))
                        (mask (ash 1 (mod fd 32)))
                        (bits (sb-alien:slot read-fds 'bits)))
                   (logtest mask (sb-alien:deref bits word)))))
          (add-fd input-fd)
          (add-fd wake-fd)
          (let* ((timeout-pointer
                   (if (and timeout-ms (not (minusp timeout-ms)))
                       (multiple-value-bind (seconds milliseconds)
                           (floor timeout-ms 1000)
                         (setf (sb-alien:slot timeout 'seconds) seconds
                               (sb-alien:slot timeout 'microseconds)
                               (* milliseconds 1000))
                         (sb-alien:addr timeout))
                       (sb-alien:sap-alien
                        (sb-sys:int-sap 0)
                        (* %loom-select-timeval))))
                 (result (%loom-select
                          (1+ (max input-fd wake-fd))
                          (sb-alien:addr read-fds)
                          (sb-alien:addr write-fds)
                          (sb-alien:addr except-fds)
                          timeout-pointer)))
            (if (minusp result)
                (let ((errno (sb-alien:get-errno)))
                  (unless (eql errno sb-unix:eintr)
                    (error "Selecting terminal input and wake pipe failed: ~S"
                           errno)))
                (return (values (fd-ready-p input-fd)
                                (fd-ready-p wake-fd))))))))))

(defun %poll-loom-terminal-session (terminal-session input-fd timeout-ms)
  #+darwin
  (%select-loom-terminal-session terminal-session input-fd timeout-ms)
  #-darwin
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
  (setf (%loom-terminal-session-suspended-p terminal-session) nil)
  (%enable-loom-terminal-session terminal-session)
  (funcall *startup-renderer-invalidate-function* *editor-state*)
  (loom/core/editor-session:run-session-hooks :resume
                                              session
                                              terminal-session)
  nil)
