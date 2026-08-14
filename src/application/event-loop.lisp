;;;; src/application/event-loop.lisp
;;;;
;;;; The application event loop owns the main loop and dispatch sequencing.
;;;; Terminal sizing and input wait policy live in event-loop-control.lisp;
;;;; frame rendering/background refresh work lives in event-loop-rendering.lisp;
;;;; input decoding itself is isolated in input-dispatch.lisp; startup and
;;;; resource lifecycle are isolated in startup.lisp.
(in-package #:loom)

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
      (labels ((read-and-dispatch ()
                 (if (%wait-for-editor-input input-stream)
                     ;; NIL once INPUT-STREAM hits EOF, which is what ends
                     ;; the LOOP below; LOOM-QUIT ends it by unwinding instead.
                     (let ((count (%read-input-octets buf input-stream)))
                       (when count
                         (%dispatch-input-chunk decoder buf count keymap-state)
                         t))
                     ;; A timeout is a productive iteration: RENDER-FRAME
                     ;; polls PTYs and runs the normal background work below.
                     :timeout)))
        (%render-event-loop-frame output-stream)
        (handler-case
            (loop for status = (read-and-dispatch)
                  while status
                  do (loom/feature/auto-save:maybe-auto-save)
                  do (multiple-value-setq (last-width last-height)
                       (%poll-terminal-resize (editor-state-renderer *editor-state*)
                                              last-width last-height))
                     (%render-event-loop-frame output-stream))
          (loom-quit () nil))))))
