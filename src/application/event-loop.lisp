;;;; src/application/event-loop.lisp
;;;;
;;;; The application event loop coordinates rendering, asynchronous
;;;; file-tree/LSP refreshes, terminal resize polling, and input dispatch.
;;;; Input decoding itself is isolated in input-dispatch.lisp; startup and
;;;; resource lifecycle are isolated in startup.lisp.
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
          (loom/feature/terminal:resize-terminal-sessions
           width height *editor-state*)
          (values width height))
        (values last-width last-height))))

(defparameter *event-loop-poll-interval* 0.05
  "Maximum seconds between background terminal and auto-save polls.

The interval is only used while there is background work that needs a
periodic turn.  With no live terminal session or auto-save target, the loop
keeps its original blocking read behavior.")

(defun %event-loop-background-work-p ()
  "Whether the event loop must wake up without a keyboard byte."
  (or (some #'loom/feature/terminal:terminal-session-alive-p
            (editor-state-terminal-sessions *editor-state*))
      (editor-state-auto-save-mode-p *editor-state*)
      (editor-state-auto-save-buffers *editor-state*)))

(defun %wait-for-editor-input ()
  "Wait for input, or return NIL after the background poll interval.

CL-TTY-KIT's descriptor wait lets PTY output and auto-save timers make
progress even when the user is idle.  Non-file streams used by tests and
embedding callers do not have a descriptor; those retain the old blocking
read semantics instead of making the event loop depend on a particular
stream implementation."
  (if (not (%event-loop-background-work-p))
      t
      (handler-case
          (cl-tty-kit:fd-wait
           (cl-tty-kit:stream-fd *standard-input*)
           :input
           *event-loop-poll-interval*)
        (error () t))))

(defun %run-event-loop (stream)
  "Run the main input and render loop, writing frames to STREAM.

The initial frame is rendered before waiting for input. Each subsequent
iteration reads raw octets, dispatches decoded key events, reacts to terminal
resizes, then redraws the frame."
  (let ((decoder (cl-tty-kit:make-input-decoder))
        (buf (make-array 4096 :element-type '(unsigned-byte 8)))
        (keymap-state (make-keymap-state (editor-state-keymap *editor-state*))))
    (multiple-value-bind (last-width last-height) (%initial-terminal-size)
      (labels ((render-frame ()
                 (loom/feature/terminal:poll-terminal-sessions *editor-state*)
                 (let ((runtime (editor-state-concurrent-runtime *editor-state*)))
                   (when runtime
                     (loom/feature/file-tree:loom-concurrent-runtime-drain runtime)
                     (loom/feature/file-tree:loom-concurrent-runtime-prefetch
                      runtime
                      (loom/feature/file-tree:file-tree-prefetch-paths
                       (editor-state-file-tree *editor-state*)))))
                 (let ((session (editor-state-lsp-session *editor-state*))
                       (buffer (%selected-buffer)))
                   (when (and session (buffer-path buffer))
                     (loom/feature/lsp:lsp-session-refresh session buffer)))
                 (compose-frame *editor-state*)
                 (loom-renderer-present (editor-state-renderer *editor-state*)
                                        :stream stream
                                        :cursor (editor-cursor *editor-state*)))
               (read-and-dispatch ()
                 (if (%wait-for-editor-input)
                     ;; NIL once *STANDARD-INPUT* hits EOF, which is what ends
                     ;; the LOOP below; LOOM-QUIT ends it by unwinding instead.
                     (let ((count (%read-input-octets buf)))
                       (when count
                         (%dispatch-input-chunk decoder buf count keymap-state)
                         t))
                     ;; A timeout is a productive iteration: RENDER-FRAME
                     ;; polls PTYs and runs the normal background work below.
                     :timeout)))
        (render-frame)
        (handler-case
            (loop for status = (read-and-dispatch)
                  while status
                  do (loom/feature/auto-save:maybe-auto-save)
                  do (multiple-value-setq (last-width last-height)
                       (%poll-terminal-resize (editor-state-renderer *editor-state*)
                                              last-width last-height))
                     (render-frame))
          (loom-quit () nil))))))
