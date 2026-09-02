;;;; src/application/event-loop.lisp
;;;;
;;;; The application event loop owns the main loop and dispatch sequencing.
;;;; Terminal sizing and input wait policy live in event-loop-control.lisp;
;;;; frame rendering/background refresh work lives in event-loop-rendering.lisp;
;;;; input decoding itself is isolated in input-dispatch.lisp; startup and
;;;; resource lifecycle are isolated in startup.lisp.
(in-package #:loom)

(defun %read-and-dispatch-event-loop-input (input-stream buffer decoder keymap-state)
  "Read and dispatch one event-loop turn.

Return T when input was dispatched, :TIMEOUT when background work should be
polled, and NIL when INPUT-STREAM reached EOF."
  (if (%wait-for-editor-input input-stream)
      (let ((count (%read-input-octets buffer input-stream)))
        (when count
          (%dispatch-input-chunk decoder buffer count keymap-state)
          t))
      :timeout))

(defun %run-event-loop-turn (output-stream input-stream buffer decoder
                             keymap-state last-width last-height)
  "Process one event-loop turn and return its status and terminal dimensions.

EOF returns NIL without running background work or rendering.  A dispatched
input chunk or timeout runs the periodic work, checks the terminal size, and
renders the next frame."
  (let ((status (%read-and-dispatch-event-loop-input
                 input-stream buffer decoder keymap-state)))
    (when status
      (loom/feature/auto-save:maybe-auto-save)
      (multiple-value-bind (width height)
          (%poll-terminal-resize (editor-state-renderer *editor-state*)
                                 last-width last-height)
        (%render-event-loop-frame output-stream)
        (values status width height)))))

(defun %run-event-loop (output-stream input-stream)
  "Run the main input and render loop, writing frames to OUTPUT-STREAM and
reading octets from INPUT-STREAM.

The initial frame is rendered before waiting for input. Each subsequent
iteration reads raw octets, dispatches decoded key events, reacts to terminal
resizes, then redraws the frame."
  (let ((decoder (cl-tty-kit:make-input-decoder))
        (buf (make-array 4096 :element-type '(unsigned-byte 8)))
        (keymap-state (make-keymap-state (editor-state-keymap *editor-state*))))
    (multiple-value-bind (last-width last-height) (%initial-terminal-size)
      (%render-event-loop-frame output-stream)
      (handler-case
          (loop
            (multiple-value-bind (status width height)
                (%run-event-loop-turn output-stream input-stream buf decoder
                                      keymap-state last-width last-height)
              (unless status (return))
              (setf last-width width
                    last-height height)))
        (loom-quit () nil)))))
