(in-package #:loom)

(defun %initial-terminal-size ()
  "Return (VALUES WIDTH HEIGHT) for the controlling terminal via
CL-TTY-KIT:TERMINAL-SIZE, falling back to 80x24 when the size is unavailable
(e.g. *STANDARD-INPUT* is not a real terminal)."
  (multiple-value-bind (columns rows) (cl-tty-kit:terminal-size)
    (values (or columns 80) (or rows 24))))

(defun %poll-terminal-resize (renderer last-width last-height)
  "Check CL-TTY-KIT:TERMINAL-SIZE against LAST-WIDTH/LAST-HEIGHT and, on a
change, resize RENDERER via LOOM-RENDERER-RESIZE. Returns the (VALUES WIDTH
HEIGHT) to track as the last-seen size from now on -- LAST-WIDTH/LAST-HEIGHT
unchanged when the terminal size could not be read or has not changed."
  (multiple-value-bind (width height) (cl-tty-kit:terminal-size)
    (if (and width height (or (/= width last-width) (/= height last-height)))
        (progn
          (loom-renderer-resize renderer width height)
          (loom/feature/terminal:resize-terminal-sessions width
                                                          height
                                                          *editor-state*)
          (values width height))
        (values last-width last-height))))

(defparameter *event-loop-poll-interval*
  0.05
  "Input-wait timeout in seconds while terminal, LSP, or auto-save work is active.

The interval is only used while there is background work that needs a
periodic turn.  With no live terminal session, LSP session, auto-save mode,
or auto-save buffers, the loop keeps its original blocking read behavior.")

(defun %event-loop-background-work-p ()
  "Whether the event loop must wake up without a keyboard byte."
  (not
   (null
    (or
     (some #'loom/feature/terminal:terminal-session-alive-p
           (editor-state-terminal-sessions *editor-state*))
     (editor-state-lsp-session *editor-state*)
     (editor-state-auto-save-mode-p *editor-state*)
     (editor-state-auto-save-buffers *editor-state*)))))

(defun %stream-fd-if-supported (stream)
  (handler-case (values (cl-tty-kit:stream-fd stream) t)
    (type-error () (values nil nil))))

(defun %wait-for-editor-input (input-stream &optional terminal-session)
  "Wait for terminal input and session wake notifications together when possible."
  (if terminal-session
      (let ((timeout-ms
             (when (%event-loop-background-work-p)
               (max 1 (round (* 1000 *event-loop-poll-interval*))))))
        (multiple-value-bind (input-fd supported-p)
            (%stream-fd-if-supported input-stream)
          (if supported-p
              (multiple-value-bind (input-ready-p wake-ready-p)
                  (%poll-loom-terminal-session terminal-session
                                               input-fd
                                               timeout-ms)
                (values input-ready-p
                        wake-ready-p
                        (and timeout-ms
                             (not input-ready-p)
                             (not wake-ready-p))))
              (values t nil nil))))
      (if (%event-loop-background-work-p)
          (multiple-value-bind (input-fd supported-p)
              (%stream-fd-if-supported input-stream)
            (if supported-p
                (if (cl-tty-kit:fd-wait input-fd
                                        :input
                                        *event-loop-poll-interval*)
                    (values t nil nil)
                    (values nil nil t))
                (values t nil nil)))
          (values t nil nil))))

(defun %process-loom-wake-events (terminal-session session bytes poll-work-p)
  (let ((suspend-request-p
         (loom/core/editor-session:consume-terminal-suspend-request session))
        (suspended-p nil)
        (frame-dirty-p nil)
        (more-ready-p nil))
    (dolist (byte bytes)
      (let ((signal-name
             (case byte
               (1 :term)
               (2 :hup)
               (3 :tstp)
               (4 :cont))))
        (when signal-name
          (let ((results
                 (loom/core/editor-session:run-session-hooks :signal
                                                             session
                                                             signal-name)))
            (when
                (or (member :terminate results :test (function eq))
                    (member signal-name (list :term :hup) :test (function eq)))
              (return-from %process-loom-wake-events
                (values :terminate
                        (case signal-name
                          (:term :sigterm)
                          (:hup :sighup)
                          (otherwise :normal))
                        (case signal-name
                          (:term 143)
                          (:hup 129)
                          (otherwise 0))
                        nil
                        nil)))
            (when (eq signal-name :tstp)
              (setf suspend-request-p nil
                    suspended-p t)
              (when
                  (eq (%suspend-loom-terminal-session session terminal-session)
                      :terminate)
                (return-from %process-loom-wake-events
                  (values :terminate :normal 0 nil nil)))
              (setf frame-dirty-p t))))
        ;; SIGWINCH wakes the poll so the event loop can query size and redraw.
))
    (when (and suspend-request-p (not suspended-p))
      (when
          (eq (%suspend-loom-terminal-session session terminal-session)
              :terminate)
        (return-from %process-loom-wake-events
          (values :terminate :normal 0 nil nil)))
      (setf frame-dirty-p t))
    (when poll-work-p
      (multiple-value-bind (poll-dirty-p poll-more-ready-p)
          (loom/core/editor-session:poll-ready-background-work session)
        (setf frame-dirty-p (or frame-dirty-p poll-dirty-p)
              more-ready-p poll-more-ready-p)))
    (values nil nil nil frame-dirty-p more-ready-p)))
