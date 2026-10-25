(in-package #:loom)

(defun %read-and-dispatch-event-loop-input (input-stream buffer
                                                         decoder
                                                         keymap-state
                                                         terminal-session
                                                         force-ready-p)
  "Process wake and polling work before dispatching ready terminal input.

Return status, reason, exit status, frame-dirty-p, and more-ready-p."
  (multiple-value-bind (input-ready-p wake-ready-p poll-ready-p)
      (if force-ready-p
          (values nil nil nil)
          (%wait-for-editor-input input-stream terminal-session))
    (let ((wake-bytes
           (when (and terminal-session (or wake-ready-p force-ready-p))
             (%drain-loom-terminal-wake terminal-session))))
      (multiple-value-bind (status reason
                                   exit-status
                                   frame-dirty-p
                                   more-ready-p)
          (if (or wake-ready-p poll-ready-p force-ready-p)
              (%process-loom-wake-events terminal-session
                                         (editor-state-session *editor-state*)
                                         wake-bytes
                                         (or wake-ready-p
                                             poll-ready-p
                                             force-ready-p))
              (values nil nil nil nil nil))
        (cond
          ((eq status :terminate)
           (values status reason exit-status frame-dirty-p more-ready-p))
          (input-ready-p
           (let ((count (%read-input-octets buffer input-stream)))
             (if count
                 (progn
                   (%dispatch-input-chunk decoder buffer count keymap-state)
                   (values :input nil nil frame-dirty-p more-ready-p))
                 (values nil nil nil frame-dirty-p more-ready-p))))
          (t (values :timeout nil nil frame-dirty-p more-ready-p)))))))

(defun %run-event-loop-turn (output-stream input-stream
                                           buffer
                                           decoder
                                           keymap-state
                                           last-width
                                           last-height
                                           terminal-session
                                           force-ready-p)
  (multiple-value-bind (status reason exit-status frame-dirty-p more-ready-p)
      (%read-and-dispatch-event-loop-input input-stream
                                           buffer
                                           decoder
                                           keymap-state
                                           terminal-session
                                           force-ready-p)
    (declare (ignore frame-dirty-p))
    (cond
      ((eq status :terminate)
       (values :terminate reason exit-status last-width last-height nil))
      (status
        (loom/core/editor-session:run-session-hooks :tick
                                                    (editor-state-session
                                                     *editor-state*)
                                                    (/ (get-internal-real-time)
                                                       internal-time-units-per-second))
        (multiple-value-bind (width height)
            (%poll-terminal-resize (editor-state-renderer *editor-state*)
                                   last-width
                                   last-height)
          (%render-event-loop-frame output-stream)
          (values status nil nil width height more-ready-p)))
      (t nil))))

(defun %run-event-loop (output-stream input-stream &optional terminal-session)
  "Run input, background wake, lifecycle and render turns until shutdown."
  (let ((decoder (cl-tty-kit:make-input-decoder))
        (buffer (make-array 4096 :element-type '(unsigned-byte 8)))
        (keymap-state (make-keymap-state (editor-state-keymap *editor-state*)))
        (poll-ready-p nil))
    (multiple-value-bind (last-width last-height) (%initial-terminal-size)
      (%render-event-loop-frame output-stream)
      (handler-case (loop (multiple-value-bind (status reason
                                                       exit-status
                                                       width
                                                       height
                                                       more-ready-p)
                              (%run-event-loop-turn output-stream
                                                    input-stream
                                                    buffer
                                                    decoder
                                                    keymap-state
                                                    last-width
                                                    last-height
                                                    terminal-session
                                                    poll-ready-p)
                            (cond
                              ((eq status :terminate)
                               (return (values reason exit-status)))
                              ((null status) (return (values :normal 0)))
                              (t
                               (setf last-width width
                                     last-height height
                                     poll-ready-p more-ready-p)))))
        (loom-quit ()
          (values :normal 0))))))
